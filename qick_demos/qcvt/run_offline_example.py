"""Build a small QICK program from a saved ``soccfg`` and visualize it offline.

No RFSoC connection is required: the repository ships an example
``examples/qick_config.json`` captured from a real board.  To regenerate it for
your own hardware, run once while connected::

    from qcvt import save_soccfg_to_json
    save_soccfg_to_json(soc, "qick_config.json")

Then, offline::

    python examples/run_offline_example.py

You can also visualize a compiled-program pickle directly (no qick needed to
plot, only to unpickle)::

    from qcvt import visualize_from_pickle
    visualize_from_pickle("path/to/prog.pkl", output_path="schedule.png")
"""
from __future__ import annotations

import os
import sys

CONFIG_PATH = os.path.join(os.path.dirname(__file__), "qick_config.json")


def main() -> int:
    import matplotlib
    matplotlib.use("Agg")

    try:
        from qcvt import load_soccfg_from_json, visualize_all
        from qick.asm_v2 import AveragerProgramV2, QickSweep1D
    except ImportError as exc:
        print("Install qcvt with qick support: pip install -e '.[qick]'", file=sys.stderr)
        raise exc

    if not os.path.isfile(CONFIG_PATH):
        print(f"No soccfg found at {CONFIG_PATH}. Save one with save_soccfg_to_json(soc, path).")
        return 1

    soccfg = load_soccfg_from_json(CONFIG_PATH, align_version=True)

    class ExampleProgram(AveragerProgramV2):
        """Gaussian qubit pulse (gain sweep) + CW pump + square readout."""

        def _initialize(self, cfg):
            self.declare_gen(ch=2, nqz=2)  # qubit drive
            self.declare_gen(ch=6, nqz=2)  # readout drive
            self.declare_gen(ch=4, nqz=1)  # CW pump
            self.add_loop("gainloop", 5)
            self.declare_readout(ch=0, length=8.0)
            self.add_readoutconfig(ch=0, name="ro", freq=1000, gen_ch=6)
            self.add_gauss(ch=2, name="gaussenv", sigma=0.3, length=1.8)
            self.add_pulse(ch=4, name="pump", style="const", length=2.0,
                           freq=500, phase=0, gain=0.2, mode="periodic")
            self.add_pulse(ch=2, name="qubit", ro_ch=0, style="arb", envelope="gaussenv",
                           freq=3200, phase=0, gain=QickSweep1D("gainloop", 0.1, 0.9))
            self.add_pulse(ch=6, name="readout", ro_ch=0, style="const", length=8.0,
                           freq=1000, phase=0, gain=0.5)

        def _body(self, cfg):
            self.pulse(ch=4, name="pump", t=0)
            self.send_readoutconfig(ch=0, name="ro", t=0)
            self.pulse(ch=2, name="qubit", t=1.0)
            self.delay_auto(0.05)
            self.pulse(ch=6, name="readout", t=0)
            self.trigger(ros=[0], pins=[0], t=0.3)

    prog = ExampleProgram(soccfg, reps=1, final_delay=50, cfg={}, reps_innermost=False)

    out_dir = os.path.join(os.path.dirname(__file__), "output")
    outputs = visualize_all(
        prog,
        out_dir=out_dir,
        title="QCVT example: gaussian qubit pulse (gain sweep), CW pump, readout",
        show_amplitude=True,
        physical_port_labels={"02": "qubit drive", "26": "readout out",
                              "24": "pump", "20": "input 0"},
        # Prefer gen_ch_labels={2: "qubit drive", 6: "readout out", ...}
        # keyed by generator channel.  The two-digit keys above are RFDC
        # tile/block ids from print(soccfg), not QICK box DAC numbers.
    )
    for key, path in outputs.items():
        if path:
            print(f"  {key}: {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
