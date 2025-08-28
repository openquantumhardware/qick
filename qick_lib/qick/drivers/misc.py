from pynq.buffer import allocate
import numpy as np
from qick import SocIp
import time


class AxisBufferUram(SocIp):
    """
     AXIS_buffer URAM registers.
     RW_REG
     * 0 : read operation.
     * 1 : write operation.
    
     START_REG
     * 0 : stop.
     * 1 : start operation.
    
     SYNC_REG
     * 0 : don't sync with Tlast.
     * 1 : sync capture with Tlast.
    
     The block will either capture or send data out based on RW_REG operation.
     Read/write operations will use the entire buffer. Tlast is created at the
     end of the read to ensure DMA does not hang. Both s_axis_tdata and tuser
     are captured. Output is always 64 bits, with the lower B bits being the
     data and the upper 16 tuser. Un-used bits should be zero.
    
     With SYNC_REG, the user can control to start the capture after a Tlast
     has been received at the input interface. Previous samples are discarded,
     included the one with the Tlast flag, and the capture starts right after
     that sample. If SYNC_REG is set to 0, the block will start capturing data
     without waiting for Tlast to happen.

    """
    bindto = ['user.org:user:axis_buffer_uram_v1:1.0']
    def __init__(self, description):
        # Initialize ip
        super().__init__(description)

        self.REGISTERS = {   'rw_reg'    : 0, 
                    'start_reg' : 1, 
                    'sync_reg'  : 2}
    
        # Generics.
        self.BDATA = int(description['parameters']['BDATA'])
        self.BUSER = int(description['parameters']['BUSER'])
        self.BOUT = int(description['parameters']['BOUT'])
        self.N = int(description['parameters']['N'])
        self.BUFFER_LENGTH = 2*(1 << self.N)

        # Default registers.
        # Write operation, stopped, don't sync with Tlast.
        self.rw_reg = 1
        self.start_reg = 0
        self.sync_reg = 0
    
    def configure(self, dma, sync = "no"):
        self.dma = dma

        if sync == "no":
            self.sync_reg = 0
        elif sync == "yes":
            self.sync_reg = 1

    def capture(self):
        # Enable write operation.
        self.rw_reg = 1
        self.start_reg = 1
        
        # Wait for capture
        time.sleep(0.1)
        
        # Stop capture
        self.start_reg = 0
        
    def transfer_raw(self):
        # Enable read operation.
        self.rw_reg = 0        
        
        # Define buffer:         
        buff = allocate(shape=(self.BUFFER_LENGTH,), dtype=np.uint64)

        # Start transfer.
        self.start_reg = 1

        # DMA data.
        self.dma.recvchannel.transfer(buff)
        self.dma.recvchannel.wait()

        # Stop transfer.
        self.start_reg = 0
        
        return buff
        
    def transfer(self):
        # Enable read operation.
        self.rw_reg = 0        
        
        # Define buffer:         
        buff = allocate(shape=(self.BUFFER_LENGTH,), dtype=np.uint64)

        # Start transfer.
        self.start_reg = 1

        # DMA data.
        self.dma.recvchannel.transfer(buff)
        self.dma.recvchannel.wait()

        # Stop transfer.
        self.start_reg = 0
        
        # Format buffer:
        # Even samples, IQ.
        # Lower 32 bits: I
        # Upper 32 bits: Q
        #
        # Odd samples, tuser, 16-bit.
        data = buff[0::2]
        dataI = data & 0xFFFFFFFF
        dataI = dataI.astype(np.int32)
        dataQ = (data >> 32)
        dataQ = dataQ.astype(np.int32)
        
        data = buff[1::2]
        index = data & 0xFFFF
        index = index.astype(np.uint16)
    
        return dataI,dataQ,index        
    
    def get_data(self):
        # Capture data.
        self.capture()
        
        # Transfer data.
        return self.transfer()

class AxisAccumulatorV6(SocIp):
    bindto = ['user.org:user:axis_accumulator_v1:1.0']

    def __init__(self, description):
        # Initialize ip
        super().__init__(description)
        
        self.REGISTERS = {   'process_reg'           :0, 
                    'tx_and_cnt_reg'        :1, 
                    'tx_and_rst_reg'        :2, 
                    'usr_round_samples_reg' :3, 
                    'usr_epoch_rounds_reg'  :4, 
                    'debug_reg'             :12, 
                    'round_cnt_reg'         :13, 
                    'epoch_cnt_reg'         :14, 
                    'transmitting_reg'      :15}
        
        # Default registers.
        self.process_reg            = 0
        self.tx_and_cnt_reg         = 0
        self.tx_and_rst_reg         = 0
        self.usr_round_samples_reg  = 100
        self.usr_epoch_rounds_reg   = 1
        
        # Generics
        self.AXIS_IN_DW     = int(description['parameters']['AXIS_IN_DW'])
        self.AXIS_OUT_DW    = int(description['parameters']['AXIS_OUT_DW'])
        self.FFT_AW         = int(description['parameters']['FFT_AW'])
        self.BANK_ARRAY_AW  = int(description['parameters']['BANK_ARRAY_AW'])
        self.MEM_DW         = int(description['parameters']['MEM_DW'])
        self.MEM_PIPE       = int(description['parameters']['MEM_PIPE'])
        self.FFT_STORE      = int(description['parameters']['FFT_STORE'])
        self.IQ_FORMAT      = int(description['parameters']['IQ_FORMAT'])

        # Check Parameters.
        if (self.AXIS_IN_DW != 64):
            raise ValueError('Data Width=%d not supported. Must be 64-bit'%self.AXIS_IN_DW)

#        if (self.FFT_AW != 14):
#            raise ValueError('FFT length=%d not supported. Must be 16384'%2**(self.FFT_AW))

        if (self.BANK_ARRAY_AW != 4):
            raise ValueError('Number of parallel input=%d not supported. Must be 16'%2**(self.BANK_ARRAY_AW))

        if (self.FFT_STORE != 1):
            raise ValueError('FFT_STORE must be set to half (1)')
            
        if (self.IQ_FORMAT != 1):
            raise ValueError('IQ_FORMAT must be set QIQIQIQI (1)')            

        # Buffer length:
        # * Half the FFT Bins x Number of inputs.
        # * One more for metadata.
        # NOTE: each sample is 128 bits.
        self.BUFFER_LENGTH = 2**(self.FFT_AW-1) * 2**self.BANK_ARRAY_AW + 1
        
        # Define buffer:         
        self.buff = allocate(shape=(self.BUFFER_LENGTH,2), dtype=np.int64)

    def configure(self, dma):
        self.dma = dma

    def start(self):
        self.process_reg = 1

    def stop(self):
        self.process_reg = 0

    def single_shot(self,N=1):
        # Set number of averages.
        self.setavg(N)
        
        # Start.
        self.start()
        
        # Wait until average is done.
        while not self.transmitting():
            time.sleep(0.1)
        
        # Stop block.
        self.stop()
        
        # Transfer data.
        return self.transfer()

    def setavg(self, N = 100):
        self.usr_round_samples_reg  = N

    def transmitting(self):
        return self.transmitting_reg

    def transfer(self):
        # DMA data.
        self.dma.recvchannel.transfer(self.buff)
        self.dma.recvchannel.wait()
        
        # Format data:
        # First dimension: Lower 64 bits.
        # Second dimension: Upper 64 bts.
        # Last sample: Meta Data.
        s_low = self.buff[:-1,0]
        s_low = s_low.astype(np.float64)
        s_high = self.buff[:-1,1]
        s_high = s_high.astype(np.float64)
        samples = s_low + (2**64 * s_high).astype(np.float64)
        meta0   = self.buff[-1,0]
        meta1   = self.buff[-1,1]
        nsamp = meta0 >> np.int64(32)

        return samples/nsamp




class AxisChSelPfbx1(SocIp):
    """
     AXIS Channel Selection PFB Registers
     CHID_REG

    """
    bindto = ['user.org:user:axis_chsel_pfb_x1:1.0']
    
    def __init__(self, description):
        # Initialize ip
        super().__init__(description)

        self.REGISTERS = {'chid_reg' : 0}

        self.B      = int(description['parameters']['B'])
        self.N      = int(description['parameters']['N'])

        # Default registers.
        self.set()

    def set(self,ch=0):
        if ch<self.N:
            # Change channel
            self.chid_reg = ch         

class AxisReorderIQ(SocIp):
    """
     Data format for PFB input.

    """
    bindto = ['QICK:QICK:axis_reorder_iq_v1:1.0']
    
    def __init__(self, description):
        # Initialize ip
        super().__init__(description)

        self.B      = int(description['parameters']['B'])
        self.L      = int(description['parameters']['L'])

class AxisBuffer(SocIp):
    # AXIS_buffer registers.
    # DW_CAPTURE_REG
    # * 0 : disable capture.
    # * 1 : enable capture.
    #
    # DR_START_REG
    # * 0 : start reader.
    # * 1 : stop reader.
    bindto = ['user.org:user:axis_buffer_v1:1.0']
    
    def __init__(self, description):
        # Initialize ip
        super().__init__(description)
        
        self.REGISTERS = {'dw_capture' : 0, 'dr_start' : 1}

        # Default registers.
        self.dw_capture = 0
        self.dr_start = 0
        
        # Generics.
        self.B = int(description['parameters']['B'])
        self.N = int(description['parameters']['N'])
        self.BUFFER_LENGTH = (1 << self.N)
        
    def configure(self,dma):
        self.dma = dma
    
    def capture(self):
        # Enable capture
        self.dw_capture = 1
        
        # Wait for capture
        time.sleep(0.1)
        
        # Stop capture
        self.dw_capture = 0
        
    def transfer(self):
        self.dr_start = 0
        
        buff = allocate(shape=(self.BUFFER_LENGTH,), dtype=np.uint32)

        # Start transfer.
        self.dr_start = 1

        # DMA data.
        self.dma.recvchannel.transfer(buff)
        self.dma.recvchannel.wait()

        # Stop transfer.
        self.dr_start = 0
        
        # Return data
        # Format:
        # -> lower 16 bits: I value.
        # -> higher 16 bits: Q value.
        data = buff
        dataI = data & 0xFFFF
        dataI = dataI.astype(np.int16)
        dataQ = data >> 16
        dataQ = dataQ.astype(np.int16)

        return dataI,dataQ
    
    def get_data(self):
        # Capture data.
        self.capture()
        
        # Transfer data.
        return self.transfer()    


