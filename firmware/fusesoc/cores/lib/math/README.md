# Library cores: math

ALUs and other math blocks.

Each core is its own FuseSoC core (`qick:math:<name>:<version>`, the version is in the `name:` of its `.core` file); the RTL is in `firmware/rtl_lib/` and `hdl/` links to it.
Simulate one with `make sim IP=<name>`, lint it with `make lint IP=<name>`. How to create a core: [NEW_CORE.md](../../../../docs/developer/NEW_CORE.md).

| Core | What it is | Tests |
|---|---|---|
| [`alu`](alu/) | ALU arithmetic unit for TPROC v1 | yes |
| [`alu_arith_unit`](alu_arith_unit/) | ALU arithmetic unit for TPROC v1 | yes |
| [`alu_bitwise_unit`](alu_bitwise_unit/) | ALU arithmetic unit for TPROC v1 | yes |
| [`avg`](avg/) | Averager block | yes |
| [`avg_buffer`](avg_buffer/) | avg_buffer (math library core) | yes |
| [`avg_top`](avg_top/) | Top module for the averager (avg) block | yes |
| [`buffer`](buffer/) | buffer (math library core) | yes |
| [`buffer_top`](buffer_top/) | Top module for the buffer (raw capture) block | yes |
| [`restoring_divider`](restoring_divider/) | restoring_divider (math library core) | yes |
| [`signed_comparator`](signed_comparator/) | Signed comparator unit for the tProcv1 | yes |
| [`tpv2_alu`](tpv2_alu/) | tpv2_alu arithmetic unit for TPROC v1 | yes |
| [`tpv2_arith`](tpv2_arith/) | tpv2_arith (math library core) | yes |
| [`weighted_buffer`](weighted_buffer/) | weighted_buffer (math library core) | yes |

13 cores. The list is checked by `make doc-check`: a core added here must be added to this table.
