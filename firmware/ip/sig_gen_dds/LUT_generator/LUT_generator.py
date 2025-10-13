#!/usr/bin/env python3
"""
Make a sine LUT init file for a DDS ROM.

- Output format: one 32-bit hex word per line (two's-complement Q1.31)
- Full table:     DEPTH = LUT_SIZE entries covering 0..2π (uniform phase)
- Quarter-wave:   DEPTH = LUT_SIZE/4 entries covering 0..π/2   (non-negative)
"""

import argparse
import math
from pathlib import Path

def q31_from_float(x: float) -> int:
    """
    convert float in [-1.0, 1.0) to Q1.31 two complement 32-bit integer.
    """
    x = max(min(x, 0.999999999), -1.0)
    return int(round(x * (2**31 - 1)))

def to_hex32(val: int) -> str:
    return f"{(val & 0xFFFFFFFF):08X}"

def gen_full_table(lut_size: int):
    """
    anagles theta_k = 2pi * k/LUT_SIZE
    """
    
    for k in range(lut_size):
        theta = 2.0 * math.pi * k / lut_size
        s = math.sin(theta)
        yield to_hex32(q31_from_float(s))
        
        
def main():
    ap = argparse.ArgumentParser(description="sin ROM generation")
    ap.add_argument("--lut-size", type=int, default=256)
    ap.add_argument("--mode", choices=["full"], default="full")
    ap.add_argument("--outfile", type=Path, default=Path("sine_full32.hex"))
    args = ap.parse_args()
    
    if args.mode == "full":
        lines = list(gen_full_table(args.lut_size))

    with args.outfile.open("w", encoding="utf-8") as f:
        for line in lines:
            f.write(line + "\n")

    print(f"Wrote {len(lines)} lines to {args.outfile}")

if __name__ == "__main__":
    main()
