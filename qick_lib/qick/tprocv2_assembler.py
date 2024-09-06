"""
///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Date        : 2024_8_2
//  Version     : 3
//  Revision    : 23
///////////////////////////////////////////////////////////////////////////////
Description: Assembler for Qick Processor
-Create Binary Files  ( list2bin, file_asm2bin, str_asm2bin )
-Create Instruction List ( file_asm2list, str_asm2list )
-Create Assembler File from Instruction List ( list2asm )

p_list        = Assembler.file_asm2list(filenames[0])
p_list[0] > program_list
p_list[1] > label_dict

p_txt, p_bin  = Assembler.file_asm2bin(filenames[0])
p_txt > Used for Simulation
p_bin > Used to store in the memory

Get ASM from Program List Structure
p_asm         = Assembler.list2asm(p_list[0], p_list[1])

///////////////////////////////////////////////////////////////////////////////
Release (March 2024)
To be used with qick_processor version 17th or Higher....

"""

###################################
###      UNDER DEVELOPMENT      ###
###################################

##### DEFINITIONS
###############################################################################

# Instructions.
instList = {
        'NOP'        : '000 - No Operation',
        'TEST'       : '000 - Update ALU Flags with an Operation',
        'JUMP'       : '001 - Branch to a Specific Address',
        'CALL'       : '001 - Function Call',
        'RET'        : '001 - Function Return',
        'FLAG'       : '010 - FLAG set / reset',
        'TIME'       : '010 - Time Instruction',
        'ARITH'      : '010 - Opeates (A+/-B)*C+/-D',
        'DIV'        : '010 - Opeates (A/B) Return Quotient and Reminder',
        'NET'        : '011 - Network Peripheral Instruction',
        'COM'        : '011 - Communication Peripheral Instruction',
        'PA'         : '011 - Cutsom Peripheral Instruction',
        'PB'         : '011 - Cutsom Peripheral Instruction',
        'REG_WR'     : '100 - Register Write',
        'DMEM_WR'    : '101 - Data Memory Write',
        'WMEM_WR'    : '101 - WaveParam Memory Write',
        'TRIG'       : '110 - Trigger Set',
        'DPORT_WR'   : '110 - Data Port Write',
        'DPORT_RD'   : '110 - Data Port Read',
        'WPORT_WR'   : '110 - WaveParam Port Write',
        'CLEAR'      : 'Complex Clear Flag (dt_new).',
        'WAIT'       : 'Complex - Jump [HERE] Until time value arrives.'
        }

# ALU OPERATIONS 
aluList = {
        '+'     : '0000',
        '-'     : '0010',
        'AND'   : '0100',
        '&'     : '0100',
        'MSK'   : '0100',
        'ASR'   : '0110',
        'ABS'   : '1000',
        'MSH'   : '1010',
        'LSH'   : '1100',
        'SWP'   : '1110',
        'NOT'   : '0001',
        '!'     : '0001',
        'OR'    : '0011',
        '|'     : '0011',
        'XOR'   : '0101',
        '^'     : '0101',
        'CAT'   : '0111',
        '::'    : '0111',
        'RFU'   : '1001',
        'PAR'   : '1011',
        'SL'    : '1101',
        '<<'    : '1101',
        'SR'    : '1111',
        '>>'    : '1111' }

aluList_s = {
        '+'   : '00',
        '-'   : '01',
        'AND' : '10',
        'ASR' : '11' } ## List with Commands for -op()

aluList_op = ['ABS', 'MSH', 'LSH', 'SWP', 'PAR', 'NOT'] ## List with Commands with one parameter

arithList = { 
'T'   : '0000', #  A*B
'TP'  : '0001', #  A*B+C
'TM'  : '0010', #  A*B-C
'PT'  : '0011', # (D+A)*B
'PTP' : '0100', # (D+A)*B+C
'PTM' : '0101', # (D+A)*B-C
'MT'  : '0110', # (D-A)*B
'MTP' : '0111', # (D-A)*B+C
'MTM' : '1000', # (D-A)*B-C
}

# CONDITIONALS
condList = {
    '1'   : '000',
    'Z'   : '001',
    'S'   : '010',
    'NZ'  : '011',
    'NS'  : '100',
    'F'   : '101',
    'NF'  : '110',
    '0'   : '111'}

#### REGULAR EXPRESSIONS
###############################################################################

# LIT SHOULD BE LAST
Param_List = { 
    'TIME'      : {'RegEx' : r'(?<=@)[\-0-9]+'               , 'RL': '@'        , 'RR': ''   },
    'ADDR'      : {'RegEx' : r'\[(.*)\]'                     , 'RL': '['        , 'RR': ']'  },
    'UF'        : {'RegEx' : r'-uf'                          , 'RL': ''         , 'RR': ''   },
    'WW'        : {'RegEx' : r'-ww'                          , 'RL': ''         , 'RR': ''   },
    'WP'        : {'RegEx' : r'-wp\(([_a-z\s]*)\)'           , 'RL': '-wp('     , 'RR': ')'  },
    'OP'        : {'RegEx' : r'-op\(([\s#a-zA-Z0-9+\-<>_]*)\)', 'RL': '-op('     , 'RR': ')'  }, 
    'IF'        : {'RegEx' : r'-if\(([A-Z\s]*)\)'            , 'RL': '-if('     , 'RR': ')'  },
    'WR'        : {'RegEx' : r'-wr\(([a-z\s0-9]*)\)'         , 'RL': '-wr('     , 'RR': ')'  },
    'PORT'      : {'RegEx' : r'p([0-9]+)'                    , 'RL': 'p'        , 'RR': ''   },
    'LIT'       : {'RegEx' : r'(?<=#)[ubh0-9ABCDEF\-_]+'      , 'RL': '#'        , 'RR': ''   },
}

Alias_List = { 
## REGISTER NAME
   'w_freq'        : 'w0'  ,
   'w_phase'       : 'w1'  ,
   'w_env'         : 'w2'  ,
   'w_gain'        : 'w3'  ,
   'w_length'      : 'w4'  ,
   'w_conf'        : 'w5'  ,
   'zero'          : 's0'  ,
   's_zero'        : 's0'  ,
   's_rand'        : 's1'  ,
   's_cfg'         : 's2'  ,
   's_ctrl'        : 's2'  ,
   's_arith_l'     : 's3'  ,
   's_div_q'       : 's4'  ,
   's_div_r'       : 's5'  ,
   's_core_r1'     : 's6'  ,
   's_core_r2'     : 's7'  ,
   's_port_l'      : 's8'  ,
   's_port_h'      : 's9'  ,
   's_status'      : 's10' ,
   's_usr_time'    : 's11' ,
   'curr_usr_time' : 's11' ,
   's_core_w1'     : 's12' ,
   's_core_w2'     : 's13' ,
   'out_usr_time'  : 's14' ,
   's_out_time'    : 's14' ,
   's_addr'        : 's15' ,
## Status
   'bit_arith_rdy' : '#h0001' ,
   'bit_arith_new' : '#h0002' ,
   'bit_div_rdy'   : '#h0004' ,
   'bit_div_new'   : '#h0008' ,
   'bit_qnet_rdy'  : '#h0010' ,
   'bit_qnet_new'  : '#h0020' ,
   'bit_qcom_rdy'  : '#h0040' ,
   'bit_qcom_new'  : '#h0080' ,
   'bit_qpa_rdy'   : '#h0100' ,
   'bit_qpa_new'   : '#h0200' ,
   'bit_qpb_rdy'   : '#h0400' ,
   'bit_qpb_new'   : '#h0800' ,
   'bit_port_new'  : '#h8000' ,
## Config
   'cfg_src_axi'       : '#h00' ,
   'cfg_src_arith'     : '#h01' ,
   'cfg_src_qnet'      : '#h02' ,
   'cfg_src_qcom'      : '#h03' ,
   'cfg_src_qpa'       : '#h04' ,
   'cfg_src_qpb'       : '#h05' ,
   'cfg_src_core'      : '#h06' ,
   'cfg_src_port'      : '#h07' ,
   'cfg_flg_int'       : '#h00' ,
   'cfg_flg_axi'       : '#h10' ,
   'cfg_flg_ext'       : '#h20' ,
   'cfg_flg_div'       : '#h30' ,
   'cfg_flg_arith'     : '#h30' ,
   'cfg_flg_port'      : '#h40' ,
   'cfg_flg_qnet'      : '#h50' ,
   'cfg_flg_qcom'      : '#h60' ,
   'cfg_flg_qpa'       : '#h70' ,
   'cfg_src_flg_arith' : '#h31' ,
   'cfg_src_flg_qnet'  : '#h52' ,
   'cfg_src_flg_qcom'  : '#h63' ,
   'cfg_src_flg_qpa'   : '#h76' ,
## CTRL
   'ctrl_clr_arith'   : ' #h1_0000'   ,
   'ctrl_clr_div'     : ' #h2_0000'   ,
   'ctrl_clr_qnet'    : ' #h4_0000'   ,
   'ctrl_clr_qcom'    : ' #h8_0000'   ,
   'ctrl_clr_qpa'     : '#h10_0000'   ,
   'ctrl_clr_qpb'     : '#h20_0000'   ,
   'ctrl_clr_port'    : '#h40_0000'   ,
   'clr_all'          : '#h7F_0000'   ,
   'ctrl_csf_arith'   : '#h01_00_3_1' ,
   'ctrl_csf_div'     : '#h02_00_3_0' ,
   'ctrl_csf_qnet'    : '#h04_00_5_2' ,
   'ctrl_csf_qcom'    : '#h08_00_6_3' ,
   'ctrl_csf_qpa'     : '#h10_00_7_4' 
}


regex = {
    'LABEL'     : r'[A-Za-z0-9_]+(?=\:)' , 
    'DIRECTIVE' : r'(?<=\.)[A-Z]+'       , 
    'CMD'       : r'^[A-Z_]+'            , 
    'CNAME'     : r'^[A-Za-z_]+'         , # Name for CONSTANT
    'NAME'      : r'^[A-Za-z0-9_]+'      , # Name for ALIAS AND LABEL
    'LIT'       : r'(?<=#)[ubh0-9ABCDEF\-_]+',
    'CDS'       : r'\s*([\w&\+\']+)'}

import re

###  LOGGER ###
class Logger():
    INFO = 0
    WARNING = 1
    ERROR = 2
   
    __STATUS = { INFO: 'INFO', WARNING: 'WARNING', ERROR: 'ERROR', }
    
    #__STATUS = [Logger.__dict__]
    filename = "assembler.log"
    f = open(filename, "w")
    f.write("-- Assembler LOG-- \n\n")
    f.close()

    level = WARNING
    
    @staticmethod
    def setLevel(level : int) -> None:
        if level > 2 :
            raise ValueError("Logger.setLevel: show_level must be samller than 2 (0-INFO, 1-WARNINGS, 2-ERRORS)")
        Logger.level = level
    
    @staticmethod
    def setFile(filename : str) -> None:
        Logger.filename = filename
        open(filename, "w+").close()
        with open(filename, 'a') as f:
            f.write("-- Assembler LOG-- \n\n")

    @staticmethod
    def log(*args, **kwargs) -> None:
        print (*args, **kwargs)
    
    @staticmethod
    def info(locator : str, message : str) -> int:
        Logger.__show_message__(Logger.INFO, locator, message)
        return 0
    
    @staticmethod
    def warning(locator : str, message : str) -> int:
        Logger.__show_message__(Logger.WARNING, locator, message)
        return 0
    
    @staticmethod
    def error(locator : str, message : str) -> int:
        Logger.__show_message__(Logger.ERROR, locator, message)
        return 1

    @staticmethod
    def __show_message__(severity : int, locator : str, message : str) -> None:
        msg = f"{Logger.__STATUS[severity]} : [{locator}] > {message}"
        if (Logger.filename):
            Logger.save(msg, Logger.filename)
        if (severity >= Logger.level):
            print (msg)
    
    @staticmethod
    def save(message : str, filename : str) -> None:
        msg_log = message + '\n'
        with open(filename, 'a') as f:
            f.write(msg_log)

def find_pattern(regex : str, text : str):
    match = re.search(regex, text)
    match = match.group() if (match) else None
    return match

def check_name(name_str : str) -> bool:
    r = False
    # Check for correct Characters
    name_check = re.findall(regex['NAME'], name_str)
    if name_check:
        name_check = name_check[0]
        if (name_check == name_str):
            # Check for Register Name
            if ( check_reg(name_str) ):
                Logger.error('CHECK_NAME', 'Name can not be a Register name.')
            else:
                r = True
        else:
            Logger.error('CHECK_NAME', 'Name should use AlphaNumeric and _ characters')
        return r
    else:
        Logger.error('CHECK_NAME', 'Name Error')
            

def integer2bin(strin : str, bits : int = 8, uint : int = 0) -> str:
    """
        receives an integer in str format and returns their bits as a string.
        
    :strin (str): string with an integer
    :bits (int): number of bits to return
    :uint (int): is unsigned 
    :returns (str): bits as a string
    """
    if (uint == 0):
        minv = -2**(bits-1)
        maxv = 2**(bits-1) - 1
    else:
        minv = 0
        maxv = 2**(bits) - 1
    dec = int(strin, 10)
    # Check max.
    if dec < minv:
        Logger.error("integer2bin", "number %d is smaller than %d" % (dec, minv))
        return None
    # Check max.
    if dec > maxv:
        Logger.error("integer2bin", "number %d is bigger than %d" % (dec, maxv))
        return None
    # Check if number is negative.
    if dec < 0:
        dec = dec + 2**bits
    # Convert to binary.
    fmt = "{0:0" + str(bits) + "b}"
    binv = fmt.format(dec)
    return binv

def get_src_type (src : str) -> str:
    """
    :returns (tuple): Type of Source
    """
    src_type = 'X'
    error = 0
    REG = re.findall('s(\d+)|r(\d+)|w(\d+)|#([ubh0-9A-F\-]+)',src) #S,R,W,Signed, Unsigned, Binary, Hexa
    if (REG):
        #print('Register Type> ',REG, REG[0])
        if ( len(REG) != 1 ):
            error = Logger.error('get_src_type', 'Source Data not Recognized '+src )
        else:            
            REG = REG[0]
            if   (REG[0]):   
                src_type = 'RS'
            elif (REG[1]):   
                src_type = 'RD'
            elif (REG[2]):   
                src_type = 'RW'
            elif (REG[3]):   
                src_type = 'N'
            else:            
                src_type = 'XX'
    else:
        error = Logger.error('get_src_type', 'Source Data not Recognized '+src )
    return error, src_type

def check_num(num_str : str) -> bool:
    r = False
    num     = re.search('^(\d+)', num_str)
    extr_num = num.group(0) if num else ''
    if (extr_num == num_str):
        r = True
    return r

def check_lit(lit_str : str) -> bool:
    r = False
    lit     = re.search('#(-?\d+)|#u(\d+)|#b(\d+)|#h([0-9A-F]+)|&(\d+)|@(-?\d+)', lit_str)
    extr_lit = lit.group(0) if lit else ''
    if (extr_lit == lit_str):
        r = True
    return r

def get_imm_dt (lit : str, bit_len : int, lit_val : int = 0) -> str:
    DataImm = ''
    LIT = re.findall('#(-?\d+)|#u(\d+)|#b(\d+)|#h([0-9A-F]+)|&(\d+)|@(-?\d+)',lit) #S,R,W,Signed, Unsigned, Binary, Hexa
    if ( LIT and check_lit(lit)):
        LIT = LIT[0]
        try: 
            if (LIT[0]): ## is Signed
                literal = str(int(LIT[0]))
                DataImm = '_'+ integer2bin(literal, bit_len)
            elif (LIT[1]): ## is Unsigned
                literal = str(int(LIT[1]))
                DataImm = '_'+ integer2bin(literal, bit_len,1)
            elif (LIT[2]): ## is Binary
                literal = str(int(LIT[2],2))
                DataImm = '_'+ integer2bin(literal, bit_len,1)
            elif (LIT[3]): ## is Hexa
                literal = str(int(LIT[3],16))
                DataImm = '_'+ integer2bin(literal, bit_len,1)
            elif (LIT[4]): ## is Address
                literal = str(int(LIT[4]))
                DataImm = '_'+ integer2bin(literal, bit_len,1)
            elif (LIT[5]): ## is Time
                literal = str(int(LIT[5]))
                DataImm = '_'+ integer2bin(literal, bit_len)
        except:
            DataImm = ''
    else:
        Logger.error("get_imm_dt", 'Data Format incorrect '+ lit )
    if  (DataImm) : 
        if (lit_val) :
            return 0, int(literal)
        else:
            return 0, DataImm
    else:
        return 1, 0

def check_reg(name_reg : str) -> bool:
    r = False
    name     = re.search('s(\d+)|r(\d+)|w(\d+)', name_reg)
    extr_reg = name.group(0) if name else ''
    if (extr_reg == name_reg):
        r = True
    return r

def get_reg_addr (reg : str, Type : str) -> tuple:
    """
    :returns (tuple): (error, register_address).
    """
    error    = 0
    reg_addr = 'X'
    if (check_reg(reg) ): #extr_num == name_num):
        REG = re.findall('s(\d+)|r(\d+)|w(\d+)', reg)[0]
        if (Type=='Dest'):
            if (REG[0]): ## is SREG
                if (int(REG[0]) > 15): error = Logger.error('get_reg_addr', 'Register s'+ str(REG[0])+' is not a sreg (Max 15)' )
                else:               reg_addr =  '00'+integer2bin(REG[0], 5,1)   
            elif (REG[1]): ## is DREG
                if (int(REG[1]) > 31): error = Logger.error('get_reg_addr', 'Register d'+ str(REG[1])+' is not a dreg (Max 31)' )
                else:               reg_addr     = '01'+integer2bin(REG[1], 5,1)     
            elif (REG[2]): ## is WREG
                if (int(REG[2]) > 5): error = Logger.error('get_reg_addr', 'Register w'+ str(REG[2])+' is not a wreg (Max 5)' )
                else:               reg_addr     = '10'+integer2bin(REG[2], 5,1)
        elif (Type=='src_data'):
            if (REG[0]): ## is SREG
                if (int(REG[0]) > 15): error = Logger.error('get_reg_addr', 'Register s'+ str(REG[0])+' is not a sreg (Max 15)' )
                else:               reg_addr =  '0_00'+integer2bin(REG[0], 5,1)   
            elif (REG[1]): ## is DREG
                if (int(REG[1]) > 31): error = Logger.error('get_reg_addr', 'Register d'+ str(REG[1])+' is not a dreg (Max 31)' )
                else:               reg_addr     = '0_01'+integer2bin(REG[1], 5,1)     
            elif (REG[2]): ## is WREG
                if (int(REG[2]) > 5): error = Logger.error('get_reg_addr', 'Register w'+ str(REG[1])+' is not a wreg (Max 5)' )
                else:               reg_addr     = '0_10'+integer2bin(REG[2], 5,1)
        elif (Type=='src_addr'):
            if (REG[0]): ## is SREG
                if (int(REG[0]) > 15): error = Logger.error('get_reg_addr', 'Register s'+ str(REG[0])+' is not a sreg (Max 15)' )
                else:               reg_addr =  '0'+integer2bin(REG[0], 5,1)   
            elif (REG[1]): ## is DREG
                if (int(REG[1]) > 31): error = Logger.error('get_reg_addr', 'Register d'+ str(REG[1])+' is not a dreg (Max 31)' )
                else:               reg_addr     = '1'+integer2bin(REG[1], 5,1)     
            elif (REG[2]): ## is WREG
                if (int(REG[2]) > 5): error = Logger.error('get_reg_addr', 'Register w'+ str(REG[2])+' is not a wreg (Max 5)' )
                error = Logger.error('get_reg_addr', 'Register w'+ str(REG[2])+' Can not be wreg' )
    else:
            error = Logger.error('get_reg_addr', 'Register '+ reg +' Name error' )
    return [error, reg_addr]

class LFSR:
    def __init__(self):
        self.val_bin = '00000000000000000000000000000000'
        self.val_int = 0
    def seed(self, seed):
        fmt = "{0:032b}"
        self.val_int = seed
        self.val_bin = fmt.format(seed)
    def nxt(self)-> int:
        inv_bin = self.val_bin[::-1]
        feedback = inv_bin[31] + inv_bin[21] + inv_bin[1] + inv_bin[0]
        ones = feedback.count('1')
        if (ones % 2 == 0):
            new_value = '1'
        else:
            new_value = '0'
        self.val_bin = self.val_bin[1:]+new_value
        self.val_int = int(self.val_bin, 2)
        return self.val_int
    def print (self):
        print (self.val_bin, self.val_int)


class Assembler():
    @staticmethod
    def list2asm(program_list : list, label_dict : dict) -> str:
        """
            translates a program list to assembly.
            
            :program_list (list): each element is a dictionary with all the commands and instructions.
            :label_dict (dictionary): dictionary with all labels information found. ({'P_ADDR': 0,'LINE': 0, 'ADDR': 0})
            :returns (str): assembly as a string.
        """
        
        def process_command(assembler : str, command : dict, p_addr : int) -> str:
            """
                processes one command from program list and adds adds it to the assembler string as an instruction.
                
                :assembler (str): assembler instructions as a string
                :command (dict): current instruction from program_list to add in assembler
                :p_addr (int): program address of the command in memory. // p_addr stands for program address.
                :returns (str): returns the assembler with extra information
            """
            assembler += "RET\n" if (command['CMD']=='RET') else f"     {command['CMD']} "
            if (command['CMD'] == 'DPORT_WR') or (command['CMD']=='WPORT_WR') or (command['CMD']=='TRIG') or (command['CMD']=='DPORT_RD'):
                    assembler += 'p'+command['DST'] + ' '
            elif ('DST' in command):
                assembler += command['DST'] + ' '
            assembler += f"{command['SRC']} "     if ('SRC'      in command) else ''
            assembler += f"{command['DATA']} "    if ('DATA'      in command) else ''
            if ('ADDR' in command):
                if (not 'LABEL' in command):
                    if ( f"&{p_addr-1}" == command['ADDR'] and command['CMD'] == 'JUMP'):
                        assembler += "PREV "
                    elif ( f"&{p_addr}" == command['ADDR'] and command['CMD'] == 'JUMP'):
                        assembler += "HERE "
                    elif ( f"&{p_addr+1}" == command['ADDR'] and command['CMD'] == 'JUMP'):
                        assembler += "NEXT "
                    elif ( f"&{p_addr+2}" == command['ADDR'] and command['CMD'] == 'JUMP'):
                        assembler += "SKIP "
                    else:
                        assembler += f"[{command['ADDR']}] "
            assembler += f"{command['LABEL'] } "     if ('LABEL'    in command) else ''
            assembler += f"-if({command['IF']}) "    if ('IF'       in command) else ''
            assembler += f"-wr({command['WR']}) "    if ('WR'       in command) else ''
            assembler += f"{command['LIT']} "       if ('LIT'      in command) else ''
            assembler += f"-op({command['OP']}) "    if ('OP'       in command) else ''
            assembler += "-uf "      if ('UF' in command and command['UF']=='1') else ''
            assembler += "-ww "                       if ('WW'       in command) else ''
            assembler += f"-wp({command['WP']}) "    if ('WP'       in command) else ''
            assembler += f"p{command['PORT']} "      if ('PORT'     in command) else ''
            assembler += f"{command['TIME']} "      if ('TIME'       in command) else ''


            assembler += f"{command['NUM']} "        if ('NUM'       in command) else ''
            if ('DEN' in command):
                assembler += '#' if (command['DEN'][0] != 'r') else ''
                assembler += f"{command['DEN']} "
            assembler += f"{command['C_OP']} "    if ('C_OP'       in command) else ''
            assembler += f"{command['R1']} "      if ('R1'       in command) else ''
            assembler += f"{command['R2']} "      if ('R2'       in command) else ''
            assembler += f"{command['R3']} "      if ('R3'       in command) else ''
            assembler += f"{command['R4']} "      if ('R4'       in command) else ''

            assembler += '\n'
            return assembler
    
        assembler_code = ''
        key_list = list(label_dict.keys())
        val_list = list(label_dict.values())
        wait_cnt = 0
        for ind, command in enumerate(program_list, start=1):
            # CHECK FOR LABEL IN THAT MEMORY PLACE
            address = command['P_ADDR'] if ('P_ADDR' in command) else (ind+wait_cnt) # set correct instruction address in memory.
            if ( command['CMD'] == 'WAIT'):
                wait_cnt = wait_cnt + 1
            # LABEL in the Correct Line
            PADDR = '&' + str(address)
            if (PADDR in val_list):
                label = key_list[val_list.index(PADDR)]
                if (label[0:2]=='F_' or label[0:2]=='S_' or label[0:2]=='T_'):
                    label = '\n' + label
                assembler_code += label + ':\n'
            # CHECK FOR LABEL SOURCE
            if ('SRC' in command):
                if (command['SRC'] =='label'):
                    ADDR = command['ADDR']
                    if (ADDR in val_list):
                        label = key_list[val_list.index(ADDR)]
                        #command.pop['ADDR']
                        command['LABEL'] = label
            assembler_code = process_command(assembler_code, command, address)

        # ADD Address to commands with LABEL
        for line_number, command in enumerate(program_list):
            if ('LABEL' in command):
                if ( command['LABEL'] in label_dict ) :
                    command['ADDR'] = label_dict[ command['LABEL'] ]
                else:
                    Logger.error('LABEL: ', 'Label ' + command['LABEL'] + ' not recognized')
            command['LINE'] = line_number
        return assembler_code
    
    @staticmethod
    def file_asm2list(filename : str) -> tuple:
        """
            takes in a filename to open it and remove all comments.
            returns it as a list of strings containing each line parsed.
            
            :filename (str): file to open and parse
            :returns (list): list with all lines of the original file stripped except comments (//).
        """
        parsed_file = []
        with open(filename, 'r') as f:
            for line in f.readlines():
                comment = line.find("//")
                if (comment >= 0):
                    line = line[:comment]
                parsed_file.append(line.strip())

        program_list, label_dict = Assembler.get_list(parsed_file)
        return (program_list, label_dict)

    def str_asm2list(asm_str : str) -> tuple:
        x = asm_str.splitlines()
        parsed_asm = []
        for line in x:
            comment = line.find("//")
            if (comment >= 0):
                line = line[:comment]
            parsed_asm.append(line.strip())

        program_list, label_dict = Assembler.get_list(parsed_asm)
        return (program_list, label_dict)
    

    def get_list(asm_str : str) -> tuple:
        """
            process the asm and return the program instructions as a list of dictionaries with the labels.
            :assembler string (asm_str): string with the ASM.
            :returns (tuple): (program_list, label_dict)
            :program_list (list): program instructions as a list of dictionaries.
            :label_dict (dict): dictionary with all labels found plus their memory address in program memory. ({'LABEL': '&0'})
        """
           
        label_line_idxs = []
            
        def label_recognition(file_lines : list) -> tuple:
            """
                gets and returns all labels from file.
                IMPORTANT: This function updates 'Alias_List'.
                
                :file_lines (list): file as a list of strings, each element represents a new line. (should be stripped)
                :returns (tuple): (error, label_dictionary)
                :error (int): if function succeeds error is 0, else it is nonzero.
                :label_dictionary (dict): dictionary with all labels found plus their memory address in program memory. ({'LABEL': '&0'})
            """
            # register 15 predefinition.
            label_dict = { 's15': 's15' }
            error = 0
            mem_addr = 1 # address 0 goes NOP
            # Check if LABEL, DIRETIVE OR INSTRUCTION
            for line_number, command in enumerate(file_lines, start=1):
                if (command):
                    label        = find_pattern(regex['LABEL'], command)
                    directive    = find_pattern(regex['DIRECTIVE'], command)
                    instruction  = find_pattern(regex['CMD'], command)
                    if (label): # add label to label_dict if not already registered.
                        L_Name    = command[:-1]
                        if (check_name(L_Name)):
                            if label in label_dict:
                                error = Logger.error('LABEL_RECOGNITION', 'Label  "' + label + '" already in use as LABEL in line ' + str(line_number) )
                            elif label in Alias_List:
                                 error = Logger.error('LABEL_RECOGNITION', 'Label "' + label + '" already in use as ALIAS in line ' + str(line_number) )
                            else:
                                if (label == 'reg'):
                                    error = Logger.error('LABEL_RECOGNITION', 'reg is not a valid label in line  ' + str(line_number) )
                                else:
                                    label_dict[label] = '&' + str(mem_addr)
                                    label_line_idxs.append(line_number)
                        else:
                            error = Logger.error('LABEL_RECOGNITION', 'Label Name error in line  ' + str(line_number) )
                    elif (directive):  # identify Aliases and adds them to Alias_List.
                        if ( directive == 'ALIAS'):
                            directive_params = list(filter(lambda x:x, command.split(' ')))
                            if (len(directive_params) == 3):
                                A_Name    = directive_params[1]
                                A_Reg     = directive_params[2]
                                if (check_name(A_Name)):
                                    if A_Name in Alias_List:
                                        error = Logger.error('DIRECTIVE_RECOGNITION', 'Alias "' + A_Name  +'" already in use as ALIAS in line ' + str(line_number) )
                                    elif A_Name in label_dict:
                                        error = Logger.error('DIRECTIVE_RECOGNITION', 'Alias "' + A_Name  +'" already in use as LABEL in line ' + str(line_number) )
                                    else:
                                        if ( check_reg(A_Reg) ):
                                            Alias_List.update({ A_Name : A_Reg } )        
                                            Logger.info("ALIAS_RECOGNITION",' > ' + A_Reg + ' is called ' + A_Name)
                                        else:
                                            error = Logger.error('DIRECTIVE_RECOGNITION', 'Register Name error in line ' + str(line_number) )
                                else:
                                    error = Logger.error('DIRECTIVE_RECOGNITION', 'Alias Name Error in line ' + str(line_number) )
                            else:
                                error = Logger.error('DIRECTIVE_RECOGNITION', 'ALIAS Parameters error in line ' + str(line_number) )
                        elif ( directive == 'CONST'):
                            directive_params = list(filter(lambda x:x, command.split(' ')))
                            if (len(directive_params) == 3):
                                C_name    = directive_params[1]
                                C_val    = directive_params[2]
                                if (check_name(C_name)):
                                    if C_name in Alias_List:
                                        error = Logger.error('DIRECTIVE_RECOGNITION', 'Const "' + C_name  +'" already in use as ALIAS in line ' + str(line_number) )
                                    elif C_name in label_dict:
                                        error = Logger.error('DIRECTIVE_RECOGNITION', 'Const "' + C_name  +'" already in use as LABEL in line ' + str(line_number) )
                                    else:
    
                                        error, lit_val = get_imm_dt (C_val, 32, 1)
                                        if (error):
                                            error = Logger.error('DIRECTIVE_RECOGNITION', 'CONST '+C_name+' Value '+C_val+' is not a Literal in line ' + str(line_number) )
                                        else:
                                            Alias_List.update({ C_name : C_val } )        
                                            Logger.info("DIRECTIVE_RECOGNITION",' > ' + C_val + ' is called ' + C_name)
                                else:
                                    error = Logger.error('DIRECTIVE_RECOGNITION', 'Alias Name Error in line ' + str(line_number) )

                            else:
                                error = Logger.error('DIRECTIVE_RECOGNITION', 'CONST Parameters error in line ' + str(line_number) )
    
                        elif ( directive == 'ADDR'):
                            directive_params = list(filter(lambda x:x, command.split(' ')))
                            if (len(directive_params) == 2):
                                if  (check_num(directive_params[1])):
                                    Value    = int(directive_params[1])
                                    distance = Value - mem_addr
                                    if  (distance < 0):
                                        error = Logger.error('DIRECTIVE_RECOGNITION', 'New Memory Address '+str(Value)+ ' before than next empty address ('+str(mem_addr)+') in Line ' + str(line_number))
                                    else :                          
                                        mem_addr = Value
                                else:
                                    error = Logger.error('DIRECTIVE_RECOGNITION', 'Address Value '+ directive_params[1] + ' error in Line ' + str(line_number))
                            else:
                                error = Logger.error('DIRECTIVE_RECOGNITION', 'ADDR Parameters error in line ' + str(line_number) )
                        elif ( directive == 'END'):
                            mem_addr += 1  
                        else:
                            error = Logger.error('DIRECTIVE_RECOGNITION', 'Directive Not Recognized in Line ' + str(line_number))
                    elif (instruction): # Identify instructions to correctly set addresses.
                        if ( instruction in instList.keys() ) :
                            if (instruction == 'WAIT'):
                                mem_addr += 2
                            else:                            
                                mem_addr += 1
                        else:
                            error = Logger.error('CMD_RECOGNITION', 'Command Not Recognized in Line ' + str(line_number))
                    else:
                        error = Logger.error('CMD_RECOGNITION', 'Instruction Not Recognized in Line ' + str(line_number))

            show_info =  ('\n## ALIAS LIST')
            show_info += '\n' + ('###############################')
            show_info += '\n' + ('REG  > ALIAS NAME\n-----|-------------')
            for key in Alias_List:
                show_info += '\n' + str( (f"{Alias_List[key]:<3}" + ' > '+ key) )
            show_info += '\n' + ('###############################')
            Logger.info("ALIAS_RECOGNITION",show_info)
            
            show_info =         ('\n## LABEL LIST ')
            show_info += '\n' + ('###############################')
            show_info += '\n' + ('LABEL NAME       > PMEM ADDRESS\n-----------------|-------------  ')
            for key in label_dict:
                if key != 's15':
                    show_info += '\n' + str( (f"{key:<15}" + ' > ' + label_dict[key]) )
            show_info += '\n' + ('###############################')
            Logger.info("LABEL_RECOGNITION",show_info)
                
            return (error, label_dict)
        
        def command_recognition(file_lines : list, label_dict : dict) -> tuple:
            """
                gets and returns all commands from file.
                IMPORTANT: Uses 'Alias_List', 'Param_List'.
                
                :file_lines (list): file as a list of strings, each element represents a new line. (should be stripped)
                :label_dict (dict): dictionary with all labels found plus their memory address in program memory. ({'LABEL': '&0'}). see ' label_recognition() '
                :returns (tuple): (error, program_list)
                :error (int): if function succeeds error is 0, else it is nonzero.
                :program_list (list): program instructions as a list of dictionaries.
                
            """
            program_list = [{'P_ADDR': 1, 'LINE': 2, 'CMD': 'NOP'}]
            #program_list = []
            error = 0
            mem_addr = 0
            for line_number, command in enumerate(file_lines, start=1):
                command_info = {}
                instruction  = find_pattern(regex['CMD'], command)
                directive    = find_pattern(regex['DIRECTIVE'], command)
                if ((not command) or (line_number in label_line_idxs)):
                    continue
                elif (directive):
                    if ( directive == 'END'):
                        mem_addr += 1            
                        command_info = { 'LINE'     : line_number,
                            'P_ADDR'   : mem_addr,
                            'ADDR'     : F"&{str(mem_addr)}",
                            'CMD'      : 'JUMP' }
                        program_list.append(command_info)
                        Logger.info("COMMAND_RECOGNITION",'END OF PROGRAM ')
                    elif ( directive == 'ADDR'): ## Already Verified on Label Recognition
                        directive_params = list(filter(lambda x:x, command.split(' ')))
                        Value    = int(directive_params[1])
                        distance = Value - mem_addr
                        for ind in range(distance-1):
                            mem_addr += 1
                            command_nop = {}
                            command_nop['P_ADDR'] = mem_addr
                            command_nop['LINE']   = line_number
                            command_nop['CMD']    = 'NOP'
                            program_list.append(command_nop)
                elif (instruction):
                    if ( instruction in instList.keys() ) :
                        mem_addr += 1            
                        command_info['P_ADDR'] = mem_addr
                        # CHECK for Literal Values
                        ###############################################################
                        LIT      = re.findall(regex['LIT'], command)
                        if (LIT and len(LIT) == 2 and LIT[0] != LIT[1]):
                            error = Logger.error('COMMAND_RECOGNITION', 'Literals not equals in Line ' + str(line_number))
                        
                        # CHANGE ALIAS 
                        ###############################################################
                        cmd_words = re.split(' |\(|\)|\[|\]', command)
                        for key in Alias_List:
                            CHANGE = find_pattern(key, command)
                            if (key in cmd_words):
                                command = command.replace(CHANGE, Alias_List[key]) if CHANGE else command
                        
                        # Extract PARAMETERS
                        ###############################################################
                        if (error == 0):
                            command_info['LINE'] = line_number # Stores Line Number for ERROR Messages
                            for key in Param_List:
                                PARAM = re.findall(Param_List[key]['RegEx'], command)
                                if PARAM:
                                    if (len(PARAM) >1):
                                        error = Logger.error('COMMAND_RECOGNITION', 'Duplicated Parameter ' + key +' in line '+str(line_number))
                                    command_info[key] = PARAM[0].strip()
                                    aux  = Param_List[key]['RL'] + PARAM[0] + Param_List[key]['RR']
                                    command = command.replace(aux, '')
                        # COMMANDS PARAMETERS CHECK
                        ###############################################################
                        if (error == 0):
                            CMD_DEST_SOURCE = re.findall(regex['CDS'], command)
                            ## SINGLE PARAMETERS CHECK
                            ###########################################################
                            if ('OP' in command_info):
                                comp_OP_PARAM = "#b(\d+)"
                                param_op = re.findall(comp_OP_PARAM, command_info['OP'])
                                if param_op:
                                    try:
                                        str(int(param_op[0],2))
                                    except ValueError:
                                        error = Logger.error("COMMAND_RECOGNITION", "Binary value incorrect in Line " + str(line_number))
                            if ('LIT' in command_info) :
                                # Remove underscores
                                command_info['LIT'] = command_info['LIT'].replace('_','')
                                # Check if Binary OK
                                if (command_info['LIT'][0] == 'b'):
                                    try:
                                        command_info['LIT'] = str(int(command_info['LIT'][1:],2))
                                    except ValueError:
                                        error = Logger.error("COMMAND_RECOGNITION", "Binary value incorrect in Line " + str(line_number))
                                command_info['LIT'] = '#' + command_info['LIT']
                            ###########################################################
                            if ('TIME' in command_info) :
                                command_info['TIME'] = '@' + command_info['TIME']
                            ###########################################################
                            if ('WW' in command_info) :
                                command_info['WW'] = '1'
                            ###########################################################
                            if ('UF' in command_info) :
                                command_info['UF'] = '1'
                                if not('OP' in command_info):
                                    error = Logger.error("COMMAND_RECOGNITION", "No Operation < -op() > set for Flag Update < -uf > in Line " + str(line_number))

                            ## COMMAND VERIFICATION
                            ###########################################################
                            if (CMD_DEST_SOURCE[0] == 'REG_WR'):
                                if (len(CMD_DEST_SOURCE) > 2):
                                    if (CMD_DEST_SOURCE[1] == 'r_wave'):
                                        if ('TIME' in command_info):
                                            error = Logger.error("COMMAND_RECOGNITION", CMD_DEST_SOURCE[0] + " Instruction is NOT a timed intruction < -@Time > in Line " + str(line_number))
                                    else:
                                        if ('WP' in command_info):
                                            error = Logger.error("COMMAND_RECOGNITION", "Not allowed Write Port < -wp() > in Line " + str(line_number))
                                        if ('WR' in command_info):
                                            error = Logger.error("COMMAND_RECOGNITION", "Not allowed Write Register < -wr() > in Line " + str(line_number))
                                        if ('WW' in command_info):
                                            error = Logger.error("COMMAND_RECOGNITION", "Not allowed Write WaveMemory < -ww() > in Line " + str(line_number))
                                        if ('TIME' in command_info):
                                            error = Logger.error("COMMAND_RECOGNITION", CMD_DEST_SOURCE[0] + " Instruction is NOT a timed intruction < -@Time > in Line " + str(line_number))
                                else:
                                    error = Logger.error("COMMAND_RECOGNITION", CMD_DEST_SOURCE[0] + " Not enough parameters in Line " + str(line_number))


                            if ( (CMD_DEST_SOURCE[0] == 'NOP')  or (CMD_DEST_SOURCE[0] == 'TEST') or (CMD_DEST_SOURCE[0] == 'RET') \
                              or (CMD_DEST_SOURCE[0] == 'TIME') or (CMD_DEST_SOURCE[0] == 'FLAG') or (CMD_DEST_SOURCE[0] == 'ARITH') \
                              or (CMD_DEST_SOURCE[0] == 'DIV')  or (CMD_DEST_SOURCE[0] == 'NET')  or (CMD_DEST_SOURCE[0] == 'COM')  \
                              or (CMD_DEST_SOURCE[0] == 'PA')   or (CMD_DEST_SOURCE[0] == 'PB') ) :
                                if ('WP' in command_info):
                                    error = Logger.error("COMMAND_RECOGNITION", "Not allowed Write Port < -wp() > in Line " + str(line_number))
                                if ('WR' in command_info):
                                    error = Logger.error("COMMAND_RECOGNITION", "Not allowed Write Register < -wr() > in Line " + str(line_number))
                                if ('WW' in command_info):
                                    error = Logger.error("COMMAND_RECOGNITION", "Not allowed Write WaveMemory < -ww() > in Line " + str(line_number))
                                if ('TIME' in command_info):
                                    error = Logger.error("COMMAND_RECOGNITION", CMD_DEST_SOURCE[0] + " Instruction is NOT a timed intruction < -@Time > in Line " + str(line_number))
                            ###########################################################
                            if ( (CMD_DEST_SOURCE[0] == 'JUMP')   or (CMD_DEST_SOURCE[0] == 'CALL') ):
                                if ('WP' in command_info):
                                    error = Logger.error("COMMAND_RECOGNITION", "Not allowed Write Port < -wp() > in Line " + str(line_number))
                                if ('WW' in command_info):
                                    error = Logger.error("COMMAND_RECOGNITION", "Not allowed Write WaveMemory < -ww() > in Line " + str(line_number))
                                if ('TIME' in command_info):
                                    error = Logger.error("COMMAND_RECOGNITION", CMD_DEST_SOURCE[0] + " Instruction is NOT a timed intruction < -@Time > in Line " + str(line_number))


                            elif (CMD_DEST_SOURCE[0] == 'DMEM_WR'):
                                if ('WP' in command_info):
                                    error = Logger.error("COMMAND_RECOGNITION", "Not allowed Write Port < -wp() > in Line " + str(line_number))
                                if ('WW' in command_info):
                                    error = Logger.error("COMMAND_RECOGNITION", "Not allowed Write WaveMemory < -ww() > in Line " + str(line_number))
                                if ('TIME' in command_info):
                                    error = Logger.error("COMMAND_RECOGNITION", "DMEM_WR is NOT a timed intruction < -@Time > in Line " + str(line_number))
                                if ( not('ADDR' in command_info) ):
                                    error = Logger.error("COMMAND_RECOGNITION", "Memory Address < [] > not set in Line " + str(line_number))

                            ###########################################################
                            elif (CMD_DEST_SOURCE[0] == 'WMEM_WR'):
                                if ('TIME' in command_info) :
                                    if ('WR' in command_info) :
                                        error = Logger.error("COMMAND_RECOGNITION", "Not allowed SDI with Literal Time in Line " + str(line_number))
                                    if ('OP' in command_info) :
                                        error = Logger.error("COMMAND_RECOGNITION", "Not allowed ALU Operation Operation with Literal Time in Line " + str(line_number))
                                if ( ('WP' in command_info) and not('PORT' in command_info) ):
                                    error = Logger.error("COMMAND_RECOGNITION", "No Port Address < -p() > in Line " + str(line_number))
                            ###########################################################
                            elif (CMD_DEST_SOURCE[0] =='DPORT_WR') or (CMD_DEST_SOURCE[0] =='WPORT_WR') \
                            or (CMD_DEST_SOURCE[0] =='TRIG') :
                                if ( not('PORT' in command_info) ):
                                    error = Logger.error("COMMAND_RECOGNITION", "No port in PORT_WR Instruction in line " + str(line_number))


                        # GET COMMAND DESTINATION SOURCE
                        ###############################################################
                        if (error == 0):
                            CMD_DEST_SOURCE = re.findall(regex['CDS'], command)
                            command_info['CMD'] = CMD_DEST_SOURCE[0]
                            ###############################################################################
                            ## MORE THAN ONE SOURCE
                            if ( len(CMD_DEST_SOURCE) > 3) :
                                if  (CMD_DEST_SOURCE[0] == 'ARITH'  or CMD_DEST_SOURCE[0] =='NET') \
                                 or (CMD_DEST_SOURCE[0] =='PA' or CMD_DEST_SOURCE[0] =='PB') :
                                    command_info['C_OP']  = CMD_DEST_SOURCE[1]
                                    command_info['R1']    = CMD_DEST_SOURCE[2]
                                    command_info['R2']    = CMD_DEST_SOURCE[3]
                                    if ( len(CMD_DEST_SOURCE) > 4) :
                                        command_info['R3'] = CMD_DEST_SOURCE[4]
                                    if ( len(CMD_DEST_SOURCE) > 5) :
                                        command_info['R4'] = CMD_DEST_SOURCE[5]
                                        if  (CMD_DEST_SOURCE[0] == 'NET') :
                                            error = Logger.error('COMMAND_RECOGNITION', 'NET command max 3 Registers in line ' + str(line_number) )
                                    if ( len(CMD_DEST_SOURCE) > 6) :
                                        error = Logger.error('COMMAND_RECOGNITION', CMD_DEST_SOURCE[0]+' Command max 4 Registers in line ' + str(line_number) )
                                
                                elif (CMD_DEST_SOURCE[0] == 'REG_WR') and (CMD_DEST_SOURCE[2] == 'label' ) :
                                    command_info['DST'] = CMD_DEST_SOURCE[1]
                                    command_info['SRC'] = CMD_DEST_SOURCE[2]
                                    if (CMD_DEST_SOURCE[3] in label_dict ) :
                                        command_info['ADDR'] = label_dict[CMD_DEST_SOURCE[3]]
                                        error = Logger.info('COMMAND_RECOGNITION', 'REG_WR command source label: '+CMD_DEST_SOURCE[3] +' replaced by value ' + command_info['ADDR'] + '  in line ' + str(line_number))
                                    else:
                                        error = Logger.error('COMMAND_RECOGNITION', 'Label: '+CMD_DEST_SOURCE[3]+' Not defined in line ' + str(line_number))
                                else:
                                    error = Logger.error("COMMAND_RECOGNITION", "[>3] Parameter Error in line " + str(line_number) )
                                    
                            ###############################################################################
                            ## ONLY ONE SOURCE / DEST
                            elif ( len(CMD_DEST_SOURCE) == 3) :
                                if (CMD_DEST_SOURCE[0] == 'REG_WR'):
                                   if (CMD_DEST_SOURCE[2] == 'label' ) :
                                        error = Logger.error("COMMAND_RECOGNITION", "Missing label in line " + str(line_number))
                                   else:
                                       command_info['DST'] = CMD_DEST_SOURCE[1]
                                       command_info['SRC'] = CMD_DEST_SOURCE[2]        
                                elif (CMD_DEST_SOURCE[0] =='DPORT_WR' ) :
                                    if ( int(command_info['PORT'])  > 3):
                                        error = Logger.error("COMMAND_RECOGNITION", "Data Port MAX port number is p3 in line " + str(line_number))
                                    else:
                                        command_info['DST'] = command_info['PORT']
                                        command_info.pop('PORT') 
                                    command_info['SRC'] = CMD_DEST_SOURCE[1]
                                    command_info['DATA'] = CMD_DEST_SOURCE[2]        
                                elif (CMD_DEST_SOURCE[0] =='COM' or CMD_DEST_SOURCE[0] == 'TIME' or CMD_DEST_SOURCE[0] == 'NET') \
                                 or (CMD_DEST_SOURCE[0] =='PA' or CMD_DEST_SOURCE[0] =='PB') :
                                    command_info['C_OP'] = CMD_DEST_SOURCE[1]     
                                    command_info['R1'] = CMD_DEST_SOURCE[2]     
                                elif (CMD_DEST_SOURCE[0] == 'DIV') :
                                    command_info['NUM'] = CMD_DEST_SOURCE[1]
                                    command_info['DEN'] = CMD_DEST_SOURCE[2]        
                                else:
                                    error = Logger.error("COMMAND_RECOGNITION", "[3] Parameter Error in line " + str(line_number) )
                            ###############################################################################
                            ## NO SOURCE OR -- SOURCE IN EXTRACTED PARAMETER
                            elif ( len(CMD_DEST_SOURCE) == 2) :
                                if (CMD_DEST_SOURCE[0] =='DMEM_WR' ) :
                                    command_info['SRC'] = CMD_DEST_SOURCE[1]     
                                    command_info['DST'] = '[' + command_info['ADDR'] + ']'     
                                    command_info.pop('ADDR')     
                                elif (CMD_DEST_SOURCE[0] =='TRIG'):
                                    command_info['SRC'] = CMD_DEST_SOURCE[1]
                                    if ( int(command_info['PORT'])  > 31):
                                        error = Logger.error("COMMAND_RECOGNITION", "Trigger Port max por number is p31 in line " + str(line_number))
                                    else:
                                        command_info['DST'] = command_info['PORT']
                                        command_info.pop('PORT') 
                                elif (CMD_DEST_SOURCE[0] =='WPORT_WR'):
                                    command_info['SRC'] = CMD_DEST_SOURCE[1]
                                    if ( int(command_info['PORT'])  > 15):
                                        error = Logger.error("COMMAND_RECOGNITION", "Wave Port Port max value is 15 in line " + str(line_number))
                                    else:
                                        command_info['DST'] = command_info['PORT']
                                        command_info.pop('PORT') 
                                elif (CMD_DEST_SOURCE[0] =='FLAG' or CMD_DEST_SOURCE[0] =='NET' or CMD_DEST_SOURCE[0] =='COM') \
                                    or (CMD_DEST_SOURCE[0] =='PA' or CMD_DEST_SOURCE[0] =='PB') :
                                    command_info['C_OP'] = CMD_DEST_SOURCE[1]     
                                elif (CMD_DEST_SOURCE[0]=='TIME'): # DST is ADDR
                                        command_info['C_OP'] = CMD_DEST_SOURCE[1]     
                                elif (CMD_DEST_SOURCE[0]=='DIV'): 
                                    if ('LIT' in command_info):
                                        command_info['NUM'] = CMD_DEST_SOURCE[1]     
                                        command_info['DEN'] = command_info['LIT']
                                    else:
                                        error = Logger.error("COMMAND_RECOGNITION", "Dividend Parameter Error in line " + str(line_number))
                                elif (CMD_DEST_SOURCE[0]=='JUMP' or CMD_DEST_SOURCE[0]=='CALL'):
                                    if CMD_DEST_SOURCE[1]  in label_dict:
                                        if (CMD_DEST_SOURCE[1]  == 's15'):
                                            Logger.info("COMMAND_RECOGNITION", "BRANCH to r_addr  > line " + str(line_number))
                                        else:
                                            Logger.info("COMMAND_RECOGNITION", "BRANCH to label : " + CMD_DEST_SOURCE[1] + " is done to address " + label_dict[CMD_DEST_SOURCE[1]] + "  > line " + str(line_number))
                                        command_info['ADDR'] = label_dict[CMD_DEST_SOURCE[1]]
                                        command_info['LABEL'] = CMD_DEST_SOURCE[1]
                                    else:
                                        if (CMD_DEST_SOURCE[1] == 'PREV'):
                                            command_info['ADDR'] = '&'+str(mem_addr-1)
                                        elif  (CMD_DEST_SOURCE[1] == 'HERE'):
                                            command_info['ADDR'] = '&'+str(mem_addr)
                                        elif (CMD_DEST_SOURCE[1] == 'NEXT'):
                                            command_info['ADDR'] = '&'+str(mem_addr+1)
                                        elif (CMD_DEST_SOURCE[1] == 'SKIP'):
                                            command_info['ADDR'] = '&'+str(mem_addr+2)
                                        else:   
                                            error = Logger.error("COMMAND_RECOGNITION", "Branch Address ERROR (Should be a label) in line " + str(line_number))
                                elif (CMD_DEST_SOURCE[0]=='WAIT'):
                                    Logger.info("COMMAND_RECOGNITION", "WAIT adding Instruction")
                                    command_info['C_OP'] = CMD_DEST_SOURCE[1]     
                                    command_info['P_ADDR'] = mem_addr

                                    mem_addr = mem_addr + 1            
                                elif (CMD_DEST_SOURCE[0]=='CLEAR'):
                                    command_info['C_OP'] = CMD_DEST_SOURCE[1]     
                                    Logger.info("COMMAND_RECOGNITION", "CLEAR Instruction")
                                    command_info['P_ADDR'] = mem_addr

                                else:
                                    error = Logger.error("COMMAND_RECOGNITION", "[2] Parameter Error in line " + str(line_number))
                            ###############################################################################
                            ## NO DESTINATION OR -- DESTINATION / SOURCE IN EXTRACTED PARAMETER
                            elif ( len(CMD_DEST_SOURCE) ==1 ):
                                if (CMD_DEST_SOURCE[0] =='NOP')       \
                                or (CMD_DEST_SOURCE[0] =='ARITH')     \
                                or (CMD_DEST_SOURCE[0] =='TEST')      \
                                or (CMD_DEST_SOURCE[0] =='RET')       :
                                    error = 0 
                                elif (CMD_DEST_SOURCE[0] =='DPORT_RD') :
                                    if ('PORT' in command_info):
                                        if ( int(command_info['PORT'])  > 7):
                                            error = Logger.error("COMMAND_RECOGNITION", "Data Port Read max value is 7 in line " + str(line_number))
                                        else:
                                            command_info['DST'] = command_info['PORT']
                                            command_info.pop('PORT') 
                                    else:
                                        error = Logger.error("COMMAND_RECOGNITION", "No Port for DPORT_RD in line " + str(line_number))

                                elif (CMD_DEST_SOURCE[0]=='WMEM_WR'):
                                    if ('ADDR' in command_info):
                                        command_info['DST'] = '[' + command_info['ADDR'] + ']'     
                                        command_info.pop('ADDR') 
                                    else:
                                        error = Logger.error("COMMAND_RECOGNITION", "No Address for WMEM_WR in line " + str(line_number))
                                elif ( (CMD_DEST_SOURCE[0]=='JUMP') or (CMD_DEST_SOURCE[0]=='CALL')):
                                    if ('ADDR' in command_info):
                                        command_info['ADDR'] = command_info['ADDR']
                                    else:
                                        error = Logger.error("COMMAND_RECOGNITION", "Address Parameter Error in line " + str(line_number))
                                else:
                                    error = Logger.error("COMMAND_RECOGNITION", "[1] Parameter Error in line " + str(line_number))
                            else:
                                error = Logger.error("COMMAND_RECOGNITION", "Error Processing Line " + str(line_number)) + ". Command not recognized."

                            # ADD CMD TO PROGRAM
                            ###########################################################
                            if (error == 1):
                                break
                            else:
                                program_list.append(command_info)
                        else:
                            break
                    else:
                        error = Logger.error("COMMAND_RECOGNITION", f"< {instruction} > is not a Recognized Command in Line " + str(line_number))
                else:
                    error = Logger.error("COMMAND_RECOGNITION", "Not a Command in Line " + str(line_number))
            return (error, program_list)
        
        
        ##### START ASSEMBLER TO LIST
        Logger.info("ASM2LIST", "##### STEP_1 - LABEL RECOGNITION")
        error, label_dict = label_recognition(asm_str)
        
        if (error):
            Logger.warning('LABEL_RECOGNITION', 'Error found ')
            return (None, None)
        
        Logger.info("ASM2LIST", "##### STEP_2 - COMMAND RECOGNITION")
        error, program_list = command_recognition(asm_str, label_dict)
            
        if (error):
            Logger.warning("COMMAND_RECOGNITION", "Errors found!")
            return (None, None)
        
        return (program_list, label_dict)
    
    @staticmethod
    def list2bin(program_list : list, label_dict : dict = {}, save_unparsed_filename : str = "") -> list:
        """
            translates a program list to binary form.
            :program_list (list): each element is a dictionary with all the commands and instructions. see ' asm2list() '
            :label_dict (dict): dictionary with label information only if program_list contains labels.
            :save_unparsed_filename (str): if not null, opens this file and saves unparsed binary ('_' not removed).
            :returns (tuple): (error, binary_program)
            :error (int):  if function succeeds error is 0, else it is nonzero.
            :binary_program_list (list): each element is a string with 0s and 1s representing the binary program
        """
        def parse_lines_and_labels(program_list : list, label_dict : dict) -> None:
            for line_number, command in enumerate(program_list, start=1):
                if (('LABEL' in command) and (command['LABEL'] in label_dict) and 'ADDR' not in command):
                    command['ADDR'] = label_dict[ command['LABEL'] ]
                if not 'LINE' in command:
                    command['LINE'] = line_number

        Logger.info("LIST2BIN", "##### LIST 2 BIN")

        parse_lines_and_labels(program_list, label_dict)
        
        # first line is NOP
        #binary_program_list = ['000_000__000__0_0_0_00_00___00000___000000__000000____0_0000000__0_0000000__0000000000000000__0000000']
        binary_program_list = []
        error = 0
        CODE = 'x'
        for command in program_list:
            if ('CMD' in command):
                if not ('UF' in command):
                    command['UF'] = '0'
            ###############################################################################
                if command['CMD'] == 'NOP':
                    CODE = '000_000__000__0_0_0_00_00___00000___000000__000000____0_0000000__0_0000000__0000000000000000__0000000'
            ###############################################################################
                elif command['CMD'] == 'TEST':
                    command['UF'] = '1'
                    error, CODE = Instruction.CFG(command)
            ###############################################################################
                elif (command['CMD'] == 'REG_WR'):
                    error, CODE = Instruction.REG_WR(command)
            ###############################################################################
                elif command['CMD'] == 'DMEM_WR':
                    error, CODE = Instruction.DMEM_WR(command)
            ###############################################################################
                elif command['CMD'] == 'WMEM_WR':
                    error, CODE = Instruction.WMEM_WR(command)
            ###############################################################################
                elif command['CMD']=='TRIG':
                    error, CODE = Instruction.PORT_WR(command)
            ###############################################################################
                elif command['CMD']=='DPORT_WR' or command['CMD'] == 'DPORT_RD' or command['CMD'] == 'WPORT_WR':
                    error, CODE = Instruction.PORT_WR(command)
            ###############################################################################
                elif command['CMD'] == 'JUMP':
                    error, CODE = Instruction.BRANCH(command, '00')
            ###############################################################################
                elif command['CMD'] == 'CALL':
                    error, CODE = Instruction.BRANCH(command, '10')
            ###############################################################################
                elif command['CMD'] == 'RET':
                    error, CODE = Instruction.BRANCH(command, '11')
            ###############################################################################
                elif command['CMD'] == 'TIME' or command['CMD'] == 'FLAG' or command['CMD'] == 'DIV' :
                    error, CODE = Instruction.CTRL(command)
            ###############################################################################
                elif command['CMD'] == 'NET' or command['CMD'] == 'COM':
                    error, CODE = Instruction.CTRL(command)
            ###############################################################################
                elif command['CMD'] == 'PA' or command['CMD'] == 'PB':
                    error, CODE = Instruction.CTRL(command)
            ###############################################################################
                elif command['CMD'] == 'ARITH':
                    error, CODE = Instruction.ARITH(command)
            ###############################################################################
                elif command['CMD'] == 'CLEAR':
                    error, CODE = Instruction.CLEAR(command)
            ###############################################################################
                elif command['CMD'] == 'WAIT':
                    error, CODE = Instruction.WAIT(command)
                else:
                    error = Logger.error("COMMAND_TRANSLATION", "Command Listed but not programmed > " + command['CMD'])
            else:    
                error = Logger.error("COMMAND_TRANSLATION", "No Command at line " + str(command['LINE']))
        ###################################################################################
            length = CODE.count('0') + CODE.count('1')
            if (length != 72):
                if (command['CMD'] == 'WAIT'):
                    Logger.info('COMMAND_TRANSLATION', 'Command Wait add one more instruction ' + str(command['LINE']) )
                else:
                    error = 72
                    Logger.error("COMMAND_TRANSLATION", f"{CODE}\nINSTRUCTION LENGTH > {length} at line {command['LINE']}")
                    return [[],[]]
            if (error):
                return [[],[]]
            if (command['CMD'] == 'WAIT'):
                binary_program_list.extend(CODE)
            else:
                CODE = CODE + ' //' + command['CMD']
                binary_program_list.append(CODE)
                
        if (save_unparsed_filename):
            with open(save_unparsed_filename, "w+") as f:
                for line in binary_program_list:
                    f.write(f"{line}\n")
        
        binary_array = []
        for line_bin in binary_program_list:
            tmp = line_bin.replace('_', '')
            b0 = '0b'+tmp[40:72]
            n0 = int(b0,2)
            b1 = '0b'+ tmp[8:40]
            n1 = int(b1,2)
            b2 = '0b'+tmp[:8]
            n2 = int(b2,2)
            binary_line = [n0, n1, n2, 0, 0, 0, 0, 0]
            binary_array.append(binary_line)
        return binary_program_list, binary_array

    def file_asm2bin(filename : str, save_unparsed_filename : str = "") -> list:
        """  opens file with assembler and returns the binary
        
        :filename (str): file containing ASM.
        :save_unparsed_filename (str): if not null, opens this file and saves unparsed binary ('_' not removed).
        
        """
        program_list, label_dict = Assembler.file_asm2list(filename)
        if program_list:
            binary_program_list = Assembler.list2bin(program_list, save_unparsed_filename)
            if binary_program_list == []:
                binary_program_list = [[],[]]
        else:
            binary_program_list = [[],[]]
            Logger.error("ASM2BIN", "Program list with errors.")
        
        return binary_program_list
    def str_asm2bin(str_asm : str, save_unparsed_filename : str = "") -> list:
        """  get STR with assembler and returns the binary
        
        :asm_str (str): string ASM.
        :save_unparsed_filename (str): if not null, opens this file and saves unparsed binary ('_' not removed).
        
        """
        program_list, label_dict = Assembler.str_asm2list(str_asm)
        if program_list:
            binary_program_list = Assembler.list2bin(program_list, save_unparsed_filename)
        else:
            binary_program_list = [[],[]]
            Logger.error("ASM2BIN", "Program list with errors.")
        return binary_program_list
###############################################################################
## BASIC COMANDS
###############################################################################
class Instruction():
    #PROCESSING
    @staticmethod
    def __PROCESS_CONDITION(command : dict) -> tuple:
        error = 0
        cond = ''
        if ('IF' in command ):
            if command['IF'] in condList:
                cond = condList[command['IF']]
            else:
                error = Logger.error('Parameter.IF', 'Posible CONDITIONS are (' + ', '.join(list(condList.keys())) + ') in instruction ' + str(command['LINE']) )
        else: 
            cond = '000'
        return error, cond

    @staticmethod
    def __PROCESS_WR(command : dict) -> tuple:    #### Get WR 
        error = 0
        RD    = '0000000'
        Rdi=Wr  = '0'
        if ('WR' in command ):
            Wr = '1'
            regex_inside_parenthesis = r'\s*([\w]+)'
            DEST_SOURCE = re.findall(regex_inside_parenthesis, command['WR'])
            #### SOURCE
            if (len(DEST_SOURCE) == 2):
                if (DEST_SOURCE[1] == 'op'):
                    if ('OP' in command ):
                        Rdi    = '0'
                    else:
                        error = Logger.error('Parameter.WR', 'Operation < -op() > option not found in instruction ' + str(command['LINE']) )
                elif (DEST_SOURCE[1] == 'imm'):
                    if ('LIT' in command ):
                        Rdi    = '1'
                    else:
                        error = Logger.error('Parameter.WR', 'Literal Value not found in instruction ' + str(command['LINE']) )
                else:
                    error = Logger.error('Parameter.WR', 'Posible Source Dest for <-wr(reg source)> are (op, imm) in instruction ' + str(command['LINE']) )
            else:
                error = Logger.error('Parameter.WR', 'Write Register error <-wr(reg source) in instruction ' + str(command['LINE']) )
            #### DESTINATION REGISTER
            if (error==0):
                error, RD = get_reg_addr (DEST_SOURCE [0], 'Dest')
        return error, Wr, Rdi, RD

    @staticmethod
    def __PROCESS_WP (command : dict) -> tuple:
        #### WRITE PORT
        error=0
        Wp=Sp='0'
        Dp='000000'
        if ('WP' in command ):
            #### DESTINATION PORT
            if ('PORT' in command):
                Wp='1'
                Dp = integer2bin(command['PORT'], 6)
                if (command['WP'] == 'r_wave'):
                    Sp = '1'
                elif (command['WP'] == 'wmem'):
                    Sp = '0'
                else:
                    error = Logger.error('Parameter.WP', 'Source Wave Port not recognized (wreg, r_wave) ' + str(command['LINE']) )
            else:
                error = Logger.error('Parameter.WP', 'Port Address not recognized < pX > ' + str(command['LINE']) )
        return error, Wp, Sp, Dp

    @staticmethod        
    def __PROCESS_SOURCE (command : dict) -> tuple:
        error = 0
        df = alu_op = 'X'
        rsD0 = rsD1 = DataImm =''
        FULL = (command['CMD']=='REG_WR') and (command['SRC']=='op')
        if ('OP' in command):
            cmd_op        = command['OP'].split()
            if (len(cmd_op)==1 ) : # Operation is COPY REG (Add Zero)
                #print('LEN 1')
                error, src_type = get_src_type(cmd_op[0])
                #print('src_type[0] > ', src_type )
                df          = '01'
                rsD1         = '0_0000000'
                if FULL:                    alu_op  = '0000' # REG_WR rd op -op(rs)
                else:                       alu_op  = '00'   # -wr(rd op) -op(rs)
                if (error==0):
                    if ('LIT' in command):      error, DataImm = get_imm_dt (command ['LIT'], 16)
                    else:                       DataImm = '_0000000000000000'
                if (error==0):
                    if   (src_type[0]=='R'):    error, rsD0    = get_reg_addr(cmd_op[0], 'src_data')
                    else:                       error = Logger.error('Parameter.SRC', 'Operand can not be a Literal.')
            
            elif (len(cmd_op)==2 ) :
                #print('LEN 2 >',cmd_op)
                operation = cmd_op[0]
                error, src_type = get_src_type(cmd_op[1])
                #print('src_type[1] > ', src_type)
                if (FULL):
                    if (operation in aluList_op) : #ALU LIST ONE PARAMETER
                        df          = '10'
                        alu_op      = aluList[operation]
                        DataImm     = '__000000000000000000000000'
                        if   (src_type[0]=='R'): 
                            error, rsD0    = get_reg_addr(cmd_op[1], 'src_data')
                        else:                    
                            error = Logger.error('Parameter.SRC', 'Operand can not be a Literal.')
                    else:
                        error = Logger.error('Parameter.SRC', 'Operation Not Recognized > ' + str(command['OP']) )
                    ## ABS Should be on rsD1
                    if (error==0):
                        if (operation == 'ABS') :
                            df        = '01'
                            rsD1      = rsD0
                            rsD0      = '0_0000000'
                            DataImm   = '_0000000000000000'
                    else:
                        error = Logger.error('Parameter.SRC', '1-Operation Not Allowed > ' + str(command['OP']) +' in instruction ' + str(command['LINE']) ) 
                else:
                    error = Logger.error('Parameter.SRC', '1-FULL Operation Not Allowed > ' + str(command['OP']) +' in instruction ' + str(command['LINE']) ) 

            elif (len(cmd_op)==3 ) :
                #print('LEN 3 >',cmd_op)
                ## CHECK FOR FIRST OPERAND (ALU_IN_A > rsD0)
                error, src_type = get_src_type(cmd_op[0])
                #print('First Operand >',src_type, cmd_op[0])
                if   (src_type[0]=='R'): 
                    error, rsD0    = get_reg_addr(cmd_op[0], 'src_data')
                else:                    
                    error = Logger.error('Parameter.SRC', 'First Operand can not be a Literal.')
                ## CHECK FOR SECOND OPERAND (ALU_IN_B > Imm|rsD1)
                if (error==0):
                    error, src_type = get_src_type(cmd_op[2])
                    #print('Second Operand >',src_type, cmd_op[2])
                    if   (src_type[0]=='R'): ## REG OP REG
                        df             = '01'
                        error, rsD1    = get_reg_addr(cmd_op[2], 'src_data')
                        ## Literal for Second Data Task -wr(rd imm)
                        if ('LIT' in command):
                                error, DataImm = get_imm_dt (command['LIT'], 16)
                        else:
                            DataImm = '_0000000000000000'
                    elif (src_type[0]=='N'): ## is Number
                        error, DataImm = get_imm_dt (cmd_op[2], 24)
                        if (error): 
                            error = Logger.error('Parameter.SRC', 'Literal Value error in instruction ' + str(command['LINE']) ) 
                        else:
                            if ( (cmd_op[1] == 'SR') or (cmd_op[1] == 'SL') or (cmd_op[1] == 'ASR') ):
                                error, lit_val = get_imm_dt (cmd_op[2], 24, 1)
                                if (error == 0 ): 
                                    if (lit_val > 15): 
                                        error = Logger.error('Parameter.SRC', 'Max Shift is 15 in instruction ' + str(command['LINE']) ) 
                                else:
                                    error = Logger.error('Parameter.SRC', 'Literal Value error in instruction ' + str(command['LINE']) ) 
                        if (error == 0 ): 
                            df             = '10'
                            DataImm  = '_'+DataImm 

                ## CHECK FOR OPERATION
                if (error==0):
                    operation = cmd_op[1]
                    if (FULL):
                        if operation in aluList:
                            alu_op      = aluList[ operation ]
                        else:
                            error = Logger.error('Parameter.SRC', 'ALU {Full List} Operation Not Recognized in instruction ' + str(command['LINE']) )
                    else:
                        if operation in aluList_s:
                            alu_op      = aluList_s[ operation ]
                        else:
                            error = Logger.error('Parameter.SRC', 'ALU {Reduced List} Operation Not Recognized in instruction ' + str(command['LINE']) )
        ## LITERAL and NO OP
        elif ('LIT' in command): 
            df = '11'
            alu_op  = '00'
            error, DataImm = get_imm_dt (command['LIT'], 32)
            if (error==0):
                DataImm  = '__'+DataImm 
        else:
            df      = '11'
            alu_op  = '00'
            DataImm = '___00000000000000000000000000000000'
        
        if (error==0):
            Data_Source = rsD0 +'__'+ rsD1 +'_'+ DataImm
            return error, Data_Source, alu_op, df
        else:
            error = Logger.error('Parameter.SRC', 'Error in line ' + str(command['LINE']) )
            return error, 'X', 'X', 'X'
    @staticmethod
    def __PROCESS_MEM_ADDR (ADDR_CMD : str) -> tuple:
        error = 0
        AI = '0'
        rsA0 = rsA1 = 'x'
        comp_ADDR_FMT = "s(\d+)|r(\d+)|&(\d+)|\s*([A-Z]{3}|[A-Z]{2}|\+|\-)"
        param_op  = re.findall(comp_ADDR_FMT, ADDR_CMD)
        if (len(param_op)==1 ) :
            ## CHECK FOR OPERAND
            rsA1     = '000000' # Register ZERO
            if (param_op[0][0]): ## is SREG
                rsA0     = '00000___0' + integer2bin(param_op[0][0], 5)     
            elif (param_op[0][1]): ## is DREG
                rsA0     = '00000___1' + integer2bin(param_op[0][1], 5)     
            elif (param_op[0][2]): ## is Literal
                rsA0     = '___'+ integer2bin(param_op[0][2], 11)
                AI = '1'
            else:
                error = Logger.error('Parameter.MEM_ADDR', 'First Operand not recognized.')
        elif (len(param_op)==3 ) :
            ## CHECK FOR FIRST OPERAND
            if (param_op[0][0]): ## is SREG
                rsA1     = '0'+integer2bin(param_op[0][0], 5)     
            elif (param_op[0][1]): ## is DREG
                rsA1     = '1' + integer2bin(param_op[0][1], 5)     
            elif (param_op[0][2]): ## is Literal
                error = Logger.error('Parameter.MEM_ADDR', 'First Operand can not be a Literal.')    
            ## CHECK FOR SECOND OPERAND 
            if (error == 0):
                if (param_op[2][0]): ## is SREG
                    rsA0     = '00000___0' + integer2bin(param_op[2][0], 5)     
                elif (param_op[2][1]): ## is DREG
                    rsA0     = '00000___1' + integer2bin(param_op[2][1], 5)     
                elif (param_op[2][2]): ## is Literal
                    rsA0     = '___'+ integer2bin(param_op[2][2], 11)     
                    AI = '1'
            ## CHECK FOR PLUS
            if (error == 0):
                if (param_op[1][3]) != '+': ## is R_Reg
                    error = Logger.error('Parameter.MEM_ADDR', 'Address Operand should be < + >.')    
        else:
            print(ADDR_CMD)
            error = Logger.error('Parameter.MEM_ADDR', 'Address format error, should be Data Register(r) or Literal(&)')
        return error, rsA0, rsA1, AI


    #INSTRUCTIONS
    @staticmethod
    def REG_WR (current : dict) -> tuple:
        AI = '0'
        error   = 0
        RdP = '000000'
        ######### CONDITIONAL
        error, COND = Instruction.__PROCESS_CONDITION(current)
        ######### SOURCES
        if (error==0):
            #### SOURCE ALU
            if (current ['SRC'] == 'op'):
                if ('OP' in current ):
                    error, DATA, alu_op, DF = Instruction.__PROCESS_SOURCE (current)
                    CFG   = '00__' + current ['UF'] + '__'+ alu_op 
                    ADDR  = '___00000000000__000000' # 17 Bits 11 + 6
                else:
                    error = Logger.error('Instruction.REG_WR', 'No < -op() > for Operation Writting in instruction ' + str(current['LINE']))
            #### SOURCE IMM
            elif (current ['SRC'] == 'imm'):
                #### Get Data Source
                if ('LIT' in current ):
                    error, DATA, alu_op, DF = Instruction.__PROCESS_SOURCE(current)
                    CFG = '11__' + current ['UF'] + '_00_' + alu_op
                    ADDR  = '___00000000000__000000' # 17 Bits 11 + 6
                else:
                    error = Logger.error('Instruction.REG_WR', 'No Literal value for immediate Assignation (#) in instruction ' + str(current['LINE']) )
            #### SOURCE LABEL
            elif (current ['SRC'] == 'label'):
                #### Get Data Source
                if ('ADDR' in current):
                    comp_addr = "&(\d+)"
                    address = re.findall(comp_addr, current['ADDR'])
                    current['LIT'] = current['ADDR']
                    if (address[0]): # LITERAL
                        error, DATA, alu_op, DF = Instruction.__PROCESS_SOURCE(current)
                        ADDR  = '___00000000000__000000' # 17 Bits 11 + 6
                        CFG = '11__' + current ['UF'] + '_00_00'
                    else:
                        error = Logger.error('Instruction.REG_WR', 'Address error in line ' + str(current['LINE']) )
                else:
                    error = Logger.error('Instruction.REG_WR', 'Address error in line ' + str(current['LINE']) )
            #### SOURCE DATA MEMORY
            elif (current ['SRC'] == 'dmem'):
                #### Get Data Source
                error, DATA, alu_op, DF = Instruction.__PROCESS_SOURCE(current)
                CFG = '01__' + current ['UF'] + '_00_' + alu_op
                #### Get ADDRESS
                if error == 0:
                    if ('ADDR' in current):
                        error, rsA0, rsA1, AI = Instruction.__PROCESS_MEM_ADDR (current ['ADDR'])
                        ADDR  = rsA0 + '__' + rsA1
                        CFG = '01__' + current ['UF'] + '_00_'+alu_op
                    else:
                        error = Logger.error('Instruction.REG_WR', 'No Address for dmem in line ' + str(current['LINE']) )
            #### SOURCE WAVE MEM
            elif (current ['SRC'] == 'wmem'):
                    if (COND != '000'):
                        error = Logger.error('Instruction.REG_WR', 'Wave Register Write is not conditional < -if() >  in instruction ' + str(current['LINE']) )
                    else:
                        WW = WP = '0'
                        if ('WW' in current):
                            WW = '1'
                        #### WRITE PORT
                        error, WP, Sp, RdP = Instruction.__PROCESS_WP(current)
                        COND = WW + Sp + WP    
                    #### WRITE REGISTER
                    if (error==0):
                        Wr = Rdi = '0'
                        error, Wr, Rdi, RD = Instruction.__PROCESS_WR(current)
                    #### Get Data Source
                    if (error==0):
                        error, DATA, alu_op, DF = Instruction.__PROCESS_SOURCE(current)
                    #### Get ADDRESS
                    if error == 0:
                        if ('ADDR' in current):
                            error, rsA0, rsA1, AI = Instruction.__PROCESS_MEM_ADDR (current ['ADDR'])
                            if (rsA1 != '000000'):
                                error = Logger.error('Instruction.REG_WR', 'Wave Memory Addres Error Source Should be LIT or Reg in instruction ' + str(current['LINE']) )                    
                            ADDR  = rsA0 + '__' + RdP
                        else:
                            error = Logger.error('Instruction.REG_WR', 'No addres for <wmem> source in instruction ' + str(current['LINE']) )
            else:
                error = Logger.error('Instruction.REG_WR', 'Posible REG_WR sources are (op, imm, dmem, wmem, label ) in instruction ' + str(current['LINE']) )

            ######### DESTINATION REGISTER
            if (error==0):
                if (current ['SRC'] == 'wmem'):
                    if (current ['DST'] != 'w0'):
                        Wr = Rdi = '0'
                        error, Wr, Rdi, RD = Instruction.__PROCESS_WR(current)
                        CFG = '10__' + current ['UF'] +'_'+ Wr + Rdi +'_'+ alu_op
                    
                    else:
                        error = Logger.error('Instruction.REG_WR', 'Wave Memory Source Should have a Wave Register <r_wave> Destination ' + str(current['LINE']) )
                elif ( (current ['SRC'] == 'label') and () ):
                    if (RD!='15'):
                        error = Logger.warning('Instruction.REG_WR', 'Register used to BRANCH should be s15 in instruction ' + str(current['LINE']) )
                else:
                    comp_OP_PARAM = "^s(\d+)|^r(\d+)|^w(\d+)|(r_wave)"
                    RD    = re.findall(comp_OP_PARAM, current ['DST'])
                    if (RD):
                        error, RD = get_reg_addr (current ['DST'], 'Dest')
                    else:
                        error = Logger.error('Instruction.REG_WR', 'Destination Register '+current ['DST']+' not Recognized in instruction ' + str(current['LINE']) )
        if (error==0):
            CODE  = '100_' + AI + DF +'__'+ COND +'__'+ CFG +'___'+ADDR+'____'+DATA + '__' + RD
        else:
            CODE = 'X'
        return error, CODE
    
    @staticmethod
    def DMEM_WR (current : dict) -> tuple:
        error   = 0
        CODE = 'X'
        #### CONDITIONAL
        error, COND = Instruction.__PROCESS_CONDITION(current)
        #### WRITE REGISTER
        Wr = Rdi = '0'
        if (error==0):
            error, Wr, Rdi, RD = Instruction.__PROCESS_WR(current)
        #### DATA SOURCE
        if (error==0):
            error, DATA, alu_op, DF = Instruction.__PROCESS_SOURCE(current)
        #### ADDRESS
        if (error==0):
            error, rsA0, rsA1, AI = Instruction.__PROCESS_MEM_ADDR (current['DST'])
            ADDR  = rsA0 + '__' + rsA1
        #### SOURCE    
        if (error==0):
            if (current ['SRC'] == 'op'):
                if ('OP' in current ):
                    DI = '0'
                else:
                    error = Logger.error('Instruction.MEM_WR', '>  -op() option not found in instruction ' + str(current['LINE']) )
            elif (current ['SRC'] == 'imm'):
                if 'LIT' in current: 
                    DI = '1'
                else:
                    error = Logger.error('Instruction.MEM_WR', 'No Literal value found in instruction ' + str(current['LINE']) )
            else:
                error = Logger.error('Instruction.MEM_WR', 'Posible MEM_WR sources are (op, imm) in instruction ' + str(current['LINE']) )
        if (error==0):
            CFG = current['UF']+ '_'+Wr+Rdi+'_'+ alu_op
            CODE = '101_'+AI+DF+'__'+COND+'__0_'+DI+'_'+CFG+"___"+ADDR+'____'+DATA+'__'+RD
        return error, CODE
        
    @staticmethod
    def WMEM_WR (current : dict) -> tuple:
        error   = 0
        AI=Wp=TI='0'
        #### WMEM ADDRESS
        if 'DST' in current:
            error, rsA0, rsA1, AI = Instruction.__PROCESS_MEM_ADDR (current['DST'])
            if (rsA1 != '000000'):
                error = Logger.error('Instruction.REG_WR', 'Wave Memory Addres Error Source Should be LIT or Reg in line ' + str(current['LINE']) )                    
        else:
            error = Logger.error('Instruction.WMEM_WR', 'No address specified in line ' + str(current['LINE']) )
        #### WRITE REGISTER
        Wr = Rdi = '0'
        if (error==0):
            error, Wr, Rdi, RD = Instruction.__PROCESS_WR(current)
        #### WRITE PORT
        if (error==0):
            error, Wp, Sp, Dp = Instruction.__PROCESS_WP(current)
        #### DATA SOURCE
        if (error==0):
            error, DATA, alu_op, DF = Instruction.__PROCESS_SOURCE(current)
        if (error==0):
            if ('TIME' in current ):
                TI='1'
                error, TIME = get_imm_dt (current ['TIME'], 32)
                if (error): 
                    error = Logger.error('Parameter.WMEM_WR', 'Time Value error in instruction ') 
                else:
                    DATA = '_____' + TIME 
            CFG  = '1_' + TI+'_' +current['UF'] +'_'+ Wr +Rdi +'_'+ alu_op
            CODE = '101_'+AI+DF+'__1'+Sp+Wp+'__'+CFG+"___"+rsA0+'__'+Dp+'____'+DATA+'__'+RD
        else:
            error = Logger.error('Instruction.WMEM_WR', 'Error in line ' + str(current['LINE']) )
            CODE = 'X'
        return error, CODE
       
    @staticmethod
    def CFG (current : dict) -> tuple:
        error   = 0
        AI=SO=TO= '0'
        ADDR = '00000000000_000000'
        #### CONDITIONAL
        error, COND = Instruction.__PROCESS_CONDITION(current)
        #### WRITE REGISTER
        Wr = Rdi = '0'
        if (error==0):
            error, Wr, Rdi, RD = Instruction.__PROCESS_WR(current)
        #### DATA SOURCE
        if (error==0):
            error, DATA, alu_op, DF = Instruction.__PROCESS_SOURCE(current)
        if (error==0):
            CFG  = current['UF'] +'_'+ Wr + Rdi +'_'+ alu_op
            CODE = '000_'+AI+DF+'__'+COND+'__'+SO+TO+'__'+CFG+"_______"+ADDR+'____'+DATA+'__'+RD
        else:
            error = Logger.error('Instruction.CFG', 'Error in line ' + str(current['LINE']) )
            CODE = 'X'
        return error, CODE
    
    @staticmethod
    def BRANCH (current : dict, cj : str) -> tuple:
        error   = 0
        #### CONDITIONAL
        error, COND = Instruction.__PROCESS_CONDITION(current)
        #### WRITE REGISTER
        if error == 0:
            Wr = Rdi = '0'
            if (error==0):
                error, Wr, Rdi, RD = Instruction.__PROCESS_WR(current)
        #### DATA SOURCE
        if (error==0):
            error, DATA, alu_op, DF = Instruction.__PROCESS_SOURCE(current)
        #### DESTINATION MEMORY ADDRESS
        if error == 0:
            if (cj =='11'): # RET Instruction. ADDR came from STACK
                current['UF'] = '0'
                AI = '0'    
                ADDR = '_00000000000_000000'
            else:
                comp_addr = "&(\d+)|s(\d+)"
                addr = re.findall(comp_addr, current['ADDR']) 
                try:
                    if (addr[0][0]): # LITERAL
                        ADDR     = '_' + integer2bin(addr[0][0], 11) + '_000000' 
                        AI = '1'
                    elif (addr[0][1] == '15'): #SREG s15
                        ADDR     = '_00000000000_000000' 
                        AI = '0'
                    else:
                        error = Logger.error("Instruction.BRANCH", "JUMP Memory Address not recognized (imm or s15)")
                except IndexError:
                    error = Logger.error("COMMAND RECOGNITION", f"for address at line {current['LINE']}. (possible extra [])")

        if (error==0):
            CFG = current['UF'] +'_'+ Wr+Rdi +'_'+ alu_op
            CODE = '001_'+AI+DF+'__'+COND+'__'+cj+'__'+CFG+"______"+ADDR+'____'+DATA+'__'+RD
        else:
            Logger.error("Instruction.BRANCH", "Exit with Error in instruction " + str(current['LINE']) )
            CODE = 'X'
        return error, CODE
    
    @staticmethod
    def PORT_WR (current : dict) -> tuple:
        error   = 0
        ##### DATA PORTS
        if (current['CMD'] == 'DPORT_WR' or current['CMD'] == 'DPORT_RD') \
        or (current['CMD'] == 'TRIG'):
            SO=AI=Ww=Sp= '0'
            rsA0 = '___00000000000'
            #### WRITE REGISTER
            if (error==0):
                Wr = Rdi = '0'
                if (error==0):
                    error, Wr, Rdi, RD = Instruction.__PROCESS_WR(current)
            #### PORT DESTINATION 
            if (error==0):
                #### TRIG PORT
                if (current['CMD'] == 'TRIG'):
                    if (current['SRC'] == 'set'):
                        Wp= '1'
                        AI=Sp = '1'
                        rsA0     = '___00000000001'
                        current['DST'] = str(int(current['DST'])+32)
                    elif (current['SRC'] == 'clr'):
                        Wp= '1'
                        AI=Sp = '1'
                        rsA0     = '___00000000000'
                        current['DST'] = str(int(current['DST'])+32)
                    else:
                        error = Logger.error('Instruction.PORT_WR', 'Posible options for TRIG command are (set, clr)' )

                #### DATA PORT
                elif (current['CMD'] == 'DPORT_WR'):
                    Wp= '1'
                    Sp= '0'
                    if (current ['SRC'] == 'imm'):
                        if 'DATA' in current:
                            if ( int(current['DATA']) > 2047 ):
                                error = Logger.error('Instruction.PORT_WR', 'Data imm should be smaller than 2047 No Port Data value found in line ' + str(current['LINE']) )
                            else:
                                AI=Sp = '1'
                                # DATA CAMES WITHOUT #
                                rsA0     = '___'+ integer2bin(current['DATA'], 11)
                        else:
                            error = Logger.error('Instruction.PORT_WR', 'No Port Data value found in line ' + str(current['LINE']) )
                    elif (current ['SRC'] == 'reg'):
                        if ('DATA' in current ):
                            AI=Sp = '0'
                            comp_REG_FMT = "r(\d+)"
                            param_op  = re.findall(comp_REG_FMT, current['DATA'])
                            if (param_op):
                               rsA0     = '00000___1' + integer2bin(param_op[0], 5)     
                            else:
                                error = Logger.error('Instruction.PORT_WR', 'Register Selection Error, should be dreg in line ' + str(current['LINE']) )
                        else:
                            error = Logger.error('Instruction.PORT_WR', 'No Port Register found in line ' + str(current['LINE']) )
                    else:
                        error = Logger.error('Instruction.PORT_WR', 'Posible DPORT_WR sources are (imm, reg) in line ' + str(current['LINE']) )
                #### READ DATA PORT
                else:
                    TO=Wp='0'
        ##### WAVEFORM PORT
        else:
            AI=Ww=Sp= '0'
            SO=Wp= '1'
            #### SOURCE
            if (error==0):
                if (current['SRC'] == 'wmem'):
                    Sp = '0'
                    if 'ADDR' in current:
                        error, rsA0, rsA1, AI = Instruction.__PROCESS_MEM_ADDR (current ['ADDR'])
                        if (rsA1 != '000000'):
                            error = Logger.error('Instruction.REG_WR', 'Wave Memory Addres Error Source Should be LIT or Reg in line ' + str(current['LINE']) )                    
                    else:
                        error = Logger.error('Instruction.PORT_WR', 'No address specified for < wmem > in line ' + str(current['LINE']) )
                elif (current['SRC'] == 'r_wave'):
                    Sp='1'
                    #### WRITE WAVE MEMORY
                    if ('WW' in current ): 
                        if 'ADDR' in current:
                            Ww = '1'
                            error, rsA0, rsA1, AI = Instruction.__PROCESS_MEM_ADDR (current ['ADDR'])
                            if (rsA1 != '000000'):
                                error = Logger.error('Instruction.REG_WR', 'Wave Memory Addres Error Source Should be LIT or Reg in line ' + str(current['LINE']) )
                        else:
                            error = Logger.error('Instruction.PORT_WR', 'No address specified for < -ww > in line ' + str(current['LINE']) )
                    else:
                        Ww  = '0'
                        rsA0 = '___00000000000'
                else:
                    error = Logger.error('Instruction.PORT_WR', 'Posible wave sources are (wmem, r_wave) in line ' + str(current['LINE']) )
                    DF = '11'
        #### OUT TIME 
        if (error==0):
            if ('TIME' in current): 
                TO = '1'
                DF = '11'
                error, TIME = get_imm_dt (current ['TIME'], 32)
                if (error): 
                    error = Logger.error('Parameter.WMEM_WR', 'Time Value error in instruction ') 
                else:
                    DATA = '_____' + TIME 

                #DATA = '______'+ integer2bin(current['TIME'], 32)
                CFG = SO+TO+'____00000'
                RD = '0000000'
                if ('WR' in current or 'OP' in current): 
                    error = Logger.error('Instruction.PORT_WR', 'If time specified, Not allowed SDI <-wr(), -op()> in line ' + str(current['LINE']) )
            else:
                TO = '0'
                error = Logger.info('Instruction.PORT_WR', 'No time specified for command will use s_time in line ' + str(current['LINE']) )
                #### WRITE REGISTER
                Wr = Rdi = '0'
                if (error==0):
                    error, Wr, Rdi, RD = Instruction.__PROCESS_WR(current)
                #### DATA SOURCE
                if (error==0):
                    error, DATA, alu_op, DF = Instruction.__PROCESS_SOURCE(current)
                    CFG = SO+TO+'__'+current['UF'] +'_'+Wr+Rdi +'_'+ alu_op
        #### OUT PORT
        if (error==0):
            if ('DST' in current):
                rsA1 = integer2bin(current['DST'], 6,1)
            else:
                error = Logger.error('Instruction.PORT_WR', 'No Destination Port in line ' + str(current['LINE']) )        
        if (error == 0):
            COND = Ww+Sp+Wp
            ADDR  = rsA0+'__'+rsA1
            CODE = '110'+'_'+AI+DF+'__'+COND+'__'+CFG+ '___'+ADDR +'____'+ DATA+'__'+RD
        else:
            Logger.error("Instruction.PORT_WR", "Exit with Error in line " + str(current['LINE']) )
            CODE = 'X'
        return error, CODE
    
    ################################ TO UPDATE CODE HERE. NOT LAST VERSION
    @staticmethod
    def CTRL (current : dict) -> tuple:
        error   = 0
        Header = '010'
        RA0=RA1='000000'
        RD0=RD1='0_0000000'
        ImmFill='__0000000000000000'
        DF='01'
        AI='0'
        #### CONDITIONAL
        error, COND = Instruction.__PROCESS_CONDITION(current)
        ######### TIME 
        if (current ['CMD'] == 'TIME'):
            CTRL_ADDR      = '000'
            if   (current['C_OP'] == 'rst'):
                OPERATION = '_0001'
            elif (current['C_OP'] == 'updt'):
                OPERATION = '_0010'
            elif (current['C_OP'] == 'set_ref'):
                OPERATION = '_0100'
            elif (current['C_OP'] == 'inc_ref'):
                OPERATION = '_1000'
            else:
                error = Logger.error('Instruction.CTRL', 'Posible Operations for TIME command are (rst, set_ref, inc_ref)' )
            if ('LIT' in current ):
                DF  ='11'
                RD0 = '_'
                error, RD1 = get_imm_dt (current ['LIT'], 32)
                ImmFill='__'
            elif ('R1' in current):
                error, RD1 = get_reg_addr (current['R1'], 'src_data')
            else: 
                if   (current['C_OP'] !='rst'):
                    error = Logger.error('Instruction.CTRL', 'No Time Data' )
        ######### FLAG
        elif (current ['CMD'] == 'FLAG'):
            CTRL_ADDR      = '001'
            if   (current['C_OP'] == 'set'):
                OPERATION = '_0001'
            elif (current['C_OP'] == 'clr'):
                OPERATION = '_0010'
            elif (current['C_OP'] == 'inv'):
                OPERATION = '_0100'
            else:
                error = Logger.error('Instruction.CTRL', 'Posible Operations for FLAG command are (set, clr, inv)' )
        ######### DIVISION
        elif (current ['CMD'] == 'DIV'):
            CTRL_ADDR  = '011'
            OPERATION  = '_0000'
            error, RA1 = get_reg_addr (current['NUM'], 'src_addr')
            if (error == 0):
                if (check_reg(current['DEN'])) : # Is Register 
                    error, RD1 = get_reg_addr (current['DEN'], 'src_data')
                elif (check_lit(current['DEN'])) : # Is Literal Value
                    DF  ='11'
                    RD0 ='_'
                    error, RD1 = get_imm_dt (current ['DEN'], 32)
                    ImmFill='__'
                else:
                    error = Logger.error('Instruction.CTRL', 'DIV Denominator not recognized in line ' + str(current['LINE']) )        
        ######### NET
        elif (current ['CMD'] == 'NET'):
            Header = '011'
            CTRL_ADDR      = '_00' # QNET ADDRESS
            if   (current['C_OP'] == 'set_net'):
                OPERATION = '00001'
            elif (current['C_OP'] == 'sync_net'):
                OPERATION = '01000'
            elif (current['C_OP'] == 'updt_offset'):
                OPERATION = '01001'
            elif (current['C_OP'] == 'set_dt'):
                OPERATION = '01010'
            elif (current['C_OP'] == 'get_dt'):
                OPERATION = '01011'
            elif (current['C_OP'] == 'set_flag'):
                OPERATION = '01010'
            elif (current['C_OP'] == 'get_flag'):
                OPERATION = '01011'
            else:
                error = Logger.error('Instruction.CTRL', 'NET Operation not recognized' )
        ######### COM
        elif (current ['CMD'] == 'COM'):
            Header = '011'
            CTRL_ADDR      = '_01' # QCOM ADDRESS
            if   (current['C_OP'] == 'set_flag'):
                if (current['R1'] == '0'):
                    OPERATION = '00000'
                elif (current['R1'] == '1'):
                    OPERATION = '00010'
                else:
                    error = Logger.error('Instruction.CTRL', 'COM flag value can be 0 or 1' )
            elif (current['C_OP'] == 'sync'):
                OPERATION = '00110'
            elif (current['C_OP'] == 'reset'):
                OPERATION = '11111'
            else:
                if (current['C_OP'] == 'set_byte_1'):
                    OPERATION = '00100'
                elif (current['C_OP'] == 'set_byte_2'):
                    OPERATION = '00101'
                elif (current['C_OP'] == 'set_hw_1'):
                    OPERATION = '01000'
                elif (current['C_OP'] == 'set_hw_2'):
                    OPERATION = '01001'
                elif (current['C_OP'] == 'set_word_1'):
                    OPERATION = '01100'
                elif (current['C_OP'] == 'set_word_2'):
                    OPERATION = '01101'
                else:
                    error = Logger.error('Instruction.CTRL', 'Posible Operations for COM command are (set_flag, set_byte, set_hw, set_word)' )
                if ('LIT' in current ):
                    DF='11'
                    RD0 = ''
                    error, RD1 = get_imm_dt (current ['LIT'], 32)
                    ImmFill=''
                elif ('R1' in current):
                    error, RD1 = get_reg_addr (current['R1'], 'src_data')
                else: 
                    if (current['C_OP'] !='rst'):
                        error = Logger.error('Instruction.CTRL', 'No Time Data' )
        ######### CUSTOM Peripheral
        elif (current ['CMD'] == 'PA' or current ['CMD'] == 'PB'):
            Header = '011'
            if (current ['CMD'] == 'PA'):
                CTRL_ADDR      = '_10' # PA PERIPHERAL
            else:
                CTRL_ADDR      = '_11' # PB PERIPHERAL
            if ( int(current['C_OP']) > 31):
                error = Logger.error("COMMAND_RECOGNITION", "External Peripheral Operation not in range [0:31] in line " + str(current['LINE']) )
            else:
                OPERATION = integer2bin(current['C_OP'], 5,1)
                if ('LIT' in current):
                        error = Logger.error('Instruction.CTRL', 'No Immediate value allowed in Peripheral instruction' )
                else :
                    if ('R1' in current):
                        error, RD0 = get_reg_addr (current['R1'], 'src_data')
                    if ('R2' in current):
                        error, RD1 = get_reg_addr (current['R2'], 'src_data')
                    if ('R3' in current):
                        error, RA0 = get_reg_addr (current['R3'], 'src_addr')
                    if ('R4' in current):
                        error, RA1 = get_reg_addr (current['R4'], 'src_addr')
        if (error):
            Logger.error("Instruction.CTRL", "Error in instruction " + str(current['LINE']) )
            CODE = 'X'
        else:
            CODE = Header+'_'+AI+DF+'__'+COND+'___'+CTRL_ADDR+'__'+OPERATION+'___00000___'+RA0+'__'+RA1+'____'+RD0+'__'+RD1+ImmFill+'__0000000'
        return error, CODE

    
    @staticmethod
    def ARITH (current : dict) -> tuple:
        error   = 0
        RsC=RsD='000000'
        #### CONDITIONAL
        error, COND = Instruction.__PROCESS_CONDITION(current)
        if ('LIT' in current):
                error = Logger.error('Instruction.ARITH', 'No Immediate value allowed ' )
        if (not 'C_OP' in current) :
            error = Logger.error('Instruction.ARITH', 'No ARITH Operation ' )
        else :
            if (current['C_OP'] in arithList ):
                ARITH_OP = arithList[current['C_OP']]
            if   (current['C_OP'] == 'T'): # A*B
                if ('R1' in current and 'R2' in current ):
                    error, RsA = get_reg_addr (current['R1'], 'src_data')
                    error, RsB = get_reg_addr (current['R2'], 'src_data')
                else:
                    error = Logger.error('Instruction.ARITH', 'Few Sources > Need Two Source Register for T operation' )
            elif (current['C_OP'] == 'TP') : # A*B+C
                if ('R1' in current and 'R2' in current and 'R3' in current ):
                    error, RsA = get_reg_addr (current['R1'], 'src_data')
                    error, RsB = get_reg_addr (current['R2'], 'src_data')
                    error, RsC = get_reg_addr (current['R3'], 'src_addr')
                else:
                    error = Logger.error('Instruction.ARITH', 'Few Sources > Need three Source Register for TP operation' )
            elif (current['C_OP'] == 'TM') : # A*B-C
                if ('R1' in current and 'R2' in current and 'R3' in current ):
                    error, RsA = get_reg_addr (current['R1'], 'src_data')
                    error, RsB = get_reg_addr (current['R2'], 'src_data')
                    error, RsC = get_reg_addr (current['R3'], 'src_addr')
                else:
                    error = Logger.error('Instruction.ARITH', 'Few Sources > Need three Source Register for TM operation' )
            elif (current['C_OP'] == 'PT') : # (D+A)*B
                if ('R1' in current and 'R2' in current and 'R3' in current ):
                    error, RsD = get_reg_addr (current['R1'], 'src_addr')
                    error, RsA = get_reg_addr (current['R2'], 'src_data')
                    error, RsB = get_reg_addr (current['R3'], 'src_data')
                else:
                    error = Logger.error('Instruction.ARITH', 'Few Sources > Need three Source Register for PT operation' )
            elif (current['C_OP'] == 'PTP'): #(D+A)*B+C
                if ('R1' in current and 'R2' in current and 'R3' in current and 'R4' in current ):
                    error, RsD = get_reg_addr (current['R1'], 'src_addr')
                    error, RsA = get_reg_addr (current['R2'], 'src_data')
                    error, RsB = get_reg_addr (current['R3'], 'src_data')
                    error, RsC = get_reg_addr (current['R4'], 'src_addr')
                else:
                    error = Logger.error('Instruction.ARITH', 'Few Sources > Need Four Source Register for PTP operation' )
            elif (current['C_OP'] == 'PTM'): #(D+A)*B-C
                if ('R1' in current and 'R2' in current and 'R3' in current and 'R4' in current ):
                    error, RsD = get_reg_addr (current['R1'], 'src_addr')
                    error, RsA = get_reg_addr (current['R2'], 'src_data')
                    error, RsB = get_reg_addr (current['R3'], 'src_data')
                    error, RsC = get_reg_addr (current['R4'], 'src_addr')
                else:
                    error = Logger.error('Instruction.ARITH', 'Few Sources > Need Four Source Register for PTP operation' )
            elif (current['C_OP'] == 'MT' ): #(D-A)*B
                if ('R1' in current and 'R2' in current and 'R3' in current ):
                    error, RsD = get_reg_addr (current['R1'], 'src_addr')
                    error, RsA = get_reg_addr (current['R2'], 'src_data')
                    error, RsB = get_reg_addr (current['R3'], 'src_data')
                else:
                    error = Logger.error('Instruction.ARITH', 'Few Sources > Need three Source Register for PT operation' )
            
            elif (current['C_OP'] == 'MTP'): #(D-A)*B+C
                if ('R1' in current and 'R2' in current and 'R3' in current and 'R4' in current ):
                    error, RsD = get_reg_addr (current['R1'], 'src_addr')
                    error, RsA = get_reg_addr (current['R2'], 'src_data')
                    error, RsB = get_reg_addr (current['R3'], 'src_data')
                    error, RsC = get_reg_addr (current['R4'], 'src_addr')
                else:
                    error = Logger.error('Instruction.ARITH', 'Few Sources > Need Four Source Register for PTP operation' )
            elif (current['C_OP'] == 'MTM'): #(D-A)*B-C
                if ('R1' in current and 'R2' in current and 'R3' in current and 'R4' in current ):
                    error, RsD = get_reg_addr (current['R1'], 'src_addr')
                    error, RsA = get_reg_addr (current['R2'], 'src_data')
                    error, RsB = get_reg_addr (current['R3'], 'src_data')
                    error, RsC = get_reg_addr (current['R4'], 'src_addr')
                else:
                    error = Logger.error('Instruction.ARITH', 'Few Sources > Need Four Source Register for PTP operation' )
            else:
                    error = Logger.error('Instruction.ARITH', 'No Recognized Operation' )
        if (error==0):
            CODE = '010_001__'+COND+'___010___'+ARITH_OP +'___00000___'+RsC+'__'+RsD+'____'+RsA+'__'+RsB+'__0000000000000000__0000000'
        else:
            Logger.error("Instruction.ARITH", "Exit with Error in line " + str(current['LINE']) )
            CODE = 'X'
        return error, CODE

    @staticmethod
    def WAIT (current : dict) -> tuple:
        error   = 0
        binary_multi_list = []
        current['ADDR'] = '&'+str(current['P_ADDR'])
        test_op   = ''
        jump_cond = ''
        if   (current['C_OP'] == 'time') : 
            test_op   = 's11 - #' + str(int(current['TIME'][1:])-10)
            jump_cond = 'S'
        elif (current['C_OP'] == 'port_dt') : 
            test_op   = 's10 AND #h8000'
            jump_cond = 'Z'
        elif (current['C_OP'] == 'div_rdy') : 
            test_op   = 's10 AND #h4'
            jump_cond = 'Z'
        elif (current['C_OP'] == 'div_dt') : 
            test_op   = 's10 AND #h8'
            jump_cond = 'Z'
        elif (current['C_OP'] == 'qpa_rdy') : 
            test_op   = 's10 AND #h100'
            jump_cond = 'Z'
        elif (current['C_OP'] == 'qpa_dt') : 
            test_op   = 's10 AND #h200'
            jump_cond = 'Z'
        else:
            msg = 'No Recognized Operation in line ' + str(current['LINE'])
            error = Logger.error('Instruction.WAIT', msg )
        if (error==0):
            current['OP'] = test_op
            current['UF'] = '1'
            error, CODE = Instruction.CFG(current) ## ADD TEST INSTRUCTION
            if (error==0):
                binary_multi_list.append(CODE)
                current['IF'] = jump_cond
                error, CODE = Instruction.BRANCH(current, '00') ## ADD JUMP INSTRUCTION
            if (error==0):
                binary_multi_list.append(CODE)
        return error, binary_multi_list        

    @staticmethod
    def CLEAR (current : dict) -> tuple:
        error   = 0
        current['CMD'] = 'REG_WR'
        current['DST'] = 's2'
        current['SRC'] = 'imm'
        if   (current['C_OP'] == 'arith') : current['LIT'] =  '#h10000'
        elif (current['C_OP'] == 'div'  ) : current['LIT'] =  '#h20000'
        elif (current['C_OP'] == 'qnet' ) : current['LIT'] =  '#h40000'
        elif (current['C_OP'] == 'qcom' ) : current['LIT'] =  '#h80000'
        elif (current['C_OP'] == 'qpa'  ) : current['LIT'] = '#h100000'
        elif (current['C_OP'] == 'qpb'  ) : current['LIT'] = '#h200000'
        elif (current['C_OP'] == 'port' ) : current['LIT'] = '#h400000'
        elif (current['C_OP'] == 'all'  ) : current['LIT'] = '#h7F0000'
        else:
            error = Logger.error('Instruction.CLEAR', 'No Recognized Operation in line ' + str(current['LINE']) )
        if (error==0):
            error, CODE = Instruction.REG_WR(current)
        return error, CODE        

