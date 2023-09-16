"""
The higher-level driver for the QICK library. Contains an tProc assembly language wrapper class and auxiliary functions.
"""
import logging
from typing import Union, List
import numpy as np
import json
from collections import namedtuple, OrderedDict, defaultdict
from abc import ABC, abstractmethod
from tqdm.auto import tqdm

from qick import obtain, get_version
from .helpers import gauss, triang, DRAG, NpEncoder, ch2list
from .parser import parse_prog

RegisterType = ["freq", "time", "phase", "adc_freq"]
DefaultUnits = {"freq": "MHz", "time": "us", "phase": "deg", "adc_freq": "MHz"}
MathOperators = ["+", "-", "*"]
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
            lines.append("\t\tADC tile %s, blk %s, %d-bit DDS, fabric=%.3f MHz, fs=%.3f MHz" %
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

    def calc_fstep(self, dict1, dict2):
        """Finds the least common multiple of the frequency steps of two channels (typically a generator and readout)

        Parameters
        ----------
        dict1 : dict
            config dict for one channel
        dict2 : dict
            config dict for the other channel

        Returns
        -------
        float
            frequency step common to the two channels

        """
        refclk = self['refclk_freq']
        # Calculate least common multiple of sampling frequencies.

        # clock multipliers from refclk to DAC/ADC - always integer
        fsmult1 = round(dict1['f_dds']/refclk)
        fsmult2 = round(dict2['f_dds']/refclk)

        # Calculate a common fstep_lcm, which is divisible by both step sizes of both channels.
        # We should only use frequencies that are evenly divisible by fstep_lcm.
        b_max = max(dict1['b_dds'], dict2['b_dds'])
        mult_lcm = np.lcm(fsmult1 * 2**(b_max - dict1['b_dds']),
                          fsmult2 * 2**(b_max - dict2['b_dds']))
        return refclk * mult_lcm / 2**b_max

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
            f_round = f
        else:
            f_round = self.roundfreq(f, thisch, otherch)
        k_i = np.round(f_round*(2**thisch['b_dds'])/thisch['f_dds'])
        return np.int64(k_i)

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
        return int(deg*2**b_phase//360) % 2**b_phase

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
        return np.int64(np.round(obtain(us)*fclk))

class AbsRegisterManager(ABC):
    """Generic class for managing registers that will be written to a tProc-controlled block (signal generator or readout).
    """
    def __init__(self, prog, tproc_ch, ch_name):
        self.prog = prog
        # the tProc output channel controlled by this manager
        self.tproc_ch = tproc_ch
        # the name of this block (for messages)
        self.ch_name = ch_name
        # the register page used by this manager
        self.rp = prog._ch_page_tproc(tproc_ch)
        # default parameters
        self.defaults = {}
        # registers that are fully defined by the default parameters
        self.default_regs = set()
        # the registers to be used in the next "set" command
        self.next_pulse = None
        # registers values used in the last set_registers() call
        self.last_set_regs = {}

    def set_reg(self, name, val, comment=None, defaults=False):
        """Wrapper around regwi.
        Looks up the register name and keeps track of whether the register already has a default value.

        Parameters
        ----------
        name : str
            Register name
        val : int
            Register value
        comment : str
            Comment to be printed in ASM output
        defaults : bool
            This is a default value, which doesn't need to be rewritten for every pulse

        """
        if defaults:
            self.default_regs.add(name)
        elif name in self.default_regs:
            # this reg was already written, so we skip it this time
            return
        r = self.prog._sreg_tproc(self.tproc_ch, name)
        if comment is None: comment = f'{name} = {val}'
        self.prog.safe_regwi(self.rp, r, val, comment)

    def set_defaults(self, kwargs):
        """Set default values for parameters.
        This is called by QickProgram.set_default_registers().

        Parameters
        ----------
        kwargs : dict
            Parameter values

        """
        if self.defaults:
            # complain if the default parameter dict is not empty
            raise RuntimeError("%s already has a set of default parameters"%(self.ch_name))
        self.defaults = kwargs
        self.write_regs(kwargs, defaults=True)

    def set_registers(self, kwargs):
        """Set pulse parameters.
        This is called by QickProgram.set_pulse_registers().

        Parameters
        ----------
        kwargs : dict
            Parameter values

        """
        self.last_set_regs = kwargs
        if not self.defaults.keys().isdisjoint(kwargs):
            raise RuntimeError("these params were set for {0} both in default_pulse_registers and set_pulse_registers: {1}".format(self.ch_name, self.defaults.keys() & kwargs.keys()))
        merged = {**self.defaults, **kwargs}
        # check the final param set for validity
        self.check_params(merged)
        self.write_regs(merged, defaults=False)

    @abstractmethod
    def check_params(self, params):
        ...

    @abstractmethod
    def write_regs(self, params, defaults):
        ...

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


class ReadoutManager(AbsRegisterManager):
    """Manages the frequency and mode registers for a tProc-controlled readout channel.
    """
    PARAMS_REQUIRED = ['freq', 'length']
    PARAMS_OPTIONAL = ['phrst', 'mode', 'outsel']

    def __init__(self, prog, ro_ch):
        self.rocfg = prog.soccfg['readouts'][ro_ch]
        tproc_ch = self.rocfg['tproc_ctrl']
        super().__init__(prog, tproc_ch, "readout %d"%(ro_ch))

    def check_params(self, params):
        """Check whether the parameters defined for a pulse are supported and sufficient for this generator and pulse type.
        Raise an exception if there is a problem.

        Parameters
        ----------
        params : dict
            Parameter values

        """
        required = set(self.PARAMS_REQUIRED)
        allowed = required | set(self.PARAMS_OPTIONAL)
        defined = params.keys()
        if required - defined:
            raise RuntimeError("missing required pulse parameter(s)", required - defined)
        if defined - allowed:
            raise RuntimeError("unsupported pulse parameter(s)", defined - allowed)

    def write_regs(self, params, defaults):
        if 'freq' in params:
            self.set_reg('freq', params['freq'], defaults=defaults)
        if not defaults:
            self.next_pulse = {}
            self.next_pulse['rp'] = self.rp
            self.next_pulse['regs'] = []

            # these mode bits could be defined, or left as None
            phrst, mode, outsel = [params.get(x) for x in ['phrst', 'mode', 'outsel']]
            mc = self.get_mode_code(phrst=phrst, mode=mode, outsel=outsel, length=params['length'])
            self.set_reg('mode', mc, f'mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
            self.next_pulse['regs'].append([self.prog._sreg_tproc(self.tproc_ch,x) for x in ['freq', '0', 'mode', '0', '0']])

    def get_mode_code(self, length, outsel=None, mode=None, phrst=None):
        """Creates mode code for the mode register in the set command, by setting flags and adding the pulse length.

        Parameters
        ----------
        length : int
            The number of ADC fabric cycles in the pulse

        outsel : str
            Selects the output source. The output is complex. Tables define envelopes for I and Q.
            The default is "product".

            * If "product", the output is the product of table and DDS.

            * If "dds", the output is the DDS only.

            * If "input", the output is from the table for the real part, and zeros for the imaginary part.

            * If "zero", the output is always zero.

        mode : str
            Selects whether the output is "oneshot" or "periodic". The default is "oneshot".

        phrst : int
            If 1, it resets the phase coherent accumulator. The default is 0.

        Returns
        -------
        int
            Compiled mode code in binary

        """
        if length >= 2**16 or length < 3:
            raise RuntimeError("Pulse length of %d is out of range (exceeds 16 bits, or less than 3) - use multiple pulses, or zero-pad the waveform" % (length))
        if outsel is None: outsel = "product"
        if mode is None: mode = "oneshot"
        if phrst is None: phrst = 0

        outsel_reg = {"product": 0, "dds": 1, "input": 2, "zero": 3}[outsel]
        mode_reg = {"oneshot": 0, "periodic": 1}[mode]
        mc = phrst*0b01000+mode_reg*0b00100+outsel_reg
        return mc << 16 | np.uint16(length)


class AbsGenManager(AbsRegisterManager):
    """Manages the envelope and pulse information for a signal generator channel.
    """
    PARAMS_REQUIRED = {}
    PARAMS_OPTIONAL = {}

    def __init__(self, prog, gen_ch):
        self.gencfg = prog.soccfg['gens'][gen_ch]
        tproc_ch = self.gencfg['tproc_ch']
        super().__init__(prog, tproc_ch, "generator %d"%(gen_ch))
        self.samps_per_clk = self.gencfg['samps_per_clk']

        # dictionary of defined pulse envelopes
        self.pulses = prog.pulses[gen_ch]
        # type and max absolute value for envelopes
        self.env_dtype = np.int16

        self.addr = 0

    def check_params(self, params):
        """Check whether the parameters defined for a pulse are supported and sufficient for this generator and pulse type.
        Raise an exception if there is a problem.

        Parameters
        ----------
        params : dict
            Parameter values

        """
        style = params['style']
        required = set(self.PARAMS_REQUIRED[style])
        allowed = required | set(self.PARAMS_OPTIONAL[style])
        defined = params.keys()
        if required - defined:
            raise RuntimeError("missing required pulse parameter(s)", required - defined)
        if defined - allowed:
            raise RuntimeError("unsupported pulse parameter(s)", defined - allowed)

    def add_pulse(self, name, idata, qdata):
        """Add a waveform to the list of envelope waveforms available for this channel.
        The I and Q arrays must be of equal length, and the length must be divisible by the samples-per-clock of this generator.

        Parameters
        ----------
        name : str
            Name for this waveform
        idata : array
            I values for this waveform
        qdata : array
            Q values for this waveform

        """
        length = [len(d) for d in [idata, qdata] if d is not None]
        if len(length)==0:
            raise RuntimeError("Error: no data argument was supplied")
        # if both arrays were defined, they must be the same length
        if len(length)>1 and length[0]!=length[1]:
            raise RuntimeError("Error: I and Q pulse lengths must be equal")
        length = length[0]

        if (length % self.samps_per_clk) != 0:
            raise RuntimeError("Error: pulse lengths must be an integer multiple of %d"%(self.samps_per_clk))
        data = np.zeros((length, 2), dtype=self.env_dtype)

        for i, d in enumerate([idata, qdata]):
            if d is not None:
                # range check
                if np.max(np.abs(d)) > self.gencfg['maxv']:
                    raise ValueError("max abs val of envelope (%d) exceeds limit (%d)" % (np.max(np.abs(d)), self.gencfg['maxv']))
                # copy data
                data[:,i] = np.round(d)

        self.pulses[name] = {"data": data, "addr": self.addr}
        self.addr += length

    def get_mode_code(self, length, mode=None, outsel=None, stdysel=None, phrst=None):
        """Creates mode code for the mode register in the set command, by setting flags and adding the pulse length.

        Parameters
        ----------
        length : int
            The number of DAC fabric cycles in the pulse
        mode : str
            Selects whether the output is "oneshot" or "periodic". The default is "oneshot".
        outsel : str
            Selects the output source. The output is complex. Tables define envelopes for I and Q.
            The default is "product".

            * If "product", the output is the product of table and DDS. 

            * If "dds", the output is the DDS only. 

            * If "input", the output is from the table for the real part, and zeros for the imaginary part. 
            
            * If "zero", the output is always zero.

        stdysel : str
            Selects what value is output continuously by the signal generator after the generation of a pulse.
            The default is "zero".

            * If "last", it is the last calculated sample of the pulse.

            * If "zero", it is a zero value.

        phrst : int
            If 1, it resets the phase coherent accumulator. The default is 0.

        Returns
        -------
        int
            Compiled mode code in binary

        """
        if mode is None: mode = "oneshot"
        if outsel is None: outsel = "product"
        if stdysel is None: stdysel = "zero"
        if phrst is None: phrst = 0
        if length >= 2**16 or length < 3:
            raise RuntimeError("Pulse length of %d is out of range (exceeds 16 bits, or less than 3) - use multiple pulses, or zero-pad the waveform" % (length))
        stdysel_reg = {"last": 0, "zero": 1}[stdysel]
        mode_reg = {"oneshot": 0, "periodic": 1}[mode]
        outsel_reg = {"product": 0, "dds": 1, "input": 2, "zero": 3}[outsel]
        mc = phrst*0b10000+stdysel_reg*0b01000+mode_reg*0b00100+outsel_reg
        return mc << 16 | np.uint16(length)

class FullSpeedGenManager(AbsGenManager):
    """Manager for the full-speed (non-interpolated, non-muxed) signal generators.
    """
    PARAMS_REQUIRED = {'const': ['style', 'freq', 'phase', 'gain', 'length'],
            'arb': ['style', 'freq', 'phase', 'gain', 'waveform'],
            'flat_top': ['style', 'freq', 'phase', 'gain', 'length', 'waveform']}
    PARAMS_OPTIONAL = {'const': ['phrst', 'stdysel', 'mode'],
            'arb': ['phrst', 'stdysel', 'mode', 'outsel'],
            'flat_top': ['phrst', 'stdysel']}

    def write_regs(self, params, defaults):
        """Write whichever pulse registers are fully determined by the defined parameters.

        The following pulse styles are supported:

        * const: A constant (rectangular) pulse.
          There is no outsel setting for this pulse style; "dds" is always used.

        * arb: An arbitrary-envelope pulse.

        * flat_top: A flattop pulse with arbitrary ramps.
          The waveform is played in three segments: ramp up, flat, and ramp down.
          To use these pulses one should use add_pulse to add the ramp waveform which should go from 0 to maxamp and back down to zero with the up and down having the same length, the first half will be used as the ramp up and the second half will be used as the ramp down.

          If the waveform is not of even length, the middle sample will be skipped.
          It's recommended to use an even-length waveform with flat_top.

          There is no outsel setting for flat_top; the ramps always use "product" and the flat segment always uses "dds".
          There is no mode setting; it is always "oneshot".

        Parameters
        ----------
        params : dict
            Pulse parameters
        defaults :
            These are default values, which don't need to be rewritten for every pulse

        """
        for parname in ['freq', 'phase', 'gain']:
            if parname in params:
                self.set_reg(parname, params[parname], defaults=defaults)
        if 'waveform' in params:
            pinfo = self.pulses[params['waveform']]
            wfm_length = pinfo['data'].shape[0] // self.samps_per_clk
            addr = pinfo['addr'] // self.samps_per_clk
            self.set_reg('addr', addr, defaults=defaults)
        if not defaults:
            style = params['style']
            # these mode bits could be defined, or left as None
            phrst, stdysel, mode, outsel = [params.get(x) for x in ['phrst', 'stdysel', 'mode', 'outsel']]

            self.next_pulse = {}
            self.next_pulse['rp'] = self.rp
            self.next_pulse['regs'] = []
            if style=='const':
                mc = self.get_mode_code(phrst=phrst, stdysel=stdysel, mode=mode, outsel="dds", length=params['length'])
                self.set_reg('mode', mc, f'phrst| stdysel | mode | | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
                self.next_pulse['regs'].append([self.prog._sreg_tproc(self.tproc_ch,x) for x in ['freq', 'phase', '0', 'gain', 'mode']])
                self.next_pulse['length'] = params['length']
            elif style=='arb':
                mc = self.get_mode_code(phrst=phrst, stdysel=stdysel, mode=mode, outsel=outsel, length=wfm_length)
                self.set_reg('mode', mc, f'phrst| stdysel | mode | | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
                self.next_pulse['regs'].append([self.prog._sreg_tproc(self.tproc_ch,x) for x in ['freq', 'phase', 'addr', 'gain', 'mode']])
                self.next_pulse['length'] = wfm_length
            elif style=='flat_top':
                # address for ramp-down
                self.set_reg('addr2', addr+(wfm_length+1)//2)
                # gain for flat segment
                self.set_reg('gain2', params['gain']//2)
                # mode for ramp up
                mc = self.get_mode_code(phrst=phrst, stdysel=stdysel, mode='oneshot', outsel='product', length=wfm_length//2)
                self.set_reg('mode2', mc, f'phrst| stdysel | mode | | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
                # mode for flat segment
                mc = self.get_mode_code(phrst=False, stdysel=stdysel, mode='oneshot', outsel='dds', length=params['length'])
                self.set_reg('mode', mc, f'phrst| stdysel | mode | | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
                # mode for ramp down
                mc = self.get_mode_code(phrst=False, stdysel=stdysel, mode='oneshot', outsel='product', length=wfm_length//2)
                self.set_reg('mode3', mc, f'phrst| stdysel | mode | | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')

                self.next_pulse['regs'].append([self.prog._sreg_tproc(self.tproc_ch,x) for x in ['freq', 'phase', 'addr', 'gain', 'mode2']])
                self.next_pulse['regs'].append([self.prog._sreg_tproc(self.tproc_ch,x) for x in ['freq', 'phase', '0', 'gain2', 'mode']])
                self.next_pulse['regs'].append([self.prog._sreg_tproc(self.tproc_ch,x) for x in ['freq', 'phase', 'addr2', 'gain', 'mode3']])
                self.next_pulse['length'] = (wfm_length//2)*2 + params['length']


class InterpolatedGenManager(AbsGenManager):
    """Manager for the interpolated signal generators.
    """
    PARAMS_REQUIRED = {'const': ['style', 'freq', 'phase', 'gain', 'length'],
            'arb': ['style', 'freq', 'phase', 'gain', 'waveform'],
            'flat_top': ['style', 'freq', 'phase', 'gain', 'length', 'waveform']}
    PARAMS_OPTIONAL = {'const': ['phrst', 'stdysel', 'mode'],
            'arb': ['phrst', 'stdysel', 'mode', 'outsel'],
            'flat_top': ['phrst', 'stdysel']}

    def write_regs(self, params, defaults):
        """Write whichever pulse registers are fully determined by the defined parameters.

        The following pulse styles are supported:

        * const: A constant (rectangular) pulse.
          There is no outsel setting for this pulse style; "dds" is always used.

        * arb: An arbitrary-envelope pulse.

        * flat_top: A flattop pulse with arbitrary ramps.
          The waveform is played in three segments: ramp up, flat, and ramp down.
          To use these pulses one should use add_pulse to add the ramp waveform which should go from 0 to maxamp and back down to zero with the up and down having the same length, the first half will be used as the ramp up and the second half will be used as the ramp down.

          If the waveform is not of even length, the middle sample will be skipped.
          It's recommended to use an even-length waveform with flat_top.

          There is no outsel setting for flat_top; the ramps always use "product" and the flat segment always uses "dds".
          There is no mode setting; it is always "oneshot".

        Parameters
        ----------
        params : dict
            Pulse parameters
        defaults :
            These are default values, which don't need to be rewritten for every pulse

        """
        addr = 0
        if 'waveform' in params:
            pinfo = self.pulses[params['waveform']]
            wfm_length = pinfo['data'].shape[0] // self.samps_per_clk
            addr = pinfo['addr'] // self.samps_per_clk
        if 'phase' in params and 'freq' in params:
            phase, freq = [params[x] for x in ['phase', 'freq']]
            self.set_reg('freq',  (phase << 16) | freq, f'phase = {phase} | freq = {freq}', defaults=defaults)
        if 'gain' in params and ('waveform' in params or params.get('style')=='const'):
            gain = params['gain']
            self.set_reg('addr',  (gain << 16) | addr, f'gain = {gain} | addr = {addr}', defaults=defaults)
        if not defaults:
            style = params['style']
            # these mode bits could be defined, or left as None
            phrst, stdysel, mode, outsel = [params.get(x) for x in ['phrst', 'stdysel', 'mode', 'outsel']]

            self.next_pulse = {}
            self.next_pulse['rp'] = self.rp
            self.next_pulse['regs'] = []
            if style=='const':
                mc = self.get_mode_code(phrst=phrst, stdysel=stdysel, mode=mode, outsel="dds", length=params['length'])
                self.set_reg('mode', mc, f'stdysel | mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
                self.next_pulse['regs'].append([self.prog._sreg_tproc(self.tproc_ch,x) for x in ['freq', 'addr', 'mode', '0', '0']])
                self.next_pulse['length'] = params['length']
            elif style=='arb':
                mc = self.get_mode_code(phrst=phrst, stdysel=stdysel, mode=mode, outsel=outsel, length=wfm_length)
                self.set_reg('mode', mc, f'stdysel | mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
                self.next_pulse['regs'].append([self.prog._sreg_tproc(self.tproc_ch,x) for x in ['freq', 'addr', 'mode', '0', '0']])
                self.next_pulse['length'] = wfm_length
            elif style=='flat_top':
                maxv_scale = self.gencfg['maxv_scale']
                gain, length = [params[x] for x in ['gain', 'length']]
                # mode for flat segment
                mc = self.get_mode_code(phrst=phrst, stdysel=stdysel, mode="oneshot", outsel="dds", length=params['length'])
                self.set_reg('mode', mc, f'stdysel | mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
                # mode for ramps
                mc = self.get_mode_code(phrst=phrst, stdysel=stdysel, mode="oneshot", outsel="product", length=wfm_length//2)
                self.set_reg('mode2', mc, f'stdysel | mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')

                # gain+addr for ramp-up
                self.set_reg('addr', (gain << 16) | addr, f'gain = {gain} | addr = {addr}')
                # gain+addr for flat
                self.set_reg('gain', (int(gain*maxv_scale/2) << 16), f'gain = {gain} | addr = {addr}')
                # gain+addr for ramp-down
                self.set_reg('addr2', (gain << 16) | addr+(wfm_length+1)//2, f'gain = {gain} | addr = {addr}')

                self.next_pulse['regs'].append([self.prog._sreg_tproc(self.tproc_ch,x) for x in ['freq', 'addr', 'mode2', '0', '0']])
                self.next_pulse['regs'].append([self.prog._sreg_tproc(self.tproc_ch,x) for x in ['freq', 'gain', 'mode', '0', '0']])
                self.next_pulse['regs'].append([self.prog._sreg_tproc(self.tproc_ch,x) for x in ['freq', 'addr2', 'mode2', '0', '0']])
                # workaround for FIR bug: we play a zero-gain DDS pulse (length equal to the flat segment) after the ramp-down, which brings the FIR to zero
                self.next_pulse['regs'].append([self.prog._sreg_tproc(self.tproc_ch,x) for x in ['0', '0', 'mode', '0', '0']])
                # set the pulse duration (including the extra duration for the FIR workaround)
                self.next_pulse['length'] = (wfm_length//2)*2 + 2*params['length']

class MultiplexedGenManager(AbsGenManager):
    """Manager for the muxed signal generators.
    """
    PARAMS_REQUIRED = {'const': ['style', 'mask', 'length']}
    PARAMS_OPTIONAL = {'const': []}

    def write_regs(self, params, defaults):
        """Write whichever pulse registers are fully determined by the defined parameters.

        Only the "const" pulse style, with the "mask" and "length" parameters, is supported.
        The frequency and gain are set at program initialization.

        Parameters
        ----------
        params : dict
            Pulse parameters
        defaults :
            These are default values, which don't need to be rewritten for every pulse

        """
        if 'length' in params:
            if params['length'] >= 2**32 or params['length'] < 3:
                raise RuntimeError("Pulse length of %d is out of range (exceeds 32 bits, or less than 3) - use multiple pulses" % (params['length']))
            self.set_reg('freq', params['length'], defaults=defaults)
        if 'mask' in params:
            val_mask = 0
            mask = params['mask']
            for maskch in mask:
                if maskch not in range(4):
                    raise RuntimeError("invalid mask specification")
                val_mask |= (1 << maskch)
            self.set_reg('phase', val_mask, f'mask = {mask}', defaults=defaults)
        if not defaults:
            style = params['style']

            self.next_pulse = {}
            self.next_pulse['rp'] = self.rp
            self.next_pulse['regs'] = []
            self.next_pulse['regs'].append([self.prog._sreg_tproc(self.tproc_ch,x) for x in ['freq', 'phase', '0', '0', '0']])
            self.next_pulse['length'] = params['length']

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
        self.pulses = [{} for ch in soccfg['gens']]
        # readout channels to configure before running the program
        self.ro_chs = OrderedDict()
        # signal generator channels to configure before running the program
        self.gen_chs = OrderedDict()

        # Timestamps, for keeping track of pulse and readout end times.
        self._gen_ts = [0]*len(soccfg['gens'])
        self._ro_ts = [0]*len(soccfg['readouts'])

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
        """
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
                    'gen_ch': gen_ch
                    }
        else: # readout is controlled by tProc
            if (freq is not None) or sel!='product' or (gen_ch is not None):
                raise RuntimeError("this is a tProc-controlled readout - freq/sel parameters are set using tProc instructions")
            cfg = {
                    'length': length
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

    def add_pulse(self, ch, name, idata=None, qdata=None):
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
        self._gen_mgrs[ch].add_pulse(name, idata, qdata)

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

        self.add_pulse(ch, name, idata=gauss(mu=length/2-0.5, si=sigma, length=length, maxv=maxv))


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

        self.add_pulse(ch, name, idata=idata, qdata=qdata)

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

        self.add_pulse(ch, name, idata=triang(length=length, maxv=maxv))

    def load_pulses(self, soc):
        """Loads pulses that were added using add_pulse into the SoC's signal generator memories.

        Parameters
        ----------
        soc : Qick object
            Qick object

        """
        for iCh, pulses in enumerate(self.pulses):
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


class QickProgram(AbsQickProgram):
    """QickProgram is a Python representation of the QickSoc processor assembly program. It can be used to compile simple assembly programs and also contains macros to help make it easy to configure and schedule pulses."""
    # Instruction set for the tproc describing how to automatically generate methods for these instructions
    instructions = {'pushi': {'type': "I", 'bin': 0b00010000, 'fmt': ((0, 53), (1, 41), (2, 36), (3, 0)), 'repr': "{0}, ${1}, ${2}, {3}"},
                    'popi':  {'type': "I", 'bin': 0b00010001, 'fmt': ((0, 53), (1, 41)), 'repr': "{0}, ${1}"},
                    'mathi': {'type': "I", 'bin': 0b00010010, 'fmt': ((0, 53), (1, 41), (2, 36), (3, 46), (4, 0)), 'repr': "{0}, ${1}, ${2} {3} {4}"},
                    'seti':  {'type': "I", 'bin': 0b00010011, 'fmt': ((1, 53), (0, 50), (2, 36), (3, 0)), 'repr': "{0}, {1}, ${2}, {3}"},
                    'synci': {'type': "I", 'bin': 0b00010100, 'fmt': ((0, 0),), 'repr': "{0}"},
                    'waiti': {'type': "I", 'bin': 0b00010101, 'fmt': ((0, 50), (1, 0)), 'repr': "{0}, {1}"},
                    'bitwi': {'type': "I", 'bin': 0b00010110, 'fmt': ((0, 53), (3, 46), (1, 41), (2, 36), (4, 0)), 'repr': "{0}, ${1}, ${2} {3} {4}"},
                    'memri': {'type': "I", 'bin': 0b00010111, 'fmt': ((0, 53), (1, 41), (2, 0)), 'repr': "{0}, ${1}, {2}"},
                    'memwi': {'type': "I", 'bin': 0b00011000, 'fmt': ((0, 53), (1, 31), (2, 0)), 'repr': "{0}, ${1}, {2}"},
                    'regwi': {'type': "I", 'bin': 0b00011001, 'fmt': ((0, 53), (1, 41), (2, 0)), 'repr': "{0}, ${1}, {2}"},
                    'setbi': {'type': "I", 'bin': 0b00011010, 'fmt': ((0, 53), (1, 41), (2, 0)), 'repr': "{0}, ${1}, {2}"},

                    'loopnz': {'type': "J1", 'bin': 0b00110000, 'fmt': ((0, 53), (1, 41), (1, 36), (2, 0)), 'repr': "{0}, ${1}, @{2}"},
                    'end':    {'type': "J1", 'bin': 0b00111111, 'fmt': (), 'repr': ""},

                    'condj':  {'type': "J2", 'bin': 0b00110001, 'fmt': ((0, 53), (2, 46), (1, 36), (3, 31), (4, 0)), 'repr': "{0}, ${1}, {2}, ${3}, @{4}"},

                    'math':  {'type': "R", 'bin': 0b01010000, 'fmt': ((0, 53), (3, 46), (1, 41), (2, 36), (4, 31)), 'repr': "{0}, ${1}, ${2} {3} ${4}"},
                    'set':  {'type': "R", 'bin': 0b01010001, 'fmt': ((1, 53), (0, 50), (2, 36), (7, 31), (3, 26), (4, 21), (5, 16), (6, 11)), 'repr': "{0}, {1}, ${2}, ${3}, ${4}, ${5}, ${6}, ${7}"},
                    'sync': {'type': "R", 'bin': 0b01010010, 'fmt': ((0, 53), (1, 31)), 'repr': "{0}, ${1}"},
                    'read': {'type': "R", 'bin': 0b01010011, 'fmt': ((1, 53), (0, 50), (2, 46), (3, 41)), 'repr': "{0}, {1}, {2} ${3}"},
                    'wait': {'type': "R", 'bin': 0b01010100, 'fmt': ((1, 53), (0, 50), (2, 31)), 'repr': "{0}, {1}, ${2}"},
                    'bitw': {'type': "R", 'bin': 0b01010101, 'fmt': ((0, 53), (1, 41), (2, 36), (3, 46), (4, 31)), 'repr': "{0}, ${1}, ${2} {3} ${4}"},
                    'memr': {'type': "R", 'bin': 0b01010110, 'fmt': ((0, 53), (1, 41), (2, 36)), 'repr': "{0}, ${1}, ${2}"},
                    'memw': {'type': "R", 'bin': 0b01010111, 'fmt': ((0, 53), (2, 36), (1, 31)), 'repr': "{0}, ${1}, ${2}"},
                    'setb': {'type': "R", 'bin': 0b01011000, 'fmt': ((0, 53), (2, 36), (1, 31)), 'repr': "{0}, ${1}, ${2}"},
                    'comment': {'fmt': ()}
                    }

    # op codes for math and bitwise operations
    op_codes = {">": 0b0000, ">=": 0b0001, "<": 0b0010, "<=": 0b0011, "==": 0b0100, "!=": 0b0101,
                "+": 0b1000, "-": 0b1001, "*": 0b1010,
                "&": 0b0000, "|": 0b0001, "^": 0b0010, "~": 0b0011, "<<": 0b0100, ">>": 0b0101,
                "upper": 0b1010, "lower": 0b0101
                }

    # To make it easier to configure pulses these special registers are reserved for each channel's pulse configuration.
    # In each page, register 0 is hard-wired with the value 0.
    # In page 0 we reserve the following additional registers:
    # 13, 14 and 15 for loop counters, 31 for the trigger time.
    # Pairs of channels share a register page.
    # The flat_top pulse uses some extra registers.
    pulse_registers = ["freq", "phase", "addr", "gain", "mode", "t", "addr2", "gain2", "mode2", "mode3"]

    # Attributes to dump when saving the program to JSON.
    dump_keys = ['prog_list', 'pulses', 'ro_chs', 'gen_chs', 'counter_addr', 'reps', 'expts', 'rounds', 'shot_angle', 'shot_threshold']

    gentypes = {'axis_signal_gen_v4': FullSpeedGenManager,
                'axis_signal_gen_v5': FullSpeedGenManager,
                'axis_signal_gen_v6': FullSpeedGenManager,
                'axis_sg_int4_v1': InterpolatedGenManager,
                'axis_sg_mux4_v1': MultiplexedGenManager,
                'axis_sg_mux4_v2': MultiplexedGenManager}

    def __init__(self, soccfg):
        """
        Constructor method
        """
        super().__init__(soccfg)

        # List of commands. This may include comments.
        self.prog_list = []

        # Label to apply to the next instruction.
        self._label_next = None

        # Address of the rep counter in the data memory.
        self.counter_addr = 1
        # Number of iterations in the innermost loop.
        self.reps = None
        # Number of times the program repeats the innermost loop. None means there is no outer loop.
        self.expts = None

        # Generator managers, for keeping track of register values.
        self._gen_mgrs = [self.gentypes[ch['type']](self, iCh) for iCh, ch in enumerate(soccfg['gens'])]
        self._ro_mgrs = [ReadoutManager(self, iCh) if 'tproc_ctrl' in ch else None for iCh, ch in enumerate(soccfg['readouts'])]

        # Number of times the whole program is to be run.
        self.rounds = 1
        # Rotation angle and thresholds for single-shot readout.
        self.shot_angle = None
        self.shot_threshold = None


    def dump_prog(self):
        """
        Dump the program to a dictionary.
        This output contains all the information necessary to run the program.
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

    def acquire(self, soc, reads_per_rep=1, load_pulses=True, start_src="internal", progress=False, debug=False):
        """Acquire data using the accumulated readout.

        Parameters
        ----------
        soc : QickSoc
            Qick object
        reads_per_rep : int
            number of readout triggers in the loop body
        load_pulses : bool
            if True, load pulse envelopes
        start_src: str
            "internal" (tProc starts immediately) or "external" (each round waits for an external trigger)
        progress: bool
            if true, displays progress bar
        debug: bool
            if true, displays assembly code for tProc program

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
        self.config_all(soc, load_pulses=load_pulses, start_src=start_src, debug=debug)

        n_ro = len(self.ro_chs)

        expts = self.expts
        if expts is None:
            expts = 1
        total_reps = expts*self.reps
        total_count = total_reps*reads_per_rep
        d_buf = np.zeros((n_ro, total_count, 2), dtype=np.int32)
        self.stats = []

        # select which tqdm progress bar to show
        hiderounds = True
        hidereps = True
        if progress:
            if self.rounds>1:
                hiderounds = False
            else:
                hidereps = False

        # avg_d doesn't have a specific shape here, so that it's easier for child programs to write custom _average_buf
        avg_d = None
        shots = None
        for ir in tqdm(range(self.rounds), disable=hiderounds):
            # Configure and enable buffer capture.
            self.config_bufs(soc, enable_avg=True, enable_buf=False)

            count = 0
            with tqdm(total=total_count, disable=hidereps) as pbar:
                soc.start_readout(total_reps, counter_addr=self.counter_addr,
                                       ch_list=list(self.ro_chs), reads_per_rep=reads_per_rep)
                while count<total_count:
                    new_data = obtain(soc.poll_data())
                    for d, s in new_data:
                        new_points = d.shape[1]
                        d_buf[:, count:count+new_points] = d
                        count += new_points
                        self.stats.append(s)
                        pbar.update(new_points)

            # if we're thresholding, apply the threshold before averaging
            if self.shot_threshold is None:
                d_reps = d_buf
            else:
                d_reps = [np.zeros_like(d_buf[i]) for i in range(len(self.ro_chs))]
                shots = self.get_single_shots(d_buf)
                for i, ch_shot in enumerate(shots):
                    d_reps[i][...,0] = ch_shot

            # calculate average over the rounds axis
            if avg_d is None:
                avg_d = self._average_buf(d_reps, reads_per_rep) / self.rounds
            else:
                avg_d += self._average_buf(d_reps, reads_per_rep) / self.rounds

        return d_buf, avg_d, shots

    def _average_buf(self, d_reps: np.ndarray, reads_per_rep: int) -> np.ndarray:
        """
        calculate averaged data in a data acquire round. This function should be overwritten in the child qick program
        if the data is created in a different shape.

        :param d_reps: buffer data acquired in a round
        :param reads_per_rep: readouts per experiment
        :return: averaged iq data after each round.
        """
        expts = self.expts
        if expts is None:
            expts = 1

        avg_d = np.zeros((len(self.ro_chs), reads_per_rep, expts, 2))
        for ii in range(reads_per_rep):
            for i_ch, (ch, ro) in enumerate(self.ro_chs.items()):
                avg_d[i_ch][ii] = np.sum(d_reps[i_ch][ii::reads_per_rep, :].reshape((expts, self.reps, 2)), axis=1) / (self.reps * ro['length'])

        if self.expts is None:  # get rid of the expts axis
            avg_d = avg_d[:, :, 0, :]

        return avg_d

    def get_single_shots(self, d_buf):
        """
        This method converts the raw I/Q data to single shots according to the threshold and rotation angle

        Parameters
        ----------
        d_buf : ndarray
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


    def acquire_decimated(self, soc, reads_per_rep=1, load_pulses=True, start_src="internal", progress=True, debug=False):
        """Acquire data using the decimating readout.

        Parameters
        ----------
        soc : QickSoc
            Qick object
        reads_per_rep : int
            number of readout triggers in the loop body
        load_pulses : bool
            if True, load pulse envelopes
        start_src: str
            "internal" (tProc starts immediately) or "external" (each round waits for an external trigger)
        progress: bool
            if true, displays progress bar
        debug: bool
            if true, displays assembly code for tProc program

        Returns
        -------
        list of ndarray
            decimated values, averaged over rounds (float)
            dimensions for a single-rep, single-read program : (length, 2)
            multi-rep, multi-read: (n_reps, n_reads, length, 2)
        """
        self.config_all(soc, load_pulses=load_pulses, start_src=start_src, debug=debug)

        # Initialize data buffers
        d_buf = []
        for ch, ro in self.ro_chs.items():
            maxlen = self.soccfg['readouts'][ch]['buf_maxlen']
            if ro['length']*self.reps > maxlen:
                raise RuntimeError("Warning: requested readout length (%d x %d reps) exceeds buffer size (%d)"%(ro['length'], self.reps, maxlen))
            d_buf.append(np.zeros((ro['length']*self.reps*reads_per_rep, 2), dtype=float))

        tproc = soc.tproc

        # for each soft average, run and acquire decimated data
        for ii in tqdm(range(self.rounds), disable=not progress):
            # Configure and enable buffer capture.
            self.config_bufs(soc, enable_avg=True, enable_buf=True)

            # make sure count variable is reset to 0
            tproc.single_write(addr=self.counter_addr, data=0)

            # run the assembly program
            # if start_src="external", you must pulse the trigger input once for every round
            tproc.start()

            count = 0
            while count < self.reps:
                count = tproc.single_read(addr=self.counter_addr)

            for ii, (ch, ro) in enumerate(self.ro_chs.items()):
                d_buf[ii] += obtain(soc.get_decimated(ch=ch,
                                    address=0, length=ro['length']*self.reps*reads_per_rep))

        # average the decimated data
        if self.reps == 1 and reads_per_rep == 1:
            return [d/self.rounds for d in d_buf]
        else:
            # split the data into the individual reps:
            # we reshape to slice each long buffer into reps,
            # then use moveaxis() to transpose the I/Q and rep axes
            result = [d.reshape(self.reps*reads_per_rep, -1, 2)/self.rounds for d in d_buf]
            if self.reps > 1 and reads_per_rep > 1:
                result = [d.reshape(self.reps, reads_per_rep, -1, 2) for d in result]
            return result

    def config_all(self, soc, load_pulses=True, start_src="internal", debug=False):
        super().config_all(soc, load_pulses)

        # load this program into the soc's tproc
        self.load_program(soc, debug=debug)

        # configure tproc for internal/external start
        soc.start_src(start_src)

    def _ch_page_tproc(self, ch):
        """Gets tProc register page associated with channel.
        Page 0 gets one tProc output because it also has some other registers.
        Other pages get two outputs each.

        This method is for internal use only.
        User code should use ch_page() (for generators) or ch_page_ro() (for readouts).

        Parameters
        ----------
        ch : int
            tProc output channel

        Returns
        -------
        int
            tProc page number

        """
        return (ch+1)//2

    def _sreg_tproc(self, ch, name):
        """Gets tProc register number associated with a channel and register name.

        This method is for internal use only.
        User code should use sreg() (for generators) or sreg_ro() (for readouts).

        Parameters
        ----------
        ch : int
            tProc output channel
        name : str
            Name of special register ("gain", "freq")

        Returns
        -------
        int
            tProc special register number

        """
        # special case for when we want to use the zero register
        if name=='0': return 0
        n_regs = len(self.pulse_registers)
        return 31 - (n_regs * 2) + n_regs*((ch+1)%2) + self.pulse_registers.index(name)

    def ch_page(self, gen_ch):
        """Gets tProc register page associated with generator channel.

        Parameters
        ----------
        gen_ch : int
            generator channel (index in 'gens' list)

        Returns
        -------
        int
            tProc page number

        """
        tproc_ch = self.soccfg['gens'][gen_ch]['tproc_ch']
        return self._ch_page_tproc(tproc_ch)

    def sreg(self, gen_ch, name):
        """Gets tProc special register number associated with a generator channel and register name.

        Parameters
        ----------
        gen_ch : int
            generator channel (index in 'gens' list)
        name : str
            Name of special register ("gain", "freq")

        Returns
        -------
        int
            tProc special register number

        """
        tproc_ch = self.soccfg['gens'][gen_ch]['tproc_ch']
        return self._sreg_tproc(tproc_ch, name)

    def ch_page_ro(self, ro_ch):
        """Gets tProc register page associated with tProc-controlled readout channel.

        Parameters
        ----------
        ro_ch : int
            readout channel (index in 'readouts' list)

        Returns
        -------
        int
            tProc page number

        """
        tproc_ch = self.soccfg['readouts'][ro_ch]['tproc_ctrl']
        return self._ch_page_tproc(tproc_ch)

    def sreg_ro(self, ro_ch, name):
        """Gets tProc special register number associated with a readout channel and register name.

        Parameters
        ----------
        ro_ch : int
            readout channel (index in 'readouts' list)
        name : str
            Name of special register ("gain", "freq")

        Returns
        -------
        int
            tProc special register number

        """
        tproc_ch = self.soccfg['readouts'][ro_ch]['tproc_ctrl']
        return self._sreg_tproc(tproc_ch, name)

    def default_pulse_registers(self, ch, **kwargs):
        """Set default values for pulse parameters.
        If any registers can be written at this point, write them in order to save time later.
        
        This is optional (you can set all parameters in set_pulse_registers).
        You can only call this method once per channel.
        There cannot be any overlap between the parameters defined here and the parameters you define in set_pulse_registers.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        **kwargs : dict
            Pulse parameters

        """
        self._gen_mgrs[ch].set_defaults(kwargs)

    def set_pulse_registers(self, ch, **kwargs):
        """Set the pulse parameters including frequency, phase, address of pulse, gain, stdysel, mode register (compiled from length and other flags), outsel, and length.
        The time is scheduled when you call pulse().
        See the write_regs() method of the relevant generator manager for the list of supported pulse styles.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        style : str
            Pulse style ("const", "arb", "flat_top")
        freq : int
            Frequency (register value)
        phase : int
            Phase (register value)
        gain : int
            Gain (DAC units)
        phrst : int
            If 1, it resets the phase coherent accumulator
        stdysel : str
            Selects what value is output continuously by the signal generator after the generation of a pulse. If "last", it is the last calculated sample of the pulse. If "zero", it is a zero value.
        mode : str
            Selects whether the output is "oneshot" or "periodic"
        outsel : str
            Selects the output source. The output is complex. Tables define envelopes for I and Q. If "product", the output is the product of table and DDS. If "dds", the output is the DDS only. If "input", the output is from the table for the real part, and zeros for the imaginary part. If "zero", the output is always zero.
        length : int
            The number of fabric clock cycles in the flat portion of the pulse, used for "const" and "flat_top" styles
        waveform : str
            Name of the envelope waveform loaded with add_pulse(), used for "arb" and "flat_top" styles
        mask : list of int
            for a muxed signal generator, the list of tones to enable for this pulse
        """
        self._gen_mgrs[ch].set_registers(kwargs)

    def set_readout_registers(self, ch, **kwargs):
        """Set the readout parameters including frequency, mode, outsel, and length.
        The time is scheduled when you call readout().

        Parameters
        ----------
        ch : int
            readout channel (index in 'readouts' list)
        freq : int
            Frequency (register value)
        phrst : int
            If 1, it resets the phase coherent accumulator
        mode : str
            Selects whether the output is "oneshot" or "periodic"
        outsel : str
            Selects the output source. The output is complex. The input comes from the ADC and is purely real. If "product", the output is the product of input and DDS. If "dds", the output is the DDS only. If "input", the output is from the input for the real part, and zeros for the imaginary part. If "zero", the output is always zero.
        length : int
            The number of fabric clock cycles for which these readout parameters are defined.
        """
        self._ro_mgrs[ch].set_registers(kwargs)

    def default_readout_registers(self, ch, **kwargs):
        """Set default values for readout parameters.
        If any registers can be written at this point, write them in order to save time later.

        This is optional (you can set all parameters in set_readout_registers).
        You can only call this method once per channel.
        There cannot be any overlap between the parameters defined here and the parameters you define in set_readout_registers.

        Parameters
        ----------
        ch : int
            readout channel (index in 'readouts' list)
        **kwargs : dict
            Pulse parameters

        """
        self._ro_mgrs[ch].set_defaults(kwargs)

    def readout(self, ch, t):
        """Play the pulse currently programmed into the registers for this tProc-controlled readout channel.
        You must have already run set_readout_registers for this channel.

        Parameters
        ----------
        ch : int
            readout channel (index in 'readouts' list)
        t : int
            The number of tProc cycles at which the pulse starts
        """
        # try to convert pulse_ch to int; if that fails, assume it's list of ints
        ch_list = ch2list(ch)
        for ch in ch_list:
            tproc_ch = self.soccfg['readouts'][ch]['tproc_ctrl']
            rp = self._ch_page_tproc(tproc_ch)
            next_pulse = self._ro_mgrs[ch].next_pulse
            if next_pulse is None:
                raise RuntimeError("no pulse has been set up for channel %d"%(ch))

            r_t = self._sreg_tproc(tproc_ch, 't')
            self.safe_regwi(rp, r_t, t, f't = {t}')

            for regs in next_pulse['regs']:
                self.set(tproc_ch, rp, *regs, r_t, f"ch = {ch}, pulse @t = ${r_t}")


    def setup_and_pulse(self, ch, t='auto', **kwargs):
        """Set up a pulse on this generator channel, and immediately play it.
        This is a wrapper around set_pulse_registers() and pulse(), and takes the arguments from both.
        You can only run this on a single generator channel.

        Parameters
        ----------
        ch : int
            generator channel (index in 'gens' list)
        t : int, optional
            Pulse time, in tProc cycles
        **kwargs : dict
            Pulse parameters: refer to set_pulse_registers
        """
        self.set_pulse_registers(ch, **kwargs)
        self.pulse(ch, t)

    def setup_and_measure(self, adcs, pulse_ch, pins=None, adc_trig_offset=270, t='auto', wait=False, syncdelay=None, **kwargs):
        """Set up a pulse on this generator channel, and immediately do a measurement with it.
        This is a wrapper around set_pulse_registers() and measure(), and takes the arguments from both.
        You can only run this on a single generator channel.

        Parameters
        ----------
        adcs : list of int
            readout channels (index in 'readouts' list)
        pulse_ch : int
            generator channel (index in 'gens' list)
        pins : list of int, optional
            refer to trigger()
        adc_trig_offset : int, optional
            refer to trigger()
        t : int, optional
            refer to pulse()
        wait : bool, optional
            refer to measure()
        syncdelay : int, optional
            refer to measure()
        **kwargs : dict
            Pulse parameters: refer to set_pulse_registers()
        """
        self.set_pulse_registers(pulse_ch, **kwargs)
        self.measure(adcs, pulse_ch, pins=pins, adc_trig_offset=adc_trig_offset, t=t, wait=wait, syncdelay=syncdelay)

    def pulse(self, ch, t='auto'):
        """Play the pulse currently programmed into the registers for this generator channel.
        You must have already run set_pulse_registers for this channel.

        Parameters
        ----------
        ch : int or list of int
            generator channel (index in 'gens' list)
        t : int, optional
            The number of tProc cycles at which the pulse starts (None to use the time register as is, 'auto' to start whenever the last pulse ends)
        """
        # try to convert pulse_ch to int; if that fails, assume it's list of ints
        ch_list = ch2list(ch)
        for ch in ch_list:
            tproc_ch = self.soccfg['gens'][ch]['tproc_ch']
            rp = self._ch_page_tproc(tproc_ch)
            next_pulse = self._gen_mgrs[ch].next_pulse
            if next_pulse is None:
                raise RuntimeError("no pulse has been set up for channel %d"%(ch))

            r_t = self._sreg_tproc(tproc_ch, 't')

            if t is not None:
                ts = self.get_timestamp(gen_ch=ch)
                if t == 'auto':
                    t = int(ts)
                elif t < ts:
                    print("warning: pulse time %d appears to conflict with previous pulse ending at %f?"%(t, ts))
                # convert from generator clock to tProc clock
                pulse_length = next_pulse['length']
                pulse_length *= self.tproccfg['f_time']/self.soccfg['gens'][ch]['f_fabric']
                self.set_timestamp(t + pulse_length, gen_ch=ch)
                self.safe_regwi(rp, r_t, t, f't = {t}')

            # Play each pulse segment.
            # We specify the same time for all segments and rely on the signal generator to concatenate them without gaps.
            # We could specify the "correct" times, but it's difficult to get right when the tProc and generator clocks are different.
            for regs in next_pulse['regs']:
                self.set(tproc_ch, rp, *regs, r_t, f"ch = {ch}, pulse @t = ${r_t}")

    def safe_regwi(self, rp, reg, imm, comment=None):
        """Due to the way the instructions are setup immediate values can only be 30bits before not loading properly.
        This comes up mostly when trying to regwi values into registers, especially the _frequency_ and _phase_ pulse registers.
        safe_regwi can be used wherever one might use regwi and will detect if the value is >2**30 and if so will break it into two steps, putting in the first 30 bits shifting it over and then adding the last two.

        Parameters
        ----------
        rp : int
            Register page
        reg : int
            Register number
        imm : int
            Value of the write
        comment : str, optional
            Comment associated with the write
        """
        if abs(imm) < 2**30:
            self.regwi(rp, reg, imm, comment)
        else:
            self.regwi(rp, reg, imm >> 2, comment)
            self.bitwi(rp, reg, reg, "<<", 2)
            if imm % 4 != 0:
                self.mathi(rp, reg, reg, "+", imm % 4)


    def sync_all(self, t=0, gen_t0=None):
        """Aligns and syncs all channels with additional time t.
        Accounts for both generator pulses and readout windows.
        This does not pause the tProc. gen_t0 is an optional list of
        additional delays for each individual generator channel, e.g. when 
        the channels are on different tiles so they don't natively sync.

        Parameters
        ----------
        t : int, optional
            The time offset in tProc cycles
        gen_t0 : list, optional
            List of additional delays for each individual generator channel, in tProc cycles
        """
        # subtract gen_t0 from the timestamps
        max_t = self.get_max_timestamp(gen_t0=gen_t0)
        if max_t + t > 0:
            self.synci(int(max_t + t))
            # reset all timestamps to 0 or gen_t0 (if defined)
            self.reset_timestamps(gen_t0=gen_t0)
        elif gen_t0:
            # we just want to set the timestamps to gen_t0
            self.reset_timestamps(gen_t0=gen_t0)


    def wait_all(self, t=0):
        """Pause the tProc until all ADC readout windows are complete, plus additional time t.
        This does not sync the tProc clock.

        Parameters
        ----------
        t : int, optional
            The time offset in tProc cycles
        """
        self.waiti(0, int(self.get_max_timestamp(gens=False, ros=True) + t))

    # should change behavior to only change bits that are specified
    def trigger(self, adcs=None, pins=None, ddr4=False, mr=False, adc_trig_offset=270, t=0, width=10, rp=0, r_out=31):
        """Pulse the readout(s) and marker pin(s) with a specified pulse width at a specified time t+adc_trig_offset.
        If no readouts are specified, the adc_trig_offset is not applied.

        Parameters
        ----------
        adcs : list of int
            List of readout channels to trigger (index in 'readouts' list)
        pins : list of int
            List of marker pins to pulse.
            Use the pin numbers in the QickConfig printout.
        ddr4 : bool
            If True, trigger the DDR4 buffer.
        mr : bool
            If True, trigger the MR buffer.
        adc_trig_offset : int, optional
            Offset time at which the ADC is triggered (in tProc cycles)
        t : int, optional
            The number of tProc cycles at which the ADC trigger starts
        width : int, optional
            The width of the trigger pulse, in tProc cycles
        rp : int, optional
            Register page
        r_out : int, optional
            Register number
        """
        if adcs is None:
            adcs = []
        if pins is None:
            pins = []
        #if not any([adcs, pins, ddr4]):
        #    raise RuntimeError("must pulse at least one readout or pin")

        outdict = defaultdict(int)
        for ro in adcs:
            rocfg = self.soccfg['readouts'][ro]
            outdict[rocfg['trigger_port']] |= (1 << rocfg['trigger_bit'])
        for pin in pins:
            pincfg = self.soccfg['tprocs'][0]['output_pins'][pin]
            outdict[pincfg[1]] |= (1 << pincfg[2])
        if ddr4:
            rocfg = self.soccfg['ddr4_buf']
            outdict[rocfg['trigger_port']] |= (1 << rocfg['trigger_bit'])
        if mr:
            rocfg = self.soccfg['mr_buf']
            outdict[rocfg['trigger_port']] |= (1 << rocfg['trigger_bit'])

        t_start = t
        if any([adcs, ddr4, mr]):
            t_start += adc_trig_offset
            # update timestamps with the end of the readout window
            for ro in adcs:
                ts = self.get_timestamp(ro_ch=ro)
                if t_start < ts:
                    print("Readout time %d appears to conflict with previous readout ending at %f?"%(t, ts))
                # convert from readout clock to tProc clock
                ro_length = self.ro_chs[ro]['length']
                ro_length *= self.tproccfg['f_time']/self.soccfg['readouts'][ro]['f_fabric']
                self.set_timestamp(t_start + ro_length, ro_ch=ro)
        t_end = t_start + width

        for outport, out in outdict.items():
            self.regwi(rp, r_out, out, f'out = 0b{out:>016b}')
            self.seti(outport, rp, r_out, t_start, f'ch =0 out = ${r_out} @t = {t}')
            self.seti(outport, rp, 0, t_end, f'ch =0 out = 0 @t = {t}')


    def measure(self, adcs, pulse_ch, pins=None, adc_trig_offset=270, t='auto', wait=False, syncdelay=None):
        """Wrapper method that combines an ADC trigger, a pulse, and (optionally) the appropriate wait and a sync_all.
        You must have already run set_pulse_registers for this channel.
        
        If you use wait=True, it's recommended to also specify a nonzero syncdelay.

        Parameters
        ----------
        adcs : list of int
            readout channels (index in 'readouts' list)
        pulse_ch : int or list of int
            generator channel(s) (index in 'gens' list)
        pins : list of int, optional
            refer to trigger()
        adc_trig_offset : int, optional
            refer to trigger()
        t : int, optional
            refer to pulse()
        wait : bool, optional
            Pause tProc execution until the end of the ADC readout window
        syncdelay : int, optional
            The number of additional tProc cycles to delay in the sync_all
        """
        self.trigger(adcs, pins=pins, adc_trig_offset=adc_trig_offset)
        self.pulse(ch=pulse_ch, t=t)
        if wait:
            # tProc should wait for the readout to complete.
            # This prevents loop counters from getting incremented before the data is available.
            self.wait_all()
        if syncdelay is not None:
            self.sync_all(syncdelay)

    def reset_phase(self, gen_ch: Union[int, List[int]] = None, ro_ch: Union[int, List[int]] = None, t: int = 0):
        """
        Reset the phase of generator and tproc-controlled readout channels at tproc time t.
        This will play an empty pulse that lasts 3 fabric clock cycles, just to trigger the phase reset.

        This command is designed to be transparent to previous 'set_pulse/readout_registers()' calls. i.e. the register
        values set using 'set_pulse/readout_registers()' before this command will remain the same after this command.
        However, pulse registers set using other functions will need to be re-set, e.g. if a pulse register value was
        set by directly calling 'regwi()', calling this function will overwrite that register value, and user need to
        redo the 'regwi()' after this phase reset.

        :param gen_ch: generator channel(s) to reset phase (index in 'gens' list)
        :param ro_ch: tProc-controlled readout channel(s) to reset phase (index in 'readouts' list)
        :param t: the number of tProc cycles at which the phase reset happens
        """
        # todo: not sure if it is possible to perform the phase reset without playing the empty pulses

        # convert gen and readout channels to lists of ints
        channels = {"generator": ch2list(gen_ch), "readout": ch2list(ro_ch)}

        # reset phase for each generator and readout channel
        for ch_type, ch_list in channels.items():
            for ch in ch_list:
                # check time and get generator/readout manager
                if ch_type == "generator":
                    ts = self.get_timestamp(gen_ch=ch)
                    if t < ts:
                        print(f"warning: generator {ch} phase reset at t={t} appears to conflict "
                              f"with previous pulse ending at {ts}")
                    ch_mgr = self._gen_mgrs[ch]
                    phrst_params = dict(style="const", phase=0, freq=0, gain=0, length=3, phrst=1)
                    tproc_ch = self.soccfg["gens"][ch]['tproc_ch']
                else:  # for readout channels
                    ch_mgr = self._ro_mgrs[ch]
                    # skip PYNQ-controlled readouts, which can't be reset
                    if ch_mgr is None: continue
                    ts = self.get_timestamp(ro_ch=ch)
                    if t < ts:
                        print(f"warning: readout {ch} phase reset at t={t} appears to conflict "
                              f"with previous readout ending at {ts}")
                    phrst_params = dict(freq=0, length=3, phrst=1)
                    tproc_ch = self.soccfg["readouts"][ch]['tproc_ctrl']

                # keeps a record of the last set registers and the default registers
                last_set_regs_ = ch_mgr.last_set_regs
                defaults_regs_ = ch_mgr.defaults
                # temporarily ignore the default registers
                ch_mgr.defaults = {}
                # set registers for phase reset
                ch_mgr.set_registers(phrst_params)

                # write phase reset time register
                rp = self._ch_page_tproc(tproc_ch)
                r_t = self._sreg_tproc(tproc_ch, 't')
                self.safe_regwi(rp, r_t, t, f't = {t}')
                # schedule phrst at $r_t
                for regs in ch_mgr.next_pulse["regs"]:
                    self.set(tproc_ch, rp, *regs, r_t, f" {ch_type} ch{ch} phase reset @t = ${r_t}")

                # set the default and last set registers back
                ch_mgr.set_defaults(defaults_regs_)
                ch_mgr.set_registers(last_set_regs_)

        self.sync_all(3)

    def convert_immediate(self, val):
        """Convert the register value to ensure that it is positive and not too large. Throws an error if you ever try to use a value greater than 2**31 as an immediate value.

        Parameters
        ----------
        val : int
            Original register value

        Returns
        -------
        int
            Converted register value

        """
        if val > 2**31:
            raise RuntimeError(
                f"Immediate values are only 31 bits {val} > 2**31")
        if val < 0:
            return 2**31+val
        else:
            return val

    def compile_instruction(self, inst, labels, debug=False):
        """Converts an assembly instruction into a machine bytecode.

        Parameters
        ----------
        inst : dict
            Assembly instruction
        labels : dict
            Map from label name to program counter
        debug : bool
            If True, debug mode is on

        Returns
        -------
        int
            Compiled instruction in binary

        """
        args = list(inst['args'])
        idef = self.__class__.instructions[inst['name']]
        fmt = idef['fmt']

        if debug:
            print(inst)

        if idef['type'] == "I":
            args[len(fmt)-1] = self.convert_immediate(args[len(fmt)-1])

        if inst['name'] == 'loopnz':
            args[2] = labels[args[2]]  # resolve label

        if inst['name'] == 'condj':
            args[4] = labels[args[4]]  # resolve label
            # get binary condtional op code
            args[2] = self.__class__.op_codes[inst['args'][2]]

        if inst['name'][:4] == 'math':
            args[3] = self.__class__.op_codes[inst['args'][3]]  # get math op code

        if inst['name'][:4] == 'bitw':
            # get bitwise op code
            args[3] = self.__class__.op_codes[inst['args'][3]]

        if inst['name'][:4] == 'read':
            args[2] = self.__class__.op_codes[inst['args'][2]]  # get read op code

        mcode = (idef['bin'] << 56)
        # print(inst)
        for field in fmt:
            mcode |= (args[field[0]] << field[1])

        if inst['name'] == 'loopnz':
            mcode |= (0b1000 << 46)

        return mcode

    def compile(self, debug=False):
        """Compiles program to machine code.

        Parameters
        ----------
        debug : bool
            If True, debug mode is on

        Returns
        -------
        list of int
            List of binary instructions

        """
        labels = {}
        # Scan the ASM instructions for labels. Skip comment lines.
        prog_counter = 0
        for inst in self.prog_list:
            if inst['name']=='comment':
                continue
            if 'label' in inst:
                if inst['label'] in labels:
                    raise RuntimeError("label used twice:", inst['label'])
                labels[inst['label']] = prog_counter
            prog_counter += 1
        return [self.compile_instruction(inst, labels, debug=debug) for inst in self.prog_list if inst['name']!='comment']

    def load_program(self, soc, debug=False, reset=False):
        """Load the compiled program into the tProcessor.

        Parameters
        ----------
        debug : bool
            If True, debug mode is on
        soc : QickSoc
            The QICK to be configured
        reset : bool
            Reset the tProc before loading
        """
        soc.load_bin_program(self.compile(debug=debug), reset=reset)

    def append_instruction(self, name, *args):
        """Append instruction to the program list

        Parameters
        ----------
        name : str
            Instruction name
        *args : dict
            Instruction arguments
        """
        n_args = max([f[0] for f in self.instructions[name]['fmt']]+[-1])+1
        if len(args)==n_args:
            inst = {'name': name, 'args': args}
        elif len(args)==n_args+1:
            inst = {'name': name, 'args': args[:n_args], 'comment': args[n_args]}
        else:
            raise RuntimeError("wrong number of args:", name, args)
        if self._label_next is not None:
            # store the label with the instruction, for printing
            inst['label'] = self._label_next
            self._label_next = None
        self.prog_list.append(inst)

    def label(self, name):
        """Add line number label to the labels dictionary. This labels the instruction by its position in the program list. The loopz and condj commands use this label information.

        Parameters
        ----------
        name : str
            Label name
        """
        if self._label_next is not None:
            raise RuntimeError("label already defined for the next line")
        self._label_next = name

    def __getattr__(self, a):
        """
        Uses instructions dictionary to automatically generate methods for the standard instruction set.

        Also include all QickConfig methods as methods of the QickProgram.
        This allows e.g. this.freq2reg(f) instead of this.soccfg.freq2reg(f).

        :param a: Instruction name
        :type a: str
        :return: Instruction arguments
        :rtype: *args object
        """
        if a in self.__class__.instructions:
            return lambda *args: self.append_instruction(a, *args)
        elif a in self.__class__.soccfg_methods:
            return getattr(self.soccfg, a)
        else:
            return object.__getattribute__(self, a)

    def hex(self):
        """Returns hex representation of program as string.

        Returns
        -------
        str
            Compiled program in hex format
        """
        return "\n".join([format(mc, '#018x') for mc in self.compile()])

    def bin(self):
        """Returns binary representation of program as string.

        Returns
        -------
        str
            Compiled program in binary format
        """
        return "\n".join([format(mc, '#066b') for mc in self.compile()])

    def asm(self):
        """Returns assembly representation of program as string, should be compatible with the parse_prog from the parser module.

        Returns
        -------
        str
            asm file
        """
        label_list = [inst['label'] for inst in self.prog_list if 'label' in inst]
        if label_list:
            max_label_len = max([len(label) for label in label_list])
        else:
            max_label_len = 0
        s = "\n// Program\n\n"
        lines = [self._inst2asm(inst, max_label_len) for inst in self.prog_list]
        return s+"\n".join(lines)

    def _inst2asm(self, inst, max_label_len):
        if inst['name']=='comment':
            return "// "+inst['comment']
        template = inst['name'] + " " + self.__class__.instructions[inst['name']]['repr'] + ";"
        line = " "*(max_label_len+2) + template.format(*inst['args'])
        if 'comment' in inst:
            line += " "*(48-len(line)) + "//" + (inst['comment'] if inst['comment'] is not None else "")
        if 'label' in inst:
            label = inst['label']
            line = label + ": " + line[len(label)+2:]
        return line

    def compare_program(self, fname):
        """For debugging purposes to compare binary compilation of parse_prog with the compile.

        Parameters
        ----------
        fname : str
            File the comparison program is stored in

        Returns
        -------
        bool
            True if programs are identical; False otherwise
        """
        match = True
        pns = [int(n, 2) for n in self.bin().split('\n')]
        fns = [int(n, 2)
               for ii, n in parse_prog(file=fname, outfmt="bin").items()]
        if len(pns) != len(fns):
            print("Programs are different lengths")
            return False
        for ii in range(len(pns)):
            if pns[ii] != fns[ii]:
                print(f"Mismatch on line ii: p={pns[ii]}, f={fns[ii]}")
                match = False
        return match

    def __len__(self):
        """
        :return: number of instructions in the program
        :rtype: int
        """
        return len(self.prog_list)

    def __str__(self):
        """
        Print as assembly by default.

        :return: The asm file associated with the class
        :rtype: str
        """
        return self.asm()

    def __enter__(self):
        """
        Enter the runtime context related to this object.

        :return: self
        :rtype: self
        """
        return self

    def __exit__(self, type, value, traceback):
        """
        Exit the runtime context related to this object.

        :param type: type of error
        :type type: type
        :param value: value of error
        :type value: int
        :param traceback: traceback of error
        :type traceback: str
        """
        pass


class QickRegister:
    """A qick register object that keeps the page, address, generator/readout channel and register type information,
       provides functions that make it easier to set register value given input values in physical units.
    """
    def __init__(self, prog: QickProgram, page: int, addr: int, reg_type: str = None,
                 gen_ch: int = None, ro_ch: int = None, init_val=None, name: str = None):
        """
        :param prog: qick program in which the register is used.
        :param page: page of the register
        :param addr: address of the register in the register page (referred as "register number" in some other places)
        :param reg_type: {"freq", "time", "phase", "adc_freq"} or None,
            type of the register, used for automatic converting to physical values.
        :param gen_ch: generator channel numer to which the register is associated with, for unit convert.
        :param ro_ch: readout channel numer to which the register is associated with, for unit convert.
        :param init_val: initial value of the register. If reg_type is not None, the value should be in its physical
            unit. i.e. freq in MHz, time in us, phase in deg.
        :param name: If None, an auto generated name based on the register page and address will be used
        """
        self.prog = prog
        self.page = page
        self.addr = addr
        self.reg_type = reg_type
        self.gen_ch = gen_ch
        self.ro_ch = ro_ch
        self.init_val = init_val
        self.unit = DefaultUnits.get(str(self.reg_type))
        if name is None:
            self.name = f"reg_p{page}_{addr}"
        else:
            self.name = name
        if init_val is not None:
            self.reset()

    def val2reg(self, val):
        """
        convert physical value to a qick register value
        :param val:
        :return:
        """
        if self.reg_type == "freq":
            return self.prog.freq2reg(val, self.gen_ch, self.ro_ch)
        elif self.reg_type == "time":
            if self.gen_ch is not None:
                return self.prog.us2cycles(val, self.gen_ch)
            else:
                return self.prog.us2cycles(val, self.gen_ch, self.ro_ch)
        elif self.reg_type == "phase":
            return self.prog.deg2reg(val, self.gen_ch)
        elif self.reg_type == "adc_freq":
            return self.prog.freq2reg_adc(val, self.ro_ch, self.gen_ch)
        else:
            return np.int32(val)

    def reg2val(self, reg):
        """
        converts a qick register value to its value in physical units
        :param reg:
        :return:
        """
        if self.reg_type == "freq":
            return self.prog.reg2freq(reg, self.gen_ch)
        elif self.reg_type == "time":
            if self.gen_ch is not None:
                return self.prog.cycles2us(reg, self.gen_ch)
            else:
                return self.prog.cycles2us(reg, self.gen_ch, self.ro_ch)
        elif self.reg_type == "phase":
            return self.prog.reg2deg(reg, self.gen_ch)
        elif self.reg_type == "adc_freq":
            return self.prog.reg2freq_adc(reg, self.ro_ch)
        else:
            return reg


    def set_to(self, a: Union["QickRegister", float, int], operator: str = "+",
                  b: Union["QickRegister", float, int] = 0, physical_unit=True):
        """
        a shorthand function that sets the register value using different asm commands based on the input type.

        if input "a" is a number, "operator" and "b" will be neglected, "a"(or the register integer that corresponds to
        "a") will be assigned to the current register

        if input "a" is a QickRegister and "b" is a number, the register will be set to the "mathi" result between "a"
        and "b". (when physical_unit==True, "b" will be auto-converted from physical value to register value based on
        the register type)

        if both  "a" and "b" are QickRegisters, the register will be set to the "math" result between "a" and "b".

        :param a: first operand register or a constant value
        :param operator: {"+", "-", "*"}. math symbol supported by "math" and "mathi" asm commands
        :param b: second operand register or a constant value
        :param physical_unit: when True, the constant value operands should be in its physical unit and will be
            automatically converted to the register integer before assignment.
        :return:
        """
        if operator not in MathOperators:
            raise ValueError(f"operator {operator} is not supported.")
        if type(a) != QickRegister: # assign value "a" to register, do unit conversion if physical_unit==True
            reg = self.val2reg(a) if physical_unit else a
            comment = f"'{self.name}' <= {reg} " + \
                      (f"({a} {self.unit})" if physical_unit and (self.unit is not None) else "")
            self.prog.safe_regwi(self.page, self.addr, reg, comment)
        else:
            if type(b) == QickRegister:
                # do math operation between register "b" and register "a", assign the result to current register
                comment = f" '{self.name}' <= '{a.name}' {operator} '{b.name}'"
                if not (self.page == a.page == b.page):
                    raise RuntimeError(f"the qick registers for mathematical operation must be on the same page. "
                                       f"Got '{self.name}' on page {self.page}, '{a.name}' on page {a.page} "
                                       f"and '{b.name}' on page {b.page}")
                self.prog.math(self.page, self.addr, a.addr, operator, b.addr, comment)
            else:
                # do math operation between value "b" and register "a", assign the result to current register
                reg = self.val2reg(b) if physical_unit else b # do unit conversion on "b" if physical_unit==True
                comment = f" '{self.name}' <= '{a.name}' {operator} {reg} " \
                          + (f"({b} {self.unit})" if physical_unit and (self.unit is not None) else "")
                if not (self.page == a.page):
                    raise RuntimeError(f"the qick registers for mathematical operation must be on the same page. "
                                       f"Got '{self.name}' on page {self.page} and '{a.name}' on page {a.page}")
                self.prog.mathi(self.page, self.addr, a.addr, operator, reg, comment)

    def reset(self):
        """
        reset register value to its init_val
        :return:
        """
        self.set_to(self.init_val)


class QickRegisterManagerMixin:
    """
    A mixin class for QickProgram that provides manager functions for getting and declaring new qick registers.
    """

    def __init__(self, *args, **kwargs):
        self.user_reg_dict = {}  # look up dict for registers defined in each generator channel
        self._user_regs = []  # (page, addr) of all user defined registers
        super().__init__(*args, **kwargs)

    def new_reg(self, page: int, addr: int = None, name: str = None, init_val=None, reg_type: str = None,
                gen_ch: int = None, ro_ch: int = None):
        """ Declare a new register in a specific page.

        :param page: register page
        :param addr: address of the new register. If None, the function will automatically try to find the next
            available address.
        :param name: name of the new register. Optional.
        :param init_val: initial value for the register, when reg_type is provided, the reg_val should be in the
            physical unit of the corresponding type. i.e. freq in MHz, time in us, phase in deg.
        :param reg_type: {"freq", "time", "phase", "adc_freq"} or None, type of the register
        :param gen_ch: generator channel numer to which the register is associated with, for unit convert.
        :param ro_ch: readout channel numer to which the register is associated with, for unit convert.
        :return: QickRegister
        """
        if addr is None:
            addr = 1
            while (page, addr) in self._user_regs:
                addr += 1
            if addr > 12:
                raise RuntimeError(f"registers in page {page} is full.")
        else:
            if addr < 1 or addr > 12:
                raise ValueError(f"register address must be greater than 0 and smaller than 13")
            if (page, addr) in self._user_regs:
                raise ValueError(f"register at address {addr} in page {page} is already occupied.")
        self._user_regs.append((page, addr))

        if name is None:
            name = f"reg_page{page}_{addr}"
        if name in self.user_reg_dict.keys():
            raise NameError(f"register name '{name}' already exists")

        reg = QickRegister(self, page, addr, reg_type, gen_ch, ro_ch, init_val, name=name)
        self.user_reg_dict[name] = reg

        return reg

    def get_gen_reg(self, gen_ch: int, name: str) -> QickRegister:
        """
        Gets tProc register page and address associated with gen_ch and register name. Creates a QickRegister object for
        return.

        :param gen_ch: generator channel number
        :param name:  name of the qick register, as in QickProgram.pulse_registers
        :return: QickRegister
        """
        gen_cgf = self.gen_chs[gen_ch]
        page = self.ch_page(gen_ch)
        addr = self.sreg(gen_ch, name)
        reg_type = name if name in RegisterType else None
        reg = QickRegister(self, page, addr, reg_type, gen_ch, gen_cgf.get("ro_ch"), name=f"gen{gen_ch}_{name}")
        return reg

    def new_gen_reg(self, gen_ch: int, name: str = None, init_val=None, reg_type: str = None,
                    tproc_reg=False) -> QickRegister:
        """
        Declare a new register in the generator register page. Address automatically adds 1 one when each time a new
        register in the same page is declared.

        :param gen_ch: generator channel number
        :param name: name of the new register. Optional.
        :param init_val: initial value for the register, when reg_type is provided, the reg_val should be in the unit of
            the corresponding type.
        :param reg_type: {"freq", "time", "phase", "adc_freq"} or None, type of the register.
        :param tproc_reg: if True, the new register created will not be associated to a specific generator or readout
            channel. It will still be on the same page as the gen_ch for math calculations. This is usually used for a
            time register in t_processor, where we want to calculate "us2cycles" with the t_proc fabric clock rate
            instead of the generator clock rate.
        :return: QickRegister
        """
        gen_cgf = self.gen_chs[gen_ch]
        page = self.ch_page(gen_ch)

        addr = 1
        while (page, addr) in self._user_regs:
            addr += 1
        if name is None:
            name = f"gen{gen_ch}_reg{addr}"

        if tproc_reg:
            return self.new_reg(page, addr, name, init_val, reg_type, None, None)
        else:
            return self.new_reg(page, addr, name, init_val, reg_type, gen_ch, gen_cgf.get("ro_ch"))
