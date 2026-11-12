#!/usr/bin/env python3
"""Assembles the small tProc v2 programs of tests/qick_processor_tests.sv with the real assembler of the repo
(qick_lib/qick/tprocv2_assembler.py) and writes them as 256-bit rows, in hex, one row per instruction: the
rows the driver (`Axis_QICK_Proc.load_mem('pmem', ...)`) sends on the DMA stream, 8 int32 words, word 0 in the low bits.

Usage:  gen_prog.py [outdir]        writes prog_<name>.hex and prog_<name>.lst, default the directory of this script.
Regenerate them whenever the assembler changes: the test then checks the binary the real assembler produces against the RTL.
"""
import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ASM = os.path.normpath(os.path.join(HERE, '../../../../../../../qick_lib/qick/tprocv2_assembler.py'))

PROGRAMS = {
    # DPORT_WR of a constant: the first instruction that has an effect at a pin.
    'dport': """
REG_WR r1 imm #9
DPORT_WR p0 reg r1
END:
JUMP END
""",
    # a counted loop, then the count on the port: 5 iterations of r1 = r1 - 1, port gets the number of iterations done (r2)
    'loop': """
REG_WR r1 imm #5
REG_WR r2 imm #0
LOOP:
REG_WR r2 op -op(r2 + #1)
REG_WR r1 op -op(r1 - #1) -uf
JUMP LOOP -if(NZ)
DPORT_WR p0 reg r2
END:
JUMP END
""",
    # one PA and one PB, four operands each, different op codes
    'pa_pb': """
REG_WR r1 imm #5
REG_WR r2 imm #7
REG_WR r3 imm #9
REG_WR r4 imm #11
PA 3 r1 r2 r3 r4
PB 4 r4 r3 r2 r1
END:
JUMP END
""",
    # wait until QPB_DT_NEW (s_status bit 11) is set, clear it with CLEAR qpb, and tell the testbench on the port
    'clear_qpb': """
WAITB:
TEST -op(s_status AND #h0800) -uf
JUMP WAITB -if(Z)
CLEAR qpb
REG_WR r1 imm #1
DPORT_WR p0 reg r1
END:
JUMP END
""",
    # same with QPA_DT_NEW (bit 9) and CLEAR qpa
    'clear_qpa': """
WAITA:
TEST -op(s_status AND #h0200) -uf
JUMP WAITA -if(Z)
CLEAR qpa
REG_WR r1 imm #1
DPORT_WR p0 reg r1
END:
JUMP END
""",
    # openquantumhardware/qick#359: PA/PB with s6/s7 (the peripheral return-data registers) as a SOURCE operand hung the core: the
    # hazard unit counted the instruction's own peripheral use as an earlier peripheral write whose result it had to wait for.
    # Each marker 0x5A5A in data memory shows how far the program got: [1] after the PA, [2] after the PB, [3] after the read of
    # s6, [4] after the read of s7, [0] the end. 'pa_s6_s7' has s6/s7 in the operands of the data section (R1, R2), 'pa_s6_s7_cd'
    # in those of the address section (R3, R4). The first one is the program of the old qick_testbench (test_issue359).
    'pa_s6_s7': """
REG_WR r0 imm #10
REG_WR r1 imm #3
PA 3 s6 r1 r0 r1
DMEM_WR [&1] imm #23130
PB 3 r0 s7 r1 r0
DMEM_WR [&2] imm #23130
REG_WR r2 imm #1234
REG_WR r3 op -op(s6 + #0)
DMEM_WR [&3] imm #23130
REG_WR r4 op -op(s7 + #0)
DMEM_WR [&4] imm #23130
DMEM_WR [&0] imm #23130
END:
JUMP END
""",
    'pa_s6_s7_cd': """
REG_WR r0 imm #10
REG_WR r1 imm #3
PA 3 r0 r1 s6 s7
DMEM_WR [&1] imm #23130
PB 3 r0 r1 s7 s6
DMEM_WR [&2] imm #23130
REG_WR r2 imm #1234
REG_WR r3 op -op(s6 + #0)
DMEM_WR [&3] imm #23130
REG_WR r4 op -op(s7 + #0)
DMEM_WR [&4] imm #23130
DMEM_WR [&0] imm #23130
END:
JUMP END
""",
    # all 16 data registers: each takes a distinct value (stored to dmem[0..15]), then each takes s_zero (stored to dmem[16..31]).
    # dmem[32] = 1 marks the end. From the old qick_testbench (test_tproc_basic, first part).
    'regs': """
REG_WR r0 imm #4096
REG_WR r1 imm #4097
REG_WR r2 imm #4098
REG_WR r3 imm #4099
REG_WR r4 imm #4100
REG_WR r5 imm #4101
REG_WR r6 imm #4102
REG_WR r7 imm #4103
REG_WR r8 imm #4104
REG_WR r9 imm #4105
REG_WR r10 imm #4106
REG_WR r11 imm #4107
REG_WR r12 imm #4108
REG_WR r13 imm #4109
REG_WR r14 imm #4110
REG_WR r15 imm #4111
DMEM_WR [&0] op -op(r0 + #0)
DMEM_WR [&1] op -op(r1 + #0)
DMEM_WR [&2] op -op(r2 + #0)
DMEM_WR [&3] op -op(r3 + #0)
DMEM_WR [&4] op -op(r4 + #0)
DMEM_WR [&5] op -op(r5 + #0)
DMEM_WR [&6] op -op(r6 + #0)
DMEM_WR [&7] op -op(r7 + #0)
DMEM_WR [&8] op -op(r8 + #0)
DMEM_WR [&9] op -op(r9 + #0)
DMEM_WR [&10] op -op(r10 + #0)
DMEM_WR [&11] op -op(r11 + #0)
DMEM_WR [&12] op -op(r12 + #0)
DMEM_WR [&13] op -op(r13 + #0)
DMEM_WR [&14] op -op(r14 + #0)
DMEM_WR [&15] op -op(r15 + #0)
REG_WR r0 op -op(s_zero + #0)
REG_WR r1 op -op(s_zero + #0)
REG_WR r2 op -op(s_zero + #0)
REG_WR r3 op -op(s_zero + #0)
REG_WR r4 op -op(s_zero + #0)
REG_WR r5 op -op(s_zero + #0)
REG_WR r6 op -op(s_zero + #0)
REG_WR r7 op -op(s_zero + #0)
REG_WR r8 op -op(s_zero + #0)
REG_WR r9 op -op(s_zero + #0)
REG_WR r10 op -op(s_zero + #0)
REG_WR r11 op -op(s_zero + #0)
REG_WR r12 op -op(s_zero + #0)
REG_WR r13 op -op(s_zero + #0)
REG_WR r14 op -op(s_zero + #0)
REG_WR r15 op -op(s_zero + #0)
DMEM_WR [&16] op -op(r0 + #0)
DMEM_WR [&17] op -op(r1 + #0)
DMEM_WR [&18] op -op(r2 + #0)
DMEM_WR [&19] op -op(r3 + #0)
DMEM_WR [&20] op -op(r4 + #0)
DMEM_WR [&21] op -op(r5 + #0)
DMEM_WR [&22] op -op(r6 + #0)
DMEM_WR [&23] op -op(r7 + #0)
DMEM_WR [&24] op -op(r8 + #0)
DMEM_WR [&25] op -op(r9 + #0)
DMEM_WR [&26] op -op(r10 + #0)
DMEM_WR [&27] op -op(r11 + #0)
DMEM_WR [&28] op -op(r12 + #0)
DMEM_WR [&29] op -op(r13 + #0)
DMEM_WR [&30] op -op(r14 + #0)
DMEM_WR [&31] op -op(r15 + #0)
DMEM_WR [&32] imm #1
END:
JUMP END
""",
}


def loopback_program(a_value, repeat_pa=1):
    """Built with the QickProgramV2 macros (periph_*), lowered by tests/data/asm_lowering.py: one PA to the loopback
    peripheral, wait for its answer, read it, branch on the QP1 flag, store the results in data memory:
        dmem[0] = a + b, dmem[1] = c ^ d ^ op, dmem[2] = 1 if the flag was clear / 2 if set, dmem[3] = 1 when done.
    repeat_pa > 1 issues the PA that many times back to back (the loopback drops the ones that arrive while it is busy)."""
    sys.path.insert(0, HERE)
    from asm_lowering import FakeProg
    p = FakeProg()
    p.write_reg('r1', a_value)
    p.write_reg('r2', 23)
    p.write_reg('r3', 0xF0F0)
    p.write_reg('r4', 0x0F00)
    for _ in range(repeat_pa):
        p.periph_write('a', 5, 'r1', 'r2', 'r3', 'r4')
    p.periph_config(data='a', flag='a')
    p.periph_wait('a', 'WAITA')
    p.periph_read('a', 'r5', 'r6')
    p.write_dmem(0, 'r5')
    p.write_dmem(1, 'r6')
    p.cond_jump(label='FLAGSET', arg1='s_zero', test='F')
    p.write_reg('r7', 1)
    p.jump('DONE')
    p.label('FLAGSET')
    p.write_reg('r7', 2)
    p.label('DONE')
    p.write_dmem(2, 'r7')
    p.periph_clear('a')
    p.write_dmem(3, 1)
    p.end()
    return p.lower().binary()


MACRO_PROGRAMS = {
    'lb_flag0': lambda: loopback_program(100),                  # a even -> flag 0
    'lb_flag1': lambda: loopback_program(101),                  # a odd  -> flag 1
    'lb_busy':  lambda: loopback_program(100, repeat_pa=3),     # three PA back to back: one taken, two dropped
}


def _periph_programs():
    spec = importlib.util.spec_from_file_location('periph_programs', os.path.join(HERE, 'periph_programs.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _nb(fn, *args):
    """A program of the QP1/QP2 hardware notebook (periph_programs.py), lowered with the 4096-word program memory of
    the RFSoC4x2 debug bench: jumps go through s15 (REG_WR s15 label, JUMP s15), the code path of the board. The bench's
    own pmem is smaller, but the program is a few dozen words and its addresses fit."""
    def build():
        sys.path.insert(0, HERE)
        from asm_lowering import FakeProg
        p = FakeProg()
        p.tproccfg = {'pmem_size': 4096, 'dreg_qty': 16}
        fn(p, *args)
        return p.lower().binary()
    return build


def notebook_programs():
    """name -> builder, with the operands the RTL bench (tc_nb_* in qick_processor_prog_tests.sv) expects"""
    m = _periph_programs()
    return {
        'nb_one_a':      _nb(m.prog_one, 'a', 5, 0xFFFFFFF0, 0x20, 0xAAAA5555, 0x0F0F0F0F),
        'nb_one_b':      _nb(m.prog_one, 'b', 31, 0x12345678, 0x0000FFFF, 0xDEADBEEF, 0x01234567),
        'nb_both':       _nb(m.prog_both, (3, 0x80000000, 0x80000000, 0xFFFF0000, 0x0000FFFF),
                             (30, 1000, 2000, 0x13579BDF, 0x2468ACE0)),
        'nb_clear_a':    _nb(m.prog_clear, 'a'),
        'nb_clear_b':    _nb(m.prog_clear, 'b'),
        'nb_flag_odd':   _nb(m.prog_flag_a, 0xFFFFFFFF),
        'nb_flag_even':  _nb(m.prog_flag_a, 0xFFFFFFFE),
        'nb_flagb_odd':  _nb(m.prog_flag_b, 0xFFFFFFFF),
        'nb_flagb_even': _nb(m.prog_flag_b, 0xFFFFFFFE),
        'nb_cross_a1_b0': _nb(m.prog_flag_cross, 0x1, 0x2),
        'nb_cross_a0_b1': _nb(m.prog_flag_cross, 0x2, 0x1),
        'nb_busy_a':     _nb(m.prog_busy, 'a', 6, 9, 1000, 2000, 3, 4),
        'nb_busy_b':     _nb(m.prog_busy, 'b', 6, 9, 1000, 2000, 3, 4),
        'nb_ext_flag':   _nb(m.prog_ext_flag),
        'nb_ext_poll':   _nb(m.prog_ext_poll),
    }


def load_assembler():
    spec = importlib.util.spec_from_file_location('tprocv2_assembler', ASM)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.Assembler


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else HERE
    asm = load_assembler()
    items = [(n, (lambda src=src: asm.str_asm2bin(src))) for n, src in PROGRAMS.items()] + list(MACRO_PROGRAMS.items()) + list(notebook_programs().items())
    for name, build in items:
        listing, rows = build()
        with open(os.path.join(out, f'prog_{name}.hex'), 'w') as fh:
            for r in rows:
                assert len(r) == 8
                v = 0
                for i, w in enumerate(r):
                    v |= (w & 0xFFFFFFFF) << (32 * i)
                fh.write(f'{v:064x}\n')
        with open(os.path.join(out, f'prog_{name}.lst'), 'w') as fh:
            fh.write(''.join(l.rstrip() + '\n' for l in listing))
        print(f'{name}: {len(rows)} instructions')


if __name__ == '__main__':
    main()
