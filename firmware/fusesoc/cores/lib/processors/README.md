# Library cores: processors

tProcessor cores.

Each core is its own FuseSoC core (`qick:processors:<name>:<version>`, the version is in the `name:` of its `.core` file); the RTL is in `firmware/rtl_lib/` and `hdl/` links to it.
Simulate one with `make sim IP=<name>`, lint it with `make lint IP=<name>`. How to create a core: [NEW_CORE.md](../../../../docs/developer/NEW_CORE.md).

| Core | What it is | Tests |
|---|---|---|
| [`qcore_cpu`](qcore_cpu/) | qcore_cpu (processors library core) | yes |
| [`qproc_core`](qproc_core/) | qproc_core (processors library core) | yes |
| [`qtt_cmd`](qtt_cmd/) | qtt_cmd (processors library core) | yes |
| [`qtt_cmd_hold`](qtt_cmd_hold/) | qtt_cmd_hold (processors library core) | yes |
| [`tprocv1`](tprocv1/) | Timed instruction dispatcher control for the QICK tProcv1 porcessor | yes |
| [`tprocv2`](tprocv2/) | tprocv2 (tProcessor v2 core) | yes |

6 cores. The list is checked by `make doc-check`: a core added here must be added to this table.
