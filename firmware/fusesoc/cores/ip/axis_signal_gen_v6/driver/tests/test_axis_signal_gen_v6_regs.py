# ============================================================================
# File: test_axis_signal_gen_v6_regs.py
# Description: Register-layer tests for axis_signal_gen_v6 using the
#   PeakRDL-generated register model + simulator (no hardware).
#
# Run:  pytest cores/ip/axis_signal_gen_v6/driver/tests/ -v
# ============================================================================
import pytest

from axis_signal_gen_v6_regmap_pkg.reg_model import RegModel
from axis_signal_gen_v6_regmap_pkg.sim import Simulator
from axis_signal_gen_v6_regmap_pkg.lib import NormalCallbackSet


def make_sim_regs():
    """Register model backed by the in-memory simulator (no hardware)."""
    sim = Simulator(address=0)
    return RegModel(
        callbacks=NormalCallbackSet(
            read_callback=sim.read,
            write_callback=sim.write,
            read_block_callback=sim.read_block,
            write_block_callback=sim.write_block,
        )
    )


@pytest.fixture
def regs():
    return make_sim_regs()


# ---------------------------------------------------------------------------
# Reset values
# ---------------------------------------------------------------------------
def test_reset_values(regs):
    assert regs.START_ADDR_REG.START_ADDR.read() == 0
    assert regs.WE_REG.WE.read() == 0
    assert regs.STATUS_REG.SATURATING.read() == 0
    assert regs.CTRL_REG.SAT_CLEAR.read() == 0


# ---------------------------------------------------------------------------
# start_addr and we round-trip
# ---------------------------------------------------------------------------
def test_start_addr_roundtrip(regs):
    regs.START_ADDR_REG.START_ADDR.write(0x1234)
    assert regs.START_ADDR_REG.START_ADDR.read() == 0x1234


def test_we_roundtrip(regs):
    regs.WE_REG.WE.write(1)
    assert regs.WE_REG.WE.read() == 1
    regs.WE_REG.WE.write(0)
    assert regs.WE_REG.WE.read() == 0


# ---------------------------------------------------------------------------
# Replicate the driver's load() register sequence:
#   _wr_enable(addr): start_addr_reg = addr; we_reg = 1
#   <DMA transfer>
#   _wr_disable():    we_reg = 0
# ---------------------------------------------------------------------------
def test_load_sequence(regs):
    addr = 0x40
    # _wr_enable
    regs.START_ADDR_REG.START_ADDR.write(addr)
    regs.WE_REG.WE.write(1)
    assert regs.START_ADDR_REG.START_ADDR.read() == addr
    assert regs.WE_REG.WE.read() == 1
    # <DMA happens on hardware>
    # _wr_disable
    regs.WE_REG.WE.write(0)
    assert regs.WE_REG.WE.read() == 0


# ---------------------------------------------------------------------------
# Saturation: status is read-only from software's view; clear via CTRL.
#   (In the simulator the hardware never sets it, but we can exercise the
#    software-visible access pattern: read STATUS, write CTRL.SAT_CLEAR.)
# ---------------------------------------------------------------------------
def test_saturation_clear_sequence(regs):
    # Software reads the status (0 in the pure-register simulator).
    assert regs.STATUS_REG.SATURATING.read() == 0
    # Issue a clear pulse via CTRL.
    regs.CTRL_REG.SAT_CLEAR.write(1)
    assert regs.CTRL_REG.SAT_CLEAR.read() == 1
    regs.CTRL_REG.SAT_CLEAR.write(0)
    assert regs.CTRL_REG.SAT_CLEAR.read() == 0


# ---------------------------------------------------------------------------
# Register independence: writing one doesn't disturb another.
# ---------------------------------------------------------------------------
def test_register_independence(regs):
    regs.START_ADDR_REG.START_ADDR.write(0xABCD)
    regs.WE_REG.WE.write(1)
    regs.CTRL_REG.SAT_CLEAR.write(1)
    # each keeps its own value
    assert regs.START_ADDR_REG.START_ADDR.read() == 0xABCD
    assert regs.WE_REG.WE.read() == 1
    assert regs.CTRL_REG.SAT_CLEAR.read() == 1