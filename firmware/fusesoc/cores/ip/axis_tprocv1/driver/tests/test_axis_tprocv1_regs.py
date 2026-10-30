# ============================================================================
# File: test_axis_tprocv1_regs.py
# Description: Python register-layer tests for axis_tprocv1 using the
#   PeakRDL-generated register model + in-memory simulator (no hardware).
#
#   Pattern follows the generated _axis_tprocv1_sim_test_base.py:
#     sim = Simulator(address=0)
#     dut = RegModel(callbacks=NormalCallbackSet(read/write/read_block/write_block))
#
# Run:  pytest cores/ip/axis_tprocv1/driver/tests/test_axis_tprocv1_regs.py -v
# ============================================================================
import pytest

# Clean aliases exported by the generated package
from axis_tprocv1_regmap_pkg.reg_model import RegModel
from axis_tprocv1_regmap_pkg.sim import Simulator
from axis_tprocv1_regmap_pkg.lib import NormalCallbackSet


def make_sim_regs():
    """Return a register model backed by the in-memory simulator (no HW)."""
    sim = Simulator(address=0)
    dut = RegModel(
        callbacks=NormalCallbackSet(
            read_callback=sim.read,
            write_callback=sim.write,
            read_block_callback=sim.read_block,
            write_block_callback=sim.write_block,
        )
    )
    return dut


@pytest.fixture
def regs():
    return make_sim_regs()


# ---------------------------------------------------------------------------
# Reset values
# ---------------------------------------------------------------------------
def test_reset_values(regs):
    assert regs.START_SRC_REG.START_SRC.read() == 0
    assert regs.START_REG.START.read() == 0
    assert regs.MEM_MODE_REG.MEM_MODE.read() == 0
    assert regs.MEM_START_REG.MEM_START.read() == 0
    assert regs.MEM_ADDR_REG.MEM_ADDR.read() == 0
    assert regs.MEM_LEN_REG.MEM_LEN.read() == 0


# ---------------------------------------------------------------------------
# Single-bit control fields round-trip
# ---------------------------------------------------------------------------
def test_control_bits_roundtrip(regs):
    regs.START_SRC_REG.START_SRC.write(1)
    assert regs.START_SRC_REG.START_SRC.read() == 1

    regs.MEM_MODE_REG.MEM_MODE.write(1)
    assert regs.MEM_MODE_REG.MEM_MODE.read() == 1

    regs.START_REG.START.write(1)
    assert regs.START_REG.START.read() == 1

    # clear
    regs.START_SRC_REG.START_SRC.write(0)
    regs.MEM_MODE_REG.MEM_MODE.write(0)
    assert regs.START_SRC_REG.START_SRC.read() == 0
    assert regs.MEM_MODE_REG.MEM_MODE.read() == 0


# ---------------------------------------------------------------------------
# Wide fields (addr / len) round-trip
# ---------------------------------------------------------------------------
def test_addr_len_roundtrip(regs):
    regs.MEM_ADDR_REG.MEM_ADDR.write(0x1234_5678)
    assert regs.MEM_ADDR_REG.MEM_ADDR.read() == 0x1234_5678

    regs.MEM_LEN_REG.MEM_LEN.write(100)
    assert regs.MEM_LEN_REG.MEM_LEN.read() == 100


# ---------------------------------------------------------------------------
# Replicate the driver load_dmem() register sequence (DMA write setup):
#   MEM_MODE=1, MEM_ADDR=addr, MEM_LEN=len, MEM_START=1, <DMA>, MEM_START=0
# ---------------------------------------------------------------------------
def test_load_dmem_sequence(regs):
    addr, length = 0, 100
    regs.MEM_MODE_REG.MEM_MODE.write(1)
    regs.MEM_ADDR_REG.MEM_ADDR.write(addr)
    regs.MEM_LEN_REG.MEM_LEN.write(length)
    regs.MEM_START_REG.MEM_START.write(1)

    assert regs.MEM_MODE_REG.MEM_MODE.read() == 1
    assert regs.MEM_ADDR_REG.MEM_ADDR.read() == addr
    assert regs.MEM_LEN_REG.MEM_LEN.read() == length
    assert regs.MEM_START_REG.MEM_START.read() == 1

    regs.MEM_START_REG.MEM_START.write(0)
    assert regs.MEM_START_REG.MEM_START.read() == 0


# ---------------------------------------------------------------------------
# Replicate the driver read_dmem() register sequence (DMA read setup)
# ---------------------------------------------------------------------------
def test_read_dmem_sequence(regs):
    addr, length = 0, 64
    regs.MEM_MODE_REG.MEM_MODE.write(0)   # read
    regs.MEM_ADDR_REG.MEM_ADDR.write(addr)
    regs.MEM_LEN_REG.MEM_LEN.write(length)
    regs.MEM_START_REG.MEM_START.write(1)

    assert regs.MEM_MODE_REG.MEM_MODE.read() == 0
    assert regs.MEM_LEN_REG.MEM_LEN.read() == length

    regs.MEM_START_REG.MEM_START.write(0)


# ---------------------------------------------------------------------------
# Replicate the driver start() sequence (pulse 0 -> 1)
# ---------------------------------------------------------------------------
def test_start_sequence(regs):
    regs.START_REG.START.write(0)   # arm
    assert regs.START_REG.START.read() == 0
    regs.START_REG.START.write(1)   # fire
    assert regs.START_REG.START.read() == 1


# ---------------------------------------------------------------------------
# Full register read/write via the whole map (independence check)
# ---------------------------------------------------------------------------
def test_register_independence(regs):
    regs.MEM_ADDR_REG.MEM_ADDR.write(0xAAAA_5555)
    regs.MEM_LEN_REG.MEM_LEN.write(0x0000_1234)
    # writing LEN must not disturb ADDR
    assert regs.MEM_ADDR_REG.MEM_ADDR.read() == 0xAAAA_5555
    assert regs.MEM_LEN_REG.MEM_LEN.read() == 0x0000_1234
