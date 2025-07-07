"""
#######################################
XCOM driver for qick_processor.
2025-06-17

#######################################
"""
import numpy as np
from qick.ip import SocIP
import re

class QICK_Xcom(SocIP):
    """
    QICK_Comm class
    ####################
    QICK COM xREG
    ####################
    XCOM_CTRL       Write / Read 32-Bits
    XCOM_CFG        Write / Read 32-Bits
    AXI_DT1         Write / Read 32-Bits
    AXI_DT2         Write / Read 32-Bits
    AXI_ADDR        Write / Read 32-Bits
    BOARD_ID        Read Only    32-Bits
    XCOM_FLAG       Read Only    32-Bits
    XCOM_DT1        Read Only    32-Bits
    XCOM_DT2        Read Only    32-Bits
    XCOM_MEM        Read Only    32-Bits
    XCOM_RX_DT      Read Only    32-Bits
    XCOM_TX_DT      Read Only    32-Bits
    XCOM_STATUS     Read Only    32-Bits
    XCOM_DEBUG      Read Only    32-Bits
    """
    bindto = ['fnal:qick:xcom:1.0','user.org:user:xcom_axil_slv:1.0'] 

    def __init__(self, description):
        """
        Constructor method
        """
        super().__init__(description)

        self.REGISTERS = {
            'xcom_ctrl' :0 ,
            'xcom_cfg'  :1 ,
            'axi_dt1'   :2 ,
            'axi_dt2'   :3 ,
            'axi_addr'  :4 ,
            'board_id'  :6 ,
            'flag'      :7 ,
            'dt1'       :8 ,
            'dt2'       :9,
            'mem'       :10,
            'rx_dt'     :12,
            'tx_dt'     :13,
            'status'    :14,
            'debug'     :15
        }
        
        self.opcodes = {
            'XCOM_RST'         : 31 , #5'b1_1111  ;//LOC command
            'XCOM_WRITE_MEM'   : 19 , #5'b1_0011  ;//LOC command
            'XCOM_WRITE_REG'   : 18 , #5'b1_0010  ;//LOC command
            'XCOM_WRITE_FLAG'  : 17 , #5'b1_0001  ;//LOC command
            'XCOM_SET_ID'      : 16 , #5'b1_0000  ;//LOC command
            'XCOM_RFU2'        : 15 , #5'b0_1111  ;
            'XCOM_RFU1'        : 13 , #5'b0_1101  ;
            'XCOM_QCTRL'       : 11 , #5'b0_1011  ;
            'XCOM_UPDATE_DT32' : 14 , #5'b0_1110  ;
            'XCOM_UPDATE_DT16' : 12 , #5'b0_1100  ;
            'XCOM_UPDATE_DT8'  : 10 , #5'b0_1010  ;
            'XCOM_AUTO_ID'     : 9  , #5'b0_1001  ;
            'XCOM_QRST_SYNC'   : 8  , #5'b0_1000  ;
            'XCOM_SEND_32BIT_2': 7  , #5'b0_0111  ;
            'XCOM_SEND_32BIT_1': 6  , #5'b0_0110  ;
            'XCOM_SEND_16BIT_2': 5  , #5'b0_0101  ;
            'XCOM_SEND_16BIT_1': 4  , #5'b0_0100  ;
            'XCOM_SEND_8BIT_2' : 3  , #5'b0_0011  ;
            'XCOM_SEND_8BIT_1' : 2  , #5'b0_0010  ;
            'XCOM_SET_FLAG'    : 1  , #5'b0_0001  ;
            'XCOM_CLEAR_FLAG'  : 0    #5'b0_0000  ;
        }


    # Initial Values 
        self.xcom_ctrl  = 0
        self.xcom_cfg   = 0
        self.axi_dt1    = 0
        self.axi_dt2    = 0
        self.axi_addr   = 0

    def __str__(self):
        lines = []
        lines.append('---------------------------------------------')
        lines.append(' QICK Xcom INFO ')
        lines.append('---------------------------------------------')
        lines.append("----------\n")
        return "\n".join(lines)

    def clear_flag(self, dst):
        if  (dst < 16 ):
            self.axi_dt1   = dst
            self.xcom_ctrl = 1+2*0
        else:
            raise RuntimeError('Destination Board error should be between 1 and 15 - current Value : %d' % (dst))

    def set_flag(self, dst):
        if  (dst < 16 ):
            self.axi_dt1   = dst
            self.xcom_ctrl = 1+2*1
        else:
            raise RuntimeError('Destination Board error should be between 1 and 15 - current Value : %d' % (dst))

    def set_local_id(self, chid):
        if  (chid < 16 ):
            self.axi_dt1   = chid
            self.xcom_ctrl = 1+2*16
        else:
            raise RuntimeError('Board ID number should be between 1 and 15 - current Value : %d' % (chid))
            
    def write_local_flag(self, flg):
        if  (flg == 1 ):
            self.axi_dt1   = flg
            self.xcom_ctrl = 1+2*17
        else:
            raise RuntimeError('Flag must be 1 - current Value : %d' % (flg))
            
    def send_byte(self, data, dst, reg):
        if  (dst < 16 ):
            self.axi_dt1  = dst
            self.axi_dt2  = data
            if   (reg == 1):
                self.xcom_ctrl = 1+2*2
            elif (reg == 2):
                self.xcom_ctrl = 1+2*3
            else:
                raise RuntimeError('Destination Register error should be 1 or 2 current Value : %d' % (reg))
        else:
            raise RuntimeError('Destination Board error should be between 1 and 15 - current Value : %d' % (dst))

    def send_half_word(self, data, dst, reg):
        if  (dst < 16 ):
            self.axi_dt1  = dst
            self.axi_dt2  = data
            if   (reg == 1):
                self.xcom_ctrl = 1+2*4
            elif (reg == 2):
                self.xcom_ctrl = 1+2*5
            else:
                raise RuntimeError('Destination Register error should be 1 or 2 current Value : %d' % (reg))
        else:
            raise RuntimeError('Destination Board error should be between 1 and 15 - current Value : %d' % (dst))

    def send_word(self, data, dst, reg):
        if  (dst < 16 ):
            self.axi_dt1  = dst
            self.axi_dt2  = data
            if   (reg == 1):
                self.xcom_ctrl = 1+2*6
            elif (reg == 2):
                self.xcom_ctrl = 1+2*7
            else:
                raise RuntimeError('Destination Register error should be 1 or 2 current Value : %d' % (reg))
        else:
            raise RuntimeError('Destination Board error should be between 1 and 15 - current Value : %d' % (dst))

    def auto_id(self):
            self.axi_dt1 = 0
            self.axi_dt2 = 0
            self.xcom_ctrl = 1+2*9
        
    def update_byte(self, data, dst):
        if  (dst < 16 ):
            self.axi_dt1   = dst
            self.axi_dt2   = data
            self.xcom_ctrl = 1+2*10
        else:
            raise RuntimeError('Destination Board error should be between 0 and 15 - current Value : %d' % (dst))
            
    def run_cmd(self, cmd, dt1, dt2):
            self.axi_dt1 = dt1
            self.axi_dt2 = dt2
            self.xcom_ctrl = 1+2*cmd
            
            
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
        #print(debug_bin)
        print('---------------------------------------------')
        print('--- AXI XCOM Register STATUS')
        tx_status = debug_num & 0x3
        if tx_status == 0:
            print( ' tx_st     : ' + 'IDLE')
        elif tx_status == 1:
            print( ' tx_st     : ' + 'WVLD')
        elif tx_status == 2:
            print( ' tx_st     : ' + 'WSYNC')
        elif tx_status == 3:
            print( ' tx_st     : ' + 'WRDY' )
        else:
            print( ' tx_st     : ' + 'UNKNOWN' )
            
        rx_status = (debug_num & 0x01C0)>>6
        if rx_status == 0:
            print( ' rx_st     : ' + 'IDLE')
        elif rx_status == 1:
            print( ' rx_st     : ' + 'HEADER')
        elif rx_status == 2:
            print( ' rx_st     : ' + 'DATA')
        elif rx_status == 3:
            print( ' rx_st     : ' + 'REQ' )
        elif rx_status == 4:
            print( ' rx_st     : ' + 'ACK' )
        else:
            print( ' rx_st     : ' + 'UNKNOWN' )
        
        print( ' tx_ready     : ' + debug_bin[15]    )
        print( ' board_id     : ' + debug_bin[11:15] )
        print( ' rx_data_cntr : ' + debug_bin[7:11]  )
        
    def print_debug(self):
        debug_num = self.debug
        debug_bin = '{:032b}'.format(debug_num)
        print(debug_num, debug_bin)
        print('---------------------------------------------')
        print('--- AXI XCOM DEBUG')
        print( ' cmd_loc_req_i : ' + debug_bin[31]    )
        print( ' cmd_loc_ack   : ' + debug_bin[30]    )
        print( ' loc_set_id    : ' + debug_bin[29]    )
        print( ' loc_wflg      : ' + debug_bin[28]    )
        print( ' loc_wreg      : ' + debug_bin[27]    )
        print( ' loc_wmem      : ' + debug_bin[26]    )
        print( ' cmd_net_req_i : ' + debug_bin[25]    )
        print( ' cmd_net_ack   : ' + debug_bin[24]    )
        print( ' cmd_op_i      : ' + debug_bin[16:24] )
        print( ' rx_cmd_op     : ' + debug_bin[12:16] )
        print( ' tx_auto_id    : ' + debug_bin[11]    )
        print( ' rx_no_dt      : ' + debug_bin[10]    )
        print( ' rx_wflg       : ' + debug_bin[9]     )
        print( ' rx_wreg       : ' + debug_bin[8]     )
        print( ' rx_wmem       : ' + debug_bin[7]     )
        print( ' rx_cmd_id     : ' + debug_bin[4:7]   )
        print( ' cfg_i         : ' + debug_bin[0:4]   )
        print('---------------------------------------------')
        print('--- AXI XCOM RX_DT')
        debug_num = self.rx_dt
        debug_bin = '{:032b}'.format(debug_num)
        print('rx_dt ', f'{debug_num:>11}'+' - '+f'{debug_bin:>33}' )
        print('---------------------------------------------')
        print('--- AXI XCOM TX_DT')
        debug_num = self.tx_dt
        debug_bin = '{:032b}'.format(debug_num)
        print('tx_dt ', f'{debug_num:>11}'+' - '+f'{debug_bin:>33}' )    

        
