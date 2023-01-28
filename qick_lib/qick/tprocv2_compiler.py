# -*- coding: utf-8 -*-
"""
Created on Tue Aug  9 13:40:39 2022

@author: mdifeder
"""
import re
import logging

logger = logging.getLogger('tprocv2_compiler')


# ALU OPERATIONS 
aluList = {}
aluList['+']     = '0000'
aluList['-']     = '0010'
aluList['AND']   = '0100'
aluList['&']     = '0100'
aluList['MSK']   = '0100'
aluList['ASR']   = '0110'
aluList['ABS']   = '1000'
aluList['MSH']   = '1010'
aluList['LSH']   = '1100'
aluList['SWP']   = '1110'
aluList['NOT']   = '0001'
aluList['!']     = '0001'
aluList['OR']    = '0011'
aluList['|']     = '0011'
aluList['XOR']   = '0101'
aluList['^']     = '0101'
aluList['CAT']   = '0111'
aluList['::']    = '0111'
aluList['RFU']   = '1001'
aluList['PAR']   = '1011'
aluList['SL']    = '1101'
aluList['<<']    = '1101'
aluList['SR']    = '1111'
aluList['>>']    = '1111'
aluList_s = {} ## List with Commands for -op()
aluList_s['+']     = '00'
aluList_s['-']     = '01'
aluList_s['AND']   = '10'
aluList_s['ASR']   = '11'
aluList_op = [] ## List with Commands with one parameter
aluList_op.append('ABS')
aluList_op.append('MSH')
aluList_op.append('LSH')
aluList_op.append('SWP')
aluList_op.append('PAR')
aluList_op.append('NOT')


arithList = {} #Arith Comand List
arithList['T']   = '00000'
arithList['TP']  = '00010'
arithList['TM']  = '00011'
arithList['PT']  = '01000'
arithList['MT']  = '11000'
arithList['PTP'] = '01010'
arithList['PTM'] = '01011'
arithList['MTP'] = '11010'
arithList['MTM'] = '11011'

# CONDITIONALS
condList = {}
condList['0']       = '000'
condList['Z']       = '001'
condList['S']       = '010'
condList['NZ']      = '011'
condList['NS']      = '100'
condList['TC']      = '101'
condList['NTC']     = '110'
condList['EC']      = '111'
condStr = ', '.join(list(condList.keys()))


def tprocv2_getasm(prog_list, Dict_Label):
    asm = ''
    addr = 0
    key_list = list(Dict_Label.keys())
    val_list = list(Dict_Label.values())
    for cmd in prog_list:
        addr = addr+1
        # LABEL in the Correct Line
        PADDR = '&'+str(addr)
        if (PADDR in val_list):
            #print('LABEL : ' + key_list[val_list.index(PADDR)] + ' > PADDR ' + PADDR)
            label = key_list[val_list.index(PADDR)]
            if (label[0:2]=='F_'):
                label = '\n' + label
            asm = asm + label + ':\n'
        # COMMAND 
        if (cmd['CMD']=='RET'):
            asm = asm + 'RET\n'
        else:
            asm = asm + '     ' +cmd['CMD'] + ' '
        # PARAMETERS
        if ('DST' in cmd):
            if (cmd['CMD']=='DMEM_WR') or (cmd['CMD']=='WMEM_WR'):
                asm = asm + '['+cmd['DST'] + '] '
            elif (cmd['CMD']=='DPORT_WR') or (cmd['CMD']=='WPORT_WR'):
                asm = asm + 'p'+cmd['DST'] + ' '
            else:            
                asm = asm + cmd['DST'] + ' '
        if ('SRC' in cmd):
               asm = asm + cmd['SRC'] + ' '

        if ('LABEL' in cmd):
            asm = asm + cmd['LABEL'] + ' '

        if ('IF' in cmd):
            asm = asm + '-if(' + cmd['IF'] + ') '

        if ('WR' in cmd):
            asm = asm + '-wr(' + cmd['WR'] + ') '

        if ('LIT' in cmd):
            asm = asm + '#' + cmd['LIT'] + ' '
        if ('OP' in cmd):
            asm = asm + '-op(' + cmd['OP'] + ') '
        elif ('ADDR' in cmd):
            asm = asm + '[' + cmd['ADDR'] + '] '
                
        if ('NUM' in cmd):
            asm = asm + cmd['NUM'] + ' '
        if ('DEN' in cmd):
            if (cmd['DEN'][0]=='r'):
                asm = asm + cmd['DEN'] + ' '
            else:
                asm = asm + '#' + cmd['DEN'] + ' '
        if ('UF' in cmd):
            if (cmd['UF']=='1'):
                asm = asm + '-uf'

        asm = asm + '\n'
    # ADD Address to commands with LABEL
    line = 0
    for cmd in prog_list:
        if ('LABEL' in cmd):
            if ( cmd['LABEL'] in Dict_Label ) :
                cmd['ADDR'] = Dict_Label[ cmd['LABEL'] ]
                #print('Label <'+cmd['LABEL'] +'> changed by address '+cmd['ADDR'])
            else:
                error = msg(4, 'LABEL: ', 'Label ' +cmd['LABEL'] + ' not recognized')
        cmd['LINE'] = line
        line = line + 1

    return prog_list, asm
    


def tprocv2_compile(prog_list, Dict_Label):
    prog_list, asm = tprocv2_getasm(prog_list, Dict_Label)
    error = 0
    PROGRAM = ['000_000__000___00__0_00_00______00000000000_000000_________00000000000000000000000000000000_0000000']
    CODE='x'
    for current in prog_list:
        if ('CMD' in current):
        ###############################################################################
            if current['CMD'] == 'NOP':
                CODE = '000_000__000___00__0_00_00______00000000000_000000_________00000000000000000000000000000000_0000000'
        ###############################################################################
            elif (current['CMD'] == 'REG_WR'):
                error, CODE = cmd_REG_WR(current)
        ###############################################################################
            elif current['CMD'] == 'DMEM_WR':
                error, CODE = cmd_DMEM_WR(current)
        ###############################################################################
            elif current['CMD'] == 'WMEM_WR':
                error, CODE = cmd_WMEM_WR(current)
        ###############################################################################
            elif current['CMD'] == 'JUMP':
                error, CODE = cmd_BRANCH(current, '00')
        ###############################################################################
            elif current['CMD'] == 'CALL':
                error, CODE = cmd_BRANCH(current, '10')
        ###############################################################################
            elif current['CMD'] == 'RET':
                error, CODE = cmd_BRANCH(current, '11')
        ###############################################################################
            elif current['CMD']=='DPORT_WR' or current['CMD'] == 'DPORT_RD' or current['CMD'] == 'WPORT_WR':
                error, CODE = cmd_PORT_WR(current)
        ###############################################################################
            elif current['CMD'] == 'TIME':
                error, CODE = cmd_CTRL(current)
        ###############################################################################
            elif current['CMD'] == 'TEST':
                current['UF'] = '1'
                error, CODE = cmd_CFG(current)
        ###############################################################################
            elif current['CMD'] == 'DIV':
                error, CODE = cmd_CTRL(current)
        ###############################################################################
            elif current['CMD'] == 'COND':
                error, CODE = cmd_CTRL(current)
        ###############################################################################
            elif current['CMD'] == 'ARITH':
                error, CODE = cmd_ARITH(current)
            else:
                logger.error('[ERROR-S2]- Command not recognized > ' + current['CMD'])
                error=1
            long = CODE.count('0') + CODE.count('1')
            if (long != 72):
                error = 1
                logger.error(CODE+"INSTRUCIONT LONG > " + str(long) +' '+ str(current['LINE']))
        else:    
            logger.error("[ERROR-S2]-No Command")
            error=1
    ###################################################################################
        if (error==0):
            PROGRAM.append(CODE)
        else:
            break
    if (error!=0):
        logger.error("S2-Exit With ERROR")
    else:    
        logger.info('##### STEP_4 - BINARY CREATION')
        p_mem = []
        for line_bin in PROGRAM:
            tmp = line_bin.replace('_', '')
            b0 = '0b'+tmp[40:72]
            n0 = int(b0,2)
            b1 = '0b'+ tmp[8:40]
            n1 = int(b1,2)
            b2 = '0b'+tmp[:8]
            n2 = int(b2,2)
            p_mem_line = [n0, n1, n2, 0, 0, 0, 0, 0]
            p_mem.append(p_mem_line)
        logger.info("\n#######################\n Finished Successfully\n#######################")
        return p_mem, PROGRAM, asm
   
    
def msg (severity, locator, msg):
    if (severity == 4):
        logger.error('[%s] > %s' % (locator, msg))
        return 1
    elif (severity == 3 ):   
        logger.warning('[%s] > %s' % (locator, msg))
    elif (severity == 2 ):   
        logger.info('[%s] > %s' % (locator, msg))
    elif (severity == 1 ):   
        logger.debug('[%s] > %s' % (locator, msg))
    else:
        logger.debug('[%s] > %s' % (locator, msg))
    return 0

    
def integer2bin(strin, bits=8):
        minv = -2**(bits-1)
        maxv = 2**(bits-1) - 1
        # Check if hex string.
        m = re.search("^0x", strin, flags=re.MULTILINE)
        if m:
            # Special case for hex number.
            dec = int(strin, 16)
            # Convert to binary.
            fmt = "{0:0" + str(bits) + "b}"
            binv = fmt.format(dec)
            return binv
        else:
            dec = int(strin, 10)
        # Check max.
        if dec < minv:
            logger.error("number %d is smaller than %d" % (dec, minv))
            return None
        # Check max.
        if dec > maxv:
            logger.error("number %d is bigger than %d" % (dec, maxv))
            return None
        # Check if number is negative.
        if dec < 0:
            dec = dec + 2**bits
        # Convert to binary.
        fmt = "{0:0" + str(bits) + "b}"
        binv = fmt.format(dec)
        return binv

def proc_CONDITION (cmd):
    error = 0
    cond = ''
    if ('IF' in cmd ):
        if cmd['IF'] in condList:
            cond = condList[cmd['IF']]
        else:
            error = msg(4, 'proc_CONDITION', 'Posible CONDITIONS are (' + condStr + ') in instruction ' + str(cmd['LINE']) )
    else: 
        cond = '000'
    return [error, cond]

def get_reg_addr (reg, Type):
    error = 0
    REG = re.findall('r(\d+)|s(\d+)|w(\d+)', reg)
    if (REG):
        REG = REG[0]
        if (Type=='Source'):
            if (REG[0]): ## is R_Reg
                reg_addr =  '0_00'+integer2bin(REG[0], 5)   
            elif (REG[1]): ## is S_Reg
                reg_addr     = '0_10'+integer2bin(REG[1], 5)     
            elif (REG[2]): ## is W_Reg
                reg_addr     = '0_01'+integer2bin(REG[2], 5)     
        elif (Type=='Dest'):
            if (REG[0]): ## is Data Register
                reg_addr =  '00'+integer2bin(REG[0], 5)   
            elif (REG[1]): ## is Special Register
                reg_addr     = '10'+integer2bin(REG[1], 5)     
            elif (REG[2]): ## is WaveForm Register
                reg_addr     = '01'+integer2bin(REG[2], 5)     
        elif (Type=='Addr'):
            if (REG[0]): ## is R_Reg
                reg_addr =  '0'+integer2bin(REG[0], 5)   
            elif (REG[1] or REG[2]): ## is S_Reg or W_Reg
                error = msg(4, 'get_reg_addr', 'Address format error, should be Data Register (Starts with r)' )
    else:
        reg_addr     = 'X'
        error = msg(4, 'get_reg_addr', 'Register not Recognized (Registers Starts with r, s or w) ' )
    return [error, reg_addr] 


def proc_WR2(cmd):    #### Get WR 
    error = 0
    RD    = '0000000'
    Rdi=Wr  = '0'
    if ('WR' in cmd ):
        Wr = '1'
        regex_DS = r'\s*([\w]+)'
        DEST_SOURCE = re.findall(regex_DS, cmd['WR'])
        #### SOURCE
        if (len(DEST_SOURCE) == 2):
            if (DEST_SOURCE[1] == 'op'):
                if ('OP' in cmd ):
                    Rdi    = '0'
                else:
                    error = msg(4, 'proc_WR2', 'Pperation < -op() > option not found in instruction ' + str(cmd['LINE']) )
            elif (DEST_SOURCE[1] == 'imm'):
                if ('LIT' in cmd ):
                    Rdi    = '1'
                else:
                    error = msg(4, 'proc_WR2', 'Literal Value not found in instruction ' + str(cmd['LINE']) )
            else:
                error = msg(4, 'proc_WR2', 'Posible Source Dest for <-wr(reg source)> are (op, imm) in instruction ' + str(cmd['LINE']) )
        else:
            error = msg(4, 'proc_WR2', 'Write Register error <-wr(reg source) in instruction ' + str(cmd['LINE']) )
        #### DESTINATION REGISTER
        error, RD = get_reg_addr (DEST_SOURCE [0], 'Dest')
    return [error, Wr, Rdi, RD]
      

  
def proc_SOURCE (cmd):
    error = 0
    df = alu_op = 'X'
    RsD = RsC = DataImm =''
    FULL = (cmd['CMD']=='REG_WR') and (cmd['SRC']=='op')
    if ('OP' in cmd):
        error = 0
        comp_OP_PARAM = "r(\d+)|s(\d+)|w(\d+)|#(-?\d+)|\s*([A-Z]{3}|[A-Z><]{2}|\+|\-)"
        param_op  = re.findall(comp_OP_PARAM, cmd['OP'])
        DataImm = RsC = '' 
        if (len(param_op)==1 ) :
            df          = '10'
            RsC         = '0_0000000'
            DataImm     = '0000000000000000'
            if FULL:
                alu_op      = '0000'
            else:
                alu_op      = '00'
                
            ## CHECK FOR ONLY OPERAND (COPY REG)
            if (param_op[0][0]): ## is R_Reg
                RsD     = '0_00'+integer2bin(param_op[0][0], 5)     
            elif (param_op[0][1]): ## is S_Reg
                RsD     = '0_10'+integer2bin(param_op[0][1], 5)     
            elif (param_op[0][2]): ## is W_Reg
                RsD     = '0_01'+integer2bin(param_op[0][2], 5)     
            elif (param_op[0][3]): ## is Literal
                error = msg(4, 'proc_SOURCE', 'Operand can not be a Literal.')
            else:
                error = msg(4, 'proc_SOURCE', 'Operand not recognized.')

            #error = msg(4, 'proc_SOURCE', 'Few parameters in < -op() >')
        elif (len(param_op)==2 ) :
            if (param_op[0][4] in aluList_op) :
                df          = '10'
                alu_op      = aluList[param_op[0][4]]
                DataImm     = '000000000000000000000000'
                ## CHECK FOR OPERAND (ALU_IN_A > rsD)
                if (param_op[1][0]): ## is R_Reg
                    RsD     = '0_00'+integer2bin(param_op[1][0], 5)     
                elif (param_op[1][1]): ## is S_Reg
                    RsD     = '0_10'+integer2bin(param_op[1][1], 5)     
                elif (param_op[1][2]): ## is W_Reg
                    RsD     = '0_01'+integer2bin(param_op[1][2], 5)     
                elif (param_op[1][3]): ## is Literal
                    error = msg(4, 'proc_SOURCE', 'Operand can not be a Literal in instruction ' + str(cmd['LINE']) )
            else:
                error = msg(4, 'proc_SOURCE', 'Operantion Not Recognized in instruction ' + str(cmd['LINE']) )
            ## ABS Should be on RsC
            if (param_op[0][4] == 'ABS') :
                df          = '01'
                RsC         = RsD
                RsD         = '0_0000000'
                DataImm     = '0000000000000000'
        elif (len(param_op)==3 ) :
            ## CHECK FOR FIRST OPERAND (ALU_IN_A > rsD)
            if (param_op[0][0]): ## is R_Reg
                RsD     = '0_00'+integer2bin(param_op[0][0], 5)     
            elif (param_op[0][1]): ## is S_Reg
                RsD     = '0_10'+integer2bin(param_op[0][1], 5)     
            elif (param_op[0][2]): ## is W_Reg
                RsD     = '0_01'+integer2bin(param_op[0][2], 5)     
            elif (param_op[0][3]): ## is Literal
                error = msg(4, 'proc_SOURCE', 'First Operand can not be a Literal.')
            else:
                error = msg(4, 'proc_SOURCE', 'First Operand not recognized.')
            ## CHECK FOR SECOND OPERAND (ALU_IN_B > Imm|rsC)
            if (error == 0):
                if ( (param_op[2][0]) or (param_op[2][1]) or (param_op[2][2]) ): ## REG OP REG
                    if ('LIT' in cmd):
                        msg(3, 'proc_SOURCE', 'With < -op() > imm value should be 16 Bits in instruction ' + str(cmd['LINE']) )
                        if ( int(cmd ['LIT']) >= 65535):
                            error = msg(4, 'proc_SOURCE',  ('Literal '+ cmd ['LIT'] + ' should be 16 Bits.') )
                        else:
                            logger.info("[OK] Literal " + cmd ['LIT'] + " can be represented with 16 Bits.")
                            df    = '01'
                            DataImm = '_'+integer2bin(cmd ['LIT'], 16)
                    else:
                        DataImm = '0000000000000000'

                    if (param_op[2][0]): ## is R_Reg
                        df = '01'
                        RsC     = '0_00'+integer2bin(param_op[2][0], 5)   
                    elif (param_op[2][1]): ## is S_Reg
                        df = '01'
                        RsC     = '0_10'+integer2bin(param_op[2][1], 5)     
                    elif (param_op[2][2]): ## is W_Reg
                        df = '01'
                        RsC     = '0_01'+integer2bin(param_op[2][2], 5)     
                elif (param_op[2][3]): ## is Literal
                    df = '10'
                    DataImm = '_'+ integer2bin(param_op[2][3], 24)
                else:
                    error = msg(4, 'proc_SOURCE', 'Second Operand not recognized in instruction ' + str(cmd['LINE']) )
            ## CHECK FOR OPERATION
            if (error == 0):
                if (FULL):
                    if param_op[1][4] in aluList:
                        alu_op      = aluList[ param_op[1][4] ]
                    else:
                        error = msg(4, 'proc_SOURCE', 'ALU {Full List} Operation Not Recognized in instruction ' + str(cmd['LINE']) )
                else:
                    if param_op[1][4] in aluList_s:
                        alu_op      = aluList_s[ param_op[1][4] ]
                    else:
                        error = msg(4, 'proc_SOURCE', 'ALU {Reduced List} Operation Not Recognized in instruction ' + str(cmd['LINE']) )
    ## LITERAL and NO OP
    elif ('LIT' in cmd): 
        df      = '11'
        alu_op  = '00'
        DataImm = '__'+integer2bin(cmd['LIT'], 32)
    else:
        df      = '11'
        alu_op  = '00'
        DataImm = '__00000000000000000000000000000000'
    
    Data_Source = RsD +'_'+ RsC +'_'+ DataImm
    return [error, Data_Source, alu_op, df]

def proc_MEM_ADDR (ADDR_CMD):
    error = 0
    AI = '0'
    RsF = RsE = 'x'
    comp_ADDR_FMT = "r(\d+)|&(\d+)|\s*([A-Z]{3}|[A-Z]{2}|\+|\-)"
    param_op  = re.findall(comp_ADDR_FMT, ADDR_CMD)
    if (len(param_op)==1 ) :
        ## CHECK FOR OPERAND
        RsE     = '000000'
        if (param_op[0][0]): ## is R_Reg
            RsF     = '00000_' + integer2bin(param_op[0][0], 6)     
        elif (param_op[0][1]): ## is Literal
            RsF     = '_'+ integer2bin(param_op[0][1], 11)
            AI = '1'
        else:
            error = msg(4, 'proc_MEM_ADDR', 'First Operand not recognized.')
    elif (len(param_op)==3 ) :
        ## CHECK FOR FIRST OPERAND
        if (param_op[0][0]): ## is R_Reg
            RsE     = integer2bin(param_op[0][0], 6)     
        elif (param_op[0][1]): ## is Literal
            error = msg(4, 'proc_MEM_ADDR', 'First Operand can not be a Literal.')    
        ## CHECK FOR SECOND OPERAND 
        if (error == 0):
            if (param_op[2][0]): ## is R_Reg
                RsF     = '00000_' + integer2bin(param_op[2][0], 6)     
            elif (param_op[2][1]): ## is Literal
                RsF     = '_'+ integer2bin(param_op[2][1], 11)     
                AI = '1'
        ## CHECK FOR PLUS
        if (error == 0):
            if (param_op[1][2]) != '+': ## is R_Reg
                error = msg(4, 'proc_MEM_ADDR', 'Address Operand should be < + >.')    
    else:
        error = msg(4, 'proc_MEM_ADDR', 'Address format error, should be Data Register(r) or Literal(&)')
    return [error, RsF, RsE, AI]




###############################################################################
## BASIC COMANDS
###############################################################################
def cmd_REG_WR (current):
    AI = '0'
    error   = 0
    RdP = '000000'
    ######### CONDITIONAL
    error, COND = proc_CONDITION(current)
    ######### SOURCES
    if (error==0):
        #### SOURCE ALU
        if (current ['SRC'] == 'op'):
            if ('OP' in current ):
                error, DATA, alu_op, DF = proc_SOURCE (current)
                CFG   = '00__' + current ['UF'] + '__'+ alu_op 
                ADDR  = '_00000000000_000000' # 17 Bits 11 + 6
            else:
                error = msg(4, 'cmd_REG_WR', 'No < -op() > for Operation Writting in instruction ' + str(current['LINE']))
        #### SOURCE IMM
        elif (current ['SRC'] == 'imm'):
            #### Get Data Source
            if ('LIT' in current ):
                error, DATA, alu_op, DF = proc_SOURCE(current)
                CFG = '11__' + current ['UF'] + '_00_' + alu_op
                ADDR  = '_00000000000_000000' # 17 Bits 11 + 6
            else:
                error = msg(4, 'cmd_REG_WR', 'No Literal value for immediate Assignation (#) in instruction ' + str(current['LINE']) )
        #### SOURCE LABEL
        elif (current ['SRC'] == 'label'):
            #### Get Data Source
            if ('LABEL' in current ):
                comp_addr = "&(\d+)"
                addr = re.findall(comp_addr, current['ADDR'])
                if (addr[0]): # LITERAL
                    ADDR  = '_00000000000_000000' # 17 Bits 11 + 6
                    DATA  = '0000000000000000_' + integer2bin(addr[0], 16) 
                    DF    = '11'
                    CFG = '11__' + current ['UF'] + '_00_00'
                else:
                    error = msg(4, 'cmd_REG_WR', 'No Literal value for immediate Assignation (#) in instruction ' + str(current['LINE']) )
        #### SOURCE DATA MEMORY
        elif (current ['SRC'] == 'dmem'):
            #### Get Data Source
            error, DATA, alu_op, DF = proc_SOURCE(current)
            CFG = '01__' + current ['UF'] + '_00_' + alu_op
            #### Get ADDRESS
            if error == 0:
                error, RsF, RsE, AI = proc_MEM_ADDR (current ['ADDR'])
                ADDR  = RsF + '_' + RsE
                CFG = '01__' + current ['UF'] + '_00_'+alu_op
    
        #### SOURCE WAVE MEM
        elif (current ['SRC'] == 'wmem'):
            if (current ['DST'] == 'r_wave'):
                if (COND != '000'):
                    error = msg(4, 'cmd_REG_WR', 'Wave Register Write is not conditional < -if() >  in instruction ' + str(current['LINE']) )
                else:
                    WW = WP = '0'
                    if ('WW' in current):
                        WW = '1'
                    #### WRITE PORT
                    error, WP, Sp, RdP = proc_WP(current)
                    COND = WW + Sp + WP    
                #### WRITE REGISTER
                if (error==0):
                    Wr = Rdi = '0'
                    error, Wr, Rdi, RD = proc_WR2(current)
                #### Get Data Source
                if (error==0):
                    error, DATA, alu_op, DF = proc_SOURCE(current)
                #### Get ADDRESS
                if error == 0:
                    if ('ADDR' in current):
                        error, RsF, RsE, AI = proc_MEM_ADDR (current ['ADDR'])
                        if (RsE != '000000'):
                            error = msg(4, 'cmd_REG_WR', 'Wave Memory Addres Error Source Should be LIT or Reg in instruction ' + str(current['LINE']) )                    
                        ADDR  = RsF + '_' + RdP
                    else:
                        error = msg(4, 'cmd_REG_WR', 'No addres for <wmem> source in instruction ' + str(current['LINE']) )
            else:
                error = msg(4, 'cmd_REG_WR', 'Wave Memory Source Should have a Wave Register <r_wave> Destination ' + str(current['LINE']) )                    

        else:
            error = msg(4, 'cmd_REG_WR', 'Posible REG_WR sources are (op, imm, dmem, wmem, label ) in instruction ' + str(current['LINE']) )
    ######### DESTINATION REGISTER
    if (error==0):
        comp_OP_PARAM = "r(\d+)|s(\d+)|w(\d+)|(wave)"
        RD    = re.findall(comp_OP_PARAM, current ['DST'])
        if (RD):
            if ( (current ['SRC'] == 'label') and (RD[0][1]!='s15') ):
                error = msg(3, 'cmd_REG_WR', 'Register used to Jump is s15 in instruction ' + str(current['LINE']) )
            if (RD[0][0]) :
                RD    = '00' + integer2bin(RD[0][0], 5)
            elif (RD[0][1]) :
                RD    = '10' + integer2bin(RD[0][1], 5) 
            elif (RD[0][2]) :
                RD    = '01' + integer2bin(RD[0][2], 5) 
            elif (RD[0][3]) :
                if (current ['SRC'] == 'wmem'):
                    Wr = Rdi = '0'
                    error, Wr, Rdi, RD = proc_WR2(current)
                    CFG = '10__' + current ['UF'] +'_'+ Wr + Rdi +'_'+ alu_op
                else:
                    error = msg(4, 'cmd_REG_WR', 'Wave Register Destination Should have a Wave Memory <wmem> Source ' + str(current['LINE']) )                    
        else:
            error = msg(4, 'cmd_REG_WR', 'Destination Register not Recognized (Starts with r, s or w) in instruction ' + str(current['LINE']) )
           
    if (error==0):
        CODE  = '100_' + AI + DF +'__'+ COND +'___'+ CFG +'_____'+ADDR+'_____'+DATA + '_' + RD
    else:
        CODE = 'X'
    return error, CODE

def cmd_DMEM_WR (current):
    error   = 0
    #### CONDITIONAL
    COND    = '000'
    error, COND = proc_CONDITION(current)
    #### WRITE REGISTER
    Wr = Rdi = '0'
    if (error==0):
        error, Wr, Rdi, RD = proc_WR2(current)
    #### DATA SOURCE
    if (error==0):
        error, DATA, alu_op, DF = proc_SOURCE(current)
    #### ADDRESS
    if (error==0):
        error, RsF, RsE, AI = proc_MEM_ADDR (current ['DST'])
        ADDR  = RsF + '_' + RsE
    #### SOURCE    
    if (error==0):
        if (current ['SRC'] == 'op'):
            if ('OP' in current ):
                DI = '0'
            else:
                error = msg(4, 'cmd_MEM_WR', '>  -op() option not found in instruction ' + str(current['LINE']) )
        elif (current ['SRC'] == 'imm'):
            if 'LIT' in current: 
                DI = '1'
            else:
                error = msg(4, 'cmd_MEM_WR', 'No Literal value found in instruction ' + str(current['LINE']) )
        else:
            error = msg(4, 'cmd_MEM_WR', 'Posible MEM_WR sources are (op, imm) in instruction ' + str(current['LINE']) )
    
    if (error==0):
        CFG = current['UF']+ '_'+Wr+Rdi+'_'+ alu_op
        CODE = '101_'+AI+DF+'__'+COND+'_0_'+DI+'__'+CFG+"_____"+ADDR+'_____'+DATA+'_'+RD
    else:
        CODE = 'X'
    return error, CODE


def proc_WP (cmd):
    #### WRITE PORT
    error=0
    Wp=Sp='0'
    Dp='000000'
    if ('WP' in cmd ):
        #### DESTINATION PORT
        if ('PORT' in cmd):
            Wp='1'
            Dp = integer2bin(cmd['PORT'], 6)
            if (cmd['WP'] == 'r_wave'):
                Sp = '1'
            elif (cmd['WP'] == 'wmem'):
                Sp = '0'
            else:
                error = msg(4, 'proc_WP', 'Source Wave Port not recognized (wreg, r_wave) ' + str(cmd['LINE']) )
        else:
            error = msg(4, 'proc_WP', 'Port Address not recognized < pX > ' + str(cmd['LINE']) )
    return [error, Wp, Sp, Dp]
    
    
def cmd_WMEM_WR (current):
    error   = 0
    AI=WP=TI='0'
    #### WMEM ADDRESS
    if 'DST' in current:
        Ww = '1'
        error, RsF, RsE, AI = proc_MEM_ADDR (current ['DST'])
        if (RsE != '000000'):
            error = msg(4, 'cmd_REG_WR', 'Wave Memory Addres Error Source Should be LIT or Reg in instruction ' + str(current['LINE']) )                    

    else:
        error = msg(4, 'cmd_WMEM_WR', 'No address specified in instruction ' + str(current['LINE']) )
    #### WRITE REGISTER
    Wr = Rdi = '0'
    if (error==0):
        error, Wr, Rdi, RD = proc_WR2(current)
    #### WRITE PORT
    if (error==0):
        error, Wp, Sp, Dp = proc_WP(current)
    #### DATA SOURCE
    if (error==0):
        error, DATA, alu_op, DF = proc_SOURCE(current)
    if (error==0):
        if ('TIME' in current ):
            TI='1'
            DATA = integer2bin(current['TIME'], 32)
        CFG  = '1_' + TI+'__' +current['UF'] +'_'+ Wr +Rdi +'_'+ alu_op
        CODE = '101_'+AI+DF+'__1'+Sp+Wp+'__'+CFG+"_____"+RsF+'_'+Dp+'____'+DATA+'_'+RD
    else:
        CODE = 'X'
    return error, CODE


def cmd_CFG (current):
    error   = 0
    AI=SO=TO= '0'
    ADDR = '00000000000_000000'
    #### CONDITIONAL
    COND    = '000'
    #### WRITE REGISTER
    Wr = Rdi = '0'
    if (error==0):
        error, Wr, Rdi, RD = proc_WR2(current)
    #### DATA SOURCE
    if (error==0):
        error, DATA, alu_op, DF = proc_SOURCE(current)
    if (error==0):
        CFG  = current['UF'] +'_'+ Wr + Rdi +'_'+ alu_op
        CODE = '000_'+AI+DF+'__'+COND+'_'+SO+TO+'__'+CFG+"_____"+ADDR+'_____'+DATA+'_'+RD
    else:
        CODE = 'X'
    return error, CODE




def cmd_BRANCH (current, cj):
    #print(current)
    error   = 0
    #### CONDITIONAL
    COND    = '000'
    error, COND = proc_CONDITION(current)
    #### WRITE REGISTER
    if error == 0:
        Wr = Rdi = '0'
        if (error==0):
            error, Wr, Rdi, RD = proc_WR2(current)
    #### DATA SOURCE
    if (error==0):
        error, DATA, alu_op, DF = proc_SOURCE(current)

    #### DESTINATION MEMORY ADDRESS
    if error == 0:
        if (cj =='11'): # RET CMD. ADDR came from STACK
            current['UF'] = '0'
            AI = '0'    
            ADDR = '_00000000000_000000'
        else:
            comp_addr = "&(\d+)|s(\d+)"
            addr = re.findall(comp_addr, current['ADDR'])
            if (addr[0][0]): # LITERAL
                ADDR     = '_' + integer2bin(addr[0][0], 11) + '_000000' 
                AI = '1'
            elif (addr[0][1] == '15'): #REGISTER
                ADDR     = '_00000000000_000000' 
                AI = '0'
            else:
                logger.error('[cmd_BRANCH] > JUMP Memory Address not recognized (imm or s15)')
                error = 1

    if (error==0):
        CFG = current['UF'] +'_'+ Wr+Rdi +'_'+ alu_op
        CODE = '001_'+AI+DF+'__'+COND+'__'+cj+'___'+CFG+"____"+ADDR+'____'+DATA+"_"+RD
    else:
        logger.error("[cmd_BRANCH] > Exit with Error in instruction " + str(current['LINE']) )
        CODE = 'X'
    return error, CODE




def cmd_PORT_WR (current):
    error   = 0
    if (current['CMD'] == 'DPORT_WR' or current['CMD'] == 'DPORT_RD'):
        SO=AI=Ww=S= '0'
        RsF = '00000000000'
        #### WRITE REGISTER
        if error == 0:
            Wr = Rdi = '0'
            if (error==0):
                error, Wr, Rdi, RD = proc_WR2(current)
        #### DATA SOURCE
        if (error==0):
            error, DATA, alu_op, DF = proc_SOURCE(current)
        
        if (current['CMD'] == 'DPORT_WR'):
            Wp= '0'
            if (current ['SRC'] == 'op'):
                if ('OP' in current ):
                    DI = '0'
                else:
                    error = msg(4, 'cmd_PORT_WR', 'No Operation < -op() > found in instruction ' + str(current['LINE']) )
            elif (current ['SRC'] == 'imm'):
                if 'LIT' in current: 
                    DI = '1'
                else:
                    error = msg(4, 'cmd_PORT_WR', 'No Literal value < # > found in instruction ' + str(current['LINE']) )
            else:
                error = msg(4, 'cmd_PORT_WR', 'Posible DPORT_WR sources are (op, imm) in instruction ' + str(current['LINE']) )
        else:
            DI=Wp='1'
        
    else:
        SO=Wp= '1'
        #### WRITE WAVE MEMORY
        if ('WW' in current ): 
            if 'ADDR' in current:
                Ww = '1'
                error, RsF, RsE, AI = proc_MEM_ADDR (current ['ADDR'])
                if (RsE != '000000'):
                    error = msg(4, 'cmd_REG_WR', 'Wave Memory Addres Error Source Should be LIT or Reg in instruction ' + str(current['LINE']) )                    

            else:
                error = msg(4, 'cmd_PORT_WR', 'No address specified for < -ww > in instruction ' + str(current['LINE']) )
        else:
            Ww  = '0'
            RsF = '00000000000'
        if (error==0):
            if (current['SRC'] == 'wmem'):
                if 'ADDR' in current:
                    error, RsF, RsE, AI = proc_MEM_ADDR (current ['ADDR'])
                    if (RsE != '000000'):
                        error = msg(4, 'cmd_REG_WR', 'Wave Memory Addres Error Source Should be LIT or Reg in instruction ' + str(current['LINE']) )                    
                    S = '0'
                else:
                    error = msg(4, 'cmd_PORT_WR', 'No address specified for < wmem > in instruction ' + str(current['LINE']) )
            elif (current['SRC'] == 'r_wave'):
                AI=S='1'
                RsF ='00000000000'
            else:
                error = msg(4, 'cmd_PORT_WR', 'Posible wave sources are (wmem, r_wave) in instruction ' + str(current['LINE']) )
                DF = '11'

    #### OUT TIME 
    if (error==0):
        if ('TIME' in current): 
            DI = '1'
            DF = '11'
            DATA = '____'+ integer2bin(current['TIME'], 32)
            CFG = SO+DI+'____00000'
            RD = '0000000'
            if ('WR' in current): 
                error = msg(4, 'cmd_PORT_WR', 'If time specified, Not allowed SDI <-wr()> in instruction ' + str(current['LINE']) )
        else:
            DI = '0'
            error = msg(3, 'cmd_PORT_WR', 'No time specified for command will use r_time in instruction ' + str(current['LINE']) )
            #### WRITE REGISTER
            Wr = Rdi = '0'
            if (error==0):
                error, Wr, Rdi, RD = proc_WR2(current)
            #### DATA SOURCE
            if (error==0):
                error, DATA, alu_op, DF = proc_SOURCE(current)
                CFG = SO+DI+'__'+current['UF'] +'_'+Wr+Rdi +'_'+ alu_op
    #### OUT PORT
    if (error==0):
        if ('DST' in current):
            RsE = integer2bin(current['DST'], 6)
        else:
            error = msg(4, 'cmd_PORT_WR', 'Port Address not recognized < pX > in instruction ' + str(current['LINE']) )        
    if (error == 0):
        COND = Ww+S+Wp
        ADDR  = RsF+'_'+RsE
        CODE = '110'+'_'+AI+DF+'__'+COND+'___'+CFG+ '______'+ADDR +'__'+ DATA+'_'+RD
    else:
        logger.error("[cmd_PORT_WR] > Exit with Error in instruction " + str(current['LINE']) )
        CODE = 'X'
    return error, CODE




def cmd_CTRL (current):
    error   = 0
    AI = SO ='0'
    RA0=RA1='000000'
    RD0=RD1='0_0000000'
    RE='0000000000000000'
    DF='10'
######### TIME 
    if (current ['CMD'] == 'TIME'):
        CTRL      = '00001'
        if   (current['DST'] == 'rst'):
            OPERATION = '00001'
        elif (current['DST'] == 'set_ref'):
            OPERATION = '00010'
        elif (current['DST'] == 'inc_ref'):
            OPERATION = '00100'
        elif (current['DST'] == 'set_cmp'):
            OPERATION = '01000'
        else:
            error = msg(4, 'cmd_TIME', 'Posible Operations for TIME command are (rst, set_ref, inc_ref, set_cmp)' )
        if ('LIT' in current ):
            DF='11'
            RD1 = '_'+integer2bin(current['LIT'], 24)
            RE=''
        elif ('SRC' in current):
            error, RD1 = get_reg_addr (current['SRC'], 'Source')
        else: 
            if   (current['DST']!='rst'):
                error = msg(4, 'cmd_TIME', 'No Data' )

            ######### CONDITION
    elif (current ['CMD'] == 'COND'):
        CTRL      = '00010'
        if   (current['SRC'] == 'set'):
            OPERATION = '00001'
        elif (current['SRC'] == 'clear'):
            OPERATION = '00010'
        else:
            error = msg(4, 'cmd_TIME', 'Posible Operations for COND command are (set, clear)' )

######### DIVISION
    elif (current ['CMD'] == 'DIV'):
        CTRL      = '01000'
        OPERATION = '00001'
        if ('NUM' in current ):
            error, RD0 = get_reg_addr (current['NUM'], 'Source')
        if (error == 0) and ('DEN' in current ):
            comp_den = "(\d+)|r(\d+)"
            den = re.findall(comp_den, current['DEN'])
            if (den[0][0]): # LITERAL
                DF='11'
                RD1 = '_'+integer2bin(current['DEN'], 24)
                RE=''
            elif (den[0][1]): #REGISTER
                error, RD1 = get_reg_addr (current['DEN'], 'Source')

            else:
                logger.error('[cmd_BRANCH] > JUMP Memory Address not recognized (imm or s15)')
                error = 1

    if (error):
        logger.error('Error in instruction ' + str(current['LINE']) )
        CODE = 'X'
    else:
        CODE = '111_'+AI+DF+'______'+OPERATION+'___'+CTRL+'_____00000___'+RA0+'_'+RA1+'__'+RD0+'__'+RD1+'_'+RE+'_0000000'
    return error, CODE

def cmd_ARITH (current):
    error   = 0
    RsC=RsD='000000'
    if ('LIT' in current):
            error = msg(4, 'cmd_ARITH', 'No Immediate value allowed ' )
    if ('OP' in current):
        if (current['OP'] in arithList ):
            ARITH_OP = arithList[current['OP']]
        else:
            error = msg(4, 'cmd_ARITH', 'No Recognized Operation Posible Operations for ARITH are (P, M, T, PT, MP, PTP, PTM, MTP, MTM)' )
    else:
        error = msg(4, 'cmd_ARITH', 'No ARITH Operation ' )
    if (error==0):
        if (ARITH_OP[1] == '1'):
            if ('R1' in current and 'R2' in current and 'R3' in current):
                error, RsD = get_reg_addr (current['R1'], 'Addr')
                error, RsA = get_reg_addr (current['R2'], 'Source')
                error, RsB = get_reg_addr (current['R3'], 'Source')
            else:
                error = msg(4, 'cmd_ARITH', 'Few Sources Registers' )
            if (ARITH_OP[3] == '1'):
                if ('R4' in current):
                    error, RsC = get_reg_addr (current['R4'], 'Addr')
        else:
            if ('R1' in current and 'R2' in current):
                RsD = '000000'
                error, RsA = get_reg_addr (current['R1'], 'Source')
                error, RsB = get_reg_addr (current['R2'], 'Source')
            else:
                error = msg(4, 'cmd_ARITH', 'Few Sources Registers' )
            if (ARITH_OP[3] == '1'):
                if ('R3' in current):
                    error, RsC = get_reg_addr (current['R3'], 'Addr')
    if (error==0):
        CODE = '111_000______'+ARITH_OP +'___00100_____00000___'+RsC+'__'+RsD+'__'+RsA+'__'+RsB+'___0000000000000000_0000000'
    else:
        logger.error("[cmd_ARITH] > Exit with Error in instruction " + str(current['LINE']) )
        CODE = 'X'
    return error, CODE
    
    AI = '0'

    return error, CODE

