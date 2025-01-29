"""
Function to parse tProc assembly language programs.
"""
import re

# Function to parse program.


def parse_prog(file="prog.asm", outfmt="bin"):
    """
    Parses the .asm assembly language tProc program into a specified output format (binary or hex)

    :param file: ASM program file name
    :type file: str
    :param outfmt: Output format ("bin" or "hex")
    :type outfmt: str
    :return: Program in the new output format
    :rtype: bin or hex
    """
    # Output structure.
    outProg = {}

    # Instructions.
    instList = {}

    # I-type.
    instList['pushi'] = {'bin': '00010000'}
    instList['popi'] = {'bin': '00010001'}
    instList['mathi'] = {'bin': '00010010'}
    instList['seti'] = {'bin': '00010011'}
    instList['synci'] = {'bin': '00010100'}
    instList['waiti'] = {'bin': '00010101'}
    instList['bitwi'] = {'bin': '00010110'}
    instList['memri'] = {'bin': '00010111'}
    instList['memwi'] = {'bin': '00011000'}
    instList['regwi'] = {'bin': '00011001'}
    instList['setbi'] = {'bin': '00011010'}

    # J-type.
    instList['loopnz'] = {'bin': '00110000'}
    instList['condj'] = {'bin': '00110001'}
    instList['end'] = {'bin': '00111111'}

    # R-type.
    instList['math'] = {'bin': '01010000'}
    instList['set'] = {'bin': '01010001'}
    instList['sync'] = {'bin': '01010010'}
    instList['read'] = {'bin': '01010011'}
    instList['wait'] = {'bin': '01010100'}
    instList['bitw'] = {'bin': '01010101'}
    instList['memr'] = {'bin': '01010110'}
    instList['memw'] = {'bin': '01010111'}
    instList['setb'] = {'bin': '01011000'}

    # Structures for symbols and program.
    progList = {}
    symbList = {}

    ##############################
    ### Read program from file ###
    ##############################
    fd = open(file, "r")
    addr = 0
    for line in fd:
        # Match comments.
        m = re.search("^\s*//", line)

        # If there is a match.
        if m:
            # print(line)
            a = 1

        else:
            # Match instructions.
            jump_re = "^((.+):)?"
            inst_re_I = "pushi|popi|mathi|seti|synci|waiti|bitwi|memri|memwi|regwi|setbi|"
            inst_re_J = "loopnz|condj|end|"
            inst_re_R = "math|set|sync|read|wait|bitw|memr|memw|setb"
            inst_re = "\s*(" + inst_re_I + inst_re_J + inst_re_R + ")\s+(.+);"
            comp_re = jump_re + inst_re
            m = re.search(comp_re, line, flags=re.MULTILINE)

            # If there is a match.
            if m:
                # Tagged instruction for jump.
                if m.group(2):
                    symb = m.group(2)
                    inst = m.group(3)
                    args = m.group(4)

                    # Add symbol to symbList.
                    symbList[symb] = addr

                    # Add instruction to progList.
                    progList[addr] = {'inst': inst, 'args': args}

                    # Increment address.
                    addr = addr + 1

                # Normal instruction.
                else:
                    inst = m.group(3)
                    args = m.group(4)

                    # Add instruction to progList.
                    progList[addr] = {'inst': inst, 'args': args}

                    # Increment address.
                    addr = addr + 1

            # Check special case of "end" instruction.
            else:
                m = re.search("\s*(end)\s*;", line)

                # If there is a match.
                if m:
                    # Add instruction to progList.
                    progList[addr] = {'inst': 'end', 'args': ''}

                    # Increment address.
                    addr = addr + 1

    #########################
    ### Support functions ###
    #########################
    def unsigned2bin(strin, bits=8):
        maxv = 2**bits - 1

        # Check if hex string.
        m = re.search("^0x", strin, flags=re.MULTILINE)
        if m:
            dec = int(strin, 16)
        else:
            dec = int(strin, 10)

        # Check max.
        if dec > maxv:
            print("Error: number %d is bigger than %d" % (dec, maxv))
            return None

        # Convert to binary.
        fmt = "{0:0" + str(bits) + "b}"
        binv = fmt.format(dec)

        return binv

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
            print("Error: number %d is smaller than %d" % (dec, minv))
            return None

        # Check max.
        if dec > maxv:
            print("Error: number %d is bigger than %d" % (dec, maxv))
            return None

        # Check if number is negative.
        if dec < 0:
            dec = dec + 2**bits

        # Convert to binary.
        fmt = "{0:0" + str(bits) + "b}"
        binv = fmt.format(dec)

        return binv

    def op2bin(op):
        if op == "0":
            return "0000"
        elif op == ">":
            return "0000"
        elif op == ">=":
            return "0001"
        elif op == "<":
            return "0010"
        elif op == "<=":
            return "0011"
        elif op == "==":
            return "0100"
        elif op == "!=":
            return "0101"
        elif op == "+":
            return "1000"
        elif op == "-":
            return "1001"
        elif op == "*":
            return "1010"
        elif op == "&":
            return "0000"
        elif op == "|":
            return "0001"
        elif op == "^":
            return "0010"
        elif op == "~":
            return "0011"
        elif op == "<<":
            return "0100"
        elif op == ">>":
            return "0101"
        elif op == "upper":
            return "1010"
        elif op == "lower":
            return "0101"
        else:
            print("Error: operation \"%s\" not recognized" % op)
            return "1111"

    ######################################
    ### First pass: parse instructions ###
    ######################################
    for e in progList:
        inst = progList[e]['inst']
        args = progList[e]['args']

        # I-type: three registers and an immediate value.
        # I-type:<inst>:page:channel:oper:ra:rb:rc:imm

        # pushi p, $ra, $rb, imm
        if inst == 'pushi':
            comp_re = "\s*(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)\s*,\s*(\-?\d+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                page = m.group(1)
                ra = m.group(2)
                rb = m.group(3)
                imm = m.group(4)

                # Add entry into structure.
                progList[e]['inst_parse'] = "I-type:pushi:" + \
                    page + ":0:0:" + rb + ":" + ra + ":0:" + imm

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # popi p, $r
        elif inst == 'popi':
            comp_re = "\s*(\d+)\s*,\s*\$(\d+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                page = m.group(1)
                r = m.group(2)

                # Add entry into structure.
                progList[e]['inst_parse'] = "I-type:popi:" + \
                    page + ":0:0:" + r + ":0:0:0"

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # mathi p, $ra, $rb oper imm
        if inst == 'mathi':
            comp_re = "\s*(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)\s*([\+\-\*])\s*(0?x?\-?[0-9a-fA-F]+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                page = m.group(1)
                ra = m.group(2)
                rb = m.group(3)
                oper = m.group(4)
                imm = m.group(5)

                # Add entry into structure.
                progList[e]['inst_parse'] = "I-type:mathi:" + page + \
                    ":0:" + oper + ":" + ra + ":" + rb + ":0:" + imm

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # seti ch, p, $r, t
        if inst == 'seti':
            comp_re = "\s*(\d+)\s*,\s*(\d+)\s*,\s*\$(\d+)\s*,\s*(\-?\d+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                ch = m.group(1)
                page = m.group(2)
                ra = m.group(3)
                t = m.group(4)

                # Add entry into structure.
                progList[e]['inst_parse'] = "I-type:seti:" + \
                    page + ":" + ch + ":0:0:" + ra + ":0:" + t

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # synci t
        if inst == 'synci':
            comp_re = "\s*(\d+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                t = m.group(1)

                # Add entry into structure.
                progList[e]['inst_parse'] = "I-type:synci:0:0:0:0:0:0:" + t

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # waiti ch, t
        if inst == 'waiti':
            comp_re = "\s*(\d+)\s*,\s*(\d+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                ch = m.group(1)
                t = m.group(2)

                # Add entry into structure.
                progList[e]['inst_parse'] = "I-type:waiti:0:" + \
                    ch + ":0:0:0:0:" + t

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # bitwi p, $ra, $rb oper imm
        if inst == 'bitwi':
            comp_re = "\s*(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)\s*([&|<>^]+)\s*(0?x?\-?[0-9a-fA-F]+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                page = m.group(1)
                ra = m.group(2)
                rb = m.group(3)
                oper = m.group(4)
                imm = m.group(5)

                # Add entry into structure.
                progList[e]['inst_parse'] = "I-type:bitwi:" + page + \
                    ":0:" + oper + ":" + ra + ":" + rb + ":0:" + imm

            # bitwi p, $ra, ~imm
            else:
                comp_re = "\s*(\d+)\s*,\s*\$(\d+)\s*,\s*~\s*(0?x?\-?[0-9a-fA-F]+)"
                m = re.search(comp_re, args)

                # If there is a match.
                if m:
                    page = m.group(1)
                    ra = m.group(2)
                    oper = "~"
                    imm = m.group(3)

                    # Add entry into structure.
                    progList[e]['inst_parse'] = "I-type:bitwi:" + \
                        page + ":0:" + oper + ":" + ra + ":0:0:" + imm

                # Error: bad instruction format.
                else:
                    print("Error: bad format on instruction @%d: %s" % (e, inst))

        # memri p, $r, imm
        if inst == 'memri':
            comp_re = "\s*(\d+)\s*,\s*\$(\d+)\s*,\s*(0?x?\-?[0-9a-fA-F]+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                page = m.group(1)
                r = m.group(2)
                imm = m.group(3)

                # Add entry into structure.
                progList[e]['inst_parse'] = "I-type:memri:" + \
                    page + ":0:0:" + r + ":0:0:" + imm

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # memwi p, $r, imm
        if inst == 'memwi':
            comp_re = "\s*(\d+)\s*,\s*\$(\d+)\s*,\s*(0?x?\-?[0-9a-fA-F]+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                page = m.group(1)
                r = m.group(2)
                imm = m.group(3)

                # Add entry into structure.
                progList[e]['inst_parse'] = "I-type:memwi:" + \
                    page + ":0:0:0:0:" + r + ":" + imm

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # regwi p, $r, imm
        if inst == 'regwi':
            comp_re = "\s*(\d+)\s*,\s*\$(\d+)\s*,\s*(0?x?\-?[0-9a-fA-F]+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                page = m.group(1)
                r = m.group(2)
                imm = m.group(3)

                # Add entry into structure.
                progList[e]['inst_parse'] = "I-type:regwi:" + \
                    page + ":0:0:" + r + ":0:0:" + imm

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # setbi ch, p, $r, t
        if inst == 'setbi':
            comp_re = "\s*(\d+)\s*,\s*(\d+)\s*,\s*\$(\d+)\s*,\s*(\-?\d+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                ch = m.group(1)
                page = m.group(2)
                ra = m.group(3)
                t = m.group(4)

                # Add entry into structure.
                progList[e]['inst_parse'] = "I-type:setbi:" + \
                    page + ":" + ch + ":0:0:" + ra + ":0:" + t

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # J-type: three registers and an address for jump.
        # J-type:<inst>:page:oper:ra:rb:rc:addr

        # loopnz p, $r, @label
        if inst == 'loopnz':
            comp_re = "\s*(\d+)\s*,\s*\$(\d+)\s*,\s*\@(.+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                page = m.group(1)
                oper = "+"
                r = m.group(2)
                label = m.group(3)

                # Resolve symbol.
                if label in symbList:
                    label_addr = symbList[label]
                else:
                    print("Error: could not resolve symbol %s on instruction @%d: %s %s" % (
                        label, e, inst, args))

                # Add entry into structure.
                regs = r + ":" + r + ":0:" + str(label_addr)
                progList[e]['inst_parse'] = "J-type:loopnz:" + \
                    page + ":" + oper + ":" + regs

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # condj p, $ra op $rb, @label
        if inst == 'condj':
            comp_re = "\s*(\d+)\s*,\s*\$(\d+)\s*([<>=!]+)\s*\$(\d+)\s*,\s*\@(.+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                page = m.group(1)
                ra = m.group(2)
                oper = m.group(3)
                rb = m.group(4)
                label = m.group(5)

                # Resolve symbol.
                if label in symbList:
                    label_addr = symbList[label]
                else:
                    print("Error: could not resolve symbol %s on instruction @%d: %s %s" % (
                        label, e, inst, args))

                # Add entry into structure.
                regs = ra + ":" + rb + ":" + str(label_addr)
                progList[e]['inst_parse'] = "J-type:condj:" + \
                    page + ":" + oper + ":0:" + regs

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # end
        if inst == 'end':
            # Add entry into structure.
            progList[e]['inst_parse'] = "J-type:end:0:0:0:0:0:0"

        # R-type: 8 registers, 7 for reading and 1 for writing.
        # R-type:<inst>:page:channel:oper:ra:rb:rc:rd:re:rf:rg:rh

        # math p, $ra, $rb oper $rc
        if inst == 'math':
            comp_re = "\s*(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)\s*([\+\-\*])\s*\$(\d+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                page = m.group(1)
                ra = m.group(2)
                rb = m.group(3)
                oper = m.group(4)
                rc = m.group(5)

                # Add entry into structure.
                regs = ra + ":" + rb + ":" + rc + ":0:0:0:0:0"
                progList[e]['inst_parse'] = "R-type:math:" + \
                    page + ":0:" + oper + ":" + regs

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # set ch, p, $ra, $rb, $rc, $rd, $re, $rt
        if inst == 'set':
            regs = "\s*\$(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)"
            comp_re = "\s*(\d+)\s*,\s*(\d+)\s*," + regs
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                ch = m.group(1)
                page = m.group(2)
                ra = m.group(3)
                rb = m.group(4)
                rc = m.group(5)
                rd = m.group(6)
                ree = m.group(7)
                rt = m.group(8)

                # Add entry into structure.
                regs = ra + ":" + rt + ":" + rb + ":" + rc + ":" + rd + ":" + ree + ":0"
                progList[e]['inst_parse'] = "R-type:set:" + \
                    page + ":" + ch + ":0:0:" + regs

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # sync p, $r
        if inst == 'sync':
            comp_re = "\s*(\d+)\s*,\s*\$(\d+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                page = m.group(1)
                r = m.group(2)

                # Add entry into structure.
                progList[e]['inst_parse'] = "R-type:sync:" + \
                    page + ":0:0:0:0:" + r + ":0:0:0:0:0"

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # read ch, p, oper $r
        if inst == 'read':
            comp_re = "\s*(\d+)\s*,\s*(\d+)\s*,\s*(upper|lower)\s+\$(\d+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                ch = m.group(1)
                page = m.group(2)
                oper = m.group(3)
                r = m.group(4)

                # Add entry into structure.
                progList[e]['inst_parse'] = "R-type:read:" + page + \
                    ":" + ch + ":" + oper + ":" + r + ":0:0:0:0:0:0:0"

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # wait ch, p, $r
        if inst == 'wait':
            comp_re = "\s*(\d+)\s*,\s*(\d+)\s*,\s*\$(\d+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                ch = m.group(1)
                page = m.group(2)
                r = m.group(3)

                # Add entry into structure.
                progList[e]['inst_parse'] = "R-type:wait:" + \
                    page + ":" + ch + ":0:0:0:" + r + ":0:0:0:0:0"

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # bitw p, $ra, $rb oper $rc
        if inst == 'bitw':
            comp_re = "\s*(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)\s*([&|<>^]+)\s*\$(\d+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                page = m.group(1)
                ra = m.group(2)
                rb = m.group(3)
                oper = m.group(4)
                rc = m.group(5)

                # Add entry into structure.
                regs = ra + ":" + rb + ":" + rc + ":0:0:0:0:0"
                progList[e]['inst_parse'] = "R-type:bitw:" + \
                    page + ":0:" + oper + ":" + regs

            # bitw p, $ra, ~$rb
            else:
                comp_re = "\s*(\d+)\s*,\s*\$(\d+)\s*,\s*~\s*\$(\d+)"
                m = re.search(comp_re, args)

                # If there is a match.
                if m:
                    page = m.group(1)
                    ra = m.group(2)
                    rb = m.group(3)
                    oper = "~"

                    # Add entry into structure.
                    regs = ra + ":0:" + ":" + rb + ":0:0:0:0:0"
                    progList[e]['inst_parse'] = "R-type:bitw:" + \
                        page + ":0:" + oper + ":" + regs

                # Error: bad instruction format.
                else:
                    print("Error: bad format on instruction @%d: %s" % (e, inst))

        # memr p, $ra, $rb
        if inst == 'memr':
            comp_re = "\s*(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                page = m.group(1)
                ra = m.group(2)
                rb = m.group(3)

                # Add entry into structure.
                regs = ra + ":" + rb + ":0:0:0:0:0:0"
                progList[e]['inst_parse'] = "R-type:memr:" + \
                    page + ":0:0:" + regs

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # memw p, $ra, $rb
        if inst == 'memw':
            comp_re = "\s*(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)"
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                page = m.group(1)
                ra = m.group(2)
                rb = m.group(3)

                # Add entry into structure.
                regs = rb + ":" + ra + ":0:0:0:0:0"
                progList[e]['inst_parse'] = "R-type:memw:" + \
                    page + ":0:0:0:" + regs

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

        # setb ch, p, $ra, $rb, $rc, $rd, $re, $rt
        if inst == 'setb':
            regs = "\s*\$(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)"
            comp_re = "\s*(\d+)\s*,\s*(\d+)\s*," + regs
            m = re.search(comp_re, args)

            # If there is a match.
            if m:
                ch = m.group(1)
                page = m.group(2)
                ra = m.group(3)
                rb = m.group(4)
                rc = m.group(5)
                rd = m.group(6)
                ree = m.group(7)
                rt = m.group(8)

                # Add entry into structure.
                regs = ra + ":" + rt + ":" + rb + ":" + rc + ":" + rd + ":" + ree + ":0"
                progList[e]['inst_parse'] = "R-type:setb:" + \
                    page + ":" + ch + ":0:0:" + regs

            # Error: bad instruction format.
            else:
                print("Error: bad format on instruction @%d: %s" % (e, inst))

    ######################################
    ### Second pass: convert to binary ###
    ######################################
    for e in progList:
        inst = progList[e]['inst_parse']
        spl = inst.split(":")

        # I-type
        if spl[0] == "I-type":
            # Instruction.
            if spl[1] in instList:
                inst_bin = instList[spl[1]]['bin']
            else:
                print(
                    "Error: instruction %s not found on instraction list" % spl[1])

            # page.
            page = unsigned2bin(spl[2], 3)

            # channel
            ch = unsigned2bin(spl[3], 3)

            # oper
            oper = op2bin(spl[4])

            # Registers.
            ra = unsigned2bin(spl[5], 5)
            rb = unsigned2bin(spl[6], 5)
            rc = unsigned2bin(spl[7], 5)

            # Immediate.
            imm = integer2bin(spl[8], 31)

            # Machine code (bin/hex).
            code = inst_bin + page + ch + oper + ra + rb + rc + imm
            code_h = "{:016x}".format(int(code, 2))

            # Write values back into hash.
            progList[e]['inst_bin'] = code
            progList[e]['inst_hex'] = code_h

        elif (spl[0] == "J-type"):
            # Instruction.
            if spl[1] in instList:
                inst_bin = instList[spl[1]]['bin']
            else:
                print(
                    "Error: instruction %s not found on instraction list" % spl[1])

            # Page.
            page = unsigned2bin(spl[2], 3)

            # Zeros.
            z3 = unsigned2bin("0", 3)

            # oper
            oper = op2bin(spl[3])

            # Registers.
            ra = unsigned2bin(spl[4], 5)
            rb = unsigned2bin(spl[5], 5)
            rc = unsigned2bin(spl[6], 5)

            # Zeros.
            z15 = unsigned2bin("0", 15)

            # Address.
            jmp_addr = unsigned2bin(spl[7], 16)

            # Machine code (bin/hex).
            code = inst_bin + page + z3 + oper + ra + rb + rc + z15 + jmp_addr
            code_h = "{:016x}".format(int(code, 2))

            # Write values back into hash.
            progList[e]['inst_bin'] = code
            progList[e]['inst_hex'] = code_h

        elif (spl[0] == "R-type"):
            # Instruction.
            if spl[1] in instList:
                inst_bin = instList[spl[1]]['bin']
            else:
                print(
                    "Error: instruction \"%s\" not found on instraction list" % spl[1])

            # Page.
            page = unsigned2bin(spl[2], 3)

            # Channel
            ch = unsigned2bin(spl[3], 3)

            # Oper
            oper = op2bin(spl[4])

            # Registers.
            ra = unsigned2bin(spl[5], 5)
            rb = unsigned2bin(spl[6], 5)
            rc = unsigned2bin(spl[7], 5)
            rd = unsigned2bin(spl[8], 5)
            ree = unsigned2bin(spl[9], 5)
            rf = unsigned2bin(spl[10], 5)
            rg = unsigned2bin(spl[11], 5)
            rh = unsigned2bin(spl[12], 5)

            # Zeros.
            z6 = unsigned2bin("0", 6)

            # Machine code (bin/hex).
            code = inst_bin + page + ch + oper + ra + \
                rb + rc + rd + ree + rf + rg + rh + z6
            code_h = "{:016x}".format(int(code, 2))

            # Write values back into hash.
            progList[e]['inst_bin'] = code
            progList[e]['inst_hex'] = code_h

        else:
            print("Error: bad type on instruction @%d: %s" % (e, inst))

    ####################
    ### Write output ###
    ####################
    # Binary format.
    if outfmt == "bin":
        for e in progList:
            outProg[e] = progList[e]['inst_bin']

    # Hex format.
    elif outfmt == "hex":
        for e in progList:
            out = progList[e]['inst_hex'] + " -> " + \
                progList[e]['inst'] + " " + progList[e]['args']
            outProg[e] = out

    else:
        print("Error: \"%s\" is not a recognized output format" % outfmt)

    # Return program list.
    return outProg


def parse_to_bin(path):
    """
    Parses the .asm assembly language tProc program into a form appropriate for QickSoc.load_bin_program().

    :param file: ASM program file name
    :type file: str
    :return: Program as a list of 64-bit ints
    :rtype: list
    """
    p = parse_prog(path)
    return [int(p[i], 2) for i in p]

def load_program(soc, prog="prog.asm", fmt="asm"):
    """
    Loads tProc program. If asm program, it compiles first

    :param soc: Qick to be programmed
    :type soc: QickSoc
    :param prog: program file name
    :type prog: string
    :param fmt: file format
    :type fmt: string
    """
    # Binary file format.
    if fmt == "bin":
        # Read binary file from disk.
        with open(prog, "r") as fd:
            progList = [int(line, 2) for line in fd]

    # Asm file.
    elif fmt == "asm":
        # Compile program.
        progList = parse_to_bin(prog)

    soc.load_bin_program(progList)
