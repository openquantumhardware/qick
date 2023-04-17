"""
Drivers for the QICK timed processor (tProc).
"""
from pynq.buffer import allocate
import numpy as np
from qick import SocIp

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

            Parameters
            ----------
            mem_sel : int
                PMEM=1, DMEM=2, WMEM=3
            buff_in : array
                Data to be loaded
            addr : int
                Starting write address
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

            Parameters
            ----------
            mem_sel : int
                PMEM=1, DMEM=2, WMEM=3
            addr : int
                Starting read address
            length : int
                Number of words to read
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
