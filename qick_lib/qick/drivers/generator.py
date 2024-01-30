"""
Drivers for signal generators: FPGA blocks that send data to DACs.
"""
from pynq.buffer import allocate
import numpy as np
from qick import SocIp

class AbsSignalGen(SocIp):
    """
    Abstract class which defines methods that are common to different signal generators.
    """
    # The DAC channel has a mixer.
    HAS_MIXER = False
    # Waveform samples per fabric clock.
    SAMPS_PER_CLK = 1
    # Maximum waveform amplitude.
    MAXV = 2**15-2
    # Scale factor between MAXV and the default maximum amplitude (necessary to avoid overshoot).
    MAXV_SCALE = 1.0

    # Configure this driver with links to the other drivers, and the signal gen channel number.
    def configure(self, ch, rf):
        # Channel number corresponding to entry in the QickConfig list of gens.
        self.ch = ch

        # RF data converter
        self.rf = rf

        self.cfg['dac'] = self.dac

        for p in ['fs', 'fs_mult', 'fs_div', 'interpolation', 'f_fabric']:
            self.cfg[p] = self.rf.daccfg[self['dac']][p]
        # interpolation reduces the DDS range
        self.cfg['f_dds'] = self['fs']/self['interpolation']
        self.cfg['fdds_div'] = self['fs_div']*self['interpolation']

    def configure_connections(self, soc):
        self.soc = soc

        # what RFDC port does this generator drive?
        ((block, port),) = soc.metadata.trace_bus(self.fullpath, 'm_axis')
        # might need to jump through an axis_register_slice
        while True:
            blocktype = soc.metadata.mod2type(block)
            if blocktype == "usp_rf_data_converter": # we're done
                break
            elif blocktype == "axis_register_slice":
                ((block, port),) = soc.metadata.trace_bus(block, "M_AXIS")
            elif blocktype == "axis_register_slice_nb":
                ((block, port),) = soc.metadata.trace_bus(block, "m_axis")
            else:
                raise RuntimeError("failed to trace RFDC port for %s - ran into unrecognized IP block %s" % (self.fullpath, block))
        # port names are of the form 's00_axis'
        self.dac = port[1:3]

        #print("%s: switch %d, tProc ch %d, DAC tile %s block %s"%(self.fullpath, self.switch_ch, self.tproc_ch, *self.dac))

    def set_nyquist(self, nqz):
        """Set the Nyquist zone mode for the DAC linked to this generator.
        For tProc-controlled generators, this method is called automatically during program config.
        You should normally only call this method directly for a constant-IQ output.

        Parameters
        ----------
        nqz : int
            Nyquist zone (must be 1 or 2).
            Setting the NQZ to 2 increases output power in the 2nd/3rd Nyquist zones.
        """
        self.rf.set_nyquist(self.dac, nqz)

    def set_mixer_freq(self, f, ro_ch=None):
        """Set the mixer frequency for the DAC linked to this generator.
        For tProc-controlled generators, this method is called automatically during program config.
        You should normally only call this method directly for a constant-IQ output.

        Parameters
        ----------
        mixer_freq : float
            Mixer frequency (in MHz)
        ro_ch : int
            readout channel for frequency matching (use None if you don't want mixer freq to be rounded to a valid readout frequency)
        """
        if not self.HAS_MIXER:
            raise NotImplementedError("This channel does not have a mixer.")
        if ro_ch is None:
            rounded_f = f
        else:
            mixercfg = {}
            mixercfg['fs_mult'] = self['fs_mult']
            mixercfg['fdds_div'] = self['fs_div']
            mixercfg['b_dds'] = 48
            fstep = self.soc.calc_fstep(mixercfg, self.soc['readouts'][ro_ch])
            rounded_f = round(f/fstep)*fstep
        self.rf.set_mixer_freq(self.dac, rounded_f)

    def get_mixer_freq(self):
        if not self.HAS_MIXER:
            raise NotImplementedError("This channel does not have a mixer.")
        return self.rf.get_mixer_freq(self.dac)

class AbsArbSignalGen(AbsSignalGen):
    """
    A signal generator with a memory for envelope waveforms.
    """
    # Name of the input driven by the waveform DMA (if applicable).
    WAVEFORM_PORT = 's0_axis'

    def configure(self, ch, rf):
        # Define buffer.
        self.buff = allocate(shape=self.MAX_LENGTH, dtype=np.int32)

        super().configure(ch, rf)

    def configure_connections(self, soc):
        super().configure_connections(soc)

        # what switch port drives this generator?
        ((block, port),) = soc.metadata.trace_bus(self.fullpath, self.WAVEFORM_PORT)
        self.switch = getattr(soc, block)
        # port names are of the form 'M01_AXIS'
        self.switch_ch = int(port.split('_')[0][1:])
        ((block, port),) = soc.metadata.trace_bus(block, 'S00_AXIS')
        self.dma = getattr(soc, block)

    # Load waveforms.
    def load(self, xin, addr=0):
        """
        Load waveform into I,Q envelope

        :param xin: array of (I, Q) values for pulse envelope
        :type xin: int16 array
        :param addr: starting address
        :type addr: int
        """
        length = xin.shape[0]
        assert xin.dtype==np.int16

        # Check for max length.
        if length+addr > self.MAX_LENGTH:
            raise RuntimeError("%s: buffer length must be %d samples or less." %
                  (self.__class__.__name__, self.MAX_LENGTH))

        # Check for even transfer size.
        #if length % 2 != 0:
        #    raise RuntimeError("Buffer transfer length must be even number.")

        # Route switch to channel.
        self.switch.sel(mst=self.switch_ch)

        #print(self.fullpath, xin.shape, addr, self.switch_ch)

        # Pack the data into a single array; columns will be concatenated
        # -> lower 16 bits: I value.
        # -> higher 16 bits: Q value.
        # Format and copy data.
        np.copyto(self.buff[:length],
                np.frombuffer(xin, dtype=np.int32))

        ################
        ### Load I/Q ###
        ################
        # Enable writes.
        self._wr_enable(addr)

        # DMA data.
        self.dma.sendchannel.transfer(self.buff, nbytes=int(length*4))
        self.dma.sendchannel.wait()

        # Disable writes.
        self._wr_disable()

    def _wr_enable(self, addr=0):
        """
           Enable WE reg
        """
        self.start_addr_reg = addr
        self.we_reg = 1

    def _wr_disable(self):
        """
           Disable WE reg
        """
        self.we_reg = 0

class AbsPulsedSignalGen(AbsSignalGen):
    """
    A signal generator controlled by the TProcessor.
    """
    # Name of the input driven by the tProc (if applicable).
    TPROC_PORT = 's1_axis'

    def configure(self, ch, rf):
        super().configure(ch, rf)
        # DDS sampling frequency.
        self.cfg['maxlen'] = self.MAX_LENGTH
        self.cfg['b_dds'] = self.B_DDS
        self.cfg['switch_ch'] = self.switch_ch
        self.cfg['samps_per_clk'] = self.SAMPS_PER_CLK
        self.cfg['maxv'] = self.MAXV
        self.cfg['maxv_scale'] = self.MAXV_SCALE

    def configure_connections(self, soc):
        super().configure_connections(soc)

        # what tProc output port drives this generator?
        # we will eventually also use this to find out which tProc drives this gen, for multi-tProc firmwares
        ((block, port),) = soc.metadata.trace_bus(self.fullpath, self.TPROC_PORT)
        while True:
            blocktype = soc.metadata.mod2type(block)
            if blocktype in ["axis_tproc64x32_x8", "qick_processor"]: # we're done
                break
            elif blocktype == "axis_register_slice":
                ((block, port),) = soc.metadata.trace_bus(block, "S_AXIS")
            elif blocktype == "axis_clock_converter":
                ((block, port),) = soc.metadata.trace_bus(block, 'S_AXIS')
            elif blocktype == "axis_cdcsync_v1":
                # port name is of the form 'm4_axis' - follow corresponding input 's4_axis'
                ((block, port),) = soc.metadata.trace_bus(block, "s"+port[1:])
            elif blocktype == "sg_translator":
                ((block, port),) = soc.metadata.trace_bus(block, "s_tproc_axis")
            elif blocktype == "axis_tmux_v1":
                self.cfg['tmux_ch'] = self.port2ch(port)
                ((block, port),) = soc.metadata.trace_bus(block, "s_axis")
            else:
                raise RuntimeError("failed to trace tProc port for %s - ran into unrecognized IP block %s" % (self.fullpath, block))
        # ask the tproc to translate this port name to a channel number
        self.cfg['tproc_ch'],_ = getattr(soc, block).port2ch(port)

    def port2ch(self, portname):
        """
        Translate a port name to a channel number.
        Used in connection mapping.
        """
        # port names are of the form 'm2_axis' (for outputs) and 's2_axis (for inputs)
        # subtract 1 to get the output channel number (s0/m0 goes to the DMA)
        chtype = {'m':'output', 's':'input'}[portname[0]]
        return int(portname.split('_')[0][1:])

class AxisSignalGen(AbsArbSignalGen, AbsPulsedSignalGen):
    """
    AxisSignalGen class
    Supports AxisSignalGen V4+V5+V6, since they have the same software interface (ignoring registers that are not used)

    AXIS Signal Generator Registers.
    START_ADDR_REG

    WE_REG
    * 0 : disable writes.
    * 1 : enable writes.
    """
    bindto = ['user.org:user:axis_signal_gen_v4:1.0',
              'user.org:user:axis_signal_gen_v5:1.0',
              'user.org:user:axis_signal_gen_v6:1.0']
    REGISTERS = {'start_addr_reg': 0, 'we_reg': 1, 'rndq_reg': 2}
    SAMPS_PER_CLK = 16
    B_DDS = 32

    def __init__(self, description):
        """
        Constructor method
        """
        super().__init__(description)

        # Default registers.
        self.start_addr_reg = 0
        self.we_reg = 0
        self.rndq_reg = 10

        # Generics
        self.N = int(description['parameters']['N'])
        self.NDDS = int(description['parameters']['N_DDS'])

        # Maximum number of samples
        self.MAX_LENGTH = 2**self.N*self.NDDS

    def rndq(self, sel_):
        """
           TODO: remove this function. This functionality was removed from IP block.
        """
        self.rndq_reg = sel_

class AxisSgInt4V1(AbsArbSignalGen, AbsPulsedSignalGen):
    """
    AxisSgInt4V1

    The default max amplitude for this generator is 0.9 times the maximum of int16.
    This is necessary to prevent interpolation overshoot:
    the output of the interpolation filter may exceed the max value of the input points.
    (https://blogs.keysight.com/blogs/tech/rfmw.entry.html/2019/05/07/confronting_measurem-IBRp.html)
    The result of overshoot is integer overflow in the filter output and big negative spikes.
    If the input to the filter is a square pulse, the rising edge of the output overshoots by 10%.
    Therefore, scaling envelopes by 90% seems safe.

    AXIS Signal Generator with envelope x4 interpolation V1 Registers.
    START_ADDR_REG

    WE_REG
    * 0 : disable writes.
    * 1 : enable writes.
    """
    bindto = ['user.org:user:axis_sg_int4_v1:1.0']
    REGISTERS = {'start_addr_reg': 0, 'we_reg': 1}
    HAS_MIXER = True
    FS_INTERPOLATION = 4
    MAXV_SCALE = 0.9
    B_DDS = 16

    def __init__(self, description):
        """
        Constructor method
        """
        super().__init__(description)

        # Default registers.
        self.start_addr_reg = 0
        self.we_reg = 0

        # Generics
        self.N = int(description['parameters']['N'])
        self.NDDS = 4  # Fixed by design, not accesible.

        # Maximum number of samples
        # Table is interpolated. Length is given only by parameter N.
        self.MAX_LENGTH = 2**self.N


class AxisSgMux4V1(AbsPulsedSignalGen):
    """
    AxisSgMux4V1

    AXIS Signal Generator with 4 muxed outputs V1 registers.

    PINC0_REG : frequency of tone 0.
    PINC1_REG : frequency of tone 1.
    PINC2_REG : frequency of tone 2.
    PINC3_REG : frequency of tone 3.

    WE_REG
    * 0 : disable writes.
    * 1 : enable writes.
    """
    bindto = ['user.org:user:axis_sg_mux4_v1:1.0']
    REGISTERS = {'pinc0_reg': 0,
            'pinc1_reg': 1,
            'pinc2_reg': 2,
            'pinc3_reg': 3,
            'we_reg': 4}

    HAS_MIXER = True
    TPROC_PORT = 's_axis'
    B_DDS = 16

    def __init__(self, description):
        """
        Constructor method
        """
        super().__init__(description)

        # Generics
        self.NDDS = int(description['parameters']['N_DDS'])

        # dummy values, since this doesn't have a waveform memory.
        self.switch_ch = -1
        self.MAX_LENGTH = 0

        # Default registers.
        self.pinc0_reg = 0
        self.pinc1_reg = 0
        self.pinc2_reg = 0
        self.pinc3_reg = 0

        self.update()

    def update(self):
        """
        Update register values
        """
        self.we_reg = 1
        self.we_reg = 0

    def set_freq(self, f, out=0, ro_ch=0):
        """
        Set frequency register

        :param f: frequency in MHz
        :type f: float
        :param out: muxed channel to configure
        :type out: int
        :param ro_ch: ADC channel (use None if you don't want to round to a valid ADC frequency)
        :type ro_ch: int
        """
        # Sanity check.
        k_i = np.int64(self.soc.freq2reg(f, gen_ch=self.ch, ro_ch=ro_ch))
        self.set_freq_int(k_i, out)

    def set_freq_int(self, k_i, out=0):
        if out not in [0,1,2,3]:
            raise IndexError("Invalid output index for mux.")
        setattr(self, "pinc%d_reg" % (out), np.uint16(k_i))

        # Register update.
        self.update()

    def get_freq(self, out=0):
        return getattr(self, "pinc%d_reg" % (out)) * self['f_dds'] / (2**self.B_DDS)

class AxisSgMux4V2(AbsPulsedSignalGen):
    """
    AxisSgMux4V2

    AXIS Signal Generator with 4 muxed outputs V2 registers.

    PINC0_REG : frequency of tone 0.
    PINC1_REG : frequency of tone 1.
    PINC2_REG : frequency of tone 2.
    PINC3_REG : frequency of tone 3.
    GAIN0_REG : gain of tone 0.
    GAIN1_REG : gain of tone 1.
    GAIN2_REG : gain of tone 2.
    GAIN3_REG : gain of tone 3.

    WE_REG
    * 0 : disable writes.
    * 1 : enable writes.
    """
    bindto = ['user.org:user:axis_sg_mux4_v2:1.0']
    REGISTERS = {'pinc0_reg':0,
                 'pinc1_reg':1,
                 'pinc2_reg':2,
                 'pinc3_reg':3,
                 'gain0_reg':4,
                 'gain1_reg':5,
                 'gain2_reg':6,
                 'gain3_reg':7,
                 'we_reg':8}

    HAS_MIXER = True
    B_DDS = 32
    TPROC_PORT = 's_axis'

    def __init__(self, description):
        """
        Constructor method
        """
        super().__init__(description)

        # Generics
        self.NDDS = int(description['parameters']['N_DDS'])

        # dummy values, since this doesn't have a waveform memory.
        self.switch_ch = -1
        self.MAX_LENGTH = 0

        # Default registers.
        self.pinc0_reg=0
        self.pinc1_reg=0
        self.pinc2_reg=0
        self.pinc3_reg=0
        self.gain0_reg=self.MAXV
        self.gain1_reg=self.MAXV
        self.gain2_reg=self.MAXV
        self.gain3_reg=self.MAXV

        self.update()

    def update(self):
        """
        Update register values
        """
        self.we_reg = 1
        self.we_reg = 0

    def set_freq(self, f, out, ro_ch=0):
        """
        Set frequency register

        :param f: frequency in MHz
        :type f: float
        :param out: muxed channel to configure
        :type out: int
        :param ro_ch: ADC channel (use None if you don't want to round to a valid ADC frequency)
        :type ro_ch: int
        """
        k_i = np.int64(self.soc.freq2reg(f, gen_ch=self.ch, ro_ch=ro_ch))
        self.set_freq_int(k_i, out)

    def set_freq_int(self, k_i, out):
        if out not in range(4):
            raise IndexError("Invalid output index for mux.")
        setattr(self, "pinc%d_reg" % (out), np.uint32(k_i))

        # Register update.
        self.update()

    def get_freq(self, out):
        return getattr(self, "pinc%d_reg" % (out)) * self['f_dds'] / (2**self.B_DDS)

    def set_gain(self, g, out):
        """
        Set gain register

        :param g: gain (in range -1 to 1)
        :type g: float
        :param out: muxed channel to configure
        :type out: int
        """
        self.set_gain_int(np.round(g*self.MAXV), out)

    def set_gain_int(self, g_i, out):
        # Sanity checks.
        if out not in range(4):
            raise IndexError("Invalid output index for mux.")
        if np.abs(g_i)>self.MAXV:
            raise RuntimeError("Requested gain exceeds max limit.")
        setattr(self, "gain%d_reg" % (out), np.int16(g_i))

        # Register update.
        self.update()

class AxisSgMux4V3(AxisSgMux4V2):
    """AxisSgMux4V3: no digital mixer, but otherwise behaves identically to AxisSgMux4V2.
    """
    bindto = ['user.org:user:axis_sg_mux4_v3:1.0']
    HAS_MIXER = False

class AxisConstantIQ(AbsSignalGen):
    """Plays a constant IQ value, which gets mixed with the DAC's built-in oscillator.
    """
    # AXIS Constant IQ registers:
    # REAL_REG : 16-bit.
    # IMAG_REG : 16-bit.
    # WE_REG   : 1-bit. Update registers.
    bindto = ['user.org:user:axis_constant_iq:1.0']
    REGISTERS = {'real_reg': 0, 'imag_reg': 1, 'we_reg': 2}
    HAS_MIXER = True

    def __init__(self, description):
        # Initialize ip
        super().__init__(description)

        # Default registers.
        self.real_reg = self.MAXV
        self.imag_reg = self.MAXV

        # Register update.
        self.update()

    def update(self):
        self.we_reg = 1
        self.we_reg = 0

    def set_iq(self, i=1, q=1):
        """
        Set gain.

        Parameters
        ----------
        i : float
            signed gain, I component (in range -1 to 1)
        q : float
            signed gain, Q component (in range -1 to 1)
        """
        # Set registers.
        self.real_reg = np.int16(i*self.MAXV)
        self.imag_reg = np.int16(q*self.MAXV)

        # Register update.
        self.update()


