#!/bin/bash
# Check the xpm_fifo_sync model against the real XPM macro in xsim, clock by clock: every output, random
# traffic with fill/drain phases and resets of 1 to 3 clocks. Configurations: the depths and widths the QICK
# cores use (N 16, B 16 / 40 / 160), other depths, with and without the advanced features.
# Needs Vivado (xsim, the xpm library) on PATH. usage: run_vendor_check.sh [workdir]
set -e
here=$(cd "$(dirname "$0")" && pwd)
fw=$(cd "$here/../../../../../../.." && pwd)            # firmware/
work=${1:-$(mktemp -d)}; mkdir -p "$work"; cd "$work"
sed 's/^module xpm_fifo_sync\b/module emu_xpm_fifo_sync/' "${MODEL_SRC:-$fw/rtl_lib/emulator/xpm_fifo_sync.sv}" > model.sv
fail=0
run() {   # name, then -d macros
    name=$1; shift
    rm -rf xsim.dir
    xvlog -sv "$@" model.sv "$here/tb_vendor_cmp.sv" > "c_$name.log" 2>&1 || { echo "$name: COMPILE ERROR (see $work/c_$name.log)"; fail=1; return; }
    xelab --relax -L xpm -s "s_$name" work.tb_vendor_cmp > "e_$name.log" 2>&1 || { echo "$name: ELAB ERROR (see $work/e_$name.log)"; fail=1; return; }
    xsim "s_$name" -R > "r_$name.log" 2>&1
    if grep -q "^DONE" "r_$name.log" && grep -q "ERRCOUNT=0" "r_$name.log"; then
        echo "$name: PASS ($(grep -o 'nchk=[0-9]*' r_$name.log), $(grep -o '(resets.*)' r_$name.log))"
    else
        echo "$name: FAIL (see $work/r_$name.log)"; grep MISMATCH "r_$name.log" | head -4; fail=1
    fi
}
run "n16_b16"      -d N=16 -d B=16
run "n16_b40"      -d N=16 -d B=40
run "n16_b160"     -d N=16 -d B=160
run "n32_b16"      -d N=32 -d B=16
run "n64_b32"      -d N=64 -d B=32
run "n16_adv0707"  -d N=16 -d B=16 -d 'ADV="0707"'
run "n16_thr"      -d N=16 -d B=16 -d PFT=9 -d PET=8   # legal range of the macro for N=16: 5..11
exit $fail
