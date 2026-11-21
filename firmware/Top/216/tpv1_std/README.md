# 216/tpv1_std

tProc v1 firmware for the ZCU216.

| | |
|---|---|
| Board | ZCU216 (`xilinx.com:zcu216:part0:2.0`) |
| FPGA part | `xczu49dr-ffvf1760-2-e` |
| Processor | tProc v1 (`axis_tprocv1`) |
| Vivado | 2023.1 |
| Block design | `bd_2023-1.tcl` |
| Name before the `Top/` migration | `qick_tprocv1_216_standard` |

## What is in the block design

The `qick:ip` IPs it packages in `pre-creation.tcl` are declared in [`qick_ips.txt`](qick_ips.txt) (8): [`axis_avg_buffer`](../../../fusesoc/cores/ip/axis_avg_buffer/README.md), [`axis_buffer_ddr`](../../../fusesoc/cores/ip/axis_buffer_ddr/README.md), [`axis_readout_v2`](../../../fusesoc/cores/ip/axis_readout_v2/README.md), [`axis_register_slice_nb`](../../../fusesoc/cores/ip/axis_register_slice_nb/README.md), [`axis_set_reg`](../../../fusesoc/cores/ip/axis_set_reg/README.md), [`axis_signal_gen_v6`](../../../fusesoc/cores/ip/axis_signal_gen_v6/README.md), [`axis_tprocv1`](../../../fusesoc/cores/ip/axis_tprocv1/README.md), [`mr_buffer_et`](../../../fusesoc/cores/ip/mr_buffer_et/README.md).

Instances of them in the block design (counted in `bd_2023-1.tcl`):

| IP | Instances |
|---|---|
| `axis_signal_gen_v6` | 7 |
| `axis_avg_buffer` | 2 |
| `axis_readout_v2` | 2 |
| `axis_register_slice_nb` | 2 |
| `axis_buffer_ddr` | 1 |
| `axis_set_reg` | 1 |
| `axis_tprocv1` | 1 |
| `mr_buffer_et` | 1 |

## Build

From `firmware/`:

```bash
./Hog/Do CREATEWORKFLOW 216/tpv1_std          # with Hog (development)
vivado -source Top/216/tpv1_std/proj.tcl   # without Hog (release); then synthesis and implementation
```

With Hog the result is `bin/216/tpv1_std-v<version>-<SHA>/` with the `.bit`, the `.hwh` (same base name), `timing_ok.txt` and `timing_summary.md` (slack per clock pair, failing paths by IP). Take the `.bit` and `.hwh` of the same build to the board.
Both ways and the checks after a build are in [firmware/README.md](../../../README.md) and [HOG_QICK_Integration_Guide.md](../../../docs/developer/HOG_QICK_Integration_Guide.md).

## Changing it

- After exporting a new block design script, or changing the RTL of an IP it uses, run `make -C fusesoc hog-lists PROJ=216/tpv1_std` and commit the lists ([why](../../../docs/developer/HOG_TRACEABILITY.md)).
- An IP that the block design adds or drops is added to or removed from `qick_ips.txt`.

## Status

The block design was migrated to the `qick:ip` cores (2026-09-25) and passed `validate_bd_design`. The project has not been rebuilt and re-validated since then.
