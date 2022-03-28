"""
The higher-level driver for the QICK library. Contains an tProc assembly language wrapper class and auxiliary functions.
"""
import numpy as np
import json
from collections import namedtuple, OrderedDict


class QickConfig():
    """
    Uses the QICK configuration to convert frequencies and clock delays.
    If running on the QICK, you don't need to use this class - the QickSoc class has all of the same methods.
    If running remotely, you may want to initialize a QickConfig from a JSON file.

    :param cfg: config dictionary, or path to JSON file
    :type cfg: dict or str
    """

    def __init__(self, cfg=None):
        if isinstance(cfg, str):
            with open(cfg) as f:
                self._cfg = json.load(f)
        elif cfg is not None:
            self._cfg = cfg

    def __str__(self):
        return self.description()

    def __getitem__(self, key):
        return self._cfg[key]

    def __setitem__(self, key, val):
        self._cfg[key] = val

    def description(self):
        """
        Generate a printable description of the QICK configuration.

        :return: description
        :rtype: str
        """
        lines = []
        lines.append("\n\tBoard: " + self['board'])
        lines.append("\n\tGlobal clocks (MHz): tProcessor %.3f, RF reference %.3f" % (
            self['fs_proc'], self['refclk_freq']))

        lines.append("\n\t%d signal generator channels:" % (len(self['gens'])))
        for iGen, gen in enumerate(self['gens']):
            lines.append("\t%d:\t%s - tProc output %d, switch ch %d, maxlen %d" %
                         (iGen, gen['type'], gen['tproc_ch'], gen['switch_ch'], gen['maxlen']))
            lines.append("\t\tDAC tile %s, ch %s, %d-bit DDS, fabric=%.3f MHz, fs=%.3f MHz" %
                         (*gen['dac'], gen['b_dds'], gen['f_fabric'], gen['fs']))

        if self['iqs']:
            lines.append("\n\t%d constant-IQ outputs:" % (len(self['iqs'])))
            for iIQ, iq in enumerate(self['iqs']):
                lines.append("\t%d:\tDAC tile %s, ch %s, fs=%.3f MHz" %
                             (iIQ, *iq['dac'], iq['fs']))

        lines.append("\n\t%d readout channels:" % (len(self['readouts'])))
        for iReadout, readout in enumerate(self['readouts']):
            lines.append("\t%d:\tADC tile %s, ch %s, %d-bit DDS, fabric=%.3f MHz, fs=%.3f MHz" %
                         (iReadout, *readout['adc'], readout['b_dds'], readout['f_fabric'], readout['fs']))
            lines.append("\t\tmaxlen %d (avg) %d (decimated), trigger %d, tProc input %d" % (
                readout['avg_maxlen'], readout['buf_maxlen'], readout['trigger_bit'], readout['tproc_ch']))

        if hasattr(self, 'tproc'):  # this is a QickSoc
            lines.append("\n\ttProc: %d words program memory, %d words data memory" % (
                2**self.tproc.PMEM_N, 2**self.tproc.DMEM_N))
            lines.append("\t\tprogram RAM: %d bytes" %
                         (self.tproc.mem.mmio.length))

        return "\nQICK configuration:\n"+"\n".join(lines)

    def get_cfg(self):
        """
        Return the QICK configuration dictionary.
        This contains everything you need to recreate the QickConfig.

        :return: configuration dictionary
        :rtype: dict
        """
        return self._cfg

    def dump_cfg(self):
        """
        Generate a JSON description of the QICK configuration.
        You can save this string to a file and load it to recreate the QickConfig.

        :return: configuration in JSON format
        :rtype: str
        """
        return json.dumps(self._cfg, indent=4)

    def calc_fstep(self, dict1, dict2):
        """
        Finds the least common multiple of the frequency steps of two channels (typically a DAC and ADC)
        :param dict1: config dict for one channel
        :type dict1: dict
        :param dict2: config dict for the other channel
        :type dict2: dict
        :return: frequency step common to the two channels
        :rtype: float
        """
        refclk = self['refclk_freq']
        # Calculate least common multiple of sampling frequencies.

        # clock multipliers from refclk to DAC/ADC - always integer
        fsmult1 = round(dict1['fs']/refclk)
        fsmult2 = round(dict2['fs']/refclk)

        # Calculate a common fstep_lcm, which is divisible by both step sizes of both channels.
        # We should only use frequencies that are evenly divisible by fstep_lcm.
        b_max = max(dict1['b_dds'], dict2['b_dds'])
        mult_lcm = np.lcm(fsmult1 * 2**(b_max - dict1['b_dds']),
                          fsmult2 * 2**(b_max - dict2['b_dds']))
        return refclk * mult_lcm / 2**b_max

    def roundfreq(self, f, dict1, dict2):
        """
        Round a frequency to the LCM of the frequency steps of two channels (typically a DAC and ADC).
        :param f: frequency (MHz)
        :type f: float or array
        :param dict1: config dict for one channel
        :type dict1: dict
        :param dict2: config dict for the other channel
        :type dict2: dict
        :return: rounded frequency (MHz)
        :rtype: float or array
        """
        fstep = self.calc_fstep(dict1, dict2)
        return np.round(f/fstep) * fstep

    def freq2int(self, f, thisch, otherch=None):
        """
        Converts frequency in MHz to integer value suitable for writing to a register.
        This method works for both DACs and ADCs.
        If a DAC will be connected to an ADC, the two channels must have exactly the same frequency, and you must supply the config for the other channel.

        :param f: frequency (MHz)
        :type f: float
        :param thisch: config dict for the channel you're configuring
        :type thisch: dict
        :param otherch: config dict for a channel you will set to the same frequency
        :type otherch: dict
        :return: Re-formatted frequency
        :rtype: int
        """
        if otherch is None:
            f_round = f
        else:
            f_round = self.roundfreq(f, thisch, otherch)
        k_i = np.round(f_round*(2**thisch['b_dds'])/thisch['fs'])
        return np.int64(k_i)

    def freq2reg(self, f, gen_ch=0, ro_ch=0):
        """
        Converts frequency in MHz to tProc DAC register value.

        :param f: frequency (MHz)
        :type f: float
        :param gen_ch: DAC channel
        :type gen_ch: int
        :param ro_ch: readout channel (use None if you don't want to round to a valid ADC frequency)
        :type ro_ch: int
        :return: Re-formatted frequency
        :rtype: int
        """
        if ro_ch is None:
            rocfg = None
        else:
            rocfg = self['readouts'][ro_ch]
        return self.freq2int(f, self['gens'][gen_ch], rocfg)

    def freq2reg_adc(self, f, ro_ch=0, gen_ch=0):
        """
        Converts frequency in MHz to ADC register value.

        :param f: frequency (MHz)
        :type f: float
        :param ro_ch: readout channel
        :type ro_ch: int
        :param gen_ch: DAC channel (use None if you don't want to round to a valid DAC frequency)
        :type gen_ch: int
        :return: Re-formatted frequency
        :rtype: int
        """
        if gen_ch is None:
            gencfg = None
        else:
            gencfg = self['gens'][gen_ch]
        return self.freq2int(f, self['readouts'][ro_ch], gencfg)

    def reg2freq(self, r, gen_ch=0):
        """
        Converts frequency from format readable by tProc DAC to MHz.

        :param r: frequency in tProc DAC format
        :type r: float
        :param gen_ch: DAC channel
        :type gen_ch: int
        :return: Re-formatted frequency in MHz
        :rtype: float
        """
        return (r/2**self['gens'][gen_ch]['b_dds']) * self['gens'][gen_ch]['fs']

    def reg2freq_adc(self, r, ro_ch=0):
        """
        Converts frequency from format readable by tProc ADC to MHz.

        :param r: frequency in tProc ADC format
        :type r: float
        :param ro_ch: ADC channel
        :type ro_ch: int
        :return: Re-formatted frequency in MHz
        :rtype: float
        """
        return (r/2**self['readouts'][ro_ch]['b_dds']) * self['readouts'][ro_ch]['fs']

    def adcfreq(self, f, gen_ch=0, ro_ch=0):
        """
        Takes a frequency and casts it to an (even) valid ADC DDS frequency.

        :param f: frequency (MHz)
        :type f: float
        :param gen_ch: DAC channel
        :type gen_ch: int
        :param ro_ch: readout channel
        :type ro_ch: int
        :return: Re-formatted frequency
        :rtype: int
        """
        return self.roundfreq(f, self['gens'][gen_ch], self['readouts'][ro_ch])

    def deg2reg(self, deg, gen_ch=0):
        """
        Converts degrees into phase register values; numbers greater than 360 will effectively be wrapped.

        :param deg: Number of degrees
        :type deg: float
        :return: Re-formatted number of degrees
        :rtype: int
        """
        gen_type = self['gens'][gen_ch]['type']
        if gen_type == 'axis_sg_int4_v1':
            b_phase = 16
        else:
            b_phase = 32
        return int(deg*2**b_phase//360) % 2**b_phase

    def reg2deg(self, reg, gen_ch=0):
        """
        Converts phase register values into degrees.

        :param cycles: Re-formatted number of degrees
        :type cycles: int
        :return: Number of degrees
        :rtype: float
        """
        gen_type = self['gens'][gen_ch]['type']
        if gen_type == 'axis_sg_int4_v1':
            b_phase = 16
        else:
            b_phase = 32
        return reg*360/2**b_phase

    def cycles2us(self, cycles):
        """
        Converts tProc clock cycles to microseconds.

        :param cycles: Number of tProc clock cycles
        :type cycles: int
        :return: Number of microseconds
        :rtype: float
        """
        return cycles/self['fs_proc']

    def us2cycles(self, us):
        """
        Converts microseconds to integer number of tProc clock cycles.

        :param cycles: Number of microseconds
        :type cycles: float
        :return: Number of tProc clock cycles
        :rtype: int
        """
        return np.int64(np.round(us*self['fs_proc']))


# configuration for an enabled readout channel
ReadoutConfig = namedtuple('ReadoutConfig', ['freq', 'length', 'sel', 'gen_ch'])
GeneratorConfig = namedtuple('GeneratorConfig', ['nqz', 'mixer_freq', 'mux_freqs', 'ro_ch'])


class QickProgram:
    """
    QickProgram is a Python representation of the QickSoc processor assembly program. It can be used to compile simple assembly programs and also contains macros to help make it easy to configure and schedule pulses.
    """
    # Instruction set for the tproc describing how to automatically generate methods for these instructions
    instructions = {'pushi': {'type': "I", 'bin': 0b00010000, 'fmt': ((0, 53), (1, 41), (2, 36), (3, 0)), 'repr': "{0}, ${1}, ${2}, {3}"},
                    'popi':  {'type': "I", 'bin': 0b00010001, 'fmt': ((0, 53), (1, 41)), 'repr': "{0}, ${1}"},
                    'mathi': {'type': "I", 'bin': 0b00010010, 'fmt': ((0, 53), (1, 41), (2, 36), (3, 46), (4, 0)), 'repr': "{0}, ${1}, ${2}, {3}, {4}"},
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

                    'math':  {'type': "R", 'bin': 0b01010000, 'fmt': ((0, 53), (3, 46), (1, 41), (2, 36), (4, 31)), 'repr': "{0}, ${1}, ${2}, {3}, ${4}"},
                    'set':  {'type': "R", 'bin': 0b01010001, 'fmt': ((1, 53), (0, 50), (2, 36), (7, 31), (3, 26), (4, 21), (5, 16), (6, 11)), 'repr': "{0}, {1}, ${2}, ${3}, ${4}, ${5}, ${6}, ${7}"},
                    'sync': {'type': "R", 'bin': 0b01010010, 'fmt': ((0, 53), (1, 31)), 'repr': "{0}, ${1}"},
                    'read': {'type': "R", 'bin': 0b01010011, 'fmt': ((1, 53), (0, 50), (2, 46), (3, 41)), 'repr': "{0}, {1}, {2} ${3}"},
                    'wait': {'type': "R", 'bin': 0b01010100, 'fmt': ((0, 53), (1, 31)), 'repr': "{0}, {1}, ${2}"},
                    'bitw': {'type': "R", 'bin': 0b01010101, 'fmt': ((0, 53), (1, 41), (2, 36), (3, 46), (4, 31)), 'repr': "{0}, ${1}, ${2} {3} ${4}"},
                    'memr': {'type': "R", 'bin': 0b01010110, 'fmt': ((0, 53), (1, 41), (2, 36)), 'repr': "{0}, ${1}, ${2}"},
                    'memw': {'type': "R", 'bin': 0b01010111, 'fmt': ((0, 53), (2, 36), (1, 31)), 'repr': "{0}, ${1}, ${2}"},
                    'setb': {'type': "R", 'bin': 0b01011000, 'fmt': ((0, 53), (2, 36), (1, 31)), 'repr': "{0}, ${1}, ${2}"}
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
    pulse_registers = ["freq", "phase", "addr", "gain", "mode", "t", "addr2", "gain2", "mode2"]

    # delay in clock cycles between marker channel (ch0) and siggen channels (due to pipeline delay)
    trig_offset = 25

    soccfg_methods = ['freq2reg', 'freq2reg_adc',
                      'reg2freq', 'reg2freq_adc',
                      'cycles2us', 'us2cycles',
                      'deg2reg', 'reg2deg']

    def __init__(self, soccfg):
        """
        Constructor method
        """
        self.soccfg = soccfg
        self.prog_list = []
        self.labels = {}
        self.dac_ts = [0]*len(soccfg['gens'])
        self.adc_ts = [0]*len(soccfg['readouts'])
        self.channels = {ch: {"addr": 0, "pulses": {}, "params": {},
                              "last_pulse": None} for ch in range(len(soccfg['gens']))}

        # readout channels to configure before running the program
        self.ro_chs = OrderedDict()
        # signal generator channels to configure before running the program
        self.gen_chs = OrderedDict()

    def declare_readout(self, ch, freq, length, sel='product', gen_ch=None):
        """
        Add a channel to the program's list of readouts.

        :param ch: ADC channel number (index in 'readouts' list)
        :type ch: int
        :param freq: downconverting frequency (MHz)
        :type freq: float
        :param length: readout length (number of samples)
        :type length: int
        :param sel: output select ('product', 'dds', 'input')
        :type sel: str
        :param gen_ch: DAC channel (use None if you don't want to round to a valid DAC frequency)
        :type gen_ch: int
        """
        self.ro_chs[ch] = ReadoutConfig(freq, length, sel, gen_ch)

    def config_readouts(self, soc):
        """
        Configure the readout channels specified in this program.
        This is usually called as part of an acquire() method.

        :param soc: the QickSoc that will execute this program
        :type soc: QickSoc
        """
        soc.init_readouts()
        for ch, cfg in self.ro_chs.items():
            if cfg.gen_ch is not None:
                gen_cfg = self.gen_chs[cfg.gen_ch]
                gen = soc.gens[cfg.gen_ch]
            soc.configure_readout(ch, output=cfg.sel, frequency=cfg.freq, gen_ch=cfg.gen_ch)

    def config_bufs(self, soc, enable_avg=True, enable_buf=True):
        """
        Configure the readout buffers specified in this program.
        This is usually called as part of an acquire() method.

        :param soc: the QickSoc that will execute this program
        :type soc: QickSoc
        :param enable_avg: enable the accumulated (averaging) buffer
        :type enable_avg: bool
        :param enable_buf: enable the decimated (waveform) buffer
        :type enable_buf: bool
        """
        for ch, cfg in self.ro_chs.items():
            if enable_avg:
                soc.config_avg(ch, address=0, length=cfg.length, enable=True)
            if enable_buf:
                soc.config_buf(ch, address=0, length=cfg.length, enable=True)

    def declare_gen(self, ch, nqz=1, mixer_freq=0, mux_freqs=None, ro_ch=None):
        """
        Add a channel to the program's list of signal generators.

        :param ch: Generator channel number (index in 'gens' list)
        :type ch: int
        :param nqz: Nyquist zone for the DAC
        :type nqz: int
        :param mixer_freq: mixer frequency (if applicable; use 0 if there's no mixer on this DAC)
        :type mixer_freq: float
        :param mux_freqs: list up to 4 output frequencies - only used for mux generator
        :type mux_freqs: list
        :param ro_ch: ADC channel (use None if you don't want to round to a valid ADC frequency) - only used for mux generator and mixer
        :type ro_ch: int
        """
        self.gen_chs[ch] = GeneratorConfig(nqz, mixer_freq, mux_freqs, ro_ch)

    def config_gens(self, soc):
        """
        Configure the signal generators specified in this program.
        This is usually called as part of an acquire() method.

        :param soc: the QickSoc that will execute this program
        :type soc: QickSoc
        """
        for ch, cfg in self.gen_chs.items():
            soc.set_nyquist(ch, cfg.nqz)
            soc.set_mixer_freq(ch, cfg.mixer_freq, cfg.ro_ch)
            if cfg.mux_freqs is not None:
                soc.set_mux_freqs(ch, cfg.mux_freqs)

    def add_pulse(self, ch, name, idata=None, qdata=None):
        """
        Adds a pulse to the pulse library within the program.

        :param ch: DAC channel (index in 'gens' list)
        :type ch: int
        :param name: Name of the pulse
        :type name: str
        :param idata: I data Numpy array
        :type idata: array
        :param qdata: Q data Numpy array
        :type qdata: array
        """
        if qdata is None and idata is None:
            raise RuntimeError("Error: no data argument was supplied")
        if qdata is None:
            qdata = np.zeros(len(idata))
        if idata is None:
            idata = np.zeros(len(qdata))
        if len(idata) != len(qdata):
            raise RuntimeError("Error: I and Q pulse lengths must be equal")
        samps_per_clk = self.soccfg['gens'][ch]['samps_per_clk']
        if (len(idata) % samps_per_clk) != 0:
            raise RuntimeError("Error: pulse lengths must be an integer multiple of %d"%(samps_per_clk))

        self.channels[ch]["pulses"][name] = {
            "idata": idata, "qdata": qdata, "addr": self.channels[ch]['addr']}
        self.channels[ch]["addr"] += len(idata)

    def load_pulses(self, soc):
        """
        Loads pulses that were added using add_pulse into the SoC's signal generator memories.

        :param soc: Qick object
        :type soc: Qick object
        """
        for ch in self.channels.keys():
            for name, pulse in self.channels[ch]['pulses'].items():
                idata = pulse['idata']
                qdata = pulse['qdata']
                soc.load_pulse_data(
                    ch, idata=idata, qdata=qdata, addr=pulse['addr'])

    def ch_page(self, ch):
        """
        Gets tProc register page associated with channel.
        Page 0 gets one DAC channel because it also has some other registers.
        Other pages get two DACs each.

        :param ch: DAC channel (index in 'gens' list)
        :type ch: int
        :return: tProc page number
        :rtype: int
        """
        return (ch+1)//2

    def sreg(self, ch, name):
        """
        Gets tProc special register number associated with a channel and register name.

        :param ch: DAC channel (index in 'gens' list)
        :type ch: int
        :param name: Name of special register ("gain", "freq")
        :type name: str
        :return: tProc special register number
        :rtype: int
        """
        n_regs = len(self.pulse_registers)
        return 31 - (n_regs * 2) + n_regs*((ch+1)%2) + self.pulse_registers.index(name)

    def set_pulse_registers(self, ch, style, **kwargs):
        #waveform=None, freq=None, phase=None, gain=None, phrst=None, stdysel=None, mode=None, outsel=None, length=None):
        """
        A macro to set the pulse parameters including frequency, phase, address of pulse, gain, stdysel, mode register (compiled from length and other flags), outsel, and length.
        The time is scheduled when you call pulse().

        Not all generators and pulse styles support all parameters - see the style-specific methods for more info.

        :param ch: DAC channel (index in 'gens' list)
        :type ch: int
        :param style: Pulse style ("const", "arb", "flat_top")
        :type style: string
        :param waveform: Name of the envelope waveform loaded with add_pulse()
        :type waveform: string
        :param freq: Frequency (register value)
        :type freq: int
        :param phase: Phase (register value)
        :type phase: int
        :param gain: Gain (DAC units)
        :type gain: int
        :param phrst: If 1, it resets the phase coherent accumulator
        :type phrst: int
        :param stdysel: Selects what value is output continuously by the signal generator after the generation of a pulse. If "last", it is the last calculated sample of the pulse. If "zero", it is a zero value.
        :type stdysel: string
        :param mode: Selects whether the output is "oneshot" or "periodic"
        :type mode: string
        :param outsel: Selects the output source. The output is complex. Tables define envelopes for I and Q. If "product", the output is the product of table and DDS. If "dds", the output is the DDS only. If "input", the output is from the table for the real part, and zeros for the imaginary part. If "zero", the output is always zero.
        :type outsel: string
        :param length: The number of fabric clock cycles in the const portion of the pulse
        :type length: int
        :param mask: for a muxed signal generator, the list of tones to enable for this pulse
        :type mask: list
        """
        f = {'const': self.const_pulse, 'arb': self.arb_pulse,
                     'flat_top': self.flat_top_pulse}[style]
        return f(ch, **kwargs)


    def const_pulse(self, ch, freq=None, phase=None, gain=None, phrst=None, stdysel=None, mode=None, length=None, mask=None):
        """
        Configure a constant (rectangular) pulse.

        There is no outsel setting for this pulse style; "dds" is always used.

        This is the only style supported by the muxed signal generator, which only takes length and mask arguments (frequency is set at program initialization).

        :param ch: DAC channel (index in 'gens' list)
        :type ch: int
        :param freq: Frequency (register value)
        :type freq: int
        :param phase: Phase (register value)
        :type phase: int
        :param gain: Gain (DAC units)
        :type gain: int
        :param phrst: If 1, it resets the phase coherent accumulator
        :type phrst: int
        :param stdysel: Selects what value is output continuously by the signal generator after the generation of a pulse. If "last", it is the last calculated sample of the pulse. If "zero", it is a zero value.
        :type stdysel: string
        :param mode: Selects whether the output is "oneshot" or "periodic".
        :type mode: string
        :param length: The number of fabric clock cycles in the const portion of the pulse
        :type length: int
        :param mask: for a muxed signal generator, the list of tones to enable for this pulse
        :type mask: list
        """
        p = self
        gen_type = self.soccfg['gens'][ch]['type']
        rp = self.ch_page(ch)

        last_pulse = {}
        self.channels[ch]['last_pulse'] = last_pulse
        last_pulse['rp'] = rp
        last_pulse['regs'] = []

        # set the pulse duration
        last_pulse['length'] = length

        r_e, r_d, r_c, r_b, r_a = [p.sreg(ch,x) for x in ['freq', 'phase', 'addr', 'gain', 'mode']]

        if gen_type in ['axis_signal_gen_v4','axis_signal_gen_v5']:
            p.safe_regwi(rp, r_e, freq, f'freq = {freq}')
            p.safe_regwi(rp, r_d, phase, f'phase = {phase}')
            p.regwi(rp, r_b, gain, f'gain = {gain}')

            mc = p.get_mode_code(phrst=phrst, stdysel=stdysel,
                                 mode=mode, outsel="dds", length=length)
            p.regwi(
                rp, r_a, mc, f'stdysel | mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
            last_pulse['regs'].append((r_e, r_d, 0, r_b, r_a))
        elif gen_type == 'axis_sg_int4_v1':
            if stdysel is not None or phrst is not None:
                raise RuntimeError(gen_type, "does not support stdysel and phrst options")
            p.safe_regwi(rp, r_e, (phase << 16) | freq, f'phase = {phase} | freq = {freq}')
            p.safe_regwi(rp, r_d, (gain << 16), f'gain = {gain}')
            mc = p.get_mode_code(mode=mode, outsel="dds", length=length)
            p.regwi(
                rp, r_c, mc, f'mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
            last_pulse['regs'].append((r_e, r_d, r_c, 0, 0))
        elif gen_type == 'axis_sg_mux4_v1':
            if mask is None:
                raise RuntimeError("mask must be specified for mux generator")
            if any([x is not None for x in [stdysel, phrst, freq, phase, gain]]):
                raise RuntimeError(gen_type, "does not support specified options")
            p.safe_regwi(rp, r_e, length, f'length = {length}')
            val_mask = 0
            for maskch in mask:
                if maskch not in range(4):
                    raise RuntimeError("invalid mask specification")
                val_mask |= (1 << maskch)
            p.regwi(rp, r_d, val_mask, f'mask = {mask}')
            last_pulse['regs'].append((r_e, r_d, 0, 0, 0))
        else:
            raise RuntimeError("this is not a tProc-controlled signal generator:", gen_type)

    def arb_pulse(self, ch, waveform=None, freq=None, phase=None, gain=None, phrst=None, stdysel=None, mode=None, outsel=None):
        """
        Configure an arbitrary pulse, can autoschedule this based on previous pulses.

        :param ch: DAC channel (index in 'gens' list)
        :type ch: int
        :param waveform: Name of the envelope waveform loaded with add_pulse()
        :type waveform: string
        :param freq: Frequency (register value)
        :type freq: int
        :param phase: Phase (register value)
        :type phase: int
        :param gain: Gain (DAC units)
        :type gain: int
        :param phrst: If 1, it resets the phase coherent accumulator
        :type phrst: int
        :param stdysel: Selects what value is output continuously by the signal generator after the generation of a pulse. If "last", it is the last calculated sample of the pulse. If "zero", it is a zero value.
        :type stdysel: string
        :param mode: Selects whether the output is "oneshot" or "periodic".
        :type mode: string
        :param outsel: Selects the output source. The output is complex. Tables define envelopes for I and Q. If "product", the output is the product of table and DDS. If "dds", the output is the DDS only. If "input", the output is from the table for the real part, and zeros for the imaginary part. If "zero", the output is always zero.
        :type outsel: string
        """
        p = self
        gen_type = self.soccfg['gens'][ch]['type']
        samps_per_clk = self.soccfg['gens'][ch]['samps_per_clk']
        rp = self.ch_page(ch)

        last_pulse = {}
        self.channels[ch]['last_pulse'] = last_pulse
        last_pulse['rp'] = rp
        last_pulse['regs'] = []

        pinfo = self.channels[ch]['pulses'][waveform]

        addr = pinfo["addr"]//samps_per_clk
        wfm_length = len(pinfo["idata"])//samps_per_clk
        # set the pulse duration
        last_pulse['length'] = wfm_length

        r_e, r_d, r_c, r_b, r_a = [p.sreg(ch,x) for x in ['freq', 'phase', 'addr', 'gain', 'mode']]
        
        if gen_type in ['axis_signal_gen_v4','axis_signal_gen_v5']:
            p.safe_regwi(rp, r_e, freq, f'freq = {freq}')
            p.safe_regwi(rp, r_d, phase, f'phase = {phase}')
            p.regwi(rp, r_b, gain, f'gain = {gain}')

            p.regwi(rp, r_c, addr, f'addr = {addr}')
            mc = p.get_mode_code(phrst=phrst, stdysel=stdysel,
                                 mode=mode, outsel=outsel, length=wfm_length)
            p.regwi(
                rp, r_a, mc, f'stdysel | mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
            last_pulse['regs'].append((r_e, r_d, r_c, r_b, r_a))
        elif gen_type == 'axis_sg_int4_v1':
            if stdysel is not None or phrst is not None:
                raise RuntimeError(gen_type, "does not support stdysel and phrst options")
            p.safe_regwi(rp, r_e, (phase << 16) | freq, f'phase = {phase} | freq = {freq}')
            p.safe_regwi(rp, r_d, (gain << 16) | addr, f'gain = {gain} | addr = {addr}')
            mc = p.get_mode_code(mode=mode, outsel=outsel, length=wfm_length)
            p.regwi(
                rp, r_c, mc, f'mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
            last_pulse['regs'].append((r_e, r_d, r_c, 0, 0))
        else:
            raise RuntimeError("this generator does not support arb pulse:", gen_type)

    def flat_top_pulse(self, ch, waveform=None, freq=None, phase=None, gain=None, phrst=None, stdysel=None, mode=None, length=None):
        """
        Program a flattop pulse with arbitrary ramps.
        The waveform is played in three segments: ramp up, flat, and ramp down.
        To use these pulses one should use add_pulse to add the ramp waveform which should go from 0 to maxamp and back down to zero with the up and down having the same length, the first half will be used as the ramp up and the second half will be used as the ramp down.

        If the waveform is not of even length, the middle sample will be skipped.

        There is no outsel setting for this pulse style; the ramps always use "product" and the flat segment always uses "dds".

        :param ch: DAC channel (index in 'gens' list)
        :type ch: int
        :param waveform: Name of the envelope waveform loaded with add_pulse()
        :type waveform: string
        :param freq: Frequency (register value)
        :type freq: int
        :param phase: Phase (register value)
        :type phase: int
        :param gain: Gain (DAC units)
        :type gain: int
        :param phrst: If 1, it resets the phase coherent accumulator
        :type phrst: int
        :param stdysel: Selects what value is output continuously by the signal generator after the generation of a pulse. If "last", it is the last calculated sample of the pulse. If "zero", it is a zero value.
        :type stdysel: string
        :param mode: Selects whether the output is "oneshot" or "periodic".
        :type mode: string
        :param length: The number of fabric clock cycles in the const portion of the pulse
        :type length: int
        """
        p = self
        gen_type = self.soccfg['gens'][ch]['type']
        samps_per_clk = self.soccfg['gens'][ch]['samps_per_clk']
        rp = self.ch_page(ch)

        last_pulse = {}
        self.channels[ch]['last_pulse'] = last_pulse
        last_pulse['rp'] = rp
        last_pulse['regs'] = []

        pinfo = self.channels[ch]['pulses'][waveform]
        addr = pinfo["addr"]//samps_per_clk
        wfm_length = len(pinfo["idata"])//samps_per_clk
        # set the pulse duration
        last_pulse['length'] = wfm_length + length

        if gen_type in ['axis_signal_gen_v4','axis_signal_gen_v5']:
            r_e, r_d, r_c, r_b, r_a = [p.sreg(ch,x) for x in ['freq', 'phase', 'addr', 'gain', 'mode']]
            r_c2, r_b2, r_a2 = [p.sreg(ch,x) for x in ['addr2', 'gain2', 'mode2']]
            p.safe_regwi(rp, r_e, freq, f'freq = {freq}')
            p.safe_regwi(rp, r_d, phase, f'phase = {phase}')
            # gain for ramps
            p.regwi(rp, r_b, gain, f'gain = {gain}')

            # address for ramp-up
            p.regwi(rp, r_c, addr, f'addr = {addr}')
            # address for ramp-down
            p.regwi(rp, r_c2, addr+(wfm_length+1)//2, f'addr = {addr}')
            # gain for flat segment
            p.regwi(rp, r_b2, gain//2, f'gain = {gain}')
            # mode for flat segment
            mc = p.get_mode_code(phrst=phrst, stdysel=stdysel,
                                 mode=mode, outsel="dds", length=length)
            p.regwi(rp, r_a, mc, f'stdysel | mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
            # mode for ramps
            mc = p.get_mode_code(phrst=phrst, stdysel=stdysel,
                                 mode=mode, outsel="product", length=wfm_length//2)
            p.regwi(rp, r_a2, mc, f'stdysel | mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')

            last_pulse['regs'].append((r_e, r_d, r_c, r_b, r_a2))
            last_pulse['regs'].append((r_e, r_d, 0, r_b2, r_a))
            last_pulse['regs'].append((r_e, r_d, r_c2, r_b, r_a2))
        elif gen_type == 'axis_sg_int4_v1':
            if stdysel is not None or phrst is not None:
                raise RuntimeError(gen_type, "does not support stdysel and phrst options")
            # phase+freq
            r_e = p.sreg(ch,'freq')
            r_c, r_c2 = [p.sreg(ch,x) for x in ['mode', 'mode2']]
            # gain+addr
            r_d1, r_d2, r_d3 = [p.sreg(ch,x) for x in ['addr', 'gain', 'addr2']]

            p.safe_regwi(rp, r_e, (phase << 16) | freq, f'phase = {phase} | freq = {freq}')

            # mode for flat segment
            mc = p.get_mode_code(mode=mode, outsel="dds", length=length)
            p.regwi(rp, r_c, mc, f'stdysel | mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')
            # mode for ramps
            mc = p.get_mode_code(mode=mode, outsel="product", length=wfm_length//2)
            p.regwi(rp, r_c2, mc, f'stdysel | mode | outsel = 0b{mc//2**16:>05b} | length = {mc % 2**16} ')

            # gain+addr for ramp-up
            p.safe_regwi(rp, r_d1, (gain << 16) | addr, f'gain = {gain} | addr = {addr}')
            # gain+addr for flat
            p.safe_regwi(rp, r_d2, (gain//2 << 16), f'gain = {gain} | addr = {addr}')
            # gain+addr for ramp-down
            p.safe_regwi(rp, r_d3, (gain << 16) | addr+(wfm_length+1)//2, f'gain = {gain} | addr = {addr}')

            last_pulse['regs'].append((r_e, r_d1, r_c2, 0, 0))
            last_pulse['regs'].append((r_e, r_d2, r_c, 0, 0))
            last_pulse['regs'].append((r_e, r_d3, r_c2, 0, 0))
        else:
            raise RuntimeError("this generator does not support flat_top pulse:", gen_type)

    def pulse(self, ch, t='auto'):
        """
        Play the pulse currently programmed into the registers for this DAC channel.

        :param ch: DAC channel (index in 'gens' list)
        :type ch: int
        :param t: The number of clock ticks at which point the pulse starts (None to use the time register as is, 'auto' to start whenever the last pulse ends)
        :type t: int
        """
        rp = self.ch_page(ch)
        tproc_ch = self.soccfg['gens'][ch]['tproc_ch']
        last_pulse = self.channels[ch]['last_pulse']

        r_t = self.sreg(ch, 't')
        
        if t is not None:
            if t == 'auto':
                t = int(self.dac_ts[ch])
            elif t < self.dac_ts[ch]:
                print("Pulse time %d appears to conflict with previous pulse ending at %f?"%(t, dac_ts[ch]))
            # convert from generator clock to tProc clock
            pulse_length = last_pulse['length']
            pulse_length *= self.soccfg['fs_proc']/self.soccfg['gens'][ch]['f_fabric']
            self.dac_ts[ch] = t + pulse_length
            self.safe_regwi(rp, r_t, t, f't = {t}')

        # Play each pulse segment.
        # We specify the same time for all segments and rely on the signal generator to concatenate them without gaps.
        # We could specify the "correct" times, but it's difficult to get right when the tProc and generator clocks are different.
        for regs in last_pulse['regs']:
            self.set(tproc_ch, rp, *regs, r_t, f"ch = {ch}, pulse @t = ${r_t}")

    def safe_regwi(self, rp, reg, imm, comment=None):
        """
        Due to the way the instructions are setup immediate values can only be 30bits before not loading properly.
        This comes up mostly when trying to regwi values into registers, especially the _frequency_ and _phase_ pulse registers.
        safe_regwi can be used wherever one might use regwi and will detect if the value is >2**30 and if so will break it into two steps, putting in the first 30 bits shifting it over and then adding the last two.

        :param rp: Register page
        :type rp: int
        :param reg: Register number
        :type reg: int
        :param imm: Value of the write
        :type imm: int
        :param comment: Comment associated with the write
        :type comment: str
        """
        if abs(imm) < 2**30:
            self.regwi(rp, reg, imm, comment)
        else:
            self.regwi(rp, reg, imm >> 2, comment)
            self.bitwi(rp, reg, reg, "<<", 2)
            if imm % 4 != 0:
                self.mathi(rp, reg, reg, "+", imm % 4)

    def sync_all(self, t=0):
        """
        Aligns and syncs all channels with additional time t.
        Accounts for both DAC pulses and ADC readout windows.

        :param t: The time offset in clock ticks
        :type t: int
        """
        max_t = max(self.dac_ts+self.adc_ts)
        if max_t+t > 0:
            self.synci(int(max_t+t))
            self.dac_ts = [0]*len(self.dac_ts)
            self.adc_ts = [0]*len(self.adc_ts)

    # should change behavior to only change bits that are specified
    def marker(self, t, t1=0, t2=0, t3=0, t4=0, adc1=0, adc2=0, rp=0, r_out=31, short=True):
        """
        Sets the value of the marker bits at time t. This triggers the ADC(s) at a specified time t and also sends trigger values to 4 PMOD pins for syncing a scope trigger.
        Channel 0 of the tProc is connected to triggers/PMODs. E.g. if t3=1 PMOD0_2 goes high.

        :param t: The number of clock ticks at which point the pulse starts
        :type t: int
        :param t1: t1 - value of an external pin connected to the PMOD (PMOD0_0)
        :type t1: int
        :param t2: t2 - value of an external pin connected to the PMOD (PMOD0_1)
        :type t2: int
        :param t3: t3 - value of an external pin connected to the PMOD (PMOD0_2)
        :type t3: int
        :param t4: t4 - value of an external pin connected to the PMOD (PMOD0_3)
        :type t4: int
        :param adc1: 1 if ADC channel 0 is triggered; 0 otherwise.
        :type adc1: bool
        :param adc2: 1 if ADC channel 1 is triggered; 0 otherwise.
        :type adc2: bool
        :param rp: Register page
        :type rp: int
        :param r_out: Register number
        :type r_out: int
        :param short: If 1, plays a short marker pulse that is 5 clock ticks long
        :type short: bool
        """
        out = (adc2 << 15) | (adc1 << 14) | (
            t4 << 3) | (t3 << 2) | (t2 << 1) | (t1 << 0)
        # update timestamps with the end of the readout window
        for i, enable in enumerate([adc1, adc2]):
            if enable == 1:
                self.adc_ts[i] = t + self.ro_chs[i].length
        self.regwi(rp, r_out, out, f'out = 0b{out:>016b}')
        self.seti(0, rp, r_out, t, f'ch =0 out = ${r_out} @t = {t}')
        if short:
            self.regwi(rp, r_out, 0, f'out = 0b{out:>016b}')
            self.seti(0, rp, r_out, t+5, f'ch =0 out = ${r_out} @t = {t}')

    def trigger_adc(self, adc1=0, adc2=0, adc_trig_offset=270, t=0):
        """
        Triggers the ADC(s) at a specified time t+adc_trig_offset.

        :param adc1: 1 if ADC channel 0 is triggered; 0 otherwise.
        :type adc1: bool
        :param adc2: 1 if ADC channel 1 is triggered; 0 otherwise.
        :type adc2: bool
        :param adc_trig_offset: Offset time at which the ADC is triggered (in clock ticks)
        :type adc_trig_offset: int
        :param t: The number of clock ticks at which point the ADC trigger starts
        :type t: int
        """
        out = (adc2 << 15) | (adc1 << 14)
        # update timestamps with the end of the readout window
        for i, enable in enumerate([adc1, adc2]):
            if enable == 1:
                self.adc_ts[i] = adc_trig_offset + self.ro_chs[i].length
        r_out = 31
        self.regwi(0, r_out, out, f'out = 0b{out:>016b}')
        self.seti(0, 0, r_out, t+adc_trig_offset,
                  f'ch =0 out = ${r_out} @t = {t}')
        self.regwi(0, r_out, 0, f'out = 0b{0:>016b}')
        self.seti(0, 0, r_out, t+adc_trig_offset+10,
                  f'ch =0 out = ${r_out} @t = {t}')

    def trigger(self, adcs=None, pins=None, adc_trig_offset=270, t=0, width=10, rp=0, r_out=31):
        """
        Pulse the ADC(s) and marker pin(s) with a specified pulse width at a specified time t+adc_trig_offset.
        If no ADCs are specified, the adc_trig_offset is not applied.

        :param adcs: List of ADC channels to trigger.
        :type adcs: list
        :param pins: List of marker pins to pulse.
        :type pins: list
        :param adc_trig_offset: Offset time at which the ADC is triggered (in clock ticks)
        :type adc_trig_offset: int
        :param t: The number of clock ticks at which point the ADC trigger starts
        :type t: int
        :param width: The width of the trigger pulse, in clock ticks
        :type width: int
        :param rp: Register page
        :type rp: int
        :param r_out: Register number
        :type r_out: int
        """
        if adcs is None:
            adcs = []
        if pins is None:
            pins = []
        if not adcs and not pins:
            raise RuntimeError("must pulse at least one ADC or pin")

        out = 0
        for adc in adcs:
            out |= (1 << self.soccfg['readouts'][adc]['trigger_bit'])
        for pin in pins:
            out |= (1 << pin)

        t_start = t
        if adcs:
            t_start += adc_trig_offset
            # update timestamps with the end of the readout window
            for adc in adcs:
                if t_start < self.adc_ts[adc]:
                    print("Readout time %d appears to conflict with previous readout ending at %f?"%(t, adc_ts[adc]))
                # convert from readout clock to tProc clock
                ro_length = self.ro_chs[adc].length
                ro_length *= self.soccfg['fs_proc']/self.soccfg['readouts'][adc]['f_fabric']
                self.adc_ts[adc] = t_start + ro_length
        t_end = t_start + width

        trig_output = self.soccfg['tprocs'][0]['trig_output']

        self.regwi(rp, r_out, out, f'out = 0b{out:>016b}')
        self.seti(trig_output, rp, r_out, t_start, f'ch =0 out = ${r_out} @t = {t}')
        self.seti(trig_output, rp, 0, t_end, f'ch =0 out = 0 @t = {t}')

    def measure(self, adcs, pulse_ch, pins=None, adc_trig_offset=270, length=None, t='auto', wait=False, syncdelay=None):
        """
        Wrapper method that combines an ADC trigger, a pulse, and (optionally) the appropriate wait and a sync_all.

        If you use wait=True, it's recommended to also specify a nonzero syncdelay.

        :param adcs: ADC channels
        :type adcs: list
        :param pulse_ch: DAC channel
        :type pulse_ch: int
        :param pins: List of marker pins to pulse.
        :type pins: list
        :param adc_trig_offset: Offset time at which the ADC is triggered (in clock ticks)
        :type adc_trig_offset: int
        :param t: The number of clock ticks at which point the pulse starts
        :type t: int
        :param wait: Pause tProc execution until the end of the ADC readout window
        :type wait: bool
        :param syncdelay: The number of additional clock ticks to delay in the sync_all.
        :type syncdelay: int
        """
        self.trigger(adcs, pins=pins, adc_trig_offset=adc_trig_offset)
        self.pulse(ch=pulse_ch, t=t)
        if wait:
            # tProc should wait for the readout to complete.
            # This prevents loop counters from getting incremented before the data is available.
            self.waiti(0, int(max(self.adc_ts)))
        if syncdelay is not None:
            self.sync_all(syncdelay)

    def convert_immediate(self, val):
        """
        Convert the register value to ensure that it is positive and not too large. Throws an error if you ever try to use a value greater than 2**31 as an immediate value.

        :param val: Original register value
        :type val: int
        :return: Converted register value
        :rtype: int
        """
        if val > 2**31:
            raise RuntimeError(
                f"Immediate values are only 31 bits {val} > 2**31")
        if val < 0:
            return 2**31+val
        else:
            return val

    def compile_instruction(self, inst, debug=False):
        """
        Converts an assembly instruction into a machine bytecode.

        :param inst: Assembly instruction
        :type inst: dict
        :param debug: If True, debug mode is on
        :type debug: bool
        :return: Compiled instruction in binary
        :rtype: int
        """
        args = list(inst['args'])
        idef = self.__class__.instructions[inst['name']]
        fmt = idef['fmt']

        if debug:
            print(inst)

        if idef['type'] == "I":
            args[len(fmt)-1] = self.convert_immediate(args[len(fmt)-1])

        if inst['name'] == 'loopnz':
            args[-1] = self.labels[args[-1]]  # resolve label

        if inst['name'] == 'condj':
            args[4] = self.labels[args[4]]  # resolve label
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
        """
        Compiles program to machine code.

        :param debug: If True, debug mode is on
        :type debug: bool
        :return: List of binary instructions
        :rtype: list
        """
        return [self.compile_instruction(inst, debug=debug) for inst in self.prog_list]

    def load_program(self, soc, debug=False):
        """
        Load the compiled program into the tProcessor.

        :param debug: If True, debug mode is on
        :type debug: bool
        """
        soc.tproc.load_bin_program(self.compile(debug=debug))

    def get_mode_code(self, length, mode=None, outsel=None, stdysel=None, phrst=None):
        """
        Creates mode code for the mode register in the set command, by setting flags and adding the pulse length.

        :param length: The number of fabric clock cycles in the pulse
        :type length: int
        :param mode: Selects whether the output is "oneshot" or "periodic"
        :type mode: string
        :param outsel: Selects the output source. The output is complex. Tables define envelopes for I and Q. If "product", the output is the product of table and DDS. If "dds", the output is the DDS only. If "input", the output is from the table for the real part, and zeros for the imaginary part. If "zero", the output is always zero.
        :type outsel: string
        :param stdysel: Selects what value is output continuously by the signal generator after the generation of a pulse. If "last", it is the last calculated sample of the pulse. If "zero", it is a zero value.
        :type stdysel: string
        :param phrst: If 1, it resets the phase coherent accumulator
        :type phrst: int
        :return: Compiled mode code in binary
        :rtype: int
        """
        if mode is None: mode = "oneshot"
        if outsel is None: outsel = "product"
        if stdysel is None: stdysel = "zero"
        if phrst is None: phrst = 0
        stdysel_reg = {"last": 0, "zero": 1}[stdysel]
        mode_reg = {"oneshot": 0, "periodic": 1}[mode]
        outsel_reg = {"product": 0, "dds": 1, "input": 2, "zero": 3}[outsel]
        mc = phrst*0b10000+stdysel_reg*0b01000+mode_reg*0b00100+outsel_reg
        return mc << 16 | length

    def append_instruction(self, name, *args):
        """
        Append instruction to the program list

        :param name: Instruction name
        :type name: str
        :param *args: Instruction arguments
        :type *args: *args object
        """
        self.prog_list.append({'name': name, 'args': args})

    def label(self, name):
        """
        Add line number label to the labels dictionary. This labels the instruction by its position in the program list. The loopz and condj commands use this label information.

        :param name: Instruction name
        :type name: str
        """
        self.labels[name] = len(self.prog_list)

    def comment(self, comment):
        """
        Dummy function used for comments.

        :param comment: Comment
        :type comment: str
        """
        pass

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
        """
        Returns hex representation of program as string.

        :return: Compiled program in hex format
        :rtype: str
        """
        return "\n".join([format(mc, '#018x') for mc in self.compile()])

    def bin(self):
        """
        Returns binary representation of program as string.

        :return: Compiled program in binary format
        :rtype: str
        """
        return "\n".join([format(mc, '#066b') for mc in self.compile()])

    def asm(self):
        """
        Returns assembly representation of program as string, should be compatible with the parse_prog from the parser module.

        :return: asm file
        :rtype: str
        """
        if self.labels == {}:
            max_label_len = 0
        else:
            max_label_len = max([len(label) for label in self.labels.keys()])
        lines = []
        s = "\n// Program\n\n"
        for ii, inst in enumerate(self.prog_list):
            # print(inst)
            template = inst['name'] + " " + \
                self.__class__.instructions[inst['name']]['repr'] + ";"
            num_args = len(self.__class__.instructions[inst['name']]['fmt'])
            line = " "*(max_label_len+2) + template.format(*inst['args'])
            if len(inst['args']) > num_args:
                line += " "*(48-len(line)) + "//" + inst['args'][-1]
            lines.append(line)

        for label, jj in self.labels.items():
            lines[jj] = label + ": " + lines[jj][len(label)+2:]
        return s+"\n".join(lines)

    def compare_program(self, fname):
        """
        For debugging purposes to compare binary compilation of parse_prog with the compile.

        :param fname: File the comparison program is stored in
        :type fname: str
        :return: True if programs are identical; False otherwise
        :rtype: bool
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
