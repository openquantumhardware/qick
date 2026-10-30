# Library cores: ctrl

Control-plane blocks (streamer, ramp and DDS control, and similar).

Each core is its own FuseSoC core (`qick:ctrl:<name>:<version>`, the version is in the `name:` of its `.core` file); the RTL is in `firmware/rtl_lib/` and `hdl/` links to it.
Simulate one with `make sim IP=<name>`, lint it with `make lint IP=<name>`. How to create a core: [NEW_CORE.md](../../../../docs/developer/NEW_CORE.md).

| Core | What it is | Tests |
|---|---|---|
| [`ctrl_dyn_ro`](ctrl_dyn_ro/) | ctrl_dyn_ro (ctrl library core) | yes |
| [`ctrl_ro_v2`](ctrl_ro_v2/) | ctrl_ro_v2 (ctrl library core) | yes |
| [`ctrl_sgmux8`](ctrl_sgmux8/) | ctrl_sgmux8 (ctrl library core) | yes |
| [`ctrl_sgv4`](ctrl_sgv4/) | ctrl_sgv4 (dsp library core) | yes |
| [`ctrl_sgv6`](ctrl_sgv6/) | ctrl_sgv6 (dsp library core) | yes |
| [`dds_chirp`](dds_chirp/) | DDS with linear frequency modulation (chirp): dds_phase_ctrl + DDS IP (streaming pinc) | yes |
| [`dds_phase_ctrl`](dds_phase_ctrl/) | dds_phase_ctrl (ctrl library core) | yes |
| [`kidsim`](kidsim/) | KID simulator datapath: demod (cmult) -> IIR resonator -> remod (cmult), with chirped DDS | yes |
| [`kidsim_top`](kidsim_top/) | One-lane KID simulator: puncturing + kidsim datapath + latency-matched bypass mux | yes |
| [`phase_ctrl_sgmux8`](phase_ctrl_sgmux8/) | phase_ctrl_sgmux8 (ctrl library core) | yes |
| [`punct`](punct/) | Puncturing / per-frame sample selector: asserts enable on the sample at index ID_REG | yes |
| [`ramp_gen`](ramp_gen/) | ramp_gen (ctrl library core) | yes |
| [`streamer`](streamer/) | Stream buffer with one-shot/continuous modes | yes |

13 cores. The list is checked by `make doc-check`: a core added here must be added to this table.
