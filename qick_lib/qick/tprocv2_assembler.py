"""
///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Date           : 10-2023
//  Version        : 2
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


Beta-Release (June 2023)
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
        'REG_WR'     : '100 - Register Write',
        'DMEM_WR'    : '101 - Data Memory Write',
        'WMEM_WR'    : '101 - WaveParam Memory Write',
        'TRIG'       : '110 - Trigger Set',
        'DPORT_WR'   : '110 - Data Port Write',
        'DPORT_RD'   : '110 - Data Port Read',
        'WPORT_WR'   : '110 - WaveParam Port Write',
        'JUMP'       : '001 - Branch to a Specific Address',
        'CALL'       : '001 - Function Call',
        'RET'        : '001 - Function Return',
        'FLAG'       : '111 - FLAG set / reset',
        'TIME'       : '111 - Time Instruction',
        'ARITH'      : '111 - Opeates (A+/-B)*C+/-D',
        'DIV'        : '111 - Opeates (A/B) Return Quotient and Reminder',
        'NET'        : '111 - Net Instruction',
        'CUSTOM'     : '111 - Cutsom Peripheral Instruction',
        'WAIT'       : '001 - Jump [HERE] Until time value arrives.'
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
'T'   : '00000', #  A*B
'TP'  : '00001', #  A*B+C
'TM'  : '00010', #  A*B-C
'PT'  : '00011', # (D+A)*B
'PTP' : '00100', # (D+A)*B+C
'PTM' : '00101', # (D+A)*B-C
'MT'  : '00110', # (D-A)*B
'MTP' : '00111', # (D-A)*B+C
'MTM' : '01000', # (D-A)*B-C

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
    'TIME'      : {'RegEx' : r'(?<=@)[0-9]+'                 , 'RL': '@'        , 'RR': ''   },
    'ADDR'      : {'RegEx' : r'\[(.*)\]'                     , 'RL': '['        , 'RR': ']'  },
    'UF'        : {'RegEx' : r'-uf'                          , 'RL': ''         , 'RR': ''   },
    'WW'        : {'RegEx' : r'-ww'                          , 'RL': ''         , 'RR': ''   },
    'WP'        : {'RegEx' : r'-wp\(([_a-z\s]*)\)'           , 'RL': '-wp('     , 'RR': ')'  },
    'OP'        : {'RegEx' : r'-op\(([\s#a-zA-Z0-9+\-<>]*)\)', 'RL': '-op('     , 'RR': ')'  }, 
    'IF'        : {'RegEx' : r'-if\(([A-Z\s]*)\)'            , 'RL': '-if('     , 'RR': ')'  },
    'WR'        : {'RegEx' : r'-wr\(([a-z\s0-9]*)\)'         , 'RL': '-wr('     , 'RR': ')'  },
    'PORT'      : {'RegEx' : r'p([0-9]+)'                    , 'RL': 'p'        , 'RR': ''   },
    'LIT'       : {'RegEx' : r'(?<=#)[ubh0-9ABCDEF\-]+'      , 'RL': '#'        , 'RR': ''   },
}

Alias_List = { 
## REGISTERS
    'W_FREQ'      : {'RegEx' : r'w_freq'                , 'R': 'w0'        },
    'W_PHASE'     : {'RegEx' : r'w_phase'               , 'R': 'w1'        },
    'W_ENV'       : {'RegEx' : r'w_env'                 , 'R': 'w2'        },
    'W_GAIN'      : {'RegEx' : r'w_gain'                , 'R': 'w3'        },
    'W_LENGHT'    : {'RegEx' : r'w_length'              , 'R': 'w4'        },
    'W_CONF'      : {'RegEx' : r'w_conf'                , 'R': 'w5'        },
    'ZERO'        : {'RegEx' : r'zero'                  , 'R': 's0'        },
    'RAND'        : {'RegEx' : r'rand'                  , 'R': 's1'        },
    'CONF'        : {'RegEx' : r's_conf|s_ctrl'         , 'R': 's2'        },
    'STATUS'      : {'RegEx' : r's_status'              , 'R': 's3'        },
    'DIVQ'        : {'RegEx' : r'div_q'                 , 'R': 's4'        },
    'DIVR'        : {'RegEx' : r'div_r'                 , 'R': 's5'        },
    'ARITHL'      : {'RegEx' : r'arith_l'               , 'R': 's6'        },
    'CORE_R1'     : {'RegEx' : r'core_r1'               , 'R': 's7'        },
    'CORE_R2'     : {'RegEx' : r'core_r2'               , 'R': 's8'        },
    'PORTL'       : {'RegEx' : r'port_l'                , 'R': 's9'        },
    'PORTH'       : {'RegEx' : r'port_h'                , 'R': 's10'       },
    'TUSER'       : {'RegEx' : r'curr_usr_time|tuser'   , 'R': 's11'       },
    'CORE_W1'     : {'RegEx' : r'core_w1'               , 'R': 's12'       },
    'CORE_W2'     : {'RegEx' : r'core_w2'               , 'R': 's13'       },
    'TIME'        : {'RegEx' : r'out_usr_time|r_time|s_time' , 'R': 's14'  },
    'ADDR'        : {'RegEx' : r's_addr|r_addr'         , 'R': 's15'       },
## Values
    'SRC_0'        : {'RegEx' : r'src_tproc'         , 'R': '#0'       },
    'SRC_3'        : {'RegEx' : r'src_arith'         , 'R': '#3'       },
    'SRC_4'        : {'RegEx' : r'src_qnet'          , 'R': '#4'       },
    'SRC_5'        : {'RegEx' : r'src_periph'        , 'R': '#5'       },
    'FLAG_0'       : {'RegEx' : r'flag_int'         , 'R': '#0'       },
    'FLAG_1'       : {'RegEx' : r'flag_axi'         , 'R': '#8'       },
    'FLAG_2'       : {'RegEx' : r'flag_ext'         , 'R': '#16'       },
    'FLAG_3'       : {'RegEx' : r'flag_div'         , 'R': '#24'       },
    'FLAG_4'       : {'RegEx' : r'flag_arith'       , 'R': '#32'       },
    'FLAG_5'       : {'RegEx' : r'flag_port'        , 'R': '#40'       },
    'FLAG_6'       : {'RegEx' : r'flag_qnet'        , 'R': '#48'       },
    'FLAG_7'       : {'RegEx' : r'flag_periph'      , 'R': '#56'       },
## CMDS
    'CLR_ARITH'     : {'RegEx' : r'clr_arith'       , 'R': '#65536'       },
    'CLR_DIV'       : {'RegEx' : r'clr_div'         , 'R': '#131072'       },
    'CLR_QNET'      : {'RegEx' : r'clr_qnet'        , 'R': '#262144'       },
    'CLR_PERIPH'    : {'RegEx' : r'clr_periph'      , 'R': '#524288'       },
    'CLR_PORT'      : {'RegEx' : r'clr_port'        , 'R': '#1048576'      },
    'CLR_ALL'       : {'RegEx' : r'clr_all'         , 'R': '#2031616'      },

}

regex = {
    'LABEL'     : r'[A-Za-z0-9_]+(?=\:)',
    'CMD'       : r'^[A-Z_]+',
    'DIRECTIVE' : r'(?<=\.)[A-Z]+',
    'LIT'       : r'(?<=#)[0-9]+',
    'CDS'       : r'\s*([\w&\+\']+)'}


import re

###  CUSTOM LOGGER ###
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
            raise ValueError(f"Logger.setLevel: show_level must be samller than 2 (0-INFO, 1-WARNINGS, 2-ERRORS)")
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
            assembler += f"#{command['LIT']} "       if ('LIT'      in command) else ''
            assembler += f"-op({command['OP']}) "    if ('OP'       in command) else ''
            assembler += "-uf "      if ('UF' in command and command['UF']=='1') else ''
            assembler += "-ww "                       if ('WW'       in command) else ''
            assembler += f"-wp({command['WP']}) "    if ('WP'       in command) else ''
            assembler += f"p{command['PORT']} "      if ('PORT'     in command) else ''
            assembler += f"@{command['TIME']} "      if ('TIME'       in command) else ''


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
        for address, command in enumerate(program_list, start=1):
            # CHECK FOR LABEL IN THAT MEMORY PLACE
            address = program_list['P_ADDR'] if ('P_ADDR' in program_list) else address # set correct instruction address in memory.
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
            # Check if LABEL< DIRETIVE OR INSTRUCTION
            for line_number, command in enumerate(file_lines, start=1):
                label = find_pattern(regex['LABEL'], command)
                directive   = find_pattern(regex['DIRECTIVE'], command)
                instruction  = find_pattern(regex['CMD'], command)
                if (label): # add label to label_dict if not already registered.
                    if label in label_dict:
                        if (label == 'reg'):
                            error = Logger.error('LABEL_RECOGNITION', 'reg is not a valid label in line > ' + str(line_number) )
                        else:
                            error = Logger.error('LABEL_RECOGNITION', 'Redefinition of LABEL "' + label + '" in line > ' + str(line_number) )
                    else:
                        label_dict[label] = '&' + str(mem_addr)
                        label_line_idxs.append(line_number)
                elif (directive):  # identify Aliases and adds them to Alias_List.
                    if ( directive == 'ALIAS'):
                        directives = re.findall(regex['CDS'], command)
                        Name     = 'ALIAS_' + directives[1]
                        RegEx    = directives[1]
                        Register = directives[2]
                        comp_PARAM = "s(\d+)|r(\d+)|w(\d+)"
                        alias_reg  = re.findall(comp_PARAM, Register)
                        if (alias_reg):
                            Alias_List.update({Name : {'RegEx' : RegEx , 'R': Register } } )        
                            Logger.info("ALIAS_RECOGNITION",' > ' + Register + ' is called ' + RegEx)
                        else:
                            error = Logger.error('ALIAS_RECOGNITION', 'Alias Register not recognized.')
                    elif ( directive == 'CONST'):
                        directives = re.findall(regex['CDS'], command)
                        Name     = 'CONS_' + directives[1]
                        RegEx    = directives[1]
                        Value    = directives[2]
                        comp_PARAM = r'[0-9]+'
                        cons_val   = re.findall(comp_PARAM, Value)
                        if (cons_val):
                            Alias_List.update({Name : {'RegEx' : RegEx , 'R': '#'+Value } } )        
                            Logger.info("CONSTANT_RECOGNITION",' > ' + Value + ' is called ' + RegEx)
                        else:
                            error = Logger.error('CONSTANT_RECOGNITION', 'CONST Value not recognized.')
                    elif ( directive == 'ADDR'):
                        directives = re.findall(regex['CDS'], command)
                        Name     = 'ADDR_' + directives[1]
                        Value    = int(directives[1])
                        distance = Value - mem_addr
                        if  (distance < 0):
                            error = Logger.error('DIRECTIVE', 'New Memory Address '+str(Value)+ ' before than next empty '+str(mem_addr)+' in Line > ' + str(line_number))
                        else :                          
                            mem_addr = Value
                       
                        
                    elif ( directive == 'END'):
                        mem_addr += 1            
                elif (instruction): # Identify instructions to correctly set addresses.
                    if ( instruction in instList.keys() ) :
                        if (instruction == 'WAIT'):
                            mem_addr += 2
                        else:                            
                            mem_addr += 1
                    else:
                        error = Logger.error('LABEL_RECOGNITION', 'Command Not Recognized in Line > ' + str(line_number))
            show_info =  ('\n## ALIAS LIST')
            show_info += '\n' + ('###############################')
            show_info += '\n' + ('REG  > ALIAS NAME\n-----|-------------')
            for key in Alias_List:
                show_info += '\n' + str( (f"{Alias_List[key]['R']:<3}" + ' > '+ Alias_List[key]['RegEx']) )
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
           
            program_list = []
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
                    elif ( directive == 'ADDR'):
                        directives = re.findall(regex['CDS'], command)
                        Name     = 'ADDR_' + directives[1]
                        Value    = int(directives[1])
                        distance = Value - mem_addr
                        if  (distance < 1):
                            error = Logger.error('DIRECTIVE', 'Memory Address is before than last command >' + str(line_number))
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
                            error = Logger.error('COMMAND_RECOGNITION', 'Literals not equals in Line >' + str(line_number))
                        
                        # CHANGE ALIAS 
                        ###############################################################
                        for key in Alias_List:
                            CHANGE = find_pattern(Alias_List[key]['RegEx'], command)
                            command = command.replace(CHANGE, Alias_List[key]['R']) if CHANGE else command
                            
                        # Extract PARAMETERS
                        ###############################################################
                        if (error == 0):
                            command_info['LINE'] = line_number # Stores Line Number for ERROR Messages
                            for key in Param_List:
                                PARAM = re.findall(Param_List[key]['RegEx'], command)
                                if PARAM:
                                    if (len(PARAM) >1):
                                        error = Logger.error('COMMAND_RECOGNITION', 'Duplicated Parameter ' + key +' in line > '+str(line_number))
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
                                if (command_info['LIT'][0] == 'b'):
                                    try:
                                        command_info['LIT'] = str(int(command_info['LIT'][1:],2))
                                    except ValueError:
                                        error = Logger.error("COMMAND_RECOGNITION", "Binary value incorrect in Line " + str(line_number))
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


                            if ( (CMD_DEST_SOURCE[0] == 'NOP')   \
                              or (CMD_DEST_SOURCE[0] == 'ARITH') or (CMD_DEST_SOURCE[0] == 'DIV') \
                              or (CMD_DEST_SOURCE[0] == 'RET') \
                              or (CMD_DEST_SOURCE[0] == 'TIME')  or (CMD_DEST_SOURCE[0] == 'TEST') or (CMD_DEST_SOURCE[0] == 'FLAG') \
                              or (CMD_DEST_SOURCE[0] == 'NET')   or (CMD_DEST_SOURCE[0] == 'CUSTOM') or (CMD_DEST_SOURCE[0] == 'NET') ):
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
                            ###########################################################
                            elif ( (CMD_DEST_SOURCE[0] == 'OUT_DATA') or (CMD_DEST_SOURCE[0] == 'OUT_WAVE') ):
                                if ('IF' in command_info):
                                    error = Logger.error("COMMAND_RECOGNITION", "Not allowed Conditional < -if() > with Port Writting cmd in Line " + str(line_number))
                                if ('WR' in command_info):
                                    error = Logger.error("COMMAND_RECOGNITION", "Not allowed Write Register < -wr() > with Port Writting cmd in Line " + str(line_number))


                        # GET COMMAND DESTINATION SOURCE
                        ###############################################################
                        if (error == 0):
                            CMD_DEST_SOURCE = re.findall(regex['CDS'], command)
                            command_info['CMD'] = CMD_DEST_SOURCE[0]
                            ## MORE THAN ONE SOURCE
                            if ( len(CMD_DEST_SOURCE) > 3) :
                                if (CMD_DEST_SOURCE[0] == 'ARITH') :
                                    command_info['C_OP']  = CMD_DEST_SOURCE[1]
                                    command_info['R1']  = CMD_DEST_SOURCE[2]
                                    command_info['R2']  = CMD_DEST_SOURCE[3]
                                    if ( len(CMD_DEST_SOURCE) > 4) :
                                        command_info['R3'] = CMD_DEST_SOURCE[4]
                                    if ( len(CMD_DEST_SOURCE) > 5) :
                                        command_info['R4'] = CMD_DEST_SOURCE[5]
                                elif (CMD_DEST_SOURCE[0] =='CUSTOM') :
                                    if (len(CMD_DEST_SOURCE) == 6):
                                        command_info['C_OP']  = CMD_DEST_SOURCE[1]
                                        command_info['R1']  = CMD_DEST_SOURCE[2]
                                        command_info['R2']  = CMD_DEST_SOURCE[3]
                                        command_info['R3']  = CMD_DEST_SOURCE[4]
                                        command_info['R4']  = CMD_DEST_SOURCE[5]
                                    else:
                                        error = Logger.error("COMMAND_RECOGNITION", "CUSTOM Command Should have Op and 4 parameters in line " + str(line_number) + " (possible missing [])")
                                elif (CMD_DEST_SOURCE[0] == 'REG_WR') and (CMD_DEST_SOURCE[2] == 'label' ) :
                                    command_info['DST'] = CMD_DEST_SOURCE[1]
                                    command_info['SRC'] = CMD_DEST_SOURCE[2]
                                    if (CMD_DEST_SOURCE[3] in label_dict ) :
                                        command_info['ADDR'] = label_dict[CMD_DEST_SOURCE[3]]
                                        error = Logger.info('COMMAND_RECOGNITION', 'REG_WR command source label: '+CMD_DEST_SOURCE[3] +' replaced by value ' + command_info['ADDR'] + '  in line ' + str(line_number))
                                    else:
                                        error = Logger.error('COMMAND_RECOGNITION', 'Label: '+CMD_DEST_SOURCE[3]+' Not defined in line ' + str(line_number))
                                else:
                                    print ('Command Info',command_info)
                                    print ('Command Destination Source',CMD_DEST_SOURCE)
                                    error = Logger.error("COMMAND_RECOGNITION", "Parameter Error in line " + str(line_number) )
                            ## ONE SOURCE
                            elif ( len(CMD_DEST_SOURCE) == 3) :
                                if (CMD_DEST_SOURCE[0] == 'REG_WR'):
                                   if (CMD_DEST_SOURCE[2] == 'label' ) :
                                        error = Logger.error("COMMAND_RECOGNITION", "Missing label in line " + str(line_number))
                                   else:
                                       command_info['DST'] = CMD_DEST_SOURCE[1]
                                       command_info['SRC'] = CMD_DEST_SOURCE[2]        
                                elif (CMD_DEST_SOURCE[0] =='DPORT_WR' ) :
                                    if ( int(command_info['PORT'])  > 7):
                                        error = Logger.error("COMMAND_RECOGNITION", "Data Port max value is 7 in line " + str(line_number))
                                    else:
                                        command_info['DST'] = command_info['PORT']
                                        command_info.pop('PORT') 
                                    command_info['SRC'] = CMD_DEST_SOURCE[1]
                                    command_info['DATA'] = CMD_DEST_SOURCE[2]        

                                elif ( (CMD_DEST_SOURCE[0] == 'TIME') \
                                or     (CMD_DEST_SOURCE[0] == 'OUT_DATA')):
                                    command_info['DST'] = CMD_DEST_SOURCE[1]
                                    command_info['SRC'] = CMD_DEST_SOURCE[2]        
                                elif (CMD_DEST_SOURCE[0] == 'DIV') :
                                    command_info['NUM'] = CMD_DEST_SOURCE[1]
                                    command_info['DEN'] = CMD_DEST_SOURCE[2]        
                                else:
                                    print ('Command Info',command_info)
                                    print ('Command Destination Source',CMD_DEST_SOURCE)
                                    error = Logger.error("COMMAND_RECOGNITION", "Parameter Error in line " + str(line_number) )

                            ## NO SOURCE OR -- SOURCE IN EXTRACTED PARAMETER
                            elif ( len(CMD_DEST_SOURCE) == 2) :
                                if (CMD_DEST_SOURCE[0] =='DMEM_WR' ) :
                                    command_info['SRC'] = CMD_DEST_SOURCE[1]     
                                    command_info['DST'] = '[' + command_info['ADDR'] + ']'     
                                    command_info.pop('ADDR')     
                                elif (CMD_DEST_SOURCE[0] =='TRIG'):
                                    command_info['CMD'] = CMD_DEST_SOURCE[0]
                                    command_info['SRC'] = CMD_DEST_SOURCE[1]
                                    if ( int(command_info['PORT'])  > 7):
                                        error = Logger.error("COMMAND_RECOGNITION", "Trigger Port max value is 7 in line " + str(line_number))
                                    else:
                                        command_info['DST'] = command_info['PORT']
                                        command_info.pop('PORT') 
                                elif (CMD_DEST_SOURCE[0] =='WPORT_WR'):
                                    command_info['CMD'] = CMD_DEST_SOURCE[0]
                                    command_info['SRC'] = CMD_DEST_SOURCE[1]
                                    if ( int(command_info['PORT'])  > 15):
                                        error = Logger.error("COMMAND_RECOGNITION", "Wave Port Port max value is 15 in line " + str(line_number))
                                    else:
                                        command_info['DST'] = command_info['PORT']
                                        command_info.pop('PORT') 
#                                elif (CMD_DEST_SOURCE[0] =='WPORT_WR') :
#                                    command_info['SRC'] = CMD_DEST_SOURCE[1]
#                                    command_info['DST'] = command_info['PORT'] 
                                elif (CMD_DEST_SOURCE[0] =='FLAG') :
                                    command_info['SRC'] = CMD_DEST_SOURCE[1]     
                                elif (CMD_DEST_SOURCE[0] =='NET') :
                                    command_info['SRC'] = CMD_DEST_SOURCE[1]     
                                elif (CMD_DEST_SOURCE[0]=='TIME'): # DST is ADDR
                                        command_info['CMD'] = CMD_DEST_SOURCE[0]     
                                        command_info['DST'] = CMD_DEST_SOURCE[1]     
                                elif (CMD_DEST_SOURCE[0]=='DIV'): 
                                    if ('LIT' in command_info):
                                        command_info['CMD'] = CMD_DEST_SOURCE[0]     
                                        command_info['NUM'] = CMD_DEST_SOURCE[1]     
                                    else:
                                        error = Logger.error("COMMAND_RECOGNITION", "Dividend Parameter Error in line " + str(line_number))
                                elif (CMD_DEST_SOURCE[0]=='JUMP' or CMD_DEST_SOURCE[0]=='CALL'):
                                    command_info['CMD'] = CMD_DEST_SOURCE[0]
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
                                else:
                                    print ('Command Info',command_info)
                                    print ('Command Destination Source',CMD_DEST_SOURCE)
                                    error = Logger.error("COMMAND_RECOGNITION", "Parameter Error in line " + str(line_number))
                            ## NO DESTINATION OR -- DESTINATION / SOURCE IN EXTRACTED PARAMETER
                            elif ( len(CMD_DEST_SOURCE) == 1):
                                if (CMD_DEST_SOURCE[0] =='NOP')       \
                                or (CMD_DEST_SOURCE[0] =='ARITH')     \
                                or (CMD_DEST_SOURCE[0] =='TEST')      \
                                or (CMD_DEST_SOURCE[0] =='RET')       :
                                    command_info['CMD'] = CMD_DEST_SOURCE[0]     
                                elif (CMD_DEST_SOURCE[0] =='DPORT_RD') :
                                    command_info['CMD'] = CMD_DEST_SOURCE[0]     
                                    if ('PORT' in command_info):
                                        if ( int(command_info['PORT'])  > 7):
                                            error = Logger.error("COMMAND_RECOGNITION", "Data Port Read max value is 7 in line " + str(line_number))
                                        else:
                                            command_info['DST'] = command_info['PORT']
                                            command_info.pop('PORT') 
                                    else:
                                        error = Logger.error("COMMAND_RECOGNITION", "No Port for DPORT_RD in line " + str(line_number))

                                elif (CMD_DEST_SOURCE[0]=='WMEM_WR'):
                                    command_info['CMD'] = CMD_DEST_SOURCE[0]     
                                    if ('ADDR' in command_info):
                                        command_info['DST'] = '[' + command_info['ADDR'] + ']'     
                                        command_info.pop('ADDR') 
                                    else:
                                        error = Logger.error("COMMAND_RECOGNITION", "No Address for WMEM_WR in line " + str(line_number))
                                elif ( (CMD_DEST_SOURCE[0]=='JUMP') or (CMD_DEST_SOURCE[0]=='CALL')):
                                    if ('ADDR' in command_info):
                                        command_info['CMD'] = CMD_DEST_SOURCE[0]
                                        command_info['ADDR'] = command_info['ADDR']
                                    else:
                                        error = Logger.error("COMMAND_RECOGNITION", "Address Parameter Error in line " + str(line_number))
                                elif (CMD_DEST_SOURCE[0]=='WAIT'):
                                    Logger.info("COMMAND_RECOGNITION", "IS WAIT adding Instruction")
                                    command_info['CMD']    = CMD_DEST_SOURCE[0]
                                    command_info['P_ADDR'] = mem_addr
                                    mem_addr = mem_addr + 1            
                                else:
                                    print ('Command Info',command_info)
                                    print ('Command Destination Source',CMD_DEST_SOURCE)
                                    error = Logger.error("COMMAND_RECOGNITION", "Parameter Error in line " + str(line_number))
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
                    error = Logger.error("COMMAND_RECOGNITION", "Not a Command in Line >" + str(line_number))
            return (error, program_list)
        
        
        ##### START ASSEMBLER TO LIST
        Logger.info("ASM2LIST", "##### STEP_1 - LABEL RECOGNITION")
        error, label_dict = label_recognition(asm_str)
        
        if (error):
            Logger.warning("LABEL_RECOGNITION", "Errors found!")
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
        binary_program_list = ['000_000__000___00__0_00_00______00000000000_000000_________00000000000000000000000000000000_0000000']
        error = 0
        CODE = 'x'
        for command in program_list:
            if ('CMD' in command):
                if not ('UF' in command):
                    command['UF'] = '0'
            ###############################################################################
                if command['CMD'] == 'NOP':
                    CODE = '000_000__000___00__0_00_00______00000000000_000000_________00000000000000000000000000000000_0000000'
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
                elif command['CMD'] == 'JUMP':
                    error, CODE = Instruction.BRANCH(command, '00')
            ###############################################################################
                elif command['CMD'] == 'WAIT':
                    error, CODE = Instruction.WAIT(command)
            ###############################################################################
                elif command['CMD'] == 'CALL':
                    error, CODE = Instruction.BRANCH(command, '10')
            ###############################################################################
                elif command['CMD'] == 'RET':
                    error, CODE = Instruction.BRANCH(command, '11')
            ###############################################################################
                elif command['CMD']=='DPORT_WR' or command['CMD'] == 'DPORT_RD' or command['CMD'] == 'WPORT_WR':
                    error, CODE = Instruction.PORT_WR(command)
            ###############################################################################
                elif command['CMD']=='TRIG':
                    error, CODE = Instruction.PORT_WR(command)
            ###############################################################################
                elif command['CMD'] == 'TIME':
                    error, CODE = Instruction.CTRL(command)
            ###############################################################################
                elif command['CMD'] == 'TEST':
                    command['UF'] = '1'
                    error, CODE = Instruction.CFG(command)
            ###############################################################################
                elif command['CMD'] == 'DIV':
                    error, CODE = Instruction.CTRL(command)
            ###############################################################################
                elif command['CMD'] == 'FLAG':
                    error, CODE = Instruction.CTRL(command)
            ###############################################################################
                elif command['CMD'] == 'NET':
                    error, CODE = Instruction.CTRL(command)
            ###############################################################################
                elif command['CMD'] == 'CUSTOM':
                    error, CODE = Instruction.CTRL(command)
            ###############################################################################
                elif command['CMD'] == 'ARITH':
                    error, CODE = Instruction.ARITH(command)
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


def get_reg_addr (reg : str, Type : str) -> tuple:
    """
    :returns (tuple): (error, register_address).
    """
    error = 0
    REG = re.findall('s(\d+)|r(\d+)|w(\d+)', reg)
    if (REG):
        REG = REG[0]
        if (Type=='Source'):
            if (REG[0]): ## is SREG 
                reg_addr =  '0_00'+integer2bin(REG[0], 5)   
            elif (REG[1]): ## is DREG 
                reg_addr     = '0_01'+integer2bin(REG[1], 5)     
            elif (REG[2]): ## is WREG
                reg_addr     = '0_10'+integer2bin(REG[2], 5)     
        elif (Type=='Dest'):
            if (REG[0]): ## is SREG
                reg_addr =  '00'+integer2bin(REG[0], 5)   
            elif (REG[1]): ## is DREG
                reg_addr     = '01'+integer2bin(REG[1], 5)     
            elif (REG[2]): ## is WREG
                reg_addr     = '10'+integer2bin(REG[2], 5)
        elif (Type=='Addr'):
            if (REG[0]): ## is SREG
                reg_addr =  '0'+integer2bin(REG[0], 5)   
            elif (REG[1]): ## is DREG
                reg_addr =  '1'+integer2bin(REG[1], 5)   
            elif (REG[2]): ## W_Reg
                reg_addr     = 'X'
                error = Logger.error('get_reg_addr', 'Register w'+ str(REG[2])+' Can not be wreg' )
    else:
        reg_addr     = 'X'
        error = Logger.error('get_reg_addr', 'Register not Recognized (Registers Starts with r, s or w) ' )
    
    return [error, reg_addr]
  
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
                        error = Logger.error('Parameter.WR', 'Pperation < -op() > option not found in instruction ' + str(command['LINE']) )
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
            error = 0
            comp_OP_PARAM = "s(\d+)|r(\d+)|w(\d+)|#(-?\d+)|#u(\d+)|#b(\d+)|#h([0-9A-F]{4})|\s*([A-Z]{3}|[A-Z><]{2}|\+|\-)"
            param_op  = re.findall(comp_OP_PARAM, command['OP'])
            DataImm = rsD1 = '' 
            if (len(param_op)==1 ) : # COPY REG
                df          = '01'
                rsD1         = '0_0000000'
                if ('LIT' in command):
                    DataImm = '_'+integer2bin(command ['LIT'], 16)
                else:
                    DataImm     = '0000000000000000'
                if FULL:
                    alu_op      = '0000'
                else:
                    alu_op      = '00'
                ## CHECK FOR ONLY OPERAND (COPY REG) (ADD S0)
                if (param_op[0][0]): ## is SREG
                    rsD0     = '0_00'+integer2bin(param_op[0][0], 5)     
                elif (param_op[0][1]): ## is DREG
                    rsD0     = '0_01'+integer2bin(param_op[0][1], 5)     
                elif (param_op[0][2]): ## is WREG
                    rsD0     = '0_10'+integer2bin(param_op[0][2], 5)     
                elif (param_op[0][3] or param_op[0][4] or param_op[0][5] or param_op[0][6] ):#is Signed,Unsigned,Binary,Hexa
                    error = Logger.error('Parameter.SRC', 'Operand can not be a Literal.')
                else:
                    error = Logger.error('Parameter.SRC', 'Operand not recognized.')
            elif (len(param_op)==2 ) :
                operation = param_op[0][7]
                if (FULL):
                    if (operation in aluList_op) : #ALU LIST ONE PARAMETER
                        df          = '10'
                        alu_op      = aluList[param_op[0][7]]
                        DataImm     = '000000000000000000000000'
                        ## CHECK FOR OPERAND (ALU_IN_A > rsD)
                        if (param_op[1][0]): ## is SREG
                            rsD0     = '0_00'+integer2bin(param_op[1][0], 5)     
                        elif (param_op[1][1]): ## is DREG
                            rsD0     = '0_01'+integer2bin(param_op[1][1], 5)     
                        elif (param_op[1][2]): ## is WREG
                            rsD0     = '0_10'+integer2bin(param_op[1][2], 5)     
                        elif (param_op[1][3] or param_op[1][4] or param_op[1][5] or param_op[1][6] ):#is Signed,Unsigned,Binary,Hexa
                            error = Logger.error('Parameter.SRC', 'Operand can not be a Literal in instruction ' + str(command['LINE']) )
                    else:
                        error = Logger.error('Parameter.SRC', 'Operation Not Recognized > ' + str(command['OP']) )
                else:
                    error = Logger.error('Parameter.SRC', '1-Operation Not Allowed > ' + str(command['OP']) +' in instruction ' + str(command['LINE']) ) 
                ## ABS Should be on rsD1
                if (param_op[0][7] == 'ABS') :
                    df          = '01'
                    rsD1         = rsD0
                    rsD0         = '0_0000000'
                    DataImm     = '0000000000000000'

            elif (len(param_op)==3 ) :
                ## CHECK FOR FIRST OPERAND (ALU_IN_A > rsD)
                if (param_op[0][0]): ## is SREG
                    rsD0     = '0_00'+integer2bin(param_op[0][0], 5)     
                elif (param_op[0][1]): ## is DREG
                    rsD0     = '0_01'+integer2bin(param_op[0][1], 5)     
                elif (param_op[0][2]): ## is WREG
                    rsD0     = '0_10'+integer2bin(param_op[0][2], 5)     
                elif (param_op[0][3] or param_op[0][4] or param_op[0][5] or param_op[0][6] ):#is Signed,Unsigned,Binary,Hexa
                    error = Logger.error('Parameter.SRC', 'First Operand can not be a Literal.')
                else:
                    error = Logger.error('Parameter.SRC', 'First Operand not recognized.')
                ## CHECK FOR SECOND OPERAND (ALU_IN_B > Imm|rsC)
                if (error == 0):
                    if ( (param_op[2][0]) or (param_op[2][1]) or (param_op[2][2]) ): ## REG OP REG
                        if ('LIT' in command):
                            Logger.info('Parameter.SRC', 'With < -op() > imm value should be 16 Bits in instruction ' + str(command['LINE']) )
                            if ( int(command ['LIT']) >= 65535):
                                error = Logger.error('Parameter.SRC',  ('Literal '+ command ['LIT'] + ' should be 16 Bits.') )
                            else:
                                Logger.info("Parameter.SRC", "[OK] Literal " + command ['LIT'] + " can be represented with 16 Bits.")
                                df    = '01'
                                DataImm = integer2bin(command ['LIT'], 16)
                        else:
                            DataImm = '0000000000000000'
                        if (param_op[2][0]): ## is SREG
                            df = '01'
                            rsD1     = '0_00'+integer2bin(param_op[2][0], 5)   
                        elif (param_op[2][1]): ## is DREG
                            df = '01'
                            rsD1     = '0_01'+integer2bin(param_op[2][1], 5)     
                        elif (param_op[2][2]): ## is WREG
                            df = '01'
                            rsD1     = '0_10'+integer2bin(param_op[2][2], 5)     
                    elif (param_op[2][3]): ## is Signed
                        df = '10'
                        DataImm = '_'+ integer2bin(param_op[2][3], 24)
                    elif (param_op[2][4]): ## is Unsigned
                        df = '10'
                        literal = str(int(param_op[2][4]))
                        DataImm = '_'+ integer2bin(literal, 24, 1)
                    elif (param_op[2][5]): ## is Binary
                        df = '10'
                        literal = str(int(param_op[2][5],2))
                        DataImm = '_'+ integer2bin(literal, 24)
                    elif (param_op[2][6]): ## is Hexa
                        df = '10'
                        literal = str(int(param_op[2][6],16))
                        DataImm = '_'+ integer2bin(literal, 24,1)
                    
                    else:
                        error = Logger.error('Parameter.SRC', 'Second Operand not recognized in instruction ' + str(command['LINE']) )
                ## CHECK FOR OPERATION
                if (error == 0):
                    operation = param_op[1][7]
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
            comp_LIT_PARAM = "(-?\d+)|u(\d+)|b(\d+)|h([0-9A-F]+)"
            param_lit  = re.findall(comp_LIT_PARAM, command['LIT'])[0]

            if (param_lit):
                df = '11'
                alu_op  = '00'
                if (param_lit[0]): ## is Signed
                    literal = str(int(param_lit[0]))
                    DataImm = '__'+ integer2bin(literal, 32)
                elif (param_lit[1]): ## is Unsigned
                    literal = str(int(param_lit[1]))
                    DataImm = '__'+ integer2bin(literal, 32, 1)
                elif (param_lit[2]): ## is Binary
                    literal = str(int(param_lit[2],2))
                    DataImm = '__'+ integer2bin(literal, 32)
                elif (param_lit[3]): ## is Hexa
                    literal = str(int(param_lit[3],16))
                    DataImm = '__'+ integer2bin(literal, 32,1)
            else:
                error = Logger.error("COMMAND_RECOGNITION", "Data Format incorrect in Line " + str(command['LINE']) )
        else:
            df      = '11'
            alu_op  = '00'
            DataImm = '__00000000000000000000000000000000'
        Data_Source = rsD0 +'_'+ rsD1 +'_'+ DataImm
        return error, Data_Source, alu_op, df

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
                rsA0     = '00000_0' + integer2bin(param_op[0][0], 5)     
            elif (param_op[0][1]): ## is DREG
                rsA0     = '00000_1' + integer2bin(param_op[0][1], 5)     
            elif (param_op[0][2]): ## is Literal
                rsA0     = '_'+ integer2bin(param_op[0][2], 11)
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
                    rsA0     = '00000_0' + integer2bin(param_op[2][0], 5)     
                elif (param_op[2][1]): ## is DREG
                    rsA0     = '00000_1' + integer2bin(param_op[2][1], 5)     
                elif (param_op[2][2]): ## is Literal
                    rsA0     = '_'+ integer2bin(param_op[2][2], 11)     
                    AI = '1'
            ## CHECK FOR PLUS
            if (error == 0):
                if (param_op[1][3]) != '+': ## is R_Reg
                    error = Logger.error('Parameter.MEM_ADDR', 'Address Operand should be < + >.')    
        else:
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
                    ADDR  = '_00000000000_000000' # 17 Bits 11 + 6
                else:
                    error = Logger.error('Instruction.REG_WR', 'No < -op() > for Operation Writting in instruction ' + str(current['LINE']))
            #### SOURCE IMM
            elif (current ['SRC'] == 'imm'):
                #### Get Data Source
                if ('LIT' in current ):
                    error, DATA, alu_op, DF = Instruction.__PROCESS_SOURCE(current)
                    CFG = '11__' + current ['UF'] + '_00_' + alu_op
                    ADDR  = '_00000000000_000000' # 17 Bits 11 + 6
                else:
                    error = Logger.error('Instruction.REG_WR', 'No Literal value for immediate Assignation (#) in instruction ' + str(current['LINE']) )
            #### SOURCE LABEL
            elif (current ['SRC'] == 'label'):
                #### Get Data Source
                if ('ADDR' in current):
                    comp_addr = "&(\d+)"
                    address = re.findall(comp_addr, current['ADDR'])
                    current['LIT'] = address[0]
                    if (address[0]): # LITERAL
                        error, DATA, alu_op, DF = Instruction.__PROCESS_SOURCE(current)
                        ADDR  = '_00000000000_000000' # 17 Bits 11 + 6
                        #DATA  = '0000000000000000_' + integer2bin(address[0], 16) 
                        #DF    = '11'
                        CFG = '11__' + current ['UF'] + '_00_00'
                    else:
                        error = Logger.error('Instruction.REG_WR', 'No Literal value for immediate Assignation (#) in instruction ' + str(current['LINE']) )

            #### SOURCE DATA MEMORY
            elif (current ['SRC'] == 'dmem'):
                #### Get Data Source
                error, DATA, alu_op, DF = Instruction.__PROCESS_SOURCE(current)
                CFG = '01__' + current ['UF'] + '_00_' + alu_op
                #### Get ADDRESS
                if error == 0:
                    error, RsF, RsE, AI = Instruction.__PROCESS_MEM_ADDR (current ['ADDR'])
                    ADDR  = RsF + '_' + RsE
                    CFG = '01__' + current ['UF'] + '_00_'+alu_op
            #### SOURCE WAVE MEM
            elif (current ['SRC'] == 'wmem'):
                if (current ['DST'] == 'r_wave'):
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
                            error, RsF, RsE, AI = Instruction.__PROCESS_MEM_ADDR (current ['ADDR'])
                            if (RsE != '000000'):
                                error = Logger.error('Instruction.REG_WR', 'Wave Memory Addres Error Source Should be LIT or Reg in instruction ' + str(current['LINE']) )                    
                            ADDR  = RsF + '_' + RdP
                        else:
                            error = Logger.error('Instruction.REG_WR', 'No addres for <wmem> source in instruction ' + str(current['LINE']) )
                else:
                    error = Logger.error('Instruction.REG_WR', 'Wave Memory Source Should have a Wave Register <r_wave> Destination ' + str(current['LINE']) )
            else:
                error = Logger.error('Instruction.REG_WR', 'Posible REG_WR sources are (op, imm, dmem, wmem, label ) in instruction ' + str(current['LINE']) )
            ######### DESTINATION REGISTER
            if (error==0):
                comp_OP_PARAM = "s(\d+)|r(\d+)|w(\d+)|(r_wave)"
                RD    = re.findall(comp_OP_PARAM, current ['DST'])
                if (RD):
                    if ( (current ['SRC'] == 'label') and (RD[0][1]!='15') ):
                        error = Logger.warning('Instruction.REG_WR', 'Register used to BRANCH should be s15 in instruction ' + str(current['LINE']) )
                    if (RD[0][0]) : #SREG
                        RD    = '00' + integer2bin(RD[0][0], 5)
                    elif (RD[0][1]) : #DREG
                        RD    = '01' + integer2bin(RD[0][1], 5) 
                    elif (RD[0][2]) : #WREG
                        RD    = '10' + integer2bin(RD[0][2], 5) 
                    elif (RD[0][3]) : #r_wave
                        if (current ['SRC'] == 'wmem'):
                            Wr = Rdi = '0'
                            error, Wr, Rdi, RD = Instruction.__PROCESS_WR(current)
                            CFG = '10__' + current ['UF'] +'_'+ Wr + Rdi +'_'+ alu_op
                        else:
                            error = Logger.error('Instruction.REG_WR', 'Wave Register Destination Should have a Wave Memory <wmem> Source ' + str(current['LINE']) + " (possible missing alias)")
                else:
                    error = Logger.error('Instruction.REG_WR', 'Destination Register '+current ['DST']+' not Recognized in instruction ' + str(current['LINE']) )
        if (error==0):
            CODE  = '100_' + AI + DF +'__'+ COND +'___'+ CFG +'_____'+ADDR+'_____'+DATA + '_' + RD
        else:
            CODE = 'X'
        return error, CODE
    
    @staticmethod
    def DMEM_WR (current : dict) -> tuple:
        error   = 0
        #### CONDITIONAL
        COND    = '000'
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
            error, RsF, RsE, AI = Instruction.__PROCESS_MEM_ADDR (current['DST'])
            ADDR  = RsF + '_' + RsE
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
            CODE = '101_'+AI+DF+'__'+COND+'__0_'+DI+'__'+CFG+"_____"+ADDR+'_____'+DATA+'_'+RD
        else:
            CODE = 'X'
        return error, CODE
        
    @staticmethod
    def WMEM_WR (current : dict) -> tuple:
        error   = 0
        AI=Wp=TI='0'
        #### WMEM ADDRESS
        if 'DST' in current:
            error, RsF, RsE, AI = Instruction.__PROCESS_MEM_ADDR (current['DST'])
            if (RsE != '000000'):
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
                DATA = '____' +integer2bin(current['TIME'], 32)
            CFG  = '1_' + TI+'__' +current['UF'] +'_'+ Wr +Rdi +'_'+ alu_op
            CODE = '101_'+AI+DF+'__1'+Sp+Wp+'__'+CFG+"_____"+RsF+'_'+Dp+'_____'+DATA+'_'+RD
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
        COND    = '000'
        error, COND = Instruction.__PROCESS_CONDITION(current)
        #### WRITE REGISTER
        Wr = Rdi = '0'
        error, Wr, Rdi, RD = Instruction.__PROCESS_WR(current)
        #### DATA SOURCE
        if (error==0):
            error, DATA, alu_op, DF = Instruction.__PROCESS_SOURCE(current)
        if (error==0):
            CFG  = current['UF'] +'_'+ Wr + Rdi +'_'+ alu_op
            CODE = '000_'+AI+DF+'__'+COND+'___'+SO+TO+'__'+CFG+"______"+ADDR+'_____'+DATA+'_'+RD
        else:
            CODE = 'X'
        return error, CODE
    
    @staticmethod
    def BRANCH (current : dict, cj : str) -> tuple:
        error   = 0
        #### CONDITIONAL
        COND    = '000'
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
            CODE = '001_'+AI+DF+'__'+COND+'__'+cj+'___'+CFG+"_____"+ADDR+'_____'+DATA+"_"+RD
        else:
            Logger.error("Instruction.BRANCH", "Exit with Error in instruction " + str(current['LINE']) )
            CODE = 'X'
        return error, CODE
    
    @staticmethod
    def PORT_WR (current : dict) -> tuple:
        error   = 0
        if (current['CMD'] == 'DPORT_WR' or current['CMD'] == 'DPORT_RD') \
        or (current['CMD'] == 'TRIG'):
            SO=AI=Ww=Sp= '0'
            RsF = '_00000000000'
            #### WRITE REGISTER
            if error == 0:
                Wr = Rdi = '0'
                if (error==0):
                    error, Wr, Rdi, RD = Instruction.__PROCESS_WR(current)
            #### DATA SOURCE
            if (error==0):
                error, DATA, alu_op, DF = Instruction.__PROCESS_SOURCE(current)
            if (current['CMD'] == 'TRIG'):
                if (current['SRC'] == 'set'):
                    Wp= '1'
                    AI=Sp = '1'
                    RsF     = '_00000000001'
                    current['DST'] = str(int(current['DST'])+8)
                elif (current['SRC'] == 'clr'):
                    Wp= '1'
                    AI=Sp = '1'
                    RsF     = '_00000000000'
                    current['DST'] = str(int(current['DST'])+8)
                else:
                    error = Logger.error('Instruction.PORT_WR', 'Posible options for TRIG command are (set, clr)' )

            elif (current['CMD'] == 'DPORT_WR'):
                Wp= '1'
                Sp= '0'
                
                if (current ['SRC'] == 'imm'):
                    if 'DATA' in current:
                        if ( int(current['DATA']) > 2047 ):
                            error = Logger.error('Instruction.PORT_WR', 'Data imm should be smaller than 2047 No Port Data value found in line ' + str(current['LINE']) )
                        else:
                            AI=Sp = '1'
                            RsF     = '_'+ integer2bin(current['DATA'], 11)
                    else:
                        error = Logger.error('Instruction.PORT_WR', 'No Port Data value found in line ' + str(current['LINE']) )
                elif (current ['SRC'] == 'reg'):
                    if ('DATA' in current ):
                        AI=Sp = '0'
                        comp_REG_FMT = "r(\d+)"
                        param_op  = re.findall(comp_REG_FMT, current['DATA'])
                        if (param_op):
                           RsF     = '00000_1' + integer2bin(param_op[0][0], 5)     
                        else:
                            error = Logger.error('Instruction.PORT_WR', 'Register Selection Error, should be dreg in line ' + str(current['LINE']) )
                    else:
                        error = Logger.error('Instruction.PORT_WR', 'No Port Register found in line ' + str(current['LINE']) )
                else:
                    error = Logger.error('Instruction.PORT_WR', 'Posible DPORT_WR sources are (imm, reg) in line ' + str(current['LINE']) )
            else: #DPORT_RD
                TO=Wp='0'
        else:
            AI=Ww=Sp= '0'
            SO=Wp= '1'
            #### SOURCE
            if (error==0):
                if (current['SRC'] == 'wmem'):
                    Sp = '0'
                    if 'ADDR' in current:
                        error, RsF, RsE, AI = Instruction.__PROCESS_MEM_ADDR (current ['ADDR'])
                        if (RsE != '000000'):
                            error = Logger.error('Instruction.REG_WR', 'Wave Memory Addres Error Source Should be LIT or Reg in line ' + str(current['LINE']) )                    
                    else:
                        error = Logger.error('Instruction.PORT_WR', 'No address specified for < wmem > in line ' + str(current['LINE']) )
                elif (current['SRC'] == 'r_wave'):
                    Sp='1'
                    #### WRITE WAVE MEMORY
                    if ('WW' in current ): 
                        if 'ADDR' in current:
                            Ww = '1'
                            error, RsF, RsE, AI = Instruction.__PROCESS_MEM_ADDR (current ['ADDR'])
                            if (RsE != '000000'):
                                error = Logger.error('Instruction.REG_WR', 'Wave Memory Addres Error Source Should be LIT or Reg in line ' + str(current['LINE']) )
                        else:
                            error = Logger.error('Instruction.PORT_WR', 'No address specified for < -ww > in line ' + str(current['LINE']) )
                    else:
                        Ww  = '0'
                        RsF = '_00000000000'
                else:
                    error = Logger.error('Instruction.PORT_WR', 'Posible wave sources are (wmem, r_wave) in line ' + str(current['LINE']) )
                    DF = '11'
        #### OUT TIME 
        if (error==0):
            if ('TIME' in current): 
                TO = '1'
                DF = '11'
                DATA = '____'+ integer2bin(current['TIME'], 32)
                CFG = SO+TO+'____00000'
                RD = '0000000'
                if ('WR' in current): 
                    error = Logger.error('Instruction.PORT_WR', 'If time specified, Not allowed SDI <-wr()> in line ' + str(current['LINE']) )
            else:
                TO = '0'
                error = Logger.info('Instruction.PORT_WR', 'No time specified for command will use r_time in line ' + str(current['LINE']) )
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
                RsE = integer2bin(current['DST'], 6)
            else:
                error = Logger.error('Instruction.PORT_WR', 'No Destination Port in line ' + str(current['LINE']) )        
        if (error == 0):
            COND = Ww+Sp+Wp
            ADDR  = RsF+'_'+RsE
            CODE = '110'+'_'+AI+DF+'__'+COND+'___'+CFG+ '_____'+ADDR +'_____'+ DATA+'_'+RD
        else:
            Logger.error("Instruction.PORT_WR", "Exit with Error in line " + str(current['LINE']) )
            CODE = 'X'
        return error, CODE
    
    ################################ TO UPDATE CODE HERE. NOT LAST VERSION
    @staticmethod
    def CTRL (current : dict) -> tuple:
        error   = 0
        RA0=RA1='000000'
        RD0=RD1='0_0000000'
        RE='0000000000000000'
        DF='10'
        ######### TIME 
        if (current ['CMD'] == 'TIME'):
            CTRL      = '00001'
            if   (current['DST'] == 'rst'):
                OPERATION = '00001'
            elif (current['DST'] == 'updt'):
                OPERATION = '00010'
            elif (current['DST'] == 'set_ref'):
                OPERATION = '00100'
            elif (current['DST'] == 'inc_ref'):
                OPERATION = '01000'
            else:
                error = Logger.error('Instruction.CTRL', 'Posible Operations for TIME command are (rst, set_ref, inc_ref)' )
            if ('LIT' in current ):
                DF='11'
                RD1 = '_'+integer2bin(current['LIT'], 24)
                RE=''
            elif ('SRC' in current):
                error, RD1 = get_reg_addr (current['SRC'], 'Source')
            else: 
                if   (current['DST'] !='rst'):
                    error = Logger.error('Instruction.CTRL', 'No Time Data' )
        ######### FLAG
        elif (current ['CMD'] == 'FLAG'):
            CTRL      = '00010'
            if   (current['SRC'] == 'set'):
                OPERATION = '00001'
            elif (current['SRC'] == 'clr'):
                OPERATION = '00010'
            else:
                error = Logger.error('Instruction.CTRL', 'Posible Operations for FLAG command are (set, clr)' )
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
                    error = Logger.error("Instruction.CTRL", "JUMP Memory Address not recognized (imm or s15)")
        ######### NET
        elif (current ['CMD'] == 'NET'):
            CTRL      = '10001' # QNET ADDRESS
            if   (current['SRC'] == 'get_net'):
                OPERATION = '00001'
            elif (current['SRC'] == 'set_net'):
                OPERATION = '00010'
            elif (current['SRC'] == 'sync_net'):
                OPERATION = '01000'
            elif (current['SRC'] == 'updt_offset'):
                OPERATION = '01001'
            elif (current['SRC'] == 'set_dt'):
                OPERATION = '01010'
            elif (current['SRC'] == 'get_dt'):
                OPERATION = '01011'
            else:
                error = Logger.error('Instruction.CTRL', 'Posible Operations for FLAG command are (set, clr)' )
        ######### CUSTOM
        elif (current ['CMD'] == 'CUSTOM'):
            CTRL      = '10010' # CUSTOM PERIPHERAL
            OPERATION = integer2bin(current['C_OP'], 5)

            if ('LIT' in current):
                    error = Logger.error('Instruction.CTRL', 'No Immediate value allowed in CUSTOM' )
            else :
                if ('R1' in current and 'R2' in current and 'R3' in current and 'R4' in current ):
                    error, RD0 = get_reg_addr (current['R1'], 'Source')
                    error, RD1 = get_reg_addr (current['R2'], 'Source')
                    error, RA0 = get_reg_addr (current['R3'], 'Addr')
                    error, RA1 = get_reg_addr (current['R4'], 'Addr')
                else:
                    error = Logger.error('Instruction.CTRL', 'Few Sources > Need Four Source Register for CUSTOM operation' )
                    
        if (error):
            Logger.error("Instruction.CTRL", "Error in instruction " + str(current['LINE']) )
            CODE = 'X'
        else:
            CODE = '111_0'+DF+'______'+OPERATION+'___'+CTRL+'_____00000___'+RA0+'_'+RA1+'__'+RD0+'__'+RD1+'_'+RE+'_0000000'
        return error, CODE

    
    @staticmethod
    def ARITH (current : dict) -> tuple:
        error   = 0
        RsC=RsD='000000'
        if ('LIT' in current):
                error = Logger.error('Instruction.ARITH', 'No Immediate value allowed ' )
        if (not 'C_OP' in current) :
            error = Logger.error('Instruction.ARITH', 'No ARITH Operation ' )
        else :
            if (current['C_OP'] in arithList ):
                ARITH_OP = arithList[current['C_OP']]
           
            if   (current['C_OP'] == 'T'): # A*B
                if ('R1' in current and 'R2' in current ):
                    error, RsA = get_reg_addr (current['R1'], 'Source')
                    error, RsB = get_reg_addr (current['R2'], 'Source')
                else:
                    error = Logger.error('Instruction.ARITH', 'Few Sources > Need Two Source Register for T operation' )
            elif (current['C_OP'] == 'TP') : # A*B+C
                if ('R1' in current and 'R2' in current and 'R3' in current ):
                    error, RsA = get_reg_addr (current['R1'], 'Source')
                    error, RsB = get_reg_addr (current['R2'], 'Source')
                    error, RsC = get_reg_addr (current['R3'], 'Addr')
                else:
                    error = Logger.error('Instruction.ARITH', 'Few Sources > Need three Source Register for TP operation' )
            elif (current['C_OP'] == 'TM') : # A*B-C
                if ('R1' in current and 'R2' in current and 'R3' in current ):
                    error, RsA = get_reg_addr (current['R1'], 'Source')
                    error, RsB = get_reg_addr (current['R2'], 'Source')
                    error, RsC = get_reg_addr (current['R3'], 'Addr')
                else:
                    error = Logger.error('Instruction.ARITH', 'Few Sources > Need three Source Register for TM operation' )
            elif (current['C_OP'] == 'PT') : # (A+D)*B
                if ('R1' in current and 'R2' in current and 'R3' in current ):
                    error, RsA = get_reg_addr (current['R1'], 'Source')
                    error, RsD = get_reg_addr (current['R2'], 'Addr')
                    error, RsB = get_reg_addr (current['R3'], 'Source')
                else:
                    error = Logger.error('Instruction.ARITH', 'Few Sources > Need three Source Register for PT operation' )
            elif (current['C_OP'] == 'PTP'): #(A+D)*B+C
                if ('R1' in current and 'R2' in current and 'R3' in current and 'R4' in current ):
                    error, RsA = get_reg_addr (current['R1'], 'Source')
                    error, RsD = get_reg_addr (current['R2'], 'Addr')
                    error, RsB = get_reg_addr (current['R3'], 'Source')
                    error, RsC = get_reg_addr (current['R4'], 'Addr')
                else:
                    error = Logger.error('Instruction.ARITH', 'Few Sources > Need Four Source Register for PTP operation' )
            elif (current['C_OP'] == 'PTM'): #(A+D)*B-C
                if ('R1' in current and 'R2' in current and 'R3' in current and 'R4' in current ):
                    error, RsA = get_reg_addr (current['R1'], 'Source')
                    error, RsD = get_reg_addr (current['R2'], 'Addr')
                    error, RsB = get_reg_addr (current['R3'], 'Source')
                    error, RsC = get_reg_addr (current['R4'], 'Addr')
                else:
                    error = Logger.error('Instruction.ARITH', 'Few Sources > Need Four Source Register for PTM operation' )
            else:
                    error = Logger.error('Instruction.ARITH', 'No Recognized Operation' )

        if (error==0):
            CODE = '111_000______'+ARITH_OP +'___00100___00000___'+RsC+'__'+RsD+'__'+RsA+'__'+RsB+'__0000000000000000_0000000'
        else:
            Logger.error("Instruction.ARITH", "Exit with Error in line " + str(current['LINE']) )
            CODE = 'X'
        return error, CODE

    @staticmethod
    def WAIT (current : dict) -> tuple:
        error   = 0
        binary_multi_list = []
        ######### WAIT 
        current['ADDR'] = '&'+str(current['P_ADDR'])
        current['TIME'] = str(int(current['TIME'])-10)
        current['UF'] = '1'
        current['IF'] = '1'
        current['OP'] = 's11-#' + current['TIME']
        error, CODE = Instruction.CFG(current) ## ADD TEST INSTRUCTION
        if (error==0):
            binary_multi_list.append(CODE)
            current['IF'] = 'S'
            error, CODE = Instruction.BRANCH(current, '00') ## ADD JUMP INSTRUCTION
        if (error==0):
            binary_multi_list.append(CODE)

        return error, binary_multi_list        
