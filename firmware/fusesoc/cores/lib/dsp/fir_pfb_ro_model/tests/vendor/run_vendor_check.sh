#!/bin/bash
# Check each fir_pfb_ro_<i> wrapper (fir_pfb_ro_model + that FIR's
# coefficients) against the real FIR Compiler 7.2 core generated from its .xci. Needs Vivado (xsim and its precompiled IP
# libraries) on PATH. usage: run_vendor_check.sh [workdir]
set -e
here=$(cd "$(dirname "$0")" && pwd)
fw=$(cd "$here/../../../../../../.." && pwd)            # firmware/
work=${1:-$(mktemp -d)}; mkdir -p "$work/xci"
for i in 0 1 2 3 4 5 6 7; do
    mkdir -p "$work/xci/fir_pfb_ro_$i"
    cp "$fw/rtl_lib/xci/fir_pfb_ro_$i/"* "$work/xci/fir_pfb_ro_$i/"
    sed "s/^module fir_pfb_ro_$i\b/module fir_pfb_ro_${i}_sim/" "$fw/rtl_lib/dsp/fir_pfb_ro_$i.sv" > "$work/wrap$i.sv"
done
(cd "$work" && vivado -mode batch -nojournal -nolog -notrace -source "$here/gen_fir_sim.tcl" -tclargs "$work" > gen.log 2>&1)
cp "$work"/proj/firsim.ip_user_files/mem_init_files/*.mif "$work/"
libs=$(grep -ohE -- '-L [a-z_0-9]+' "$work"/proj/firsim.ip_user_files/sim_scripts/fir_pfb_ro_0/xsim/*.sh 2>/dev/null | sort -u | tr '\n' ' ')
[ -n "$libs" ] || libs="-L xbip_utils_v3_0_15 -L axi_utils_v2_0_11 -L xbip_pipe_v3_0_11 -L fir_compiler_v7_2_26"
fail=0
for i in 0 1 2 3 4 5 6 7; do
    cd "$work"; rm -rf xsim.dir
    xvhdl --relax -work xil_defaultlib proj/firsim.gen/sources_1/ip/fir_pfb_ro_$i/sim/fir_pfb_ro_$i.vhd > v$i.log 2>&1
    xvlog -sv -d FIRMOD=fir_pfb_ro_$i -d WRAPMOD=fir_pfb_ro_${i}_sim \
        "$fw/rtl_lib/dsp/fir_pfb_ro_model.sv" "wrap$i.sv" "$here/tb_vendor_cmp.sv" > c$i.log 2>&1
    xelab --relax -L xil_defaultlib $libs -L xpm -L unisims_ver -s cmp$i work.tb_vendor_cmp > e$i.log 2>&1
    xsim cmp$i -R > r$i.log 2>&1
    if grep -q "^DONE" r$i.log && ! grep -q "MISMATCH\|ERRCOUNT" r$i.log; then
        echo "fir_pfb_ro_$i: PASS ($(grep -o 'nval=[0-9]*' r$i.log) outputs)"
    else
        echo "fir_pfb_ro_$i: FAIL (see $work/r$i.log)"; fail=1
    fi
done
exit $fail
