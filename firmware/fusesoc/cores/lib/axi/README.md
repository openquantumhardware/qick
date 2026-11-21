# Library cores: axi

AXI4, AXI4-Lite and AXI4-Stream utilities.

Each core is its own FuseSoC core (`qick:axi:<name>:<version>`, the version is in the `name:` of its `.core` file); the RTL is in `firmware/rtl_lib/` and `hdl/` links to it.
Simulate one with `make sim IP=<name>`, lint it with `make lint IP=<name>`. How to create a core: [NEW_CORE.md](../../../../docs/developer/NEW_CORE.md).

| Core | What it is | Tests |
|---|---|---|
| [`axi_mst_read`](axi_mst_read/) | AXI4 master read channel of axis_buffer_ddr: bursts of up to 256 beats, never across 4 kB, into a FIFO and out on AXI4-Stream | no |
| [`axi_mst_write`](axi_mst_write/) | AXI4 master write channel of axis_buffer_ddr: AXI4-Stream into a FIFO, written to DDR in bursts when triggered | no |
| [`axi_slv_tprocv1`](axi_slv_tprocv1/) | AXI4-Lite slave of axis_tprocv1: eight control registers and single-word access to the data memory over one port | no (tested through axis_tprocv1) |
| [`axil_slv`](axil_slv/) | AXI Lite Slave core. It support up to 16 registers | yes |
| [`axis_data_concat`](axis_data_concat/) | Prepends an offset word to every AXI-Stream beat | yes |
| [`axis_pipe`](axis_pipe/) | Elastic pipeline primitive | yes |
| [`axis_tap`](axis_tap/) | Elastic pipeline primitive | yes |
| [`axis_to_bram_sg`](axis_to_bram_sg/) | Data writter from AXI-Stream to BRAM memory using a trigger | yes |
| [`axis_to_bram_sg_nt`](axis_to_bram_sg_nt/) | Data writter from AXI-Stream to BRAM memory using a trigger | yes |
| [`axis_to_bram_trig`](axis_to_bram_trig/) | Data writter from AXI-Stream to BRAM memory using a trigger | yes |
| [`bram_to_axis`](bram_to_axis/) | BRAM to AXI-Stream bridge using a SYNC FIFO as pipe | yes |
| [`bram_to_axis_nt`](bram_to_axis_nt/) | BRAM to AXI-Stream bridge using a SYNC FIFO as pipe | yes |
| [`qproc_axi_reg`](qproc_axi_reg/) | qproc_axi_reg (axi library core) | yes |

13 cores. The list is checked by `make doc-check`: a core added here must be added to this table.
