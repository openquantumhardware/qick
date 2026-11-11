# 111/tpv2_std

tProc v2 firmware for the ZCU111.

| | |
|---|---|
| Board | ZCU111 (`xilinx.com:zcu111:part0:1.4`) |
| FPGA part | `xczu28dr-ffvg1517-2-e` |
| Processor | tProc v2 (`qick_processor`) |
| Vivado | 2023.1 |
| Block design | `bd_2023-1.tcl` |
| Name before the `Top/` migration | `qick_tprocv2_111_standard` |

## What is in the block design

The `qick:ip` IPs it packages in `pre-creation.tcl` are declared in [`qick_ips.txt`](qick_ips.txt) (9): [`axis_avg_buffer`](../../../fusesoc/cores/ip/axis_avg_buffer/README.md), [`axis_buffer_ddr`](../../../fusesoc/cores/ip/axis_buffer_ddr/README.md), [`axis_cdcsync_v1`](../../../fusesoc/cores/ip/axis_cdcsync_v1/README.md), [`axis_dyn_readout_v1`](../../../fusesoc/cores/ip/axis_dyn_readout_v1/README.md), [`axis_register_slice_nb`](../../../fusesoc/cores/ip/axis_register_slice_nb/README.md), [`axis_signal_gen_v6`](../../../fusesoc/cores/ip/axis_signal_gen_v6/README.md), [`mr_buffer_et`](../../../fusesoc/cores/ip/mr_buffer_et/README.md), [`qick_processor`](../../../fusesoc/cores/ip/qick_processor/README.md), [`sg_translator`](../../../fusesoc/cores/ip/sg_translator/README.md).

Instances of them in the block design (counted in `bd_2023-1.tcl`):

| IP | Instances |
|---|---|
| `sg_translator` | 12 |
| `axis_signal_gen_v6` | 8 |
| `axis_avg_buffer` | 4 |
| `axis_dyn_readout_v1` | 4 |
| `axis_register_slice_nb` | 4 |
| `axis_buffer_ddr` | 1 |
| `axis_cdcsync_v1` | 1 |
| `mr_buffer_et` | 1 |
| `qick_processor` | 1 |

## Build

From `firmware/`:

```bash
./Hog/Do CREATEWORKFLOW 111/tpv2_std          # with Hog (development)
vivado -source Top/111/tpv2_std/proj.tcl   # without Hog (release); then synthesis and implementation
```

With Hog the result is `bin/111/tpv2_std-v<version>-<SHA>/` with the `.bit`, the `.hwh` (same base name), `timing_ok.txt` and `timing_summary.md` (slack per clock pair, failing paths by IP). Take the `.bit` and `.hwh` of the same build to the board.
Both ways and the checks after a build are in [firmware/README.md](../../../README.md) and [HOG_QICK_Integration_Guide.md](../../../docs/developer/HOG_QICK_Integration_Guide.md).

## Changing it

- After exporting a new block design script, or changing the RTL of an IP it uses, run `make -C fusesoc hog-lists PROJ=111/tpv2_std` and commit the lists ([why](../../../docs/developer/HOG_TRACEABILITY.md)).
- An IP that the block design adds or drops is added to or removed from `qick_ips.txt`.

## Timing

The ADC x2 domain (512 MHz, `clk_adc0_x2`) has little margin. Build AD9B7A5 (Vivado 2023.1, plain `./Hog/Do CREATEWORKFLOW`, no manual step) meets timing: setup WNS +0.031 ns (`clk_adc0_x2`), hold +0.009 ns, pulse width 0, 0 failing endpoints of 842 740. It has `axis_avg_buffer` 1.2.1 (registered inputs and memory write) and the directives of the strategy, `ExtraNetDelay_high` (placement) and `NoTimingRelaxation` (routing); with `axis_avg_buffer` 1.2.0 and the same directives this domain failed by 0.081 ns. Not run on a board with this build.

The margin is small: any later change of RTL in the ADC x2 domain can open it again. If `timing_summary.md` of a new build says not met, read the failing paths by block, fix the RTL there, and only then repeat `impl_1` with other directives (`ExtraPostPlacementOpt` or `ExtraTimingOpt` / `MoreGlobalIterations` also closed on an earlier synthesis) and set the pair that closes with the most margin in `proj.tcl` after the strategy, with the same values in `hog.conf` (as 2x4/tpv1_std does: Hog applies `hog.conf` before it sources `proj.tcl`, whose strategy resets the directives, and then compares the two).

## Status

The block design was migrated to the `qick:ip` cores (2026-09-25) and passed `validate_bd_design`. The project has not been rebuilt and re-validated since then.
