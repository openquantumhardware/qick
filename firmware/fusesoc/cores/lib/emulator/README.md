# Library cores: emulator

The QICK emulator (`emulator/` at the repository root): the system that Verilator simulates, built from the cores of the ported IPs.

Each core is its own FuseSoC core (`qick:emulator:<name>:<version>`, the version is in the `name:` of its `.core` file); the RTL is in `firmware/rtl_lib/emulator/` and `hdl/` links to it.
They are for Verilator only (the models keep the names of the vendor blocks they replace, so they must not be compiled together with those). How to create a core: [NEW_CORE.md](../../../../docs/developer/NEW_CORE.md).

Build and run: `cd emulator/testbench && make test_sim` (it asks fusesoc for `qick:emulator:qickemu_harness`). The programs run through it and their results: [`emulator/regression/README.md`](../../../../../emulator/regression/README.md).

The four models are checked clock by clock against the real block in xsim with scripts (`tests/vendor/run_vendor_check.sh` in each core; they need Vivado), with mutations of the model that the check catches.

| Core | What it is | Tests |
|---|---|---|
| [`axi_router_lite`](axi_router_lite/) | AXI4-Lite router of the emulator: one master, the address picks the slave (from the HRL emulator) | no |
| [`model_dac_adc`](model_dac_adc/) | `model_DAC` and `model_ADC`: the RF data converters in loopback, optional ADC noise from a fixed seed (from the HRL emulator) | no |
| [`qick_dut`](qick_dut/) | Device under test: tProc v2, signal generators and multiplexer, three readouts (PFB v4 with 4 of 8 outputs), four averaging buffers, the multi-rate buffer datapath (`qick:mem:mr_buffer`, armed from reset, started by the tProc trigger 8), behind one AXI-Lite master | regression (`emulator/regression/`) |
| [`qickemu_harness`](qickemu_harness/) | Verilator testbench `QICKEmu_harness` (clocks, converters, replay of what `qick_emu.py` records, CSV output; the DAC -> ADC transport delay is the parameter `RF_DELAY_TIME_NS`, 110 ns (it reproduces a ZCU216 loopback; HRL had 100), `make verilate EXTRA_VERILATOR_FLAGS=-GRF_DELAY_TIME_NS=100` for the HRL value); target `verilate` | regression |
| [`ssr_8x64`](ssr_8x64/) | Model of the System Generator FFT of the PFB readouts (64 points, 8 per clock); not bit-exact, within 20 counts | vs the real core (vendor) |
| [`xpm_fifo_async`](xpm_fifo_async/) | Model of the XPM macro `xpm_fifo_async` (fwft), same names and latencies | vs the real macro (vendor) |
| [`xpm_fifo_sync`](xpm_fifo_sync/) | Model of the XPM macro `xpm_fifo_sync` (fwft) | vs the real macro (vendor) |
| [`xpm_memory_tdpram`](xpm_memory_tdpram/) | Model of the XPM macro `xpm_memory_tdpram` | vs the real macro (vendor) |

8 cores. The list is checked by `make doc-check`: a core added here must be added to this table.
