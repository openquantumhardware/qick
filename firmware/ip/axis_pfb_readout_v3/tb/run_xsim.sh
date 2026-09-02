#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_DIR="$SCRIPT_DIR"
SRC_DIR="$(dirname "$TB_DIR")"
SIM_DIR="$TB_DIR/sim_work"

rm -rf "$SIM_DIR"
mkdir -p "$SIM_DIR/xsim.dir/xil_defaultlib"
mkdir -p "$SIM_DIR/xsim.dir/work"

cd "$SIM_DIR"

echo "=== Compiling VHDL (xil_defaultlib) ==="
xvhdl --nolog --work xil_defaultlib="$SIM_DIR/xsim.dir/xil_defaultlib" \
  "$SRC_DIR/src/pfb/fft/ssr_fft_8x64/conv_pkg.vhd" \
  "$SRC_DIR/src/pfb/fft/ssr_fft_8x64/xlclockdriver_rd.vhd" \
  "$SRC_DIR/src/pfb/fft/ssr_fft_8x64/single_reg_w_init.vhd" \
  "$SRC_DIR/src/pfb/fft/ssr_fft_8x64/srl17e.vhd" \
  "$SRC_DIR/src/pfb/fft/ssr_fft_8x64/srl33e.vhd" \
  "$SRC_DIR/src/pfb/fft/ssr_fft_8x64/ssr_8x64_entity_declarations.vhd" \
  "$SRC_DIR/src/pfb/fft/ssr_fft_8x64/ssr_8x64.vhd" \
  "$SRC_DIR/src/pfb/fft/ssr_fft_8x64/synth_reg_reg.vhd" \
  "$SRC_DIR/src/pfb/fft/ssr_fft_8x64/synth_reg.vhd" \
  "$SRC_DIR/src/pfb/fft/ssr_fft_8x64/synth_reg_w_init.vhd"

echo "=== Compiling Verilog DUT (work) ==="
xvlog --nolog --sv --work work="$SIM_DIR/xsim.dir/work" \
  "$SRC_DIR/src/verilog/ssr_8x64_sv.sv"

echo "=== Compiling Testbench (work) ==="
xvlog --nolog --sv --work work="$SIM_DIR/xsim.dir/work" \
  "$TB_DIR/tb_ssr_8x64_compare.sv"

echo "=== Elaborating ==="
xelab --nolog -log xelab.log \
  -L xil_defaultlib="$SIM_DIR/xsim.dir/xil_defaultlib" \
  -L work="$SIM_DIR/xsim.dir/work" \
  tb_ssr_8x64_compare

echo "=== Running Simulation ==="
xsim work.tb_ssr_8x64_compare \
  --xsimdir "$SIM_DIR/xsim.dir" \
  --runall \
  --log sim.log

echo "=== Simulation Complete ==="
