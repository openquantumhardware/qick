# The tProc v2 programs of the QP1 / QP2 hardware validation notebook, written with the
# QickProgramV2 peripheral macros of #129. This file is the source: the notebook cell "Programs" is a verbatim copy
# (driver/tests/test_periph_notebook_programs.py fails if they differ), and tests/data/gen_prog.py assembles the same
# functions into the hex files that the RTL bench (tests/qick_processor_prog_tests.sv, tc_nb_*) runs on the real core.
# The `p` argument is anything with the AsmV2 methods: a QickProgramV2 on the board, asm_lowering.FakeProg in the repository tests.

DONE = 15           # dmem word that every program sets to 1 as its last act (the PS clears it before the start)
NOPS = 4            # NOPs between a CLEAR and the status snapshot, so the one-shot clear has taken effect

# s_status bits (TRM 4.6). The registered ext flag is not here: it is bit 15 of TPROC_STATUS, which only the PS reads.
QPA_RDY, QPA_NEW, QPB_RDY, QPB_NEW = 1 << 8, 1 << 9, 1 << 10, 1 << 11

def s32(v):
    """REG_WR literals are signed 32 bit: 0xFFFFFFFF is written as -1"""
    v &= 0xFFFFFFFF
    return v - (1 << 32) if v & 0x80000000 else v

def model(op, a, b, c, d):
    """what qick_periph_loopback answers: (dt1, dt2)"""
    return (a + b) & 0xFFFFFFFF, (c ^ d ^ op) & 0xFFFFFFFF

def _load(p, regs, vals):
    for r, v in zip(regs, vals):
        p.write_reg(r, s32(v))

def prog_one(p, which, op, a, b, c, d):
    """one command to peripheral `which` ('a' = PA/QP1, 'b' = PB/QP2); dmem[0:2] = the two result words,
    dmem[2] = s_status when the answer had arrived"""
    _load(p, ['r1', 'r2', 'r3', 'r4'], [a, b, c, d])
    p.periph_config(data=which)
    p.periph_clear(which)
    p.periph_write(which, op, 'r1', 'r2', 'r3', 'r4')
    p.periph_wait(which, 'W_RSP')
    p.write_reg('r13', 's_status')
    p.periph_read(which, 'r9', 'r10')
    p.write_dmem(0, 'r9')
    p.write_dmem(1, 'r10')
    p.write_dmem(2, 'r13')
    p.write_dmem(DONE, 1)
    p.end()

def prog_both(p, qa, qb):
    """PA and PB back to back, each with its own op and four operands; dmem[0:2] = A's words, dmem[2:4] = B's"""
    _load(p, ['r1', 'r2', 'r3', 'r4'], qa[1:])
    _load(p, ['r5', 'r6', 'r7', 'r8'], qb[1:])
    p.periph_config(data='a')
    p.periph_clear('a')
    p.periph_clear('b')
    p.periph_write('a', qa[0], 'r1', 'r2', 'r3', 'r4')
    p.periph_write('b', qb[0], 'r5', 'r6', 'r7', 'r8')
    p.periph_wait('a', 'W_A')
    p.periph_wait('b', 'W_B')
    p.periph_read('a', 'r9', 'r10')
    p.periph_read('b', 'r11', 'r12')
    p.write_dmem(0, 'r9')
    p.write_dmem(1, 'r10')
    p.write_dmem(2, 'r11')
    p.write_dmem(3, 'r12')
    p.write_dmem(DONE, 1)
    p.end()

def prog_clear(p, first):
    """both peripherals answer, then the new-data flags are cleared one at a time, `first` first.
    dmem[4] = s_status with both answers in, [5] = after the two reads, [6] = after the first CLEAR, [7] = after the second"""
    second = 'b' if first == 'a' else 'a'
    _load(p, ['r1', 'r2', 'r3', 'r4'], [1, 2, 3, 4])
    _load(p, ['r5', 'r6', 'r7', 'r8'], [5, 6, 7, 8])
    p.periph_config(data='a')
    p.periph_clear('a')
    p.periph_clear('b')
    p.periph_write('a', 1, 'r1', 'r2', 'r3', 'r4')
    p.periph_write('b', 2, 'r5', 'r6', 'r7', 'r8')
    p.periph_wait('a', 'W_A')
    p.periph_wait('b', 'W_B')
    p.write_reg('r13', 's_status')
    p.write_dmem(4, 'r13')
    p.periph_read('a', 'r9', 'r10')
    p.periph_read('b', 'r11', 'r12')
    p.write_reg('r13', 's_status')
    p.write_dmem(5, 'r13')
    p.periph_clear(first)
    for _ in range(NOPS):
        p.nop()
    p.write_reg('r13', 's_status')
    p.write_dmem(6, 'r13')
    p.periph_clear(second)
    for _ in range(NOPS):
        p.nop()
    p.write_reg('r13', 's_status')
    p.write_dmem(7, 'r13')
    p.write_dmem(DONE, 1)
    p.end()

def prog_flag_a(p, a_value):
    """one PA, then branch on the QP1 flag (flg_qpa): dmem[2] = 1 when the flag was clear, 2 when set"""
    _load(p, ['r1', 'r2', 'r3', 'r4'], [a_value, 23, 0xF0F0, 0x0F00])
    p.periph_config(data='a', flag='a')
    p.periph_clear('a')
    p.periph_write('a', 5, 'r1', 'r2', 'r3', 'r4')
    p.periph_wait('a', 'W_RSP')
    p.periph_read('a', 'r9', 'r10')
    p.write_dmem(0, 'r9')
    p.write_dmem(1, 'r10')
    p.cond_jump(label='L_SET', arg1='s_zero', test='F')
    p.write_reg('r7', 1)
    p.jump('L_END')
    p.label('L_SET')
    p.write_reg('r7', 2)
    p.label('L_END')
    p.write_dmem(2, 'r7')
    p.write_dmem(DONE, 1)
    p.end()

def prog_busy(p, which, n, op, a, b, c, d):
    """n PA (or PB) back to back with the same operands. The peripheral takes the first and drops what arrives while
    it is busy; the counters of the loopback say how many of each. dmem[0:2] = the words read after the first answer"""
    _load(p, ['r1', 'r2', 'r3', 'r4'], [a, b, c, d])
    p.periph_config(data=which)
    p.periph_clear(which)
    for _ in range(n):
        p.periph_write(which, op, 'r1', 'r2', 'r3', 'r4')
    p.periph_wait(which, 'W_RSP')
    p.periph_read(which, 'r9', 'r10')
    p.write_dmem(0, 'r9')
    p.write_dmem(1, 'r10')
    p.write_dmem(DONE, 1)
    p.end()

def prog_ext_flag(p):
    """branch on ext_flag_i (flg_ext): dmem[2] = 1 when clear, 2 when set"""
    p.periph_config(flag='ext')
    p.nop()
    p.nop()
    p.cond_jump(label='L_SET', arg1='s_zero', test='F')
    p.write_reg('r7', 1)
    p.jump('L_END')
    p.label('L_SET')
    p.write_reg('r7', 2)
    p.label('L_END')
    p.write_dmem(2, 'r7')
    p.write_dmem(DONE, 1)
    p.end()

def prog_ext_poll(p):
    """wait in a loop until ext_flag_i is set (the PS raises it after the start); dmem[0] counts the loop passes"""
    p.periph_config(flag='ext')
    p.write_reg('r1', 0)
    p.label('L_POLL')
    p.inc_reg('r1', 1)
    p.cond_jump(label='L_POLL', arg1='s_zero', test='NF')
    p.write_dmem(0, 'r1')
    p.write_dmem(DONE, 1)
    p.end()

def prog_flag_b(p, a_value):
    """one PB, then branch on the QP2 flag (flg_qpb, tProc v2 revision 29 or newer): dmem[2] = 1 when the flag was clear, 2 when set"""
    _load(p, ['r1', 'r2', 'r3', 'r4'], [a_value, 23, 0xF0F0, 0x0F00])
    p.periph_config(data='b', flag='b')
    p.periph_clear('b')
    p.periph_write('b', 6, 'r1', 'r2', 'r3', 'r4')
    p.periph_wait('b', 'W_RSP')
    p.periph_read('b', 'r9', 'r10')
    p.write_dmem(0, 'r9')
    p.write_dmem(1, 'r10')
    p.cond_jump(label='L_SET', arg1='s_zero', test='F')
    p.write_reg('r7', 1)
    p.jump('L_END')
    p.label('L_SET')
    p.write_reg('r7', 2)
    p.label('L_END')
    p.write_dmem(2, 'r7')
    p.write_dmem(DONE, 1)
    p.end()

def prog_flag_cross(p, a_a, a_b):
    """PA(a = a_a) and PB(a = a_b), both answered; then the same conditional jump twice, once with the flag source on QP2 and
    once on QP1: dmem[2] = 1/2 for the QP2 flag clear/set, dmem[3] = 1/2 for the QP1 flag. The two flags differ when a_a and a_b have
    different bit 0, so a mux that picks the wrong port shows"""
    _load(p, ['r1', 'r2', 'r3', 'r4'], [a_a, 1, 2, 3])
    _load(p, ['r5', 'r6', 'r7', 'r8'], [a_b, 4, 5, 6])
    p.periph_config(data='a')
    p.periph_clear('a')
    p.periph_clear('b')
    p.periph_write('a', 5, 'r1', 'r2', 'r3', 'r4')
    p.periph_write('b', 6, 'r5', 'r6', 'r7', 'r8')
    p.periph_wait('a', 'W_A')
    p.periph_wait('b', 'W_B')
    p.periph_config(flag='b')
    p.cond_jump(label='L_B_SET', arg1='s_zero', test='F')
    p.write_reg('r9', 1)
    p.jump('L_B_END')
    p.label('L_B_SET')
    p.write_reg('r9', 2)
    p.label('L_B_END')
    p.periph_config(flag='a')
    p.cond_jump(label='L_A_SET', arg1='s_zero', test='F')
    p.write_reg('r10', 1)
    p.jump('L_A_END')
    p.label('L_A_SET')
    p.write_reg('r10', 2)
    p.label('L_A_END')
    p.write_dmem(2, 'r9')
    p.write_dmem(3, 'r10')
    p.write_dmem(DONE, 1)
    p.end()
