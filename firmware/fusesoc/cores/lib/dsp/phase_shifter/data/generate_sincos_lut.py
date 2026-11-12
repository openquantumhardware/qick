#!/usr/bin/env python3
# generate_sincos_lut.py  (corrected: signed literals, matches .sv style)
import math
N, SCALE = 2048, 32767
def q15(x):
    return max(-32768, min(32767, int(round(x*SCALE))))
def fmt(v):
    return f"-16'sd{-v:5d}" if v < 0 else f" 16'sd{v:5d}"
print("   // BEGIN LUT INITIALIZATION")
print("   initial begin")
for b in range(0, N, 3):
    print("      " + "; ".join(f"cos_lut[{i:4d}] = {fmt(q15(math.cos(2*math.pi*i/N)))}" for i in range(b,b+3)) + ";")
    print("      " + "; ".join(f"sin_lut[{i:4d}] = {fmt(q15(math.sin(2*math.pi*i/N)))}" for i in range(b,b+3)) + ";")
print("   end")
print("   // END LUT INITIALIZATION")

