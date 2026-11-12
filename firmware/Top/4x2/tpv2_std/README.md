# 4x2/tpv2_std

tProc v2 firmware for the RFSoC4x2.

| | |
|---|---|
| Board | RFSoC4x2 (`realdigital.org:rfsoc4x2:part0:1.0`) |
| FPGA part | `xczu48dr-ffvg1517-2-e` |
| Processor | tProc v2 (`qick_processor`) |
| Vivado | 2023.1 |
| Block design | `bd_2023-1.tcl` |
| Name before the `Top/` migration | `qick_tprocv2_4x2_standard` |

## What is in the block design

The `qick:ip` IPs it packages in `pre-creation.tcl` are declared in [`qick_ips.txt`](qick_ips.txt) (11): [`axis_avg_buffer`](../../../fusesoc/cores/ip/axis_avg_buffer/README.md), [`axis_buffer_ddr`](../../../fusesoc/cores/ip/axis_buffer_ddr/README.md), [`axis_cdcsync_v1`](../../../fusesoc/cores/ip/axis_cdcsync_v1/README.md), [`axis_dyn_readout_v1`](../../../fusesoc/cores/ip/axis_dyn_readout_v1/README.md), [`axis_register_slice_nb`](../../../fusesoc/cores/ip/axis_register_slice_nb/README.md), [`axis_signal_gen_v6`](../../../fusesoc/cores/ip/axis_signal_gen_v6/README.md), [`axis_weighted_buffer`](../../../fusesoc/cores/ip/axis_weighted_buffer/README.md), [`mr_buffer_et`](../../../fusesoc/cores/ip/mr_buffer_et/README.md), [`qick_processor`](../../../fusesoc/cores/ip/qick_processor/README.md), [`qick_time_tagger`](../../../fusesoc/cores/ip/qick_time_tagger/README.md), [`sg_translator`](../../../fusesoc/cores/ip/sg_translator/README.md).

Instances of them in the block design (counted in `bd_2023-1.tcl`):

| IP | Instances |
|---|---|
| `axis_register_slice_nb` | 6 |
| `sg_translator` | 5 |
| `axis_dyn_readout_v1` | 3 |
| `axis_avg_buffer` | 2 |
| `axis_signal_gen_v6` | 2 |
| `axis_buffer_ddr` | 1 |
| `axis_cdcsync_v1` | 1 |
| `axis_weighted_buffer` | 1 |
| `mr_buffer_et` | 1 |
| `qick_processor` | 1 |
| `qick_time_tagger` | 1 |

## Build

From `firmware/`:

```bash
./Hog/Do CREATEWORKFLOW 4x2/tpv2_std          # with Hog (development)
vivado -source Top/4x2/tpv2_std/proj.tcl   # without Hog (release); then synthesis and implementation
```

With Hog the result is `bin/4x2/tpv2_std-v<version>-<SHA>/` with the `.bit`, the `.hwh` (same base name), `timing_ok.txt` and `timing_summary.md` (slack per clock pair, failing paths by IP). Take the `.bit` and `.hwh` of the same build to the board.
Both ways and the checks after a build are in [firmware/README.md](../../../README.md) and [HOG_QICK_Integration_Guide.md](../../../docs/developer/HOG_QICK_Integration_Guide.md).

## Changing it

- After exporting a new block design script, or changing the RTL of an IP it uses, run `make -C fusesoc hog-lists PROJ=4x2/tpv2_std` and commit the lists ([why](../../../docs/developer/HOG_TRACEABILITY.md)).
- An IP that the block design adds or drops is added to or removed from `qick_ips.txt`.

## Status

The block design was migrated to the `qick:ip` cores (2026-09-25) and passed `validate_bd_design`. Build 9D75BD7 (Vivado 2023.1, plain `./Hog/Do CREATEWORKFLOW`) meets timing: setup WNS +0.030 ns (ADC x2 clock), WHS +0.010 ns, TPWS +0.028 ns, 0 failing endpoints of 541 337. Not run on a board with this build.
