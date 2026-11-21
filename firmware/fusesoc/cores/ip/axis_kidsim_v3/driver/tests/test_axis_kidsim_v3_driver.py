"""Behaviour tests of the axis_kidsim_v3 driver (standalone AxisKidsimV3), off the board (firmware/docs/user/IP_INTEGRATION.md, D4).

FakeKidsim models the per-lane commit of the RTL: the parameter registers are a staging area, and a rising edge of
WE_REG copies them into the lane that ADDR_REG selects (README U2).
"""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "scripts"))
import driver_testing as dt                                     # noqa: E402
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))   # driver/
from axis_kidsim_v3 import AxisKidsimV3                        # noqa: E402

RDL = Path(__file__).resolve().parents[2] / "rdl" / "axis_kidsim_v3_regmap.rdl"
OFF = dt.rdl_offsets(RDL)
FIELDS = ('dds_bval_reg', 'dds_slope_reg', 'dds_steps_reg', 'dds_wait_reg', 'dds_freq_reg',
          'iir_c0_reg', 'iir_c1_reg', 'iir_g_reg', 'outsel_reg', 'punct_id_reg')


class FakeKidsim(dt.FakeMmio):
    def __init__(self, lanes):
        super().__init__()
        self.lanes = [None] * lanes
        self._we = 0

    def on_write(self, index, value):
        if index == OFF['we_reg'] // 4:
            if value & 1 and not self._we:
                lane = self.words[OFF['addr_reg'] // 4]
                self.lanes[lane] = {f: self.words[OFF[f] // 4] for f in FIELDS}
            self._we = value & 1


def make(lanes=8):
    mmio = FakeKidsim(lanes)
    return AxisKidsimV3(dt.description('qick:ip:axis_kidsim_v3:1.0', mmio, L=lanes)), mmio


def test_lanes_from_parameter():
    k, _ = make(lanes=4)
    assert k['lanes'] == 4


def test_config_lane_commits_to_the_addressed_lane_only():
    k, mmio = make()
    k.config_lane(3, outsel=k.OUT_SIGNAL, freq=0x0400, c1=k.q15(0.99), g=k.G_UNITY, punct=2)
    assert mmio.lanes[3] == dict(dds_bval_reg=0, dds_slope_reg=0, dds_steps_reg=0, dds_wait_reg=0,
                                 dds_freq_reg=0x0400, iir_c0_reg=0, iir_c1_reg=k.q15(0.99),
                                 iir_g_reg=0x7FFF, outsel_reg=0, punct_id_reg=2)
    assert all(mmio.lanes[i] is None for i in range(8) if i != 3)
    assert mmio.words[OFF['we_reg'] // 4] == 0          # WE left low, so the next commit has an edge


def test_every_field_is_rewritten_so_nothing_leaks_between_lanes():
    k, mmio = make()
    k.config_lane(0, outsel=k.OUT_DDS, freq=0x1234, c0=k.q15(-0.5), bval=0x10, slope=0x20, steps=5, wait=1)
    k.config_lane(1)                                    # defaults: bypass, all zero, G = unity
    assert mmio.lanes[1] == dict.fromkeys(FIELDS, 0) | dict(iir_g_reg=0x7FFF, outsel_reg=k.OUT_BYPASS)
    assert mmio.lanes[0]['dds_freq_reg'] == 0x1234 and mmio.lanes[0]['iir_c0_reg'] == 0xC000


def test_config_all():
    k, mmio = make(lanes=8)
    k.config_all(outsel=k.OUT_ZERO, g=0)
    assert all(l['outsel_reg'] == 3 and l['iir_g_reg'] == 0 for l in mmio.lanes)


def test_q15_matches_the_model_convention():
    k, _ = make()
    assert (k.q15(0.5), k.q15(-0.5), k.q15(1.0), k.q15(-1.0), k.q15(0.0)) == (0x4000, 0xC000, 0x7FFF, 0x8000, 0)
    assert k.from_q15(0xC000) == -0.5 and k.from_q15(0x4000) == 0.5
    sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "model"))
    import kidsim_resonator as kr
    for x in (-0.999, -0.25, 0.0, 0.3, 0.99, 0.9999):
        assert k.q15(x) == kr.real_to_q15(x)
    assert k.G_UNITY == kr.G_UNITY


def test_negative_words_are_masked_to_16_bits():
    k, mmio = make()
    k.config_lane(2, slope=-3, bval=-1)
    assert mmio.lanes[2]['dds_slope_reg'] == 0xFFFD and mmio.lanes[2]['dds_bval_reg'] == 0xFFFF


def test_bad_lane_and_outsel_raise():
    k, _ = make(lanes=8)
    with pytest.raises(ValueError, match="lane 8"):
        k.config_lane(8)
    with pytest.raises(ValueError, match="outsel"):
        k.config_lane(0, outsel=4)
