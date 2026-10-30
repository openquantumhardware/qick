#!/bin/bash
# Compare the ssr_8x64 model with the real System Generator FFT (qick:dsp:ssr_fft_8x64) in xsim: the same
# frames (tones, noise, impulses, DC) go to both and the latency, the valid pattern, the order of the bins and the
# size of the difference are reported. Needs Vivado (xsim) on PATH. usage: run_vendor_check.sh [workdir]
set -e
here=$(cd "$(dirname "$0")" && pwd)
fw=$(cd "$here/../../../../../../.." && pwd)            # firmware/
vhdl="$fw/fusesoc/cores/lib/dsp/ssr_fft_8x64/hdl"
work=${1:-$(mktemp -d)}; mkdir -p "$work"; cd "$work"
sed 's/^module ssr_8x64\b/module emu_ssr_8x64/' "${MODEL_SRC:-$fw/rtl_lib/emulator/ssr_8x64.sv}" > model.sv
rm -rf xsim.dir
for f in conv_pkg synth_reg synth_reg_w_init synth_reg_reg single_reg_w_init srl33e xlclockdriver_rd ssr_8x64_entity_declarations ssr_8x64; do
    xvhdl --relax -work xil_defaultlib "$vhdl/$f.vhd" > "v_$f.log" 2>&1 || { echo "VHDL COMPILE ERROR $f (see $work/v_$f.log)"; exit 1; }
done
fail=0
run() {   # name, then -d macros
    name=$1; shift
    xvlog -sv "$@" model.sv "$here/tb_vendor_cmp.sv" > "c_$name.log" 2>&1 || { echo "$name: COMPILE ERROR (see $work/c_$name.log)"; fail=1; return; }
    xelab --relax -L xil_defaultlib -s "s_$name" work.tb_vendor_cmp > "e_$name.log" 2>&1 || { echo "$name: ELAB ERROR (see $work/e_$name.log)"; fail=1; return; }
    xsim "s_$name" -R > "r_$name.log" 2>&1
    if grep -q "RESULT ERRCOUNT=0" "r_$name.log"; then
        echo "$name: PASS ($(grep -o 'nvalid_real=[0-9]*' r_$name.log), $(grep -o 'maxerr=[0-9]*' r_$name.log) of $(grep -o 'maxmag=[0-9]*' r_$name.log))"
    else
        echo "$name: FAIL (see $work/r_$name.log)"; grep -E "VALID MISMATCH|DIFF|DONE|ERRORS" "r_$name.log" | head -4; fail=1
    fi
}
for sc in 0 1 2 5 6 21 63; do run "scale$sc" -d SCALE=$sc; done
run "gaps" -d GAPS=1 -d SCALE=0
run "gaps_scale3" -d GAPS=1 -d SCALE=3 -d SEED=32\'h0BADF00D
exit $fail
