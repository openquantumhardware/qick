"""
The lower-level driver for the QICK library. Contains classes for interfacing with the SoC.
"""
import os
from pynq import Overlay, DefaultIP, allocate
try:
    import xrfclk
    import xrfdc
except:
    pass
import numpy as np
from pynq.lib import AxiGPIO
import time
from .parser import *
from .streamer import DataStreamer
from .qick_asm import QickConfig
from .helpers import trace_net, get_fclk, BusParser
from . import bitfile_path

class SocIp(DefaultIP):
    """
    SocIp class
    """
    REGISTERS = {}    
    
    def __init__(self, description, **kwargs):
        """
        Constructor method
        """
        #print("SocIp init", description)
        super().__init__(description)
        self.fullpath = description['fullpath']
        #self.ip = description
        
    def write(self, offset, value):
        """
        Writes a value to a register specified by an offset

        :param offset: Offset value (register)
        :type offset: int
        :param value: value to be written
        :type value: int
        """
        super().write(offset, value)
        
    def read(self, offset):
        """
        Reads an offset

        :param offset: Offset value
        :type offset: int
        """
        return super().read(offset)
    
    def __setattr__(self, a ,v):
        """
        Sets the arguments associated with a register

        :param a: Register specified by an offset value
        :type a: int
        :param v: value to be written
        :type v: int
        :return: Register arguments
        :rtype: *args object
        """
        if a in self.__class__.REGISTERS:
            super().write(4*self.__class__.REGISTERS[a], int(v))
        else:
            return super().__setattr__(a,v)
    
    def __getattr__(self, a):
        """
        Gets the arguments associated with a register

        :param a: register name
        :type a: str
        :return: Register arguments
        :rtype: *args object
        """
        if a in self.__class__.REGISTERS:
            return super().read(4*self.__class__.REGISTERS[a])
        else:
            return super().__getattribute__(a)           
        
class AbsSignalGen(SocIp):
    """
    Abstract class which defines methods that are common to different signal generators.
    """
    def __init__(self, description, **kwargs):
        """
        Constructor method
        """
        super().__init__(description)

    # Configure this driver with links to the other drivers, and the signal gen channel number.
    def configure(self, axi_dma, axis_switch, fs):
        # dma
        self.dma = axi_dma
        
        # Switch
        self.switch = axis_switch

        # Sampling frequency.
        self.fs = fs   

        # Frequency step for rounding.
        self.fstep = fs/(2**self.B_DDS)                 

    def configure_connections(self, soc, sigparser, busparser):
        # what tProc output port drives this generator?
        # we will eventually also use this to find out which tProc drives this gen, for multi-tProc firmwares
        ((block,port),) = trace_net(busparser, self.fullpath, 's1_axis')
        # might need to jump through an axis_clk_cnvrt
        if 'axis_tproc' not in block:
            ((block,port),) = trace_net(busparser, block, 'S_AXIS')
        # port names are of the form 'm2_axis_tdata'
        # subtract 1 to get the output channel number (m0 goes to the DMA)
        self.tproc_ch = int(port.split('_')[0][1:])-1

        # what switch port drives this generator?
        ((block,port),) = trace_net(busparser, self.fullpath, 's0_axis')
        # port names are of the form 'M01_AXIS'
        self.switch_ch = int(port.split('_')[0][1:])

        # what RFDC port does this generator drive?
        ((block,port),) = trace_net(busparser, self.fullpath, 'm_axis')
        # might need to jump through an axis_register_slice
        if 'rf_data_converter' not in block:
            ((block,port),) = trace_net(busparser, block, 'M_AXIS')
        # port names are of the form 's00_axis'
        self.dac = port[1:3]

        #print("%s: switch %d, tProc ch %d, DAC tile %s block %s"%(self.fullpath, self.switch_ch, self.tproc_ch, *self.dac))

    # Load waveforms.
    def load(self, xin_i, xin_q ,addr=0):
        """
        Load waveform into I,Q envelope

        :param xin_i: real part of envelope
        :type xin_i: list
        :param xin_q: imaginary part of envelope
        :type xin_q: list
        :param addr: starting address
        :type addr: int
        """
        # Check for equal length.
        if len(xin_i) != len(xin_q):
            print("%s: I/Q buffers must be the same length." % self.__class__.__name__)
            return
        
        # Check for max length.
        if len(xin_i) > self.MAX_LENGTH:
            print("%s: buffer length must be %d samples or less." % (self.__class__.__name__,self.MAX_LENGTH))
            return

        # Check for even transfer size.
        if len(xin_i) %2 != 0:
            raise RuntimeError("Buffer transfer length must be even number.")

        # Check for max length.
        if np.max(xin_i) > np.iinfo(np.int16).max or np.min(xin_i) < np.iinfo(np.int16).min:
            raise ValueError("real part of envelope exceeds limits of int16 datatype")

        if np.max(xin_q) > np.iinfo(np.int16).max or np.min(xin_q) < np.iinfo(np.int16).min:
            raise ValueError("imaginary part of envelope exceeds limits of int16 datatype")

        # Route switch to channel.
        self.switch.sel(mst=self.switch_ch)
        
        #time.sleep(0.050)
        
        # Format data.
        xin_i = xin_i.astype(np.int32)
        xin_q = xin_q.astype(np.int32)

        xin = xin_i + (xin_q << 16)
        
        # Define buffer.
        self.buff = allocate(shape=len(xin), dtype=np.int32)
        np.copyto(self.buff, xin)
        
        ################
        ### Load I/Q ###
        ################
        # Enable writes.
        self.wr_enable(addr)

        # DMA data.
        self.dma.sendchannel.transfer(self.buff)
        self.dma.sendchannel.wait()

        # Disable writes.
        self.wr_disable()        
        
    def wr_enable(self,addr=0):
        """
           Enable WE reg
        """
        self.start_addr_reg = addr
        self.we_reg = 1
        
    def wr_disable(self):
        """
           Disable WE reg
        """
        self.we_reg = 0
        
class AxisSignalGen(AbsSignalGen):
    """
    AxisSignalGen class
    Supports AxisSignalGenV4 and AxisSignalGenV5, since they have the same software interface (ignoring registers that are not used)

    AXIS Signal Generator Registers.
    START_ADDR_REG

    WE_REG
    * 0 : disable writes.
    * 1 : enable writes.
    """
    bindto = ['user.org:user:axis_signal_gen_v4:1.0', 'user.org:user:axis_signal_gen_v5:1.0']
    REGISTERS = {'start_addr_reg':0, 'we_reg':1, 'rndq_reg':2}
    
    def __init__(self, description, **kwargs):
        """
        Constructor method
        """
        super().__init__(description)
        
        # Default registers.
        self.start_addr_reg=0
        self.we_reg=0
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
                
class AxisSgInt4V1(SocIp):
    """
    AxisSgInt4V1

    AXIS Signal Generator with envelope x4 interpolation V1 Registers.
    START_ADDR_REG

    WE_REG
    * 0 : disable writes.
    * 1 : enable writes.
    """
    bindto = ['user.org:user:axis_sg_int4_v1:1.0']
    REGISTERS = {'start_addr_reg':0, 'we_reg':1}
    
    def __init__(self, description, **kwargs):
        """
        Constructor method
        """
        super().__init__(description)
        
        # Default registers.
        self.start_addr_reg=0
        self.we_reg=0

        # Generics
        self.N = int(description['parameters']['N'])
        self.NDDS = 4 # Fixed by design, not accesible.
                
        # Frequency resolution
        self.B_DDS = 16      

        # Maximum number of samples
        self.MAX_LENGTH = 2**self.N # Table is interpolated. Length is given only by parameter N.

        ## Get the channel number from the IP instance name.
        #self.ch = int(description['fullpath'].split('_')[-1])
        
class AxisSgMux4V1(AbsSignalGen):
    """
    AxisSgMux4V1

    AXIS Signal Generator with 4 muxed outputs V1 registers.
    
    PINC0_REG : frequency of waveform 0.
    PINC1_REG : frequency of waveform 1.
    PINC2_REG : frequency of waveform 2.
    PINC3_REG : frequency of waveform 3.

    WE_REG
    * 0 : disable writes.
    * 1 : enable writes.
    """
    bindto = ['user.org:user:axis_sg_mux4_v1:1.0']
    REGISTERS = {'pinc0_reg':0,'pinc1_reg':1,'pinc2_reg':2,'pinc3_reg':3, 'we_reg':4}
    
    def __init__(self, description, **kwargs):
        """
        Constructor method
        """
        super().__init__(description)
        
        # Default registers.
        self.pinc0_reg=0
        self.pinc1_reg=0
        self.pinc2_reg=0
        self.pinc3_reg=0
        self.we_reg=0

        # Generics
        self.NDDS = int(description['parameters']['N_DDS'])        
                
        # Frequency resolution
        self.B_DDS = 16      
        
        # NOTE: Only added to avoid errors when parsing.
        #TODO: do something more sensible
        self.ch = int(description['fullpath'].split('_')[-1])
        self.switch_ch = self.ch
        self.MAX_LENGTH = 0
        
    # Configure this driver with links to the other drivers, and the signal gen channel number.
    def configure(self, axi_dma, axis_switch, fs):
        # Sampling frequency: 4x Interpolation applied by DAC IP.
        self.fs = fs/4
        
        # Frequency step for rounding.
        self.fstep = self.fs/(2**self.B_DDS)     
        
    def configure_connections(self, soc, sigparser, busparser):
        self.soc = soc

        # what tProc output port drives this generator?
        # we will eventually also use this to find out which tProc drives this gen, for multi-tProc firmwares
        ((block,port),) = trace_net(busparser, self.fullpath, 's_axis')
        # might need to jump through an axis_clk_cnvrt
        if 'axis_tproc' not in block:
            ((block,port),) = trace_net(busparser, block, 'S_AXIS')
        # port names are of the form 'm2_axis_tdata'
        # subtract 1 to get the output channel number (m0 goes to the DMA)
        self.tproc_ch = int(port.split('_')[0][1:])-1

        # what RFDC port does this generator drive?
        ((block,port),) = trace_net(busparser, self.fullpath, 'm_axis')
        # port names are of the form 's00_axis'
        self.dac = port[1:3]        

    def update(self):
        """
        Update register values
        """
        self.we_reg = 1
        self.we_reg = 0
            
    def set_freq(self, f, out=0):
        """
        Set frequency register

        :param f: frequency in MHz
        :type f: float
        :param out: muxed channel to configure
        :type out: int
        :param dac_ch: DAC channel (use None if you don't want to round to a valid DAC frequency)
        :type dac_ch: int
        """
        # Sanity check.
        if f<self.fs:
            k_i = np.int64(self.soc.freq2reg_adc(f, ro_ch=self.ch))
        
    def set_freq_int(self, k_i, out=0):
        if out==0:
            self.pinc0_reg = k_i
        elif out==1:
            self.pinc1_reg = k_i
        elif out==2:
            self.pinc2_reg = k_i
        elif out==3:
            self.pinc3_reg = k_i                
            
        # Register update.
        self.update()              
                
class AxisConstantIQ(SocIp):
    # AXIS Constant IQ registers:
    # REAL_REG : 16-bit.
    # IMAG_REG : 16-bit.
    # WE_REG   : 1-bit. Update registers.
    bindto = ['user.org:user:axis_constant_iq:1.0']
    REGISTERS = {'real_reg':0, 'imag_reg':1, 'we_reg':2}
    
    # Number of bits.
    B = 16
    MAX_V = 2**(B-1)-1
        
    def __init__(self, description):
        # Initialize ip
        super().__init__(description)
        
        # Default registers.
        self.real_reg = 30000
        self.imag_reg = 30000
        
        # Register update.
        self.update()
        
    def config(self, tile, block, fs):
        self.tile = tile
        self.dac = block
        self.fs = fs

    def update(self):
        self.we_reg = 1        
        self.we_reg = 0
        
    def set_iq(self,i=1,q=1):
        # Set registers.
        self.real_reg = int(i*self.MAX_V)
        self.imag_reg = int(q*self.MAX_V)
        
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
    * 2 : bypass.

    MODE_REG : 1-bit.
    * 0 : NSAMP.
    * 1 : Periodic.

    WE_REG : enable/disable to perform register update.

    :param ip: IP address
    :type ip: str
    :param fs: sampling frequency in MHz
    :type fs: float
    """
    bindto = ['user.org:user:axis_readout_v2:1.0']
    REGISTERS = {'freq_reg':0, 'phase_reg':1, 'nsamp_reg':2, 'outsel_reg':3, 'mode_reg': 4, 'we_reg':5}
    
    # Bits of DDS.
    B_DDS = 32
    
    def __init__(self, description, **kwargs):
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
    def configure(self, ch, fs):
        # Channel number.
        self.ch = ch
        # Frequency step for rounding.
        self.fstep = fs/(2**self.B_DDS)
        # Sampling frequency.
        self.fs = fs
        
    def configure_connections(self, soc, sigparser, busparser):
        self.soc = soc

        # what RFDC port drives this readout?
        ((block,port),) = trace_net(busparser, self.fullpath, 's_axis')
         # might need to jump through an axis_register_slice
        if 'rf_data_converter' not in block:
            ((block,port),) = trace_net(busparser, block, 'S_AXIS')
        # port names are of the form 'm02_axis' where the block number is always even
        iTile, iBlock = [int(x) for x in port[1:3]]
        if soc.hs_adc:
            iBlock //= 2
        self.adc = "%d%d"%(iTile, iBlock)

        # what buffer does this readout drive?
        ((block,port),) = trace_net(busparser, self.fullpath, 'm1_axis')
        self.buffer = getattr(soc, block)

        #print("%s: ADC tile %s block %s, buffer %s"%(self.fullpath, *self.adc, self.buffer.fullpath))

    def update(self):
        """
        Update register values
        """
        self.we_reg = 1
        self.we_reg = 0
        
    def set_out(self,sel="product"):
        """
        Select readout signal output

        :param sel: select mux control
        :type sel: int
        """
        self.outsel_reg={"product":0,"dds":1,"input":2}[sel]
            
        # Register update.
        self.update()
            
    def set_freq(self, f, dac_ch=0):
        """
        Set frequency register

        :param f: frequency in MHz
        :type f: float
        :param dac_ch: DAC channel (use None if you don't want to round to a valid DAC frequency)
        :type dac_ch: int
        """
        # Sanity check.
        if f<self.fs:
            self.freq_reg = np.int64(self.soc.freq2reg_adc(f, ro_ch=self.ch))
            
        # Register update.
        self.update()
        
    def set_freq_int(self, f_int):
        """
        Set frequency register (integer version)

        :param f_int: frequency value register
        :type f_int: int
        """
        self.freq_reg = f_int
            
        # Register update.
        self.update()        
        
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

    :param ip: IP address
    :type ip: str
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
    REGISTERS = {'avg_start_reg'    : 0, 
                 'avg_addr_reg'     : 1,
                 'avg_len_reg'      : 2,
                 'avg_dr_start_reg' : 3,
                 'avg_dr_addr_reg'  : 4,
                 'avg_dr_len_reg'   : 5,
                 'buf_start_reg'    : 6, 
                 'buf_addr_reg'     : 7,
                 'buf_len_reg'      : 8,
                 'buf_dr_start_reg' : 9,
                 'buf_dr_addr_reg'  : 10,
                 'buf_dr_len_reg'   : 11}
    
    def __init__(self, description, **kwargs):
        """
        Constructor method
        """
        super().__init__(description)
        
        # Default registers.
        self.avg_start_reg    = 0
        self.avg_dr_start_reg = 0
        self.buf_start_reg    = 0
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
        
    def configure_connections(self, soc, sigparser, busparser):
        # which readout drives this buffer?
        ((block,port),) = trace_net(busparser, self.fullpath, 's_axis')
        self.readout = getattr(soc, block)

        # which switch_avg port does this buffer drive?
        ((block,port),) = trace_net(busparser, self.fullpath, 'm0_axis')
        # port names are of the form 'S01_AXIS'
        switch_avg_ch = int(port.split('_')[0][1:],10)

        # which switch_buf port does this buffer drive?
        ((block,port),) = trace_net(busparser, self.fullpath, 'm1_axis')
        # port names are of the form 'S01_AXIS'
        switch_buf_ch = int(port.split('_')[0][1:],10)
        if switch_avg_ch!=switch_buf_ch:
            raise RuntimeError("switch_avg and switch_buf port numbers do not match:",self.fullpath)
        self.switch_ch = switch_avg_ch

        # which tProc output bit triggers this buffer?
        ((block,port),) = trace_net(sigparser, self.fullpath, 'trigger')
        # port names are of the form 'dout14'
        self.trigger_bit = int(port[4:])

        # which tProc input port does this buffer drive?
        ((block,port),) = trace_net(busparser, self.fullpath, 'm2_axis')
        # jump through an axis_clk_cnvrt
        ((block,port),) = trace_net(busparser, block, 'M_AXIS')
        # port names are of the form 's1_axis'
        # subtract 1 to get the channel number (s0 comes from the DMA)
        self.tproc_ch = int(port.split('_')[0][1:])-1

        #print("%s: readout %s, switch %d, trigger %d, tProc port %d"%(self.fullpath, self.readout.fullpath, self.switch_ch, self.trigger_bit, self.tproc_ch))


    def config(self,address=0,length=100):
        """
        Configure both average and raw buffers

        :param addr: Start address of first capture
        :type addr: int
        :param length: window size
        :type length: int
        """
        # Configure averaging and buffering to the same address and length.
        self.config_avg(address=address,length=length)
        self.config_buf(address=address,length=length)
        
    def enable(self):
        """
        Enable both average and raw buffers
        """
        # Enable both averager and buffer.
        self.enable_avg()
        self.enable_buf()
        
    def config_avg(self,address=0,length=100):
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
        
    def transfer_avg(self,address=0,length=100):
        """
        Transfer average buffer data from average and buffering readout block.

        :param addr: starting reading address
        :type addr: int
        :param length: number of samples
        :type length: int
        :return: I,Q pairs
        :rtype: list
        """

        if length %2 != 0:
            raise RuntimeError("Buffer transfer length must be even number.")
        if length >= self.AVG_MAX_LENGTH:
            raise RuntimeError("length=%d longer than %d"%(length, self.AVG_MAX_LENGTH))

        # Route switch to channel.
        self.switch_avg.sel(slv=self.switch_ch)
        
        # Set averager data reader address and length.
        self.avg_dr_addr_reg = address
        self.avg_dr_len_reg = length
        
        # Start send data mode.
        self.avg_dr_start_reg = 1
        
        # DMA data.
        buff = self.avg_buff
        self.dma_avg.recvchannel.transfer(buff,nbytes=length*8)
        self.dma_avg.recvchannel.wait()

        if self.dma_avg.recvchannel.transferred != length*8:
            raise RuntimeError("Requested %d samples but only got %d from DMA" % (length, self.dma_avg.recvchannel.transferred//8))

        # Stop send data mode.
        self.avg_dr_start_reg = 0

        # Format:
        # -> lower 32 bits: I value.
        # -> higher 32 bits: Q value.
        data = buff[:length]
        dataI = data & 0xFFFFFFFF
        dataQ = data >> 32

        return np.stack((dataI,dataQ)).astype(np.int32)
        
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
        
    def config_buf(self,address=0,length=100):
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
        
    def transfer_buf(self,address=0,length=100):
        """
        Transfer raw buffer data from average and buffering readout block

        :param addr: starting reading address
        :type addr: int
        :param length: number of samples
        :type length: int
        :return: I,Q pairs
        :rtype: list
        """

        if length %2 != 0:
            raise RuntimeError("Buffer transfer length must be even number.")
        if length >= self.BUF_MAX_LENGTH:
            raise RuntimeError("length=%d longer or equal to %d"%(length, self.BUF_MAX_LENGTH))

        # Route switch to channel.
        self.switch_buf.sel(slv=self.switch_ch)
        
        #time.sleep(0.050)
        
        # Set buffer data reader address and length.
        self.buf_dr_addr_reg = address
        self.buf_dr_len_reg = length
        
        # Start send data mode.
        self.buf_dr_start_reg = 1
        
        # DMA data.
        buff = self.buf_buff
        self.dma_buf.recvchannel.transfer(buff,nbytes=length*4)
        self.dma_buf.recvchannel.wait()

        if self.dma_buf.recvchannel.transferred != length*4:
            raise RuntimeError("Requested %d samples but only got %d from DMA" % (length, self.dma_buf.recvchannel.transferred//4))

        # Stop send data mode.
        self.buf_dr_start_reg = 0

        # Format:
        # -> lower 16 bits: I value.
        # -> higher 16 bits: Q value.
        data = buff[:length]
        dataI = data & 0xFFFF
        dataQ = data >> 16

        return np.stack((dataI,dataQ)).astype(np.int16)
        
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
    REGISTERS = {'dw_capture_reg':0, 'dr_start_reg':1}
        
    def __init__(self, description):    
        # Init IP.
        super().__init__(description)
        
        # Default registers.
        self.dw_capture_reg=0
        self.dr_start_reg=0
        
        # Generics
        self.B = int(description['parameters']['B'])
        self.N = int(description['parameters']['N'])
        self.NM = int(description['parameters']['NM'])

        # Maximum number of samples
        self.MAX_LENGTH = 2**self.N * self.NM          

        # Preallocate memory buffers for DMA transfers.
        self.buff = allocate(shape=self.MAX_LENGTH, dtype=np.int32)        
    
    def config(self, dma, switch):
        self.dma = dma
        self.switch = switch
        
    def route(self,ch):
        # Route switch to channel.
        self.switch.sel(slv=ch)
        
    def transfer(self):
        # Start send data mode.
        self.dr_start_reg = 1
        
        # DMA data.        
        buff = self.buff
        self.dma.recvchannel.transfer(buff)
        self.dma.recvchannel.wait()        

        # Stop send data mode.
        self.dr_start_reg = 0
        
        # Format:
        # -> lower 16 bits: I value.
        # -> higher 16 bits: Q value.
        data = buff
        dataI = data & 0xFFFF
        dataQ = data >> 16
        
        return np.stack((dataI,dataQ)).astype(np.int16)        
        
    def enable(self):
        self.dw_capture_reg = 1
        
    def disable(self):
        self.dw_capture_reg = 0
        
class AxisTProc64x32_x8(SocIp):
    """
    AxisTProc64x32_x8 class

    AXIS tProcessor registers:
    START_SRC_REG
    * 0 : internal start.
    * 1 : external start.

    START_REG
    * 0 : stop.
    * 1 : start.

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

    :param ip: IP address
    :type ip: str
    :param mem: memory address
    :type mem: int
    :param axi_dma: axi_dma address
    :type axi_dma: int
    """
    bindto = ['user.org:user:axis_tproc64x32_x8:1.0']
    REGISTERS = {'start_src_reg' : 0, 
                 'start_reg' : 1, 
                 'mem_mode_reg' : 2, 
                 'mem_start_reg' : 3, 
                 'mem_addr_reg' : 4, 
                 'mem_len_reg' : 5}
    
    # Reserved lower memory section for register access.
    DMEM_OFFSET = 256 
    
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
        self.start_reg     = 0
        self.mem_mode_reg  = 0
        self.mem_start_reg = 0
        self.mem_addr_reg  = 0
        self.mem_len_reg   = 100

        # Generics.
        self.DMEM_N = int(description['parameters']['DMEM_N'])
        self.PMEM_N = int(description['parameters']['PMEM_N'])
        
    # Configure this driver with links to its memory and DMA.
    def configure(self, mem, axi_dma):
        # Program memory.
        self.mem = mem

        # dma
        self.dma = axi_dma 

    def start_src(self,src=0):
        """
        Sets the start source of tProc

        :param src: start source
        :type src: int
        """
        self.start_src_reg = src
        
    def start(self):
        """
        Start tProc from register
        """
        self.start_reg = 1
        
    def stop(self):
        """
        Stop tProc from register
        """
        self.start_reg = 0
        
    def load_bin_program(self, binprog):
        for ii,inst in enumerate(binprog):
            dec_low = inst & 0xffffffff
            dec_high = inst >> 32
            self.mem.write(8*ii, value=int(dec_low))
            self.mem.write(4*(2*ii+1), value=int(dec_high))
        
    def load_qick_program(self, prog, debug= False):
        """
        :param prog: the QickProgram to load
        :type prog: str
        :param debug: Debug option
        :type debug: bool
        """
        self.load_bin_program(prog.compile(debug=debug))
        
    def load_program(self,prog="prog.asm",fmt="asm"):
        """
        Loads tProc program. If asm progam, it compiles first

        :param prog: program file name
        :type prog: string
        :param fmt: file format
        :type fmt: string
        """
        # Binary file format.
        if fmt == "bin":
            # Read binary file from disk.
            fd = open(prog,"r")
            
            # Write memory.
            addr = 0
            for line in fd:
                line.strip("\r\n")
                dec = int(line,2)
                dec_low = dec & 0xffffffff
                dec_high = dec >> 32
                self.mem.write(addr,value=int(dec_low))
                addr = addr + 4
                self.mem.write(addr,value=int(dec_high))
                addr = addr + 4                
                
        # Asm file.
        elif fmt == "asm":
            # Compile program.
            progList = parse_to_bin(prog)
        
            # Load Program Memory.
            addr = 0
            for dec in progList:
                #print ("@" + str(addr) + ": " + str(dec))
                dec_low = dec & 0xffffffff
                dec_high = dec >> 32
                self.mem.write(addr,value=int(dec_low))
                addr = addr + 4
                self.mem.write(addr,value=int(dec_high))
                addr = addr + 4   
                
    def single_read(self, addr):
        """
        Reads one sample of tProc data memory using AXI access

        :param addr: reading address
        :type addr: int
        :param data: value to be written
        :type data: int
        :return: requested value
        :rtype: int
        """
        # Address should be translated to upper map.
        addr_temp = 4*addr + self.DMEM_OFFSET
            
        # Read data.
        data = self.read(addr_temp)
            
        return data
    
    def single_write(self, addr=0, data=0):
        """
        Writes one sample of tProc data memory using AXI access

        :param addr: writing address
        :type addr: int
        :param data: value to be written
        :type data: int
        """
        # Address should be translated to upper map.
        addr_temp = 4*addr + self.DMEM_OFFSET
            
        # Write data.
        self.write(addr_temp,value=int(data))
        
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
        np.copyto(self.buff,buff_in)

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
    
class AxisSwitch(SocIp):
    """
    AxisSwitch class to control Xilinx AXI-Stream switch IP

    :param ip: IP address
    :type ip: str
    :param nslave: Number of slave interfaces
    :type nslave: int
    :param nmaster: Number of master interfaces
    :type nmaster: int
    """
    bindto = ['xilinx.com:ip:axis_switch:1.1']
    REGISTERS = {'ctrl': 0x0, 'mix_mux': 0x040}
    
    def __init__(self, description, **kwargs):
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
            self.write(offset,0x80000000)
        
    def sel(self, mst=0, slv=0):
        """
        Digitally connects a master interface with a slave interface

        :param mst: Master interface
        :type mst: int
        :param slv: Slave interface
        :type slv: int
        """
        # Sanity check.
        if slv>self.NSL-1:
            print("%s: Slave number %d does not exist in block." % __class__.__name__)
            return
        if mst>self.NMI-1:
            print("%s: Master number %d does not exist in block." % __class__.__name__)
            return
        
        # Disable register update.
        self.ctrl = 0

        # Disable all MI ports.
        self.disable_ports()
        
        # MI[mst] -> SI[slv]
        offset = self.REGISTERS['mix_mux'] + 4*mst
        self.write(offset,slv)

        # Enable register update.
        self.ctrl = 2     


class Mixer:    
    # rf
    rf = 0
    
    def __init__(self, ip):        
        # Get Mixer Object.
        self.rf = ip
    
    def set_freq(self,f,tile,dac):
        # Make a copy of mixer settings.
        dac_mixer = self.rf.dac_tiles[tile].blocks[dac].MixerSettings        
        new_mixcfg = dac_mixer.copy()

        # Update the copy
        new_mixcfg.update({
            'EventSource': xrfdc.EVNT_SRC_IMMEDIATE,
            'Freq' : f,
            'MixerType': xrfdc.MIXER_TYPE_FINE,
            'PhaseOffset' : 0})

        # Update settings.                
        self.rf.dac_tiles[tile].blocks[dac].MixerSettings = new_mixcfg
        self.rf.dac_tiles[tile].blocks[dac].UpdateEvent(xrfdc.EVENT_MIXER)
       
    def set_nyquist(self,nz,tile,dac):
        dac_tile = self.rf.dac_tiles[tile]
        dac_block = dac_tile.blocks[dac]
        dac_block.NyquistZone = nz  
        
class QickSoc(Overlay, QickConfig):
    """
    QickSoc class. This class will create all object to access system blocks

    :param bitfile: Name of the bitfile
    :type bitfile: str
    :param force_init_clks: Whether the board clocks are re-initialized
    :type force_init_clks: bool
    :param ignore_version: Whether version discrepancies between PYNQ build and firmware build are ignored
    :type ignore_version: bool
    """

    # The following constants are no longer used. Some of the values may not match the bitfile.
    #fs_adc = 384*8 # MHz
    #fs_dac = 384*16 # MHz
    #pulse_mem_len_IQ = 65536 # samples for I, Q
    #ADC_decim_buf_len_IQ = 1024 # samples for I, Q
    #ADC_accum_buf_len_IQ = 16384 # samples for I, Q
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
    def __init__(self, bitfile=None, force_init_clks=False,ignore_version=True, **kwargs):
        """
        Constructor method
        """
        # Load bitstream. We read the bitstream configuration from the HWH file, but we don't program the FPGA yet.
        # We need to program the clocks first.
        if bitfile==None:
            Overlay.__init__(self, bitfile_path(), ignore_version=ignore_version, download=False, **kwargs)
        else:
            Overlay.__init__(self, bitfile, ignore_version=ignore_version, download=False, **kwargs)

        # Configuration dictionary
        self._cfg = {}

        self['board'] = os.environ["BOARD"]

        # Read the config to get a list of enabled ADCs and DACs, and the sampling frequencies.
        self.list_rf_blocks(self.ip_dict['usp_rf_data_converter_0']['parameters'])

        # Configure PLLs if requested, or if any ADC/DAC is not locked.
        if force_init_clks:
            self.set_all_clks()
            self.download()
        else:
            self.download()
            if not self.clocks_locked():
                self.set_all_clks()
                self.download()
        if not self.clocks_locked():
            print("Not all DAC and ADC PLLs are locked. You may want to repeat the initialization of the QickSoc.")

        # RF data converter (for configuring ADCs and DACs)
        self.rf = self.usp_rf_data_converter_0

        # AXIS Switch to upload samples into Signal Generators.
        self.switch_gen = self.axis_switch_gen

        # AXIS Switch to read samples from averager.
        self.switch_avg = self.axis_switch_avg
        
        # AXIS Switch to read samples from buffer.
        self.switch_buf = self.axis_switch_buf
        
        # Signal generators.
        self.gens = []

        # Average + Buffer blocks.
        self.avg_bufs = []

        # Use the HWH parser to trace connectivity and deduce the channel numbering.
        # Since the HWH parser doesn't parse buses, we also make our own BusParser.
        busparser = BusParser(self.parser)
        for key,val in self.ip_dict.items():
            if hasattr(val['driver'],'configure_connections'):
                getattr(self,key).configure_connections(self, self.parser, busparser)

        gen_drivers = set([AxisSignalGen, AxisSgInt4V1, AxisSgMux4V1])

        # Populate the lists with the registered IP blocks.
        for key,val in self.ip_dict.items():
            if (val['driver'] in gen_drivers):
                self.gens.append(getattr(self,key))
            elif (val['driver'] == AxisAvgBuffer):
                self.avg_bufs.append(getattr(self,key))

        # Sanity check: we should have the same number of signal generators as switch ports.
        #TODO: update?
        #if self.switch_gen.NMI != len(self.gens):
        #    raise RuntimeError("We have %d switch_gen outputs but %d signal generators."%(len(self.switch_gen.NMI),len(self.gens)))

        # Sanity check: we should have the same number of readouts and buffer blocks as switch ports.
        if self.switch_avg.NSL != len(self.avg_bufs):
            raise RuntimeError("We have %d switch_avg inputs but %d avg/buffer blocks."%(len(self.switch_avg.NSL),len(self.avg_bufs)))
        if self.switch_buf.NSL != len(self.avg_bufs):
            raise RuntimeError("We have %d switch_buf inputs but %d avg/buffer blocks."%(len(self.switch_buf.NSL),len(self.avg_bufs)))

        # Sort the lists by channel number.
        # Typically they are already in order, but good to make sure?
        # The single source of truth for channel numbering is the switch port index.
        self.gens.sort(key=lambda x: x.switch_ch)
        self.avg_bufs.sort(key=lambda x: x.switch_ch)

        # Readout blocks.
        self.readouts = [buf.readout for buf in self.avg_bufs]

        # Fill the config dictionary with driver parameters.
        self['b_dac'] = self.gens[0].B_DDS #typically 32
        self['b_adc'] = self.readouts[0].B_DDS #typically 32

        self['gens'] = []
        self['readouts'] = []
        for iGen,gen in enumerate(self.gens):
            thiscfg = {}
            thiscfg['maxlen'] = gen.MAX_LENGTH
            thiscfg['b_dds'] = gen.B_DDS
            thiscfg['tproc_ch'] = gen.tproc_ch
            thiscfg['dac'] = gen.dac
            thiscfg['fs'] = self.dacs[gen.dac]['fs']
            thiscfg['f_fabric'] = self.dacs[gen.dac]['f_fabric']
            self['gens'].append(thiscfg)

        for iBuf,buf in enumerate(self.avg_bufs):
            thiscfg = {}
            thiscfg['avg_maxlen'] = buf.AVG_MAX_LENGTH
            thiscfg['buf_maxlen'] = buf.BUF_MAX_LENGTH
            thiscfg['b_dds'] = buf.readout.B_DDS
            thiscfg['adc'] = buf.readout.adc
            thiscfg['fs'] = self.adcs[buf.readout.adc]['fs']
            thiscfg['f_fabric'] = self.adcs[buf.readout.adc]['f_fabric']
            thiscfg['trigger_bit'] = buf.trigger_bit
            thiscfg['tproc_ch'] = buf.tproc_ch
            self['readouts'].append(thiscfg)

        # tProcessor, 64-bit instruction, 32-bit registers, x8 channels.
        self._tproc  = self.axis_tproc64x32_x8_0
        self._tproc.configure(self.axi_bram_ctrl_0, self.axi_dma_tproc)

        self['fs_proc'] = get_fclk(self.parser, self.tproc.fullpath, "aclk")

        self._streamer = DataStreamer(self)

        # Initialize the configuration (this will calculate the frequency plan)
        QickConfig.__init__(self)

        # Configure the drivers.
        for gen in self.gens:
            gen.configure(self.axi_dma_gen, self.switch_gen, self.dacs[gen.dac]['fs'])

        for i,readout in enumerate(self.readouts):
            readout.configure(i, self.adcs[readout.adc]['fs'])

        for buf in self.avg_bufs:
            buf.configure(self.axi_dma_avg, self.switch_avg,
                          self.axi_dma_buf, self.switch_buf)

        # Mixer for NCO ADC/DAC control.
        self.mixer = Mixer(self.usp_rf_data_converter_0)

        # list of objects that need to be registered for autoproxying over Pyro
        self.autoproxy = [self.streamer, self.tproc]

    @property
    def tproc(self):
        return self._tproc

    @property
    def streamer(self):
        return self._streamer

    def clocks_locked(self):
        """
        Checks whether the DAC and ADC PLLs are locked.
        This can only be run after the bitstream has been downloaded.

        :return: clock status
        :rtype: bool
        """

        dac_locked = [self.usp_rf_data_converter_0.dac_tiles[iTile].PLLLockStatus==2 for iTile in self.dac_tiles]
        adc_locked = [self.usp_rf_data_converter_0.adc_tiles[iTile].PLLLockStatus==2 for iTile in self.adc_tiles]
        return (all(dac_locked) and all(adc_locked))

    def list_rf_blocks(self, rf_config):
        """
        Lists the enabled ADCs and DACs and get the sampling frequencies.
        XRFdc_CheckBlockEnabled in xrfdc_ap.c is not accessible from the Python interface to the XRFdc driver.
        This re-implements that functionality.
        """

        self.hs_adc = rf_config['C_High_Speed_ADC']=='1'

        self.dac_tiles = []
        self.adc_tiles = []
        dac_fabric_freqs = []
        adc_fabric_freqs = []
        refclk_freqs = []
        self.dacs = {}
        self.adcs = {}

        for iTile in range(4):
            if rf_config['C_DAC%d_Enable'%(iTile)]!='1':
                continue
            self.dac_tiles.append(iTile)
            f_fabric = float(rf_config['C_DAC%d_Fabric_Freq'%(iTile)])
            f_refclk = float(rf_config['C_DAC%d_Refclk_Freq'%(iTile)])
            dac_fabric_freqs.append(f_fabric)
            refclk_freqs.append(f_refclk)
            fs = float(rf_config['C_DAC%d_Sampling_Rate'%(iTile)])*1000
            for iBlock in range(4):
                if rf_config['C_DAC_Slice%d%d_Enable'%(iTile,iBlock)]!='true':
                    continue
                self.dacs["%d%d"%(iTile,iBlock)] = {'fs':fs,
                                                    'f_fabric':f_fabric}

        for iTile in range(4):
            if rf_config['C_ADC%d_Enable'%(iTile)]!='1':
                continue
            self.adc_tiles.append(iTile)
            f_fabric = float(rf_config['C_ADC%d_Fabric_Freq'%(iTile)])
            f_refclk = float(rf_config['C_ADC%d_Refclk_Freq'%(iTile)])
            adc_fabric_freqs.append(f_fabric)
            refclk_freqs.append(f_refclk)
            fs = float(rf_config['C_ADC%d_Sampling_Rate'%(iTile)])*1000
            for iBlock in range(4):
                if self.hs_adc:
                    if iBlock>=2 or rf_config['C_ADC_Slice%d%d_Enable'%(iTile,2*iBlock)]!='true':
                        continue
                else:
                    if rf_config['C_ADC_Slice%d%d_Enable'%(iTile,iBlock)]!='true':
                        continue
                self.adcs["%d%d"%(iTile,iBlock)] = {'fs':fs,
                                                    'f_fabric':f_fabric}

        def get_common_freq(freqs):
            """
            Check that all elements of the list are equal, and return the common value.
            """
            if not freqs: # input is empty list
                return None
            if len(set(freqs))!=1:
                raise RuntimeError("Unexpected frequencies:",freqs)
            return freqs[0]

        self['refclk_freq'] = get_common_freq(refclk_freqs)

    def set_all_clks(self):
        """
        Resets all the board clocks
        """
        if self['board']=='ZCU111':
            print("resetting clocks:",self['refclk_freq'])
            xrfclk.set_all_ref_clks(self['refclk_freq'])
        elif self['board']=='ZCU216':
            lmk_freq = self['refclk_freq']
            lmx_freq = self['refclk_freq']*2
            print("resetting clocks:",lmk_freq, lmx_freq)
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
        transfer_len = length + length%2

        # there is a bug which causes the first sample of a transfer to always be the sample at address 0
        # we work around this by requesting an extra 2 samples at the beginning
        data = self.avg_bufs[ch].transfer_buf((address-2)%self.avg_bufs[ch].BUF_MAX_LENGTH,transfer_len+2)

        # we remove the padding here
        return data[:,2:length+2].astype(float)

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
        transfer_len = length + length%2

        # there is a bug which causes the first sample of a transfer to always be the sample at address 0
        # we work around this by requesting an extra 2 samples at the beginning
        data = self.avg_bufs[ch].transfer_avg((address-2)%self.avg_bufs[ch].AVG_MAX_LENGTH,transfer_len+2)

        # we remove the padding here
        return data[:,2:length+2]
    
    def configure_readout(self, ch, output, frequency):
        """Configure readout channel output style and frequency
        :param ch: Channel to configure
        :type ch: int
        :param output: output type from 'product', 'dds', 'input'
        :type output: str
        """
        self.readouts[ch].set_out(sel=output)
        self.readouts[ch].set_freq(frequency)

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
        self.avg_bufs[ch].config_avg(address, length)
        if enable:
            self.enable_avg(ch)
        
    def enable_avg(self, ch):
        self.avg_bufs[ch].enable_avg()
    
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
        self.avg_bufs[ch].config_buf(address, length)
        if enable:
            self.enable_buf(ch)

    def enable_buf(self, ch):
        self.avg_bufs[ch].enable_buf()
        
    def get_avg_max_length(self, ch=0):
        """Get accumulation buffer length for channel
        :param ch: Channel
        :type ch: int
        :return: Length of accumulation buffer for channel 'ch'
        :rtype: int
        """
        return self['readouts'][ch]['avg_maxlen']

    def load_pulse_data(self, ch, idata, qdata, addr):
        """Load pulse data into signal generators
        :param ch: Channel
        :type ch: int
        :param idata: data for ichannel
        :type idata: ndarray(dtype=int16)
        :param qdata: data for qchannel
        :type qdata: ndarray(dtype=int16)
        :param addr: address to start data at
        :type addr: int
        """
        return self.gens[ch-1].load(xin_i=idata, xin_q=qdata, addr=addr)                 

    def set_nyquist(self, ch, nqz):
        """
        Sets DAC channel ch to operate in Nyquist zone nqz mode.
        Channels are indexed as they are on the tProc outputs: in other words, the first DAC channel is channel 1.
        (tProc output 0 is reserved for readout triggers and PMOD outputs)

        Channel 1 : connected to Signal Generator V4, which drives DAC 228 CH0.
        Channel 2 : connected to Signal Generator V4, which drives DAC 228 CH1.
        Channel 3 : connected to Signal Generator V4, which drives DAC 228 CH2.
        Channel 4 : connected to Signal Generator V4, which drives DAC 229 CH0.
        Channel 5 : connected to Signal Generator V4, which drives DAC 229 CH1.
        Channel 6 : connected to Signal Generator V4, which drives DAC 229 CH2.
        Channel 7 : connected to Signal Generator V4, which drives DAC 229 CH3.
        tiles: DAC 228: 0, DAC 229: 1
        channels: CH0: 0, CH1: 1, CH2: 2, CH3: 3

        :param ch: DAC channel
        :type ch: int
        :param nqz: Nyquist zone
        :type nqz: int
        :return: 'True' or '1' if the task was completed successfully
        :rtype: bool
        """
        #ch_info={1: (0,0), 2: (0,1), 3: (0,2), 4: (1,0), 5: (1,1), 6: (1, 2), 7: (1,3)}
    
        tile, channel = [int(a) for a in self['gens'][ch-1]['dac']]
        dac_block=self.rf.dac_tiles[tile].blocks[channel]
        dac_block.NyquistZone=nqz
        return dac_block.NyquistZone

