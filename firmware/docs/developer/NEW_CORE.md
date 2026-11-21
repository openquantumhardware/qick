This guide explains how to create new FuseSoC cores in the QICK environment.
There are two kinds:

1. **Library cores** — reusable building blocks (ALU, FIFO, sync, LFSR, ...).
   Created with `scripts/new_lib_core.sh`. RTL lives in `rtl_lib/<category>/`.
2. **Packaged IPs** — top-level IPs with a register map and Python driver.
   Created with `make new-ip` (PeakRDL flow). See firmware/docs/developer/DRIVER.md.

---

## 1. Library cores (`scripts/new_lib_core.sh`)

### What it does

Creates `cores/lib/<category>/<core>/` with:

```
<core>/
├── <core>.core                  ← FuseSoC description (anchors-based)
├── data/
├── hdl/
│   └── <core>.sv -> (relative symlink to rtl_lib/<category>/<core>.sv)
├── lint/
└── tests/
    ├── <core>_tc00.sv           ← SVUnit testbench top (stub)
    └── <core>_tests.sv          ← SVUnit test cases (stub)
```

The symlink's relative path is computed automatically (no manual `../../..`
counting), and every file is named consistently with `<core>`.

### Usage

```bash
cd firmware/fusesoc
./scripts/new_lib_core.sh <category> <core_name> [pkg_depend]
```

- `<category>` : one of `utils | math | cdc | mem | axi | dsp | interfaces | processors`
- `<core_name>`: the module name (must match the file in `rtl_lib/<category>/`)
- `[pkg_depend]` (optional): a package the RTL needs, e.g. `qick:pkg:alu_pkg`

### Examples

```bash
# Generic utility (no package dependency)
./scripts/new_lib_core.sh utils lfsr

# Math block that imports alu_pkg
./scripts/new_lib_core.sh math tpv2_alu qick:pkg:alu_pkg

# Control unit that imports tproc_pkg
./scripts/new_lib_core.sh utils tpv1_ctrl qick:pkg:tproc_pkg

# CDC synchronizer
./scripts/new_lib_core.sh cdc sync_nxm
```

### Prerequisites

The RTL must already exist at `rtl_lib/<category>/<core>.sv`. If it does not, the
script still creates the core and a (dangling) symlink, and warns you — add the
RTL afterward.

### After running

1. Edit `tests/<core>_tc00.sv` and `tests/<core>_tests.sv` with real tests
   (the script writes a `tc_smoke` placeholder).
2. Run the test target:
   ```bash
   make sim IP=<core>            # single core, direct
   # or
   make sim_svunit IP=<core>     # same run, JUnit report in report_svunit/
   ```
3. Lint:
   ```bash
   make lint IP=<core>
   ```

### Generated .core

The `.core` uses YAML anchors and includes `default`, `lint`, and `test`
targets:

```yaml
CAPI=2:
name: qick:<category>:<core>:1.0.0
description: <core> (<category> library core).
filesets:
  hdl:
    files:
      - hdl/<core>.sv
    file_type: systemVerilogSource
    depend:
      - <pkg_depend>            # only if provided
  tb:
    files:
      - tests/<core>_tc00.sv
      - tests/<core>_tests.sv: {is_include_file: true}
    file_type: systemVerilogSource
    depend:
      - qick:common:sim_base
  lint_files:
    depend:
      - qick:common:lint
generate:
  testrunner_gen:
    generator: svunit_gen
    parameters:
        test_files:
          - tests/<core>_tc00.sv
targets:
  default: &default
    filesets: [hdl]
    toplevel: <core>
  lint:
    <<: *default
    filesets_append: [lint_files]
    default_tool: veriblelint
    toplevel: <core>
    tools:
      verilator:
        mode: lint-only
        verilator_options: [-Wall]
  test:
    <<: *default
    description: Simulate the design
    filesets_append: [tb]
    default_tool: xsim
    generate: [testrunner_gen]
    toplevel: testrunner
    tools:
      xsim:
        xelab_options: [-timescale=1ns/1ns -debug all -L XPM]
        xsim_options: [-testplusarg SVUNIT_FILTER="*" -onerror stop]
```

---

## 2. SVUnit testbench template

Both stubs follow the SVUnit pattern used across the repo. A typical top:

```systemverilog
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module <core>_unit_test;
    import svunit_pkg::svunit_testcase;
    // import <pkg>::*;   // if the DUT needs a package

    string name = "<core>_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    // DUT signals ...
    // DUT instance: <core> dut ( ... );

    function void build(); svunit_ut = new(name); endfunction
    task setup();    svunit_ut.setup();    endtask
    task teardown(); svunit_ut.teardown(); endtask

    `SVUNIT_TESTS_BEGIN
    `include "<core>_tests.sv"
    `SVUNIT_TESTS_END
endmodule
```

### Verification guidelines (lessons learned)

- For combinational blocks, drive inputs and settle with `#1` before checking;
  use `clk_gen` only to sequence assertions.
- For memories, model them faithfully (synchronous, registered, write-first if
  the real BRAM is like `bram_tdp`); idealized combinational models hide
  read-latency bugs.
- For AXIS producers/consumers, advance counters only on accepted beats
  (`tvalid && tready`), not on `tvalid` alone.
- Do not sample combinational outputs of single-cycle FSM states right after a
  `wait_state`; use a concurrent `fork` monitor or settle one cycle.
- Synchronize multi-step / multi-transaction tests on real state
  (`ready`, `busy`, `tready`) rather than fixed `repeat` delays.
- **Use indexed part-selects (`[base +: WIDTH]`) with a variable base**, not
  `[msb:lsb]` with loop-variable bounds — xsim rejects the latter as
  "range index value is not constant".
- When a real RTL bug is found, fix it in `rtl_lib/` (not in the testbench) and
  document it in the module header. Case study: the SG-v6 amplitude fix — the
  testbench exposed that `env=MAXV, cos=full, gain=MAXV` produced `0x3FFD`
  (≈MAXV/2); the fix ([31:16] -> [30:15] + ±MAXV saturation) went into
  `rtl_lib/dsp/sgv6.sv`, not the TB.

---

## 3. Packaged IPs (`make new-ip`)

For top-level IPs that expose an AXI register map and a Python driver, use the
PeakRDL flow:

```bash
make new-ip IP=my_new_ip
```

This creates `cores/ip/my_new_ip/` with `rdl/`, `driver/`, `hdl/`, and `tests/`, plus a `README.md` copied
from [IP_README_TEMPLATE.md](IP_README_TEMPLATE.md) (see section 6: every IP documents itself for its users).
Then:

1. Edit `cores/ip/my_new_ip/rdl/my_new_ip_regmap.rdl` (the register map).
2. Write/adjust the RTL in `rtl_lib/ip/my_new_ip.sv` and the symlink.
3. Generate the driver/register layer (also runs the register tests):
   ```bash
   make driver IP=my_new_ip
   ```
4. Run only the register-layer tests (no regeneration):
   ```bash
   make driver-test IP=my_new_ip
   ```
5. Run the RTL testbench:
   ```bash
   make sim_svunit IP=my_new_ip
   ```
6. Generate docs:
   ```bash
   make rdl-docs IP=my_new_ip
   ```

See **firmware/docs/developer/DRIVER.md** for the full PeakRDL workflow, register access API, the
register-layer pytest tests, and the two RTL strategies (generated regblock vs
custom AXI slave).

> Note: `make new-ip` historically had two bugs in its Makefile template
> (duplicated `RDL_FILE` line and a double `dirname` in `IP_NAME`). These are
> fixed; if you create an IP and `make driver` complains about `_regmap.rdl` or
> `ip_regmap.rdl`, check `scripts/create_ip.sh` against firmware/docs/developer/DRIVER.md.

> Packaged IPs also use the `tests/` directory (plural), consistent with library
> cores — `tests/<ip>_tc00.sv` (top) and `tests/<ip>_tests.sv` (included).

---

## 4. Quick checklist for a new library core

```
1. Write/place RTL          ->  rtl_lib/<category>/<core>.sv  (lowercase ports)
2. Create the core          ->  ./scripts/new_lib_core.sh <category> <core> [pkg]
3. Write the testbench      ->  edit tests/<core>_tc00.sv + tests/<core>_tests.sv
4. Simulate                 ->  make sim IP=<core>   (or make sim_svunit IP=<core>)
5. Lint                     ->  make lint IP=<core>
6. Coverage                 ->  make coverage IP=<core>   (see firmware/docs/developer/COVERAGE.md)
7. Fix RTL bugs in rtl_lib/ ->  document them in the module header
8. Re-run until green
```

Step 6 is where latent datapath bugs surface. Two ways that happens:

- **Toggle coverage shows low percentages on a DUT whose logic is never
  reached.** A bit that never toggles is a path the tests never exercised.
- **A test can pass under `make sim` and fail under `make coverage`.** That was
  a real datapath bug in `rtl_lib/math/buffer.sv`, not a tooling artifact — see
  [COVERAGE.md](COVERAGE.md#coverage-found-a-real-datapath-bug).

If the new core instantiates `axi4_stream_if`, add `-d SVUNIT` to the
`xelab_options` above. That switches on the interface's protocol checkers, so a
`tvalid`/`tdata` violation is caught by the testbench rather than by review. If
a core was already green, a new failure after adding the define is a finding to
investigate, not a regression to revert.

## 5. Quick checklist for a new packaged IP

```
1. Scaffold                 ->  make new-ip IP=<name>
2. Define registers         ->  edit rdl/<name>_regmap.rdl  (source of truth)
3. Choose RTL strategy      ->  regblock (--hdl) OR custom AXI slave (drop --hdl)
4. Write RTL + symlink      ->  rtl_lib/ip/<name>.sv
5. Generate driver + tests  ->  make driver IP=<name>
6. RTL verification         ->  make sim_svunit IP=<name>
7. Coverage                 ->  make coverage IP=<name>   (see firmware/docs/developer/COVERAGE.md)
8. Docs                     ->  make rdl-docs IP=<name>
9. Package                  ->  make package IP=<name>
10. Document                 ->  README.md (Part I for users), see section 6
11. Driver + board          ->  firmware/docs/user/IP_INTEGRATION.md: one class per VLNV (make driver-bindings),
                                behaviour pytest, debug bench + notebook through QickSoc, board run recorded
```

A port is done only when it meets D1-D6 of [IP_INTEGRATION.md](../user/IP_INTEGRATION.md) §2.

---

## 6. Documenting an IP

**Every packaged IP has a `README.md` in `cores/ip/<ip>/`, written for the person who uses the IP**, not for the
person who wrote it. `make new-ip` creates it from [IP_README_TEMPLATE.md](IP_README_TEMPLATE.md), which lists
what has to be in it. Part I explains the IP the way a user meets it: what it does, the rules it follows that are
not obvious from the port names (state machines, thresholds, registers with special semantics, what happens at
the limits, units), the data formats with a working decoding function, a Python quick start, what to set in the
block design (which clock each port needs), a table of gotchas, and the validation status (what was measured on
hardware and what was not). Part II is the reference: ports, registers, verification, files.

Where each kind of information goes:

| Where | What belongs there |
|---|---|
| `cores/ip/<ip>/README.md` | how the IP behaves and how to use it (the single place for this) |
| driver docstrings | what each method does (the API), with the one-line rule that matters |
| `rdl/<ip>_regmap.rdl` descriptions | register and field semantics: keep them true (an RDL that called an edge-triggered bit a "self-clearing pulse" cost a bring-up day) |
| `Top/<board>/<project>/README.md` | the bring-up log of that project: what was built, tried and fixed. It links to the IP README and does not re-explain the IP |
| notebook markdown | what that test shows and how to read its output; link to the IP README for the behaviour |

When something is learned on hardware (a rule, a limit, a unit), update the IP README's rules (U2), gotchas (U7) and
validation status (U8) in the same change; do not leave it in the log.

Status (2026-09-21): `axis_signal_gen_v6`, `mr_buffer_et`, `qick_time_tagger` and `axis_constant_iq` have such a
README. The other packaged IPs under `cores/ip/` do not yet; add one the first time an IP is touched or used on a
board.
