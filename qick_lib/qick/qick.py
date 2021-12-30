"""
The lower-level driver for the QICK library. Contains classes for interfacing with the SoC.
"""
import os
from pynq import Overlay, DefaultIP, allocate
try:
    import xrfclk
    import xrfdc
    from pynq import Xlnk
except:
    pass
import numpy as np
from pynq import Overlay
from pynq.lib import AxiGPIO
import time
from .parser import *
from . import bitfile_path

# Some support functions
def format_buffer(buff):
    """
    Return the I and Q values associated with a buffer value. The lower 16 bits correspond to the I value, and the upper 16 bits correspond to the Q value.

    :param buff: Buffer location
    :type buff: int
    :returns:
    - dataI (:py:class:`int`) - I data value
    - dataQ (:py:class:`int`) - Q data value
    """
    data = buff
    dataI = data & 0xFFFF
    dataI = dataI.astype(np.int16)
    dataQ = data >> 16
    dataQ = dataQ.astype(np.int16)
    
    return dataI,dataQ

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
            return super().__getattr__(a)           
        
class AxisSignalGenV4(SocIp):
    """
    AxisSignalGenV4 class

    AXIS Signal Generator V4 Registers.
    START_ADDR_REG

    WE_REG
    * 0 : disable writes.
    * 1 : enable writes.
    """
    bindto = ['user.org:user:axis_signal_gen_v4:1.0']
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

        # Get the channel number from the IP instance name.
        self.ch = int(description['fullpath'].split('_')[-1])
        
    # Configure this driver with links to the other drivers, and the signal gen channel number.
    def configure(self, axi_dma, axis_switch):
        # dma
        self.dma = axi_dma
        
        # Switch
        self.switch = axis_switch
        
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
        self.switch.sel(mst=self.ch)
        
        #time.sleep(0.050)
        
        # Format data.
        xin_i = xin_i.astype(np.int16)
        xin_q = xin_q.astype(np.int16)
        xin = np.zeros(len(xin_i))
        for i in range(len(xin)):
            xin[i] = xin_i[i] + (xin_q[i] << 16)
            
        xin = xin.astype(np.int32)
        
        # Define buffer.
        self.buff = Xlnk().cma_array(shape=(len(xin)), dtype=np.int32)
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
        
    def rndq(self, sel_):
        """
           TODO: remove this function. This functionality was removed from IP block.
        """
        self.rndq_reg = sel_
                
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
        
        # Get the channel number from the IP instance name.
        self.ch = int(description['fullpath'].split('_')[-1])

    # Configure this driver with the sampling frequency.
    def configure(self, fs):
        # Sampling frequency.
        self.fs = fs
        
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
#         if sel is "product":
#             self.outsel_reg = 0
#         elif sel is "dds":
#             self.outsel_reg = 1
#         elif sel is "input":
#             self.outsel_reg = 2
#         else:
#             print("AxisReadoutV2: %s output unknown" % sel)
            
        # Register update.
        self.update()
            
    def set_freq(self, f):
        """
        Set frequency register

        :param f: frequency in MHz
        :type f: float
        """
        # Sanity check.
        if f<self.fs:
            df = self.fs/2**self.B_DDS
            k_i = int(np.round(f/df))
            self.freq_reg = k_i
            
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

        # Get the channel number from the IP instance name.
        self.ch = int(description['fullpath'].split('_')[-1])

    # Configure this driver with links to the other drivers.
    def configure(self, axi_dma_avg, switch_avg, axi_dma_buf, switch_buf):
        # DMAs.
        self.dma_avg = axi_dma_avg
        self.dma_buf = axi_dma_buf
        
        # Switches.
        self.switch_avg = switch_avg
        self.switch_buf = switch_buf
        

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
        
    def transfer_avg(self,buff,address=0,length=100):
        """
        Transfer average buffer data from average and buffering readout block.

        :param buff: DMA buffer to be used for transfer
        :type buff: list
        :param addr: starting reading address
        :type addr: int
        :param length: number of samples
        :type length: int
        :return: I,Q pairs
        :rtype: list
        """
        # Route switch to channel.
        self.switch_avg.sel(slv=self.ch)        
        
        # Set averager data reader address and length.
        self.avg_dr_addr_reg = address
        self.avg_dr_len_reg = length
        
        # Start send data mode.
        self.avg_dr_start_reg = 1
        
        # DMA data.
        self.dma_avg.recvchannel.transfer(buff)
        self.dma_avg.recvchannel.wait()

        if self.dma_avg.recvchannel.transferred != length*8:
            raise RuntimeError("Requested %d samples but only got %d from DMA" % (length, self.dma_avg.recvchannel.transferred//8))

        # Stop send data mode.
        self.avg_dr_start_reg = 0
        
        # Format: 
        # -> lower 32 bits: I value.
        # -> higher 32 bits: Q value.
        data = buff
        dataI = data & 0xFFFFFFFF
        dataI = dataI.astype(np.int32)
        dataQ = data >> 32
        dataQ = dataQ.astype(np.int32)
    
        return dataI,dataQ        
        
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
        
    def transfer_buf(self,buff,address=0,length=100):
        """
        Transfer raw buffer data from average and buffering readout block

        :param buff: DMA buffer to be used for transfer
        :type buff: list
        :param addr: starting reading address
        :type addr: int
        :param length: number of samples
        :type length: int
        :return: I,Q pairs
        :rtype: list
        """
        # Route switch to channel.
        self.switch_buf.sel(slv=self.ch)
        
        #time.sleep(0.050)
        
        # Set buffer data reader address and length.
        self.buf_dr_addr_reg = address
        self.buf_dr_len_reg = length
        
        # Start send data mode.
        self.buf_dr_start_reg = 1
        
        # DMA data.
        self.dma_buf.recvchannel.transfer(buff)
        self.dma_buf.recvchannel.wait()

        if self.dma_buf.recvchannel.transferred != length*4:
            raise RuntimeError("Requested %d samples but only got %d from DMA" % (length, self.dma_buf.recvchannel.transferred//4))

        # Stop send data mode.
        self.buf_dr_start_reg = 0
        
        # Format: 
        # -> lower 16 bits: I value.
        # -> higher 16 bits: Q value.
        data = buff
        dataI = data & 0xFFFF
        dataI = dataI.astype(np.int16)
        dataQ = data >> 16
        dataQ = dataQ.astype(np.int16)
    
        return dataI,dataQ
        
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
            self.mem.write(offset=8*ii,value=int(dec_low))
            self.mem.write(offset=4*(2*ii+1),value=int(dec_high))
        
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
                self.mem.write(offset=addr,value=int(dec_low))
                addr = addr + 4
                self.mem.write(offset=addr,value=int(dec_high))
                addr = addr + 4                
                
        # Asm file.
        elif fmt == "asm":
            # Compile program.
            progList = parse_prog(prog)
        
            # Load Program Memory.
            addr = 0
            for e in progList:
                dec = int(progList[e],2)
                #print ("@" + str(addr) + ": " + str(dec))
                dec_low = dec & 0xffffffff
                dec_high = dec >> 32
                self.mem.write(offset=addr,value=int(dec_low))
                addr = addr + 4
                self.mem.write(offset=addr,value=int(dec_high))
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
        data = self.read(offset=addr_temp)
            
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
        self.write(offset=addr_temp,value=int(data))
        
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
        self.buff = Xlnk().cma_array(shape=(length), dtype=np.int32)
        
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
        buff = Xlnk().cma_array(shape=(length), dtype=np.int32)
        
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
        
class QickSoc(Overlay):
    """
    QickSoc class. This class will create all object to access system blocks

    :param bitfile: Name of the bitfile
    :type bitfile: str
    :param force_init_clks: Whether the board clocks are re-initialized
    :type force_init_clks: bool
    :param ignore_version: Whether version discrepancies between PYNQ build and firmware build are ignored
    :type ignore_version: bool
    """
    FREF_PLL = 204.8 # MHz

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
        # Load bitstream.
        if bitfile==None:
            super().__init__(bitfile_path(), ignore_version=ignore_version, **kwargs)
        else:
            super().__init__(bitfile, ignore_version=ignore_version, **kwargs)

        # RF data converter (for configuring ADCs and DACs)
        self.rf = self.usp_rf_data_converter_0

        # Read the config to get a list of enabled ADCs and DACs, and the sampling frequencies.
        self.list_rf_blocks(self.ip_dict['usp_rf_data_converter_0']['parameters'])

        # Configure PLLs if requested, or if any ADC/DAC is not locked.
        if force_init_clks:
            self.set_all_clks()
        else:
            dac_locked = [self.rf.dac_tiles[iTile].PLLLockStatus==2 for iTile in self.dac_tiles]
            adc_locked = [self.rf.adc_tiles[iTile].PLLLockStatus==2 for iTile in self.adc_tiles]
            if not (all(dac_locked) and all(adc_locked)):
                self.set_all_clks()
                
        # AXIS Switch to upload samples into Signal Generators.
        self.switch_gen = self.axis_switch_gen

        # AXIS Switch to read samples from averager.
        self.switch_avg = self.axis_switch_avg
        
        # AXIS Switch to read samples from buffer.
        self.switch_buf = self.axis_switch_buf
        
        # Signal generators.
        self.gens = []

        # Readout blocks.
        self.readouts = []

        # Average + Buffer blocks.
        self.avg_bufs = []

        # Populate the lists with the registered IP blocks.
        for key,val in self.ip_dict.items():
            if (val['driver'] == AxisSignalGenV4):
                self.gens.append(getattr(self,key))
            elif (val['driver'] == AxisReadoutV2):
                self.readouts.append(getattr(self,key))
            elif (val['driver'] == AxisAvgBuffer):
                self.avg_bufs.append(getattr(self,key))

        # Sanity check: we should have the same number of signal generators as DACs.
        if len(self.dac_blocks) != len(self.gens):
            raise RuntimeError("We have %d DACs but %d signal generators."%(len(self.dac_blocks),len(self.gens)))

        # Sanity check: we should have the same number of readouts and buffer blocks as ADCs.
        if len(self.adc_blocks) != len(self.readouts):
            raise RuntimeError("We have %d ADCs but %d readout blocks."%(len(self.adc_blocks),len(self.readouts)))
        if len(self.adc_blocks) != len(self.avg_bufs):
            raise RuntimeError("We have %d ADCs but %d avg/buffer blocks."%(len(self.adc_blocks),len(self.avg_bufs)))
        
        # Sort the lists by channel number.
        # Typically they are already in order, but good to make sure?
        self.gens.sort(key=lambda x: x.ch)
        self.readouts.sort(key=lambda x: x.ch)
        self.avg_bufs.sort(key=lambda x: x.ch)

        # Configure the drivers.
        for gen in self.gens:
            gen.configure(self.axi_dma_gen, self.switch_gen)

        for readout in self.readouts:
            readout.configure(self.fs_adc)

        for buf in self.avg_bufs:
            buf.configure(self.axi_dma_avg, self.switch_avg,
                    self.axi_dma_buf, self.switch_buf)


        # tProcessor, 64-bit instruction, 32-bit registes, x8 channels.
        self.tproc  = self.axis_tproc64x32_x8_0
        self.tproc.configure(self.axi_bram_ctrl_0, self.axi_dma_tproc)

    def __repr__(self):
        lines=[]
        lines.append("\n\tGenerator switch: %d to %d"%(
            self.switch_gen.NSL, self.switch_gen.NMI))
        lines.append("\n\tAverager switch: %d to %d"%(
            self.switch_avg.NSL, self.switch_avg.NMI))
        lines.append("\n\tBuffer switch: %d to %d"%(
            self.switch_buf.NSL, self.switch_buf.NMI))

        lines.append("\n\t%d DAC channels:"%(len(self.dac_blocks)))
        for iCh, (iTile,iBlock) in enumerate(self.dac_blocks):
            lines.append("\t%d:\ttile %d, channel %d, fs=%.3f GHz"%(iCh,iTile,iBlock,
                self.rf.dac_tiles[iTile].blocks[iBlock].BlockStatus['SamplingFreq']))

        lines.append("\n\t%d ADC channels:"%(len(self.adc_blocks)))
        for iCh, (iTile,iBlock) in enumerate(self.adc_blocks):
            lines.append("\t%d:\ttile %d, channel %d, fs=%.3f GHz"%(iCh,iTile,iBlock,
                self.rf.adc_tiles[iTile].blocks[iBlock].BlockStatus['SamplingFreq']))

        lines.append("\n\t%d signal generators: max length %d samples"%(len(self.gens),
            self.gens[0].MAX_LENGTH))

        lines.append("\n\t%d readout blocks"%(len(self.readouts)))

        lines.append("\n\t%d average+buffer blocks: max length %d samples (averages), %d (decimated buffer)"%(len(self.avg_bufs),
            self.avg_bufs[0].AVG_MAX_LENGTH, 
            self.avg_bufs[0].BUF_MAX_LENGTH))

        lines.append("\n\ttProc: %d words program memory, %d words data memory"%(2**self.tproc.PMEM_N, 2**self.tproc.DMEM_N))

        return "\nQICK configuration:\n"+"\n".join(lines)

    def list_rf_blocks(self, rf_config):
        """
        Lists the enabled ADCs and DACs and get the sampling frequencies.
        XRFdc_CheckBlockEnabled in xrfdc_ap.c is not accessible from the Python interface to the XRFdc driver.
        This re-implements that functionality.
        """

        hs_adc = rf_config['C_High_Speed_ADC']=='1'

        self.dac_tiles = []
        self.dac_blocks = []
        self.adc_tiles = []
        self.adc_blocks = []

        for iTile,tile in enumerate(self.rf.dac_tiles):
            if rf_config['C_DAC%d_Enable'%(iTile)]!='1':
                continue
            self.dac_tiles.append(iTile)
            for iBlock,block in enumerate(tile.blocks):
                if rf_config['C_DAC_Slice%d%d_Enable'%(iTile,iBlock)]!='true':
                    continue
                self.dac_blocks.append((iTile,iBlock))

        for iTile,tile in enumerate(self.rf.adc_tiles):
            if rf_config['C_ADC%d_Enable'%(iTile)]!='1':
                continue
            self.adc_tiles.append(iTile)
            for iBlock,block in enumerate(tile.blocks):
                if hs_adc:
                    if iBlock>=2 or rf_config['C_ADC_Slice%d%d_Enable'%(iTile,2*iBlock)]!='true':
                        continue
                else:
                    if rf_config['C_ADC_Slice%d%d_Enable'%(iTile,iBlock)]!='true':
                        continue
                self.adc_blocks.append((iTile,iBlock))

        # Assume all DACs and ADCs each share a common sampling frequency, so we only need to check the first one.
        # We assume the sampling frequencies are integers in MHz.
        iTile,iBlock = self.dac_blocks[0]
        self.fs_dac = int(self.rf.dac_tiles[iTile].blocks[iBlock].BlockStatus['SamplingFreq']*1000)
        iTile,iBlock = self.adc_blocks[0]
        self.fs_adc = int(self.rf.adc_tiles[iTile].blocks[iBlock].BlockStatus['SamplingFreq']*1000)

    def set_all_clks(self):
        """
        Resets all the board clocks
        """
        print("resetting clocks:",self.__class__.FREF_PLL)
        xrfclk.set_all_ref_clks(self.__class__.FREF_PLL)
    
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
        if length %2 != 0:
            raise RuntimeError("Buffer transfer length must be even number.")
        if length >= self.avg_bufs[ch].BUF_MAX_LENGTH:
            raise RuntimeError("length=%d longer or equal to %d"%(length, self.avg_bufs[ch].BUF_MAX_LENGTH))
        buff = allocate(shape=length, dtype=np.int32)
        [di,dq]=self.avg_bufs[ch].transfer_buf(buff,address,length)
        return [np.array(di,dtype=float),np.array(dq,dtype=float)]

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
        if length %2 != 0:
            raise RuntimeError("Buffer transfer length must be even number.")
        if length >= self.avg_bufs[ch].AVG_MAX_LENGTH:
            raise RuntimeError("length=%d longer than %d"%(length, self.avg_bufs[ch].AVG_MAX_LENGTH))
        buff = allocate(shape=length, dtype=np.int64)
        di,dq = self.avg_bufs[ch].transfer_avg(buff,address=address,length=length)

        return di, dq #[np_buffi,np_buffq]

    def start(self):
        """Start the tprocessor"""
        return self.tproc.start()

    def stop(self):
        """Stop the tprocessor"""
        return self.tproc.stop()

    def single_read(self, addr):
        """Read single value from data memory
        
        :param addr: Address of data memory to read
        :type addr: int
        :return: value at data address 'addr' 
        :rtype: int

        """
        return self.tproc.single_read(addr)

    def single_write(self, addr,data):
        """Read single value from data memory
        
        :param addr: Address of data memory to read
        :type addr: int
        :param data: data to write into memory
        :type data: int
        """
        return self.tproc.single_write(addr,data)

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
        return self.tproc.read_dmem(addr,length)

    def load_dmem(self, buff_in, addr=0):
        """
        Writes tProc data memory using DMA

        :param buff_in: Input buffer
        :type buff_in: int
        :param addr: Starting destination address
        :type addr: int
        """
        return self.tproc.load_dmem(buff_in, addr)

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
        
    def load_bin_program(self, binprog):
        return self.tproc.load_bin_program(binprog)

    def get_avg_max_length(self, ch=0):
        """Get accumulation buffer length for channel
        :param ch: Channel
        :type ch: int
        :return: Length of accumulation buffer for channel 'ch'
        :rtype: int
        """
        return self.avg_bufs[ch].AVG_MAX_LENGTH
    
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
    
        tile, channel = self.dac_blocks[ch-1]
        dac_block=self.rf.dac_tiles[tile].blocks[channel]
        dac_block.NyquistZone=nqz
        return dac_block.NyquistZone

