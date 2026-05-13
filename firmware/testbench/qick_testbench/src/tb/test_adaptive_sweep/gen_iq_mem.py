"""
Convert resonator_sweep.ipynb's CSV dump to iq_shots.mem for the
test_adaptive_sweep Vivado testbench.

Input: a CSV produced by Cell 8 of personal_files/adaptive_sweep_simulation/
       resonator_sweep.ipynb (header row of metadata + freq_Hz,shot_idx,
       I_int16,Q_int16 rows).

Output: iq_shots.mem -- one int32 per line, hex, packed {Q[15:0], I[15:0]}
        per shot.  Layout = bin*N_SHOTS + shot_cursor.

Also prints the parameters resonator_emulator should be instantiated with.

Usage:
  python gen_iq_mem.py path/to/sweep_*.csv [-o iq_shots.mem]
"""

from __future__ import annotations
import argparse, csv, os, sys
from pathlib import Path

import numpy as np


def _parse_metadata(meta_row: list[str]) -> dict:
    out = {}
    for item in meta_row:
        if "=" in item:
            k, v = item.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("csv_path", type=Path)
    ap.add_argument("-o", "--out", type=Path, default=Path("iq_shots.mem"))
    args = ap.parse_args()

    with open(args.csv_path, "r") as f:
        rdr = csv.reader(f)
        meta_row = next(rdr)
        header   = next(rdr)
        rows     = [r for r in rdr]

    meta    = _parse_metadata(meta_row)
    n_sweep = int(meta["n_sweep"])
    n_shots = int(meta["N_SHOTS"])
    f_start = float(meta["f_start_Hz"])
    f_end   = float(meta["f_end_Hz"])
    f_step  = (f_end - f_start) / (n_sweep - 1)
    iq_scale= int(meta.get("IQ_SCALE", 1 << 14))

    if len(rows) != n_sweep * n_shots:
        print(f"WARN: row count {len(rows)} != n_sweep*n_shots {n_sweep*n_shots}",
              file=sys.stderr)

    # rows are emitted as repeat(freqs, n_shots) -> tile(arange(n_shots), n_sweep)
    # i.e. row index = bin*n_shots + shot, matching the .mem layout.
    arr = np.asarray([[int(r[2]), int(r[3])] for r in rows], dtype=np.int32)
    i16 = arr[:, 0].astype(np.uint16)
    q16 = arr[:, 1].astype(np.uint16)
    packed = (q16.astype(np.uint32) << 16) | i16.astype(np.uint32)

    with open(args.out, "w") as f:
        f.write(f"// Auto-generated from {args.csv_path.name}\n")
        f.write(f"// N_SWEEP={n_sweep}\n")
        f.write(f"// N_SHOTS={n_shots}\n")
        f.write(f"// F_START_HZ={f_start:.0f}\n")
        f.write(f"// F_STEP_HZ={f_step:.6f}\n")
        f.write(f"// IQ_SCALE={iq_scale}\n")
        f.write(f"// Format: int32 hex per line, packed {{Q[15:0], I[15:0]}}\n")
        for w in packed:
            f.write(f"{w:08x}\n")

    print(f"Wrote {args.out} ({len(packed)} entries)")
    print()
    print("Use these parameters when instantiating resonator_emulator:")
    print(f"    .N_SWEEP    ({n_sweep}),")
    print(f"    .N_SHOTS    ({n_shots}),")
    print(f"    .F_START_HZ ({f_start:.1f}),")
    print(f"    .F_STEP_HZ  ({f_step:.6f}),")
    print(f"    .IQ_SCALE   ({iq_scale}),")
    return 0


if __name__ == "__main__":
    sys.exit(main())
