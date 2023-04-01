"""
The lower-level driver for the QICK library. Contains classes for interfacing with the SoC.
"""
import os
from pynq.overlay import Overlay, DefaultIP
from pynq.buffer import allocate
try:
    import xrfclk
    import xrfdc
except:
    pass
import numpy as np
import time
import queue
import logging
from .parser import parse_to_bin
from .streamer import DataStreamer
from .qick_asm import QickConfig, QickProgram, obtain
from .helpers import QickMetadata
from . import bitfile_path


class SocIp(DefaultIP):
    """
    SocIp class
    """
    REGISTERS = {}

    def __init__(self, description):
        """
        Constructor method
        """
        #print("SocIp init", description)
        super().__init__(description)
        self.fullpath = description['fullpath']
        self.type = description['type'].split(':')[-2]
        #self.ip = description
        self.logger = logging.getLogger(self.type)

    def __setattr__(self, a, v):
        """
        Sets the arguments associated with a register

        :param a: Register specified by an offset value
        :type a: int
        :param v: value to be written
        :type v: int
        """
        try:
            index = self.REGISTERS[a]
            self.mmio.array[index] = np.uint32(obtain(v))
        except KeyError:
            super().__setattr__(a, v)

    def __getattr__(self, a):
        """
        Gets the arguments associated with a register

        :param a: register name
        :type a: str
        :return: Register arguments
        :rtype: *args object
        """
        try:
            index = self.REGISTERS[a]
            return self.mmio.array[index]
        except KeyError:
            return super().__getattribute__(a)


class AbsSignalGen(SocIp):
    """
    Abstract class which defines methods that are common to different signal generators.
    """
    # This signal generator has a waveform memory.
    HAS_WAVEFORM = False
    # This signal generator is controlled by the tProc.
    HAS_TPROC = False
    # The DAC channel has a mixer.
    HAS_MIXER = False
    # Interpolation factor relating the generator and DAC sampling freqs.
    FS_INTERPOLATION = 1
    # Waveform samples per fabric clock.
    SAMPS_PER_CLK = 1
    # Name of the input driven by the tProc (if applicable).
    TPROC_PORT = 's1_axis'
    # Name of the input driven by the waveform DMA (if applicable).
    WAVEFORM_PORT = 's0_axis'
    # Maximum waveform amplitude.
    MAXV = 2**15-2
    # Scale factor between MAXV and the default maximum amplitude (necessary to avoid overshoot).
    MAXV_SCALE = 1.0

    # Configure this driver with links to the other drivers, and the signal gen channel number.
    def configure(self, ch, rf, fs, axi_dma=None, axis_switch=None):
        # Channel number corresponding to entry in the QickConfig list of gens.
        self.ch = ch

        if self.HAS_WAVEFORM:
            # dma
            self.dma = axi_dma

            # Switch
            self.switch = axis_switch

            # Define buffer.
            self.buff = allocate(shape=self.MAX_LENGTH, dtype=np.int32)

        # RF data converter
        self.rf = rf

        # DAC sampling frequency.
        self.fs_dac = fs

        # DDS sampling frequency.
        self.fs_dds = fs/self.FS_INTERPOLATION

    def configure_connections(self, soc):
        self.soc = soc

        if self.HAS_TPROC:
            # what tProc output port drives this generator?
            # we will eventually also use this to find out which tProc drives this gen, for multi-tProc firmwares
            ((block, port),) = soc.metadata.trace_bus(self.fullpath, self.TPROC_PORT)
            while True:
                blocktype = soc.metadata.mod2type(block)
                if blocktype in ["axis_tproc64x32_x8", "axis_tproc_v2"]: # we're done
                    break
                elif blocktype == "axis_clock_converter":
                    ((block, port),) = soc.metadata.trace_bus(block, 'S_AXIS')
                elif blocktype == "axis_cdcsync_v1":
                    # port name is of the form 'm4_axis' - follow corresponding input 's4_axis'
                    ((block, port),) = soc.metadata.trace_bus(block, "s"+port[1:])
                elif blocktype == "sg_translator":
                    ((block, port),) = soc.metadata.trace_bus(block, "s_tproc_axis")
                else:
                    raise RuntimeError("failed to trace tProc port for %s - ran into unrecognized IP block %s" % (self.fullpath, block))
            # ask the tproc to translate this port name to a channel number
            self.tproc_ch = getattr(soc, block).port2ch(port)

        if self.HAS_WAVEFORM:
            # what switch port drives this generator?
            ((block, port),) = soc.metadata.trace_bus(self.fullpath, self.WAVEFORM_PORT)
            # port names are of the form 'M01_AXIS'
            self.switch_ch = int(port.split('_')[0][1:])

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

    # Load waveforms.
    def load(self, xin, addr=0):
        """
        Load waveform into I,Q envelope

        :param xin: array of (I, Q) values for pulse envelope
        :type xin: int16 array
        :param addr: starting address
        :type addr: int
        """
        if not self.HAS_WAVEFORM:
            raise NotImplementedError(
                "This generator does not support waveforms.")

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

    def set_nyquist(self, nqz):
        self.rf.set_nyquist(self.dac, nqz)

    def set_mixer_freq(self, f, ro_ch=None):
        if not self.HAS_MIXER:
            raise NotImplementedError("This channel does not have a mixer.")
        if ro_ch is None:
            rounded_f = f
        else:
            mixercfg = {}
            mixercfg['fs'] = self.fs_dac
            mixercfg['b_dds'] = 48
            fstep = self.soc.calc_fstep(mixercfg, self.soc['readouts'][ro_ch])
            rounded_f = round(f/fstep)*fstep
        self.rf.set_mixer_freq(self.dac, rounded_f)

    def get_mixer_freq(self):
        if not self.HAS_MIXER:
            raise NotImplementedError("This channel does not have a mixer.")
        return self.rf.get_mixer_freq(self.dac)


class AxisSignalGen(AbsSignalGen):
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
    HAS_TPROC = True
    HAS_WAVEFORM = True
    SAMPS_PER_CLK = 16

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

        # Frequency resolution
        self.B_DDS = 32

    def rndq(self, sel_):
        """
           TODO: remove this function. This functionality was removed from IP block.
        """
        self.rndq_reg = sel_

class AxisSgInt4V1(AbsSignalGen):
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
    HAS_TPROC = True
    HAS_WAVEFORM = True
    HAS_MIXER = True
    FS_INTERPOLATION = 4
    MAXV_SCALE = 0.9

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

        # Frequency resolution
        self.B_DDS = 16

        # Maximum number of samples
        # Table is interpolated. Length is given only by parameter N.
        self.MAX_LENGTH = 2**self.N


class AxisSgMux4V1(AbsSignalGen):
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

    HAS_TPROC = True
    HAS_MIXER = True
    FS_INTERPOLATION = 4
    TPROC_PORT = 's_axis'

    def __init__(self, description):
        """
        Constructor method
        """
        super().__init__(description)

        # Generics
        self.NDDS = int(description['parameters']['N_DDS'])

        # Frequency resolution
        self.B_DDS = 16

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
        return getattr(self, "pinc%d_reg" % (out)) * self.fs_dds / (2**self.B_DDS)

class AxisSgMux4V2(AbsSignalGen):
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

    HAS_TPROC = True
    HAS_MIXER = True
    FS_INTERPOLATION = 4
    TPROC_PORT = 's_axis'

    def __init__(self, description):
        """
        Constructor method
        """
        super().__init__(description)

        # Generics
        self.NDDS = int(description['parameters']['N_DDS'])

        # Frequency resolution
        self.B_DDS = 32

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
        return getattr(self, "pinc%d_reg" % (out)) * self.fs_dds / (2**self.B_DDS)

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

class AxisConstantIQ(AbsSignalGen):
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
        # Set registers.
        self.real_reg = np.int16(i*self.MAXV)
        self.imag_reg = np.int16(q*self.MAXV)

        # Register update.
        self.update()


class AxisReadoutV2(SocIp):
    """
    AxisReadoutV2 class

    Registers.
    FREQ_REG : 32-bit.

    PHASE_REG : 32-bit.

    NSAMP_REG : 16-bit.

    OUTSEL_REG : 2-bit.
    * 0 : product.
    * 1 : dds.
    * 2 : input (bypass).

    MODE_REG : 1-bit.
    * 0 : NSAMP.
    * 1 : Periodic.

    WE_REG : enable/disable to perform register update.

    :param fs: sampling frequency in MHz
    :type fs: float
    """
    bindto = ['user.org:user:axis_readout_v2:1.0']
    REGISTERS = {'freq_reg': 0, 'phase_reg': 1, 'nsamp_reg': 2,
                 'outsel_reg': 3, 'mode_reg': 4, 'we_reg': 5}

    # Bits of DDS.
    B_DDS = 32

    # this readout is not controlled by the tProc.
    tproc_ch = None

    def __init__(self, description):
        """
        Constructor method
        """
        super().__init__(description)

        # Default registers.
        self.freq_reg = 0
        self.phase_reg = 0
        self.nsamp_reg = 10
        self.outsel_reg = 0
        self.mode_reg = 1

        # Register update.
        self.update()

    # Configure this driver with the sampling frequency.
    def configure(self, fs):
        # Sampling frequency.
        self.fs = fs

    def configure_connections(self, soc):
        self.soc = soc

        # what RFDC port drives this readout?
        ((block, port),) = soc.metadata.trace_bus(self.fullpath, 's_axis')
        # might need to jump through an axis_register_slice
        while soc.metadata.mod2type(block) == "axis_register_slice":
            ((block, port),) = soc.metadata.trace_bus(block, 'S_AXIS')
        # port names are of the form 'm02_axis' where the block number is always even
        iTile, iBlock = [int(x) for x in port[1:3]]
        if soc.hs_adc:
            iBlock //= 2
        self.adc = "%d%d" % (iTile, iBlock)

        # what buffer does this readout drive?
        ((block, port),) = soc.metadata.trace_bus(self.fullpath, 'm1_axis')
        self.buffer = getattr(soc, block)

        #print("%s: ADC tile %s block %s, buffer %s"%(self.fullpath, *self.adc, self.buffer.fullpath))

    def initialize(self):
        """
        Does nothing.
        """
        pass

    def update(self):
        """
        Update register values
        """
        self.we_reg = 1
        self.we_reg = 0

    def set_out(self, sel="product"):
        """
        Select readout signal output

        :param sel: select mux control
        :type sel: int
        """
        self.outsel_reg = {"product": 0, "dds": 1, "input": 2}[sel]

        # Register update.
        self.update()

    def set_freq(self, f, gen_ch=0):
        """
        Set frequency register

        :param f: frequency in MHz (before adding any DAC mixer frequency)
        :type f: float
        :param gen_ch: DAC channel (use None if you don't want to round to a valid DAC frequency)
        :type gen_ch: int
        """
        thiscfg = {}
        thiscfg['fs'] = self.fs
        thiscfg['b_dds'] = self.B_DDS
        # calculate the exact frequency we expect to see
        ro_freq = f
        if gen_ch is not None: # calculate the frequency that will be applied to the generator
            ro_freq = self.soc.roundfreq(f, self.soc['gens'][gen_ch], thiscfg)
        if gen_ch is not None and self.soc.gens[gen_ch].HAS_MIXER:
            ro_freq += self.soc.gens[gen_ch].get_mixer_freq()
        ro_freq = ro_freq % self.fs
        # we can calculate the register value without further referencing the gen_ch
        f_int = self.soc.freq2int(ro_freq, thiscfg)
        self.set_freq_int(f_int)

    def set_freq_int(self, f_int):
        """
        Set frequency register (integer version)

        :param f_int: frequency value register
        :type f_int: int
        """
        self.freq_reg = np.int64(f_int)

        # Register update.
        self.update()

    def get_freq(self):
        return self.freq_reg * self.fs / (2**self.B_DDS)

class AxisPFBReadoutV2(SocIp):
    """
    AxisPFBReadoutV2 class.

    This readout block contains a polyphase filter bank with 8 channels.
    Channel i mixes the input signal down by a fixed frequency f = i * fs/16,
    then by a programmable DDS with a range of +/- fs/16.

    The PFB channels can be freely mapped to the 4 outputs of the readout block.

    Registers.
    FREQ[0-7]_REG : 32-bit frequency of each channel.

    OUTSEL_REG : 2-bit.
    * 0 : product.
    * 1 : input (bypass).
    * 2 : dds.

    CH[0-3]SEL_REG : 3-bit ID mapping an output channel to an input.
    """
    bindto = ['user.org:user:axis_pfb_readout_v2:1.0']
    REGISTERS = {'freq0_reg': 0,
            'freq1_reg': 1,
            'freq2_reg': 2,
            'freq3_reg': 3,
            'freq4_reg': 4,
            'freq5_reg': 5,
            'freq6_reg': 6,
            'freq7_reg': 7,
            'outsel_reg': 8,
            'ch0sel_reg': 9,
            'ch1sel_reg': 10,
            'ch2sel_reg': 11,
            'ch3sel_reg': 12,
            }

    # Bits of DDS. 
    # The channelizer DDS range is 1/8 of the sampling frequency, which effectively adds 3 bits of resolution.
    B_DDS = 35

    # index of the PFB channel that is centered around DC.
    CH_OFFSET = 4

    # this readout is not controlled by the tProc.
    tproc_ch = None

    def __init__(self, description):
        """
        Constructor method
        """
        super().__init__(description)
        self.initialize()

    # Configure this driver with the sampling frequency.
    def configure(self, fs):
        # Sampling frequency.
        self.fs = fs

    def configure_connections(self, soc):
        self.soc = soc

        # what RFDC port drives this readout?
        ((block, port),) = soc.metadata.trace_bus(self.fullpath, 's_axis')
        # might need to jump through an axis_register_slice
        while soc.metadata.mod2type(block) == "axis_register_slice":
            ((block, port),) = soc.metadata.trace_bus(block, 'S_AXIS')
        if soc.metadata.mod2type(block) == "axis_combiner":
            ((block, port),) = soc.metadata.trace_bus(block, 'S00_AXIS')

        # port names are of the form 'm02_axis' where the block number is always even
        iTile, iBlock = [int(x) for x in port[1:3]]
        if soc.hs_adc:
            iBlock //= 2
        self.adc = "%d%d" % (iTile, iBlock)

        # what buffers does this readout drive?
        self.buffers=[]
        for iBuf in range(4):
            ((block, port),) = soc.metadata.trace_bus(self.fullpath, 'm%d_axis'%(iBuf))
            self.buffers.append(getattr(soc, block))

        #print("%s: ADC tile %s block %s, buffers[0] %s"%(self.fullpath, *self.adc, self.buffers[0].fullpath))

    def initialize(self):
        """
        Set up local variables to track definitions of frequencies or readout modes.
        """
        self.ch_freqs = {}
        self.sel = None
        self.out_chs = {}

    def set_out(self, sel="product"):
        """
        Select readout signal output

        :param sel: select mux control
        :type sel: int
        """
        if self.sel is not None and sel != self.sel:
            raise RuntimeError("trying to set output mode to %s, but mode was previously set to %s"%(sel, self.sel))
        self.sel = sel
        self.outsel_reg = {"product": 0, "input": 1, "dds": 2}[sel]

    def set_freq(self, f, out_ch, gen_ch=0):
        """
        Select the best PFB channel for reading out the requested frequency.
        Set that channel's frequency register, and wire that channel to the specified output of the PFB readout block.

        :param f: frequency in MHz (before adding any DAC mixer frequency)
        :type f: float
        :param out_ch: output channel
        :type out_ch: int
        :param gen_ch: DAC channel (use None if you don't want to round to a valid DAC frequency)
        :type gen_ch: int
        """
        thiscfg = {}
        thiscfg['fs'] = self.fs
        thiscfg['b_dds'] = self.B_DDS
        # calculate the exact frequency we expect to see
        ro_freq = f
        if gen_ch is not None: # calculate the frequency that will be applied to the generator
            ro_freq = self.soc.roundfreq(f, self.soc['gens'][gen_ch], thiscfg)
        if gen_ch is not None and self.soc.gens[gen_ch].HAS_MIXER:
            ro_freq += self.soc.gens[gen_ch].get_mixer_freq()

        nqz = int(ro_freq // (self.fs/2)) + 1
        if nqz % 2 == 0: # even Nyquist zone
            ro_freq *= -1
        # the PFB channels are separated by half the DDS range
        # round() gives you the single best channel
        # floor() and ceil() would give you the 2 best channels
        # if you have two RO frequencies close together, you might need to force one of them onto a non-optimal channel
        f_steps = int(np.round(ro_freq/(self.fs/16)))
        f_dds = ro_freq - f_steps*(self.fs/16)
        in_ch = (self.CH_OFFSET + f_steps) % 8

        # we can calculate the register value without further referencing the gen_ch
        freq_int = self.soc.freq2int(f_dds, thiscfg)
        self.set_freq_int(freq_int, in_ch, out_ch)

    def set_freq_int(self, f_int, in_ch, out_ch):
        if in_ch in self.ch_freqs and f_int != self.ch_freqs[in_ch]:
            # we are already using this PFB channel, and it's set to a different frequency
            # now do a bunch of math to print an informative message
            centerfreq = ((in_ch - self.CH_OFFSET) % 8) * (self.fs/16)
            lofreq = centerfreq - self.fs/32
            hifreq = centerfreq + self.fs/32
            thiscfg = {}
            thiscfg['fs'] = self.fs
            thiscfg['b_dds'] = self.B_DDS
            oldfreq = centerfreq + self.soc.int2freq(self.ch_freqs[in_ch], thiscfg)
            newfreq = centerfreq + self.soc.int2freq(f_int, thiscfg)
            raise RuntimeError("frequency collision: tried to set PFB output %d to %f MHz and output %d to %f MHz, but both map to the PFB channel that is optimal for [%f, %f] (all freqs expressed in first Nyquist zone)"%(out_ch, newfreq, self.out_chs[in_ch], oldfreq, lofreq, hifreq))
        self.ch_freqs[in_ch] = f_int
        self.out_chs[in_ch] = out_ch
        # wire the selected PFB channel to the output
        setattr(self, "ch%dsel_reg"%(out_ch), in_ch)
        # set the PFB channel's DDS frequency
        setattr(self, "freq%d_reg"%(in_ch), f_int)

class AxisReadoutV3():
    """tProc-controlled readout block.
    This isn't a PYNQ driver, since the block has no registers for PYNQ control.
    We still need this class to represent the block and its connectivity.
    """
    # Bits of DDS.
    B_DDS = 32

    def __init__(self, fullpath):
        self.fullpath = fullpath
        self.type = "axis_readout_v3"

    # Configure this driver with the sampling frequency.
    def configure(self, fs):
        # Sampling frequency.
        self.fs = fs

    def configure_connections(self, soc):
        self.soc = soc

        # what tProc output port controls this readout?
        ((block, port),) = soc.metadata.trace_bus(self.fullpath, 's0_axis')
        while True:
            blocktype = soc.metadata.mod2type(block)
            if blocktype == "axis_tproc64x32_x8": # we're done
                break
            elif blocktype == "axis_clock_converter":
                ((block, port),) = soc.metadata.trace_bus(block, 'S_AXIS')
            elif blocktype == "axis_cdcsync_v1":
                # port name is of the form 'm4_axis' - follow corresponding input 's4_axis'
                ((block, port),) = soc.metadata.trace_bus(block, "s"+port[1:])
            else:
                raise RuntimeError("failed to trace tProc port for %s - ran into unrecognized IP block %s" % (self.fullpath, block))
        # port names are of the form 'm2_axis_tdata'
        # subtract 1 to get the output channel number (m0 goes to the DMA)
        self.tproc_ch = int(port.split('_')[0][1:])-1

        # what RFDC port drives this readout?
        ((block, port),) = soc.metadata.trace_bus(self.fullpath, 's1_axis')
        while True:
            blocktype = soc.metadata.mod2type(block)
            if blocktype == "usp_rf_data_converter": # we're done
                break
            elif blocktype == "axis_resampler_2x1_v1":
                ((block, port),) = soc.metadata.trace_bus(block, 's_axis')
            elif blocktype == "axis_register_slice":
                ((block, port),) = soc.metadata.trace_bus(block, 'S_AXIS')
            elif blocktype == "axis_clock_converter":
                ((block, port),) = soc.metadata.trace_bus(block, 'S_AXIS')
            else:
                raise RuntimeError("failed to trace tProc port for %s - ran into unrecognized IP block %s" % (self.fullpath, block))

        # port names are of the form 'm02_axis' where the block number is always even
        iTile, iBlock = [int(x) for x in port[1:3]]
        if soc.hs_adc:
            iBlock //= 2
        self.adc = "%d%d" % (iTile, iBlock)

        # what buffer does this readout drive?
        ((block, port),) = soc.metadata.trace_bus(self.fullpath, 'm_axis')
        self.buffer = getattr(soc, block)

        #print("%s: ADC tile %s block %s, buffer %s"%(self.fullpath, *self.adc, self.buffer.fullpath))

class AxisAvgBuffer(SocIp):
    """
    AxisAvgBuffer class

    Registers.
    AVG_START_REG
    * 0 : Averager Disabled.
    * 1 : Averager Enabled (started by external trigger).

    AVG_ADDR_REG : start address to write results.

    AVG_LEN_REG : number of samples to be added.

    AVG_DR_START_REG
    * 0 : do not send any data.
    * 1 : send data using m0_axis.

    AVG_DR_ADDR_REG : start address to read data.

    AVG_DR_LEN_REG : number of samples to be read.

    BUF_START_REG
    * 0 : Buffer Disabled.
    * 1 : Buffer Enabled (started by external trigger).

    BUF_ADDR_REG : start address to write results.

    BUF_LEN_REG : number of samples to be buffered.

    BUF_DR_START_REG
    * 0 : do not send any data.
    * 1 : send data using m1_axis.

    BUF_DR_ADDR_REG : start address to read data.

    BUF_DR_LEN_REG : number of samples to be read.

    :param axi_dma_avg: dma block for average buffers
    :type axi_dma_avg: str
    :param switch_avg: switch block for average buffers
    :type switch_avg: str
    :param axi_dma_buf: dma block for raw buffers
    :type axi_dma_buf: str
    :param switch_buf: switch block for raw buffers
    :type switch_buf: str
    :param channel: readout channel selection
    :type channel: int
    """
    bindto = ['user.org:user:axis_avg_buffer:1.0']
    REGISTERS = {'avg_start_reg': 0,
                 'avg_addr_reg': 1,
                 'avg_len_reg': 2,
                 'avg_dr_start_reg': 3,
                 'avg_dr_addr_reg': 4,
                 'avg_dr_len_reg': 5,
                 'buf_start_reg': 6,
                 'buf_addr_reg': 7,
                 'buf_len_reg': 8,
                 'buf_dr_start_reg': 9,
                 'buf_dr_addr_reg': 10,
                 'buf_dr_len_reg': 11}

    def __init__(self, description):
        """
        Constructor method
        """
        super().__init__(description)

        # Default registers.
        self.avg_start_reg = 0
        self.avg_dr_start_reg = 0
        self.buf_start_reg = 0
        self.buf_dr_start_reg = 0

        # Generics
        self.B = int(description['parameters']['B'])
        self.N_AVG = int(description['parameters']['N_AVG'])
        self.N_BUF = int(description['parameters']['N_BUF'])

        # Maximum number of samples
        self.AVG_MAX_LENGTH = 2**self.N_AVG
        self.BUF_MAX_LENGTH = 2**self.N_BUF

        # Preallocate memory buffers for DMA transfers.
        self.avg_buff = allocate(shape=self.AVG_MAX_LENGTH, dtype=np.int64)
        self.buf_buff = allocate(shape=self.BUF_MAX_LENGTH, dtype=np.int32)

    # Configure this driver with links to the other drivers.
    def configure(self, axi_dma_avg, switch_avg, axi_dma_buf, switch_buf):
        # DMAs.
        self.dma_avg = axi_dma_avg
        self.dma_buf = axi_dma_buf

        # Switches.
        self.switch_avg = switch_avg
        self.switch_buf = switch_buf

    def configure_connections(self, soc):
        # which readout drives this buffer?
        ((block, port),) = soc.metadata.trace_bus(self.fullpath, 's_axis')
        blocktype = soc.metadata.mod2type(block)
        if blocktype == "axis_readout_v3":
            # the V3 readout block has no registers, so it doesn't get a PYNQ driver
            # so we initialize it here
            self.readout = AxisReadoutV3(block)
            self.readout.configure_connections(soc)
        else:
            self.readout = getattr(soc, block)
            if blocktype == "axis_pfb_readout_v2":
                # port names are of the form 'm1_axis'
                self.readoutport = int(port.split('_')[0][1:], 10)

        # which switch_avg port does this buffer drive?
        ((block, port),) = soc.metadata.trace_bus(self.fullpath, 'm0_axis')
        # port names are of the form 'S01_AXIS'
        switch_avg_ch = int(port.split('_')[0][1:], 10)

        # which switch_buf port does this buffer drive?
        ((block, port),) = soc.metadata.trace_bus(self.fullpath, 'm1_axis')
        # port names are of the form 'S01_AXIS'
        switch_buf_ch = int(port.split('_')[0][1:], 10)
        if switch_avg_ch != switch_buf_ch:
            raise RuntimeError(
                "switch_avg and switch_buf port numbers do not match:", self.fullpath)
        self.switch_ch = switch_avg_ch

        # which tProc output bit triggers this buffer?
        ((block, port),) = soc.metadata.trace_sig(self.fullpath, 'trigger')
        # port names are of the form 'dout14'
        self.trigger_bit = int(port[4:])

        # which tProc input port does this buffer drive?
        ((block, port),) = soc.metadata.trace_bus(self.fullpath, 'm2_axis')
        # jump through an axis_clk_cnvrt
        while soc.metadata.mod2type(block) == "axis_clock_converter":
            ((block, port),) = soc.metadata.trace_bus(block, 'M_AXIS')
        # port names are of the form 's1_axis'
        # subtract 1 to get the channel number (s0 comes from the DMA)
        if soc.metadata.mod2type(block) in ["axis_tproc64x32_x8", "axis_tproc_v2"]:
            # ask the tproc to translate this port name to a channel number
            self.tproc_ch = getattr(soc, block).port2ch(port)
        else:
            # this buffer doesn't feed back into the tProc
            self.tproc_ch = -1

        # print("%s: readout %s, switch %d, trigger %d, tProc port %d"%
        # (self.fullpath, self.readout.fullpath, self.switch_ch, self.trigger_bit, self.tproc_ch))

    def set_freq(self, f, gen_ch=0):
        """
        Set the downconversion frequency on the readout that drvies this buffer.

        :param f: frequency in MHz (before adding any DAC mixer frequency)
        :type f: float
        :param gen_ch: DAC channel (use None if you don't want to round to a valid DAC frequency)
        :type gen_ch: int
        """
        if isinstance(self.readout, AxisPFBReadoutV2):
            self.readout.set_freq(f, self.readoutport, gen_ch=gen_ch)
        else:
            self.readout.set_freq(f, gen_ch=gen_ch)

    def config(self, address=0, length=100):
        """
        Configure both average and raw buffers

        :param addr: Start address of first capture
        :type addr: int
        :param length: window size
        :type length: int
        """
        # Configure averaging and buffering to the same address and length.
        self.config_avg(address=address, length=length)
        self.config_buf(address=address, length=length)

    def enable(self):
        """
        Enable both average and raw buffers
        """
        # Enable both averager and buffer.
        self.enable_avg()
        self.enable_buf()

    def config_avg(self, address=0, length=100):
        """
        Configure average buffer data from average and buffering readout block

        :param addr: Start address of first capture
        :type addr: int
        :param length: window size
        :type length: int
        """
        # Disable averaging.
        self.disable_avg()

        # Set registers.
        self.avg_addr_reg = address
        self.avg_len_reg = length

    def transfer_avg(self, address=0, length=100):
        """
        Transfer average buffer data from average and buffering readout block.

        :param addr: starting reading address
        :type addr: int
        :param length: number of samples
        :type length: int
        :return: I,Q pairs
        :rtype: list
        """

        if length % 2 != 0:
            raise RuntimeError("Buffer transfer length must be even number.")
        if length >= self.AVG_MAX_LENGTH:
            raise RuntimeError("length=%d longer than %d" %
                               (length, self.AVG_MAX_LENGTH))

        # Route switch to channel.
        self.switch_avg.sel(slv=self.switch_ch)

        # Set averager data reader address and length.
        self.avg_dr_addr_reg = address
        self.avg_dr_len_reg = length

        # Start send data mode.
        self.avg_dr_start_reg = 1

        # DMA data.
        buff = self.avg_buff
        # nbytes has to be a Python int (it gets passed to mmio.write, which requires int or bytes)
        self.dma_avg.recvchannel.transfer(buff, nbytes=int(length*8))
        self.dma_avg.recvchannel.wait()

        # Stop send data mode.
        self.avg_dr_start_reg = 0

        if self.dma_avg.recvchannel.transferred != length*8:
            raise RuntimeError("Requested %d samples but only got %d from DMA" % (
                length, self.dma_avg.recvchannel.transferred//8))

        # Format:
        # -> lower 32 bits: I value.
        # -> higher 32 bits: Q value.
        data = np.frombuffer(buff[:length], dtype=np.int32).reshape((-1,2))

        # data is a view into the data buffer, so copy it before returning

        return data.copy()

    def enable_avg(self):
        """
        Enable average buffer capture
        """
        self.avg_start_reg = 1

    def disable_avg(self):
        """
        Disable average buffer capture
        """
        self.avg_start_reg = 0

    def config_buf(self, address=0, length=100):
        """
        Configure raw buffer data from average and buffering readout block

        :param addr: Start address of first capture
        :type addr: int
        :param length: window size
        :type length: int
        """
        # Disable buffering.
        self.disable_buf()

        # Set registers.
        self.buf_addr_reg = address
        self.buf_len_reg = length

    def transfer_buf(self, address=0, length=100):
        """
        Transfer raw buffer data from average and buffering readout block

        :param addr: starting reading address
        :type addr: int
        :param length: number of samples
        :type length: int
        :return: I,Q pairs
        :rtype: list
        """

        if length % 2 != 0:
            raise RuntimeError("Buffer transfer length must be even number.")
        if length >= self.BUF_MAX_LENGTH:
            raise RuntimeError("length=%d longer or equal to %d" %
                               (length, self.BUF_MAX_LENGTH))

        # Route switch to channel.
        self.switch_buf.sel(slv=self.switch_ch)

        # time.sleep(0.050)

        # Set buffer data reader address and length.
        self.buf_dr_addr_reg = address
        self.buf_dr_len_reg = length

        # Start send data mode.
        self.buf_dr_start_reg = 1

        # DMA data.
        buff = self.buf_buff
        # nbytes has to be a Python int (it gets passed to mmio.write, which requires int or bytes)
        self.dma_buf.recvchannel.transfer(buff, nbytes=int(length*4))
        self.dma_buf.recvchannel.wait()

        if self.dma_buf.recvchannel.transferred != length*4:
            raise RuntimeError("Requested %d samples but only got %d from DMA" % (
                length, self.dma_buf.recvchannel.transferred//4))

        # Stop send data mode.
        self.buf_dr_start_reg = 0

        # Format:
        # -> lower 16 bits: I value.
        # -> higher 16 bits: Q value.
        data = np.frombuffer(buff[:length], dtype=np.int16).reshape((-1,2))

        # data is a view into the data buffer, so copy it before returning
        return data.copy()

    def enable_buf(self):
        """
        Enable raw buffer capture
        """
        self.buf_start_reg = 1

    def disable_buf(self):
        """
        Disable raw buffer capture
        """
        self.buf_start_reg = 0


class MrBufferEt(SocIp):
    # Registers.
    # DW_CAPTURE_REG
    # * 0 : Capture disabled.
    # * 1 : Capture enabled (capture started by external trigger).
    #
    # DR_START_REG
    # * 0 : don't send.
    # * 1 : start sending data.
    #
    # DW_CAPTURE_REG needs to be de-asserted and asserted again to allow a new capture.
    # DR_START_REG needs to be de-assereted and asserted again to allow a new transfer.
    #
    bindto = ['user.org:user:mr_buffer_et:1.0']
    REGISTERS = {'dw_capture_reg': 0, 'dr_start_reg': 1}

    def __init__(self, description):
        # Init IP.
        super().__init__(description)

        # Default registers.
        self.dw_capture_reg = 0
        self.dr_start_reg = 0

        # Generics
        self.B = int(description['parameters']['B'])
        self.N = int(description['parameters']['N'])
        self.NM = int(description['parameters']['NM'])

        # Maximum number of samples
        self.MAX_LENGTH = 2**self.N * self.NM

        # Preallocate memory buffers for DMA transfers.
        #self.buff = allocate(shape=self.MAX_LENGTH, dtype=np.int32)
        self.buff = allocate(shape=self.MAX_LENGTH, dtype=np.int16)

    def config(self, dma, switch):
        self.dma = dma
        self.switch = switch

    def route(self, ch):
        # Route switch to channel.
        self.switch.sel(slv=ch)

    def transfer(self, buff=None):
        if buff is None:
            buff = self.buff
        # Start send data mode.
        self.dr_start_reg = 1

        # DMA data.
        self.dma.recvchannel.transfer(buff)
        self.dma.recvchannel.wait()

        # Stop send data mode.
        self.dr_start_reg = 0

        return buff

    def enable(self):
        self.dw_capture_reg = 1

    def disable(self):
        self.dw_capture_reg = 0


class AxisTProc64x32_x8(SocIp):
    """
    AxisTProc64x32_x8 class

    AXIS tProcessor registers:
    START_SRC_REG
    * 0 : internal start (using START_REG)
    * 1 : external start (using "start" input)

    Regardless of the START_SRC, the start logic triggers on a rising edge:
    A low level arms the trigger (transitions from "end" to "init" state).
    A high level fires the trigger (starts the program).
    To stop a running program, see reset().

    START_REG
    * 0 : init
    * 1 : start

    MEM_MODE_REG
    * 0 : AXIS Read (from memory to m0_axis)
    * 1 : AXIS Write (from s0_axis to memory)

    MEM_START_REG
    * 0 : Stop.
    * 1 : Execute operation (AXIS)

    MEM_ADDR_REG : starting memory address for AXIS read/write mode.

    MEM_LEN_REG : number of samples to be transferred in AXIS read/write mode.

    DMEM: The internal data memory is 2^DMEM_N samples, 32 bits each.
    The memory can be accessed either single read/write from AXI interface. The lower 256 Bytes are reserved for registers.
    The memory is then accessed in the upper section (beyond 256 bytes). Byte to sample conversion needs to be performed.
    The other method is to DMA in and out. Here the access is direct, so no conversion is needed.
    There is an arbiter to ensure data coherency and avoid blocking transactions.

    :param mem: memory address
    :type mem: int
    :param axi_dma: axi_dma address
    :type axi_dma: int
    """
    bindto = ['user.org:user:axis_tproc64x32_x8:1.0']
    REGISTERS = {'start_src_reg': 0,
                 'start_reg': 1,
                 'mem_mode_reg': 2,
                 'mem_start_reg': 3,
                 'mem_addr_reg': 4,
                 'mem_len_reg': 5}

    # Number of 32-bit words in the lower address map (reserved for register access)
    NREG = 64

    def __init__(self, description):
        """
        Constructor method
        """
        super().__init__(description)

        # Default registers.
        # start_src_reg = 0   : internal start.
        # start_reg     = 0   : stopped.
        # mem_mode_reg  = 0   : axis read.
        # mem_start_reg = 0   : axis operation stopped.
        # mem_addr_reg  = 0   : start address = 0.
        # mem_len_reg   = 100 : default length.
        self.start_src_reg = 0
        self.start_reg = 0
        self.mem_mode_reg = 0
        self.mem_start_reg = 0
        self.mem_addr_reg = 0
        self.mem_len_reg = 100

        # Generics.
        # data memory address size (log2 of the number of 32-bit words)
        self.DMEM_N = int(description['parameters']['DMEM_N'])
        # program memory address size (log2 of the number of 64-bit words, though the actual memory is usually smaller)
        self.PMEM_N = int(description['parameters']['PMEM_N'])

    # Configure this driver with links to its memory and DMA.
    # TODO: is this "mem" argument actually used? we are not setting it to anything sensible.
    def configure(self, mem, axi_dma):
        # Program memory.
        self.mem = mem

        # dma
        self.dma = axi_dma

    def configure_connections(self, soc):
        self.output_pins = []
        self.start_pin = None
        try:
            ((port),) = soc.metadata.trace_sig(self.fullpath, 'start')
            # check if the start pin is driven by a port of the top-level design
            if len(port)==1:
                self.start_pin = port[0]
        except:
            pass
        # search for the trigger port
        for i in range(8):
            # what block does this output drive?
            # add 1, because output 0 goes to the DMA
            try:
                ((block, port),) = soc.metadata.trace_bus(self.fullpath, 'm%d_axis' % (i+1))
            except: # skip disconnected tProc outputs
                continue
            if soc.metadata.mod2type(block) == "axis_set_reg":
                self.trig_output = i
                ((block, port),) = soc.metadata.trace_sig(block, 'dout')
                for iPin in range(16):
                    try:
                        ports = soc.metadata.trace_sig(block, "dout%d"%(iPin))
                        if len(ports)==1 and len(ports[0])==1:
                            # it's an FPGA pin, save it
                            pinname = ports[0][0]
                            self.output_pins.append((iPin, pinname))
                    except KeyError:
                        pass

    def port2ch(self, portname):
        """
        Translate a port name to a channel number.
        Used in connection mapping.
        """
        # port names are of the form 'm2_axis' (for outputs) and 's2_axis (for inputs)
        # subtract 1 to get the output channel number (s0/m0 goes to the DMA)
        return int(portname.split('_')[0][1:])-1

    def start(self):
        """
        Start tProc from register.
        This has no effect if the tProc is not in init or end state,
        or if the start source is set to "external."
        """
        self.start_reg = 0
        self.start_reg = 1

    def reset(self):
        """
        Force the tProc to stop by filling the program memory with "end" instructions.
        For speed, we hard-code the "end" instruction and write directly to the program memory.
        This typically takes about 1 ms.
        """
        # we only write the high half of each program word, the low half doesn't matter
        np.copyto(self.mem.mmio.array[1::2],np.uint32(0x3F000000))

    def single_read(self, addr):
        """
        Reads one sample of tProc data memory using AXI access

        :param addr: reading address
        :type addr: int
        :return: requested value
        :rtype: int
        """
        # Read data.
        # Address should be translated to upper map.
        return self.mmio.array[addr + self.NREG]

    def single_write(self, addr=0, data=0):
        """
        Writes one sample of tProc data memory using AXI access

        :param addr: writing address
        :type addr: int
        :param data: value to be written
        :type data: int
        """
        # Write data.
        # Address should be translated to upper map.
        self.mmio.array[addr + self.NREG] = np.uint32(data)

    def load_dmem(self, buff_in, addr=0):
        """
        Writes tProc data memory using DMA

        :param buff_in: Input buffer
        :type buff_in: int
        :param addr: Starting destination address
        :type addr: int
        """
        # Length.
        length = len(buff_in)

        # Configure dmem arbiter.
        self.mem_mode_reg = 1
        self.mem_addr_reg = addr
        self.mem_len_reg = length

        # Define buffer.
        self.buff = allocate(shape=length, dtype=np.int32)

        # Copy buffer.
        np.copyto(self.buff, buff_in)

        # Start operation on block.
        self.mem_start_reg = 1

        # DMA data.
        self.dma.sendchannel.transfer(self.buff)
        self.dma.sendchannel.wait()

        # Set block back to single mode.
        self.mem_start_reg = 0

    def read_dmem(self, addr=0, length=100):
        """
        Reads tProc data memory using DMA

        :param addr: Starting address
        :type addr: int
        :param length: Number of samples
        :type length: int
        :return: List of memory data
        :rtype: list
        """
        # Configure dmem arbiter.
        self.mem_mode_reg = 0
        self.mem_addr_reg = addr
        self.mem_len_reg = length

        # Define buffer.
        buff = allocate(shape=length, dtype=np.int32)

        # Start operation on block.
        self.mem_start_reg = 1

        # DMA data.
        self.dma.recvchannel.transfer(buff)
        self.dma.recvchannel.wait()

        # Set block back to single mode.
        self.mem_start_reg = 0

        return buff

    class AxisTProc_v2(SocIp):
        """
        AxisTProc_v2 class
     
        AXIS tProcessor registers:
        TPROC_CTRL       Write / Read 32-Bits
        RAND             Read Only    32-Bits
        TPROC_CFG        Write / Read  2-Bits
        MEM_ADDR         Write / Read 16-Bits
        MEM_LEN          Write / Read 16-Bits
        MEM_DT_I         Write / Read 32-Bits
        TPROC_EXT_DT1_I  Write / Read 32-Bits
        TPROC_EXT_DT2_I  Write / Read 32-Bits
        PORT_LSW         Read Only    32-Bits
        PORT_MSW         Read Only    32-Bits
        TIME_USR         Read Only    32-Bits
        TPROC_EXT_DT1_O  Read Only    32-Bits
        TPROC_EXT_DT2_O  Read Only    32-Bits
        MEM_DT_O         Read Only    32-Bits
        TPROC_STATUS     Read Only    32-Bits
        TPROC_DEBUG      Read Only    32-Bits
     
        TPROC_CTRL[0] - Reset       : Reset the tProc
        TPROC_CTRL[1] - Stop        : Stop the tProc
        TPROC_CTRL[2] - Pause       : Pause the tProc(Time continue Running)
        TPROC_CTRL[3] - Freeze      : Freeze Time (tProc Runs, but time stops)
        TPROC_CTRL[4] - Play        : Starts / Continue running the tProc
        TPROC_CTRL[10] - COND_set   : Set External Condition Flag from
        TPROC_CTRL[11] - COND_clear : Clears External Condition Flag from
        TPROC_CFG[0] - START_REG
        * 0 : init
        * 1 : Start
        TPROC_CFG[1] - OPERATION_REG
        * 0 : Read
        * 1 : Write
        TPROC_CFG[3:2] - MEM_BANK_REG 
        * 0 : None Selected
        * 1 : Program memory 
        * 2 : Data Memory
        * 3 : WaveParam Memory
        TPROC_CFG[4] - SOURCE_REG
        * 0 : AXIS Operation     (Using MEM_ADDR, MEM_LEN, (s0_axis / m0_axis) )
        * 1 : REGISTER Operation (Using MEM_ADDR, (MEM_DT_I, MEM_DT_O) )
     
        MEM_ADDR : starting memory address for AXIS read/write mode.
     
        MEM_LEN : number of samples to be transferred in AXIS read/write mode.
     
        :param mem: memory address
        :type mem: int
        :param axi_dma: axi_dma address
        :type axi_dma: int
        """
        bindto = ['Fermi:user:axis_tproc_v2:2.0']
     
        REGISTERS = {
           'tproc_ctrl':0, 'rand':1, 'tproc_cfg':2,
           'mem_addr'  :3, 'mem_len'  :4, 'mem_dt_i':5, 'mem_dt_o':6,
           'tproc_ext_dt1_i':7 , 'tproc_ext_dt2_i':8,
           'port_lsw':9, 'port_msw':10, 'time_usr':11,
           'tproc_ext_dt1_o':12, 'tproc_ext_dt2_o':13,
           'tproc_status':14, 'tproc_debug':15,}
     
        def __init__(self, description):
            """
            Constructor method
            """
            super().__init__(description)

            # Parameters
            self.PMEM_SIZE = pow( 2, int(description['parameters']['PMEM_AW']) )
            self.DMEM_SIZE = pow( 2, int(description['parameters']['DMEM_AW']) )
            self.WMEM_SIZE = pow( 2, int(description['parameters']['WMEM_AW']) )
            self.DREG_QTY  = pow( 2, int(description['parameters']['REG_AW'])  )
            self.IN_PORT_QTY   = int(description['parameters']['IN_PORT_QTY'])
            self.OUT_DPORT_QTY = int(description['parameters']['OUT_DPORT_QTY'])
            self.OUT_WPORT_QTY = int(description['parameters']['OUT_WPORT_QTY'])
            self.LFSR      = int(description['parameters']['LFSR'])
            self.DIVIDER   = int(description['parameters']['DIVIDER'])
            self.ARITH     = int(description['parameters']['ARITH'])
            self.TIME_CMP  = int(description['parameters']['TIME_CMP'])
            self.TIME_READ = int(description['parameters']['TIME_READ'])
            
            # Initial Values 
            self.tproc_ctrl = 0
            self.tproc_cfg  = 0
            self.mem_addr   = 0
            self.mem_len    = 100
            self.mem_dt_i   = 0
            self.tproc_ext_dt1_i = 0
            self.tproc_ext_dt2_i = 0
            
            #COmpatible with previous Version
            self.DMEM_N = int(description['parameters']['DMEM_AW']) 

      
        # Configure this driver with links to its memory and DMA.
        def configure(self, mem, axi_dma):
            # Program memory.
            self.mem = mem
            # dma
            self.dma = axi_dma
     
        def configure_connections(self, soc):
            self.output_pins = []
            self.start_pin = None
            try:
                ((port),) = soc.metadata.trace_sig(self.fullpath, 'start')
                self.start_pin = port[0]
            except:
                pass
           # search for the trigger port
            for i in range(4):
                
                # what block does this output drive?
                # add 1, because output 0 goes to the DMA
                try:
                    ((block, port),) = soc.metadata.trace_sig(self.fullpath, 'port_%d_dt_o' % (i))
                except: # skip disconnected tProc outputs
                    continue
                if soc.metadata.mod2type(block).startswith("vect2bits"):
                    self.trig_output = i
                    for iPin in range(16):
                        try:
                            #print(iPin, trace_net(sigparser, block, "dout%d"%(iPin)))
                            ports = soc.metadata.trace_sig(block, "dout%d"%(iPin))
                            if len(ports)==1 and len(ports[0])==1:
                                # it's an FPGA pin, save it
                                pinname = ports[0][0]
                                self.output_pins.append((iPin, pinname))
                        except KeyError:
                            pass

        def port2ch(self, portname):
            """
            Translate a port name to a channel number.
            Used in connection mapping.
            """
            # port names are of the form 'm2_axis' (for outputs) and 's2_axis (for inputs)
            return int(portname.split('_')[0][1:])
                        
        def reset(self):
            self.logger.info('RESET')
            self.tproc_ctrl      = 1
        def stop(self):
            self.logger.info('STOP')
            self.tproc_ctrl      = 2
        def pause(self):
            self.logger.info('PAUSE')
            self.tproc_ctrl      = 4
        def freeze(self):
            self.logger.info('FREEZE')
            self.tproc_ctrl      = 8
        def run(self):
            self.logger.info('RUN')
            self.tproc_ctrl      = 16
        def set_cond(self):
            self.logger.info('RESET')
            self.tproc_ctrl      = 1024
        def clear_cond(self):
            self.logger.info('RESET')
            self.tproc_ctrl      = 2048
            
        def info(self):
            print(self)
            
        def __str__(self):
            lines = []
            lines.append('---------------------------------------------')
            lines.append(' TPROC V2 INFO ')
            lines.append('---------------------------------------------')
            for param in ["PMEM_SIZE", "DMEM_SIZE", "WMEM_SIZE", "DREG_QTY", "IN_PORT_QTY", "OUT_DPORT_QTY", "OUT_WPORT_QTY"]:
                lines.append("%-14s: %d" % (param, getattr(self, param)))
            lines.append("\nPeripherals:")
            for param in ["LFSR", "DIVIDER", "ARITH", "TIME_CMP", "TIME_READ"]:
                lines.append("%-14s: %s" % (param, ["NO", "YES"][getattr(self, param)]))
            return "\n".join(lines)

        def single_read(self, addr):
            """
            Reads one sample of tProc data memory using AXI access
           
            :param addr: reading address
            :type addr: int
            :return: requested value
            :rtype: int
            """
            # Read data.
            # Address should be translated to upper map.
            return self.mmio.array[addr + self.NREG]
     
        def single_write(self, addr=0, data=0):
            """
            Writes one sample of tProc data memory using AXI access
            
            :param addr: writing address
            :type addr: int
            :param data: value to be written
            :type data: int
            """
            # Write data.
            # Address should be translated to upper map.
            self.mmio.array[addr + self.NREG] = np.uint32(data)
     

        def load_mem(self,mem_sel, buff_in, addr=0):
            """
            Writes tProc Selected memory using DMA
            PARAMETERS> 
              mem_sel   : Destination Memory ( int PMEM=1, DMEM=2, WMEM=3 )
              buff_in   : Input buffer ( int )
              addr      : Starting destination address ( int )
            """
            # Length.
            length = len(buff_in)
            # Configure Memory arbiter. (Write MEM)
            self.mem_addr        = addr
            self.mem_len         = length

            # Define buffer.
            # TODO: pre-allocate buffer
            self.buff = allocate(shape=(length,8), dtype=np.int32)
            # Copy buffer.
            np.copyto(self.buff, buff_in)
            print(self.buff)
            #Start operation
            if (mem_sel==1):       # WRITE PMEM
                self.tproc_cfg       = 7
            elif (mem_sel==2):     # WRITE DMEM
                self.tproc_cfg       = 11
            elif (mem_sel==3):     # WRITE WMEM
                self.tproc_cfg       = 15
            else:
                raise RuntimeError('Destination Memeory error should be  PMEM=1, DMEM=2, WMEM=3 current Value : %d' % (mem_sel))

            # DMA data.
            self.dma.sendchannel.transfer(self.buff)
            self.dma.sendchannel.wait()
            
            # End Operation
            self.tproc_cfg       = 0

        
        
        def read_mem(self,mem_sel, addr=0, length=100):
            """
            Read tProc Selected memory using DMA
            PARAMETERS> 
              mem_sel   : Destination Memory ( int PMEM=1, DMEM=2, WMEM=3 )
              buff_in   : Input buffer ( int )
              addr      : Starting destination address ( int )
            """
        # Configure Memory arbiter. (Read DMEM)
            self.mem_addr        = addr
            self.mem_len         = length

            # Define buffer.
            # TODO: pre-allocate buffer
            buff_rd = allocate(shape=(length,8), dtype=np.int32)

            #Start operation
            if (mem_sel==1):       # READ PMEM
                self.tproc_cfg       = 5
            elif (mem_sel==2):     # READ DMEM
                self.tproc_cfg       = 9
            elif (mem_sel==3):     # READ WMEM
                self.tproc_cfg       = 13
            else:
                raise RuntimeError('Source Memeory error should be PMEM=1, DMEM=2, WMEM=3 current Value : %d' % (mem_sel))

            # DMA data.
            self.dma.recvchannel.transfer(buff_rd)
            self.dma.recvchannel.wait()
            
            # End Operation
            self.tproc_cfg       = 0      
            return buff_rd
        
        def Load_PMEM(self, p_mem):
            self.logger.info('Loading Program in PMEM')
            # Length.
            length = len(p_mem)
            # Configure Memory arbiter.
            self.mem_addr        = 0
            self.mem_len         = length
            # Define buffer.
            self.buff = allocate(shape=(length,8), dtype=np.int32)
            # Copy buffer.
            np.copyto(self.buff, p_mem)
            #Start operation
            self.tproc_cfg       = 7
            # DMA data.
            self.logger.debug('P1')
            self.dma.sendchannel.transfer(self.buff)
            self.logger.debug('P2')
            self.dma.sendchannel.wait()
            self.logger.debug('P3')
            # End Operation
            self.tproc_cfg       = 0
            
            #Read PROGRAM MEMORY
            # Configure Memory arbiter.
            self.mem_addr        = 0
            self.mem_len         = length
            self.tproc_cfg       = 5
            # DMA data.
            self.logger.debug('P4')
            self.dma.recvchannel.transfer(self.buff)
            self.logger.debug('P5')
            self.dma.recvchannel.wait()
            self.logger.debug('P6')
            # End Operation
            self.tproc_cfg       = 0      
            
            if ( (np.max(self.buff - p_mem) )  == 0):
                self.logger.info('Program Loaded OK')
            else:
                self.logger.error('Error Loading Program')

            
        def getALL(self):
            print(self.status_axi())

        def status_axi(self):
            lines = []
            lines.append('---------------------------------------------')
            lines.append('--- AXI Registers')
            for param in ["tproc_ctrl",
                    "tproc_cfg",
                    "rand",
                    "mem_addr",
                    "mem_len",
                    "mem_dt_i",
                    "mem_dt_o",
                    "port_lsw",
                    "port_msw",
                    "tproc_ext_dt1_i",
                    "tproc_ext_dt2_i",
                    "tproc_ext_dt1_o",
                    "tproc_ext_dt2_o",
                    "time_usr"]:
                lines.append("%-16s: %d" % (param.upper(), getattr(self, param)))
            lines.append('TPROC_STATUS : {0:12d} - {0:039_b}'.format(self.tproc_status))
            lines.append('TPROC_DEBUG  : {0:12d} - {0:039_b}'.format(self.tproc_debug))
            return "\n".join(lines)
     
        def getStatus(self):
            print(self.status())

        def status(self):
            lines = []
            debug_num = self.tproc_debug
            lines.append('---------------------------------------------')
            lines.append('--- Debug signals')
            lines.append('EXT_MEM_ADDR :' + '{:032b}'.format(debug_num)[0:8])
            lines.append('PMEM_ADDR    :' + '{:032b}'.format(debug_num)[8:16])
            lines.append('Time Ref     :' + '{:032b}'.format(debug_num)[16:24])
            lines.append("")
            lines.append('FIFO[0] Time :' + '{:032b}'.format(debug_num)[24:27])
            lines[-1] += ('FIFO_OK :'      + '{:032b}'.format(debug_num)[28])
            lines.append('Header  :'      + '{:032b}'.format(debug_num)[29:32])
            status_num = self.tproc_status
            lines.append('---------------------------------------------')
            lines.append('--- Memory Unit Status signals')
            lines.append('AXI_Read  :'+ '{:032b}'.format(status_num)[0])
            lines[-1] += ('AXI_Write :'+ '{:032b}'.format(status_num)[1] )
            lines.append('ext_P_Mem_EN  :'+ '{:032b}'.format(status_num)[2])
            lines[-1] += ('ext_P_Mem_WEN :'+ '{:032b}'.format(status_num)[3])
            lines.append('ext_D_Mem_EN  :'+ '{:032b}'.format(status_num)[4])
            lines[-1] += ('ext_D_Mem_WEN :'+ '{:032b}'.format(status_num)[5])
            lines.append('ext_W_Mem_EN  :'+ '{:032b}'.format(status_num)[6])
            lines[-1] += ('ext_W_Mem_WEN :'+ '{:032b}'.format(status_num)[7])
            lines.append('--- Processing Unit Status signals')
            lines.append('FD0_Empty:'+ '{:032b}'.format(status_num)[8])
            lines[-1] += ('FD1_Empty:'+ '{:032b}'.format(status_num)[10])
            lines[-1] += ('FD0_Full:'+ '{:032b}'.format(status_num)[9])
            lines[-1] += ('FD1_Full:'+ '{:032b}'.format(status_num)[11])
            lines.append('FW0_Empty:'+ '{:032b}'.format(status_num)[12])
            lines[-1] += ('FW1_Empty:'+ '{:032b}'.format(status_num)[14])
            lines[-1] += ('FW0_Full:'+ '{:032b}'.format(status_num)[13])
            lines[-1] += ('FW1_Full:'+ '{:032b}'.format(status_num)[15])
            lines.append('PMEM_EN:'+ '{:032b}'.format(status_num)[16])
            lines[-1] += ('DMEM_WE:'+ '{:032b}'.format(status_num)[17])
            lines[-1] += ('WMEM_WE:'+ '{:032b}'.format(status_num)[18])
            lines[-1] += ('PORT_WE:'+ '{:032b}'.format(status_num)[19])
            lines.append('T_en:'+ '{:032b}'.format(status_num)[26])
            lines[-1] += ('P_en:'+ '{:032b}'.format(status_num)[27])
            lines[-1] += ('STATE:'+ '{:032b}'.format(status_num)[29:32])
            return "\n".join(lines)



class AxisSwitch(SocIp):
    """
    AxisSwitch class to control Xilinx AXI-Stream switch IP

    :param nslave: Number of slave interfaces
    :type nslave: int
    :param nmaster: Number of master interfaces
    :type nmaster: int
    """
    bindto = ['xilinx.com:ip:axis_switch:1.1']
    REGISTERS = {'ctrl': 0x0, 'mix_mux': 0x040}

    def __init__(self, description):
        """
        Constructor method
        """
        super().__init__(description)

        # Number of slave interfaces.
        self.NSL = int(description['parameters']['NUM_SI'])
        # Number of master interfaces.
        self.NMI = int(description['parameters']['NUM_MI'])

        # Init axis_switch.
        self.ctrl = 0
        self.disable_ports()

    def disable_ports(self):
        """
        Disables ports
        """
        for ii in range(self.NMI):
            offset = self.REGISTERS['mix_mux'] + 4*ii
            self.write(offset, 0x80000000)

    def sel(self, mst=0, slv=0):
        """
        Digitally connects a master interface with a slave interface

        :param mst: Master interface
        :type mst: int
        :param slv: Slave interface
        :type slv: int
        """
        # Sanity check.
        if slv > self.NSL-1:
            print("%s: Slave number %d does not exist in block." %
                  __class__.__name__)
            return
        if mst > self.NMI-1:
            print("%s: Master number %d does not exist in block." %
                  __class__.__name__)
            return

        # Disable register update.
        self.ctrl = 0

        # Disable all MI ports.
        self.disable_ports()

        # MI[mst] -> SI[slv]
        offset = self.REGISTERS['mix_mux'] + 4*mst
        self.write(offset, slv)

        # Enable register update.
        self.ctrl = 2


class RFDC(xrfdc.RFdc):
    """
    Extends the xrfdc driver.
    Since operations on the RFdc tend to be slow (tens of ms), we cache the Nyquist zone and frequency.
    """
    bindto = ["xilinx.com:ip:usp_rf_data_converter:2.3",
              "xilinx.com:ip:usp_rf_data_converter:2.4",
              "xilinx.com:ip:usp_rf_data_converter:2.6"]

    def __init__(self, description):
        """
        Constructor method
        """
        super().__init__(description)
        # Nyquist zone for each channel
        self.nqz_dict = {}
        # Rounded NCO frequency for each channel
        self.mixer_dict = {}

    def configure(self, soc):
        self.daccfg = soc.dacs

    def set_mixer_freq(self, dacname, f, force=False, reset=False):
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

        :param dacname: DAC channel (2-digit string)
        :type dacname: int
        :param f: NCO frequency
        :type f: float
        :param force: force update, even if the setting is the same
        :type force: bool
        :param reset: if we change the frequency, also reset the NCO's phase accumulator
        :type reset: bool
        """
        fs = self.daccfg[dacname]['fs']
        fstep = fs/2**48
        rounded_f = round(f/fstep)*fstep
        if not force and rounded_f == self.get_mixer_freq(dacname):
            return
        fset = rounded_f
        if abs(rounded_f) > fs/2 and self.get_nyquist(dacname)==2:
            fset *= -1

        tile, channel = [int(a) for a in dacname]
        # Make a copy of mixer settings.
        dac_mixer = self.dac_tiles[tile].blocks[channel].MixerSettings
        new_mixcfg = dac_mixer.copy()

        # Update the copy
        new_mixcfg.update({
            'EventSource': xrfdc.EVNT_SRC_IMMEDIATE,
            'Freq': fset,
            'MixerType': xrfdc.MIXER_TYPE_FINE,
            'PhaseOffset': 0})

        # Update settings.
        if reset: self.dac_tiles[tile].blocks[channel].ResetNCOPhase()
        self.dac_tiles[tile].blocks[channel].MixerSettings = new_mixcfg
        self.dac_tiles[tile].blocks[channel].UpdateEvent(xrfdc.EVENT_MIXER)
        self.mixer_dict[dacname] = rounded_f

    def get_mixer_freq(self, dacname):
        try:
            return self.mixer_dict[dacname]
        except KeyError:
            tile, channel = [int(a) for a in dacname]
            self.mixer_dict[dacname] = self.dac_tiles[tile].blocks[channel].MixerSettings['Freq']
            return self.mixer_dict[dacname]

    def set_nyquist(self, dacname, nqz, force=False):
        """
        Sets DAC channel to operate in Nyquist zone nqz.
        This setting doesn't change the output frequencies:
        you will always have some power at both the demanded frequency and its image(s).
        Setting the NQZ to 2 increases output power in the 2nd/3rd Nyquist zones.
        See "RF-DAC Nyquist Zone Operation" in PG269.

        :param dacname: DAC channel (2-digit string)
        :type dacname: int
        :param nqz: Nyquist zone (1 or 2)
        :type nqz: int
        :param force: force update, even if the setting is the same
        :type force: bool
        """
        if nqz not in [1,2]:
            raise RuntimeError("Nyquist zone must be 1 or 2")
        tile, channel = [int(a) for a in dacname]
        if not force and self.get_nyquist(dacname) == nqz:
            return
        self.dac_tiles[tile].blocks[channel].NyquistZone = nqz
        self.nqz_dict[dacname] = nqz

    def get_nyquist(self, dacname):
        try:
            return self.nqz_dict[dacname]
        except KeyError:
            tile, channel = [int(a) for a in dacname]
            self.nqz_dict[dacname] = self.dac_tiles[tile].blocks[channel].NyquistZone
            return self.nqz_dict[dacname]


class QickSoc(Overlay, QickConfig):
    """
    QickSoc class. This class will create all object to access system blocks

    :param bitfile: Path to the bitfile. This should end with .bit, and the corresponding .hwh file must be in the same directory.
    :type bitfile: str
    :param force_init_clks: Re-initialize the board clocks regardless of whether they appear to be locked. Specifying (as True or False) the clk_output or external_clk options will also force clock initialization.
    :type force_init_clks: bool
    :param clk_output: If true, output a copy of the RF reference. This option is supported for the ZCU111 (get 122.88 MHz from J108) and ZCU216 (get 245.76 MHz from OUTPUT_REF J10).
    :type clk_output: bool or None
    :param external_clk: If true, lock the board clocks to an external reference. This option is supported for the ZCU111 (put 12.8 MHz on External_REF_CLK J109), ZCU216 (put 10 MHz on INPUT_REF_CLK J11), and RFSoC 4x2 (put 10 MHz on CLK_IN).
    :type external_clk: bool or None
    :param ignore_version: Whether version discrepancies between PYNQ build and firmware build are ignored
    :type ignore_version: bool
    """

    # The following constants are no longer used. Some of the values may not match the bitfile.
    # fs_adc = 384*8 # MHz
    # fs_dac = 384*16 # MHz
    # pulse_mem_len_IQ = 65536 # samples for I, Q
    # ADC_decim_buf_len_IQ = 1024 # samples for I, Q
    # ADC_accum_buf_len_IQ = 16384 # samples for I, Q
    #tProc_instruction_len_bytes = 8
    #tProc_prog_mem_samples = 8000
    #tProc_prog_mem_size_bytes_tot = tProc_instruction_len_bytes*tProc_prog_mem_samples
    #tProc_data_len_bytes = 4
    #tProc_data_mem_samples = 4096
    #tProc_data_mem_size_bytes_tot = tProc_data_len_bytes*tProc_data_mem_samples
    #tProc_stack_len_bytes = 4
    #tProc_stack_samples = 256
    #tProc_stack_size_bytes_tot = tProc_stack_len_bytes*tProc_stack_samples
    #phase_resolution_bits = 32
    #gain_resolution_signed_bits = 16

    # Constructor.
    def __init__(self, bitfile=None, force_init_clks=False, ignore_version=True, no_tproc=False, clk_output=None, external_clk=None, **kwargs):
        """
        Constructor method
        """

        self.external_clk = external_clk
        self.clk_output = clk_output
        # Load bitstream. We read the bitstream configuration from the HWH file, but we don't program the FPGA yet.
        # We need to program the clocks first.
        if bitfile is None:
            Overlay.__init__(self, bitfile_path(
            ), ignore_version=ignore_version, download=False, **kwargs)
        else:
            Overlay.__init__(
                self, bitfile, ignore_version=ignore_version, download=False, **kwargs)

        # Initialize the configuration
        self._cfg = {}
        QickConfig.__init__(self)

        self['board'] = os.environ["BOARD"]

        # Read the config to get a list of enabled ADCs and DACs, and the sampling frequencies.
        self.list_rf_blocks(
            self.ip_dict['usp_rf_data_converter_0']['parameters'])

        self.config_clocks(force_init_clks)

        # RF data converter (for configuring ADCs and DACs, and setting NCOs)
        self.rf = self.usp_rf_data_converter_0
        self.rf.configure(self)

        # Extract the IP connectivity information from the HWH parser and metadata.
        self.metadata = QickMetadata(self)

        if not no_tproc:
            # tProcessor, 64-bit instruction, 32-bit registers, x8 channels.
            if 'axis_tproc64x32_x8_0' in self.ip_dict:
                self._tproc = self.axis_tproc64x32_x8_0
                self._tproc.configure(self.axi_bram_ctrl_0, self.axi_dma_tproc)
                self['fs_proc'] = self.metadata.get_fclk(self.tproc.fullpath, "aclk")
            else:
                self._tproc = self.axis_tproc_v2_0
                self._tproc.configure(self.axis_tproc_v2_0, self.axi_dma_tproc)
                self['fs_proc'] = self.metadata.get_fclk(self.tproc.fullpath, "t_clk_i")

            self.map_signal_paths()

            self._streamer = DataStreamer(self)

            # list of objects that need to be registered for autoproxying over Pyro
            self.autoproxy = [self.streamer, self.tproc]

    @property
    def tproc(self):
        return self._tproc

    @property
    def streamer(self):
        return self._streamer

    def map_signal_paths(self):
        """
        Make lists of signal generator, readout, and buffer blocks in the firmware.
        Also map the switches connecting the generators and buffers to DMA.
        Fill the config dictionary with parameters of the DAC and ADC channels.
        """
        # Use the HWH parser to trace connectivity and deduce the channel numbering.
        for key, val in self.ip_dict.items():
            if hasattr(val['driver'], 'configure_connections'):
                getattr(self, key).configure_connections(self)

        # AXIS Switch to upload samples into Signal Generators.
        self.switch_gen = self.axis_switch_gen

        # AXIS Switch to read samples from averager.
        self.switch_avg = self.axis_switch_avg

        # AXIS Switch to read samples from buffer.
        self.switch_buf = self.axis_switch_buf

        # Signal generators (anything driven by the tProc)
        self.gens = []
        gen_drivers = set([AxisSignalGen, AxisSgInt4V1, AxisSgMux4V1, AxisSgMux4V2])

        # Constant generators
        self.iqs = []

        # Average + Buffer blocks.
        self.avg_bufs = []

        # Readout blocks.
        self.readouts = []
        ro_drivers = set([AxisReadoutV2, AxisPFBReadoutV2])

        # Populate the lists with the registered IP blocks.
        for key, val in self.ip_dict.items():
            if val['driver'] in gen_drivers:
                self.gens.append(getattr(self, key))
            elif val['driver'] == AxisConstantIQ:
                self.iqs.append(getattr(self, key))
            elif val['driver'] in ro_drivers:
                self.readouts.append(getattr(self, key))
            elif val['driver'] == AxisAvgBuffer:
                self.avg_bufs.append(getattr(self, key))

        for buf in self.avg_bufs:
            if buf.readout not in self.readouts:
                self.readouts.append(buf.readout)

        # Sanity check: we should have the same number of readouts and buffer blocks as switch ports.
        #TODO: bring back?
        #if len(self.readouts) != len(self.avg_bufs):
        #    raise RuntimeError("We have %d readouts but %d avg/buffer blocks." %
        #                       (len(self.readouts), len(self.avg_bufs)))
        if self.switch_avg.NSL != len(self.avg_bufs):
            raise RuntimeError("We have %d switch_avg inputs but %d avg/buffer blocks." %
                               (self.switch_avg.NSL, len(self.avg_bufs)))
        if self.switch_buf.NSL != len(self.avg_bufs):
            raise RuntimeError("We have %d switch_buf inputs but %d avg/buffer blocks." %
                               (self.switch_buf.NSL, len(self.avg_bufs)))

        # Sort the lists.
        # We order gens by the tProc port number and buffers by the switch port number.
        # Those orderings are important, since those indices get used in programs.
        self.gens.sort(key=lambda x: x.tproc_ch)
        self.avg_bufs.sort(key=lambda x: x.switch_ch)
        # The IQ and readout orderings aren't critical for anything.
        self.iqs.sort(key=lambda x: x.dac)
        self.readouts.sort(key=lambda x: x.adc)

        # Configure the drivers.
        for i, gen in enumerate(self.gens):
            gen.configure(i, self.rf,
                          self.dacs[gen.dac]['fs'], self.axi_dma_gen, self.switch_gen)

        for i, iq in enumerate(self.iqs):
            iq.configure(i, self.rf, self.dacs[iq.dac]['fs'])

        for buf in self.avg_bufs:
            buf.configure(self.axi_dma_avg, self.switch_avg,
                          self.axi_dma_buf, self.switch_buf)
        for readout in self.readouts:
            readout.configure(self.adcs[readout.adc]['fs'])

        # Fill the config dictionary with driver parameters.
        self['dacs'] = list(self.dacs.keys())
        self['adcs'] = list(self.adcs.keys())
        self['gens'] = []
        self['readouts'] = []
        self['iqs'] = []
        for gen in self.gens:
            thiscfg = {}
            thiscfg['type'] = gen.type
            thiscfg['maxlen'] = gen.MAX_LENGTH
            thiscfg['b_dds'] = gen.B_DDS
            thiscfg['switch_ch'] = gen.switch_ch
            thiscfg['tproc_ch'] = gen.tproc_ch
            thiscfg['dac'] = gen.dac
            thiscfg['fs'] = gen.fs_dds
            thiscfg['f_fabric'] = self.dacs[gen.dac]['f_fabric']
            thiscfg['samps_per_clk'] = gen.SAMPS_PER_CLK
            thiscfg['maxv'] = gen.MAXV
            thiscfg['maxv_scale'] = gen.MAXV_SCALE
            self['gens'].append(thiscfg)

        for buf in self.avg_bufs:
            thiscfg = {}
            thiscfg['avg_maxlen'] = buf.AVG_MAX_LENGTH
            thiscfg['buf_maxlen'] = buf.BUF_MAX_LENGTH
            thiscfg['b_dds'] = buf.readout.B_DDS
            thiscfg['ro_type'] = buf.readout.type
            thiscfg['tproc_ctrl'] = buf.readout.tproc_ch
            thiscfg['adc'] = buf.readout.adc
            thiscfg['fs'] = self.adcs[buf.readout.adc]['fs']
            thiscfg['f_fabric'] = self.adcs[buf.readout.adc]['f_fabric']
            if thiscfg['ro_type'] == 'axis_readout_v3':
                # there is a 2x1 resampler between the RFDC and readout, which doubles the effective fabric frequency.
                thiscfg['f_fabric'] *= 2
            thiscfg['trigger_bit'] = buf.trigger_bit
            thiscfg['tproc_ch'] = buf.tproc_ch
            self['readouts'].append(thiscfg)

        for iq in self.iqs:
            thiscfg = {}
            thiscfg['dac'] = iq.dac
            thiscfg['fs'] = iq.fs_dac
            self['iqs'].append(thiscfg)

        self['tprocs'] = []
        for tproc in [self.tproc]:
            thiscfg = {}
            thiscfg['trig_output'] = tproc.trig_output
            thiscfg['output_pins'] = tproc.output_pins
            thiscfg['start_pin'] = tproc.start_pin
            thiscfg['pmem_size'] = tproc.mem.mmio.length//8
            thiscfg['dmem_size'] = 2**tproc.DMEM_N
            self['tprocs'].append(thiscfg)

    def config_clocks(self, force_init_clks):
        """
        Configure PLLs if requested, or if any ADC/DAC is not locked.
        """
              
        # if we're changing the clock config, we must set the clocks to apply the config
        if force_init_clks or (self.external_clk is not None) or (self.clk_output is not None):
            self.set_all_clks()
            self.download()
        else:
            self.download()
            if not self.clocks_locked():
                self.set_all_clks()
                self.download()
        if not self.clocks_locked():
            print(
                "Not all DAC and ADC PLLs are locked. You may want to repeat the initialization of the QickSoc.")

    def clocks_locked(self):
        """
        Checks whether the DAC and ADC PLLs are locked.
        This can only be run after the bitstream has been downloaded.

        :return: clock status
        :rtype: bool
        """

        dac_locked = [self.usp_rf_data_converter_0.dac_tiles[iTile]
                      .PLLLockStatus == 2 for iTile in self.dac_tiles]
        adc_locked = [self.usp_rf_data_converter_0.adc_tiles[iTile]
                      .PLLLockStatus == 2 for iTile in self.adc_tiles]
        return all(dac_locked) and all(adc_locked)

    def list_rf_blocks(self, rf_config):
        """
        Lists the enabled ADCs and DACs and get the sampling frequencies.
        XRFdc_CheckBlockEnabled in xrfdc_ap.c is not accessible from the Python interface to the XRFdc driver.
        This re-implements that functionality.
        """

        self.hs_adc = rf_config['C_High_Speed_ADC'] == '1'

        self.dac_tiles = []
        self.adc_tiles = []
        dac_fabric_freqs = []
        adc_fabric_freqs = []
        refclk_freqs = []
        self.dacs = {}
        self.adcs = {}

        for iTile in range(4):
            if rf_config['C_DAC%d_Enable' % (iTile)] != '1':
                continue
            self.dac_tiles.append(iTile)
            f_fabric = float(rf_config['C_DAC%d_Fabric_Freq' % (iTile)])
            f_refclk = float(rf_config['C_DAC%d_Refclk_Freq' % (iTile)])
            dac_fabric_freqs.append(f_fabric)
            refclk_freqs.append(f_refclk)
            fs = float(rf_config['C_DAC%d_Sampling_Rate' % (iTile)])*1000
            for iBlock in range(4):
                if rf_config['C_DAC_Slice%d%d_Enable' % (iTile, iBlock)] != 'true':
                    continue
                self.dacs["%d%d" % (iTile, iBlock)] = {'fs': fs,
                                                       'f_fabric': f_fabric}

        for iTile in range(4):
            if rf_config['C_ADC%d_Enable' % (iTile)] != '1':
                continue
            self.adc_tiles.append(iTile)
            f_fabric = float(rf_config['C_ADC%d_Fabric_Freq' % (iTile)])
            f_refclk = float(rf_config['C_ADC%d_Refclk_Freq' % (iTile)])
            adc_fabric_freqs.append(f_fabric)
            refclk_freqs.append(f_refclk)
            fs = float(rf_config['C_ADC%d_Sampling_Rate' % (iTile)])*1000
            for iBlock in range(4):
                if self.hs_adc:
                    if iBlock >= 2 or rf_config['C_ADC_Slice%d%d_Enable' % (iTile, 2*iBlock)] != 'true':
                        continue
                else:
                    if rf_config['C_ADC_Slice%d%d_Enable' % (iTile, iBlock)] != 'true':
                        continue
                self.adcs["%d%d" % (iTile, iBlock)] = {'fs': fs,
                                                       'f_fabric': f_fabric}

        def get_common_freq(freqs):
            """
            Check that all elements of the list are equal, and return the common value.
            """
            if not freqs:  # input is empty list
                return None
            if len(set(freqs)) != 1:
                raise RuntimeError("Unexpected frequencies:", freqs)
            return freqs[0]

        self['refclk_freq'] = get_common_freq(refclk_freqs)

    def set_all_clks(self):
        """
        Resets all the board clocks
        """
        if self['board'] == 'ZCU111':
            print("resetting clocks:", self['refclk_freq'])

            if hasattr(xrfclk, "xrfclk"): # pynq 2.7
                # load the default clock chip configurations from file, so we can then modify them
                xrfclk.xrfclk._find_devices()
                xrfclk.xrfclk._read_tics_output()
                if self.clk_output:
                    # change the register for the LMK04208 chip's 5th output, which goes to J108
                    # we need this for driving the RF board
                    xrfclk.xrfclk._Config['lmk04208'][122.88][6] = 0x00140325
                if self.external_clk:
                    # default value is 0x2302886D
                    xrfclk.xrfclk._Config['lmk04208'][122.88][14] = 0x2302826D
            else: # pynq 2.6
                if self.clk_output:
                    # change the register for the LMK04208 chip's 5th output, which goes to J108
                    # we need this for driving the RF board
                    xrfclk._lmk04208Config[122.88][6] = 0x00140325
                else: # restore the default
                    xrfclk._lmk04208Config[122.88][6] = 0x80141E05
                if self.external_clk:
                    xrfclk._lmk04208Config[122.88][14] = 0x2302826D
                else: # restore the default
                    xrfclk._lmk04208Config[122.88][14] = 0x2302886D
            xrfclk.set_all_ref_clks(self['refclk_freq'])
        elif self['board'] == 'ZCU216':
            lmk_freq = self['refclk_freq']
            lmx_freq = self['refclk_freq']*2
            print("resetting clocks:", lmk_freq, lmx_freq)

            assert hasattr(xrfclk, "xrfclk") # ZCU216 only has a pynq 2.7 image
            xrfclk.xrfclk._find_devices()
            xrfclk.xrfclk._read_tics_output()
            if self.external_clk:
                # default value is 0x01471A
                xrfclk.xrfclk._Config['lmk04828'][245.76][80] = 0x01470A
            if self.clk_output:
                # default value is 0x012C22
                xrfclk.xrfclk._Config['lmk04828'][245.76][55] = 0x012C02
            xrfclk.set_ref_clks(lmk_freq=lmk_freq, lmx_freq=lmx_freq)
        elif self['board'] == 'RFSoC4x2':
            lmk_freq = self['refclk_freq']/2
            lmx_freq = self['refclk_freq']
            print("resetting clocks:", lmk_freq, lmx_freq)
            xrfclk.xrfclk._find_devices()
            xrfclk.xrfclk._read_tics_output()
            print(xrfclk.xrfclk._Config['lmk04828'][245.76][80])
            if self.external_clk:
                # default value is 0x01471A
                xrfclk.xrfclk._Config['lmk04828'][245.76][80] = 0x01470A
            xrfclk.set_ref_clks(lmk_freq=lmk_freq, lmx_freq=lmx_freq)

    def get_decimated(self, ch, address=0, length=None):
        """
        Acquires data from the readout decimated buffer

        :param ch: ADC channel
        :type ch: int
        :param address: Address of data
        :type address: int
        :param length: Buffer transfer length
        :type length: int
        :return: List of I and Q decimated arrays
        :rtype: list
        """
        if length is None:
            # this default will always cause a RuntimeError
            # TODO: remove the default, or pick a better fallback value
            length = self.avg_bufs[ch].BUF_MAX_LENGTH

        # we must transfer an even number of samples, so we pad the transfer size
        transfer_len = length + length % 2

        # there is a bug which causes the first sample of a transfer to always be the sample at address 0
        # we work around this by requesting an extra 2 samples at the beginning
        data = self.avg_bufs[ch].transfer_buf(
            (address-2) % self.avg_bufs[ch].BUF_MAX_LENGTH, transfer_len+2)

        # we remove the padding here
        return data[2:length+2]

    def get_accumulated(self, ch, address=0, length=None):
        """
        Acquires data from the readout accumulated buffer

        :param ch: ADC channel
        :type ch: int
        :param address: Address of data
        :type address: int
        :param length: Buffer transfer length
        :type length: int
        :returns:
            - di[:length] (:py:class:`list`) - list of accumulated I data
            - dq[:length] (:py:class:`list`) - list of accumulated Q data
        """
        if length is None:
            # this default will always cause a RuntimeError
            # TODO: remove the default, or pick a better fallback value
            length = self.avg_bufs[ch].AVG_MAX_LENGTH

        # we must transfer an even number of samples, so we pad the transfer size
        transfer_len = length + length % 2

        # there is a bug which causes the first sample of a transfer to always be the sample at address 0
        # we work around this by requesting an extra 2 samples at the beginning
        data = self.avg_bufs[ch].transfer_avg(
            (address-2) % self.avg_bufs[ch].AVG_MAX_LENGTH, transfer_len+2)

        # we remove the padding here
        return data[2:length+2]

    def init_readouts(self):
        """
        Initialize readouts, in preparation for configuring them.
        """
        for readout in self.readouts:
            # if this is a tProc-controlled readout, we don't initialize it here
            if not isinstance(readout, AxisReadoutV3):
                readout.initialize()

    def configure_readout(self, ch, output, frequency, gen_ch=0):
        """Configure readout channel output style and frequency.
        This method is only for use with PYNQ-controlled readouts.
        :param ch: Channel to configure
        :type ch: int
        :param output: output type from 'product', 'dds', 'input'
        :type output: str
        :param frequency: frequency
        :type frequency: float
        :param gen_ch: DAC channel (use None if you don't want to round to a valid DAC frequency)
        :type gen_ch: int
        """
        buf = self.avg_bufs[ch]
        buf.readout.set_out(sel=output)
        buf.set_freq(frequency, gen_ch=gen_ch)

    def config_avg(self, ch, address=0, length=1, enable=True):
        """Configure and optionally enable accumulation buffer
        :param ch: Channel to configure
        :type ch: int
        :param address: Starting address of buffer
        :type address: int
        :param length: length of buffer (how many samples to take)
        :type length: int
        :param enable: True to enable buffer
        :type enable: bool
        """
        avg_buf = self.avg_bufs[ch]
        avg_buf.config_avg(address, length)
        if enable:
            avg_buf.enable_avg()

    def config_buf(self, ch, address=0, length=1, enable=True):
        """Configure and optionally enable decimation buffer
        :param ch: Channel to configure
        :type ch: int
        :param address: Starting address of buffer
        :type address: int
        :param length: length of buffer (how many samples to take)
        :type length: int
        :param enable: True to enable buffer
        :type enable: bool
        """
        avg_buf = self.avg_bufs[ch]
        avg_buf.config_buf(address, length)
        if enable:
            avg_buf.enable_buf()

    def get_avg_max_length(self, ch=0):
        """Get accumulation buffer length for channel
        :param ch: Channel
        :type ch: int
        :return: Length of accumulation buffer for channel 'ch'
        :rtype: int
        """
        return self['readouts'][ch]['avg_maxlen']

    def load_pulse_data(self, ch, data, addr):
        """Load pulse data into signal generators
        :param ch: Channel
        :type ch: int
        :param data: array of (I, Q) values for pulse envelope
        :type data: int16 array
        :param addr: address to start data at
        :type addr: int
        """
        return self.gens[ch].load(xin=data, addr=addr)

    def set_nyquist(self, ch, nqz, force=False):
        """
        Sets DAC channel ch to operate in Nyquist zone nqz mode.

        :param ch: DAC channel (index in 'gens' list)
        :type ch: int
        :param nqz: Nyquist zone
        :type nqz: int
        """

        self.gens[ch].set_nyquist(nqz)

    def set_mixer_freq(self, ch, f, ro_ch=None):
        """
        Set mixer frequency for a signal generator.
        If the generator does not have a mixer, you will get an error.

        :param ch: DAC channel (index in 'gens' list)
        :type ch: int
        :param f: frequency (MHz)
        :type f: float
        :param ro_ch: readout channel (use None if you don't want to round to a valid ADC frequency)
        :type ro_ch: int
        """
        if self.gens[ch].HAS_MIXER:
            self.gens[ch].set_mixer_freq(f, ro_ch)
        elif f != 0:
            raise RuntimeError("tried to set a mixer frequency, but this channel doesn't have a mixer")

    def set_mux_freqs(self, ch, freqs, gains=None, ro_ch=0):
        """
        Set muxed frequencies and gains for a signal generator.
        If it's not a muxed signal generator, you will get an error.

        Gains can only be specified for a muxed generator with configurable gains.
        The gain list must be the same length as the freqs list.

        :param ch: DAC channel (index in 'gens' list)
        :type ch: int
        :param freqs: frequencies (MHz)
        :type freqs: list
        :param gains: gains (in range -1 to 1)
        :type gains: list
        :param ro_ch: readout channel (use None if you don't want to round to a valid ADC frequency)
        :type ro_ch: int
        """
        if gains is not None and len(gains) != len(freqs):
            raise RuntimeError("lengths of freqs and gains lists do not match")
        for ii, f in enumerate(freqs):
            self.gens[ch].set_freq(f, out=ii, ro_ch=ro_ch)
            if gains is not None:
                self.gens[ch].set_gain(gains[ii], out=ii)

    def set_iq(self, ch, f, i, q):
        """
        Set frequency, I, and Q for a constant-IQ output.

        :param ch: IQ channel (index in 'iqs' list)
        :type ch: int
        :param f: frequency (MHz)
        :type f: float
        :param i: I value (in range -1 to 1)
        :type i: float
        :param q: Q value (in range -1 to 1)
        :type q: float
        """
        self.iqs[ch].set_mixer_freq(f)
        self.iqs[ch].set_iq(i, q)

    def load_bin_program(self, binprog, reset=False):
        """
        Write the program to the tProc program memory.

        :param reset: Reset the tProc before writing the program.
        :type reset: bool
        """
        if reset: self.tproc.reset()

        # cast the program words to 64-bit uints
        self.binprog = np.array(obtain(binprog), dtype=np.uint64)
        # reshape to 32 bits to match the program memory
        self.binprog = np.frombuffer(self.binprog, np.uint32)

        self.reload_program()

    def reload_program(self):
        """
        Write the most recently written program to the tProc program memory.
        This is normally useful after a reset (which erases the program memory)
        """
        # write the program to memory with a fast copy
        #print(self.binprog)
        np.copyto(self.tproc.mem.mmio.array[:len(self.binprog)], self.binprog)

    def start_src(self, src):
        """
        Sets the start source of tProc

        :param src: start source "internal" or "external"
        :type src: string
        """
        # set internal-start register to "init"
        # otherwise we might start the tProc on a transition from external to internal start
        self.tproc.start_reg = 0
        self.tproc.start_src_reg = {"internal": 0, "external": 1}[src]

    def reset_gens(self):
        """
        Reset the tProc and run a minimal tProc program that drives all signal generators with 0's.
        Useful for stopping any periodic or stdysel="last" outputs that may have been driven by a previous program.
        """
        prog = QickProgram(self)
        for gen in self.gens:
            if gen.HAS_WAVEFORM:
                prog.set_pulse_registers(ch=gen.ch, style="const", mode="oneshot", freq=0, phase=0, gain=0, length=3)
                prog.pulse(ch=gen.ch,t=0)
        prog.end()
        # this should always run with internal trigger
        self.start_src("internal")
        prog.load_program(self, reset=True)
        self.tproc.start()

    def start_readout(self, total_reps, counter_addr=1, ch_list=None, reads_per_rep=1, stride=None):
        """
        Start a streaming readout of the accumulated buffers.

        :param total_count: Number of data points expected
        :type total_count: int
        :param counter_addr: Data memory address for the loop counter
        :type counter_addr: int
        :param ch_list: List of readout channels
        :type ch_list: list
        :param reads_per_count: Number of data points to expect per counter increment
        :type reads_per_count: int
        :param stride: Default number of measurements to transfer at a time.
        :type stride: int
        """
        ch_list = obtain(ch_list)
        if ch_list is None: ch_list = [0, 1]
        streamer = self.streamer

        if not streamer.readout_worker.is_alive():
            print("restarting readout worker")
            streamer.start_worker()
            print("worker restarted")

        # if there's still a readout job running, stop it
        if streamer.readout_running():
            print("cleaning up previous readout: stopping tProc and streamer loop")
            # stop the tProc
            self.tproc.reset()
            # tell the readout to stop (this will break the readout loop)
            streamer.stop_readout()
            streamer.done_flag.wait()
            # push a dummy packet into the data queue to halt any running poll_data(), and wait long enough for the packet to be read out
            streamer.data_queue.put((0, None))
            time.sleep(0.1)
            # reload the program (since the reset will have wiped it out)
            self.reload_program()
            print("streamer stopped")
        streamer.stop_flag.clear()

        if streamer.data_available():
            # flush all the data in the streamer buffer
            print("clearing streamer buffer")
            # read until the queue times out, discard the data
            self.poll_data(totaltime=-1, timeout=0.1)
            print("buffer cleared")

        streamer.total_count = total_reps*reads_per_rep
        streamer.count = 0

        streamer.done_flag.clear()
        streamer.job_queue.put((total_reps, counter_addr, ch_list, reads_per_rep, stride))

    def poll_data(self, totaltime=0.1, timeout=None):
        """
        Get as much data as possible from the streamer data queue.
        Stop when any of the following conditions are met:
        * all the data has been transferred (based on the total_count)
        * we got data, and it has been totaltime seconds since poll_data was called
        * timeout is defined, and the timeout expired without getting new data in the queue
        If there are errors in the error queue, raise the first one.

        :param totaltime: How long to acquire data (negative value = ignore total time and total count, just read until timeout)
        :type totaltime: float
        :param timeout: How long to wait for the next data packet (None = wait forever)
        :type timeout: float
        :return: list of (data, stats) pairs, oldest first
        :rtype: list
        """
        streamer = self.streamer

        time_end = time.time() + totaltime
        new_data = []
        while (totaltime < 0) or (streamer.count < streamer.total_count and time.time() < time_end):
            try:
                raise RuntimeError("exception in readout loop") from streamer.error_queue.get(block=False)
            except queue.Empty:
                pass
            try:
                length, data = streamer.data_queue.get(block=True, timeout=timeout)
                # if we stopped the readout while we were waiting for data, break out and return
                if streamer.stop_flag.is_set() or data is None:
                    break
                streamer.count += length
                new_data.append(data)
            except queue.Empty:
                break
        return new_data
