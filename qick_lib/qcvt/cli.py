"""Command-line interface for QCVT.

Plot a pulse schedule and export a state edge matrix from a compiled QICK
program pickle, without a live RFSoC connection::

    qcvt --pickle prog.pkl --out-dir ./out --show-amplitude
"""
from __future__ import annotations

import argparse
import os
import sys


def main() -> int:
    parser = argparse.ArgumentParser(
        description="QCVT: visualize a compiled QICK asm_v2 program and export a state edge matrix.",
    )
    parser.add_argument("--pickle", required=True, help="Path to compiled program pickle (.pkl)")
    parser.add_argument("--out-dir", default=".", help="Output directory (default: current dir)")
    parser.add_argument("--title", default="Pulse schedule", help="Schedule plot title")
    parser.add_argument("--show-amplitude", action="store_true",
                        help="Add an amplitude vs. time panel to the schedule plot")
    parser.add_argument("--amplitude-units", choices=("dac", "norm"), default="dac",
                        help="Amplitude units for the plot panel (default: dac)")
    parser.add_argument("--no-table-png", action="store_true",
                        help="Write the edge-matrix CSV only (skip the table PNG)")
    parser.add_argument("--strict", action="store_true",
                        help="Raise on incomplete/ambiguous schedule extraction")
    parser.add_argument("--no-suppress-off", action="store_true",
                        help="Do not hide '*_off' cleanup pulses co-timed with CW")
    parser.add_argument("--t0", type=float, default=0.0, help="Export window start (µs)")
    parser.add_argument("--t1", type=float, default=None,
                        help="Export window end (µs); default: infer from schedule")
    parser.add_argument("--time-origin", choices=("program", "body"), default="program",
                        help="Time axis origin for the schedule plot: 'program' "
                             "(absolute, default) or 'body' (t=0 at loop-body start). "
                             "Exports always use the absolute timeline.")
    args = parser.parse_args()

    if not os.path.isfile(args.pickle):
        print(f"Error: pickle file not found: {args.pickle}", file=sys.stderr)
        return 1

    # Non-interactive backend before importing pyplot anywhere.
    import matplotlib
    matplotlib.use("Agg")

    from .io import load_program_pickle, visualize_all
    from .model import QCVTError

    try:
        prog = load_program_pickle(args.pickle)
    except Exception as exc:
        print(f"Error: could not load pickle ({exc}).", file=sys.stderr)
        return 1

    try:
        outputs = visualize_all(
            prog,
            out_dir=args.out_dir,
            title=args.title,
            show_amplitude=args.show_amplitude,
            amplitude_units=args.amplitude_units,
            t0_us=args.t0,
            t1_us=args.t1,
            time_origin=args.time_origin,
            write_table_png=not args.no_table_png,
            strict=args.strict,
            suppress_off_pulses=not args.no_suppress_off,
        )
    except QCVTError as exc:
        print(f"Error: strict schedule extraction failed ({exc}).", file=sys.stderr)
        return 1

    for key, path in outputs.items():
        if path:
            print(f"Saved {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
