# Library cores: interfaces

SystemVerilog interfaces (AXI, BRAM, and similar).

Each core is its own FuseSoC core (`qick:interfaces:<name>:<version>`, the version is in the `name:` of its `.core` file); the RTL is in `firmware/rtl_lib/` and `hdl/` links to it.
Simulate one with `make sim IP=<name>`, lint it with `make lint IP=<name>`. How to create a core: [NEW_CORE.md](../../../../docs/developer/NEW_CORE.md).

| Core | What it is | Tests |
|---|---|---|
| [`axi4_lite_if`](axi4_lite_if/) | AXI4 Lite interface definition (includes master & slave modports) | no |
| [`axi4_stream_if`](axi4_stream_if/) | AXI4-Stream interface definition (includes master & slave modports and assertions for simulations) | no |
| [`bram_if`](bram_if/) | BRAM memory interface | yes |

3 cores. The list is checked by `make doc-check`: a core added here must be added to this table.
