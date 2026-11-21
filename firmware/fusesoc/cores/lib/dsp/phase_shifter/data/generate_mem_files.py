#!/usr/bin/env python3
import math

# Equivalent parameters to your generics in SystemVerilog
LAW = 11
DW = 16

SCALE = (1 << (DW - 1)) - 1
LUT_DEPTH = (1 << LAW)

def q_format(x):
    min_val = -(1 << (DW - 1))
    max_val = (1 << (DW - 1)) - 1
    return max(min_val, min(max_val, int(round(x * SCALE))))

# Generate cosine_table.mem
with open("cosine_table.mem", "w") as f_cos:
    for i in range(LUT_DEPTH):
        val = q_format(math.cos(2 * math.pi * i / LUT_DEPTH))
        f_cos.write(f"{(val & ((1 << DW) - 1)):0{DW//4}X}\n")

# Generate sine_table.mem
with open("sine_table.mem", "w") as f_sin:
    for i in range(LUT_DEPTH):
        val = q_format(math.sin(2 * math.pi * i / LUT_DEPTH))
        f_sin.write(f"{(val & ((1 << DW) - 1)):0{DW//4}X}\n")

print(f"Files generated successfully: LUT_DEPTH={LUT_DEPTH}, DW={DW}")
