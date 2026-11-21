#!/bin/bash
# Check the fir_decim8_dynro model against the real FIR Compiler 7.2 core generated from fir_decim8_dynro.xci, clock by
# clock (valid and data). Needs Vivado (xsim and its precompiled IP libraries) on PATH. usage: run_vendor_check.sh [workdir]
set -e
here=$(cd "$(dirname "$0")" && pwd)
fw=$(cd "$here/../../../../../../.." && pwd)            # firmware/
work=${1:-$(mktemp -d)}; mkdir -p "$work/xci"; cd "$work"
cp "$fw/rtl_lib/xci/fir_decim8_dynro/"* "$work/xci/"
sed 's/^module fir_decim8_dynro\b/module fir_model/' "${MODEL_SRC:-$fw/rtl_lib/dsp/fir_decim8_dynro.sv}" > model.sv
vivado -mode batch -nojournal -nolog -notrace -source "$here/gen_fir_sim.tcl" -tclargs "$work" > gen.log 2>&1
cp "$work"/proj/firsim.ip_user_files/mem_init_files/*.mif "$work/"
libs="-L xbip_utils_v3_0_15 -L axi_utils_v2_0_11 -L xbip_pipe_v3_0_11 -L fir_compiler_v7_2_26"
rm -rf xsim.dir
xvhdl --relax -work xil_defaultlib proj/firsim.gen/sources_1/ip/fir_decim8_dynro/sim/fir_decim8_dynro.vhd > v.log 2>&1
xvlog -sv model.sv "$here/tb_vendor_cmp.sv" > c.log 2>&1 || { echo "COMPILE ERROR (see $work/c.log)"; exit 1; }
xelab --relax -L xil_defaultlib $libs -L xpm -L unisims_ver -s cmp work.tb_vendor_cmp > e.log 2>&1 || { echo "ELAB ERROR (see $work/e.log)"; exit 1; }
xsim cmp -R > r.log 2>&1
if grep -q "RESULT ERRCOUNT=0" r.log; then
    echo "fir_decim8_dynro: PASS ($(grep -o 'nval=[0-9]*' r.log) valid outputs identical to the IP)"
else
    echo "fir_decim8_dynro: FAIL (see $work/r.log)"; grep -E "MISMATCH|ERRORS" r.log | head -8; exit 1
fi
