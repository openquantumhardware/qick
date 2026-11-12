#!/bin/bash
# Check the xpm_memory_tdpram model against the real XPM macro in xsim, cycle by cycle, for the
# configurations the QICK cores use and the neighbouring ones (latency 1/2 per port, the three write
# modes, 1 and 4 byte columns, an init file, a random regce). Needs Vivado (xsim, the xpm library) on PATH.
# usage: run_vendor_check.sh [workdir]
set -e
here=$(cd "$(dirname "$0")" && pwd)
fw=$(cd "$here/../../../../../../.." && pwd)            # firmware/
work=${1:-$(mktemp -d)}; mkdir -p "$work"; cd "$work"
sed "s/^module xpm_memory_tdpram\\b/module emu_xpm_memory_tdpram/" "${MODEL_SRC:-$fw/rtl_lib/emulator/xpm_memory_tdpram.sv}" > model.sv
fail=0; n=0
run() {   # name, then -d macros
    name=$1; shift
    rm -rf xsim.dir
    xvlog -sv "$@" model.sv "$here/tb_vendor_cmp.sv" > "c_$name.log" 2>&1 || { echo "$name: COMPILE ERROR (see $work/c_$name.log)"; fail=1; return; }
    xelab --relax -L xpm -s "s_$name" work.tb_vendor_cmp > "e_$name.log" 2>&1 || { echo "$name: ELAB ERROR (see $work/e_$name.log)"; fail=1; return; }
    xsim "s_$name" -R > "r_$name.log" 2>&1
    if grep -q "^DONE" "r_$name.log" && grep -q "ERRCOUNT=0" "r_$name.log"; then
        echo "$name: PASS ($(grep -o 'nchk=[0-9]*' r_$name.log))"
    else
        echo "$name: FAIL (see $work/r_$name.log)"; grep MISMATCH "r_$name.log" | head -3; fail=1
    fi
}
for la in 1 2; do for lb in 1 2; do
    run "lat${la}${lb}" -d LAT_A=$la -d LAT_B=$lb
done; done
for wm in read_first no_change write_first; do for lat in 1 2; do
    run "wm_${wm}_lat$lat" -d LAT_A=$lat -d LAT_B=$lat -d "WM_A=\"$wm\"" -d "WM_B=\"$wm\""
done; done
run "mixed_modes" -d LAT_A=2 -d LAT_B=1 -d 'WM_A="read_first"' -d 'WM_B="no_change"'
run "cols4_lat2" -d COLS=4 -d LAT_A=2 -d LAT_B=2
run "cols4_lat1_rf" -d COLS=4 -d LAT_A=1 -d LAT_B=1 -d 'WM_A="read_first"' -d 'WM_B="read_first"'
run "regce_rand" -d LAT_A=2 -d LAT_B=2 -d REGCE_RAND=1
# init file: 32 words of W bits (8 bits x 1 column), hex
python3 - <<'PY'
with open("init.mem", "w") as f:
    for i in range(32): f.write("%02x\n" % ((i * 37 + 11) & 0xFF))
PY
run "init_file" -d LAT_A=2 -d LAT_B=1 -d 'INIT="init.mem"'
exit $fail
