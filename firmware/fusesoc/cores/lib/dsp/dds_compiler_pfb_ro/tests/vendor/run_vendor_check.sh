#!/bin/bash
# Check dds_compiler_pfb_ro (dds_compiler_model wrapper) against the real DDS
# Compiler 6.0 core generated from its .xci. Needs Vivado (xsim and its
# precompiled IP libraries) on PATH. usage: run_vendor_check.sh [workdir]
# Pass: identical valid timing and at most MAXERR counts on I and Q.
set -e
MAXERR=19
here=$(cd "$(dirname "$0")" && pwd)
fw=$(cd "$here/../../../../../../.." && pwd)            # firmware/
work=${1:-$(mktemp -d)}; mkdir -p "$work"
cp "$fw/rtl_lib/xci/dds_compiler_pfb_ro/dds_compiler_pfb_ro.xci" "$work/"
sed "s/^module dds_compiler_pfb_ro\b/module dds_compiler_pfb_ro_sim/" \
    "$fw/rtl_lib/dsp/dds_compiler_pfb_ro.sv" > "$work/wrap.sv"
(cd "$work" && vivado -mode batch -nojournal -nolog -notrace -source "$here/gen_dds_sim.tcl" -tclargs "$work" > gen.log 2>&1)
cd "$work"
xvhdl --relax -work xil_defaultlib proj/ddssim.gen/sources_1/ip/dds_compiler_pfb_ro/sim/dds_compiler_pfb_ro.vhd > v.log 2>&1
xvlog -sv "$fw/rtl_lib/dsp/dds_compiler_model.sv" wrap.sv "$here/tb_vendor_cmp.sv" > c.log 2>&1
xelab --relax -L xil_defaultlib -L xbip_utils_v3_0_15 -L axi_utils_v2_0_11 -L xbip_pipe_v3_0_11 \
    -L xbip_bram18k_v3_0_11 -L mult_gen_v12_0_23 -L xbip_dsp48_wrapper_v3_0_7 \
    -L xbip_dsp48_addsub_v3_0_11 -L xbip_dsp48_multadd_v3_0_11 -L dds_compiler_v6_0_28 \
    -L xpm -L unisims_ver -s cmp work.tb_vendor_cmp > e.log 2>&1
xsim cmp -R > r.log 2>&1
line=$(grep "^DDSCHK" r.log) || { echo "dds_compiler_pfb_ro: FAIL (no result, see $work)"; exit 1; }
vm=$(echo "$line" | sed 's/.*valid_mismatch=\([0-9]*\).*/\1/'); me=$(echo "$line" | sed 's/.*max_err=\([0-9]*\).*/\1/')
if [ "$vm" -eq 0 ] && [ "$me" -le $MAXERR ]; then echo "dds_compiler_pfb_ro: PASS ($line)"; else echo "dds_compiler_pfb_ro: FAIL ($line)"; exit 1; fi
