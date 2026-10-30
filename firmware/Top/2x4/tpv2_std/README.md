# 2x4/tpv2_std

tProc v2 firmware for the RFSoC 2x4.

| | |
|---|---|
| Board | RFSoC 2x4 (`realdigital.org:rfsoc4x2:part0:1.0`) |
| FPGA part | `xczu48dr-ffvg1517-2-e` |
| Processor | tProc v2 (`qick_processor`) |
| Vivado | 2023.1 |
| Block design | `bd_2023-1.tcl` |
| Name before the `Top/` migration | `qick_tprocv2_2x4_standard` |

## What is in the block design

The `qick:ip` IPs it packages in `pre-creation.tcl` are declared in [`qick_ips.txt`](qick_ips.txt) (9): [`axis_avg_buffer`](../../../fusesoc/cores/ip/axis_avg_buffer/README.md), [`axis_buffer_ddr`](../../../fusesoc/cores/ip/axis_buffer_ddr/README.md), [`axis_cdcsync_v1`](../../../fusesoc/cores/ip/axis_cdcsync_v1/README.md), [`axis_dyn_readout_v1`](../../../fusesoc/cores/ip/axis_dyn_readout_v1/README.md), [`axis_register_slice_nb`](../../../fusesoc/cores/ip/axis_register_slice_nb/README.md), [`axis_signal_gen_v6`](../../../fusesoc/cores/ip/axis_signal_gen_v6/README.md), [`mr_buffer_et`](../../../fusesoc/cores/ip/mr_buffer_et/README.md), [`qick_processor`](../../../fusesoc/cores/ip/qick_processor/README.md), [`sg_translator`](../../../fusesoc/cores/ip/sg_translator/README.md).

Instances of them in the block design (counted in `bd_2023-1.tcl`):

| IP | Instances |
|---|---|
| `axis_register_slice_nb` | 6 |
| `sg_translator` | 6 |
| `axis_signal_gen_v6` | 4 |
| `axis_avg_buffer` | 2 |
| `axis_dyn_readout_v1` | 2 |
| `axis_buffer_ddr` | 1 |
| `axis_cdcsync_v1` | 1 |
| `mr_buffer_et` | 1 |
| `qick_processor` | 1 |

## Build

From `firmware/`:

```bash
./Hog/Do CREATEWORKFLOW 2x4/tpv2_std          # with Hog (development)
vivado -source Top/2x4/tpv2_std/proj.tcl   # without Hog (release); then synthesis and implementation
```

With Hog the result is `bin/2x4/tpv2_std-v<version>-<SHA>/` with the `.bit`, the `.hwh` (same base name), `timing_ok.txt` and `timing_summary.md` (slack per clock pair, failing paths by IP). Take the `.bit` and `.hwh` of the same build to the board.
Both ways and the checks after a build are in [firmware/README.md](../../../README.md) and [HOG_QICK_Integration_Guide.md](../../../docs/developer/HOG_QICK_Integration_Guide.md).

## Changing it

- After exporting a new block design script, or changing the RTL of an IP it uses, run `make -C fusesoc hog-lists PROJ=2x4/tpv2_std` and commit the lists ([why](../../../docs/developer/HOG_TRACEABILITY.md)).
- An IP that the block design adds or drops is added to or removed from `qick_ips.txt`.

## Status

Created on 2026-10-16 from the public repository's project of the same name. Its block design was validated with Vivado 2023.1 (`validate_bd_design`). Build 95FE9F3 (114 90775500, Vivado 2023.1, plain `./Hog/Do CREATEWORKFLOW`) meets timing: setup WNS +0.000 ns (limiting clock `RFDAC2_CLK`), WHS +0.006 ns, TPWS +0.028 ns, 0 failing endpoints of 523 099. Not tried on a board.
