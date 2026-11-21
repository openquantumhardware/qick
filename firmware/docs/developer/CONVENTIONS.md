# Conventions: RTL, naming, headers and license

The rules for RTL and cores in `rtl_lib/` and `fusesoc/cores/`. Setup and daily commands are in the
[environment README](../../fusesoc/README.md); how to create a core is in [NEW_CORE.md](NEW_CORE.md).

---


- **Clock/reset port names are fixed** for multi-clock cores: AXI-Lite uses
  `s_axi_aclk`/`s_axi_aresetn` (interface `s_axi`); the AXI-Stream datapath uses
  `aclk`/`aresetn` (all `*_axis`). Internal CDC/pipeline clocks are not exposed.
  See "Port naming conventions for AXI auto-inference" in [PACKAGING.md](PACKAGING.md). This is what makes
  `make package` produce correct `ASSOCIATED_BUSIF` for two clock domains.
- **rtl_lib/ is the source of truth** for all RTL; cores symlink into it.
- **Ports and signals are lowercase** (linter requirement), e.g. `a_i`, `z_o`.
- **Module naming**: processor-specific blocks use a `tpv2_*` / `tpv1_*` prefix;
  generic reusable blocks have no prefix (e.g. `lfsr`, `sync_nxm`).
- **Constants / opcodes live in packages** (`cores/pkg/*`, `rtl_lib/pkg/*`),
  e.g. `alu_pkg`, `tproc_pkg`.
- **Test directory is `tests/`** (plural) for BOTH library cores and packaged
  IPs, with `<core>_tc00.sv` (top) and `<core>_tests.sv` (included cases).
- **VLNV pattern**: `qick:<category>:<core>:<version>` for library cores,
  `qick:ip:<name>:<version>` for packaged IPs.
- PeakRDL-generated files (`*_regmap_pkg/`, generated `.sv`, `docs/`) are
  **never committed**.
- IPs that instantiate Xilinx primitives (DSP, XPM, DDS, FIR) require Vivado/xsim
  and cannot be linted/simulated with Verilator alone.
- **When a real RTL bug is found, fix it in `rtl_lib/`** (not in the testbench)
  and document it in the module header. Example: the SG-v6 amplitude fix
  ([31:16] -> [30:15] quantization + ±MAXV saturation) is documented in the
  `axis_signal_gen_v6` / `sgv6` headers.
- **A single driver can serve several IP versions** via multiple `bindto`
  strings. Example: `AxisSignalGen` binds v4/v5/v6. When you change the RTL of
  one, check the shared driver against the others.
- **Source file header and license.** Every SystemVerilog file in `rtl_lib/` starts with this block (`Package` or `Interface`
  instead of `Module` for those); new files copy it. 179 of the 216 existing files have it, the others predate it and should get
  it when they are next edited.

  ```systemverilog
  ///////////////////////////////////////////////////////////////////////////////
  // Fermi National Accelerator Laboratory
  // Module : <name>
  // Project: QICK
  ///////////////////////////////////////////////////////////////////////////////
  //! @file    <name>.sv
  //!
  //! @brief   One line.
  //!
  //! @details
  //!
  //! What it does, rules that are not obvious, known limits.
  //!
  //! @author  QICK Development Team
  //!
  //! @version 1.0
  ```

  No license text goes in the files: the repository's `LICENSE` applies (MIT, Copyright (c) Open Quantum Hardware). Decided on
  2026-10-12.
