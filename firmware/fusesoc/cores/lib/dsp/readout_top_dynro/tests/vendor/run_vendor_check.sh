#!/bin/bash
# readout_top_dynro with the behavioural models of the DDS and the FIR (what the emulator and the unit tests use)
# against the same RTL with the real DDS Compiler and FIR Compiler IP, generated from the .xci, on the same input:
# the product (m0) and the decimated data (m1) must agree to within a few counts once the pipeline runs, and the
# valid of m1 must be the same. Needs Vivado (xsim and its precompiled IP libraries) on PATH.
# usage: run_vendor_check.sh [workdir]
# Measured on the unmodified RTL: product 3 counts, decimated 1 count. Mutations it catches: the FIR with 2^-15 gain
# (the 1.0.0 bug), the FIR with 10 clocks of latency, the DDS at twice the frequency. NOT caught: a DDS that ignores
# the resync flag (this stimulus never sends one mid-pulse). FIR_SRC / DDS_SRC replace the model sources (mutations).
set -e
here=$(cd "$(dirname "$0")" && pwd)
fw=$(cd "$here/../../../../../../.." && pwd)            # firmware/
work=${1:-$(mktemp -d)}; mkdir -p "$work/xci/dds" "$work/xci/fir"; cd "$work"
glbl=$(dirname "$(dirname "$(which xvlog)")")/data/verilog/src/glbl.v
cp "$fw/rtl_lib/xci/dds_compiler_dyn_readout/"* xci/dds/
cp "$fw/rtl_lib/xci/fir_decim8_dynro/"* xci/fir/
vivado -mode batch -nojournal -nolog -notrace -source "$here/gen_ip_sim.tcl" -tclargs "$work" > gen.log 2>&1
ipdir=$work/proj/ipsim.gen/sources_1/ip
sed 's/fir_decim8_dynro/fir_ip_real/g' $ipdir/fir_decim8_dynro/sim/fir_decim8_dynro.vhd > "$work/fir_ip_real.vhd"
r="$fw/rtl_lib"
common="$r/ctrl/ctrl_dyn_ro.sv $r/mem/fifo_sync.sv $r/dsp/down_conversion_dynro.sv $r/dsp/readout_top_dynro.sv"
libs="-L dds_compiler_v6_0_28 -L fir_compiler_v7_2_26 -L xbip_utils_v3_0_15 -L axi_utils_v2_0_11 -L xbip_pipe_v3_0_11 -L xpm -L unisims_ver"
build() {   # tag, files...
    tag=$1; shift; rm -rf "$tag"; mkdir "$tag"; cd "$tag"
    cp "$work"/proj/ipsim.ip_user_files/mem_init_files/fir_decim8_dynro.mif . ; cp fir_decim8_dynro.mif fir_ip_real.mif   # read at elaboration
    for f in "$@"; do
        case $f in *.vhd) xvhdl --relax -work work "$f" > "v_$(basename $f).log" 2>&1 || { echo "VHDL COMPILE ERROR $f"; exit 1; } ;;
                   *) xvlog -sv "$f" > "c_$(basename $f).log" 2>&1 || { echo "COMPILE ERROR $f"; exit 1; } ;; esac
    done
    xvlog -sv "$here/tb_ro.sv" > c_tb.log 2>&1 || { echo "COMPILE ERROR tb"; exit 1; }
    xelab --relax $libs -s s work.tb_ro work.glbl > e.log 2>&1 || { echo "ELAB ERROR (see $work/$tag/e.log)"; exit 1; }
    xsim s -R > r.log 2>&1
    cd ..
}
build models "$glbl" "${DDS_SRC:-$r/dsp/dds_compiler_model.sv}" "${FIR_SRC:-$r/dsp/fir_decim8_dynro.sv}" "$r/dsp/dds_compiler_dyn_readout.sv" $common
build ip "$glbl" "$ipdir/dds_compiler_dyn_readout/sim/dds_compiler_dyn_readout.vhd" "$work/fir_ip_real.vhd" "$here/fir_shim.sv" $common
# trace columns: cycle m1_valid m1_I m1_Q m0_valid then 8 lanes of (I Q)
paste -d' ' models/trace.txt ip/trace.txt | awk -v maxm0=8 -v maxm1=2 '
    function abs(x) { return x < 0 ? -x : x }
    { n = NF / 2; row = $1
      if (row >= 100) { if ($2 != $(n + 2)) vbad++ ; for (i = 6; i <= n; i++) { d = abs($i - $(n + i)); if (d > m0) m0 = d } }
      if (row >= 200) for (i = 3; i <= 4; i++) { d = abs($i - $(n + i)); if (d > m1) m1 = d } }
    END { printf "readout_top_dynro models against the real IP: max |diff| product %d (limit %d), decimated %d (limit %d), valid mismatches %d\n", m0, maxm0, m1, maxm1, vbad
          exit !(m0 <= maxm0 && m1 <= maxm1 && vbad == 0) }'
