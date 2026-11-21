# Library cores: utils

Utility modules (FIFOs, buffers, command handlers).

Each core is its own FuseSoC core (`qick:utils:<name>:<version>`, the version is in the `name:` of its `.core` file); the RTL is in `firmware/rtl_lib/` and `hdl/` links to it.
Simulate one with `make sim IP=<name>`, lint it with `make lint IP=<name>`. How to create a core: [NEW_CORE.md](../../../../docs/developer/NEW_CORE.md).

| Core | What it is | Tests |
|---|---|---|
| [`delay_line`](delay_line/) | delay_line (utils library core) | yes |
| [`diff_in_nb`](diff_in_nb/) | Differential input buffer | yes |
| [`diff_out_nb`](diff_out_nb/) | Differential output buffer | yes |
| [`lfsr`](lfsr/) | lfsr (utils library core) | yes |
| [`qcore_ctrl_hazard`](qcore_ctrl_hazard/) | qcore_ctrl_hazard (utils library core) | yes |
| [`qproc_ctrl`](qproc_ctrl/) | qproc_ctrl (utils library core) | yes |
| [`qproc_dispatcher`](qproc_dispatcher/) | qproc_dispatcher (utils library core) | yes |
| [`qproc_inport_reg`](qproc_inport_reg/) | qproc_inport_reg (utils library core) | yes |
| [`qproc_time_ctrl`](qproc_time_ctrl/) | qproc_time_ctrl (utils library core) | yes |
| [`req_ack_cmd`](req_ack_cmd/) | Board communication peripheral | yes |
| [`rising_edge_det`](rising_edge_det/) | Rising edge detection circuit | yes |
| [`rx_cmd`](rx_cmd/) | Board communication peripheral. Wrapper and synchronization logic for the xcom_link_rx block | yes |
| [`tpv1_ctrl`](tpv1_ctrl/) | Control Unit for the QICK tProcv1 porcessor | yes |
| [`tpv1_timed_dispatch`](tpv1_timed_dispatch/) | Timed instruction dispatcher control for the QICK tProcv1 porcessor | yes |
| [`tx_cmd`](tx_cmd/) | Board communication peripheral | yes |
| [`wide_en_signal`](wide_en_signal/) | Enable pulse generator for a wide enable signal | yes |
| [`xcom_cmd`](xcom_cmd/) | Command synchronizer for the XCOM core. Receives commands from tproc and Python | yes |
| [`xcom_cmd_hold`](xcom_cmd_hold/) | xcom_cmd_hold (utils library core) | yes |
| [`xcom_link_rx`](xcom_link_rx/) | Board communication peripheral | yes |
| [`xcom_link_tx`](xcom_link_tx/) | Board communication peripheral | yes |
| [`xcom_qctrl`](xcom_qctrl/) | Control block to instruct the tproc to start/stop internal processing | yes |
| [`xcom_txrx`](xcom_txrx/) | Board communication peripheral | yes |
| [`zn_nb`](zn_nb/) | Simple buffer for interface management | yes |

24 cores. The list is checked by `make doc-check`: a core added here must be added to this table.
