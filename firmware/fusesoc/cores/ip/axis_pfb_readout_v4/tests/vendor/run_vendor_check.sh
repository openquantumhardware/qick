#!/bin/bash
# axis_pfb_readout_v4 as the QICK emulator has it (the FFT as the behavioural ssr_8x64 model, the FIRs and the DDS as their models)
# against the same RTL with the real IPs: the System Generator FFT, the eight FIR Compilers and the DDS Compiler generated from
# the .xci. Same input and the same AXI configuration; the eight outputs of every clock of a 3000-clock window are compared.
# Needs Vivado (xsim, its precompiled IP libraries) and fusesoc on PATH. usage: run_vendor_check.sh [workdir]
# ENV: MAXERR (counts, default 4), MODEL_FFT (source of the FFT model, to try mutations).
set -e
MAXERR=${MAXERR:-4}
here=$(cd "$(dirname "$0")" && pwd)
fw=$(cd "$here/../../../../../.." && pwd)                 # firmware/
work=${1:-$(mktemp -d)}; mkdir -p "$work"; cd "$work"
glbl=$(dirname "$(dirname "$(which xvlog)")")/data/verilog/src/glbl.v
fft_model=${MODEL_FFT:-$fw/rtl_lib/emulator/ssr_8x64.sv}

# the file list of the IP as xsim gets it (fusesoc), and the IPs generated from the .xci
fusesoc --cores-root $fw/fusesoc/cores --cores-root $fw/fusesoc/common --cores-root $fw/fusesoc/generators \
    run --target default --tool xsim --setup --build-root "$work/fs" qick:ip:axis_pfb_readout_v4 > fs.log 2>&1
prjdir=$(ls -d "$work"/fs/*/default-xsim); prj=$(ls "$prjdir"/*.prj)
mkdir -p xci; for i in 0 1 2 3 4 5 6 7; do mkdir -p xci/fir_pfb_ro_$i; cp "$fw/rtl_lib/xci/fir_pfb_ro_$i/"* xci/fir_pfb_ro_$i/; done
mkdir -p xci/dds_compiler_pfb_ro; cp "$fw/rtl_lib/xci/dds_compiler_pfb_ro/"* xci/dds_compiler_pfb_ro/
vivado -mode batch -nojournal -nolog -notrace -source "$here/gen_ip_sim.tcl" -tclargs "$work" > gen.log 2>&1
ipdir=$work/proj/ipsim.gen/sources_1/ip
libs="-L xil_defaultlib -L xbip_utils_v3_0_15 -L axi_utils_v2_0_11 -L xbip_pipe_v3_0_11 -L xbip_bram18k_v3_0_11 -L mult_gen_v12_0_23 \
 -L xbip_dsp48_wrapper_v3_0_7 -L xbip_dsp48_addsub_v3_0_11 -L xbip_dsp48_multadd_v3_0_11 -L dds_compiler_v6_0_28 -L fir_compiler_v7_2_26 -L xpm -L unisims_ver"

build() {   # tag, mode (models|ip)
    tag=$1; mode=$2; rm -rf "$tag"; mkdir "$tag"; cd "$tag"
    cp "$work"/proj/ipsim.ip_user_files/mem_init_files/*.mif . 2>/dev/null || true
    cd "$prjdir"
    while read -r kind lib file; do
        f=$prjdir/$file
        case "$mode:$kind:$file" in
            models:vhdl:*ssr_fft_8x64*) continue ;;                                        # the FFT is the model
            ip:sv:*fir_pfb_ro_[0-7]_*|ip:sv:*fir_pfb_ro_model*|ip:sv:*dds_compiler_pfb_ro_*) continue ;;   # the IPs replace the wrappers
        esac
        if [ "$kind" = vhdl ]; then (cd "$work/$tag" && xvhdl --relax -work $lib "$f" > "v_$(basename $file).log" 2>&1) || { echo "VHDL COMPILE ERROR $file"; exit 1; }
        else (cd "$work/$tag" && xvlog -sv "$f" > "c_$(basename $file).log" 2>&1) || { echo "COMPILE ERROR $file"; exit 1; }; fi
    done < <(grep -E '^(sv|vhdl) ' "$prj")
    cd "$work/$tag"
    if [ "$mode" = models ]; then xvlog -sv "$fft_model" > c_fft.log 2>&1 || { echo "COMPILE ERROR fft model"; exit 1; }
    else
        for i in 0 1 2 3 4 5 6 7; do xvhdl --relax -work xil_defaultlib $ipdir/fir_pfb_ro_$i/sim/fir_pfb_ro_$i.vhd > v_fir$i.log 2>&1 || { echo "VHDL COMPILE ERROR fir $i"; exit 1; }; done
        xvhdl --relax -work xil_defaultlib $ipdir/dds_compiler_pfb_ro/sim/dds_compiler_pfb_ro.vhd > v_dds.log 2>&1 || { echo "VHDL COMPILE ERROR dds"; exit 1; }
    fi
    xvlog -sv "$here/tb_pfb.sv" "$glbl" > c_tb.log 2>&1 || { echo "COMPILE ERROR tb"; exit 1; }
    xelab --relax $libs -s s work.tb_pfb work.glbl > e.log 2>&1 || { echo "ELAB ERROR (see $work/$tag/e.log)"; exit 1; }
    xsim s -R > r.log 2>&1
    cd "$work"
}
build models models
build ip ip
# trace: cycle, then (valid I Q) x 8
paste -d' ' models/trace.txt ip/trace.txt | awk -v maxerr=$MAXERR '
    function abs(x) { return x < 0 ? -x : x }
    { n = NF / 2
      for (o = 0; o < 8; o++) {
        a = 2 + 3 * o; v1 = $a; v2 = $(n + a)
        if (v1 != v2) vbad++
        if (v1 == 1 && v2 == 1) {
          di = abs($(a + 1) - $(n + a + 1)); dq = abs($(a + 2) - $(n + a + 2)); d = di > dq ? di : dq
          if (d > m[o]) m[o] = d
          if (d > mx) mx = d
          p = abs($(n + a + 1)); if (p > pk) pk = p
          q = abs($(n + a + 2)); if (q > pk) pk = q
          nv++
        }
      } }
    END { printf "axis_pfb_readout_v4, models against the real IPs: max |diff| %d counts (limit %d) over %d valid outputs, largest output %d, valid mismatches %d\n", mx, maxerr, nv, pk, vbad
          printf "   max |diff| per output:"; for (o = 0; o < 8; o++) printf " %d", m[o]; printf "\n"
          exit !(mx <= maxerr && vbad == 0 && nv > 0) }'
