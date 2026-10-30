# Makefile Reference

Complete reference for the `firmware/fusesoc/Makefile`. Every target, the
variables it consumes, and the gotchas learned in practice.

All targets are run from `firmware/fusesoc/`. Most activate the shared `../../.venv/` internally,
but for interactive work do `source ../../.venv/bin/activate` first.

## Variables

| Variable | Default | Used by | Meaning |
|----------|---------|---------|---------|
| `IP`      | (none)  | most targets | Core / IP short name, e.g. `axis_signal_gen_v6`. Required by sim/lint/driver/package. |
| `CORE`    | (none)  | `core-info` | Full VLNV, e.g. `qick:ip:axis_signal_gen_v6`. |
| `TOOL`    | (unset) | `lint` | EDA tool for `make lint`, only when given on the command line or in the environment: `TOOL=verilator`. Unset, the core's default tool runs (Verible for `lint`, xsim for `sim`). |
| `VERSION` | `1.0`   | `package` | IP version for packaging. |
| `PART`    | `xczu49dr-ffvf1760-2-e` | `package` | Target FPGA part. |
| `DESCRIPTION` / `DISPLAY_NAME` | (opt) | `package` | IP metadata. |

`FUSESOC_CORES` adds three roots: `--cores-root cores`, `common` and `generators` (there used to be a fourth, `projects`, which does not exist and made FuseSoC print `Failed to register library 'projects is not a directory'`).

---

## Environment

### `make setup_environment`
One-time setup: submodules, the shared venv (`build_virtualenv.sh`), the FuseSoC
env (`build_fusesocenv.sh`), the repository's Verilator (`make install_verilator`),
ossschem (`make install_ossschem`), source symlinks, and a Verilator check
(`build_verilator.sh`).

Verilator is **required for `make coverage`** (the default backend), `make lint
TOOL=verilator`, `make block-diagram`, `make schematic` and the QICKEmu emulator.
Vivado does not bundle it, so `which vivado` says nothing about whether Verilator
is present. The Verilator and ossschem steps are non-fatal on purpose: simulation
under xsim needs neither, and a machine without the C++ build tools must still get
the venv, libraries and symlinks. `make coverage` / `make schematic` refuse with an
explicit message if what they need is absent or too old.

`build_fusesocenv.sh` registers SVUnit from `lharnaldi/svunit` (a fork of
`ivanvig/svunit`, which adds the FuseSoC core and generator, with fixes for
Verilator 5.046 and newer). A checkout set up before (on `ivanvig/svunit`) is moved
to it the next time `setup_environment` runs.

### `make install_verilator`
Builds `VERILATOR_VERSION` (5.052, set at the top of the Makefile) from source into
`~/.local/verilator-<version>` without root, and links `~/.local/verilator` to it.
A few minutes the first time; nothing to do once installed. When it is there,
every target of this Makefile (and of `emulator/testbench/Makefile`) puts it first
on `PATH`, ahead of any other Verilator of the machine, so every flow uses the same
release. Environment of the script: `VERILATOR_VERSION`, `VERILATOR_PREFIX`,
`JOBS`. `build_verilator.sh` and `scripts/cov/cov_run.py` check the version found.

| Verilator | Status |
|---|---|
| 5.052 | the repository's version: coverage, lint, block-diagram, schematic, QICKEmu validated against 5.042 |
| 5.046 to 5.050 | not validated. 5.046 to 5.052 share bugs that the SVUnit fork works around (toggle coverage, scheduling after `disable fork`, and from 5.048 SVUnit's `report()` does not compile) |
| 5.042 | the previous version; ossschem needs 5.046 or newer |
| 5.020 | verified broken — cannot parse SVUnit's sources, fails with a syntax error inside `svunit_base` |

To move to another release: change `VERILATOR_VERSION`, run `make install_verilator`,
and repeat the checks of the last update (coverage-all against the previous
release, the xsim suite, `make lint TOOL=verilator`, the QICKEmu regression).

### `make install_ossschem`
Downloads ossschem `OSSSCHEM_VERSION` (0.7.0, linux-x64), checks it against
`OSSSCHEM_SHA256`, installs it into `~/.local/ossschem-<version>` (`~/.local/ossschem`
points at it), and installs the VS Code extension `markusdd.ossschem@<version>` when
`code` is on `PATH`. Nothing to do once installed. Used by `make schematic`.

---

## Simulation & test

### `make sim IP=<core>`
Runs the FuseSoC `test` target directly (SVUnit via xsim) for a single core.
Fast path for one core. Example: `make sim IP=lfsr`.

**Waveforms.** The saved signal layouts are `cores/**/data/*.gtkw`. Open one with the dump the simulation wrote, from the repository root (the translate-filter files, `data/states.txt` and `data/opcodes.txt`, are referenced relative to it): `gtkwave firmware/fusesoc/build/<core>/test-xsim/<name>.vcd firmware/fusesoc/cores/<...>/data/<name>.gtkw`.

### `make sim_svunit [IP=<core>]`   ← multi-core / CI
`make sim` on every core whose `.core` has a `test` target (found by grepping
`cores/`), or only on `IP=` (bare name, VLNV, or VLNV with version). For each
core, `report_svunit/<vlnv>.log` gets the run's output and
`report_svunit/<vlnv>.xml` the SVUnit JUnit report (`tests.xml`, one entry per
test); a testbench that does not build gets a JUnit file with one failure. A core
passes when SVUnit prints `[testrunner]: PASSED`, since xsim exits 0 also when
tests fail. The target fails if any core failed and prints `N of M cores
passed`. CI (`.github/workflows/sim_svunit.yml`) publishes `report_svunit/*.xml`.

### `make lint IP=<core> [TOOL=verilator]`
Runs the FuseSoC `lint` target of the core.

| Command | Tool | What it checks |
|---|---|---|
| `make lint IP=<core>` | Verible (the core's default) | style and naming rules shared by every core; waivers in `lint/verible_waiver.vbw` |
| `make lint IP=<core> TOOL=verilator` | Verilator, `lint-only`, `-Wall` | widths, unused signals, latches, missing modules |

NOTE: IPs instantiating Xilinx primitives (DSP/XPM/DDS) cannot be linted by Verilator alone: it stops with
`MODMISSING` for `xpm_*` (e.g. `axis_avg_buffer`: 3 errors, 42 warnings). Cores of the library without primitives lint clean.
Without `make`: `fusesoc --cores-root cores --cores-root common --cores-root generators run --target lint --tool verilator qick:ip:<core>`.

---

## Code coverage

See [COVERAGE.md](COVERAGE.md) for the flow, the toolchain and the known
limitations. Summary:

### `make coverage IP=<core>`
Re-runs the core's SVUnit testbenches under an instrumented simulator and reports
DUT coverage. Two backends: **Verilator** (default) compiles the SVUnit
`testrunner` to a native binary and measures line + toggle; **xsim**
(`COV_BACKEND=xsim`) re-elaborates with `--cc_type` for statement/branch/
condition coverage. Writes annotated source under `report_cov/<core>/html/`
plus a machine-readable `report_cov/<core>/summary.json`.

```sh
make coverage IP=cdc_handshake
make coverage IP=cdc_handshake COV_MIN=80                   # gate on toggle
make coverage IP=xcom COV_DEFINE=SVUNIT                     # enable interface SVA
make coverage IP=fifo_async COV_BACKEND=xsim COV=sb         # statement coverage
make coverage IP=fifo_async CONFIGS="--TB_N=64 --TB_B=24|--TB_N=256 --FWFT=1"
```

| Variable | Default | Meaning |
|---|---|---|
| `COV_BACKEND` | `verilator` | `verilator` or `xsim`. Verilator runs the SVUnit suite natively and reaches purely combinational RTL, which xsim reports as 0 statements. Cores using XPM/DSP primitives need `xsim`. |
| `COV_DEFINE` | *(unset)* | Verilog defines for the Verilator run, e.g. `COV_DEFINE=SVUNIT`. |
| `COV` | `sbct` | `xsim` only: `xelab --cc_type`, any of `s`,`b`,`c`,`t`. `t` (toggle) is what finds dead branches in the FSMs but costs the most elaboration time and memory. |
| `COV_OUT` | `report_cov` | Report root. |
| `COV_MIN` | *(unset)* | Fail the run if the backend's primary metric is below this percentage (toggle for Verilator, line for xsim). Exits 1. |
| `CONFIGS` | *(unset)* | Pipe-separated sim configurations, all merged into one report. |
| `COV_FILTER` | *(unset)* | `coverage-all` only: regex on the VLNV to narrow the sweep. |
| `COV_TIMEOUT` | `1800` | Per-run wall-clock limit (s) for elaborate + simulate. |

Verilator's `--coverage-line` is not offered: Verilator 5.042 miscompiles an
SVUnit testcase under it (not re-checked with 5.052). The driver rejects `--verilator-cov=l` with the
explanation rather than failing later in a compiler error.

`CONFIGS` is split by the driver, not by `make`, because a configuration
contains spaces. Note that only `vlogdefine` parameters can be swept this way
(`TB_N`, `TB_B`, `FWFT`, `SWAP_CLK`, `TB_MEM`); a `vlogparam` like `NB` or `B`
is elaborated into the DUT and never reaches the SVUnit `testrunner` toplevel,
so `xelab` rejects it with *"Parameter/Generic ... not found in design"*.

### `make coverage-matrix IP=<core> CONFIGS="a|b|c"`
Same as `make coverage` with `CONFIGS`, merged into one report.

**Currently non-functional for every core in this tree.** The parsing and
multi-config plumbing work, but a `paramtype: vlogparam` on the `test` target
becomes a command-line override aimed at the toplevel, and the toplevel is the
`svunit_gen`-generated `testrunner`, which does not declare it — Verilator and
xsim reject it identically. No core here threads a parameter into the testbench,
so there is no configuration that works today. See
[COVERAGE.md](COVERAGE.md#coverage-matrix-does-not-work-with-these-cores-parameters).

### `make coverage-all [COV_FILTER=<regex>]`
Coverage for every core that declares a `test` target. Keeps going on failure
and lists the failing cores at the end. With Verilator this is far cheaper than
under xsim, but over ~186 cores it is still not a per-PR job:

```sh
make coverage-all                             # all cores
make coverage-all COV_FILTER='^qick:ip:'      # the packaged IPs
make coverage-all COV_FILTER='^qick:mem:'
```

Cores instantiating Xilinx primitives do not elaborate under Verilator and are
reported as failures rather than skipped silently, so a Verilator sweep is never
mistaken for a complete one.

### `make coverage-summary`
Aggregate every `report_cov/<core>/summary.json` into one table plus
`report_cov/summary_all.json`, which is what you need before deciding to gate (a
gate needs a baseline):

```sh
make coverage-summary
make coverage-summary COV_SORT=toggle_pct COV_MIN=70
```

Equivalent to calling `cov_summary.py` directly for the other options:

```sh
python3 scripts/cov/cov_summary.py --root report_cov --metric toggle_pct
python3 scripts/cov/cov_summary.py --root report_cov --sort line_pct --out baseline.json
```

`--metric` picks which column the gate reads (default `toggle_pct`, the only one
both backends measure, so a sweep can mix them). It exits 1 if any core is below
the threshold, and also if any core reported 0 coverage points for a DUT file
(`--ignore-zero-statements` downgrades that second case to a warning — see the
limitation in [COVERAGE.md](COVERAGE.md)).

### `scripts/cov/apply_svunit.py` — enable the interface checkers
`-d SVUNIT` switches on the `axi4_stream_if` protocol checkers. Of the 186 cores
with a `test` target, 21 already carry it and only 22 of the remaining 165 can
actually reach an assertion behind the define; this script applies it to exactly
those 22 and leaves the other 143 alone. It is idempotent — a core that already
carries the define is skipped. 43 cores in the tree carry the define in total.

```sh
python3 scripts/cov/apply_svunit.py --check              # dry run
python3 scripts/cov/apply_svunit.py                     # apply
python3 scripts/cov/apply_svunit.py --with-held-back    # also the 5 held back
```

Five are **held back** pending RTL fixes:
`axis_dyn_readout_v1`, `axis_readout_v2` and `axis_readout_v3` trip `VALID_RST`;
`axis_tap` and `qproc_mem_ctrl` trip genuine protocol violations
(`TSTRB_X`, `TVALID_STABLE`, `TLAST_STABLE`). Two further cores, `axis_pipe` and
`axis_to_sigma_delta_fifo`, used to fail to build whether or not the define was
present. On 2026-10-23 `axis_pipe` was fixed and carries it now;
`axis_to_sigma_delta_fifo` was removed with the other cores imported from another
project that QICK does not use (`axis_tlast_generator`, the sixth held back, among them). All of it is recorded in the script's
`HELD_BACK` table with the specific assertion and location.

### `scripts/cov/validate_xsim.sh`, `scripts/cov/xsim_regression.sh`
Regression helpers for the `-d SVUNIT` change. `validate_xsim.sh` runs every
`cores/ip/*` target plus the patched cores, and for each failure re-runs it with
the change stashed so pre-existing breakage is classified rather than guessed at.
`xsim_regression.sh` is the narrower `cores/ip/*`-only version.

```sh
bash scripts/cov/validate_xsim.sh
bash scripts/cov/xsim_regression.sh
```

Both are long-running (tens of seconds per core under xsim) and are validation
tools, not per-PR jobs.

---

## Register map & driver (PeakRDL)

### `make rdl-gen IP=<ip>`
`cd cores/ip/<ip>/rdl && make gen`. Generates the PeakRDL Python package (and
regblock SV only if the IP's rdl/Makefile keeps `--hdl`). No symlink.

### `make driver IP=<ip>`
Full driver flow:
1. `make gen` in `rdl/` (same step as `make rdl-gen`, with `PYTHONHASHSEED=0` so the output is
   deterministic).
2. If `cores/ip/<ip>/driver/<ip>.py` is a standalone file, symlinks it into
   `qick_lib/qick/drivers/<ip>.py` (`QickSoc` auto-imports what it finds there). If it is
   itself a symlink into a monolithic `qick_lib` module, nothing is linked.
3. Copies the generated package to `qick_lib/qick/rdl_pkgs/<ip>_regmap_pkg/`.
4. Automatically calls `make driver-test IP=<ip>`.

The symlink and the runtime part of the copied package are committed (see
[DRIVER.md](DRIVER.md) and [BOARD_WORKFLOW.md](../user/BOARD_WORKFLOW.md)).

### `make driver-check IP=<ip>`
Regenerates the package into a temporary directory and diffs it against
`qick_lib/qick/rdl_pkgs/<ip>_regmap_pkg` (ignoring `tests/` and `lib_test/`). Exits non-zero with
`DRIFT: run 'make driver IP=<ip>' ...` if the committed package is stale.

### `make driver-test IP=<ip>`
Runs the register-layer pytest in `cores/ip/<ip>/driver/tests/` (PeakRDL
reg-model + in-memory Simulator, no hardware). Writes
`report_pytest/driver-<ip>-report.xml`. Skips gracefully if `driver/tests/`
is absent.

### `make driver-all`
Runs `make driver` for every IP under `cores/ip/` that has an `rdl/Makefile`. It keeps going
when one fails and lists the failures at the end. It also activates every standalone driver
in `qick_lib`, so use it deliberately.

### `make rdl-docs IP=<ip>`
`cd cores/ip/<ip>/rdl && make docs` → HTML register docs at
`cores/ip/<ip>/rdl/docs/index.html`.

---

## RTL library documentation

### `make rtl-docs [INPUT=<file>]`
Generates Markdown documentation for every module in `../rtl_lib` (the RTL
source of truth), mirroring TerosHDL's Generics/Ports tables. Output goes to
`docs/rtl-md/` (one `.md` per module + a `README.md` index).

- `make rtl-docs` — document the whole library.
- `make rtl-docs INPUT=../rtl_lib/dsp/sgv6_top.sv` — a single file.

Driven by `scripts/gen_docs.py`. Reads doc from BOTH styles:
- Modern: `//!` block above `module`, `//!` adjacent to each port/param.
- Legacy: `/** ... */` header with `@brief`/`@description`/`@port`/`@param`
  (a fallback fills port/param descriptions from `@port`/`@param` tags).

Excludes are read from `../rtl_lib/.docsignore` (globs; e.g.
`*_entity_declarations.sv`, `ssr_*.sv`) plus a built-in default.

### `make rtl-docs-clean`
Removes `docs/rtl-md/` (and the old `docs/rtl/` if present).

**Gotchas (learned the hard way):**
- Doxygen is NOT used for HDL: with `sv=C++` it renders ports as functions and
  chokes on `generate`. The custom generator replaces it.
- `teroshdl` pip 3.0.0 has no documentation CLI (only the VS Code extension),
  hence the in-house generator.
- Single-file `INPUT=` and full-tree runs must anchor output at the `rtl_lib`
  root, or a file lands in `docs/rtl-md/<name>.md` (root) while you read the
  stale `docs/rtl-md/dsp/<name>.md`. (Anchoring fix in `gen_docs.py:main`.)
- The index flags modules with 0 parsed ports (!) as documentation debt.

## Schematics

### `make schematic TOP=<module>` / `make schematic PROJ=<group>/<project>`
The interactive schematic of `TOP` in VS Code (ossschem): the whole hierarchy,
expanded in place, signals traced to their drivers and loads. Writes
`build/schematic/<TOP>/schematic-ir.json` (`gen_block_diagram.py --ir`, the same
Verilator elaboration as `make block-diagram`) and opens it with `code`. Modules
Verilator cannot find become port-only blackboxes (UNISIM/XPM from Vivado, IP cores
and block designs from the stubs Vivado wrote). `PROJ=` draws a whole Vivado
project of `Top/` (its top, its block designs from what Vivado generated in
`Projects/`, our IPs inside them down to RTL); the project must have been created
once. Guide: [../user/SCHEMATIC.md](../user/SCHEMATIC.md).

### `make block-diagram TOP=<module> [IP=<name>]`
A static SVG of one level of `TOP` (its direct children, their ports and the
wires between them) into `../docs/block-diagrams/`. Same blackboxes as
`make schematic`.

## Core creation

### `make new-ip IP=<name>`
`./scripts/create_ip.sh <name>` — scaffolds `cores/ip/<name>/` (rdl/, driver/,
hdl/, tests/). See firmware/docs/developer/DRIVER.md for the two RTL strategies (generated regblock
vs custom AXI slave) and the rdl/Makefile gotchas (single `dirname`, TABs).

(Library cores are NOT a Makefile target — use `./scripts/new_lib_core.sh`.)

---

## Packaging (Vivado)

### `make package IP=<ip> [VERSION=] [PART=] [DESCRIPTION=] [DISPLAY_NAME=]`
Runs `generators/ip_gen/ip_packager.py` in `build/package_<ip>/`. Prints usage
if `IP` is missing.

### `make package-all`
Packages every IP under `cores/ip/`.

### `make package-dry IP=<ip>`
Generates the packaging TCL without running Vivado (inspection / debug).

---

## Inspection

| Target | Purpose |
|--------|---------|
| `make list-cores` | List all cores across the four roots. |
| `make core-info CORE=<vlnv>` | Show a core's filesets/targets/deps. |
| `make deps IP=<core> [TARGET=<t>]` | Resolved dependencies of a core in compile order (any category, bare name or VLNV; `scripts/core_deps.py`). |
| `make doc-check` | Documentation check (`scripts/doc_check.py`): every IP README has the template's sections, every Hog project and every library category has a README (a category lists all its cores), no relative Markdown link is broken. Warns about library cores whose `.core` has no description. It checks what git tracks (`git add` a new README or project first): a directory left behind by another branch is ignored. |
| `make verify-core IP=<ip>` | Sanity-check that core dir, `.core`, RTL source and packaged source exist; prints deps. |

---

## Cleanup

### `make clean`
`rm -rf build report_pytest report_svunit report_cov vivado* .Xil .fusesoc_libraries`.
NOTE: this also deletes the cloned `.fusesoc_libraries/svunit_lib`, so the next
`make sim` / `sim_svunit` re-clones SVUnit (slower first run, needs network). It does NOT touch `../../.venv/` or
the source symlinks.

---

## Typical workflows

**New IP end-to-end:**
```
make new-ip     IP=my_ip
# edit rdl/my_ip_regmap.rdl and rtl_lib/ip/my_ip.sv
make driver     IP=my_ip      # gen + symlink + driver-test
make sim_svunit IP=my_ip      # RTL verification
make rdl-docs   IP=my_ip
make package    IP=my_ip
make rtl-docs                 # complete RTL documentation from RTL modules
```

**Close an IP (what we did for SG-v6):**
```
make driver     IP=axis_signal_gen_v6   # driver + reg tests green
make sim_svunit IP=axis_signal_gen_v6   # SVUnit PASSED
make rdl-docs   IP=axis_signal_gen_v6
```

---

## Makefile pitfalls (repo-wide)

- **TABs, not spaces** in every recipe line, or `*** missing separator`.
- **`$$VAR` inside recipes** (double `$`) to pass a shell var, e.g.
  `PYTHONPATH=scripts:$$PYTHONPATH`. A single `$` is expanded by Make.
- **Line continuations**: every non-final line of a multi-line recipe needs a
  trailing `\`; dropping one silently truncates the command (we lost a
  `--junitxml` flag this way once).
