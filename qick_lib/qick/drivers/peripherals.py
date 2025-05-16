"""
Drivers for qick_processor Peripherals.
2024-5-22
"""
from pynq.buffer import allocate
import numpy as np
from qick import SocIP
import re

class QICK_Time_Tagger(SocIP):
    """
    QICK_Time_Tagger class
    """
    bindto = ['Fermi:user:qick_time_tagger:1.0']

    def __init__(self, description):
        """
        Constructor method
        """
        super().__init__(description)
        
        # list of connected ADCs
        self.cfg['adcs'] = []

        # DMA block
        self.dma = None

        # DMA buffer
        self.buff_rd = None

    def _init_config(self, description):
        self.REGISTERS = {
            'qtt_ctrl'     :0 ,
            'qtt_cfg'      :1 ,
            'dma_cfg'      :2 ,
            'axi_dt1'      :3 ,
            'proc_dt'      :5 ,
            'proc_qty'     :6,
            'tag0_qty'     :7,
            'tag1_qty'     :8,
            'tag2_qty'     :9,
            'tag3_qty'     :10,
            'smp_qty'      :11,
            'arm_qty'      :12,
            'thr_inh'      :13,
            'qtt_status'   :14,
            'qtt_debug'    :15,
        }
        
        # dict to map from memory names to IDs and counter names
        self.MEMS = {}
        for i in range(4):
            self.MEMS['TAG%d'%(i)] = (i, 'tag%d_qty'%(i))
        self.MEMS['ARM'] = (4, 'arm_qty')
        self.MEMS['SMP'] = (5, 'smp_qty')

        # state names
        self.DMA_STATES = ['ST_IDLE','ST_TX','ST_LAST','ST_END']

        # Parameters
        self.cfg['tag_mem_size'] = 2**int(description['parameters']['TAG_FIFO_AW'])
        self.cfg['arm_mem_size'] = 2**int(description['parameters']['ARM_FIFO_AW'])
        self.cfg['smp_mem_size'] = 2**int(description['parameters']['SMP_FIFO_AW'])
        
        for param in ['adc_qty','cmp_inter','arm_store','smp_store','cmp_slope']:
            self.cfg[param] = int(description['parameters'][param.upper()])
        self.cfg['debug']  = int(description['parameters']['DEBUG'])

    def _init_firmware(self):
        # Initial Values 
        self.qtt_ctrl = 0
        self.qtt_cfg  = 0
        self.dma_cfg  = 0 + 16* 1
        self.axi_dt1  = 0

    # Configure this driver with links to its memory and DMA.
    def configure_connections(self, soc):
        self.cfg['f_fabric'] = soc.metadata.get_fclk(self['fullpath'], 'adc_clk')

        ((block, port),) = soc.metadata.trace_bus(self['fullpath'], "m_axis_dma")
        self.dma = soc._get_block(block)

        dma_maxlen = 2**int(self.dma.description["parameters"]["c_sg_length_width"])//4 - 1
        buflen = max(self['tag_mem_size'], self['arm_mem_size'], self['smp_mem_size'])
        buflen = min(buflen, dma_maxlen)
        self.buff_rd = allocate(shape=buflen, dtype=np.int32)

        for iADC in range(4):
            try:
                block, port, _ = soc.metadata.trace_back(self['fullpath'], "s%d_axis_adc%d"%(iADC, iADC), ["usp_rf_data_converter"])
                # port names are of the form 'm02_axis' where the block number is always even
                adc = port[1:3]
                self.cfg['adcs'].append([adc, soc._describe_adc(adc)])
            except: # skip disconnected ADC Ports
                self.cfg['adcs'].append([None, "not connected"])
                
    def __str__(self):
        lines = []
        lines.append('---------------------------------------------')
        lines.append(' QICK Time Tagger INFO ')
        lines.append('---------------------------------------------')
        lines.append("Connections:")
        for i, (_, adcdesc) in enumerate(self['adcs']):
            lines.append(" ADC%d : %s" % (i, adcdesc) )
        lines.append("Configuration:")
        for param in ['adc_qty','tag_mem_size', 'cmp_slope','cmp_inter','arm_store','arm_mem_size', 'smp_store','smp_mem_size']:
            lines.append(" %-14s: %d" % (param, self.cfg[param]) )
        lines.append("----------\n")
        return "\n".join(lines)
    
    def read_mem(self, mem_sel:str, length=None):
        """
        Read selected time-tagger memory using DMA.

        Parameters
        ----------
        mem_sel : str
            TAG0, TAG1, TAG2, TAG3, ARM, SMP
        length : int
            Number of values to read.
            If None, read as many as possible (all the values, or the DMA max.
        """
        if mem_sel not in self.MEMS:
            raise RuntimeError('Source Memory error. Options are TAG0, TAG1, TAG2, TAG3, ARM, SMP current Value : %s' % (mem_sel))
        mem_id, mem_counter = self.MEMS[mem_sel]

        # Configure FIFO Read.
        if length is None:
            length = min(getattr(self, mem_counter), len(self.buff_rd))
        self.dma_cfg = mem_id + 16*length
       
        if length==0:
            print('No Data to read in ', mem_sel)
            return np.array([])
        else:
            #Start DMA Transfer
            self.qtt_ctrl     = 32
            # DMA data.
            self.dma.recvchannel.transfer(self.buff_rd, nbytes=int(length*4))
            self.dma.recvchannel.wait()
            # truncate, copy, convert PynqBuffer to ndarray
            return np.array(self.buff_rd[:length], copy=True)
    
    def flush_mems(self, verbose=False):
        """Flush the time-tagger memories by reading them.
        This does not clear the tag queue to the tProc, only the memories readable by DMA.
        """
        for memname, (_, countname) in self.MEMS.items():
            while True:
                to_read = getattr(self, countname)
                if verbose: print(memname, to_read)
                if to_read == 0: break
                self.read_mem(memname)

    def set_config(self, filt, slope, interp, wr_smp, invert):
        """
        QICK_Time_Tagger Configuration
        filt   : Filter ADC Inputs  > 0:No , 1:Yes
        slope  : Compare with Slope > 0:No , 1:Yes
        inter  : Number of bits for Interpolation (0 to 7)
        wr_smp : Number of group of 8 samples to store (1 to 32)
        invert : Invert Input       > 0:No , 1:Yes
        """
        # Check for Parameters
        if (slope > self.cfg['cmp_slope']):
            raise ValueError('Slope Comparator not implemented')
        if (interp > self.cfg['cmp_inter']):
            raise ValueError('Interpolation bits max Value ',  self.cfg['cmp_inter'])
        if (self.cfg['smp_store'] == 1):
            if wr_smp < 1 or wr_smp > 32:
                raise ValueError('wr_smp must be in range [1, 32]')
            if (wr_smp == 32):
                wr_smp = 0
        self.qtt_cfg = filt + (slope << 1) + (interp << 2) + (wr_smp << 5) + (invert << 10)

    def get_config(self, print_cfg=False):
        cfg = self.qtt_cfg
        filt = cfg & 1
        slope = (cfg >> 1) & 1
        interp = (cfg >> 2) & 0x7
        wr_smp = (cfg >> 5) & 0x1f
        if wr_smp == 0:
            wr_smp = 32
        invert = (cfg >> 10) & 1
        if print_cfg:
            print('--- AXI Time Tagger CONFIG')
            print( ' FILTER           : ' + str(filt))
            print( ' SLOPE            : ' + str(slope))
            print( ' INTERPOLATION    : ' + str(interp))
            print( ' WRITE SAMPLE QTY : ' + str(wr_smp))
            print( ' INVERT INPUT     : ' + str(invert))
        return filt, slope, interp, wr_smp, invert

    def disarm(self):
        self.qtt_ctrl    = 1 + 2*0
    def arm(self):
        self.qtt_ctrl    = 1 + 2*1
    def pop_dt(self):
        self.qtt_ctrl    = 1 + 2*2
    def set_threshold(self, value):
        valid = [-1*2**15, 2**15-1]
        if value < valid[0] or value > valid[1]:
            raise ValueError('Threshold must be in the range %s ADU.'%(valid))
        self.axi_dt1     = value
        self.qtt_ctrl    = 1 + 2*4
    def set_dead_time(self, value):
        valid = [5, 255]
        if value < valid[0] or value > valid[1]:
            raise ValueError('Dead time must be in the range %s clocks.'%(valid))
        self.axi_dt1     = value
        self.qtt_ctrl    = 1 + 2*5
    def reset(self):
        """Flush the time-tagger memories and reset the counters to 0.
        This flushes both the memories read by DMA and those read by the tProc.
        The configuration is not changed.

        This functionality is not reliable in current firmware.
        You should use flush_mems() instead.
        """
        self.qtt_ctrl    = 1 + 2*7

    def info(self):
        print(self)
    def print_axi_regs(self):
        print('---------------------------------------------')
        print('--- AXI Registers')
        for xreg in self.REGISTERS.keys():
            reg_num = getattr(self, xreg)
            reg_bin = '{:039_b}'.format(reg_num)
            print(f'{xreg:>10}', f'{reg_num:>11}'+' - '+f'{reg_bin:>33}' )
    def print_status(self):
        print('---------------------------------------------')
    def print_debug(self):
        print('---------------------------------------------')
        print('--- AXI Time Tagger DEBUG')
        status_num = self.qtt_status
        status_bin = '{:032b}'.format(status_num)
        trig_st      = int(status_bin[24:32], 2) 
        dma_st       = int(status_bin[22:24], 2) 
        print( ' ST_TRIG  : ' + str(trig_st) )
        print( ' ST_DMA   : ' + str(dma_st) )
        debug_num = self.qtt_debug
        debug_bin = '{:032b}'.format(debug_num)
        dma_st  = int(debug_bin[0:1], 2) 
        len_cnt      = int(debug_bin[10:16], 2) 
        frd_cnt      = int(debug_bin[6:10], 2) 
        vld_cnt      = int(debug_bin[2:6], 2) 
        print( ' -- FIFO --' )
        print( ' DMA_FULL   : ' + str(debug_bin[31])  )
        print( ' DMA_EMPTY  : ' + str(debug_bin[30])  )
        print( ' PROC_FULL  : ' + str(debug_bin[29])  )
        print( ' PROC_EMPTY : ' + str(debug_bin[28])  )
        print( ' -- DMA --' )
        print( ' DMA_ST     : ' + str(dma_st) + ' - ' + self.DMA_STATES[dma_st])
        print( ' DMA_REQ    : ' + str(debug_bin[25])  )
        print( ' DMA_ACK    : ' + str(debug_bin[24])  )
        print( ' POP_REQ    : ' + str(debug_bin[23])  )
        print( ' POP_ACK    : ' + str(debug_bin[22])  )
        print( ' FIFO_RD  : ' + str(debug_bin[21])  )
        print( ' DT_TX    : ' + str(debug_bin[20]) )
        print( ' DT_W     : ' + str(debug_bin[19])  )
        print( ' DT_VLD   : ' + str(debug_bin[18]) )
        print( ' DT_BF    : ' + str(debug_bin[17]) )
        print( ' LP_CNT_EN: ' + str(debug_bin[16]) )
        print( ' LEN_CNT    : ' + str(len_cnt) )
        print( ' FIFO_RD_CNT: ' + str(frd_cnt) )
        print( ' VLD_CNT    : ' + str(vld_cnt) )
        th_num = self.thr_inh
        th_bin = '{:032b}'.format(th_num)
        thr          = int(th_bin[16:32], 2) 
        inh          = int(th_bin[8:16], 2) 
        cmd_cnt      = int(th_bin[0:8], 2) 
        print( ' THRESHOLD  : ' + str(thr) )
        print( ' INHIBIT    : ' + str(inh) )
        print( ' CMD_CNT    : ' + str(cmd_cnt) )



class QICK_Com(SocIP):
    """
    QICK_Comm class

    ####################
    QICK COM xREG
    ####################
    QCOM_CTRL        Write / Read 32-Bits
    QCOM_CFG         Write / Read 32-Bits
    AXI_DT1          Write / Read 32-Bits
    QCOM_FLAG        Read Only    32-Bits
    QCOM_DT1         Read Only    32-Bits
    QCOM_DT2         Read Only    32-Bits
    QCOM_STATUS      Read Only    32-Bits
    QCOM_TX_DT       Read Only    32-Bits
    QCOM_RX_DT       Read Only    32-Bits
    QCOM_DEBUG       Read Only    32-Bits
    """
    bindto = ['Fermi:user:qick_com:1.0']

    def _init_config(self, description):
        self.REGISTERS = {
            'qcom_ctrl'     :0 ,
            'qcom_cfg'      :1 ,
            'axi_dt1'       :2 ,
            'flag'     :7 ,
            'dt1'      :8 ,
            'dt2'      :9,
            'status'   :12,
            'tx_dt'    :13,
            'rx_dt'    :14,
            'debug'    :15
        }    

    def _init_firmware(self):
    # Initial Values 
        self.qcom_ctrl = 0
        self.qcom_cfg  = 10
        self.raxi_dt1  = 0

    def __str__(self):
        lines = []
        lines.append('---------------------------------------------')
        lines.append(' QICK Com INFO ')
        lines.append('---------------------------------------------')
        lines.append("----------\n")
        return "\n".join(lines)

    def clr_flg(self):
        self.qcom_ctrl = 1
    def send_byte(self, data, dst):
        self.axi_dt1 = data
        if   (dst == 1):
            self.qcom_ctrl = 1+2*2
        elif (dst == 2):
            self.qcom_ctrl = 1+2*3
        else:
            raise RuntimeError('Destination Register error should be 1 or 2 current Value : %d' % (dst))
    def send_half_word(self, data, dst):
        self.axi_dt1 = data
        if   (dst == 1):
            self.qcom_ctrl = 1+2*4
        elif (dst == 2):
            self.qcom_ctrl = 1+2*5
        else:
            raise RuntimeError('Destination Register error should be 1 or 2 current Value : %d' % (dst))
    def send_word(self, data, dst):
        self.axi_dt1 = data
        if   (dst == 1):
            self.qcom_ctrl = 1+2*6
        elif (dst == 2):
            self.qcom_ctrl = 1+2*7
        else:
            raise RuntimeError('Destination Register error should be 1 or 2 current Value : %d' % (dst))
    def set_flg(self):
        self.qcom_ctrl = 1+2*8

    def print_dt(self):
        print("FLAG:{}   DT1:{}   DT2:{}   ".format(self.flag, self.dt1, self.dt2))
    
    def print_axi_regs(self):
        print('---------------------------------------------')
        print('--- AXI Registers')
        for xreg in self.REGISTERS.keys():
            reg_num = getattr(self, xreg)
            reg_bin = '{:039_b}'.format(reg_num)
            print(f'{xreg:>10}', f'{reg_num:>11}'+' - '+f'{reg_bin:>33}' )
    def print_status(self):
        debug_num = self.status
        debug_bin = '{:032b}'.format(debug_num)
        print('---------------------------------------------')
        print('--- AXI TNET Register RX_STATUS')
        print( ' qcom_rx_st   : ' + debug_bin[30:32] )
        print( ' rx_header    : ' + debug_bin[27:30] )
        print( ' reg_sel      : ' + debug_bin[25:27] )
        print( ' reg_wr_size  : ' + debug_bin[23:25] )
        print( ' qcom_tx_st   : ' + debug_bin[20:23] )
        print( ' tx_header    : ' + debug_bin[17:20]  )            
    def print_debug(self):
        debug_num = self.debug
        debug_bin = '{:032b}'.format(debug_num)
        print('---------------------------------------------')
        print('--- AXI TNET Register RX_STATUS')
        print( ' qcom_rx_st   : ' + debug_bin[30:32] )
        print( ' rx_header    : ' + debug_bin[27:30] )
        print( ' reg_sel      : ' + debug_bin[25:27] )
        print( ' reg_wr_size  : ' + debug_bin[23:25] )
        print( ' qcom_tx_st   : ' + debug_bin[20:23] )
        print( ' tx_header    : ' + debug_bin[17:20]  )            

            
class QICK_Net(SocIP):
    """
    QICK_Net class

    ####################
    AXIS T_CORE xREG
    ####################
    CORE_CTRL        Write / Read 32-Bits
    CORE_CFG         Write / Read 32-Bits
    RAXI_DT1         Write / Read 32-Bits
    RAXI_DT2         Write / Read 32-Bits
    CORE_R_DT1       Read Only    32-Bits
    CORE_R_DT2       Read Only    32-Bits
    PORT_LSW         Read Only    32-Bits
    PORT_MSW         Read Only    32-Bits
    RAND             Read Only    32-Bits
    CORE_W_DT1       Read Only    32-Bits
    CORE_W_DT2       Read Only    32-Bits
    CORE_STATUS      Read Only    32-Bits
    CORE_DEBUG       Read Only    32-Bits

    :param mem: memory address
    :type mem: int
    :param axi_dma: axi_dma address
    :type axi_dma: int
    """
    bindto = ['Fermi:user:qick_network:1.0']


    main_list = ['M_NOT_READY','M_IDLE','M_LOC_CMD','M_NET_CMD','M_WRESP','M_WACK','M_NET_RESP','M_NET_ANSW','M_CMD_EXEC','M_ERROR']
    task_list = ['T_NOT_READY','T_IDLE','T_LOC_CMD','T_LOC_WSYNC','T_LOC_SEND','T_LOC_WnREQ','T_NET_CMD', 'T_NET_SEND']
    cmd_list = [ 'NOT_READY','IDLE','L_GNET','L_SNET','L_SYNC1','L_UPDT_OFF','L_SET_DT','L_GET_DT','L_RST_TIME','L_START',\
    'L_STOP','N_GNET_P','N_SNET_P','N_SYNC1_P','N_UPDT_OFF_P','N_SET_DT_P','N_GET_DT_P','N_RST_TIME_P','N_START_P','N_STOP_P',\
    'N_GNET_R','N_SNET_R','N_SYNC1_R','N_UPDT_OFF_R','N_DT_R','N_TPROC_R','N_GET_DT_A','WAIT_TX_ACK','WAIT_TX_nACK','WAIT_CMD_nACK',\
             'STATE','ST_ERROR']
    link_list = ['NOT_READY','IDLE','RX','PROCESS','PROPAGATE','TX_H','TX_D','WAIT_nREQ']
    ctrl_list = ['X','IDLE','CHECK_TIME1','CHECK_TIME2','WAIT_TIME','WAIT_SYNC','EXECUTE','ERROR']

    def _init_config(self, description):
        self.REGISTERS = {
                'tnet_ctrl'     :0 ,
                'tnet_cfg'      :1 ,
                'tnet_addr'     :2 ,
                'tnet_len'      :3 ,
                'raxi_dt1'      :4 ,
                'raxi_dt2'      :5 ,
                'raxi_dt3'      :6 ,
                'nn_id'         :7 ,
                'rtd'           :8,
                'tnet_w_dt1'    :9,
                'tnet_w_dt2'    :10,
                'rx_status'     :11,
                'tx_status'     :12,
                'status'        :13,
                'debug'         :14,
                'hist'          :15
                }
       
    def _init_firmware(self):
        # Initial Values 
        self.tnet_ctrl = 0
        self.tnet_cfg  = 0
        self.tnet_addr = 0
        self.mem_len   = 100
        self.tnet_len  = 0
        self.raxi_dt1  = 0
        self.raxi_dt2  = 0
        self.raxi_dt3  = 0

    # Configure this driver with links to its memory and DMA.
    def configure(self, mem, axi_dma):
        # Program memory.
        self.mem = mem
        # dma
        self.dma = axi_dma
    

    def clear_cond(self):
        self.logger.info('RESET')
        self.tproc_ctrl      = 2048
        
    def print_axi_regs(self):
        print('---------------------------------------------')
        print('--- AXI Registers')
        for xreg in self.REGISTERS.keys():
            print(f'{xreg:>15}', getattr(self, xreg))
    def print_status(self):
        rx_status_num = self.rx_status
        rx_status_bin = '{:032b}'.format(rx_status_num)
        tx_status_num = self.tx_status
        tx_status_bin = '{:032b}'.format(tx_status_num)
        status_num = self.status
        status_bin = '{:032b}'.format(status_num)
        print('---------------------------------------------')
        print('--- AXI TNET Register RX_STATUS')
        print( ' RX_CNT    : ' + rx_status_bin[26:32] )
        print( ' RX_CMD    : ' + rx_status_bin[18:23] )
        print( ' RX_FLAGS  : ' + rx_status_bin[23:26] )
        print( ' RX_DST    : ' + rx_status_bin[14:18] )
        print( ' RX_SRC    : ' + rx_status_bin[10:14] )
        print( ' RX_STEP   : ' + rx_status_bin[4:10]  )
        print( ' RX_H_DT   : ' + rx_status_bin[0:4]   )

        print('--- AXI TNET Register TX_STATUS')
        print( ' TX_CNT    : ' + tx_status_bin[26:32] )
        print( ' TX_CMD    : ' + tx_status_bin[18:23] )
        print( ' TX_FLAGS  : ' + tx_status_bin[23:26] )
        print( ' TX_DST    : ' + tx_status_bin[14:18] )
        print( ' TX_SRC    : ' + tx_status_bin[10:14] )
        print( ' TX_STEP   : ' + tx_status_bin[4:10]  )
        print( ' TX_H_DT   : ' + tx_status_bin[0:4]   )

        print('--- AXI TNET Register TNET_STATUS')
        print( ' MMC_LOCKED   : ' + status_bin[31] )
        print( ' GT_PLL_LOCK  : ' + status_bin[30] )
        print( ' CH_A_RX_UP   : ' + status_bin[29] )
        print( ' CH_A_TX_UP   : ' + status_bin[28] )
        print( ' CH_B_RX_UP   : ' + status_bin[27] )
        print( ' CH_B_TX_UP   : ' + status_bin[26] )
        print( ' AURORA_RDY   : ' + status_bin[25] )
        print( ' TX_REQ       : ' + status_bin[24] )
        print( ' TX_ACK       : ' + status_bin[23] )
        print( ' ERROR_ID     : ' + status_bin[19:23] )
        print( '--------------------------------')
        print( ' READY        : ' + status_bin[15] )
        print( '--------------------------------')
        print( ' GET_NET      : ' + status_bin[14] )
        print( ' SET_NET      : ' + status_bin[13] )
        print( ' SYNC1_NET    : ' + status_bin[12] )
        print( ' SYNC2_NET    : ' + status_bin[11] )
        print( ' GET_OFF      : ' + status_bin[8] )
        print( ' UPDT_OFF     : ' + status_bin[7] )
        print( ' SET_DT       : ' + status_bin[6] )
        print( ' GET_DT       : ' + status_bin[5] )
        print( ' RST_TIME     : ' + status_bin[4] )
        print( ' START_CORE   : ' + status_bin[3] )
        print( ' STOP_CORE    : ' + status_bin[2] )
        print( ' GET_COND     : ' + status_bin[1] )
        print( ' SET_COND     : ' + status_bin[0] )

    def print_debug(self):

        print('---------------------------------------------')

        print('--- AXI TNET Register DEBUG_0')
        self.tnet_cfg = 0
        debug_num = self.debug
        debug_bin = '{:032b}'.format(debug_num)
        main_st  = int(debug_bin[28:32], 2) 
        task_st  = int(debug_bin[24:28], 2) 
        cmd_st   = int(debug_bin[19:24], 2) 
        ctrl_st  = int(debug_bin[16:19], 2) 
        link_st  = int(debug_bin[13:16], 2) 
        print( ' MAIN_ST    : ' + str(main_st) + ' - ' + self.main_list[main_st])
        print( ' TASK_ST    : ' + str(task_st) + ' - ' + self.task_list[task_st])
        print( ' CMD_ST     : ' + str(cmd_st)  + ' - ' + self.cmd_list[cmd_st] )
        print( ' CTRL_ST    : ' + str(ctrl_st)  + ' - ' + self.ctrl_list[ctrl_st] )
        print( ' LINK_ST    : ' + str(link_st)  + ' - ' + self.link_list[link_st] )

        print('---------------------------------------------')
        print('--- AXI TNET Register DEBUG_1')
        self.tnet_cfg = 1
        debug_num = self.debug
        debug_bin = '{:032b}'.format(debug_num)
        print( ' PY_CMD_CNT    : ' + debug_bin[29:32] )
        print( ' tProc_CMD_CNT : ' + debug_bin[26:29] )
        print( ' NET_CMD_CNT   : ' + debug_bin[23:26] )
        print( ' ERROR_CNT     : ' + debug_bin[15:23] )
        print( ' READY_CNT     : ' + debug_bin[7:15] )

        
        print('--- AXI TNET Register DEBUG_2')
        self.tnet_cfg = 2
        debug_num = self.debug
        debug_bin = '{:032b}'.format(debug_num)
        print( ' PR_CNT    : ' + debug_bin[28:32] )
        print( ' PR_CMD    : ' + debug_bin[23:28] )
        print( ' PR_SRC    : ' + debug_bin[13:23] )
        print( ' PR_DST    : ' + debug_bin[3:13] )
        print( ' net_dst_ones: ' + debug_bin[2]  )
        print( ' net_dst_own : ' + debug_bin[1]  )
        print( ' net_src_own : ' + debug_bin[0]  )

        print('--- AXI TNET Register DEBUG_3')
        self.tnet_cfg = 3
        debug_num = self.debug
        debug_bin = '{:032b}'.format(debug_num)
        print( ' EX_CNT    : ' + debug_bin[28:32] )
        print( ' EX_CMD    : ' + debug_bin[23:28] )
        print( ' EX_SRC    : ' + debug_bin[13:23] )
        print( ' EX_DST    : ' + debug_bin[3:13] )
        print( ' net_dst_ones: ' + debug_bin[2]  )
        print( ' net_dst_own : ' + debug_bin[1]  )
        print( ' net_src_own : ' + debug_bin[0]  )

        print('--- AXI TNET Register DEBUG_4')
        self.tnet_cfg = 4
        debug_num = self.debug
        debug_bin = '{:032b}'.format(debug_num)
        print( ' ERR_1    : ' + debug_bin[28:32] )
        print( ' ERR_2    : ' + debug_bin[24:28] )
        print( ' ERR_3    : ' + debug_bin[20:24] )
        print( ' ERR_4    : ' + debug_bin[16:20] )
        print( ' ERR_5    : ' + debug_bin[12:16] )
        print( ' ERR_6    : ' + debug_bin[8:12] )
        print( ' ERR_7    : ' + debug_bin[4:8] )
        print( ' ERR_8    : ' + debug_bin[0:4] )

        print('--- AXI TNET Register HIST')
        hist_num = self.hist
        hist_bin = '{:032b}'.format(hist_num)
        cmd1_st = int(hist_bin[27:32], 2) 
        cmd2_st = int(hist_bin[22:27], 2) 
        cmd3_st = int(hist_bin[17:22], 2) 
        cmd4_st = int(hist_bin[12:17], 2) 
        cmd5_st = int(hist_bin[7:12], 2) 

        self.tnet_cfg = 5
        debug_num = self.debug
        debug_bin = '{:032b}'.format(debug_num)
        cmd6_st = int(debug_bin[27:32], 2) 
        cmd7_st = int(debug_bin[22:27], 2) 
        cmd8_st = int(debug_bin[17:22], 2) 
        cmd9_st = int(debug_bin[12:17], 2) 
        cmd10_st = int(debug_bin[7:12], 2) 
        self.tnet_cfg = 6
        debug_num = self.debug
        debug_bin = '{:032b}'.format(debug_num)
        cmd11_st = int(debug_bin[27:32], 2) 
        cmd12_st = int(debug_bin[22:27], 2) 
        cmd13_st = int(debug_bin[17:22], 2) 
        cmd14_st = int(debug_bin[12:17], 2) 
        cmd15_st = int(debug_bin[7:12], 2) 
        self.tnet_cfg = 7
        debug_num = self.debug
        debug_bin = '{:032b}'.format(debug_num)
        cmd16_st = int(debug_bin[27:32], 2) 
        cmd17_st = int(debug_bin[22:27], 2) 
        cmd18_st = int(debug_bin[17:22], 2) 
        cmd19_st = int(debug_bin[12:17], 2) 
        cmd20_st = int(debug_bin[7:12], 2) 
       
        print( ' T1   : ' + str(cmd1_st) + ' - ' + self.cmd_list[cmd1_st])
        print( ' T2   : ' + str(cmd2_st) + ' - ' + self.cmd_list[cmd2_st])
        print( ' T3   : ' + str(cmd3_st) + ' - ' + self.cmd_list[cmd3_st])
        print( ' T4   : ' + str(cmd4_st) + ' - ' + self.cmd_list[cmd4_st])
        print( ' T5   : ' + str(cmd5_st) + ' - ' + self.cmd_list[cmd5_st])
        print( ' T6   : ' + str(cmd6_st) + ' - ' + self.cmd_list[cmd6_st])
        print( ' T7   : ' + str(cmd7_st) + ' - ' + self.cmd_list[cmd7_st])
        print( ' T8   : ' + str(cmd8_st) + ' - ' + self.cmd_list[cmd8_st])
        print( ' T9   : ' + str(cmd9_st) + ' - ' + self.cmd_list[cmd9_st])
        print( ' T10  : ' + str(cmd10_st) + ' - ' + self.cmd_list[cmd10_st])
        print( ' T11  : ' + str(cmd11_st) + ' - ' + self.cmd_list[cmd11_st])
        print( ' T12  : ' + str(cmd12_st) + ' - ' + self.cmd_list[cmd12_st])
        print( ' T13  : ' + str(cmd13_st) + ' - ' + self.cmd_list[cmd13_st])
        print( ' T14  : ' + str(cmd14_st) + ' - ' + self.cmd_list[cmd14_st])
        print( ' T15  : ' + str(cmd15_st) + ' - ' + self.cmd_list[cmd15_st])
        print( ' T16  : ' + str(cmd16_st) + ' - ' + self.cmd_list[cmd16_st])
        print( ' T17  : ' + str(cmd17_st) + ' - ' + self.cmd_list[cmd17_st])
        print( ' T18  : ' + str(cmd18_st) + ' - ' + self.cmd_list[cmd18_st])
        print( ' T19  : ' + str(cmd19_st) + ' - ' + self.cmd_list[cmd19_st])
        print( ' T20  : ' + str(cmd19_st) + ' - ' + self.cmd_list[cmd20_st])
        
    def get_sth(self):
        debug_num = self.tnet_debug
        debug_bin = '{:032b}'.format(debug_num)
        task_st = int(debug_bin[19:23], 2) 
        ver_num = self.version
        ver_bin = '{:032b}'.format(ver_num)
        cmd0_st = int(ver_bin[25:30], 2) 
        cmd1_st = int(ver_bin[20:25], 2) 
        cmd2_st = int(ver_bin[15:20], 2) 
        cmd3_st = int(ver_bin[10:15], 2) 
        cmd4_st = int(ver_bin[5:10], 2) 
        cmd5_st = int(ver_bin[0:5], 2) 
        print('---------------------------------------------')
        print( ' AURORA_CNT  : ' + debug_bin[27:32] )
        print( ' AURORA_OP   : ' + debug_bin[23:27] )
        print( ' TASK_ST     : ' + str(task_st) + ' - ' + task_list[task_st])
        print( ' MAIN_ST     : ' + debug_bin[15:19] )
        print( ' T0   : ' + str(cmd0_st) + ' - ' + cmd_list[cmd0_st])
        print( ' T1   : ' + str(cmd1_st) + ' - ' + cmd_list[cmd1_st])
        print( ' T2   : ' + str(cmd2_st) + ' - ' + cmd_list[cmd2_st])
        print( ' T3   : ' + str(cmd3_st) + ' - ' + cmd_list[cmd3_st])
        print( ' T4   : ' + str(cmd4_st) + ' - ' + cmd_list[cmd4_st])
        print( ' T5   : ' + str(cmd5_st) + ' - ' + cmd_list[cmd5_st])
        
