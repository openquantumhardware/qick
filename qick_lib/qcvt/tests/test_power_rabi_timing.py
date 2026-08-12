"""
Offline regression test for QCVT against the Power_rabi case reported by the
PhD student.  Requires no RFSoC: `qick`'s QickConfig is built from the bundled
qick_config.json, and AveragerProgramV2 compiles purely in software.

Run:  pytest tests/test_power_rabi_timing.py -v
"""
from pathlib import Path

import numpy as np
import pytest

qick = pytest.importorskip("qick")
from qick.asm_v2 import AveragerProgramV2, QickSweep1D
from qick.qick_asm import QickConfig

from qcvt.model import amplitude_trace, extract_schedule

# Resolve the bundled config relative to this file so the test runs from any cwd.
CFG = str(Path(__file__).resolve().parent / "qick_config.json")

QUBIT_CH, RES_CH, PUMP_CH, RO_CH = 6, 4, 0, 0
QUBIT_LEN, RES_LEN = 1.62, 30.0
GAP, ADC_OFF = 0.01, 0.474
TOL = 5e-3  # us; QICK rounds times to tProc cycles


class PowerRabi(AveragerProgramV2):
    """setup: CW pump on gen 0.  body: qubit pulse -> readout pulse -> ADC.
    cleanup: one-shot pulse on gen 0 to turn the pump off."""

    def _initialize(self, cfg):
        for ch in (PUMP_CH, QUBIT_CH, RES_CH):
            self.declare_gen(ch=ch, nqz=1)
        self.declare_readout(ch=RO_CH, length=RES_LEN)
        self.add_readoutconfig(ch=RO_CH, name="ro", freq=500.0, gen_ch=RES_CH)

        self.add_pulse(ch=PUMP_CH, name="pump", style="const", freq=1000.0,
                       phase=0, gain=0.5, length=1.0, mode="periodic")
        self.add_pulse(ch=PUMP_CH, name="pump_off", style="const", freq=1000.0,
                       phase=0, gain=0.5, length=1.0, mode="oneshot")

        self.add_gauss(ch=QUBIT_CH, name="qgauss", sigma=QUBIT_LEN / 5,
                       length=QUBIT_LEN, even_length=True)
        self.add_loop("gainloop", 10)
        self.add_pulse(ch=QUBIT_CH, name="qubit", style="arb", envelope="qgauss",
                       freq=3000.0, phase=0,
                       gain=QickSweep1D("gainloop", 0.0, 1.0))

        self.add_pulse(ch=RES_CH, name="res", style="const", freq=500.0,
                       phase=0, gain=1.0, length=RES_LEN)

        self.send_readoutconfig(ch=RO_CH, name="ro", t=0)
        self.pulse(ch=PUMP_CH, name="pump", t=0)
        self.delay(1.0)

    def _body(self, cfg):
        self.pulse(ch=QUBIT_CH, name="qubit", t=0)
        self.pulse(ch=RES_CH, name="res", t=QUBIT_LEN + GAP)
        self.trigger(ros=[RO_CH], t=QUBIT_LEN + GAP + ADC_OFF)

    def _cleanup(self, cfg):
        self.delay_auto(1.0)
        self.pulse(ch=PUMP_CH, name="pump_off", t=0)


@pytest.fixture(scope="module")
def sched():
    soccfg = QickConfig(CFG)
    return extract_schedule(PowerRabi(soccfg, reps=2, final_delay=10.0, cfg={}))


def _one(sched, name):
    hits = [e for e in sched.events if e.name == name]
    assert len(hits) == 1, f"expected exactly one {name!r}, got {len(hits)}"
    return hits[0]


def test_body_relative_timing(sched):
    """The reported bug: relative offsets inside _body must be exact."""
    q, res, adc = _one(sched, "qubit"), _one(sched, "res"), _one(sched, "readout")

    assert q.length == pytest.approx(QUBIT_LEN, abs=TOL)
    # readout pulse starts GAP after the qubit pulse ends
    assert res.t_start - q.t_end == pytest.approx(GAP, abs=TOL)
    # integration starts ADC_OFF after the readout pulse starts
    assert adc.t_start - res.t_start == pytest.approx(ADC_OFF, abs=TOL)


def test_durations(sched):
    assert _one(sched, "res").length == pytest.approx(RES_LEN, abs=TOL)
    assert _one(sched, "readout").length == pytest.approx(RES_LEN, abs=TOL)


def test_periodic_pump_extends_to_cleanup(sched):
    pump, off = _one(sched, "pump"), _one(sched, "pump_off")
    assert pump.periodic and not off.periodic
    drawn = sched.draw_lengths()[id(pump)]
    assert drawn == pytest.approx(off.t_start - pump.t_start, abs=TOL)


def test_gain_sweep_range_captured(sched):
    q = _one(sched, "qubit")
    assert "gain" in q.swept_params
    assert q.gain_min == pytest.approx(0.0, abs=1e-3)
    assert q.gain_max == pytest.approx(1.0, abs=1e-3)


def test_swept_pulse_has_nonzero_amplitude(sched):
    q = _one(sched, "qubit")
    _, amp = amplitude_trace(sched.prog, q)
    assert np.max(np.abs(amp)) > 0.0


def test_resync_advances_reference():
    soccfg = QickConfig(CFG)

    class WithResync(AveragerProgramV2):
        def _initialize(self, cfg):
            self.declare_gen(ch=6, nqz=1)
            for n in ("a", "b"):
                self.add_pulse(ch=6, name=n, style="const", freq=1000.0,
                               phase=0, gain=0.5, length=1.0)

        def _body(self, cfg):
            self.pulse(ch=6, name="a", t=0)
            self.resync(5.0)
            self.pulse(ch=6, name="b", t=0)
            self.resync(5.0)

    with pytest.warns(UserWarning, match="Resync") as record:
        s = extract_schedule(WithResync(soccfg, reps=1, final_delay=1.0, cfg={}))
    # One warning per program, not one per Resync macro.
    assert sum("Resync" in str(w.message) for w in record) == 1
    a, b = _one(s, "a"), _one(s, "b")
    assert b.t_start - a.t_start == pytest.approx(5.0, abs=TOL)


def test_negative_gain_sweep_amplitude():
    """Signed gain sweeps (kerrcat sweeps -0.6..0.6) must render at the
    largest |gain|, not at the sweep maximum (≈0 for a -0.6..0 sweep)."""
    soccfg = QickConfig(CFG)

    class NegSweep(AveragerProgramV2):
        def _initialize(self, cfg):
            self.declare_gen(ch=6, nqz=1)
            self.add_loop("gainloop", 11)
            self.add_pulse(ch=6, name="drive", style="const", length=1.0,
                           freq=1000.0, phase=0,
                           gain=QickSweep1D("gainloop", -0.6, 0.0))

        def _body(self, cfg):
            self.pulse(ch=6, name="drive", t=0)

    s = extract_schedule(NegSweep(soccfg, reps=1, final_delay=1.0, cfg={}))
    d = _one(s, "drive")
    _, amp = amplitude_trace(s.prog, d)
    assert np.max(np.abs(amp)) == pytest.approx(0.6 * 32766, rel=0.02)


def test_swept_pulse_in_edge_matrix(sched, tmp_path):
    """The swept gen 6 pulse must appear in the state edge matrix."""
    import csv

    from qcvt.export import export_edge_matrix_csv

    path = export_edge_matrix_csv(sched.prog, out_prefix=str(tmp_path / "edges"),
                                  t0_us=0.0, t1_us=None, schedule=sched)
    with open(path, newline="") as f:
        rows = list(csv.reader(f))
    labels = [r[0] for r in rows[1:]]
    assert f"gen {QUBIT_CH}" in labels
    qubit_row = next(r for r in rows[1:] if r[0] == f"gen {QUBIT_CH}")
    assert "on" in qubit_row[1:]


def test_unhandled_timed_macro_warns_once():
    soccfg = QickConfig(CFG)

    class Minimal(AveragerProgramV2):
        def _initialize(self, cfg):
            self.declare_gen(ch=6, nqz=1)
            self.add_pulse(ch=6, name="a", style="const", freq=1000.0,
                           phase=0, gain=0.5, length=1.0)

        def _body(self, cfg):
            self.pulse(ch=6, name="a", t=0)

    class FutureTimedMacro:
        """Stand-in for a timed macro QCVT doesn't know about."""
        t_params: dict = {}

    prog = Minimal(soccfg, reps=1, final_delay=1.0, cfg={})
    prog.macro_list.extend([FutureTimedMacro(), FutureTimedMacro()])
    with pytest.warns(UserWarning, match="FutureTimedMacro") as record:
        extract_schedule(prog)
    assert sum("FutureTimedMacro" in str(w.message) for w in record) == 1


def test_untimed_macros_do_not_warn(sched):
    """Loop control / register ops / labels in the compiled Power_rabi program
    must not trigger the unhandled-macro warning (fixture compiled cleanly)."""
    import warnings as _warnings

    with _warnings.catch_warnings():
        _warnings.simplefilter("error")
        extract_schedule(sched.prog)


def test_off_suppression_names():
    from qcvt.model import PulseEvent, Schedule

    def sched_with(name, suppress=True):
        cw = PulseEvent(ch=0, name="pump", kind="gen", t_start=0.0, length=1.0,
                        periodic=True)
        cand = PulseEvent(ch=0, name=name, kind="gen", t_start=0.0, length=1.0)
        return Schedule(events=[cw, cand], suppress_off_pulses=suppress), cand

    for name in ("pump_off", "turnoff", "turn_off", "off"):
        s, cand = sched_with(name)
        assert id(cand) in s.suppressed_events(), name
    for name in ("offset_cal", "off_resonant_probe", "readout_offset"):
        s, cand = sched_with(name)
        assert id(cand) not in s.suppressed_events(), name

    s, cand = sched_with("pump_off", suppress=False)
    assert id(cand) not in s.suppressed_events()


def test_strict_mode_raises_on_unhandled_timed_macro():
    from qcvt.model import QCVTError, extract_schedule as es

    class FutureTimedMacro:
        t_params: dict = {}

    class Prog:
        macro_list = [FutureTimedMacro()]
        pulses = {}
        soccfg = None
        loop_dict = {}

    with pytest.raises(QCVTError, match="FutureTimedMacro"):
        es(Prog(), strict=True)


def test_strict_mode_raises_on_resync():
    from qcvt.model import QCVTError

    soccfg = QickConfig(CFG)

    class WithResync(AveragerProgramV2):
        def _initialize(self, cfg):
            self.declare_gen(ch=6, nqz=1)
            self.add_pulse(ch=6, name="a", style="const", freq=1000.0,
                           phase=0, gain=0.5, length=1.0)

        def _body(self, cfg):
            self.pulse(ch=6, name="a", t=0)
            self.resync(1.0)

    with pytest.raises(QCVTError, match="Resync"):
        extract_schedule(WithResync(soccfg, reps=1, final_delay=1.0, cfg={}),
                         strict=True)


def test_gen_colors_avoid_adc_green():
    """Generator lane colors must not reuse the ADC green (tab10 index 2)."""
    import matplotlib.pyplot as plt
    from qcvt.plotting import _ADC_COLOR, _channel_colors

    colors = _channel_colors(list(range(12)))
    adc = plt.matplotlib.colors.to_rgb(_ADC_COLOR)
    tab10_green = plt.cm.tab10(2)[:3]
    for ch, rgba in colors.items():
        assert rgba[:3] != pytest.approx(tab10_green, abs=1e-6), ch
        dist = sum((a - b) ** 2 for a, b in zip(rgba[:3], adc)) ** 0.5
        assert dist > 0.15, ch


def test_body_time_origin(sched):
    """body_start_us puts the first _body() pulse at t = 0."""
    q = _one(sched, "qubit")
    assert sched.body_start_us > 0.5  # initial_delay + explicit delay(1.0)
    assert q.t_start - sched.body_start_us == pytest.approx(0.0, abs=TOL)

    import matplotlib
    matplotlib.use("Agg")
    from qcvt.plotting import plot_pulse_schedule

    ax = plot_pulse_schedule(sched.prog, schedule=sched, time_origin="body")
    assert "body start" in ax.get_xlabel()
    # Draw-time only: the schedule itself must keep the absolute timeline.
    assert _one(sched, "qubit").t_start == q.t_start