"""
Drivers for readouts (FPGA blocks that receive data from ADCs) and buffers (blocks that receive data from readouts).
"""
from pynq.buffer import allocate
import numpy as np
from qick import DummyIp, SocIp

class AbsReadout(DummyIp):
    # Configure this driver with the sampling frequency.
    def configure(self, rf):
        self.rf = rf
        # Sampling frequency.
        #self.fs = fs
        self.cfg['adc'] = self.adc
        self.cfg['b_dds'] = self.B_DDS
        for p in ['fs', 'fs_mult', 'fs_div', 'decimation', 'f_fabric']:
            self.cfg[p] = self.rf.adccfg[self['adc']][p]
        # decimation reduces the DDS range
        self.cfg['f_dds'] = self.cfg['fs']/self['decimation']
        self.cfg['fdds_div'] = self['fs_div']*self['decimation']

    def initialize(self):
        """
        Reset the readout configuration.
        """
        pass

    def update(self):
        """
        Push the register values to the readout logic.
        """
        pass

class AxisReadoutV2(SocIp, AbsReadout):
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
        blocktype = soc.metadata.mod2type(block)
        if blocktype == "axis_broadcaster":
                ((block, port),) = soc.metadata.trace_bus(block, 'M00_AXIS')
        self.buffer = getattr(soc, block)

        #print("%s: ADC tile %s block %s, buffer %s"%(self.fullpath, *self.adc, self.buffer.fullpath))

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
        # calculate the exact frequency we expect to see
        ro_freq = f
        if gen_ch is not None: # calculate the frequency that will be applied to the generator
            ro_freq = self.soc.roundfreq(f, self.soc['gens'][gen_ch], self.cfg)
        if gen_ch is not None and self.soc.gens[gen_ch].HAS_MIXER:
            ro_freq += self.soc.gens[gen_ch].get_mixer_freq()
        ro_freq = ro_freq % self['f_dds']
        # we can calculate the register value without further referencing the gen_ch
        f_int = self.soc.freq2int(ro_freq, self.cfg)
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

class AxisPFBReadoutV2(SocIp, AbsReadout):
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
    B_DDS = 32

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

    def configure(self, rf):
        super().configure(rf)
        # The DDS range is reduced by both the RF-ADC decimation and the PFB.
        self.cfg['f_dds'] /= 4
        self.cfg['fdds_div'] *= 4

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
        # calculate the exact frequency we expect to see
        ro_freq = f
        if gen_ch is not None: # calculate the frequency that will be applied to the generator
            ro_freq = self.soc.roundfreq(f, self.soc['gens'][gen_ch], self.cfg)
        if gen_ch is not None and self.soc.gens[gen_ch].HAS_MIXER:
            ro_freq += self.soc.gens[gen_ch].get_mixer_freq()

        nqz = int(ro_freq // (self['fs']/2)) + 1
        if nqz % 2 == 0: # even Nyquist zone
            ro_freq *= -1
        # the PFB channels are separated by half the DDS range
        # round() gives you the single best channel
        # floor() and ceil() would give you the 2 best channels
        # if you have two RO frequencies close together, you might need to force one of them onto a non-optimal channel
        f_steps = int(np.round(ro_freq/(self['f_dds']/2)))
        f_dds = ro_freq - f_steps*(self['f_dds']/2)
        in_ch = (self.CH_OFFSET + f_steps) % 8

        # we can calculate the register value without further referencing the gen_ch
        freq_int = self.soc.freq2int(f_dds, self.cfg)
        self.set_freq_int(freq_int, in_ch, out_ch)

    def set_freq_int(self, f_int, in_ch, out_ch):
        if in_ch in self.ch_freqs and f_int != self.ch_freqs[in_ch]:
            # we are already using this PFB channel, and it's set to a different frequency
            # now do a bunch of math to print an informative message
            centerfreq = ((in_ch - self.CH_OFFSET) % 8) * (self['f_dds']/2)
            lofreq = centerfreq - self['f_dds']/4
            hifreq = centerfreq + self['f_dds']/4
            oldfreq = centerfreq + self.soc.int2freq(self.ch_freqs[in_ch], self.cfg)
            newfreq = centerfreq + self.soc.int2freq(f_int, self.cfg)
            raise RuntimeError("frequency collision: tried to set PFB output %d to %f MHz and output %d to %f MHz, but both map to the PFB channel that is optimal for [%f, %f] (all freqs expressed in first Nyquist zone)"%(out_ch, newfreq, self.out_chs[in_ch], oldfreq, lofreq, hifreq))
        self.ch_freqs[in_ch] = f_int
        self.out_chs[in_ch] = out_ch
        # wire the selected PFB channel to the output
        setattr(self, "ch%dsel_reg"%(out_ch), in_ch)
        # set the PFB channel's DDS frequency
        setattr(self, "freq%d_reg"%(in_ch), f_int)

class AxisReadoutV3(AbsReadout):
    """tProc-controlled readout block.
    This isn't a PYNQ driver, since the block has no registers for PYNQ control.
    We still need this class to represent the block and its connectivity.
    """
    # Bits of DDS.
    B_DDS = 32

    def __init__(self, fullpath):
        super().__init__("axis_readout_v3", fullpath)

    def configure(self, rf):
        super().configure(rf)
        self.cfg['tproc_ctrl'] = self.tproc_ch
        # there is a 2x1 resampler between the RFDC and readout, which doubles the effective fabric frequency.
        self.cfg['f_fabric'] *= 2

    def configure_connections(self, soc):
        self.soc = soc

        # what tProc output port controls this readout?
        ((block, port),) = soc.metadata.trace_bus(self['fullpath'], 's0_axis')
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
        ((block, port),) = soc.metadata.trace_bus(self['fullpath'], 's1_axis')
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
        ((block, port),) = soc.metadata.trace_bus(self['fullpath'], 'm_axis')
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
        self.cfg['avg_maxlen'] = 2**self.N_AVG
        self.cfg['buf_maxlen'] = 2**self.N_BUF

        # Preallocate memory buffers for DMA transfers.
        self.avg_buff = allocate(shape=self['avg_maxlen'], dtype=np.int64)
        self.buf_buff = allocate(shape=self['buf_maxlen'], dtype=np.int32)

    def configure_connections(self, soc):
        # which readout drives this buffer?
        ((block, port),) = soc.metadata.trace_bus(self.fullpath, 's_axis')
        blocktype = soc.metadata.mod2type(block)

        if blocktype == "axis_broadcaster":
                ((block, port),) = soc.metadata.trace_bus(block, 'S_AXIS')
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
        self.switch_avg = getattr(soc, block)
        # port names are of the form 'S01_AXIS'
        switch_avg_ch = int(port.split('_')[0][1:], 10)
        ((block, port),) = soc.metadata.trace_bus(block, 'M00_AXIS')
        self.dma_avg = getattr(soc, block)

        # which switch_buf port does this buffer drive?
        ((block, port),) = soc.metadata.trace_bus(self.fullpath, 'm1_axis')
        self.switch_buf = getattr(soc, block)
        # port names are of the form 'S01_AXIS'
        switch_buf_ch = int(port.split('_')[0][1:], 10)
        ((block, port),) = soc.metadata.trace_bus(block, 'M00_AXIS')
        self.dma_buf = getattr(soc, block)

        if switch_avg_ch != switch_buf_ch:
            raise RuntimeError(
                "switch_avg and switch_buf port numbers do not match:", self.fullpath)
        self.switch_ch = switch_avg_ch

        # which tProc output bit triggers this buffer?
        ((block, port),) = soc.metadata.trace_sig(self.fullpath, 'trigger')
        # vect2bits/qick_vec2bit port names are of the form 'dout14'
        self.cfg['trigger_bit'] = int(port[4:])

        # which tProc output port triggers this buffer?
        # two possibilities:
        # tproc v1 output port -> axis_set_reg -> vect2bits -> buffer
        # tproc v2 data port -> vect2bits -> buffer
        ((block, port),) = soc.metadata.trace_sig(block, 'din')
        if soc.metadata.mod2type(block) == "axis_set_reg":
            ((block, port),) = soc.metadata.trace_bus(block, 's_axis')
        # ask the tproc to translate this port name to a channel number
        self.cfg['trigger_port'], self.cfg['trigger_type'] = getattr(soc, block).port2ch(port)

        # which tProc input port does this buffer drive?
        try:
            ((block, port),) = soc.metadata.trace_bus(self.fullpath, 'm2_axis')
            # jump through an axis_clk_cnvrt
            while soc.metadata.mod2type(block) == "axis_clock_converter":
                ((block, port),) = soc.metadata.trace_bus(block, 'M_AXIS')
            # port names are of the form 's1_axis'
            # subtract 1 to get the channel number (s0 comes from the DMA)
            if soc.metadata.mod2type(block) in ["axis_tproc64x32_x8", "qick_processor"]:
                # ask the tproc to translate this port name to a channel number
                self.cfg['tproc_ch'], _ = getattr(soc, block).port2ch(port)
            else:
                # this buffer doesn't feed back into the tProc
                self.cfg['tproc_ch'] = -1
        except:
            self.cfg['tproc_ch'] = -1

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

        if length >= self['avg_maxlen']:
            raise RuntimeError("length=%d longer than %d" %
                               (length, self['avg_maxlen']))

        # pad the transfer size to an even number (odd lengths seem to break the DMA)
        transferlen = length + (length % 2)

        # Route switch to channel.
        self.switch_avg.sel(slv=self.switch_ch)

        # Set averager data reader address and length.
        self.avg_dr_addr_reg = address
        self.avg_dr_len_reg = transferlen

        # Start send data mode.
        self.avg_dr_start_reg = 1

        # DMA data.
        buff = self.avg_buff
        # nbytes has to be a Python int (it gets passed to mmio.write, which requires int or bytes)
        self.dma_avg.recvchannel.transfer(buff, nbytes=int(transferlen*8))
        self.dma_avg.recvchannel.wait()

        # Stop send data mode.
        self.avg_dr_start_reg = 0

        if self.dma_avg.recvchannel.transferred != transferlen*8:
            raise RuntimeError("Requested %d samples but only got %d from DMA" % (
                transferlen, self.dma_avg.recvchannel.transferred//8))

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

        if length >= self['buf_maxlen']:
            raise RuntimeError("requested length=%d longer or equal to decimated buffer size=%d" %
                               (length, self['buf_maxlen']))

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

        if length >= self['buf_maxlen']:
            raise RuntimeError("requested length=%d longer or equal to decimated buffer size=%d" %
                               (length, self['buf_maxlen']))

        # pad the transfer size to an even number (odd lengths seem to break the DMA)
        transferlen = length + (length % 2)

        # Route switch to channel.
        self.switch_buf.sel(slv=self.switch_ch)

        # time.sleep(0.050)

        # Set buffer data reader address and length.
        self.buf_dr_addr_reg = address
        self.buf_dr_len_reg = transferlen

        # Start send data mode.
        self.buf_dr_start_reg = 1

        # DMA data.
        buff = self.buf_buff
        # nbytes has to be a Python int (it gets passed to mmio.write, which requires int or bytes)
        self.dma_buf.recvchannel.transfer(buff, nbytes=int(transferlen*4))
        self.dma_buf.recvchannel.wait()

        if self.dma_buf.recvchannel.transferred != transferlen*4:
            raise RuntimeError("Requested %d samples but only got %d from DMA" % (
                transferlen, self.dma_buf.recvchannel.transferred//4))

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
        self.cfg['maxlen'] = 2**self.N * self.NM

        self.cfg['junk_len'] = 8

        # Preallocate memory buffers for DMA transfers.
        self.buff = allocate(shape=2*self['maxlen'], dtype=np.int16)

        # Map from avg_buf name to switch port.
        self.buf2switch = {}
        self.cfg['readouts'] = []

    def configure_connections(self, soc):
        self.soc = soc

        ((block, port),) = soc.metadata.trace_bus(self.fullpath, 'm00_axis')
        self.dma = getattr(soc, block)

        # readout, fullspeed output -> clock converter (optional) -> many-to-one switch -> MR buffer
        # readout, decimated output -> broadcaster (optional, for DDR) -> avg_buf

        # get the MR switch
        ((block, port),) = soc.metadata.trace_bus(self.fullpath, 's00_axis')
        self.switch = getattr(soc, block)

        # Number of slave interfaces.
        NUM_SI_param = int(soc.metadata.get_param(block, 'NUM_SI'))

        # Back trace all slaves.
        sw_block = block
        for iIn in range(NUM_SI_param):
            inname = "S%02d_AXIS" % (iIn)
            ((block, port),) = soc.metadata.trace_bus(sw_block, inname)

            # there may be a clock converter between the readout and the Mr switch
            if soc.metadata.mod2type(block) == "axis_clock_converter":
                ((block, port),) = soc.metadata.trace_bus(block, 'S_AXIS')

            # now we have the readout
            if soc.metadata.mod2type(block) == "axis_readout_v2":
                # we want to find the avg_buf driven by this readout
                ((block, port),) = soc.metadata.trace_bus(block, 'm1_axis')
                if soc.metadata.mod2type(block) == "axis_broadcaster":
                    br_block = block
                    for iOut in range(int(soc.metadata.get_param(br_block, 'NUM_MI'))):
                        ((block, port),) = soc.metadata.trace_bus(br_block, "M%02d_AXIS" % (iOut))
                        if soc.metadata.mod2type(block) == "axis_avg_buffer":
                            self.buf2switch[block] = iIn
                            self.cfg['readouts'].append(block)
                            break
            else:
                raise RuntimeError("failed to trace port for %s - unrecognized IP block %s" % (self.fullpath, block))


        # which tProc output bit triggers this buffer?
        ((block, port),) = soc.metadata.trace_sig(self.fullpath, 'trigger')
        # vect2bits/qick_vec2bit port names are of the form 'dout14'
        self.cfg['trigger_bit'] = int(port[4:])

        # which tProc output port triggers this buffer?
        # two possibilities:
        # tproc v1 output port -> axis_set_reg -> vect2bits -> buffer
        # tproc v2 data port -> vect2bits -> buffer
        ((block, port),) = soc.metadata.trace_sig(block, 'din')
        if soc.metadata.mod2type(block) == "axis_set_reg":
            ((block, port),) = soc.metadata.trace_bus(block, 's_axis')
        # ask the tproc to translate this port name to a channel number
        self.cfg['trigger_port'], self.cfg['trigger_type'] = getattr(soc, block).port2ch(port)

    def route(self, ch):
        # Route switch to channel.
        self.switch.sel(slv=ch)

    def set_switch(self, bufname):
        self.route(self.buf2switch[bufname])

    def transfer(self, start=None):
        if start is None: start = self['junk_len']

        # Start send data mode.
        self.dr_start_reg = 1

        # DMA data.
        self.dma.recvchannel.transfer(self.buff)
        self.dma.recvchannel.wait()

        # Stop send data mode.
        self.dr_start_reg = 0

        return np.copy(self.buff).reshape((-1,2))[start:]

    def enable(self):
        self.dw_capture_reg = 1

    def disable(self):
        self.dw_capture_reg = 0


class AxisBufferDdrV1(SocIp):
    """
    The DDR4 buffer block is similar to the decimated buffer in the avg_buffer block, except that data is written to DDR4 memory instead of FPGA memory.

    Typically multiple readouts will be connected to this buffer through a switch.
    The driver assumes that input(s) to this buffer are also sent to avg_buffer blocks.
    """
    # AXIS Buffer DDR V1 Registers.
    bindto = ['user.org:user:axis_buffer_ddr_v1:1.0']
    REGISTERS = {   'rstart_reg' : 0,
                    'raddr_reg'  : 1,
                    'rlength_reg': 2,
                    'wstart_reg' : 3,
                    'waddr_reg'  : 4,
                    'wnburst_reg': 5
                }

    # Stream Input Port.
    STREAM_IN_PORT  = "s_axis"

    def __init__(self, description):
        # Initialize ip
        super().__init__(description)

        # Default registers.
        self.rstart_reg  = 0
        self.raddr_reg   = 0
        self.rlength_reg = 10
        self.wstart_reg  = 0
        self.waddr_reg   = 0
        self.wnburst_reg = 10

        # DDR4 controller.
        self.ddr4_mem = None
        # DDR4 data array.
        self.ddr4_array = None

        # Switch for selecting input.
        self.switch = None
        # Map from avg_buf name to switch port.
        self.buf2switch = {}

        # Generics.
        self.TARGET_SLAVE_BASE_ADDR   = int(description['parameters']['TARGET_SLAVE_BASE_ADDR'],0)
        self.ID_WIDTH                 = int(description['parameters']['ID_WIDTH'])
        self.DATA_WIDTH               = int(description['parameters']['DATA_WIDTH']) # width of the AXI bus, in bits
        self.BURST_SIZE               = int(description['parameters']['BURST_SIZE']) + 1 # words per AXI burst

        self.cfg['burst_len'] = self.DATA_WIDTH*self.BURST_SIZE//32
        self.cfg['readouts'] = []
        self.cfg['junk_len'] = 50*self.DATA_WIDTH//32 + 1 # not clear where this 50 comes from, presumably some FIFO somewhere
        self.cfg['junk_nt'] = int(np.ceil(self['junk_len']/self.cfg['burst_len']))

    def configure_connections(self, soc):
        self.soc = soc

        # follow the output to find the DDR4 controller
        ((block,port),) = soc.metadata.trace_bus(self.fullpath, 'm_axi')
        # jump through the smartconnect
        ((block,port),) = soc.metadata.trace_bus(block, 'M00_AXI')
        self.ddr4_mem = getattr(soc, block)
        self.ddr4_array = self.ddr4_mem.mmio.array.view('uint32')
        self.cfg['maxlen'] = self.ddr4_array.shape[0]

        # Typical: buffer_ddr -> clock_converter -> dwidth_converter -> switch (optional) -> broadcaster
        # the broadcaster will feed this block and a regular avg_buf
        ((block,port),) = soc.metadata.trace_bus(self.fullpath, self.STREAM_IN_PORT)

        while True:
            blocktype = soc.metadata.mod2type(block)
            if blocktype == "axis_clock_converter":
                ((block, port),) = soc.metadata.trace_bus(block, 'S_AXIS')
            elif blocktype == "axis_dwidth_converter":
                ((block, port),) = soc.metadata.trace_bus(block, 'S_AXIS')
            elif blocktype == "axis_broadcaster":
                # no switch, just wired to a single readout
                ((block, port),) = soc.metadata.trace_bus(block, 'S_AXIS')
                for iOut in range(int(soc.metadata.get_param(block, 'NUM_MI'))):
                    outname = "M%02d_AXIS" % (iOut)
                    if outname != port:
                        ((bufname, _),) = soc.metadata.trace_bus(block, outname)
                        self.avg_buf = bufname
                        self.buf2switch[bufname] = 0
                break
            elif blocktype == "axis_switch":
                # Add switch
                self.switch = getattr(soc, block)

                # Number of slave interfaces.
                NUM_SI_param = int(soc.metadata.get_param(block, 'NUM_SI'))

                # Back trace all slaves.
                sw_block = block
                for iIn in range(NUM_SI_param):
                    inname = "S%02d_AXIS" % (iIn)
                    ((block, port),) = soc.metadata.trace_bus(sw_block, inname)

                    blocktype = soc.metadata.mod2type(block)
                    if blocktype == "axis_broadcaster":
                        br_block = block
                        for iOut in range(int(soc.metadata.get_param(br_block, 'NUM_MI'))):
                            ((block, port),) = soc.metadata.trace_bus(br_block, "M%02d_AXIS" % (iOut))
                            if soc.metadata.mod2type(block) == "axis_avg_buffer":
                                self.buf2switch[block] = iIn
                                self.cfg['readouts'].append(block)
                    else:
                        raise RuntimeError("tracing inputs to DDR4 switch and found something other than a broadcaster")
                break
            else:
                raise RuntimeError("failed to trace port for %s - unrecognized IP block %s" % (self.fullpath, block))

        # which tProc output bit triggers this buffer?
        ((block, port),) = soc.metadata.trace_sig(self.fullpath, 'trigger')
        # vect2bits/qick_vec2bit port names are of the form 'dout14'
        self.cfg['trigger_bit'] = int(port[4:])

        # which tProc output port triggers this buffer?
        # two possibilities:
        # tproc v1 output port -> axis_set_reg -> vect2bits -> buffer
        # tproc v2 data port -> vect2bits -> buffer
        ((block, port),) = soc.metadata.trace_sig(block, 'din')
        if soc.metadata.mod2type(block) == "axis_set_reg":
            ((block, port),) = soc.metadata.trace_bus(block, 's_axis')
        # ask the tproc to translate this port name to a channel number
        self.cfg['trigger_port'], self.cfg['trigger_type'] = getattr(soc, block).port2ch(port)

    def rstop(self):
        self.rstart_reg = 0

    def rstart(self):
        self.rstart_reg = 1

    def wstop(self):
        self.wstart_reg = 0

    def wstart(self):
        self.wstart_reg = 1

    def wlen(self, len_=10):
        """
        Set the number of bursts. Each burst is 256 IQ pairs.
        """
        self.wnburst_reg = len_

    def set_switch(self, bufname):
        # if there's no switch, just check that the specified buffer is the one that's hardwired
        if self.switch is None:
            assert self.buf2switch[bufname]==0
        self.switch.sel(slv=self.buf2switch[bufname])

    def clear_mem(self, length=None):
        if length is None:
            np.copyto(self.ddr4_array, 0)
        else:
            np.copyto(self.ddr4_array[:length], 0)

    def get_mem(self, nt, start=None):
        if start is None:
            start = self['junk_len']
            end = nt*self['burst_len']
        else:
            end = start + nt*self['burst_len']
        length = end-start

        # when we access memory-mapped data, the start and end need to be aligned to multiples of 64 bits.
        # violations result in the Python interpreter crashing on SIGBUS/BUS_ADRALN
        # this doesn't matter for all operations, but np.copy() definitely seems to care
        # it seems that even if you slice out an address-aligned chunk of data and just print it, sometimes that will access it in an illegal way
        # therefore we pad out the requested address block, copy the data, and trim
        # this way, no special care needs to be taken with the returned array
        buf_copy = self.ddr4_array[start - (start%2):end + (end%2)].copy()
        return buf_copy[start%2:length + start%2].view(dtype=np.int16).reshape((-1,2))

    def arm(self, nt, force_overwrite=False):
        if nt > self['maxlen']//self['burst_len'] and not force_overwrite:
            raise RuntimeError("the requested number of DDR4 transfers (nt) exceeds the memory size; the buffer will overwrite itself. You can disable this error message with force_overwrite=True.")
        self.wlen(nt)
        self.wstop()
        self.wstart()
