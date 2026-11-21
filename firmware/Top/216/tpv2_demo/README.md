# 216/tpv2_demo

tProc v2 firmware for the ZCU216 (demo variant).

| | |
|---|---|
| Board | ZCU216 (`xilinx.com:zcu216:part0:2.0`) |
| FPGA part | `xczu49dr-ffvf1760-2-e` |
| Processor | tProc v2 (`qick_processor`) |
| Vivado | 2023.1 |
| Block design | `bd_2023-1.tcl` |
| Name before the `Top/` migration | `qick_tprocv2_216_demo` |

## What is in the block design

The `qick:ip` IPs it packages in `pre-creation.tcl` are declared in [`qick_ips.txt`](qick_ips.txt) (17): [`axis_avg_buffer`](../../../fusesoc/cores/ip/axis_avg_buffer/README.md), [`axis_buffer_ddr`](../../../fusesoc/cores/ip/axis_buffer_ddr/README.md), [`axis_cdcsync_v1`](../../../fusesoc/cores/ip/axis_cdcsync_v1/README.md), [`axis_dyn_readout_v1`](../../../fusesoc/cores/ip/axis_dyn_readout_v1/README.md), [`axis_pfb_readout_v3`](../../../fusesoc/cores/ip/axis_pfb_readout_v3/README.md), [`axis_readout_v2`](../../../fusesoc/cores/ip/axis_readout_v2/README.md), [`axis_readout_v3`](../../../fusesoc/cores/ip/axis_readout_v3/README.md), [`axis_register_slice_nb`](../../../fusesoc/cores/ip/axis_register_slice_nb/README.md), [`axis_resampler_2x1_v1`](../../../fusesoc/cores/ip/axis_resampler_2x1_v1/README.md), [`axis_sg_int4_v2`](../../../fusesoc/cores/ip/axis_sg_int4_v2/README.md), [`axis_sg_mixmux8_v1`](../../../fusesoc/cores/ip/axis_sg_mixmux8_v1/README.md), [`axis_sg_mux8_v1`](../../../fusesoc/cores/ip/axis_sg_mux8_v1/README.md), [`axis_signal_gen_v6`](../../../fusesoc/cores/ip/axis_signal_gen_v6/README.md), [`axis_tmux_v1`](../../../fusesoc/cores/ip/axis_tmux_v1/README.md), [`mr_buffer_et`](../../../fusesoc/cores/ip/mr_buffer_et/README.md), [`qick_processor`](../../../fusesoc/cores/ip/qick_processor/README.md), [`sg_translator`](../../../fusesoc/cores/ip/sg_translator/README.md).

Instances of them in the block design (counted in `bd_2023-1.tcl`):

| IP | Instances |
|---|---|
| `sg_translator` | 8 |
| `axis_avg_buffer` | 7 |
| `axis_register_slice_nb` | 3 |
| `axis_sg_int4_v2` | 2 |
| `axis_signal_gen_v6` | 2 |
| `axis_buffer_ddr` | 1 |
| `axis_cdcsync_v1` | 1 |
| `axis_dyn_readout_v1` | 1 |
| `axis_pfb_readout_v3` | 1 |
| `axis_readout_v2` | 1 |
| `axis_readout_v3` | 1 |
| `axis_resampler_2x1_v1` | 1 |
| `axis_sg_mixmux8_v1` | 1 |
| `axis_sg_mux8_v1` | 1 |
| `axis_tmux_v1` | 1 |
| `mr_buffer_et` | 1 |
| `qick_processor` | 1 |

## Build

From `firmware/`:

```bash
./Hog/Do CREATEWORKFLOW 216/tpv2_demo          # with Hog (development)
vivado -source Top/216/tpv2_demo/proj.tcl   # without Hog (release); then synthesis and implementation
```

With Hog the result is `bin/216/tpv2_demo-v<version>-<SHA>/` with the `.bit`, the `.hwh` (same base name), `timing_ok.txt` and `timing_summary.md` (slack per clock pair, failing paths by IP). Take the `.bit` and `.hwh` of the same build to the board.
Both ways and the checks after a build are in [firmware/README.md](../../../README.md) and [HOG_QICK_Integration_Guide.md](../../../docs/developer/HOG_QICK_Integration_Guide.md).

## Changing it

- After exporting a new block design script, or changing the RTL of an IP it uses, run `make -C fusesoc hog-lists PROJ=216/tpv2_demo` and commit the lists ([why](../../../docs/developer/HOG_TRACEABILITY.md)).
- An IP that the block design adds or drops is added to or removed from `qick_ips.txt`.

## Status

The block design was migrated to the `qick:ip` cores (2026-09-25) and passed `validate_bd_design`. The project has not been rebuilt and re-validated since then.
