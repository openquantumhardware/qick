#!/bin/bash
# Check the xpm_fifo_async model against the real XPM macro in xsim, clock by clock, in both clock domains:
# random traffic with fill/drain phases and resets of 1 to 3 clocks, for several relations of the two clocks
# (either faster, close and far ratios, the 430/200 MHz of the tProc dispatcher), depths and widths.
# Needs Vivado (xsim, the xpm and unisims libraries, glbl) on PATH. usage: run_vendor_check.sh [workdir]
set -e
here=$(cd "$(dirname "$0")" && pwd)
fw=$(cd "$here/../../../../../../.." && pwd)            # firmware/
work=${1:-$(mktemp -d)}; mkdir -p "$work"; cd "$work"
glbl=$(dirname "$(dirname "$(which xvlog)")")/data/verilog/src/glbl.v
sed 's/^module xpm_fifo_async\b/module emu_xpm_fifo_async/' "${MODEL_SRC:-$fw/rtl_lib/emulator/xpm_fifo_async.sv}" > model.sv
fail=0
run() {   # name, then -d macros
    name=$1; shift
    rm -rf xsim.dir
    xvlog -sv "$@" model.sv "$here/tb_vendor_cmp.sv" "$glbl" > "c_$name.log" 2>&1 || { echo "$name: COMPILE ERROR (see $work/c_$name.log)"; fail=1; return; }
    xelab --relax -L xpm -L unisims_ver -s "s_$name" work.tb_vendor_cmp work.glbl > "e_$name.log" 2>&1 || { echo "$name: ELAB ERROR (see $work/e_$name.log)"; fail=1; return; }
    xsim "s_$name" -R > "r_$name.log" 2>&1
    if grep -q "^DONE" "r_$name.log" && grep -q "ERRCOUNT=0" "r_$name.log"; then
        echo "$name: PASS ($(grep -o 'nchk=[0-9]*' r_$name.log), $(grep -o '(resets.*)' r_$name.log))"
    else
        echo "$name: FAIL (see $work/r_$name.log)"; grep MISMATCH "r_$name.log" | head -4; fail=1
    fi
}
run "w10_r7p3"       -d WP=10.0  -d RP=7.3
run "w7p3_r10"       -d WP=7.3   -d RP=10.0
run "w5_r12p3"       -d WP=5.0   -d RP=12.3
run "w12p3_r5"       -d WP=12.3  -d RP=5.0
run "w2p324_r5"      -d WP=2.324 -d RP=5.0
run "w5_r2p324"      -d WP=5.0   -d RP=2.324
run "close_9p7_10"   -d WP=9.7   -d RP=10.0
run "n32_b40"        -d N=32  -d B=40
run "n256_b32"       -d N=256 -d B=32 -d RUNNS=1500000
run "b216"           -d N=16  -d B=216
run "ss3"            -d SS=3
run "ss4_far"        -d SS=4 -d WP=3.1 -d RP=11.7
run "adv0707"        -d 'ADV="0707"'
exit $fail
