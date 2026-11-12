# Code Coverage

`make coverage IP=<core>` re-runs a core's SVUnit testbenches under an
instrumented simulator and reports coverage of the **DUT** — the RTL, with the
testbench, `clk_gen`, `glbl` and vendor library models excluded.

Read [MAKEFILE_DOC.md](MAKEFILE_DOC.md#code-coverage) for the target reference.

## Two backends

| | Verilator (default) | xsim |
|---|---|---|
| metric | line + **toggle** | statement, branch, condition, toggle |
| how | compiles the SVUnit `testrunner` to a native binary | re-elaborates with `xelab --cc_type` |
| speed | milliseconds of simulation; elaboration dominates | tens of seconds per run |
| purely combinational RTL | **instrumented** | reports 0 statements |
| vendor primitives (XPM, DSP) | not available | available |
| select with | *(default)* | `COV_BACKEND=xsim` |

**Toggle is the metric to gate on.** It is the only one both backends measure, so
a sweep can mix them, and it is the one that finds dead RTL: a bit that never
toggles is logic the tests never reach.

> **Prerequisite:** the Verilator backend needs the repository's Verilator,
> `VERILATOR_VERSION` of the Makefile (5.052). Vivado does not
> bundle it. `make setup_environment` builds it into `~/.local/verilator-5.052`
> without root (a few minutes; needs `gcc`, `flex`, `bison`, `autoconf`, `perl`,
> `help2man`, `git`), and every `make` target puts it first on `PATH`;
> `make install_verilator` does that step alone. `make coverage` refuses an older
> Verilator with an explicit message rather than failing obscurely. Until
> Verilator is available, `COV_BACKEND=xsim` works with only Vivado installed.
>
> The Verilator run gets the `-timescale` the core gives xelab in its xsim test
> target, so both simulators use the same time units (without it a delay such as
> 1.5 ns is rounded and a test can pass or fail depending on the release).
> SVUnit comes from `lharnaldi/svunit`, whose `SVTEST_END` skips the `#0` before
> `disable fork` under Verilator: with it, Verilator 5.046+ lose part of the toggles
> a test makes and evaluate combinational logic one time step late in the next test.

```
make coverage IP=cdc_handshake
make coverage IP=cdc_handshake COV_MIN=80            # gate on toggle
make coverage IP=fifo_async COV_BACKEND=xsim COV=sb  # statement coverage
make coverage IP=xcom COV_DEFINE=SVUNIT              # enable interface SVA
make coverage-summary                                # table over the sweep
```

`IP=` accepts the short core name, a VLNV, or a VLNV with version — all three
resolve to the same core. An ambiguous short name is an error listing the
candidates rather than a silent pick (`fifo` matches both `qick:external:fifo`
and `qick:mem:fifo`).

## Why it is not just `fusesoc run --target test`

Both simulators instrument at build time, so coverage cannot be layered onto a
simulation that already ran.

The obvious fix — add coverage flags to the `xelab_options` / `verilator_options`
of all 186 `test` targets — is not available:

- FuseSoC does **not** merge `tools:` sections across cores.
  `fusesoc/capi2/core.py::get_tool_options` reads only the target's own
  `tools:` block, so a dependency core such as `qick:common:sim_base` cannot
  inject options into the targets that depend on it.
- edalize takes its options verbatim out of the generated `config.mk`, with no
  environment-variable hook.

So `scripts/cov/cov_run.py` sidesteps both: it exports the design with
`fusesoc run --setup` and then calls the generated Makefile with
`VERILATOR_OPTIONS` / `XELAB_OPTIONS` overridden on the command line. Make
command-line variables beat the `include config.mk` assignment, so the per-core
options that already exist (`-timescale`, `-L XPM`, `-d SVUNIT`) are preserved
and simply appended to. **No `.core` file is modified by the coverage flow.**

The Verilator path also needs `make binary`, not the default target: the default
`V<top>` rule runs `verilator -f` *without* `--binary`, so it emits no C++
`main()` and fails at link time with an undefined reference to `main`.

## Verilator runs the SVUnit suites

This was not obvious — Verilator is only used for `lint-only` elsewhere in the
repo — but it does. `fusesoc run --target test --tool verilator --setup`
elaborates the whole SVUnit testrunner, and the compiled binary prints the same
marker xsim does, so `cov_run.py`'s pass detection is shared:

```
INFO:  [268000][testrunner]: PASSED (1 of 1 suites passing)
```

Three flags are always required:

| flag | why |
|---|---|
| `--timing` | SVUnit's runner uses `#delay`, `fork` and `disable fork`; without it Verilator aborts with `NEEDTIMINGOPT`. |
| `-Wno-fatal` | the SVUnit sources and the testbenches trip width and lint warnings that would otherwise stop elaboration before the run starts. |
| `--coverage-toggle` | the coverage instrumentation itself. |

### `--coverage-line` does not work with SVUnit

Verilator 5.042 miscompiles an SVUnit testcase under `--coverage-line` (not re-checked with 5.052). The
generated `__ctor_var_reset` resolves the `name` formal argument of
`svunit_testcase::new()` as a data member instead of a method, and the C++ does
not compile:

```
Vtestrunner_bin2gray_unit_test__0__Slow.cpp:39:64: error:
  no match for call to '(std::string {aka std::__cxx11::basic_string<char>}) ()'
```

`--coverage-toggle` compiles cleanly. `cov_run.py` rejects `--verilator-cov=l`
up front with this explanation rather than failing later in a compiler error.

The `line` column in a Verilator report is therefore *not* the same quantity as
xsim's statement coverage: under `--coverage-toggle` it counts lines that
carried at least one coverage point. The table says so, and
`cov_summary.py --metric` defaults to toggle precisely because it is comparable
across backends.

## `clk_gen` had to be fixed first

Verilator could not run any testbench that synchronises to a clock edge until
`common/sim/modules/clk_gen/hdl/clk_gen.sv` was corrected. The module started
its clock from an edge:

```systemverilog
always @ (posedge i_enable or negedge i_enable)   // old
    #(START_DELAY) start_clk = i_enable;
```

Every testbench in the tree ties `.i_enable(1'b1)`, so this only ever worked
because xsim evaluates the block once at t=0 and sees the implicit `x -> 1`
transition. **Verilator does not model that transition**, so `start_clk` never
rose, `generated_clk` stayed low, and the simulation ended at `end at 0s` with
the testbench stuck on its first `@(posedge clk)`.

Reproduced in isolation, with no SVUnit and no other repo file involved
(`/tmp/kilo/cbtest`): `clk_gen` plus a plain `@(posedge clk)` ends at 0s, and so
does `always @(posedge en)` with `logic en = 1'b1`. A `default clocking` block on
its own works fine, so the clocking block was not the culprit.

This is a portability defect in the repo's own code, not a Verilator limitation.
The module now tests the initial value explicitly in an `initial` block with
`fork`/`join_any`, so it starts whether or not `i_enable` ever transitions.

xsim results are unchanged: 28/28 `cores/ip/*` targets pass after the change
(`scripts/cov/xsim_regression.sh`).

## Why the DUT filter matters

Raw numbers mostly measure the testbench. For `qick:encoders:bin2gray` under
xsim:

```
Files 7   Statements 347   Line coverage 87.61%
  clk_gen.sv            20 stmt
  bin2gray.sv            3 stmt   <-- the actual DUT
  bin2gray_tc00.sv     117 stmt
  svunit_pkg.sv        155 stmt
  junit_xml.sv          38 stmt
  .testrunner.sv         8 stmt
  .__testsuite.sv        6 stmt
```

3 of 347 statements are the design under test. The driver therefore keeps only
files under a `qick_*` core's `hdl`/`rtl`/`src` directory, minus `qick_common_*`
(`clk_gen`, `glbl`). It still reports the *full* picture with `--keep-all`, and
prints per-file DUT numbers so a low score can be traced.

`cdc_handshake` for comparison: `cdc_handshake.sv` 23 stmt at 100% plus its
submodule `cdc_bit_sync.sv` 7 stmt at 85.71%, i.e. 96.43% over 30 statements.

## What xsim cannot measure, and Verilator can

**xsim only counts statements inside procedural blocks.** A module or package
whose body is entirely continuous assignments and instantiations reports
**0 executable statements**, however much logic it contains. Verified against
the `coverage-all COV_FILTER='^qick:ip:'` baseline: every DUT file reporting 0
has zero `always_ff` / `always_comb` / `always_latch` blocks
(`fifo_async.sv`, `bram_tdp.sv`, `cdc_reg_sync.sv`, `axis_constant.sv`,
`axis_terminator.sv`, `sgv6_top.sv`, `tag_mem.sv`, `weighted_buffer.sv`,
`axis_weighted_buffer.sv`, `qick_time_tagger.sv`, and every `*_pkg.sv`), and
every DUT file that *is* counted has at least one.

Under xsim this makes **every percentage a lower bound**: the combinational
parts of a design — the `full`/`empty` OR logic in `fifo_async`, the mux and
concat logic in `axis_constant_iq`'s thin files — contribute to neither
numerator nor denominator.

Verilator's toggle coverage does reach that RTL. `bin2gray.sv` is entirely one
`assign` and xsim scores it 0 statements; Verilator reports real numbers for it:

```
100.00%      2 line   50.00% tg  bin2gray.sv
```

Both `cov_run.py` and `cov_summary.py` flag any file with no coverage points,
because a silent zero is the worst failure mode a coverage tool can have. Treat
a flagged core as **partial data**, not as `0%`.

## Cores that cannot run under Verilator

Two classes, both reported with a targeted message instead of a compiler dump.

**1. Xilinx primitives.** A core instantiating `xpm_fifo_sync`, DSP48, and so on
does not elaborate: Verilator has no XPM library.

```
ERROR-MODMISSING: fifo_sync.sv:99:5: Cannot find file containing module: 'xpm_fifo_sync'

error: the DUT uses Xilinx primitives Verilator has no library for (xpm_fifo_sync).
       This core needs --backend xsim
```

This is the same limitation the `lint` target already documents. Eight cores also
declare `toplevel: [testrunner, glbl]`; `glbl` is a Xilinx simulation primitive
with no Verilator equivalent.

**2. Testbenches that call the interface's driver tasks.**
`axi4_stream_if.sv:91-386` puts `axi_read`, `axi_write`, `burst_tx`, `burst_rx`,
`tx`, `rx`, `m_reset` and the `tb_master`/`tb_slave` modports inside
`` `ifndef VERILATOR ``, because they are clocking-block helpers.

```
error: the testbench calls interface driver tasks (axi_read, axi_write, reset)
       that axi4_stream_if.sv excludes under `ifndef VERILATOR`.
       This core needs --backend xsim
```

**This is the dominant limitation, and it is not cosmetic.** Removing the guard
to see what breaks shows Verilator cannot compile the interface at all:

```
%Error: axi4_stream_if.sv:148:9: Found definition of 'm_cb' as a
  MODPORTCLOCKINGREF but expected a scope/variable
```

The interface imports its clocking blocks through modports
(`modport tb_master (clocking m_cb, ...)`) and then drives them as `m_cb.tready`.
Verilator supports clocking blocks on their own — a `default clocking` block
with `@(cb)` works fine, verified in isolation — but not referencing one through
a modport. Supporting these 20 cores would mean restructuring the interface's
modport and clocking-block usage, which is a redesign of shared verification
code rather than a coverage change.

`qick_processor` is one of these. This is unrelated to `-d SVUNIT`: the tasks are
excluded by the `VERILATOR` guard, which the tool defines for itself.

`coverage-all` reports both classes as failures rather than skipping them
silently, so a Verilator sweep is never mistaken for a complete one.

## Measured Verilator reach

With Verilator 5.052 and the SVUnit fork, `make coverage-all` over every core with a
`test` target (187) gives a report for 95 cores, against 62 with 5.042 under the same conditions; none that
reported under 5.042 fails, and 54 give the same numbers. Toggle percentages count a bit as covered once it
toggled 10 times (`verilator_coverage`'s default threshold), so a test that runs fewer cycles reads lower.

Earlier measurement, `make coverage-all COV_FILTER='^qick:ip:'` (28 packaged IPs, Verilator 5.042):

| outcome | count | why |
|---|---|---|
| produced a number | **5** | |
| blocked on interface driver tasks | 20 | `MODPORTCLOCKINGREF`, above |
| blocked on Xilinx primitives | 3 | `xpm_fifo_async` and friends |

So Verilator covers roughly a fifth of the packaged IPs. That is enough to make
it the right default for the cores it *can* reach — it is also the only backend
that instruments combinational RTL — but a sweep over the whole tree needs
xsim, or a per-core backend choice.

## `$dumpvars(0, dut)` makes xsim's toggle coverage unreliable

83 testbenches called `$dumpvars(0, dut)` (the dump scoped to the DUT) and the other 82
called `$dumpvars()`. Under xsim the scoped form changes **which variables the toggle
metric instruments**, not just the size of the waveform, and the numbers it gives are
sometimes impossible: `lfsr`, whose bits all toggle every few cycles, read 3%, and
`xcom_cmd_hold` and `qtt_cmd_hold` read 0% with 100% statement coverage. The same test
with `$dumpvars()` reads 100% for `lfsr` and `iq_gain`. The cause is not understood; the
effect is reproducible, and statement, branch and condition coverage are unaffected.

Replacing it in all 83 and re-running them (xsim, `COV_JOBS=8`, 77 cores that produce a
number both ways) changed the toggle score of 51 cores by one point or more and left 26
unchanged. No test changed outcome: the same two cores (`axis_avg_buffer`, `avg_buffer`)
fail before and after.

| core | scoped | plain |
|---|---|---|
| `lfsr` | 3.0% | 100% |
| `xcom_cmd_hold`, `qtt_cmd_hold` | 0% | 60% |
| `gcc` | 43.1% | 93.1% |
| `sync_ab_en` | 66.7% | 100% |
| `iq_gain` | 0% | 100% |
| `smp_fifo_dc` | 50.2% | 30.7% |
| `smp_mem` | 56.2% | 39.0% |
| `tag_fifo_dc` | 46.4% | 31.8% |

The numbers also fall for the memory-heavy cores, so a toggle figure measured with the
scoped form was not a conservative one: it was a different subset of the design. The
plain form is the one the majority already used and the one that gives the right answer
where the right answer is known, so every testbench now uses it. **A toggle score taken
before this change is not comparable with one taken after it.** New testbenches should
call `$dumpvars()` with no arguments.

## Known limitations

- **Coverage is a partial check, not a proof.** A passing percentage says
  nothing about which behaviour was exercised. The repo's real verification
  mechanism is the SVA in `rtl_lib/interfaces/axi4_stream_if.sv` plus
  [TESTBENCH_PATTERNS.md](TESTBENCH_PATTERNS.md).
- **Sub-metrics are aggregated, not summed.** Line/branch/condition percentages
  are aggregated exactly under xsim (it reports per-file totals to 4 decimals).
  Branch/condition/toggle have no per-file counts, so they are **weighted
  averages** — weighted by the number of coverage points each file actually has,
  so a file with 4 toggle points does not move the total as much as one with
  400. The table labels this.
- `coverage-all` over ~186 cores is long even with Verilator. Prefer
  `make coverage IP=<core>` per PR.
- **A testbench that never terminates will hang a sweep.** `COV_TIMEOUT`
  (default 1800 s per run) turns that into a reported failure instead of a stuck
  job. If a core trips it, re-run that core without coverage before blaming the
  RTL.

## Coverage found a real datapath bug

`make coverage IP=axis_avg_buffer` fails under coverage while
`make sim IP=axis_avg_buffer` passes — deterministically, 3/3 runs in each
direction. It is a genuine RTL defect, not a bench sampling race.

**Root cause: `firmware/rtl_lib/math/buffer.sv`.** The FSM leaves its capture
state on this condition:

```systemverilog
// buffer.sv:113-120
end else if (din_valid_i && cnt == len_r) begin
  state <= WAIT_TRIGGER_ST;
```

while the write enable is combinational and *also* requires `din_valid_i`:

```systemverilog
// buffer.sv:178
assign mem_we_o = memw_state && din_valid_i && start_reg;
```

The comment above the FSM claims "after `len_r` samples `cnt == len_r`", but
the sample that brings the counter to `len_r` is written in the cycle where
`cnt == len_r - 1`. For the FSM to then exit cleanly, `din_valid_i` has to
still be high one cycle later. If the sample stream has already deasserted it,
`mem_we_o` falls and **the final sample is dropped silently**, with the FSM left
in `MEMW_ST`. There is no margin: the capture window is exactly one cycle wide
at the boundary.

Evidence from two runs of the same testbench, identical apart from the coverage
flag:

| `buffer_i` signal | no coverage | with coverage |
|---|---|---|
| `state` (FSM path) | identical | identical |
| `mem_we_o` high for | 15 ns (3 cycles) | 10 ns (2 cycles) |
| `cnt` reached | 2 | 3 |

The FSM traverses exactly the same states; only the `mem_we_o` window differs.
With coverage only 2 of 3 samples reach the BRAM, the unwritten address reads
back as XPM's `DOUT_RESET_VALUE` of 0, and the comparator at
`cores/ip/axis_avg_buffer/tests/axis_avg_buffer_tests.sv:78` fails on a
`0x0000` beat.

Ruled out, so nobody repeats it:

- **Not a race.** With `tready=0`, `tvalid=1` and `tdata=0000` are stable for
  four consecutive cycles. Stable and empty, not racing.
- **Not the AXI-Stream output stage.** `bram_to_axis_nt.sv:217-219` unpacks
  `fifo_sync` directly, and `fifo_sync.sv` instantiates XPM with
  `READ_MODE="fwft"` and `FIFO_READ_LATENCY=0`, so `dout` is a look-ahead
  output valid whenever `!empty`. `m_axis_tvalid` and `m_axis_tdata` are aligned
  by construction.
- **Not the clocking block or `#TSU`.** Both were tried; adding `#TSU` made it
  worse, because sampling post-edge crosses the pop and reads the *next* state.

The natural fix is to latch completion rather than conflating "the counter
reached the length" with "a valid sample is present now" — exit on
`cnt >= len_r - 1 && din_valid_i`, or set a registered `last_sample_done`. That
is an RTL change to `buffer.sv` and is out of scope here.

Until it is settled, `axis_avg_buffer` cannot produce a coverage number: the
driver reports the sim failure rather than a misleading percentage, which is the
intended behaviour.

## `-d SVUNIT` audit

`-d SVUNIT` switches on the `axi4_stream_if` protocol checkers
(`rtl_lib/interfaces/axi4_stream_if.sv:391-520`), which are wrapped in
`` `ifdef SVUNIT ``. Without it they are not compiled at all, so a build can be
silently running no AXI-Stream verification.

Of the 186 `.core` files that declare a `test` target:

- **21** already pass `-d SVUNIT`.
- **165** do not, but only **30** of them can actually reach an assertion behind
  the define. The other 135 have no translation unit that reads `SVUNIT`, so
  adding it there is a no-op that would silently couple 135 cores to the
  meaning of a macro that does nothing for them.

The 30 were split by how the interface is reached:

- **B1 (25)** the interface is instantiated in the core's own test build.
- **B2 (5)** it arrives through a dependency: `qick_processor` and `tprocv2`
  reach `dmem_axis_reader` / `dmem_axis_writer` via `qproc_mem_ctrl` and
  `dmem_ctrl`, and `dmem_single_rw` via the same chain.

`scripts/cov/apply_svunit.py` applies the change to exactly those 22 (run with
`--check` for a dry run). It is idempotent.

### Enabling the checkers found four real AXI-Stream violations

Validating the sweep (`scripts/cov/validate_xsim.sh`) turned up four cores whose
testbench was green and goes red as soon as the define is present. All four trip
the same property, and all four are genuine violations rather than checker bugs:

```
ERROR: [160000][axis_tlast_generator_ut]: fail_assertion_concurrent: VALID_RST
  [ AXIS_ERR: tvalid must be LOW while reset is asserted ]
  (axi4_stream_if.sv line:409)
```

`VALID_RST` (`axi4_stream_if.sv:406-409`) requires `tvalid` low in the cycle
after reset is asserted. The testbenches legitimately drive `tvalid` high *into*
reset on the stimulus interface — which is allowed for an input — and the DUT
passes it straight through to its output instead of forcing it low.

| Core | Assertion | Cause |
|---|---|---|
| `axis_tlast_generator` | `VALID_RST` | `axis_tlast_generator.sv:40` is `assign o_axis.tvalid = i_axis.tvalid;` — a pure combinational pass-through with no reset gating at all. |
| `axis_dyn_readout_v1` | `VALID_RST`, `AXI4STREAM_ERRM_TVALID_RESET`, `AXI4STREAM_ERRM_TDATA_X` | output `tvalid` reaches the stream through `fir_decim8_dynro`, which has no reset of its own (the TB header says as much). |
| `axis_readout_v2` | same three | same pattern; 297 `VALID_RST` hits |
| `axis_readout_v3` | same three | same pattern |

These four are **held back** by `apply_svunit.py` so the tree stays green, with
the finding recorded in its `HELD_BACK` table. Fixing the RTL is the real
remedy; `--with-held-back` re-enables them once it is done.

Note that this is the failure mode to expect in general: a build that was green
because no checker was compiled can only turn *redder*, never greener, when the
checkers arrive. A failure after adding the define is a finding to investigate,
not a regression to revert.

### The register-readback output carries no tlast, by design

Turning the define on turned four more suites red with
`AXI4STREAM_ERRM_TLAST_X`, all from one cause: the register-readback output is
modelled in the testbench as a full `axi4_stream_if`, but no wrapper declares
an `m2_axis_tlast` port and `avg_top` declares `m1_axis_tlast`
(`avg_top.sv:58`) without ever assigning it — the `fifo_async` feeding it has no
`dlast`.

This is a deliberate decision, not an oversight. Every wrapper leaves the port
open on purpose (`avg_buffer.sv:143`, `weighted_buffer.sv:201`) and every
consumer takes m2 as `tdata`/`tvalid` only (`qick_processor.sv:574`). So the
testbench was the thing that was wrong: it asserted a framing contract on a port
that has none. Undrove, `tlast` floats to X and the checker fires on the first
readback beat.

Fixed by tying the testbench's `tlast` low in `axis_avg_buffer`,
`weighted_buffer`, `avg_buffer` and `avg_top`. The RTL is untouched, so nothing
upstream or downstream sees a new signal or a new constraint — the tests still
check `tvalid`/`tdata` on m2, only the framing check is dropped. The one real
cost is that m2's `tlast` stability check becomes trivially true.

### Two more cores fail real protocol checks

Distinct from the `VALID_RST` group above: these are not reset gating, they are
AXI4-Stream violations in the datapath. They are in `HELD_BACK` and therefore
silent today.

| Core | Assertions |
|---|---|
| `axis_tap` | `AXI4STREAM_ERRM_TSTRB_X`, `AXIS_TVALID_STABLE` — the tap drives `tstrb` from a source that is X, and drops `tvalid` while `tready` is low |
| `qproc_mem_ctrl` | `AXIS_TVALID_STABLE`, `AXI4STREAM_ERRM_TLAST_STABLE` — `tvalid` drops under backpressure and `tlast` changes with it |

### `coverage-matrix` does not work with these cores' parameters

The multi-config plumbing is correct — both configs are parsed and passed to
`fusesoc run`, and each is labelled and run in turn. The core-side parameter
override is what fails. Six cores declare `parameters:` on their `test` target
(`axis_streamer`, `mr_buffer_et`, `cdc_handshake`, `streamer`, `sg_mux8`,
`fifo_async`) and all six use `paramtype: vlogparam`, which edalize turns into a
command-line parameter override aimed at the toplevel.

The toplevel is `testrunner`, the module `svunit_gen` generates — and it does not
declare those parameters. So both simulators reject the override identically:

```
verilator: %Error: Parameters from the command line were not found in the design: DW
xsim:      %Error: [XSIM 43-3281] Parameter/Generic DW specified in commandline not found in design.
```

This is not a Verilator gap and not specific to the define; it is a property of
combining a command-line parameter override with an SVUnit-generated toplevel.
Passing the configuration as a Verilog *define* rather than a parameter override
would avoid it, but no core here is set up for that. Until a core threads a
configurable parameter into the testbench itself, `coverage-matrix` has no working
target in this tree. `apply_svunit.py` and the single-config path are unaffected.

### Five cores were already broken before any of this

> **Status 2026-10-23:** `axis_pipe` and `axis_data_concat` build and
> pass. `round_robin`, `data_to_axis_fifo`, `memory_data_dispatcher`,
> `axis_to_sigma_delta_fifo`, `axis_producer`, `axi4_stream_fifo`,
> `axis_tlast_generator`, `axis_skid_buffer` and the `data_stream_if` /
> `config_stream_if` interfaces were removed: they were imported from another
> project and QICK does not use them. Details in `firmware/fusesoc/CHANGELOG.md`.
> The tables below are the record of what was found.

`validate_xsim.sh` classifies every failure by re-running it with the change
reverted. These five fail identically with and without `-d SVUNIT`:

| Core | Cause |
|---|---|
| `round_robin` | `round_robin_tc00.sv:39` passes `.N_BYTES_TDATA` to `axi4_stream_if`, which has no such parameter (it has `TDATA_WIDTH`). |
| `axis_pipe` | same class of interface-parameter mismatch |
| `memory_data_dispatcher` | fails to elaborate |
| `axis_to_sigma_delta_fifo` | fails to elaborate |
| `data_to_axis_fifo` | declared dependency on non-existent VLNVs, plus the wrong fileset path (see below) |

Do not attribute these to the coverage work.

### Corrections to the premises this replaced

- Only **`axi4_stream_if.sv`** is gated by `` `ifdef SVUNIT ``. `config_stream_if.sv`
  and `data_stream_if.sv` use the *inverse* gate — active by default in any
  simulation — so `-d SVUNIT` is a pure no-op for their consumers.
- The macros live in `firmware/fusesoc/common/sim/include/svunit_assert_macros/`,
  not `common/include/`.
- The VLNVs are `qick:interfaces:{axi4_stream_if,config_stream_if,data_stream_if}`.
- 186 cores declare a `test` target. The figure 212 counts *lines* matching
  `SVUNIT` across `.core` files, not cores.
- All 186 are genuine SVUnit suites (`SVUNIT_FILTER="*"` in 189 of 190
  `xsim_options`; `generate: [testrunner_gen]` in 186/186), so there is no
  "not an SVUnit suite" carve-out to respect.

### Not handled: two cores need the dependency fixed first

- `cores/lib/axi/axis_data_concat` — RTL declares `axi4_stream_if.slave` /
  `.master` ports but the core has **no** `depend` on any interface. Its `tb`
  fileset also points at `tests/axis_data_concat_tc00.sv` and `tests/tests.sv`,
  which do not exist on disk, so the `test` target cannot build at all.
- `cores/lib/utils/data_to_axis_fifo` — uses `data_stream_if.slave` /
  `axi4_stream_if.master`, but depends on `"^qick:interfaces:axi4_stream:1.1.0"`
  and `"^qick:interfaces:data_stream:0.2"` (neither exists) and on
  `qick:external:axis_fifo` (the real core is `qick:axi:axis_fifo`). Its `rtl`
  fileset also points at `src/…` when the file is at `hdl/…`.

Adding `-d SVUNIT` to either is cosmetic until the `depend` block is corrected.
(Both corrected 2026-10-23; `axis_data_concat` got the testbench it was missing.)

### Related defects found while auditing

- `config_stream_if.core:11` and `data_stream_if.core:11` depend on
  `qick:sim:svunit_assert_macros`, which does not exist — the real VLNV is
  `qick:common:svunit_assert_macros`. Both files `` `include `` the `.svh`
  unconditionally in simulation, so a `tool_xsim` build that reaches them fails
  on include resolution. (Fixed 2026-10-23.)
- `axi4_stream_if.sv` `` `include ``s the `.svh` whenever `SVUNIT` is defined on
  *any* tool, but the dependency carrying it is guarded by `tool_xsim ?`. A
  Verilator run with `-DSVUNIT` would need the `.svh` on the include path with
  the dependency suppressed. (In practice the checkers are excluded under
  Verilator anyway — the block is wrapped in `` `ifndef VERILATOR `` — so this
  is latent rather than active.)
- Four cores use `name :` with a space before the colon (`axis_fifo.core:3`,
  `eth_udp_external.core:3`, `eth_udp_phy_external.core:2`,
  `fifo.core:3`). Tooling that greps `^name:` misses them.

## Suggested rollout

Measured Verilator results for the five packaged IPs it can reach:

| Core | stmt | toggle |
|---|---|---|
| `qick:ip:axis_constant` | 42.9 % | 1.5 % |
| `qick:ip:qick_vec2bit` | 100 % | 68.2 % |
| `qick:ip:axis_reorder_iq_v1` | 87.5 % | 99.0 % |
| `qick:ip:axis_terminator` | 100 % | 98.7 % |
| `qick:ip:sg_translator` | 95.5 % | 99.3 % |

`axis_constant` at 1.5 % toggle and `qick_vec2bit` at 68 % are the interesting
ones — both are combinational cores that xsim could not instrument at all, and
both have output bits that essentially never toggle. That is the class of dead
logic the old flow was structurally blind to.

1. Land the flow. Verilator/toggle is the default for the cores it can reach.
2. Treat the first Verilator baseline as informational, not as a gate. 5 of 28
   packaged IPs produce a number, which is not a baseline to gate on.
3. Fix `buffer.sv` (above) before `axis_avg_buffer` appears in any gate.
4. Keep `-d SVUNIT` in the cores carrying it. The six held back in the tables
   above are real findings waiting on an RTL fix, not deferred work: four
   `VALID_RST`, plus `axis_tap` and `qproc_mem_ctrl` for genuine protocol
   violations.
5. Then gate per core with `COV_MIN`, on toggle, only on files that changed — and
   only on cores that actually ran, so a Verilator-blocked core is never read as
   a 0 %.

## Validation

`scripts/cov/validate_xsim.sh` runs every `cores/ip/*` target plus all the
SVUNIT-patched cores under xsim, and for each failure re-runs the core with the
`.core` change stashed so pre-existing breakage is classified rather than
guessed at. `scripts/cov/xsim_regression.sh` is the narrower `cores/ip/*`-only
version.

Measured over the 26 cores that carry `-d SVUNIT`, after the `tlast` fix:

```
23 passed, 1 failed
  axis_to_sigma_delta_fifo  pre-existing dependency conflict, fails
                            identically with the define stripped
```

Of the two cores removed from the programme for being unbuildable, `axis_pipe`
and `axis_to_sigma_delta_fifo` were each confirmed to fail the same way with
the define stripped, so the define could never have helped them.

The `clk_gen` rewrite introduced **no** regressions: every core that passed
before it passes after it.
