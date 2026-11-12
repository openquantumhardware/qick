# gen_pmem.py
def itype(opcode, page, ch, oper, ra, rb, rc, imm):
    word  = (opcode & 0xFF) << 56
    word |= (page   & 0x7)  << 53
    word |= (ch     & 0x7)  << 50
    word |= (oper   & 0xF)  << 46
    word |= (ra     & 0x1F) << 41
    word |= (rb     & 0x1F) << 36
    word |= (rc     & 0x1F) << 31
    word |= (imm    & 0x7FFFFFFF)
    return word

OP_REGWI = 0x19
OP_MEMWI = 0x18
OP_END   = 0x3F

prog = [
    itype(OP_REGWI, 0,0,0, 1,0,0, 0x12345678 & 0x7FFFFFFF),  # r1 = ...
    itype(OP_MEMWI, 0,0,0, 0,0,1, 10),                       # mem[10] = r1
    (OP_END << 56),                                          # end
]

with open("pmem.hex", "w") as f:
    for w in prog:
        f.write(f"{w:016X}\n")