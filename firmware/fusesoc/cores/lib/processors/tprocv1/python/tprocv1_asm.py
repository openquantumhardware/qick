#!/usr/bin/env python3
"""
tproc_asm.py - Assembler / program generator for the QICK tProcessor V1.

Generates pmem.hex (instructions) and dmem.hex (initial data) files compatible
with the tprocv1 testbench ($readmemh format: one word per line, hex).

Instruction word is 64 bits. Field layout (matching tprocv1.sv):

  I-Type: [63:56] opcode | [55:53] page | [52:50] ch | [49:46] oper |
          [45:41] ra | [40:36] rb | [35:31] rc | [30:0] imm

  J-Type: [63:56] opcode | [55:53] page | [52:50] ch | [49:46] oper |
          [45:41] ra | [40:36] rb | [35:31] rc | [30:16] (unused) | [15:0] addr

  R-Type: [63:56] opcode | [55:53] page | [52:50] ch | [49:46] oper |
          [45:41] ra | [40:36] rb | [35:31] rc | [30:26] rd | [25:21] re |
          [20:16] rf | [15:11] rg | [10:6] rh | [5:0] (unused)

Datapath operand mapping (important!):
  ra (ir[45:41]) -> addr7 : write-back destination register
  rb (ir[40:36]) -> addr0 -> reg_dout0 : ALU 'a', dmem_addr, comparator 'a', stack
  rc (ir[35:31]) -> addr1 -> reg_dout1 : ALU 'b', dmem_di, comparator 'b'
"""

# -----------------------------------------------------------------------------
# Opcodes (8-bit)
# -----------------------------------------------------------------------------
# I-Type
OP_PUSHI = 0x10
OP_POPI  = 0x11
OP_MATHI = 0x12
OP_SETI  = 0x13
OP_SYNCI = 0x14
OP_WAITI = 0x15
OP_BITWI = 0x16
OP_MEMRI = 0x17
OP_MEMWI = 0x18
OP_REGWI = 0x19
OP_SETBI = 0x1A
# J-Type
OP_LOOPNZ = 0x30
OP_CONDJ  = 0x31
OP_END    = 0x3F
# R-Type
OP_MATH = 0x50
OP_SET  = 0x51
OP_SYNC = 0x52
OP_READ = 0x53
OP_WAIT = 0x54
OP_BITW = 0x55
OP_MEMR = 0x56
OP_MEMW = 0x57
OP_SETB = 0x58

# -----------------------------------------------------------------------------
# ALU / arithmetic operations (4-bit oper field)
# -----------------------------------------------------------------------------
ARITH_ADD = 0b1000   # a + b
ARITH_SUB = 0b1001   # a - b
ARITH_MUL = 0b1010   # a * b

# Bitwise operations
BIT_AND = 0b0000
BIT_OR  = 0b0001
BIT_XOR = 0b0010
BIT_NOT = 0b0011
BIT_LSH = 0b0100
BIT_RSH = 0b0101

# Conditional operations (for CONDJ)
COND_GT = 0b0000   # a >  b
COND_GE = 0b0001   # a >= b
COND_LT = 0b0010   # a <  b
COND_LE = 0b0011   # a <= b
COND_EQ = 0b0100   # a == b
COND_NE = 0b0101   # a != b

# READ operation selector
READ_UPPER = 0b1010  # upper 32 bits
READ_LOWER = 0b0000  # lower 32 bits


# -----------------------------------------------------------------------------
# Bit-field helpers
# -----------------------------------------------------------------------------
def _field(value, width, name):
    """Mask a value to `width` bits, raising on overflow."""
    mask = (1 << width) - 1
    if value < 0:
        value &= mask  # two's complement wrap
    if value > mask:
        raise ValueError(f"{name}={value} does not fit in {width} bits")
    return value & mask


# -----------------------------------------------------------------------------
# Instruction builders
# -----------------------------------------------------------------------------
def itype(opcode, imm, ra=0, rb=0, rc=0, oper=0, page=0, ch=0):
    """Build a 64-bit I-Type instruction word."""
    w  = _field(opcode, 8, "opcode") << 56
    w |= _field(page,   3, "page")   << 53
    w |= _field(ch,     3, "ch")     << 50
    w |= _field(oper,   4, "oper")   << 46
    w |= _field(ra,     5, "ra")     << 41
    w |= _field(rb,     5, "rb")     << 36
    w |= _field(rc,     5, "rc")     << 31
    w |= _field(imm,   31, "imm")
    return w


def jtype(opcode, addr=0, ra=0, rb=0, rc=0, oper=0, page=0, ch=0):
    """Build a 64-bit J-Type instruction word."""
    w  = _field(opcode, 8, "opcode") << 56
    w |= _field(page,   3, "page")   << 53
    w |= _field(ch,     3, "ch")     << 50
    w |= _field(oper,   4, "oper")   << 46
    w |= _field(ra,     5, "ra")     << 41
    w |= _field(rb,     5, "rb")     << 36
    w |= _field(rc,     5, "rc")     << 31
    w |= _field(addr,  16, "addr")
    return w


def rtype(opcode, ra=0, rb=0, rc=0, rd=0, re=0, rf=0, rg=0, rh=0,
          oper=0, page=0, ch=0):
    """Build a 64-bit R-Type instruction word."""
    w  = _field(opcode, 8, "opcode") << 56
    w |= _field(page,   3, "page")   << 53
    w |= _field(ch,     3, "ch")     << 50
    w |= _field(oper,   4, "oper")   << 46
    w |= _field(ra,     5, "ra")     << 41
    w |= _field(rb,     5, "rb")     << 36
    w |= _field(rc,     5, "rc")     << 31
    w |= _field(rd,     5, "rd")     << 26
    w |= _field(re,     5, "re")     << 21
    w |= _field(rf,     5, "rf")     << 16
    w |= _field(rg,     5, "rg")     << 11
    w |= _field(rh,     5, "rh")     << 6
    return w


# -----------------------------------------------------------------------------
# Convenience pseudo-instructions (named, readable API)
# -----------------------------------------------------------------------------
def regwi(rd, imm, page=0):
    """rd = imm   (rd uses the ra field / addr7 write port)"""
    return itype(OP_REGWI, imm, ra=rd, page=page)

def mathi(rd, rs, imm, oper=ARITH_ADD, page=0):
    """rd = rs <oper> imm   (rs read on rb/reg_dout0)"""
    return itype(OP_MATHI, imm, ra=rd, rb=rs, oper=oper, page=page)

def bitwi(rd, rs, imm, oper=BIT_AND, page=0):
    """rd = rs <bitop> imm"""
    return itype(OP_BITWI, imm, ra=rd, rb=rs, oper=oper, page=page)

def memwi(rsrc, addr, page=0):
    """mem[addr] = rsrc   (rsrc on rc field -> reg_dout1 -> dmem_di)"""
    return itype(OP_MEMWI, addr, rc=rsrc, page=page)

def memri(rd, addr, page=0):
    """rd = mem[addr]"""
    return itype(OP_MEMRI, addr, ra=rd, page=page)

def loopnz(rcnt, addr, page=0):
    """if rcnt != 0: rcnt--, jump to addr   (rcnt on rb/reg_dout0)"""
    return jtype(OP_LOOPNZ, addr, rb=rcnt, oper=ARITH_ADD, page=page)

def condj(ra, rb, addr, cond=COND_GT, page=0):
    """if (reg_a <cond> reg_b): jump to addr
       ra -> rb field (reg_dout0 / comparator a)
       rb -> rc field (reg_dout1 / comparator b)"""
    return jtype(OP_CONDJ, addr, rb=ra, rc=rb, oper=cond, page=page)

def read(rd, ch, upper=False, page=0):
    """rd = s<ch>_axis input port"""
    op = READ_UPPER if upper else READ_LOWER
    return rtype(OP_READ, ra=rd, oper=op, ch=ch, page=page)

def synci(t):
    """sync master clock to time t (immediate)"""
    return itype(OP_SYNCI, t)

def waiti(ch, t):
    """wait until master clock = t on channel ch (immediate)"""
    return itype(OP_WAITI, t, ch=ch)

def seti(ch, rsrc, t, page=0):
    """set value of register rsrc at time t on channel ch
       rsrc on rb field (reg_dout0)"""
    return itype(OP_SETI, t, rb=rsrc, ch=ch, page=page)

def end():
    """terminate program"""
    return OP_END << 56


# -----------------------------------------------------------------------------
# Output writers
# -----------------------------------------------------------------------------
def write_pmem(filename, program, pad_to=None):
    """Write a list of 64-bit instruction words to a $readmemh file.
       If pad_to is given, fill remaining slots with END."""
    prog = list(program)
    if pad_to is not None:
        while len(prog) < pad_to:
            prog.append(end())
    with open(filename, "w") as f:
        for i, w in enumerate(prog):
            f.write(f"{w & 0xFFFFFFFFFFFFFFFF:016X}  // [{i}]\n")
    print(f"Wrote {len(prog)} instructions to {filename}")


def write_dmem(filename, data, size=None):
    """Write 32-bit data words to a $readmemh file.
       data can be a dict {addr: value} or a list."""
    if isinstance(data, dict):
        n = size if size else (max(data.keys()) + 1 if data else 0)
        arr = [0] * n
        for a, v in data.items():
            arr[a] = v
    else:
        arr = list(data)
        if size:
            arr += [0] * (size - len(arr))
    with open(filename, "w") as f:
        for d in arr:
            f.write(f"{d & 0xFFFFFFFF:08X}\n")
    print(f"Wrote {len(arr)} data words to {filename}")


# -----------------------------------------------------------------------------
# Example program: sum 1..5 using a loop, store result in mem[10]
# -----------------------------------------------------------------------------
def example_program():
    """
    Pseudocode:
      r1 = 0          ; accumulator
      r2 = 5          ; loop counter
      r3 = 0          ; index value
    loop:
      r3 = r3 + 1     ; (we use the counter indirectly here for demo)
      r1 = r1 + r2    ; accumulate counter value
      loopnz r2, loop ; decrement r2 and jump back if != 0
      mem[10] = r1    ; store result
      end

    NOTE: This is a simplified illustrative program. Adjust to your needs.
    """
    R_ACC  = 1
    R_CNT  = 2
    LOOP   = 1   # address of the loop body (instruction index)

    prog = []
    prog.append(regwi(R_ACC, 0))            # [0] r1 = 0
    # LOOP starts here:
    prog.append(mathi(R_ACC, R_ACC, 5,      # [1] r1 = r1 + 5  (demo: add constant)
                      oper=ARITH_ADD))
    prog.append(regwi(R_CNT, 4))            # [2] (placeholder)
    prog.append(loopnz(R_CNT, LOOP))        # [3] if r2!=0: r2--, jump to [1]
    prog.append(memwi(R_ACC, 10))           # [4] mem[10] = r1
    prog.append(end())                      # [5] end
    return prog


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(description="tProcV1 program generator")
    ap.add_argument("--pmem", default="pmem.hex", help="output program hex file")
    ap.add_argument("--dmem", default="dmem.hex", help="output data hex file")
    ap.add_argument("--pad",  type=int, default=None, help="pad program to N words")
    args = ap.parse_args()

    prog = example_program()
    write_pmem(args.pmem, prog, pad_to=args.pad)

    # Initial data memory (optional)
    init_data = {3: 0x0000000A}   # mem[3] = 10
    write_dmem(args.dmem, init_data, size=16)