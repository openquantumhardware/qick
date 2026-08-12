"""QCVT walkthrough: build several example pulse programs and visualize them.

No RFSoC needed — uses the bundled ``examples/qick_config.json``.

    python examples/walkthrough_demo.py

Writes PNGs (and CSVs) under ``examples/walkthrough_output/``.
"""
from __future__ import annotations

import os
import sys

import matplotlib

matplotlib.use("Agg")

from qick.asm_v2 import AveragerProgramV2, QickSweep1D
from qcvt import load_soccfg_from_json, visualize_all

HERE = os.path.dirname(__file__)
CONFIG_PATH = os.path.join(HERE, "qick_config.json")
OUT = os.path.join(HERE, "walkthrough_output")


def _save(prog, name: str, title: str, **kwargs):
    out_dir = os.path.join(OUT, name)
    print(f"\n=== {name} ===")
    print(f"  {title}")
    outputs = visualize_all(
        prog,
        out_dir=out_dir,
        title=title,
        show_amplitude=True,
        **kwargs,
    )
    for key, path in outputs.items():
        if path:
            print(f"  {key}: {path}")
    return outputs


def demo_1_const_and_readout(soccfg):
    """Simplest case: square drive + readout pulse + ADC window."""

    class Prog(AveragerProgramV2):
        def _initialize(self, cfg):
            self.declare_gen(ch=2, nqz=1)
            self.declare_gen(ch=6, nqz=1)
            self.declare_readout(ch=0, length=5.0)
            self.add_readoutconfig(ch=0, name="ro", freq=1000, gen_ch=6)
            self.add_pulse(ch=2, name="drive", style="const", length=2.0,
                           freq=3200, phase=0, gain=0.6)
            self.add_pulse(ch=6, name="readout", style="const", length=5.0,
                           freq=1000, phase=0, gain=0.4)

        def _body(self, cfg):
            self.send_readoutconfig(ch=0, name="ro", t=0)
            self.pulse(ch=2, name="drive", t=0)
            self.delay_auto(0.1)          # wait until drive ends + 0.1 us
            self.pulse(ch=6, name="readout", t=0)
            self.trigger(ros=[0], t=0.2)  # ADC window starts 0.2 us into readout

    prog = Prog(soccfg, reps=1, final_delay=10, cfg={})
    return _save(
        prog,
        "01_const_readout",
        "1. Square drive + readout + ADC window",
        physical_port_labels={"02": "drive", "26": "readout", "20": "ADC 0"},
    )


def demo_2_gaussian_and_flat_top(soccfg):
    """Envelope styles: gaussian (arb) and flat_top on two generators."""

    class Prog(AveragerProgramV2):
        def _initialize(self, cfg):
            self.declare_gen(ch=2, nqz=1)
            self.declare_gen(ch=3, nqz=1)
            self.declare_gen(ch=6, nqz=1)
            self.declare_readout(ch=0, length=4.0)
            self.add_readoutconfig(ch=0, name="ro", freq=1000, gen_ch=6)

            self.add_gauss(ch=2, name="genv", sigma=0.25, length=1.5)
            self.add_pulse(ch=2, name="gauss", style="arb", envelope="genv",
                           freq=3200, phase=0, gain=0.8)

            # flat_top: rising ramp + plateau + falling ramp
            self.add_gauss(ch=3, name="ftenvi", sigma=0.1, length=0.5)
            self.add_pulse(ch=3, name="ft", style="flat_top", envelope="ftenvi",
                           freq=2800, phase=0, gain=0.5, length=2.0)

            self.add_pulse(ch=6, name="readout", style="const", length=4.0,
                           freq=1000, phase=0, gain=0.35)

        def _body(self, cfg):
            self.send_readoutconfig(ch=0, name="ro", t=0)
            self.pulse(ch=2, name="gauss", t=0)
            self.pulse(ch=3, name="ft", t=0.2)
            self.delay_auto(0.15)
            self.pulse(ch=6, name="readout", t=0)
            self.trigger(ros=[0], t=0.2)

    prog = Prog(soccfg, reps=1, final_delay=10, cfg={})
    return _save(
        prog,
        "02_gaussian_flattop",
        "2. Gaussian (arb) + flat_top envelopes",
        physical_port_labels={"02": "gaussian", "03": "flat_top",
                              "26": "readout", "20": "ADC 0"},
    )


def demo_3_cw_pump_and_gain_sweep(soccfg):
    """CW (periodic) pump + qubit pulse with a swept gain (power Rabi style)."""

    class Prog(AveragerProgramV2):
        def _initialize(self, cfg):
            self.declare_gen(ch=0, nqz=1)  # CW pump
            self.declare_gen(ch=2, nqz=1)  # qubit
            self.declare_gen(ch=6, nqz=1)  # readout
            self.declare_readout(ch=0, length=6.0)
            self.add_readoutconfig(ch=0, name="ro", freq=1000, gen_ch=6)

            self.add_loop("gainloop", 8)
            self.add_pulse(ch=0, name="pump", style="const", length=1.0,
                           freq=500, phase=0, gain=0.25, mode="periodic")
            self.add_pulse(ch=0, name="pump_off", style="const", length=1.0,
                           freq=500, phase=0, gain=0.25, mode="oneshot")

            self.add_gauss(ch=2, name="genv", sigma=0.3, length=1.8)
            self.add_pulse(ch=2, name="qubit", style="arb", envelope="genv",
                           freq=3200, phase=0,
                           gain=QickSweep1D("gainloop", 0.0, 0.9))

            self.add_pulse(ch=6, name="readout", style="const", length=6.0,
                           freq=1000, phase=0, gain=0.4)

            # Start CW pump in setup (before the loop body)
            self.pulse(ch=0, name="pump", t=0)
            self.delay(0.5)

        def _body(self, cfg):
            self.send_readoutconfig(ch=0, name="ro", t=0)
            self.pulse(ch=2, name="qubit", t=0)
            self.delay_auto(0.05)
            self.pulse(ch=6, name="readout", t=0)
            self.trigger(ros=[0], t=0.3)

        def _cleanup(self, cfg):
            # One-shot pulse ends the periodic pump
            self.pulse(ch=0, name="pump_off", t="auto")

    prog = Prog(soccfg, reps=1, final_delay=10, cfg={})
    return _save(
        prog,
        "03_cw_and_sweep",
        "3. CW pump (hatched) + swept-gain qubit pulse",
        physical_port_labels={"00": "CW pump", "02": "qubit (sweep)",
                              "26": "readout", "20": "ADC 0"},
        time_origin="body",  # t=0 at start of loop body (matches _body times)
    )


def demo_4_multi_timescale(soccfg):
    """Short ns-scale pulse next to a long readout — triggers zoom inset."""

    class Prog(AveragerProgramV2):
        def _initialize(self, cfg):
            self.declare_gen(ch=2, nqz=1)
            self.declare_gen(ch=6, nqz=1)
            self.declare_readout(ch=0, length=40.0)
            self.add_readoutconfig(ch=0, name="ro", freq=1000, gen_ch=6)

            # ~100 ns gaussian next to a 40 us readout
            self.add_gauss(ch=2, name="short", sigma=0.02, length=0.1)
            self.add_pulse(ch=2, name="pi", style="arb", envelope="short",
                           freq=4500, phase=0, gain=0.9)
            self.add_pulse(ch=6, name="readout", style="const", length=40.0,
                           freq=1000, phase=0, gain=0.3)

        def _body(self, cfg):
            self.send_readoutconfig(ch=0, name="ro", t=0)
            self.pulse(ch=2, name="pi", t=0)
            self.delay_auto(0.02)
            self.pulse(ch=6, name="readout", t=0)
            self.trigger(ros=[0], t=0.5)

    prog = Prog(soccfg, reps=1, final_delay=10, cfg={})
    return _save(
        prog,
        "04_multi_timescale",
        "4. Multi-timescale: 100 ns pulse + 40 us readout (auto inset)",
        physical_port_labels={"02": "short pi", "26": "readout", "20": "ADC 0"},
    )


def main() -> int:
    if not os.path.isfile(CONFIG_PATH):
        print(f"Missing {CONFIG_PATH}", file=sys.stderr)
        return 1

    soccfg = load_soccfg_from_json(CONFIG_PATH)
    os.makedirs(OUT, exist_ok=True)

    demo_1_const_and_readout(soccfg)
    demo_2_gaussian_and_flat_top(soccfg)
    demo_3_cw_pump_and_gain_sweep(soccfg)
    demo_4_multi_timescale(soccfg)

    print(f"\nAll figures written under {OUT}/")
    print("Open each subdirectory's schedule.png (and edges_*.png) to inspect.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
