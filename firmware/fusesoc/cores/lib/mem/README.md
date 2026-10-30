# Library cores: mem

Memories, FIFOs and register files.

Each core is its own FuseSoC core (`qick:mem:<name>:<version>`, the version is in the `name:` of its `.core` file); the RTL is in `firmware/rtl_lib/` and `hdl/` links to it.
Simulate one with `make sim IP=<name>`, lint it with `make lint IP=<name>`. How to create a core: [NEW_CORE.md](../../../../docs/developer/NEW_CORE.md).

| Core | What it is | Tests |
|---|---|---|
| [`bram_simple_dp`](bram_simple_dp/) | bram_simple_dp (mem library core) | yes |
| [`bram_simple_sp`](bram_simple_sp/) | Simple single-port, one clock, read-first block RAM | yes |
| [`bram_tdp`](bram_tdp/) | True Dual-clock dual-port BRAM | yes |
| [`bram_tdp_banked`](bram_tdp_banked/) | bram_tdp_banked (mem library core) | yes |
| [`dma_fifo_rd`](dma_fifo_rd/) | dma_fifo_rd (mem library core) | yes |
| [`dmem`](dmem/) | dmem data writer/reader core for the TPROC v1 | yes |
| [`dmem_axis_reader`](dmem_axis_reader/) | Stack core for the TPROC v1 | yes |
| [`dmem_axis_writer`](dmem_axis_writer/) | AXI4-Stream writer for the dmem core of the TPROC v1 | yes |
| [`dmem_ctrl`](dmem_ctrl/) | Stack core for the TPROC v1 | yes |
| [`dmem_single_rw`](dmem_single_rw/) | Single read/write module for the dmem module of TPROC v1 | yes |
| [`fifo`](fifo/) | FIFO implementation | yes |
| [`fifo_async`](fifo_async/) | Asynchronous (dual-clock) FIFO wrapper around XPM_FIFO_ASYNC | yes |
| [`fifo_async_gated`](fifo_async_gated/) | fifo_async_gated (mem library core) | yes |
| [`fifo_axi`](fifo_axi/) | FIFO with the legacy rd2axi read adapter (valid/ready-style read side) | yes |
| [`fifo_sync`](fifo_sync/) | FIFO implementation | yes |
| [`gray2bin`](gray2bin/) | Binary to Gray code converter | yes |
| [`mr_buffer`](mr_buffer/) | Multi-Rate (MR) Buffer with External Trigger (ET) | yes |
| [`qcore_mem`](qcore_mem/) | qcore_mem (mem library core) | yes |
| [`qcore_reg_bank`](qcore_reg_bank/) | qcore_reg_bank (mem library core) | yes |
| [`qproc_mem_ctrl`](qproc_mem_ctrl/) | qproc_mem_ctrl (mem library core) | yes |
| [`regfile_8p`](regfile_8p/) | Simple single-port, one clock, read-first block RAM | yes |
| [`smp_fifo_dc`](smp_fifo_dc/) | smp_fifo_dc (mem library core) | yes |
| [`smp_mem`](smp_mem/) | smp_mem (mem library core) | yes |
| [`tag_fifo_dc`](tag_fifo_dc/) | tag_fifo_dc (mem library core) | yes |
| [`tag_fifo_tc`](tag_fifo_tc/) | tag_fifo_tc (mem library core) | yes |
| [`tag_mem`](tag_mem/) | tag_mem (mem library core) | yes |
| [`tpv1_stack`](tpv1_stack/) | Stack core for the TPROC v1 | yes |
| [`tpv2_stack`](tpv2_stack/) | tpv2_stack (mem library core) | yes |

27 cores. The list is checked by `make doc-check`: a core added here must be added to this table.
