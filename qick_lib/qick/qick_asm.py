"""
The interface for writing QICK programs.
This contains tools for managing the board configuration and the base class for QICK programs.
The assembly language for QICK programs is defined separately for the v1 and v2 tProcessors.
"""
import logging
import numpy as np
import json
from collections import namedtuple, OrderedDict, defaultdict
import operator
import functools
from tqdm.auto import tqdm

from qick import obtain, get_version
from .helpers import to_int, cosine, gauss, triang, DRAG

logger = logging.getLogger(__name__)

class QickConfig():
    """Uses the QICK configuration to convert frequencies and clock delays.
    If running on the QICK, you don't need to use this class - the QickSoc class has all of the same methods.
    If running remotely, you may want to initialize a QickConfig from a JSON file.

    Parameters
    ----------
    cfg : dict or str
        config dictionary, or path to JSON file

    Returns
    -------

    """

    def __init__(self, cfg=None):
        if cfg is not None:
            # we are getting an external config dictionary (e.g. from a Pyro server)
            if isinstance(cfg, str):
                with open(cfg) as f:
                    self._cfg = json.load(f)
            else:
                self._cfg = cfg
            # compare the remote and local versions, warn on mismatch
            # if the remote library is so old that it doesn't have sw_version, get() will return None
            extversion = self._cfg.get('sw_version')
            ourversion = get_version()
            if extversion != ourversion:
                logger.warning("QICK library version mismatch: %s remote (the board), %s local (the PC)\n\
                        This may cause errors, usually KeyError in QickConfig initialization.\n\
                        If this happens, you must bring your versions in sync."%(extversion, ourversion))

    def __str__(self):
        return self.description()

    def __getitem__(self, key):
        return self._cfg[key]

    def __setitem__(self, key, val):
        self._cfg[key] = val

    def description(self):
        """Generate a printable description of the QICK configuration.

        Parameters
        ----------

        Returns
        -------
        str
            description

        """
        tproc = self['tprocs'][0]

        lines = []
        lines.append("\n\tBoard: " + self['board'])
        lines.append("\n\tSoftware version: " + self['sw_version'])
        lines.append("\tFirmware timestamp: " + self['fw_timestamp'])
        lines.append("\n\tGlobal clocks (MHz): tProcessor %.3f, RF reference %.3f" % (
            tproc['f_time'], self['refclk_freq']))

        lines.append("\n\t%d signal generator channels:" % (len(self['gens'])))
        for iGen, gen in enumerate(self['gens']):
            lines.append("\t%d:\t%s - tProc output %d, envelope memory %d samples" %
                         (iGen, gen['type'], gen['tproc_ch'], gen['maxlen']))
            lines.append("\t\tDAC tile %s, blk %s, %d-bit DDS, fabric=%.3f MHz, f_dds=%.3f MHz" %
                         (*gen['dac'], gen['b_dds'], gen['f_fabric'], gen['f_dds']))

        if self['iqs']:
            lines.append("\n\t%d constant-IQ outputs:" % (len(self['iqs'])))
            for iIQ, iq in enumerate(self['iqs']):
                lines.append("\t%d:\tDAC tile %s, blk %s, fs=%.3f MHz" %
                             (iIQ, *iq['dac'], iq['fs']))

        lines.append("\n\t%d readout channels:" % (len(self['readouts'])))
        for iReadout, readout in enumerate(self['readouts']):
            if 'tproc_ctrl' in readout:
                lines.append("\t%d:\t%s - controlled by tProc output %d" % (iReadout, readout['ro_type'], readout['tproc_ctrl']))
            else:
                lines.append("\t%d:\t%s - controlled by PYNQ" % (iReadout, readout['ro_type']))
            lines.append("\t\tADC tile %s, blk %s, %d-bit DDS, fabric=%.3f MHz, f_dds=%.3f MHz" %
                         (*readout['adc'], readout['b_dds'], readout['f_fabric'], readout['f_dds']))
            lines.append("\t\tmaxlen %d (avg) %d (decimated)" % (
                readout['avg_maxlen'], readout['buf_maxlen']))
            lines.append("\t\ttriggered by %s %d, pin %d, feedback to tProc input %d" % (
                readout['trigger_type'], readout['trigger_port'], readout['trigger_bit'], readout['tproc_ch']))

        lines.append("\n\t%d DACs:" % (len(self['dacs'])))
        for dac in self['dacs']:
            tile, block = [int(c) for c in dac]
            if self['board']=='ZCU111':
                label = "DAC%d_T%d_CH%d or RF board output %d" % (tile + 228, tile, block, tile*4 + block)
            elif self['board']=='ZCU216':
                label = "%d_%d, on JHC%d" % (block, tile + 228, 1 + (block%2) + 2*(tile//2))
            elif self['board']=='RFSoC4x2':
                label = {'00': 'DAC_B', '20': 'DAC_A'}[dac]
            lines.append("\t\tDAC tile %d, blk %d is %s" %
                         (tile, block, label))

        lines.append("\n\t%d ADCs:" % (len(self['adcs'])))
        for adc in self['adcs']:
            tile, block = [int(c) for c in adc]
            if self['board']=='ZCU111':
                rfbtype = "DC" if tile > 1 else "AC"
                label = "ADC%d_T%d_CH%d or RF board %s input %d" % (tile + 224, tile, block, rfbtype, (tile%2)*2 + block)
            elif self['board']=='ZCU216':
                label = "%d_%d, on JHC%d" % (block, tile + 224, 5 + (block%2) + 2*(tile//2))
            elif self['board']=='RFSoC4x2':
                label = {'00': 'ADC_D', '01': 'ADC_C', '20': 'ADC_B', '21': 'ADC_A'}[adc]
            lines.append("\t\tADC tile %d, blk %d is %s" %
                         (tile, block, label))

        lines.append("\n\t%d digital output pins:" % (len(tproc['output_pins'])))
        for iPin, (porttype, port, pin, name) in enumerate(tproc['output_pins']):
            lines.append("\t%d:\t%s (%s %d, pin %d)" % (iPin, name, porttype, port, pin))

        lines.append("\n\ttProc %s: program memory %d words, data memory %d words" %
                (tproc['type'], tproc['pmem_size'], tproc['dmem_size']))
        lines.append("\t\texternal start pin: %s" % (tproc['start_pin']))

        bufnames = [ro['avgbuf_fullpath'] for ro in self['readouts']]
        if "ddr4_buf" in self._cfg:
            buf = self['ddr4_buf']
            buflist = [bufnames.index(x) for x in buf['readouts']]
            lines.append("\n\tDDR4 memory buffer: %d samples, %d samples/transfer" % (buf['maxlen'], buf['burst_len']))
            lines.append("\t\twired to readouts %s, triggered by %s %d, pin %d" % (
                buflist, buf['trigger_type'], buf['trigger_port'], buf['trigger_bit']))

        if "mr_buf" in self._cfg:
            buf = self['mr_buf']
            buflist = [bufnames.index(x) for x in buf['readouts']]
            lines.append("\n\tMR buffer: %d samples, wired to readouts %s, triggered by %s %d, pin %d" % (
                buf['maxlen'], buflist, buf['trigger_type'], buf['trigger_port'], buf['trigger_bit']))
            #lines.append("\t\twired to readouts %s, triggered by %s %d, pin %d" % (
            #    buflist, buf['trigger_type'], buf['trigger_port'], buf['trigger_bit']))

        return "\nQICK configuration:\n"+"\n".join(lines)

    def get_cfg(self):
        """Return the QICK configuration dictionary.
        This contains everything you need to recreate the QickConfig.

        Parameters
        ----------

        Returns
        -------
        dict
            configuration dictionary

        """
        return self._cfg

    def dump_cfg(self):
        """Generate a JSON description of the QICK configuration.
        You can save this string to a file and load it to recreate the QickConfig.

        Parameters
        ----------

        Returns
        -------
        str
            configuration in JSON format

        """
        return json.dumps(self._cfg, indent=4)

    def calc_fstep_int(self, dict1, dict2):
        """Finds the multiplier that needs to be applied to a channel's frequency step size to allow this channel to be frequency-matched with another channel.

        Parameters
        ----------
        dict1 : dict
            config dict for this channel
        dict2 : dict
            config dict for the other channel

        Returns
        -------
        int
            frequency step multiplier for the first channel
        """
        refclk = self['refclk_freq']
        # Calculate least common multiple of sampling frequencies.

        # The DDS ranges are related to the refclk by fs_mult and fdds_div, both integers: f_dds = refclk*fs_mult/fdds_div
        # So we can find a common div:
        max_div = np.lcm(dict1['fdds_div'], dict2['fdds_div'])
        # and the max of the bit resolutions:
        b_max = max(dict1['b_dds'], dict2['b_dds'])

        # so the frequency steps are both divisible by a "common divisor" of refclk/max_div/2**b_max
        # and these multipliers from the common divisor to the channel steps are always integer
        fsmult1 = dict1['fs_mult'] * (max_div//dict1['fdds_div']) * 2**(b_max - dict1['b_dds'])
        fsmult2 = dict2['fs_mult'] * (max_div//dict2['fdds_div']) * 2**(b_max - dict2['b_dds'])

        # the LCM of those multipliers will give us a common multiple of the channel steps
        mult_lcm = np.lcm(fsmult1, fsmult2)
        # so mult_lcm times the common divisor gives us a common step size that is divisible by both channel steps
        # we want the common step divided by the channel 1 step:
        return mult_lcm//fsmult1

    def ch_fstep(self, dict1):
        """Finds the frequency step size of a single channel (generator or readout).

        Parameters
        ----------
        dict1 : dict
            config dict for one channel

        Returns
        -------
        float
            frequency step for this channel
        """
        return dict1['fs_mult'] * (self['refclk_freq']/dict1['fdds_div']) / 2**dict1['b_dds']

    def calc_fstep(self, dict1, dict2):
        """Finds the least common multiple of the frequency steps of two channels (typically a generator and readout)
        For proper frequency matching, you should only use frequencies that are evenly divisible by this value.
        The order of the parameters does not matter.

        Parameters
        ----------
        dict1 : dict
            config dict for this channel
        dict2 : dict
            config dict for the other channel

        Returns
        -------
        float
            frequency step common to the two channels
        """
        # find the multiplier from channel 1's minimum step size to the common step size
        step_int1 = self.calc_fstep_int(dict1, dict2)
        # multiply channel 1's step size by the multiplier
        return step_int1 * self.ch_fstep(dict1)

    def roundfreq(self, f, dict1, dict2):
        """Round a frequency to the LCM of the frequency steps of two channels (typically a generator and readout).

        Parameters
        ----------
        f : float or array
            frequency (MHz)
        dict1 : dict
            config dict for one channel
        dict2 : dict
            config dict for the other channel

        Returns
        -------
        float or array
            rounded frequency (MHz)

        """
        fstep = self.calc_fstep(dict1, dict2)
        return np.round(f/fstep) * fstep

    def freq2int(self, f, thisch, otherch=None):
        """Converts frequency in MHz to integer value suitable for writing to a register.
        This method works for both generators and readouts.
        If a gen will be connected to an RO, the two channels must have exactly the same frequency, and you must supply the config for the other channel.

        Parameters
        ----------
        f : float
            frequency (MHz)
        thisch : dict
            config dict for the channel you're configuring
        otherch : dict
            config dict for a channel you will set to the same frequency

        Returns
        -------
        int
            Re-formatted frequency

        """
        if otherch is None:
            step_int = 1
        else:
            step_int = self.calc_fstep_int(thisch, otherch)
        return to_int(f, 1/self.ch_fstep(thisch), parname='freq', quantize=step_int)

    def int2freq(self, r, thisch):
        """Converts register value to MHz.
        This method works for both generators and readouts.

        Parameters
        ----------
        r : int
            register value
        thisch : dict
            config dict for the channel you're configuring

        Returns
        -------
        float
            Re-formatted frequency (MHz)

        """
        return r * thisch['f_dds'] / 2**thisch['b_dds']

    def freq2reg(self, f, gen_ch=0, ro_ch=None):
        """Converts frequency in MHz to tProc generator register value.

        Parameters
        ----------
        f : float
            frequency (MHz)
        gen_ch : int
            generator channel
        ro_ch : int
            readout channel (use None if you don't want to frequency-match to a readout)

        Returns
        -------
        int
            Re-formatted frequency

        """
        if ro_ch is None:
            rocfg = None
        else:
            rocfg = self['readouts'][ro_ch]
        gencfg = self['gens'][gen_ch]
        if gencfg['type'] in ['axis_sg_int4_v1', 'axis_sg_mux4_v1', 'axis_sg_mux4_v2']:
            # because of the interpolation filter, there is no output power in the higher nyquist zones
            if abs(f)>gencfg['f_dds']/2:
                raise RuntimeError("requested frequency %f is outside of the range [-fs/2, fs/2]"%(f))
        return self.freq2int(f, gencfg, rocfg) % 2**gencfg['b_dds']

    def freq2reg_adc(self, f, ro_ch=0, gen_ch=None):
        """Converts frequency in MHz to readout register value.

        Parameters
        ----------
        f : float
            frequency (MHz)
        ro_ch : int
            readout channel
        gen_ch : int
            generator channel (use None if you don't want to frequency-match to a generator)

        Returns
        -------
        int
            Re-formatted frequency

        """
        if gen_ch is None:
            gencfg = None
        else:
            gencfg = self['gens'][gen_ch]
        rocfg = self['readouts'][ro_ch]
        return self.freq2int(f, rocfg, gencfg) % 2**rocfg['b_dds']

    def reg2freq(self, r, gen_ch=0):
        """Converts frequency from format readable by generator to MHz.

        Parameters
        ----------
        r : int
            frequency in generator format
        gen_ch : int
            generator channel

        Returns
        -------
        float
            Re-formatted frequency in MHz

        """
        return (r/2**self['gens'][gen_ch]['b_dds']) * self['gens'][gen_ch]['f_dds']

    def reg2freq_adc(self, r, ro_ch=0):
        """Converts frequency from format readable by readout to MHz.

        Parameters
        ----------
        r : int
            frequency in readout format
        ro_ch : int
            readout channel

        Returns
        -------
        float
            Re-formatted frequency in MHz

        """
        return (r/2**self['readouts'][ro_ch]['b_dds']) * self['readouts'][ro_ch]['f_dds']

    def adcfreq(self, f, gen_ch=0, ro_ch=0):
        """Takes a frequency and trims it to the closest DDS frequency valid for both channels.

        Parameters
        ----------
        f : float
            frequency (MHz)
        gen_ch : int
            generator channel
        ro_ch : int
            readout channel

        Returns
        -------
        float
            Re-formatted frequency

        """
        return self.roundfreq(f, self['gens'][gen_ch], self['readouts'][ro_ch])

    def deg2reg(self, deg, gen_ch=0):
        """Converts degrees into phase register values; numbers greater than 360 will effectively be wrapped.

        Parameters
        ----------
        deg : float
            Number of degrees
        gen_ch : int
             generator channel (index in 'gens' list)

        Returns
        -------
        int
            Re-formatted number of degrees

        """
        gen_type = self['gens'][gen_ch]['type']
        if gen_type == 'axis_sg_int4_v1':
            b_phase = 16
        else:
            b_phase = 32
        return to_int(deg, 2**b_phase/360, parname='phase') % 2**b_phase

    def reg2deg(self, reg, gen_ch=0):
        """Converts phase register values into degrees.

        Parameters
        ----------
        reg : int
            Re-formatted number of degrees
        gen_ch : int
             generator channel (index in 'gens' list)

        Returns
        -------
        float
            Number of degrees

        """
        gen_type = self['gens'][gen_ch]['type']
        if gen_type == 'axis_sg_int4_v1':
            b_phase = 16
        else:
            b_phase = 32
        return reg*360/2**b_phase

    def cycles2us(self, cycles, gen_ch=None, ro_ch=None):
        """Converts clock cycles to microseconds.
        Uses tProc clock frequency by default.
        If gen_ch or ro_ch is specified, uses that generator/readout channel's fabric clock.

        Parameters
        ----------
        cycles : int
            Number of clock cycles
        gen_ch : int
            generator channel (index in 'gens' list)
        ro_ch : int
            readout channel (index in 'readouts' list)

        Returns
        -------
        float
            Number of microseconds

        """
        if gen_ch is not None and ro_ch is not None:
            raise RuntimeError("can't specify both gen_ch and ro_ch!")
        if gen_ch is not None:
            fclk = self['gens'][gen_ch]['f_fabric']
        elif ro_ch is not None:
            fclk = self['readouts'][ro_ch]['f_fabric']
        else:
            fclk = self['tprocs'][0]['f_time']
        return cycles/fclk

    def us2cycles(self, us, gen_ch=None, ro_ch=None):
        """Converts microseconds to integer number of clock cycles.
        Uses tProc clock frequency by default.
        If gen_ch or ro_ch is specified, uses that generator/readout channel's fabric clock.

        Parameters
        ----------
        us : float
            Number of microseconds
        gen_ch : int
            generator channel (index in 'gens' list)
        ro_ch : int
            readout channel (index in 'readouts' list)

        Returns
        -------
        int
            Number of clock cycles

        """
        if gen_ch is not None and ro_ch is not None:
            raise RuntimeError("can't specify both gen_ch and ro_ch!")
        if gen_ch is not None:
            fclk = self['gens'][gen_ch]['f_fabric']
        elif ro_ch is not None:
            fclk = self['readouts'][ro_ch]['f_fabric']
        else:
            fclk = self['tprocs'][0]['f_time']
        #return np.int64(np.round(obtain(us)*fclk))
        return to_int(obtain(us), fclk, parname='length')


class DummyIp:
    """Stores the configuration constants for a firmware IP block.
    """
    def __init__(self, iptype, fullpath):
        # config dictionary for QickConfig
        self._cfg = {'type': iptype,
                    'fullpath': fullpath}

    @property
    def cfg(self):
        return self._cfg

    def __getitem__(self, key):
        return self._cfg[key]


class AbsQickProgram:
    """Generic QICK program, including support for generator and readout configuration but excluding tProc-specific code.
    """
    # Calls to these methods will be passed through to the soccfg object.
    soccfg_methods = ['freq2reg', 'freq2reg_adc',
                      'reg2freq', 'reg2freq_adc',
                      'cycles2us', 'us2cycles',
                      'deg2reg', 'reg2deg']

    def __init__(self, soccfg):
        """
        Constructor method
        """
        self.soccfg = soccfg
        self.tproccfg = self.soccfg['tprocs'][0]

        # Pulse envelopes.
        self.envelopes = [{} for ch in soccfg['gens']]
        # readout channels to configure before running the program
        self.ro_chs = OrderedDict()
        # signal generator channels to configure before running the program
        self.gen_chs = OrderedDict()

        # Timestamps, for keeping track of pulse and readout end times.
        self._gen_ts = [0]*len(soccfg['gens'])
        self._ro_ts = [0]*len(soccfg['readouts'])

        # tProc address of the rep counter, must be defined
        self.counter_addr = None

        # data dimensions, must be defined:
        # list of loop dimensions, outermost loop first
        self.loop_dims = None
        # which loop level to average over (0 is outermost)
        self.avg_level = None

        # threshold and angle for single-shot discrimination, if desired
        self.shot_threshold = None
        self.shot_angle = None

    def __getattr__(self, a):
        """
        Include QickConfig methods as methods of the QickProgram.
        This allows e.g. this.freq2reg(f) instead of this.soccfg.freq2reg(f).

        :param a: Instruction name
        :type a: str
        :return: Instruction arguments
        :rtype: *args object
        """
        if a in self.__class__.soccfg_methods:
            return getattr(self.soccfg, a)
        else:
            return object.__getattribute__(self, a)

    def config_all(self, soc, load_pulses=True):
        """
        Load the waveform memory, gens, ROs, and program memory as specified for this program.
        The decimated+accumulated buffers are not configured, since those should be re-configured for each acquisition.
        The tProc is set to internal start before any other configuration is done, to prevent spurious external starts.
        """
        # set tproc to internal-start, to prevent spurious starts
        soc.start_src("internal")

        # Load the pulses from the program into the soc
        if load_pulses:
            self.load_pulses(soc)

        # Configure signal generators
        self.config_gens(soc)

        # Configure the readout down converters
        self.config_readouts(soc)


    def declare_readout(self, ch, length, freq=None, sel='product', gen_ch=None):
        """Add a channel to the program's list of readouts.

        Parameters
        ----------
        ch : int
            readout channel number (index in 'readouts' list)
        freq : float
            downconverting frequency (MHz)
        length : int
            readout length (number of samples)
        sel : str
            output select ('product', 'dds', 'input')
        gen_ch : int
            generator channel (use None if you don't want the downconversion frequency to be rounded to a valid DAC frequency or be offset by the DAC mixer frequency)
        """
        ro_cfg = self.soccfg['readouts'][ch]
        if 'tproc_ctrl' not in ro_cfg: # readout is controlled by PYNQ
            if freq is None:
                raise RuntimeError("frequency must be declared for a PYNQ-controlled readout")
            # this number comes from the fact that the ADC is 12 bit + 3 bits from decimation = 15 bit
            # and the sum buffer values are 32 bit signed
            if length > 2**(31-15):
                logger.warning(f'With the given readout length there is a possibility that the sum buffer will overflow giving invalid results.')
            cfg = {
                    'freq': freq,
                    'length': length,
                    'sel': sel,
                    'gen_ch': gen_ch,
                    'trigs': 0
                    }
        else: # readout is controlled by tProc
            if (freq is not None) or sel!='product' or (gen_ch is not None):
                raise RuntimeError("this is a tProc-controlled readout - freq/sel parameters are set using tProc instructions")
            cfg = {
                    'length': length,
                    'trigs': 0
                    }
        self.ro_chs[ch] = cfg

    def config_readouts(self, soc):
        """Configure the readout channels specified in this program.
        This is usually called as part of an acquire() method.

        Parameters
        ----------
        soc : QickSoc
            the QickSoc that will execute this program

        """
        soc.init_readouts()
        for ch, cfg in self.ro_chs.items():
            if 'tproc_ctrl' not in self.soccfg['readouts'][ch]:
                soc.configure_readout(ch, output=cfg['sel'], frequency=cfg['freq'], gen_ch=cfg['gen_ch'])

    def config_bufs(self, soc, enable_avg=True, enable_buf=True):
        """Configure the readout buffers specified in this program.
        This is usually called as part of an acquire() method.

        Parameters
        ----------
        soc : QickSoc
            the QickSoc that will execute this program
        enable_avg : bool
            enable the accumulated (averaging) buffer
        enable_buf : bool
            enable the decimated (waveform) buffer

        """
        for ch, cfg in self.ro_chs.items():
            if enable_avg:
                soc.config_avg(ch, address=0, length=cfg['length'], enable=True)
            if enable_buf:
                soc.config_buf(ch, address=0, length=cfg['length'], enable=True)

    def declare_gen(self, ch, nqz=1, mixer_freq=0, mux_freqs=None, mux_gains=None, ro_ch=None):
        """Add a channel to the program's list of signal generators.

        If this is a generator with a mixer (interpolated or muxed generator), you may define a mixer frequency.

        If this is a muxed generator, the mux_freqs and mux_gains lists must be long enough to define all the tones you will play.
        (in other words, if your mask list ever enables tone 2 you must define at least 3 freqs+gains)

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        nqz : int, optional
            Nyquist zone (must be 1 or 2).
            Setting the NQZ to 2 increases output power in the 2nd/3rd Nyquist zones.
        mixer_freq : float, optional
            Mixer frequency (in MHz)
        mux_freqs : list of float, optional
            Tone frequencies for the muxed generator (in MHz).
            Positive and negative values are allowed.
        mux_gains : list of float, optional
            Tone amplitudes for the muxed generator (in range -1 to 1).
        ro_ch : int, optional
            readout channel (use None if you don't want mixer and mux freqs to be rounded to a valid ADC frequency)
        """
        cfg = {
                'nqz': nqz,
                'mixer_freq': mixer_freq,
                'mux_freqs': mux_freqs,
                'mux_gains': mux_gains,
                'ro_ch': ro_ch
                }
        self.gen_chs[ch] = cfg

    def config_gens(self, soc):
        """Configure the signal generators specified in this program.
        This is usually called as part of an acquire() method.

        Parameters
        ----------
        soc : QickSoc
            the QickSoc that will execute this program

        """
        for ch, cfg in self.gen_chs.items():
            soc.set_nyquist(ch, cfg['nqz'])
            soc.set_mixer_freq(ch, cfg['mixer_freq'], cfg['ro_ch'])
            if cfg['mux_freqs'] is not None:
                soc.set_mux_freqs(ch, freqs=cfg['mux_freqs'], gains=cfg['mux_gains'])

    def add_envelope(self, ch, name, idata=None, qdata=None):
        """Adds a waveform to the waveform library within the program.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        name : str
            Name of the pulse
        idata : array
            I data Numpy array
        qdata : array
            Q data Numpy array

        """
        self._gen_mgrs[ch].add_envelope(name, idata, qdata)

    def add_cosine(self, ch, name, length, maxv=None):
        """Adds a Cosine pulse to the waveform library.
        The pulse will peak at after ramp until length and then ramp down again with ramp.
        The total length is 2*ramp+length.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        name : str
            Name of the pulse
        length : int
            Total pulse length (in units of fabric clocks)
        maxv : float
            Value at the peak (if None, the max value for this generator will be used)

        """
        gencfg = self.soccfg['gens'][ch]
        if maxv is None: maxv = gencfg['maxv']*gencfg['maxv_scale']
        samps_per_clk = gencfg['samps_per_clk']

        length = np.round(length) * samps_per_clk

        self.add_pulse(ch, name, idata=cosine(length=length, maxv=maxv))

    def add_gauss(self, ch, name, sigma, length, maxv=None):
        """Adds a Gaussian pulse to the waveform library.
        The pulse will peak at length/2.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        name : str
            Name of the pulse
        sigma : float
            Standard deviation of the Gaussian (in units of fabric clocks)
        length : int
            Total pulse length (in units of fabric clocks)
        maxv : float
            Value at the peak (if None, the max value for this generator will be used)

        """
        gencfg = self.soccfg['gens'][ch]
        if maxv is None: maxv = gencfg['maxv']*gencfg['maxv_scale']
        samps_per_clk = gencfg['samps_per_clk']

        length = np.round(length) * samps_per_clk
        sigma *= samps_per_clk

        self.add_envelope(ch, name, idata=gauss(mu=length/2-0.5, si=sigma, length=length, maxv=maxv))


    def add_DRAG(self, ch, name, sigma, length, delta, alpha=0.5, maxv=None):
        """Adds a DRAG pulse to the waveform library.
        The pulse will peak at length/2.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        name : str
            Name of the pulse
        sigma : float
            Standard deviation of the Gaussian (in units of fabric clocks)
        length : int
            Total pulse length (in units of fabric clocks)
        maxv : float
            Value at the peak (if None, the max value for this generator will be used)
        delta : float
            anharmonicity of the qubit (units of MHz)
        alpha : float
            alpha parameter of DRAG (order-1 scale factor)

        Returns
        -------

        """
        gencfg = self.soccfg['gens'][ch]
        if maxv is None: maxv = gencfg['maxv']*gencfg['maxv_scale']
        samps_per_clk = gencfg['samps_per_clk']
        f_fabric = gencfg['f_fabric']

        delta /= samps_per_clk*f_fabric

        length = np.round(length) * samps_per_clk
        sigma *= samps_per_clk

        idata, qdata = DRAG(mu=length/2-0.5, si=sigma, length=length, maxv=maxv, alpha=alpha, delta=delta)

        self.add_envelope(ch, name, idata=idata, qdata=qdata)

    def add_triangle(self, ch, name, length, maxv=None):
        """Adds a triangle pulse to the waveform library.
        The pulse will peak at length/2.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        name : str
            Name of the pulse
        length : int
            Total pulse length (in units of fabric clocks)
        maxv : float
            Value at the peak (if None, the max value for this generator will be used)

        """
        gencfg = self.soccfg['gens'][ch]
        if maxv is None: maxv = gencfg['maxv']*gencfg['maxv_scale']
        samps_per_clk = gencfg['samps_per_clk']

        length = np.round(length) * samps_per_clk

        self.add_envelope(ch, name, idata=triang(length=length, maxv=maxv))

    def load_pulses(self, soc):
        """Loads pulses that were added using add_envelope into the SoC's signal generator memories.

        Parameters
        ----------
        soc : Qick object
            Qick object

        """
        for iCh, pulses in enumerate(self.envelopes):
            for name, pulse in pulses.items():
                soc.load_pulse_data(iCh,
                        data=pulse['data'],
                        addr=pulse['addr'])

    def reset_timestamps(self, gen_t0=None):
        self._gen_ts = [0]*len(self._gen_ts) if gen_t0 is None else gen_t0.copy()
        self._ro_ts = [0]*len(self._ro_ts)

    def get_timestamp(self, gen_ch=None, ro_ch=None):
        if gen_ch is not None and ro_ch is not None:
            raise RuntimeError("can't specify both gen_ch and ro_ch!")
        if gen_ch is not None:
            return self._gen_ts[gen_ch]
        elif ro_ch is not None:
            return self._ro_ts[ro_ch]
        else:
            raise RuntimeError("must specify gen_ch or ro_ch!")

    def set_timestamp(self, val, gen_ch=None, ro_ch=None):
        if gen_ch is not None and ro_ch is not None:
            raise RuntimeError("can't specify both gen_ch and ro_ch!")
        if gen_ch is not None:
            self._gen_ts[gen_ch] = val
        elif ro_ch is not None:
            self._ro_ts[ro_ch] = val
        else:
            raise RuntimeError("must specify gen_ch or ro_ch!")

    def get_max_timestamp(self, gens=True, ros=True, gen_t0=None):
        timestamps = []
        if gens:
            if gen_t0 is None:
                timestamps += list(self._gen_ts)
            else:
                gen_ts_copy = np.copy(self._gen_ts)
                gen_t0_copy = np.copy(gen_t0)
                timestamps += list(np.maximum(gen_ts_copy - gen_t0_copy, 0))
        if ros: timestamps += list(self._ro_ts)
        return max(timestamps)

    def acquire(self, soc, soft_avgs, reads_per_rep=None, load_pulses=True, start_src="internal", progress=False):
        """Acquire data using the accumulated readout.

        Parameters
        ----------
        soc : QickSoc
            Qick object
        soft_avgs : int
            number of times to rerun the program, averaging results in software (aka "rounds")
        reads_per_rep : int
            number of readout triggers in the loop body
            by default, this is automatically detected based on calls to trigger()
        load_pulses : bool
            if True, load pulse envelopes
        start_src: str
            "internal" (tProc starts immediately) or "external" (each round waits for an external trigger)
        progress: bool
            if true, displays progress bar

        Returns
        -------
        ndarray
            raw accumulated IQ values (int32)
            if rounds>1, only the last round is kept
            dimensions : (n_ch, n_expts*n_reps*n_reads, 2)

        ndarray
            averaged IQ values (float)
            divided by the length of the RO window, and averaged over reps and rounds
            if shot_threshold is defined, the I values will be the fraction of points over threshold
            dimensions for a simple averaging program: (n_ch, n_reads, 2)
            dimensions for a program with multiple expts/steps: (n_ch, n_reads, n_expts, 2)
        """

        self.config_all(soc, load_pulses=load_pulses)

        # configure tproc for internal/external start
        soc.start_src(start_src)

        n_ro = len(self.ro_chs)
        if reads_per_rep is not None:
            for ro_ch in self.ro_chs.values():
                ro_ch['trigs'] = reads_per_rep
        reads_per_rep = [ro['trigs'] for ro in self.ro_chs.values()]

        total_count = functools.reduce(operator.mul, self.loop_dims)
        d_buf = [np.zeros((total_count*nreads, 2), dtype=np.int32) for nreads in reads_per_rep]
        self.stats = []

        # select which tqdm progress bar to show
        hiderounds = True
        hidereps = True
        if progress:
            if soft_avgs>1:
                hiderounds = False
            else:
                hidereps = False

        # avg_d doesn't have a specific shape here, so that it's easier for child programs to write custom _average_buf
        avg_d = None
        shots = None
        for ir in tqdm(range(soft_avgs), disable=hiderounds):
            # Configure and enable buffer capture.
            self.config_bufs(soc, enable_avg=True, enable_buf=False)

            count = 0
            with tqdm(total=total_count, disable=hidereps) as pbar:
                soc.start_readout(total_count, counter_addr=self.counter_addr,
                                       ch_list=list(self.ro_chs), reads_per_rep=reads_per_rep)
                while count<total_count:
                    new_data = obtain(soc.poll_data())
                    for new_points, (d, s) in new_data:
                        for ii, nreads in enumerate(reads_per_rep):
                            d_buf[ii][count*nreads:(count+new_points)*nreads] = d[ii]
                        count += new_points
                        self.stats.append(s)
                        pbar.update(new_points)

            # if we're thresholding, apply the threshold before averaging
            if self.shot_threshold is None:
                d_reps = d_buf
            else:
                d_reps = [np.zeros_like(d) for d in d_buf]
                shots = self.get_single_shots(d_buf)
                for i, ch_shot in enumerate(shots):
                    d_reps[i][...,0] = ch_shot

            # sum over rounds axis
            round_d = self._average_buf(d_reps, reads_per_rep)
            if avg_d is None:
                avg_d = round_d
            else:
                for ii, d in enumerate(round_d): avg_d[ii] += d

        # divide total by rounds
        for d in avg_d: d /= soft_avgs

        return d_buf, avg_d, shots

    def _average_buf(self, d_reps: np.ndarray, reads_per_rep: list) -> np.ndarray:
        """
        calculate averaged data in a data acquire round. This function should be overwritten in the child qick program
        if the data is created in a different shape.

        :param d_reps: buffer data acquired in a round
        :param reads_per_rep: readouts per experiment
        :return: averaged iq data after each round.
        """
        averaged_dims = self.loop_dims.copy()
        del averaged_dims[self.avg_level]
        avg_d = [np.zeros((nreads, *averaged_dims, 2)) for nreads in reads_per_rep]
        for i_ch, ro in enumerate(self.ro_chs.values()):
            nreads = reads_per_rep[i_ch]
            for ii in range(nreads):
                avg_d[i_ch][ii] = d_reps[i_ch][ii::nreads, :].reshape((*self.loop_dims, 2)).sum(axis=self.avg_level) / (self.loop_dims[self.avg_level] * ro['length'])

        return avg_d

    def get_single_shots(self, d_buf):
        """
        This method converts the raw I/Q data to single shots according to the threshold and rotation angle

        Parameters
        ----------
        d_buf : list of ndarray
            Raw IQ data

        Returns
        -------
        list of ndarray
            Single shot data

        """
        # try to convert threshold to list of floats; if that fails, assume it's already a list
        try:
            thresholds = [float(self.shot_threshold)]*len(self.ro_chs)
        except TypeError:
            thresholds = self.shot_threshold
        # angle is 0 if not specified
        if self.shot_angle is None:
            angles = [0.0]*len(self.ro_chs)
        else:
            try:
                angles = [float(self.shot_angle)]*len(self.ro_chs)
            except TypeError:
                angles = self.shot_angle

        shots = []
        for i, ch in enumerate(self.ro_chs):
            rotated = np.inner(d_buf[i], [np.cos(angles[i]), np.sin(angles[i])])/self.ro_chs[ch]['length']
            shots.append(np.heaviside(rotated - thresholds[i], 0))
        return shots


    def acquire_decimated(self, soc, soft_avgs, reads_per_rep=None, load_pulses=True, start_src="internal", progress=True):
        """Acquire data using the decimating readout.

        Parameters
        ----------
        soc : QickSoc
            Qick object
        soft_avgs : int
            number of times to rerun the program, averaging results in software (aka "rounds")
        reads_per_rep : int
            number of readout triggers in the loop body
            by default, this is automatically detected based on calls to trigger()
        load_pulses : bool
            if True, load pulse envelopes
        start_src: str
            "internal" (tProc starts immediately) or "external" (each round waits for an external trigger)
        progress: bool
            if true, displays progress bar

        Returns
        -------
        list of ndarray
            decimated values, averaged over rounds (float)
            dimensions for a single-rep, single-read program : (length, 2)
            multi-rep or multi-read: (n_reps*n_reads, length, 2)
            multi-rep and multi-read: (n_reps, n_reads, length, 2)
        """
        self.config_all(soc, load_pulses=load_pulses)

        # configure tproc for internal/external start
        soc.start_src(start_src)

        if reads_per_rep is not None:
            for ro_ch in self.ro_chs.values():
                ro_ch['trigs'] = reads_per_rep
        reads_per_rep = [ro['trigs'] for ro in self.ro_chs.values()]

        total_count = functools.reduce(operator.mul, self.loop_dims)

        # Initialize data buffers
        d_buf = []
        for ch, ro in self.ro_chs.items():
            maxlen = self.soccfg['readouts'][ch]['buf_maxlen']
            if ro['length']*ro['trigs']*total_count > maxlen:
                raise RuntimeError("Warning: requested readout length (%d x %d trigs x %d reps) exceeds buffer size (%d)"%(ro['length'], ro['trigs'], total_count, maxlen))
            d_buf.append(np.zeros((ro['length']*total_count*ro['trigs'], 2), dtype=float))

        # for each soft average, run and acquire decimated data
        for ii in tqdm(range(soft_avgs), disable=not progress):
            # Configure and enable buffer capture.
            self.config_bufs(soc, enable_avg=True, enable_buf=True)

            # make sure count variable is reset to 0
            soc.set_tproc_counter(addr=self.counter_addr, val=0)

            # run the assembly program
            # if start_src="external", you must pulse the trigger input once for every round
            soc.start_tproc()

            count = 0
            while count < total_count:
                count = soc.get_tproc_counter(addr=self.counter_addr)

            for ii, (ch, ro) in enumerate(self.ro_chs.items()):
                d_buf[ii] += obtain(soc.get_decimated(ch=ch,
                                    address=0, length=ro['length']*ro['trigs']*total_count))

        onetrig = all([ro['trigs']==1 for ro in self.ro_chs.values()])

        # average the decimated data
        if total_count == 1 and onetrig:
            # simple case: data is 1D (one rep and one shot), just average over rounds
            return [d/soft_avgs for d in d_buf]
        else:
            # split the data into the individual reps
            result = []
            for ii, (ch, ro) in enumerate(self.ro_chs.items()):
                if onetrig or total_count==1:
                    d_reshaped = d_buf[ii].reshape(total_count*ro['trigs'], -1, 2)/soft_avgs
                else:
                    d_reshaped = d_buf[ii].reshape(total_count, ro['trigs'], -1, 2)/soft_avgs
                result.append(d_reshaped)
            return result


