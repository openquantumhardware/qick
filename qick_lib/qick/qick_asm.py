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
from abc import ABC, abstractmethod
from tqdm.auto import tqdm

from qick import obtain, get_version
from .helpers import to_int, cosine, gauss, triang, DRAG, decode_array

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

    def _describe_dac(self, dacname):
        tile, block = [int(c) for c in dacname]
        if self['board']=='ZCU111':
            label = "DAC%d_T%d_CH%d or RF board output %d" % (tile + 228, tile, block, tile*4 + block)
        elif self['board']=='ZCU216':
            label = "%d_%d, on JHC%d" % (block, tile + 228, 1 + (block%2) + 2*(tile//2))
        elif self['board']=='RFSoC4x2':
            label = {'00': 'DAC_B', '20': 'DAC_A'}[dacname]
        return "DAC tile %d, blk %d is %s" % (tile, block, label)

    def _describe_adc(self, adcname):
        tile, block = [int(c) for c in adcname]
        if self['board']=='ZCU111':
            rfbtype = "DC" if tile > 1 else "AC"
            label = "ADC%d_T%d_CH%d or RF board %s input %d" % (tile + 224, tile, block, rfbtype, (tile%2)*2 + block)
        elif self['board']=='ZCU216':
            label = "%d_%d, on JHC%d" % (block, tile + 224, 5 + (block%2) + 2*(tile//2))
        elif self['board']=='RFSoC4x2':
            label = {'00': 'ADC_D', '01': 'ADC_C', '20': 'ADC_B', '21': 'ADC_A'}[adcname]
        return "ADC tile %d, blk %d is %s" % (tile, block, label)

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
            dacname = gen['dac']
            dac = self['dacs'][dacname]
            buflen = gen['maxlen']/(gen['samps_per_clk']*gen['f_fabric'])
            lines.append("\t%d:\t%s - envelope memory %d samples (%.3f us)" %
                         (iGen, gen['type'], gen['maxlen'], buflen))
            lines.append("\t\tfs=%.3f MHz, fabric=%.3f MHz, %d-bit DDS, range=%.3f MHz" %
                         (dac['fs'], gen['f_fabric'], gen['b_dds'], gen['f_dds']))
            lines.append("\t\t" + self._describe_dac(dacname))

        if self['iqs']:
            lines.append("\n\t%d constant-IQ outputs:" % (len(self['iqs'])))
            for iIQ, iq in enumerate(self['iqs']):
                dacname = iq['dac']
                dac = self['dacs'][dacname]
                lines.append("\t%d:\tfs=%.3f MHz" % (iIQ, *dacname, iq['fs']))
                lines.append("\t\t" + self._describe_dac(dacname))

        lines.append("\n\t%d readout channels:" % (len(self['readouts'])))
        for iReadout, readout in enumerate(self['readouts']):
            adcname = readout['adc']
            adc = self['adcs'][adcname]
            buflen = readout['buf_maxlen']/readout['f_output']
            if 'tproc_ctrl' in readout:
                lines.append("\t%d:\t%s - controlled by tProc output %d" % (iReadout, readout['ro_type'], readout['tproc_ctrl']))
            else:
                lines.append("\t%d:\t%s - controlled by PYNQ" % (iReadout, readout['ro_type']))
            lines.append("\t\tfs=%.3f MHz, decimated=%.3f MHz, %d-bit DDS, range=%.3f MHz" %
                         (adc['fs'], readout['f_output'], readout['b_dds'], readout['f_dds']))
            lines.append("\t\tmaxlen %d accumulated, %d decimated (%.3f us)" % (
                readout['avg_maxlen'], readout['buf_maxlen'], buflen))
            lines.append("\t\ttriggered by %s %d, pin %d, feedback to tProc input %d" % (
                readout['trigger_type'], readout['trigger_port'], readout['trigger_bit'], readout['tproc_ch']))
            lines.append("\t\t" + self._describe_adc(adcname))

        lines.append("\n\t%d digital output pins:" % (len(tproc['output_pins'])))
        for iPin, (porttype, port, pin, name) in enumerate(tproc['output_pins']):
            lines.append("\t%d:\t%s" % (iPin, name))
            #lines.append("\t%d:\t%s (%s %d, pin %d)" % (iPin, name, porttype, port, pin))

        lines.append("\n\ttProc %s: program memory %d words, data memory %d words" %
                (tproc['type'], tproc['pmem_size'], tproc['dmem_size']))
        lines.append("\t\texternal start pin: %s" % (tproc['start_pin']))

        bufnames = [ro['avgbuf_fullpath'] for ro in self['readouts']]
        if "ddr4_buf" in self._cfg:
            buf = self['ddr4_buf']
            buflist = [bufnames.index(x) for x in buf['readouts']]
            buflen = buf['maxlen']/self['readouts'][buflist[0]]['f_fabric']
            lines.append("\n\tDDR4 memory buffer: %d samples (%.3f sec), %d samples/transfer" % (buf['maxlen'], buflen/1e6, buf['burst_len']))
            lines.append("\t\twired to readouts %s" % (buflist))
            #lines.append("\t\twired to readouts %s, triggered by %s %d, pin %d" % (
            #    buflist, buf['trigger_type'], buf['trigger_port'], buf['trigger_bit']))

        if "mr_buf" in self._cfg:
            buf = self['mr_buf']
            buflist = [bufnames.index(x) for x in buf['readouts']]
            buflen = buf['maxlen']/self['adcs'][self['readouts'][buflist[0]]['adc']]['fs']
            lines.append("\n\tMR buffer: %d samples (%.3f us), wired to readouts %s" % (
                buf['maxlen'], buflen, buflist))
            #lines.append("\n\tMR buffer: %d samples, wired to readouts %s, triggered by %s %d, pin %d" % (
            #    buf['maxlen'], buflist, buf['trigger_type'], buf['trigger_port'], buf['trigger_bit']))

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

    def calc_fstep_int(self, dict1, other_dicts):
        """Finds the multiplier that needs to be applied to a channel's frequency step size to allow this channel to be frequency-matched with another channel.

        Parameters
        ----------
        dict1 : dict
            config dict for this channel
        other_dicts : list of dict
            config dict for the other channel(s)

        Returns
        -------
        int
            frequency step multiplier for the first channel
        """
        refclk = self['refclk_freq']
        # Calculate least common multiple of sampling frequencies.

        alldicts = [dict1] + other_dicts
        # The DDS ranges are related to the refclk by fs_mult and fdds_div, both integers: f_dds = refclk*fs_mult/fdds_div
        # So we can find a common div:
        max_div = np.lcm.reduce([d['fdds_div'] for d in alldicts])
        # and the max of the bit resolutions:
        b_max = max([d['b_dds'] for d in alldicts])

        # so the frequency steps are both divisible by a "common divisor" of refclk/max_div/2**b_max
        # and these multipliers from the common divisor to the channel steps are always integer
        fsmults = [d['fs_mult'] * (max_div//d['fdds_div']) * 2**(b_max - d['b_dds']) for d in alldicts]

        # the LCM of those multipliers will give us a common multiple of the channel steps
        mult_lcm = np.lcm.reduce(fsmults)
        # so mult_lcm times the common divisor gives us a common step size that is divisible by all channel steps
        # we want the common step divided by the channel 1 step:
        return mult_lcm//fsmults[0]

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

    def calc_fstep(self, dicts):
        """Finds the least common multiple of the frequency steps of two or more channels (typically a generator and readout)
        For proper frequency matching, you should only use frequencies that are evenly divisible by this value.
        The order of the parameters does not matter.

        Parameters
        ----------
        dicts : list of dict
            config dict for the channels

        Returns
        -------
        float
            frequency step common to all channels
        """
        # find the multiplier from channel 1's minimum step size to the common step size
        step_int1 = self.calc_fstep_int(dicts[0], dicts[1:])
        # multiply channel 1's step size by the multiplier
        return step_int1 * self.ch_fstep(dicts[0])

    def roundfreq(self, f, dicts):
        """Round a frequency to the LCM of the frequency steps of two or more channels (typically a generator and readout).

        Parameters
        ----------
        f : float or array
            frequency (MHz)
        dicts : list of dict
            config dict for the channels

        Returns
        -------
        float or array
            rounded frequency (MHz)

        """
        fstep = self.calc_fstep(dicts)
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
            step_int = self.calc_fstep_int(thisch, [otherch])
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
        return r / (2**thisch['b_dds'] / thisch['f_dds'])

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
        #if gencfg['type'] in ['axis_sg_int4_v1', 'axis_sg_mux4_v1', 'axis_sg_mux4_v2']:
        if gencfg['interpolation'] != 1:
            # because of the interpolation filter, there is no output power in the higher nyquist zones
            if f > gencfg['f_dds']/2 or f < -gencfg['f_dds']/2:
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
        gencfg = self['gens'][gen_ch]
        return self.int2freq(r, gencfg)

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
        rocfg = self['readouts'][ro_ch]
        return self.int2freq(r, rocfg)

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
        return self.roundfreq(f, [self['gens'][gen_ch], self['readouts'][ro_ch]])

    def _get_ch_cfg(self, gen_ch=None, ro_ch=None):
        """Helper method to grab the config dictionary for a generator or readout.

        Parameters
        ----------
        gen_ch : int
             generator channel (index in 'gens' list)
        ro_ch : int
             readout channel (index in 'readouts' list)

        Returns
        -------
        dict
            Config dictionary, or None if neither paramater was defined

        """
        if gen_ch is not None and ro_ch is not None:
            raise RuntimeError("can't specify both gen_ch and ro_ch!")
        elif gen_ch is not None:
            return self['gens'][gen_ch]
        elif ro_ch is not None:
            return self['readouts'][ro_ch]
        else:
            return None

    def _get_mixer_cfg(self, gen_ch):
        """
        Create a fake config dictionary for a generator's NCO, for use in frequency matching.
        """
        gencfg = self['gens'][gen_ch]
        mixercfg = {}
        mixercfg['fs_mult'] = gencfg['fs_mult']
        mixercfg['fdds_div'] = gencfg['fs_div']
        mixercfg['b_dds'] = 48
        return mixercfg

    def deg2reg(self, deg, gen_ch=0, ro_ch=None):
        """Converts degrees into phase register values; numbers greater than 360 will effectively be wrapped.

        Parameters
        ----------
        deg : float
            Number of degrees
        gen_ch : int
             generator channel (index in 'gens' list)
        ro_ch : int
             readout channel (index in 'readouts' list)

        Returns
        -------
        int
            Re-formatted number of degrees
        """
        ch_cfg = self._get_ch_cfg(gen_ch=gen_ch, ro_ch=ro_ch)
        if ch_cfg is None:
            raise RuntimeError("must specify either gen_ch or ro_ch!")
        b_phase = ch_cfg['b_phase']
        return to_int(deg, 2**b_phase/360, parname='phase') % 2**b_phase

    def reg2deg(self, r, gen_ch=0, ro_ch=None):
        """Converts phase register values into degrees.

        Parameters
        ----------
        reg : int
            Re-formatted number of degrees
        gen_ch : int
             generator channel (index in 'gens' list)
        ro_ch : int
             readout channel (index in 'readouts' list)

        Returns
        -------
        float
            Number of degrees
        """
        ch_cfg = self._get_ch_cfg(gen_ch=gen_ch, ro_ch=ro_ch)
        if ch_cfg is None:
            raise RuntimeError("must specify either gen_ch or ro_ch!")
        b_phase = ch_cfg['b_phase']
        return r / (2**b_phase / 360)

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
            fclk = self['readouts'][ro_ch]['f_output']
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
            fclk = self['readouts'][ro_ch]['f_output']
        else:
            fclk = self['tprocs'][0]['f_time']
        #return np.int64(np.round(obtain(us)*fclk))
        return to_int(obtain(us), fclk, parname='length')

    def calc_mixer_freq(self, gen_ch, mixer_freq, nqz, ro_ch):
        """
        Set the NCO frequency that will be mixed with the generator output.

        The RFdc driver does its own math to convert a frequency to a register value.
        (see XRFdc_SetMixerSettings in xrfdc_mixer.c, and "NCO Frequency Conversion" in PG269)
        This is what it does:
        1. Add/subtract fs to get the frequency in the range of [-fs/2, fs/2].
        2. If the original frequency was not in [-fs/2, fs/2] and the DAC is configured for 2nd Nyquist zone, multiply by -1.
        3. Convert to a 48-bit register value, rounding using C integer casting (i.e. round towards 0).

        Step 2 is not desirable for us, so we must undo it.

        The rounding gives unexpected results sometimes: it's hard to tell if a freq will get rounded up or down.
        This is important if the demanded frequency was rounded to a valid frequency for frequency matching.
        The safest way to get consistent behavior is to always round to a valid NCO frequency.
        We are trusting that the floating-point math is exact and a number we rounded here is still a round number in the RFdc driver.
        """
        cfg = {}
        cfg['userval'] = mixer_freq
        gencfg = self['gens'][gen_ch]
        if ro_ch is None:
            rounded_f = f
        else:
            mixercfg = self._get_mixer_cfg(gen_ch)
            rounded_f = self.roundfreq(mixer_freq, [mixercfg, self['readouts'][ro_ch]])
        cfg['rounded'] = rounded_f
        if abs(rounded_f) > gencfg['fs']/2 and nqz==2:
            cfg['setval'] = -rounded_f
        else:
            cfg['setval'] = rounded_f
        return cfg

    def calc_mux_regs(self, gen_ch, freqs, gains, phases, ro_ch):
        """Calculate the register values to program into a multiplexed generator.
        """
        gencfg = self['gens'][gen_ch]
        if gains is not None and len(gains) != len(freqs):
            raise RuntimeError("lengths of freqs and gains lists do not match")
        if phases is not None and len(phases) != len(freqs):
            raise RuntimeError("lengths of freqs and phases lists do not match")
        tones = []
        for i, freq in enumerate(freqs):
            tone = {}
            tone['freq_int'] = self.freq2reg(freq, gen_ch=gen_ch, ro_ch=ro_ch)
            tone['freq_rounded'] = self.reg2freq(tone['freq_int'], gen_ch=gen_ch)
            if gencfg['has_gain']:
                gain = 1.0 if gains is None else gains[i]
                tone['gain_int'] = int(np.round(gain * gencfg['maxv']))
                tone['gain_rounded'] = tone['gain_int']/gencfg['maxv']
            if gencfg['has_phase']:
                phase = 0.0 if phases is None else phases[i]
                tone['phase_int'] = self.deg2reg(phase, gen_ch=gen_ch)
                tone['phase_rounded'] = self.reg2deg(tone['phase_int'], gen_ch=gen_ch)
            tones.append(tone)
        return tones

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
    QickProgram/QickProgramV2 are the concrete subclasses for tProc v1/v2.

    The tProc executes binary machine code; you write declarations and ASM code (or macros that get expanded to ASM).
    So before a program gets run, you need to fill it with declarations and ASM, and they need to get compiled (converted to machine code).
    There are three ways to prepare a QickProgram for running:

    1. External initialization: Create an empty program object.
    Write the program by calling declaration and ASM methods of the program object.
    The program will be compiled when you try to run, dump, or print it.

    2. Internal initialization: Create a subclass which calls declaration and ASM methods as part of __init__().
    When you create an instance of the subclass, it will automatically fill itself.
    Typically you won't subclass QickProgram directly, you will subclass something like AveragerProgram which does a lot of the work for you.
    The program will be compiled when you try to run, dump, or print.

    3. Loading a dump: Create an empty program object.
    Call QickProgram.load_prog() to load the program definition from a dump.
    The program will be compiled as part of load_prog().
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
        self._init_declarations()
        self._init_instructions()

        # Attributes to dump when saving the program to JSON.
        self.dump_keys = ['envelopes', 'ro_chs', 'gen_chs']

    def _init_declarations(self):
        """Initialize data structures for keeping track of program declarations.
        Structures that are filled directly by user code or a make_program() should be initialized here.
        This will typically mean macros, channels and envelopes.
        Concrete subclasses will extend this method to add more data structures.
        This should be called at class initialization.
        If a program is filled using a make_program() that is called during compilation, this should also be called before make_program().
        """
        logger.debug("init_declarations")
        # Pulse envelopes.
        self.envelopes = [{"next_addr": 0, "envs": {}} for ch in self.soccfg['gens']]
        # readout channels to configure before running the program
        self.ro_chs = OrderedDict()
        # signal generator channels to configure before running the program
        self.gen_chs = OrderedDict()

    def _init_instructions(self):
        """Initialize data structures for keeping track of program instructions.
        Structures that are filled automatically at compilation should be initialized here.
        This will typically mean the ASM list.
        Concrete subclasses will extend this method to add more data structures.
        This should be called at class initialization and before compilation.
        """
        logger.debug("init_instructions")
        # Timestamps, for keeping track of pulse and readout end times.
        self._gen_ts = [0]*len(self.soccfg['gens'])
        self._ro_ts = [0]*len(self.soccfg['readouts'])

        # binary program, ready to execute
        self.binprog = None

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

    @abstractmethod
    def compile(self):
        """Fills self.binprog with a binary representation of the program.
        """
        ...

    def dump_prog(self):
        """
        Dump the program to a dictionary.
        This output contains all the information necessary to run the program.
        In other words, it will have the low-level ASM and pulse+envelope data, but not higher-level structures.
        Caution: don't modify the sub-dictionaries of this dict!
        You will be modifying the original program (this is not a deep copy).
        """
        progdict = {}
        for key in self.dump_keys:
            progdict[key] = getattr(self, key)
        return progdict

    def load_prog(self, progdict):
        """
        Load the program from a dictionary.
        """
        for key in self.dump_keys:
            setattr(self, key, progdict[key])

        # tweak data structures that got screwed up by JSON:
        # in JSON, dict keys are always strings, so we must cast back to int
        self.gen_chs = OrderedDict([(int(k),v) for k,v in self.gen_chs.items()])
        self.ro_chs = OrderedDict([(int(k),v) for k,v in self.ro_chs.items()])
        # the envelope arrays need to be restored as numpy arrays with the proper type
        for iCh, envdict in enumerate(self.envelopes):
            for name, env in envdict['envs'].items():
                env['data'] = decode_array(env['data'])

    def config_all(self, soc, load_pulses=True, reset=False):
        """
        Load the waveform memory, gens, ROs, and program memory as specified for this program.
        The decimated+accumulated buffers are not configured, since those should be re-configured for each acquisition.
        The tProc is set to internal start before any other configuration is done, to prevent spurious external starts.

        Parameters
        ----------
        reset : bool
            Force-stop the tProc before loading the program.
            This option only affects tProc v1, where the reset takes several ms.
            For tProc v2, where reset is easy, we always do the reset.
        """
        # compile() first, because envelopes might be declared in a make_program() inside _make_asm()
        if self.binprog is None:
            self.compile()

        # set tproc to internal-start, to prevent spurious starts
        soc.start_src("internal")

        # now stop the tproc (if the tproc supports it)
        soc.stop_tproc(lazy=not reset)

        # Load the pulses from the program into the soc
        if load_pulses:
            self.load_pulses(soc)

        # Configure signal generators
        self.config_gens(soc)

        # Configure the readout down converters
        self.config_readouts(soc)

        # Load the program into the tProc
        soc.load_bin_program(self.binprog)

    def run(self, soc, load_prog=True, load_pulses=True, start_src="internal"):
        """Load the program into the tProcessor and start it.
        Because there is in general no way to tell when a program is done running, there is no guarantee that the program will be done before this method returns.
        If you want that guarantee, use run_rounds().

        Parameters
        ----------
        soc : QickSoc
            The QickSoc that will execute this program.
        load_prog : bool
            Load the program before starting the tProc.
        load_pulses : bool
            Load the generator envelopes before starting the tProc.
            If load_prog is False, load_pulses is ignored.
        start_src: str
            "internal" (tProc starts immediately) or "external" (each round waits for an external trigger).
        """
        if load_prog:
            self.config_all(soc, load_pulses=load_pulses)
        # configure tproc for internal/external start
        soc.start_src(start_src)
        # run the assembly program
        # if start_src="external", it won't actually start until it sees a pulse
        soc.start_tproc()

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

    def declare_gen(self, ch, nqz=1, mixer_freq=None, mux_freqs=None, mux_gains=None, mux_phases=None, ro_ch=None):
        """Add a channel to the program's list of signal generators.

        If this is a generator with a mixer (interpolated or muxed generator), you may define a mixer frequency.

        If this is a muxed generator, the mux_freqs list must be long enough to define all the tones you will play.
        (in other words, if your mask list ever enables tone 2 you must define at least 3 freqs+gains)
        If your mux gen supports gains and/or phases and you define them, those lists must be the same length.
        If you don't define gains or phases, they will be set to defaults (max positive gain, zero phase).

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
        mux_phases : list of float, optional
            Phases for the muxed generator (in degrees).
        ro_ch : int, optional
            readout channel for frequency-matching mixer and mux freqs
        """
        cfg = {
                'nqz': nqz,
                'ro_ch': ro_ch
                }
        gencfg = self.soccfg['gens'][ch]
        if gencfg['has_mixer']:
            if mixer_freq is None:
                raise RuntimeError("generator %d has a digital mixer, but no mixer_freq was defined" % (ch))
            cfg['mixer_freq'] = self.soccfg.calc_mixer_freq(ch, mixer_freq, nqz, ro_ch)
        else:
            if mixer_freq is not None:
                logger.warning("generator %d doesn't have a digital mixer, but mixer_freq was defined" % (ch))
        if 'n_tones' in gencfg:
            if mux_freqs is None:
                raise RuntimeError("generator %d is multiplexed, but no mux_freqs were defined" % (ch))
            if mux_gains is not None and not gencfg['has_gain']:
                logger.warning("generator %d doesn't support gain config, but mux_gains was defined" % (ch))
            if mux_phases is not None and not gencfg['has_phase']:
                logger.warning("generator %d doesn't support phase config, but mux_phases was defined" % (ch))
            cfg['mux_tones'] = self.soccfg.calc_mux_regs(ch, mux_freqs, mux_gains, mux_phases, ro_ch)
        else:
            if any([x is not None for x in [mux_freqs, mux_gains, mux_phases]]):
                logger.warning("generator %d is not multiplexed, but mux parameters were defined" % (ch))
        if ro_ch is not None and not gencfg['has_mixer'] and 'n_tones' not in gencfg:
            logger.warning("ro_ch was defined for generator %d, but it's not multiplexed and doesn't have a mixer, so it will do nothing" % (ch))

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
            if 'mixer_freq' in cfg:
                soc.set_mixer_freq(ch, cfg['mixer_freq']['setval'])
            if 'mux_tones' in cfg:
                soc.set_mux_tones(ch, cfg['mux_tones'])

    def add_envelope(self, ch, name, idata=None, qdata=None):
        """Adds a waveform to the list of envelope waveforms available for this channel.
        The I and Q arrays must be of equal length, and the length must be divisible by the samples-per-clock of this generator.

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
        gencfg = self.soccfg['gens'][ch]

        length = [len(d) for d in [idata, qdata] if d is not None]
        if len(length)==0:
            raise RuntimeError("Error: no data argument was supplied")
        # if both arrays were defined, they must be the same length
        if len(length)>1 and length[0]!=length[1]:
            raise RuntimeError("Error: I and Q envelope lengths must be equal")
        length = length[0]

        if (length % gencfg['samps_per_clk']) != 0:
            raise RuntimeError("Error: envelope lengths must be an integer multiple of %d"%(gencfg['samps_per_clk']))
        # currently, all gens with envelopes use int16 for I and Q
        data = np.zeros((length, 2), dtype=np.int16)

        for i, d in enumerate([idata, qdata]):
            if d is not None:
                # range check
                if np.max(np.abs(d)) > gencfg['maxv']:
                    raise ValueError("max abs val of envelope (%d) exceeds limit (%d)" % (np.max(np.abs(d)), gencfg['maxv']))
                # copy data
                data[:,i] = np.round(d)

        self.envelopes[ch]['envs'][name] = {"data": data, "addr": self.envelopes[ch]['next_addr']}
        self.envelopes[ch]['next_addr'] += length

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
            for name, pulse in pulses['envs'].items():
                soc.load_pulse_data(iCh,
                        data=pulse['data'],
                        addr=pulse['addr'])

    def reset_timestamps(self, gen_t0=None):
        # used by init and sync_all()
        self._gen_ts = [0]*len(self._gen_ts) if gen_t0 is None else gen_t0.copy()
        self._ro_ts = [0]*len(self._ro_ts)

    def decrement_timestamps(self, t):
        # used by sync() in v2
        self._gen_ts = [max(0, x-t) for x in self._gen_ts]
        self._ro_ts = [max(0, x-t) for x in self._ro_ts]

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

class AcquireMixin:
    """Adds acquire() and acquire_decimated() methods for acquiring readout data, and run_rounds() for running repeatedly without acquisition.
    Program classes that use this mixin must call setup_acquire() after _init_prog() and before acquire()/acquire_decimated().
    """
    def __init__(self, *args, **kwargs):
        # pass through any init arguments
        super().__init__(*args, **kwargs)

        # Attributes to dump when saving the program to JSON.
        self.dump_keys += ['counter_addr', 'reads_per_shot', 'loop_dims', 'avg_level']

        # measurements from the most recent acquisition
        # raw I/Q data without normalizing to window length or averaging over reps
        self.d_buf = None
        # shot-by-shot threshold classification
        self.shots = None

    def _init_declarations(self):
        super()._init_declarations()

        # tProc address of the rep counter, must be defined
        self.counter_addr = None

        # data dimensions, must be defined:
        # number of times each readout is triggered in a single shot
        self.reads_per_shot = None
        # list of loop dimensions, outermost loop first
        self.loop_dims = None
        # which loop level to average over (0 is outermost)
        self.avg_level = None

    def setup_counter(self, counter_addr, loop_dims):
        """Set the parameters needed to track the progress of the program.
        This is a subset of setup_acquire(), appropriate for programs where you have no readouts.
        You should use this if you're updating a tProc counter and want to use it to track program progress.

        Parameters
        ----------
        counter_addr : int
            The special tProc address holding the number of shots read out thus far.
        loop_dims : list of int
            List of loop dimensions, outermost loop first.
        """
        self.counter_addr = counter_addr
        self.loop_dims = loop_dims

    def setup_acquire(self, counter_addr, loop_dims, avg_level):
        """Set the parameters needed to define the data acquisition.
        Since the number of readouts per shot is set based on calls to trigger(), this should be called after the program has been fully defined.

        Parameters
        ----------
        counter_addr : int
            The special tProc address holding the number of shots read out thus far.
        loop_dims : list of int
            List of loop dimensions, outermost loop first.
        avg_level : int
            Which loop level to average over (0 is outermost).
        """
        # this doesn't work unless trigger macros have been processed, so compile if we haven't already compiled
        if self.binprog is None:
            self.compile()
        self.setup_counter(counter_addr, loop_dims)
        self.avg_level = avg_level
        self.reads_per_shot = [ro['trigs'] for ro in self.ro_chs.values()]

    def set_reads_per_shot(self, reads_per_shot):
        """Override the default count of readout triggers per shot.
        This should be called after setup_acquire().
        You probably shouldn't be using this method; the default value is usually correct.

        Parameters
        ----------
        reads_per_shot : int or list of int
            Number of readout triggers per shot.
            If int, all declared readout channels use this value.
        """
        try:
            self.reads_per_shot = [int(reads_per_shot)]*len(self.ro_chs)
        except TypeError:
            self.reads_per_shot = reads_per_shot

    def get_raw(self):
        """Get the raw integer I/Q values (before normalizing to the readout window, averaging across reps, removing the readout offset, or thresholding).

        Returns
        -------
        list of ndarray
            Array of I/Q values for each readout channel.
        """
        return self.d_buf

    def get_shots(self):
        """Get the shot-by-shot threshold decisions.

        Returns
        -------
        list of ndarray
            Array of shots for each readout channel.
        """
        return self.shots

    def acquire(self, soc, soft_avgs=1, load_pulses=True, start_src="internal", threshold=None, angle=None, progress=True, remove_offset=True):
        """Acquire data using the accumulated readout.

        Parameters
        ----------
        soc : QickSoc
            Qick object
        soft_avgs : int
            number of times to rerun the program, averaging results in software (aka "rounds")
        load_pulses : bool
            if True, load pulse envelopes
        start_src: str
            "internal" (tProc starts immediately) or "external" (each round waits for an external trigger)
        threshold : float or list of float
            The threshold(s) to apply to the I values after rotation.
            Length-normalized units (same units as the output of acquire()).
            If scalar, the same threshold will be applied to all readout channels.
            A list must have length equal to the number of declared readout channels.
        angle : float or list of float
            The angle to rotate the I/Q values by before applying the threshold.
            Units of radians.
            If scalar, the same angle will be applied to all readout channels.
            A list must have length equal to the number of declared readout channels.
        progress: bool
            if true, displays progress bar
        remove_offset: bool
            Some readouts (muxed and tProc-configured) introduce a small fixed offset to the I and Q values of every decimated sample.
            This subtracts that offset, if any, before returning the averaged IQ values or rotating to apply software thresholding.

        Returns
        -------
        ndarray
            averaged IQ values (float)
            divided by the length of the RO window, and averaged over reps and rounds
            if threshold is defined, the I values will be the fraction of points over threshold
            dimensions for a simple averaging program: (n_ch, n_reads, 2)
            dimensions for a program with multiple expts/steps: (n_ch, n_reads, n_expts, 2)
        """
        self.config_all(soc, load_pulses=load_pulses)

        if any([x is None for x in [self.counter_addr, self.loop_dims, self.avg_level]]):
            raise RuntimeError("data dimensions need to be defined with setup_acquire() before calling acquire()")

        # configure tproc for internal/external start
        soc.start_src(start_src)

        n_ro = len(self.ro_chs)

        total_count = functools.reduce(operator.mul, self.loop_dims)
        self.d_buf = [np.zeros((*self.loop_dims, nreads, 2), dtype=np.int32) for nreads in self.reads_per_shot]
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
        for ir in tqdm(range(soft_avgs), disable=hiderounds):
            # Configure and enable buffer capture.
            self.config_bufs(soc, enable_avg=True, enable_buf=False)

            count = 0
            with tqdm(total=total_count, disable=hidereps) as pbar:
                soc.start_readout(total_count, counter_addr=self.counter_addr,
                                       ch_list=list(self.ro_chs), reads_per_shot=self.reads_per_shot)
                while count<total_count:
                    new_data = obtain(soc.poll_data())
                    for new_points, (d, s) in new_data:
                        for ii, nreads in enumerate(self.reads_per_shot):
                            # use reshape to view the d_buf array in a shape that matches the raw data
                            self.d_buf[ii].reshape((-1,2))[count*nreads:(count+new_points)*nreads] = d[ii]
                        count += new_points
                        self.stats.append(s)
                        pbar.update(new_points)

            # if we're thresholding, apply the threshold before averaging
            if threshold is None:
                d_reps = self.d_buf
                round_d = self._average_buf(d_reps, self.reads_per_shot, length_norm=True, remove_offset=remove_offset)
            else:
                d_reps = [np.zeros_like(d) for d in self.d_buf]
                self.shots = self._apply_threshold(self.d_buf, threshold, angle, remove_offset=remove_offset)
                for i, ch_shot in enumerate(self.shots):
                    d_reps[i][...,0] = ch_shot
                round_d = self._average_buf(d_reps, self.reads_per_shot, length_norm=False)

            # sum over rounds axis
            if avg_d is None:
                avg_d = round_d
            else:
                for ii, d in enumerate(round_d): avg_d[ii] += d

        # divide total by rounds
        for d in avg_d: d /= soft_avgs

        return avg_d

    def _average_buf(self, d_reps: np.ndarray, reads_per_shot: list, length_norm: bool=True, remove_offset: bool=True) -> np.ndarray:
        """
        calculate averaged data in a data acquire round. This function should be overwritten in the child qick program
        if the data is created in a different shape.

        :param d_reps: buffer data acquired in a round
        :param reads_per_shot: readouts per experiment
        :param length_norm: normalize by readout window length (disable for thresholded values)
        :param remove_offset: if normalizing by length, also subtract the readout's IQ offset if any
        :return: averaged iq data after each round.
        """
        avg_d = []
        for i_ch, (ro_ch, ro) in enumerate(self.ro_chs.items()):
            # average over the avg_level
            avg = d_reps[i_ch].sum(axis=self.avg_level) / self.loop_dims[self.avg_level]
            if length_norm:
                avg /= ro['length']
                if remove_offset:
                    offset = self.soccfg['readouts'][ro_ch]['iq_offset']
                    avg -= offset
            # the reads_per_shot axis should be the first one
            avg_d.append(np.moveaxis(avg, -2, 0))

        return avg_d

    def _apply_threshold(self, d_buf, threshold, angle, remove_offset):
        """
        This method converts the raw I/Q data to single shots according to the threshold and rotation angle

        Parameters
        ----------
        d_buf : list of ndarray
            Raw IQ data
        threshold : float or list of float
            The threshold(s) to apply to the I values after rotation.
            Length-normalized units (same units as the output of acquire()).
            If scalar, the same threshold will be applied to all readout channels.
            A list must have length equal to the number of declared readout channels.
        angle : float or list of float
            The angle to rotate the I/Q values by before applying the threshold.
            Units of radians.
            If scalar, the same angle will be applied to all readout channels.
            A list must have length equal to the number of declared readout channels.
        remove_offset: bool
            Subtract the readout's IQ offset, if any.

        Returns
        -------
        list of ndarray
            Single shot data

        """
        # try to convert threshold to list of floats; if that fails, assume it's already a list
        try:
            thresholds = [float(threshold)]*len(self.ro_chs)
        except TypeError:
            thresholds = threshold
        # angle is 0 if not specified
        if angle is None: angle = 0.0
        try:
            angles = [float(angle)]*len(self.ro_chs)
        except TypeError:
            angles = angle

        shots = []
        for i_ch, (ro_ch, ro) in enumerate(self.ro_chs.items()):
            avg = d_buf[i_ch]/ro['length']
            if remove_offset:
                offset = self.soccfg['readouts'][ro_ch]['iq_offset']
                avg -= offset
            rotated = np.inner(avg, [np.cos(angles[i_ch]), np.sin(angles[i_ch])])
            shots.append(np.heaviside(rotated - thresholds[i_ch], 0))
        return shots

    def get_time_axis(self, ro_index):
        """Get an array usable as the time axis for plotting decimated data.

        Parameters
        ----------
        ro_index : int
            Index of the readout channel in this program.
            The first readout declared in your program has index 0 and it will have index 0 in the output array, etc.

        Returns
        -------
        ndarray of float
            An array starting at 0 and spaced by the time (in us) per decimated sample.
        """
        ch, ro = list(self.ro_chs.items())[ro_index]
        return self.soccfg.cycles2us(ro_ch=ch, cycles=np.arange(ro['length']))

    def get_time_axis_ddr4(self, ro_ch, data):
        """Get an array usable as the time axis for plotting DDR4 data.

        Parameters
        ----------
        ro_ch : int
            readout channel (index in 'readouts' list)
        data : ndarray
            DDR4 data array, the returned array will have the same length.

        Returns
        -------
        ndarray of float
            An array starting at 0 and spaced by the time (in us) per decimated sample.
        """
        return self.soccfg.cycles2us(ro_ch=ro_ch, cycles=np.arange(data.shape[0]))

    def get_time_axis_mr(self, ro_ch, data):
        """Get an array usable as the time axis for plotting MR data.

        Parameters
        ----------
        ro_ch : int
            readout channel (index in 'readouts' list)
        data : ndarray
            MR data array, the returned array will have the same length.

        Returns
        -------
        ndarray of float
            An array starting at 0 and spaced by the time (in us) per MR sample.
        """
        return np.arange(data.shape[0])/self.soccfg['readouts'][ro_ch]['fs']

    def run_rounds(self, soc, rounds=1, load_pulses=True, start_src="internal", progress=True):
        """Run the program and wait until it completes, once or multiple times.
        No data will be saved.

        Parameters
        ----------
        soc : QickSoc
            Qick object
        rounds : int
            number of times to rerun the program
        load_pulses : bool
            if True, load pulse envelopes
        start_src: str
            "internal" (tProc starts immediately) or "external" (each round waits for an external trigger)
        progress: bool
            if true, displays progress bar
        """
        self.config_all(soc, load_pulses=load_pulses)

        if any([x is None for x in [self.counter_addr, self.loop_dims]]):
            raise RuntimeError("data dimensions need to be defined with setup_acquire() before calling run_rounds()")

        # configure tproc for internal/external start
        soc.start_src(start_src)

        total_count = functools.reduce(operator.mul, self.loop_dims)

        # select which tqdm progress bar to show
        hiderounds = True
        hidereps = True
        if progress:
            if rounds>1:
                hiderounds = False
            else:
                hidereps = False

        # run each round
        for ii in tqdm(range(rounds), disable=hiderounds):
            # make sure count variable is reset to 0
            soc.set_tproc_counter(addr=self.counter_addr, val=0)

            # run the assembly program
            # if start_src="external", you must pulse the trigger input once for every round
            soc.start_tproc()

            count = 0
            with tqdm(total=total_count, disable=hidereps) as pbar:
                while count < total_count:
                    newcount = soc.get_tproc_counter(addr=self.counter_addr)
                    pbar.update(newcount-count)
                    count = newcount

    def acquire_decimated(self, soc, soft_avgs, load_pulses=True, start_src="internal", progress=True, remove_offset=True):
        """Acquire data using the decimating readout.

        Parameters
        ----------
        soc : QickSoc
            Qick object
        soft_avgs : int
            number of times to rerun the program, averaging results in software (aka "rounds")
        load_pulses : bool
            if True, load pulse envelopes
        start_src: str
            "internal" (tProc starts immediately) or "external" (each round waits for an external trigger)
        progress: bool
            if true, displays progress bar
        remove_offset: bool
            Subtract the readout's IQ offset, if any.

        Returns
        -------
        list of ndarray
            decimated values, averaged over rounds (float)
            dimensions for a single-rep, single-read program : (length, 2)
            multi-rep or multi-read: (n_reps*n_reads, length, 2)
            multi-rep and multi-read: (n_reps, n_reads, length, 2)
        """
        self.config_all(soc, load_pulses=load_pulses)

        if any([x is None for x in [self.counter_addr, self.loop_dims, self.avg_level]]):
            raise RuntimeError("data dimensions need to be defined with setup_acquire() before calling acquire_decimated()")

        # configure tproc for internal/external start
        soc.start_src(start_src)

        total_count = functools.reduce(operator.mul, self.loop_dims)

        # Initialize data buffers
        # buffer for decimated data
        dec_buf = []
        for ch, ro in self.ro_chs.items():
            maxlen = self.soccfg['readouts'][ch]['buf_maxlen']
            if ro['length']*ro['trigs']*total_count > maxlen:
                raise RuntimeError("Warning: requested readout length (%d x %d trigs x %d reps) exceeds buffer size (%d)"%(ro['length'], ro['trigs'], total_count, maxlen))
            dec_buf.append(np.zeros((ro['length']*total_count*ro['trigs'], 2), dtype=float))

        # for each soft average, run and acquire decimated data
        for ii in tqdm(range(soft_avgs), disable=not progress):
            # buffer for accumulated data (for convenience/debug)
            self.d_buf = []

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
                dec_buf[ii] += obtain(soc.get_decimated(ch=ch,
                                    address=0, length=ro['length']*ro['trigs']*total_count))
                self.d_buf.append(obtain(soc.get_accumulated(ch=ch, address=0, length=ro['trigs']*total_count).reshape((*self.loop_dims, ro['trigs'], 2))))

        onetrig = all([ro['trigs']==1 for ro in self.ro_chs.values()])

        # average the decimated data
        result = []
        for ii, (ch, ro) in enumerate(self.ro_chs.items()):
            d_avg = dec_buf[ii]/soft_avgs
            if remove_offset:
                offset = self.soccfg['readouts'][ch]['iq_offset']
                d_avg -= offset
            if total_count == 1 and onetrig:
                # simple case: data is 1D (one rep and one shot), just average over rounds
                result.append(d_avg)
            else:
                # split the data into the individual reps
                if onetrig or total_count==1:
                    d_reshaped = d_avg.reshape(total_count*ro['trigs'], -1, 2)
                else:
                    d_reshaped = d_avg.reshape(total_count, ro['trigs'], -1, 2)
                result.append(d_reshaped)
        return result
