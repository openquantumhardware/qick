import os
import pynq
from pynq import Overlay, allocate
import xrfclk
import xrfdc
import numpy as np
import scipy as sp
import scipy.signal
import fractions as frac
from pynq import Xlnk
from pynq import Overlay
from pynq.lib import AxiGPIO
import matplotlib.pyplot as plt
import time
import scipy.io as sio

from parser import *

# Support functions.
def gauss(mu=0,si=0,length=100,maxv=30000):
    x = np.arange(0,length)
    y = 1/(2*np.pi*si**2)*np.exp(-(x-mu)**2/si**2)
    y = y/np.max(y)*maxv
    return y

def triang(length=100,maxv=30000):
    y1 = np.arange(0,length/2)
    y2 = np.flip(y1,0)
    y = np.concatenate((y1,y2))
    y = y/np.max(y)*maxv
    return y

def freq2reg(fs,f,B=16):
    df = 2**B/fs
    f_i = f*df
    return int(f_i)

# Some support functions
def format_buffer(buff):
    # Format: 
    # -> lower 16 bits: I value.
    # -> higher 16 bits: Q value.
    data = buff
    dataI = data & 0xFFFF
    dataI = dataI.astype(np.int16)
    dataQ = data >> 16
    dataQ = dataQ.astype(np.int16)
    
    return dataI,dataQ

class SocIp:
    REGISTERS = {}    
    
    def __init__(self, ip, **kwargs):
        self.ip = ip
        
    def write(self, offset, s):
        self.ip.write(offset, s)
        
    def read(self, offset):
        return self.ip.read(offset)
    
    def __setattr__(self, a ,v):
        if a in self.__class__.REGISTERS:
            self.ip.write(4*self.__class__.REGISTERS[a], v)
        else:
            return super().__setattr__(a,v)
    
    def __getattr__(self, a):
        if a in self.__class__.REGISTERS:
            return self.ip.read(4*self.__class__.REGISTERS[a])
        else:
            return super().__getattr__(a)           
        
class AxisSignalGenV4(SocIp):
    # AXIS Signal Generator V4 Registers.
    # START_ADDR_REG
    #
    # WE_REG
    # * 0 : disable writes.
    # * 1 : enable writes.
    #
    REGISTERS = {'start_addr_reg':0, 'we_reg':1, 'rndq_reg':2}
    
    # Generics
    N = 12
    NDDS = 16
    
    # Maximum number of samples
    MAX_LENGTH = 2**N*NDDS
    
    def __init__(self, ip, axi_dma, axis_switch, channel, **kwargs):
        # Init IP.
        super().__init__(ip)
        
        # Default registers.
        self.start_addr_reg=0
        self.we_reg=0
        self.rndq_reg = 10
        
        # dma
        self.dma = axi_dma
        
        # Switch
        self.switch = axis_switch
        
        # Channel.
        self.ch = channel        
        
    # Load waveforms.
    def load(self, xin_i, xin_q ,addr=0):
        # Check for equal length.
        if len(xin_i) != len(xin_q):
            print("%s: I/Q buffers must be the same length." % self.__class__.__name__)
            return
        
        # Check for max length.
        if len(xin_i) > self.MAX_LENGTH:
            print("%s: buffer length must be %d samples or less." % (self.__class__.__name__,self.MAX_LENGTH))
            return
        
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
        self.start_addr_reg = addr
        self.we_reg = 1
        
    def wr_disable(self):
        self.we_reg = 0
        
    def rndq(self, sel_):
        self.rndq_reg = sel_
                
class AxisReadoutV1(SocIp):
    # Registers.
    # OUTSEL_REG
    # * 0 : Product of Input Data and DDS.
    # * 1 : DDS.
    # * 2 : Input Data.
    #
    # DDS_FREQ_REG : to set the frequency of the down-conversion.
    #
    REGISTERS = {'outsel_reg':0, 'dds_freq_reg':1}
    
    # Bits of DDS.
    B_DDS = 16
    
    def __init__(self, ip, fs, **kwargs):
        # Init IP.
        super().__init__(ip)
        
        # Default registers.
        self.outsel_reg=0
        self.dds_freq_reg=0
        
        # Sampling frequency.
        self.fs = fs
        
    def set_out(self,sel="product"):        
        if sel is "product":
            self.outsel_reg = 0
        elif sel is "dds":
            self.outsel_reg = 1
        elif sel is "input":
            self.outsel_reg = 2
        else:
            print("AxisReadoutV1: %s output unknown" % sel)
            
    def set_freq(self, f):
        # Sanity check.
        if f<self.fs:
            df = self.fs/2**self.B_DDS
            k_i = int(np.round(f/df))
            self.dds_freq_reg = k_i
            #print (k_i)
        
class AxisAvgBuffer(SocIp):
    # Registers.
    # AVG_START_REG
    # * 0 : Averager Disabled.
    # * 1 : Averager Enabled (started by external trigger).
    #
    # AVG_ADDR_REG : start address to write results.
    #
    # AVG_LEN_REG : number of samples to be added.
    #
    # AVG_DR_START_REG
    # * 0 : do not send any data.
    # * 1 : send data using m0_axis.
    #
    # AVG_DR_ADDR_REG : start address to read data.
    #
    # AVG_DR_LEN_REG : number of samples to be read.
    #
    # BUF_START_REG
    # * 0 : Buffer Disabled.
    # * 1 : Buffer Enabled (started by external trigger).
    #
    # BUF_ADDR_REG : start address to write results.
    #
    # BUF_LEN_REG : number of samples to be buffered.
    #
    # BUF_DR_START_REG
    # * 0 : do not send any data.
    # * 1 : send data using m1_axis.
    #
    # BUF_DR_ADDR_REG : start address to read data.
    #
    # BUF_DR_LEN_REG : number of samples to be read.    
    #
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
    
    # Generics
    B = 16
    N_AVG = 14
    N_BUF = 10
        
    # Maximum number of samples
    AVG_MAX_LENGTH = 2**N_AVG  
    BUF_MAX_LENGTH = 2**N_BUF
    
    def __init__(self, ip, axi_dma_avg, switch_avg, axi_dma_buf, switch_buf, channel, **kwargs):
        # Init IP.
        super().__init__(ip)
        
        # Default registers.
        self.avg_start_reg    = 0
        self.avg_dr_start_reg = 0
        self.buf_start_reg    = 0
        self.buf_dr_start_reg = 0        
        
        # DMAs.
        self.dma_avg = axi_dma_avg
        self.dma_buf = axi_dma_buf
        
        # Switches.
        self.switch_avg = switch_avg
        self.switch_buf = switch_buf
        
        # Channel number.
        self.ch = channel

    def config(self,address=0,length=100):
        # Configure averaging and buffering to the same address and length.
        self.config_avg(address=address,length=length)
        self.config_buf(address=address,length=length)
        
    def enable(self):
        # Enable both averager and buffer.
        self.enable_avg()
        self.enable_buf()
        
    def config_avg(self,address=0,length=100):
        # Disable averaging.
        self.disable_avg()
        
        # Set registers.
        self.avg_addr_reg = address
        self.avg_len_reg = length
        
    def transfer_avg(self,buff,address=0,length=100):
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
        self.avg_start_reg = 1
        
    def disable_avg(self):
        self.avg_start_reg = 0    
        
    def config_buf(self,address=0,length=100):
        # Disable buffering.
        self.disable_buf()
        
        # Set registers.
        self.buf_addr_reg = address
        self.buf_len_reg = length    
        
    def transfer_buf(self,buff,address=0,length=100):
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
        self.buf_start_reg = 1
        
    def disable_buf(self):
        self.buf_start_reg = 0         
        
class AxisTProc64x32_x8(SocIp):
    # AXIS tProcessor registers.
    # START_SRC_REG
    # * 0 : internal start.
    # * 1 : external start.
    #
    # START_REG
    # * 0 : stop.
    # * 1 : start.
    #
    # MEM_MODE_REG
    # * 0 : AXIS Read (from memory to m0_axis)
    # * 1 : AXIS Write (from s0_axis to memory)
    #
    # MEM_START_REG
    # * 0 : Stop.
    # * 1 : Execute operation (AXIS)
    #
    # MEM_ADDR_REG : starting memory address for AXIS read/write mode.
    #
    # MEM_LEN_REG : number of samples to be transferred in AXIS read/write mode.
    #
    #
    # DMEM: The internal data memory is 2^DMEM_N samples, 32 bits each.
    # The memory can be accessed either single read/write from AXI interface. The lower 256 Bytes are reserved for registers.
    # The memory is then accessed in the upper section (beyond 256 bytes). Byte to sample conversion needs to be performed.
    # The other method is to DMA in and out. Here the access is direct, so no conversion is needed.
    # There is an arbiter to ensure data coherency and avoid blocking transactions.
    REGISTERS = {'start_src_reg' : 0, 
                 'start_reg' : 1, 
                 'mem_mode_reg' : 2, 
                 'mem_start_reg' : 3, 
                 'mem_addr_reg' : 4, 
                 'mem_len_reg' : 5}
    
    # Generics.
    DMEM_N = 10
    PMEM_N = 16
    
    # Reserved lower memory section for register access.
    DMEM_OFFSET = 256 
    
    def __init__(self, ip, mem, axi_dma):
        # Initialize ip
        super().__init__(ip)
        
        # Program memory.
        self.mem = mem
        
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
        
        # dma
        self.dma = axi_dma 
        
    def start_src(self,src=0):
        self.start_src_reg = src
        
    def start(self):
        self.start_reg = 1
        
    def stop(self):
        self.start_reg = 0
        
    def load_asm_program(self, prog, debug= False):
        """
        prog -- the ASM_program to load 
        """
        for ii,inst in enumerate(prog.compile(debug=debug)):
            dec_low = inst & 0xffffffff
            dec_high = inst >> 32
            self.mem.write(offset=8*ii,value=dec_low)
            self.mem.write(offset=4*(2*ii+1),value=dec_high)

    def load_program(self,prog="prog.asm",fmt="asm"):
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
                self.mem.write(offset=addr,value=dec_low)
                addr = addr + 4
                self.mem.write(offset=addr,value=dec_high)
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
                self.mem.write(offset=addr,value=dec_low)
                addr = addr + 4
                self.mem.write(offset=addr,value=dec_high)
                addr = addr + 4   
                
    def single_read(self, addr):
        # Address should be translated to uppder map.
        addr_temp = 4*addr + self.DMEM_OFFSET
            
        # Read data.
        data = self.ip.read(offset=addr_temp)
            
        return data
    
    def single_write(self, addr=0, data=0):
        # Address should be translated to uppder map.
        addr_temp = 4*addr + self.DMEM_OFFSET
            
        # Write data.
        self.ip.write(offset=addr_temp,value=data)
        
    def load_dmem(self, buff_in, addr=0):
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
    REGISTERS = {'ctrl': 0x0, 'mix_mux': 0x040}
    
    # Number of slave interfaces.
    NSL = 1
    
    # Number of master interfaces.
    NMI = 4
    
    def __init__(self, ip, nslave=1, nmaster=4, **kwargs):
        super().__init__(ip)        
        
        # Set number of Slave/Master interfaces.
        self.NSL = nslave
        self.NMI = nmaster
        
        # Init axis_switch.
        self.ctrl = 0
        self.disable_ports()
            
    def disable_ports(self):
        for ii in range(self.NMI):
            offset = self.REGISTERS['mix_mux'] + 4*ii
            self.write(offset,0x80000000)
        
    def sel(self, mst=0, slv=0):
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
        
class PfbSoc(Overlay):
    FREF_PLL = 204.8
    fs_adc = 384*8
    fs_dac = 384*16
    
    # Constructor.
    def __init__(self, bitfile, force_init_clks=False,ignore_version=True, **kwargs):
        # Load bitstream.
        super().__init__(bitfile, ignore_version=ignore_version, **kwargs)
        
        # Configure PLLs if requested.
        if force_init_clks:
            self.set_all_clks()
        else:
            rf=self.usp_rf_data_converter_0
            dac_tile = rf.dac_tiles[1] # DAC 228: 0, DAC 229: 1
            DAC_PLL=dac_tile.PLLLockStatus
            adc_tile = rf.adc_tiles[0] # ADC 224: 0, ADC 225: 1, ADC 226: 2, ADC 227: 3
            ADC_PLL=adc_tile.PLLLockStatus
            
            if not (DAC_PLL==2 and ADC_PLL==2):
                self.set_all_clks()
                
        # AXIS Switch to upload samples into Signal Generators.
        self.switch_gen = AxisSwitch(self.axis_switch_gen, nslave=1, nmaster=7)
        
        # AXIS Switch to read samples from averager.
        self.switch_avg = AxisSwitch(self.axis_switch_avg, nslave=2, nmaster=1)
        
        # AXIS Switch to read samples from buffer.
        self.switch_buf = AxisSwitch(self.axis_switch_buf, nslave=2, nmaster=1)
        
        # Signal generators.
        self.gens = []
        self.gens.append(AxisSignalGenV4(self.axis_signal_gen_v4_0, self.axi_dma_gen, self.switch_gen, 0))
        self.gens.append(AxisSignalGenV4(self.axis_signal_gen_v4_1, self.axi_dma_gen, self.switch_gen, 1))
        self.gens.append(AxisSignalGenV4(self.axis_signal_gen_v4_2, self.axi_dma_gen, self.switch_gen, 2))
        self.gens.append(AxisSignalGenV4(self.axis_signal_gen_v4_3, self.axi_dma_gen, self.switch_gen, 3))
        self.gens.append(AxisSignalGenV4(self.axis_signal_gen_v4_4, self.axi_dma_gen, self.switch_gen, 4))
        self.gens.append(AxisSignalGenV4(self.axis_signal_gen_v4_5, self.axi_dma_gen, self.switch_gen, 5))
        self.gens.append(AxisSignalGenV4(self.axis_signal_gen_v4_6, self.axi_dma_gen, self.switch_gen, 6))
        
        # Readout blocks.
        self.readouts = []
        self.readouts.append(AxisReadoutV1(self.axis_readout_v1_0, self.fs_adc))
        self.readouts.append(AxisReadoutV1(self.axis_readout_v1_1, self.fs_adc))
        
        # Average + Buffer blocks.
        self.avg_bufs = []
        self.avg_bufs.append(AxisAvgBuffer(self.axis_avg_buffer_0, 
                                           self.axi_dma_avg, self.switch_avg,
                                           self.axi_dma_buf, self.switch_buf,
                                           0))
        
        self.avg_bufs.append(AxisAvgBuffer(self.axis_avg_buffer_1, 
                                           self.axi_dma_avg, self.switch_avg,
                                           self.axi_dma_buf, self.switch_buf,
                                           1))        
        
        
        # tProcessor, 64-bit instruction, 32-bit registes, x8 channels.
        self.tproc  = AxisTProc64x32_x8(self.axis_tproc64x32_x8_0, self.axi_bram_ctrl_0, self.axi_dma_tproc)
        
    def set_all_clks(self):
        xrfclk.set_all_ref_clks(self.__class__.FREF_PLL)
    
    def get_decimated(self, ch, address=0, length=AxisAvgBuffer.BUF_MAX_LENGTH):
        if length %2 != 0:
            raise RuntimeError("Buffer transfer length must be even number.")
        if length >= AxisAvgBuffer.BUF_MAX_LENGTH:
            raise RuntimeError("length=%d longer or euqal to %d"%(length, AxisAvgBuffer.BUF_MAX_LENGTH))
        buff = allocate(shape=length, dtype=np.int32)
        [di,dq]=self.avg_bufs[ch].transfer_buf(buff,address,length)
        return [np.array(di,dtype=float),np.array(dq,dtype=float)]

    def get_accumulated(self, ch, address=0, length=AxisAvgBuffer.AVG_MAX_LENGTH):
        if length >= AxisAvgBuffer.AVG_MAX_LENGTH:
            raise RuntimeError("length=%d longer than %d"%(length, AxisAvgBuffer.AVG_MAX_LENGTH))
        evenLength = length+length%2
        buff = allocate(shape=evenLength, dtype=np.int64)
        di,dq = self.avg_bufs[ch].transfer_avg(buff,address=address,length=evenLength)

        return di[:length], dq[:length] #[np_buffi,np_buffq]

    
    
    def set_nyquist(self, ch, nqz):
#         Channel 1 : connected to Signal Generator V4, which drives DAC 228 CH0.
#         Channel 2 : connected to Signal Generator V4, which drives DAC 228 CH1.
#         Channel 3 : connected to Signal Generator V4, which drives DAC 228 CH2.
#         Channel 4 : connected to Signal Generator V4, which drives DAC 229 CH0.
#         Channel 5 : connected to Signal Generator V4, which drives DAC 229 CH1.
#         Channel 6 : connected to Signal Generator V4, which drives DAC 229 CH2.
#         Channel 7 : connected to Signal Generator V4, which drives DAC 229 CH3.
#         tiles: DAC 228: 0, DAC 229: 1
#         channels: CH0: 0, CH1: 1, CH2: 2, CH3: 3
        ch_info={1: (0,0), 2: (0,1), 3: (0,2), 4: (1,0), 5: (1,1), 6: (1, 2), 7: (1,3)}
    
        rf=self.usp_rf_data_converter_0
        tile, channel = ch_info[ch]
        dac_block=rf.dac_tiles[tile].blocks[channel]        
        dac_block.NyquistZone=nqz
        return dac_block.NyquistZone