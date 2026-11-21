"""A minimal stand-in for QickProgramV2, to lower tProc v2 macros (qick_lib/qick/asm_v2.py) to the instruction list of the real
assembler without a soccfg: registers by name (r0..r31, w0..w5, s0..s15 and the s_* aliases), a program list with P_ADDR / LINE,
and labels as '&addr' (the same contract as QickProgramV2._add_asm / _add_label / _get_reg).

Used by tests/data/gen_prog.py (the programs of the RTL bench) and driver/tests/test_asm_v2_periph.py.
"""
import sys
from pathlib import Path

_SCRIPTS = Path(__file__).resolve().parents[5] / "scripts"      # firmware/fusesoc/scripts
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))
import driver_testing  # noqa: E402,F401  (puts qick_lib on sys.path and stubs pynq when it is not installed)
from qick import asm_v2  # noqa: E402
from qick.tprocv2_assembler import Assembler  # noqa: E402


class FakeProg(asm_v2.AsmV2):
    REG_ALIASES = asm_v2.QickProgramV2.REG_ALIASES
    tproccfg = {'pmem_size': 1024, 'dreg_qty': 16}

    def __init__(self):
        super().__init__()
        self.prog_list = [{'CMD': 'NOP', 'P_ADDR': 0}]
        self.labels = {}
        self.p_addr = 1
        self.line = 1

    def _get_reg(self, name):
        if name in self.REG_ALIASES:
            return self.REG_ALIASES[name]
        return name

    def _add_asm(self, inst, addr_inc=1):
        inst = inst.copy()
        inst['P_ADDR'] = self.p_addr
        inst['LINE'] = self.line
        self.p_addr += addr_inc
        self.line += 1
        self.prog_list.append(inst)

    def _add_label(self, label):
        self.line += 1
        self.labels[label] = '&%d' % (self.p_addr)

    def lower(self):
        for m in self.macro_list:
            m.translate(self)
        return self

    def binary(self):
        """(listing, rows): the 8-word rows the driver sends to the program memory"""
        return Assembler.list2bin(self.prog_list, self.labels, dreg_qty=16)
