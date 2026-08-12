"""Tests for QCVT schedule extraction, plotting and exports.

Run with: pytest tests/ -v
"""
from __future__ import annotations

import os

import matplotlib

matplotlib.use("Agg")

import pytest

CONFIG = os.path.join(os.path.dirname(__file__), "qick_config.json")
try:
    import qick  # noqa: F401
    HAVE_QICK = True
except Exception:
    HAVE_QICK = False

needs_qick = pytest.mark.skipif(
    not (HAVE_QICK and os.path.isfile(CONFIG)),
    reason="requires qick and qick_config.json",
)


def test_public_api():
    import qcvt

    for name in [
        "plot_pulse_schedule", "show_schedule", "visualize_all",
        "visualize_from_pickle", "extract_schedule", "Schedule", "PulseEvent",
        "QCVTError", "strict_mode", "is_strict",
        "export_edge_matrix_csv", "csv_to_table_png",
        "save_soccfg_to_json", "load_soccfg_from_json",
        "review_schedule",
    ]:
        assert hasattr(qcvt, name), name


def test_csv_to_table_png_without_pandas(tmp_path, monkeypatch):
    """Table PNG rendering must not need pandas, which is not a dependency.

    pandas may still be installed in the test environment, so block the import
    outright rather than trusting its absence.
    """
    import builtins

    real_import = builtins.__import__

    def no_pandas(name, *args, **kwargs):
        if name == "pandas" or name.startswith("pandas."):
            raise ImportError("pandas is not a QCVT dependency")
        return real_import(name, *args, **kwargs)

    monkeypatch.setattr(builtins, "__import__", no_pandas)

    from qcvt.export import csv_to_table_png

    csv_path = tmp_path / "edges_state.csv"
    csv_path.write_text("timestamp (ns),0.00e0,1.00e3\ngen 0,on,off\n")
    png_path = tmp_path / "edges_state.png"
    csv_to_table_png(str(csv_path), str(png_path), title="state")
    assert png_path.is_file() and png_path.stat().st_size > 0


def test_extract_schedule_empty():
    from qcvt import extract_schedule

    class Empty:
        macro_list = []
        pulses = {}
        soccfg = None

    sched = extract_schedule(Empty())
    assert len(sched) == 0
    assert not sched


def test_param_helpers():
    from qcvt.model import param_nominal, param_range

    assert param_nominal(3.0) == 3.0
    assert param_range(5)[:2] == (5.0, 5.0)
    assert param_range(5)[2] is False

    class FakeSweep:
        start = 1.0
        spans = {"loop": 4.0}

        def minval(self):
            return 1.0

        def maxval(self):
            return 5.0

    lo, hi, swept = param_range(FakeSweep())
    assert (lo, hi, swept) == (1.0, 5.0, True)


def test_representative_gain_and_band():
    """QICK gains are signed: sweeps like -0.6..0.6 or -0.6..0 must not
    render/export near zero, and the amplitude band must reach 0 when the
    sweep crosses zero."""
    from qcvt.model import PulseEvent, gain_band, representative_gain

    def ev(g, gmin, gmax):
        return PulseEvent(ch=0, name="p", kind="gen", t_start=0.0, length=1.0,
                          gain=g, gain_min=gmin, gain_max=gmax)

    # constant gain (incl. negative)
    assert representative_gain(ev(-0.5, -0.5, -0.5)) == -0.5
    assert gain_band(ev(-0.5, -0.5, -0.5)) == (0.5, 0.5)
    # positive sweep (power Rabi 0..1)
    assert representative_gain(ev(0.0, 0.0, 1.0)) == 1.0
    assert gain_band(ev(0.0, 0.0, 1.0)) == (0.0, 1.0)
    # sign-crossing sweep (kerrcat -0.6..0.6): largest |endpoint|, band reaches 0
    assert abs(representative_gain(ev(-0.6, -0.6, 0.6))) == pytest.approx(0.6)
    assert gain_band(ev(-0.6, -0.6, 0.6)) == (0.0, pytest.approx(0.6))
    # negative-only sweep: must pick -0.6, not the near-zero max
    assert representative_gain(ev(-0.6, -0.6, 0.0)) == -0.6
    assert gain_band(ev(-0.6, -0.6, 0.0)) == (0.0, pytest.approx(0.6))
    assert gain_band(ev(-0.6, -0.6, -0.2)) == (pytest.approx(0.2), pytest.approx(0.6))


# --------------------------------------------------------------------------- #
# Golden tests against a real (offline-built) program
# --------------------------------------------------------------------------- #
def _build_spec_program():
    from qick.asm_v2 import AveragerProgramV2, QickSweep1D
    from qcvt import load_soccfg_from_json

    soccfg = load_soccfg_from_json(CONFIG)

    class Spec(AveragerProgramV2):
        def _initialize(self, cfg):
            self.declare_gen(ch=2, nqz=2)
            self.declare_gen(ch=6, nqz=2)
            self.add_loop("freqloop", 11)
            self.declare_readout(ch=0, length=10.0)
            self.add_readoutconfig(ch=0, name="ro", freq=1000, gen_ch=6)
            self.add_pulse(ch=2, name="qpulse", ro_ch=0, style="const",
                           length=5.0, freq=QickSweep1D("freqloop", 3000, 3200),
                           phase=0, gain=0.3)
            self.add_pulse(ch=6, name="readout", ro_ch=0, style="const",
                           length=10.0, freq=1000, phase=0, gain=0.5)

        def _body(self, cfg):
            self.send_readoutconfig(ch=0, name="ro", t=0)
            self.pulse(ch=2, name="qpulse", t=0)
            self.delay_auto(0.01)
            self.pulse(ch=6, name="readout", t=0)
            self.trigger(ros=[0], pins=[0], t=0.5)

    return Spec(soccfg, reps=2, final_delay=100, cfg={}, reps_innermost=False)


@needs_qick
def test_timing_and_sweeps():
    from qcvt import extract_schedule

    sched = extract_schedule(_build_spec_program())
    by_name = {e.name: e for e in sched.gen_events}

    q = by_name["qpulse"]
    assert q.length == pytest.approx(5.0, abs=1e-2)
    assert q.t_start == pytest.approx(1.0, abs=1e-2)  # includes initial sync delay
    assert "freq" in q.swept_params

    r = by_name["readout"]
    # readout follows qpulse + delay_auto(0.01): ~1.0 + 5.0 + 0.01
    assert r.t_start == pytest.approx(6.01, abs=5e-2)
    assert r.length == pytest.approx(10.0, abs=1e-2)

    adc = sched.adc_events[0]
    assert adc.t_start == pytest.approx(6.51, abs=5e-2)
    # ADC window uses the readout integration length, not the tiny trigger width.
    assert adc.length == pytest.approx(10.0, abs=1e-1)


@needs_qick
def test_plot_with_ax_and_amplitude_no_crash():
    import matplotlib.pyplot as plt
    from qcvt import plot_pulse_schedule

    prog = _build_spec_program()
    fig, ax = plt.subplots()
    result = plot_pulse_schedule(prog, ax=ax, show_amplitude=True)
    assert isinstance(result, tuple) and len(result) == 2
    plt.close("all")


@needs_qick
def test_visualize_all_writes_all_outputs(tmp_path):
    from qcvt import visualize_all

    prog = _build_spec_program()
    out = visualize_all(prog, str(tmp_path), title="spec", show_amplitude=True)
    for key in ("schedule_png", "edges_state_csv", "edges_state_png"):
        assert out[key] and os.path.isfile(out[key]), key


@needs_qick
def test_edge_matrix_state_values(tmp_path):
    import csv

    from qcvt import export_edge_matrix_csv

    prog = _build_spec_program()
    state_csv = export_edge_matrix_csv(
        prog, out_prefix=str(tmp_path / "edges"), t0_us=0.0, t1_us=None,
    )
    with open(state_csv) as f:
        rows = list(csv.reader(f))
    labels = [r[0] for r in rows[1:]]
    assert any("gen 2" in lbl for lbl in labels)
    assert any("gen 6" in lbl for lbl in labels)
    # Each generator row should be on for at least one timestamp.
    for row in rows[1:]:
        if row[0].startswith("gen "):
            assert "on" in row[1:]


def _build_flat_top_program():
    from qick.asm_v2 import AveragerProgramV2
    from qcvt import load_soccfg_from_json

    soccfg = load_soccfg_from_json(CONFIG)

    class FlatTopProg(AveragerProgramV2):
        def _initialize(self, cfg):
            self.declare_gen(ch=2, nqz=2)
            self.add_gauss(ch=2, name="ramp", sigma=0.05, length=0.3, even_length=True)
            self.add_pulse(ch=2, name="ft", style="flat_top", envelope="ramp",
                           freq=3000, phase=0, gain=0.5, length=2.0)

        def _body(self, cfg):
            self.pulse(ch=2, name="ft", t=0.5)

    return FlatTopProg(soccfg, reps=1, final_delay=1, cfg={}, reps_innermost=False)


@needs_qick
def test_flat_top_amplitude_has_ramps_and_plateau():
    from qcvt import extract_schedule
    from qcvt.model import amplitude_trace

    prog = _build_flat_top_program()
    sched = extract_schedule(prog)
    e = next(x for x in sched.gen_events if x.name == "ft")
    assert e.style == "flat_top"
    assert e.length == pytest.approx(2.3, abs=0.05)  # plateau 2.0 + ramps ~0.3

    t, amp = amplitude_trace(prog, e, dac_units=True)
    assert t is not None and amp is not None
    # Should have rising samples, a high plateau, then falling samples.
    peak = float(amp.max())
    assert peak == pytest.approx(0.5 * 32766, rel=0.05)
    # Plateau: many consecutive samples near the peak.
    on_plateau = amp > 0.95 * peak
    assert on_plateau.sum() >= 2
    # Ramps: amplitude takes intermediate values, not just 0 and peak.
    mid = (amp > 0.05 * peak) & (amp < 0.95 * peak)
    assert mid.sum() >= 4
    # Total span matches get_length.
    assert (t[-1] - t[0]) == pytest.approx(e.length, abs=0.05)


@needs_qick
def test_review_schedule_saves_and_returns_true(tmp_path):
    from qcvt import review_schedule

    prog = _build_spec_program()
    ok = review_schedule(
        prog,
        save_dir=str(tmp_path / "review"),
        title="review test",
        show=False,
        confirm=False,
    )
    assert ok is True
    assert os.path.isfile(tmp_path / "review" / "schedule.png")


@needs_qick
def test_multi_timescale_window_and_insets():
    """Short ns-scale pulse next to a long readout still plots; zoom window works."""
    import matplotlib.pyplot as plt
    from qick.asm_v2 import AveragerProgramV2
    from qcvt import load_soccfg_from_json, plot_pulse_schedule, extract_schedule

    soccfg = load_soccfg_from_json(CONFIG)

    class Mixed(AveragerProgramV2):
        def _initialize(self, cfg):
            self.declare_gen(ch=2, nqz=2)
            self.declare_gen(ch=6, nqz=2)
            self.declare_readout(ch=0, length=50.0)
            self.add_readoutconfig(ch=0, name="ro", freq=1000, gen_ch=6)
            self.add_gauss(ch=2, name="g", sigma=0.01, length=0.05)
            self.add_pulse(ch=2, name="short", style="arb", envelope="g",
                           freq=3200, phase=0, gain=0.8)
            self.add_pulse(ch=6, name="long", style="const", length=50.0,
                           freq=1000, phase=0, gain=0.4)

        def _body(self, cfg):
            self.pulse(ch=2, name="short", t=0.1)
            self.delay_auto(0.05)
            self.pulse(ch=6, name="long", t=0)
            self.trigger(ros=[0], pins=[0], t=0.2)

    prog = Mixed(soccfg, reps=1, final_delay=10, cfg={}, reps_innermost=False)
    sched = extract_schedule(prog)
    short = next(e for e in sched.gen_events if e.name == "short")
    long = next(e for e in sched.gen_events if e.name == "long")
    assert short.length < 0.2
    assert long.length == pytest.approx(50.0, abs=0.1)

    # Full window + forced inset must not crash, and pulse labels must not
    # blow up the tight bbox (long pulses labelled at off-window midpoints
    # once produced ~40000 px wide PNGs).
    ax, ax_amp = plot_pulse_schedule(prog, show_amplitude=True, insets=True)
    assert ax.get_xlim()[1] > 40
    fig = ax.figure
    fig.canvas.draw()
    bbox = fig.get_tightbbox(fig.canvas.get_renderer())
    assert bbox.width < 3 * fig.get_size_inches()[0], "tight bbox exploded"
    plt.close("all")

    # Zoomed window around the short pulse: same bbox sanity check.
    ax = plot_pulse_schedule(prog, show_amplitude=False, t0_us=0.0, max_time_us=1.0, insets=False)
    assert ax.get_xlim() == pytest.approx((0.0, 1.0))
    fig = ax.figure
    fig.canvas.draw()
    bbox = fig.get_tightbbox(fig.canvas.get_renderer())
    assert bbox.width < 3 * fig.get_size_inches()[0], "tight bbox exploded"
    plt.close("all")
