# SVUnit Testbench Patterns — QICK Firmware Verification

Lessons learned from the verification campaign on `alu_arithmetic_unit`, `alu_bitwise_unit`, `alu`, `timed_ictrl`, `tpv1_ctrl`, `bram_simple_sp`, `regfile_8p`, and `xcom_async`. These patterns apply to any SVUnit testbench in this repo.

---

## 1. Clocking Block Timing: outputs drive before the edge, inputs sample after

All testbenches use:

```systemverilog
default clocking cb @(posedge tb_clk);
default input #1step output #2;
    ...
endclocking
```

Rule: after `@(cb)`, you are **in** the new state — its outputs are already visible. Do not check outputs before the first `@(cb)` of a state.

drive signal        → FSM still in current state
@(cb)               → FSM transitions; new state outputs visible NOW
check outputs       ✓

This is the most common source of off-by-one errors in Moore FSM testbenches.

---

## 2. Moore FSM: present the opcode/input one cycle before it is needed

For processors or decoders where an input (e.g. opcode) is latched in state N and used in state N+1, present it **during state N**, not after reaching N+1.

Example from `tpv1_ctrl`: the opcode must be stable during `FETCH_ST` (where `ir_en=1`) so the FSM can dispatch correctly in `DECODE_ST`.

```systemverilog
// WRONG: opcode presented after DECODE_ST is reached
@(cb);              // → DECODE_ST
cb.tb_opcode <= op; // FSM already sampled opcode=0

// CORRECT: opcode presented during FETCH_ST
cb.tb_opcode <= op; // IR load: mirrors hardware ir_en behavior
@(cb);              // → DECODE_ST: FSM sees correct opcode
@(cb);              // → first instruction state: ready to check
```

---

## 3. Pipeline latency: count register stages, not clock edges

Every pipeline register between input and output adds one cycle of latency. Count them explicitly before writing helper tasks.

| Module | Latency | Reason |
|--------|---------|--------|
| `alu_arithmetic_unit` | 2 cycles | `din_a_r` → `dout_r` → `dout_rr` |
| `alu_bitwise_unit`    | 2 cycles | same structure |
| `alu` (top)           | 3 cycles | sub-module (2) + `op_rrr` selector alignment (3) |
| `regfile`             | 1 cycle  | synchronous read in `always_ff` |
| `regfile_8p`          | 2 cycles | `regfile` read (1) + `pnum_r` mux (1) |

Read tasks must wait the full latency before sampling:

```systemverilog
// regfile_8p: 2-cycle read latency
task read_reg0(...);
    cb.tb_pnum  <= page;
    cb.tb_addr0 <= addr;
@(cb);   // Cycle 1: regfile clocks addr
@(cb);   // Cycle 2: pnum_r mux resolves
    data = tb_dout0;
endtask
```

---

## 4. Diagnosing read failures: X vs 0x0000 mean different things

When a read check fails, the value returned tells you the root cause:

| Got | Meaning | Fix |
|-----|---------|--------|
| Value shifted by one position | A handshake was miscounted: the testbench either sampled a beat it never consumed, or consumed one it never counted | Section 8 — check the ready/valid ordering in the driver tasks, not the DUT |
| Correct data, wrong beat count | `tlast` position or a stranded tail | Section 10 — check `beats.size()`; if the count is short by exactly `NT`, suspect section 16 |
| `0xxxxx` (X/Z) | Memory never initialized; no hardware reset on `mem[]` | Write a known value before reading |
| `0x0000` (all zeros) | Written correctly but sampled too early | Add missing latency cycles in read task |
| Stale value from previous test | Test state leaking between SVUnit tests | Initialize all relevant registers at test start |

`$isunknown()` in the first assertion of each test catches the X case early.

---

## 5. Memories without reset must be explicitly initialized in tests

Modules using `logic [B-1:0] mem [N]` (e.g. `regfile`, `bram_simple_sp`) do not reset their array contents — only control registers reset. In simulation, `mem[]` starts as X.

```systemverilog
// WRONG: assumes mem[10] is 0 after reset
read_reg0(0, 10, read_data);
`FAIL_UNLESS_LOG(read_data == 0, "...");  // will see X

// CORRECT: write a known value first
write_reg(0, 10, 16'h0000);
read_reg0(0, 10, read_data);
`FAIL_UNLESS_LOG(read_data == 0, "...");  // reliable
```

When a test needs to verify that a location was _not_ written (e.g. write enable
gating), initialize that location to a known value before the operation under
test, then verify it is unchanged after.

---

## 6. Concurrent assertions: always use `disable iff (!rstn)`

Assertions that fire at time zero — before the clocking block has run — will
fail spuriously because signals are X. Guard all concurrent assertions:

```systemverilog
// WRONG: fires at time 0 when signals are X
property zero_a_detect;
@(posedge tb_clk)
    (tb_din_a == '0) |-> (tb_zero_a == 1'b1);
endproperty

// CORRECT
property zero_a_detect;
@(posedge tb_clk) disable iff (!tb_rstn)
    (tb_din_a == '0) |-> (tb_zero_a == 1'b1);
endproperty
```

Exception: properties using `|=>` (non-overlapping implication) are naturally
safe because the consequent evaluates one cycle later, by which time signals are
valid.

---

## 7. Inter-test state isolation

SVUnit runs `setup()` / `teardown()` between tests, but hardware state (memory contents, pipeline registers) carries over. Each test should initialize only the state it depends on. Do not assume a fresh device.

The `setup()` task should:
- Assert and deassert reset
- Drive all inputs to safe idle values
- **Not** attempt to initialize memories (too slow for large arrays)

Individual tests are responsible for initializing any memory locations they need to read with predictable values.

---

## 8. Clocking-block drives land at the _next_ clocking event

A synchronous drive through a clocking block is not visible on the bus at the edge you are standing on. `cb.sig <= v` schedules the drive for the next clocking event plus the output skew. This single fact caused four separate bugs in one campaign.

**The ready-before-valid trap.** A master that samples `ready` before its `valid` has reached the bus can cancel its own beat:

```systemverilog
// WRONG — tx() that drops the beat whenever the slave already holds tready high
m_cb.tdata  <= data;
m_cb.tvalid <= 1'b1;      // scheduled for T1 + skew
do begin
@(m_cb);                // returns at T1; tvalid is NOT on the bus yet
end while (!m_cb.tready); // tready already high -> loop exits immediately
m_cb.tvalid <= 1'b0;      // scheduled for T1 + skew TOO — last write wins
```

Both drives land in the same time slot, `tvalid` never rises, and the beat vanishes silently. Align to the clocking event _before_ driving:

```systemverilog
// CORRECT
@(m_cb);                  // align first
m_cb.tdata  <= data;      // drive lands at T0 + skew
m_cb.tvalid <= 1'b1;
do begin
@(m_cb);                // at T1 the DUT sees tvalid: the sampled ready is real
if (++cnt > timeout) $fatal(1, "[AXIS_FATAL] TX timeout");
end while (!m_cb.tready);
m_cb.tvalid <= 1'b0;      // different slot — no cancellation
```

The same defect appears on the slave side and in AXI4-Lite:

| Task | Symptom | Fix |
|------|---------|-----|
| `tx` / `burst_tx` | beat silently dropped when the DUT holds tready high | align with `@(m_cb)` before driving |
| `rx` | returns a beat that was never consumed; the next call returns it again | one `@(s_cb)` after raising tready |
| `burst_rx` | first beat counted twice — packet length off by exactly one | one `@(s_cb)` after raising tready |
| `axi_write` / `axi_read` | write lost when the slave holds awready/arready high in idle | `do...while` instead of `while` |

The tell for all of these is an off-by-one that is _constant_ and _data-independent_: 2049 beats instead of 2048, every time, in every test. A constant offset is a scheduling bug. A varying one is a logic bug.

---

## 9. Never mix raw-signal sampling with clocking-block drives

If you drive a signal through a clocking block, sample everything on that interface through the same clocking block. Reading the raw signal right after `@(cb)` returns puts you in the same delta region in which the DUT is updating it — you get the old value or the new one depending on scheduling order.

```systemverilog
// WRONG — drives tready through s_cb, samples the raw bus
m_axis_if.s_cb.tready <= 1'b1;
while (!m_axis_if.tvalid) @(m_axis_if.s_cb);
word = m_axis_if.tdata;      // races with fifo_dout updating

// CORRECT
m_axis_if.s_cb.tready <= 1'b1;
@(m_axis_if.s_cb);
do @(m_axis_if.s_cb); while (!m_axis_if.s_cb.tvalid);
word = m_axis_if.s_cb.tdata; // sampled #1step before the edge
```

The symptom is a test that passes and an almost identical one that fails, with a value that is neither right nor obviously wrong — often the bus's idle value `0x0000`) rather than the expected payload.

**The one legitimate exception.** Clocking-block _outputs_ cannot be read at all — xsim rejects it with `VRFC 10-3226` — so a task that needs to know whether it is currently asserting `tready` must read the raw signal. This is safe _because_ of the output skew: a signal driven with `output #2` only changes 2 ns after a clocking event, so it is stable at the sampling edge. Write the reason in a comment, or someone will "fix" it later.

**Corollary:** helper functions that expose raw asynchronous reads `sample_tdata`, `sample_tlast`) belong in waveform debugging only. Say so in their docstring. They are a loaded gun pointed at every checker in the repo.

---

## 10. Single-beat and packet APIs are not interchangeable

`rx()` consumes one beat and lowers `tready` immediately. Calling it in a loop to drain a packet does **not** work: the deassert at the end of one call and the assert at the start of the next land in the same clocking slot and cancel, so `tready` stays continuously high. The DUT then free-runs at one beat per cycle while the testbench counts one per two, the packet ends mid-loop, and the task dies on a timeout with no explanation.

Use the packet API `burst_rx`) for anything delimited by `tlast`. It holds `tready` for the whole packet and stops on `tlast`, which also makes the returned length a free correctness check:

```systemverilog
m_axis_if.burst_rx(beats);
`FAIL_IF_LOG(beats.size() !== TOTAL_WORDS,
$sformatf("burst had %0d beats, expected %0d (tlast position)",
              beats.size(), TOTAL_WORDS));
```

That one assertion covers early `tlast`, late `tlast`, and dropped beats. It is the single highest-value check in a streaming testbench.

---

## 11. Park buses in idle _before_ reset, not after

`m_reset()` blocks until `aresetn` is high, so it cannot be what clears `tvalid` during the reset window itself. Anything not explicitly driven sits at X, and X fails `tvalid == 1'b0`.

```systemverilog
task setup();
    svunit_ut.setup();

// Blocking assignments on the raw signals, on purpose: this has to happen
// before reset is asserted, and m_reset() cannot run that early.
    s_axis_if.tvalid = 1'b0;
    s_axis_if.tlast  = 1'b0;
    s_axis_if.tdata  = '0;
    s_axis_if.tstrb  = '1;
    s_axis_if.tkeep  = '0;
    s_axis_if.tuser  = '0;
    m_axis_if.tready = 1'b0;

// ... assert reset, hold, release ...

    s_axis_if.m_reset();   // hand over to the clocking-block driver
endtask
```

Also check what the reset helpers leave behind. A `s_reset()` that ends with `s_cb.tready <= 1'b1` puts the sink in an accepting state the moment reset releases — which, on a DUT that streams on a register write, means a packet can drain into nowhere while the test is busy elsewhere. Prefer explicit idle.

---

## 12. Run with the protocol assertions on

The `axi4_stream_if` compliance checkers only compile under `-d SVUNIT`. A suite that has never been run with them is measuring far less than it looks. Turning them on for the first time typically surfaces uninitialised buses (section 11) before it surfaces anything about the DUT.

Two things to know when they fire:

- A concurrent assertion failure **aborts the test** a few cycles later, so everything after it in that test is not executed. A run where every test fails early is usually one root cause, not many.
- The SVUnit pass counter **underflows**. `FAILED (4294966773 of 7 tests passing `is` 2**32 - 523`, i.e. 523 assertion failures. Read the count as a failure tally, not as a test result.

While reviewing the interface's own assertions, check for copy-paste inversions — `(!aresetn && tvalid) |-> ...` instead of `(aresetn && tvalid) |-> ...` disables the check entirely while looking perfectly plausible.

---

## 13. Escape paths in helper tasks must fail the test

Every early `return`, `break` and timeout inside a drain or send helper is a path where the test finishes without checking anything. If it only prints, the test goes green.

```systemverilog
// WRONG — a short drain passes silently and leaves beats in the DUT's FIFO
if (++timeout_cnt > 500) begin
$display("[ERROR] drain_burst: tvalid timeout at beat %0d", i);
return;
end
```

This is worse than a plain false pass: for a DUT whose read burst must be consumed in full, a silent short drain contaminates the _next_ test with stale data, and the failure then appears somewhere unrelated. Prefer `$fatal` in interface tasks and `FAIL_IF_LOG` in test code.

---

## 14. Verify the parametrisation you actually deploy

A parametrised core verified at one set of parameters tells you nothing about another. `bram_to_axis_nt` was green for months at `NM=8, N=8` and shipped in a bitstream at `NM=2, N=16`, where it lost the last `NT` beats of every burst. The bug needed the producer to barely outrun the consumer; at `NT=8` the margin hid it completely.

Make the deployed configuration a first-class simulation target. With FuseSoC, expose the parameters as `vlogdefine` and add a second target:

```yaml
parameters:
MRBUF_NM: {datatype: int, paramtype: vlogdefine, default: 8}
MRBUF_N:  {datatype: int, paramtype: vlogdefine, default: 8}

targets:
sim: &sim
parameters: [MRBUF_NM, MRBUF_N]
# ...
sim_deployed:
<<: *sim
parameters: [MRBUF_NM=2, MRBUF_N=16]
```

and in the testbench:

```systemverilog
`ifndef MRBUF_NM
`define MRBUF_NM 8
`endif
localparam **int** NM = `MRBUF_NM;
```

The deployed target is slower — a full-depth burst is minutes of wall clock rather than seconds — so run the small configuration per push and the deployed one at merge. When the project's parameters change in Vivado, move `sim_deployed` with them, or it silently stops testing what you think.

---

## 15. A new test must fail against the old RTL

After writing a test for a bug you just fixed, revert the fix and confirm the test fails. Two tests written for specific `axis_to_bram_trig` fixes passed against both versions — the failure mode simply was not reachable from the testbench, so the tests were documentation, not verification.

This costs two minutes and is the only thing that distinguishes a regression test from one that just happens to be green.

---

## 16. Do not retire on a status flag — count the events

An RTL pattern rather than a testbench one, but it is what the whole campaign came down to, and it is worth recognising in review.

XPM FIFO's `empty` deasserts one to two cycles _after_ a write. An FSM that decides a burst is finished by reading `empty` can retire while its final words are still in flight:

```systemverilog
// WRONG
FIFO_ST: if (!fifo_empty) next_state = FIFO_ST;
else             next_state = END_ST;   // and stream_en drops here
```

The stranded words never come out, and if one of them carries `tlast` the consumer hangs forever. Count the actual strobes instead:

```systemverilog
// CORRECT
always_ff @(posedge clk) begin
if (!rstn)   fifo_level <= '0;
else unique case ({fifo_wr_en, fifo_rd_en})
2'b10:   fifo_level <= fifo_level + 1'b1;
2'b01:   fifo_level <= fifo_level - 1'b1;
default: fifo_level <= fifo_level;
endcase
end

FIFO_ST: if (fifo_level == '0) next_state = END_ST;
```

The generalisation: **status flags are advisory, strobes are authoritative.** Anything that gates a completion decision, a `tlast`, or a handshake should be derived from the event itself. The same reasoning covers `fifo_wr_en` — write on `tvalid && tready`, never on `tvalid` alone, or a stalled cycle duplicates the beat.

---

## 17. Structure and Scope

To ensure maintainability and avoid compilation errors in large test suites:

1. **Variable Declarations in `SVTEST`**: Any variable used within a `` `SVTEST(name) ... `SVTEST_END `` block must be declared at the beginning of the block. Do not declare variables in the middle of the test logic.
2. **Helper Function Location**: The `_tests.sv` file must contain only the test cases. Any helper functions (e.g., reference models like `exp_mem` or complex checkers) must be placed in the `_tc00.sv` (or corresponding top-level test) file to avoid multiple-definition errors and keep the test list clean.

---

## 18. `axil_slv`: always connect `i_reg_is_readonly` explicitly

`axil_slv.sv` declares `input logic [NUM_REGS-1:0] i_reg_is_readonly = '0`, so it looks safe to leave unconnected when every register is plain `sw=rw`. In xsim it is not: for a parameter-sized vector port, an omitted connection resolves bit 0 to the declared default but leaves the remaining bits floating (`z`), rather than replicating the default across the whole width.

`axil_slv`'s write-enable guard is `!i_reg_is_readonly[reg_idx]`. `!1'bz` evaluates to `1'bx`, and `if (x)` is treated as false — so a write to any register index whose readonly bit floated is silently dropped. Register 0 writes fine (its bit happens to resolve to `0`), which is exactly the trap: a `tc_axi_register_round_trip` test that only checks register 0 passes while every other register is dead.

This was found via four IPs whose round-trip tests failed at the *second* register in the test (`tc_axi_register_round_trip::FAILED` on the second `reg_write`/`reg_read` pair, first one always green): `axis_sg_int4_v2`, `axis_readout_v2`, `axis_sg_mux8_v1`, `axis_sg_mixmux8_v1`. In `axis_sg_int4_v2` this was worse than a failed assertion: the dead register was `WE_REG` (envelope capture enable), so `axis_to_bram_sg`'s FSM never left `INIT_ST`, `s0_axis_tready` never asserted, and the testbench's unbounded `while (!tready)` wait in `load_envelope` spun forever — multi-GB VCD, simulator killed by hand.

```systemverilog
// WRONG — relies on the port default for every bit; only bit 0 gets it in xsim
axil_slv #(.NUM_REGS(NUM_REGS)) axil_slv_i (
    ...
    .o_slv_regs (slv_regs_o),
    .i_slv_regs (slv_regs_o)
);

// CORRECT — tie off explicitly, even when nothing is read-only
axil_slv #(.NUM_REGS(NUM_REGS)) axil_slv_i (
    ...
    .o_slv_regs        (slv_regs_o),
    .i_slv_regs        (slv_regs_o),
    .i_reg_is_readonly ('0)
);
```

The tell: `tc_axi_register_round_trip` (or equivalent) fails on a specific register, not on all of them, and the value read back is the register's *previous* contents (reset value or whatever the last successful write left), not X. If a downstream test hangs instead of failing, check whether the dead register gates a blocking wait in the testbench (a capture/write-enable bit) rather than just a datapath value.

---

## 19. Without a clocking block, `#TSU` is the contract — apply it at *every* edge

Sections 1, 8 and 9 all assume a clocking block. Some testbenches legitimately cannot use one: `xcom_async_tc00` drives three mutually asynchronous domains (`i_time_clk`, `i_core_clk`, `i_ps_clk`), so it declares its own convention instead —

```systemverilog
localparam time TSU = 1ns; // drive/sample offset from the clock edge
```

— and every stimulus is driven and sampled `#TSU` **after** the rising edge, never at it. That works, but unlike a clocking block nothing enforces it. It is a convention held up by hand, on every task, on every interface.

```systemverilog
// WRONG — drives AT the edge, racing the DUT's own always_ff
@(posedge tb_core_clk);
tb_i_core_op = {1'b0, op};
tb_i_core_en = 1'b1;

// CORRECT — the whole point of the convention
@(posedge tb_core_clk); #TSU;
tb_i_core_op = {1'b0, op};
tb_i_core_en = 1'b1;
```

**One omission is enough.** In `xcom_async_tc00` the AXI-Lite tasks honoured `#TSU` and the QP1 core-port task did not — two lines out of a 400-line bench.

**And the race is not stable across tool versions.** Those two lines passed 4/4 under xsim 2023.1 and failed under 2025.2, with no RTL change whatsoever: the newer scheduler resolved the race the other way, the DUT sampled the stale idle value, `i_core_en` was never observed, and no command was ever dispatched. A green testbench is not evidence that the convention was followed — it may only be evidence that today's simulator resolved the race in your favour. Treat a suite that breaks on a tool upgrade, with RTL untouched, as a race until proven otherwise.

**Corollary — debug from the source, not the sink.** That lost `i_core_en` surfaced thousands of cycles downstream as `rx_aligned=0`, `frm_valid=0` and a fixed `disp_err=23`: an almost perfect impression of an 8b/10b disparity or word-alignment fault, in a decoder already known to be fragile about running disparity. Two plausible hypotheses were chased and disproved there. What settled it in a single run was probing the *transmitter* instead: `link_tx.send_i` never asserted at all (`send_cyc=0`), so no frame had ever been sent and nothing downstream could have worked.

When a self-loopback fails, confirm the stimulus actually left the source before analysing the sink. The generalisation: **an absent stimulus and a corrupted one look identical at the far end of a pipeline** — distinguish them at the near end, where one probe separates the two, rather than at the far end, where every theory fits.

**A second case, and a different signature: a stimulus half-seen.** The `axis_avg_buffer` IP testbench drove `tvalid`/`tdata`/`trigger` with a blocking assignment right after `@(posedge axis_clk)`. Under xsim 2025.2 the FSM flops took the first sample of a capture and the write did not reach the memory (most likely the XPM model sampled `wea`, which is combinational from the same `tvalid`, before the change landed), so the sample was counted but never stored. With RTL untouched, the existing readback test was red and every readback came out **shifted by one word**: the first beat was whatever the memory held before, the data were `mem[addr-1 ...]`, the last captured word was missing, and a capture of N samples wrote N-1 words starting at address 1. That reads like an off-by-one in the RTL (the address counter, the reader), and the lower-level testbenches, which drive through a clocking block, were green. What settled it was a monitor on the *internal* write port (`mem_we`, `mem_addr`, `mem_di`) next to the FSM state and counters at every cycle: the counters were already one sample ahead of the memory on the first valid cycle. Signature to recognise: **counters ahead of the data, constant and data-independent, only in the testbench that drives raw signals at the edge.** The fix is the convention above (`@(posedge clk); #TSU;` before every drive and every sample), not an RTL change.

---

## 20. Clocking blocks can desync a DUT that wraps a Xilinx XPM primitive — use raw signals instead

`tag_fifo_dc` wraps `qick:mem:fifo_async` (an `xpm_fifo_async` wrapper, `READ_MODE="fwft"`) behind a small dma_clk-only ring buffer. Its testbench, written with the usual `default clocking cb @(posedge clk); output ...; input ...; endclocking` pattern used everywhere else in this repo, reproducibly dropped the *first* word of every burst: pushing `0x1000..0x1004` and draining produced `0x1001..0x1004` (and once, past a flush, silently ate two words in a row). `full`/`push_full`/`wr_rst_busy` all read `0` throughout — nothing on the write side ever reported backpressure. It looked exactly like an XPM ordering bug.

It was not. `fifo_async`'s own testbench (`fifo_async_tc00.sv`) deliberately does **not** use clocking blocks — its header says so explicitly ("SAMPLING CONVENTION (no clocking blocks, on purpose)") — and its `test01_basic_flow`/`test02_random_stress` push thousands of words through the exact same primitive, at a comparable clock ratio (307.2/100 MHz vs. this bench's 300/100 MHz), with zero loss (confirmed by re-running that suite with `make sim IP=fifo_async MODE=fwft`). Rewriting `tag_fifo_dc`'s testbench to drop the clocking blocks — plain `sig <= val; @(posedge clk);` for drives, a bare `@(posedge clk)` before reading a DUT output — fixed all four tests immediately, with no RTL change.

The generalisation: a clocking block's `output`/`input` skew (even the IEEE-default `#0`/`#1step`, with no explicit skew declared) is one more clock-domain-crossing-shaped thing sitting between the testbench and a DUT that itself contains a real, silicon CDC primitive. Two independent pieces of skew-sensitive logic stacked on top of each other is exactly the kind of interaction that is easy to get subtly wrong and hard to prove correct by inspection. When a DUT wraps `xpm_fifo_async`, `xpm_cdc_*`, or any other dual-clock Xilinx macro, prefer the convention that macro's *own* testbench uses — usually raw non-blocking drives before `@(posedge clk)` and raw reads right after it — rather than defaulting to this repo's usual clocking-block style. If a bench already uses clocking blocks and shows an unexplained "one beat lost/duplicated at a domain boundary, flags never indicate why" symptom, rewriting it without clocking blocks is a cheap, high-signal experiment before suspecting the RTL.

**Corollary:** when in doubt about whether a shared, already-ported primitive is misbehaving, run *that primitive's own testbench* in the configuration you actually need (here, `MODE=fwft`, since it defaults to `std`) before spending time distrusting or replacing it. It had 10/10 passing tests in that exact configuration the whole time.

---

## 21. A parameter chosen "to simplify the test" can change which cycle a valid flag and its data become consistent

Building `qick_time_tagger`'s end-to-end integration test, `CMP_INTER=0` was picked to sidestep the interpolator entirely. It broke the tag capture: `tag_vld_o` pulsed on the *same* cycle `qtt_tag_calc` scheduled `trig_time_adc_r`'s non-blocking update, one cycle before that update was actually visible on the signal — so `tag_mem`'s FIFO, which samples `tag_wr_i`/`tag_dt_i` together on the write edge, latched whichever value `trig_time_adc_r` held *before* this crossing (all-zero, for the first-ever trigger).

The cause: with `CMP_INTER=0`, `qtt_tag_calc` takes its `gen_no_inter` branch, where `x_inter_end` is wired straight to `trigger_cmp` with zero delay — and `tag_vld_o = arm_i & x_inter_end`. `trig_time_adc_r`'s own update fires on that identical `trigger_cmp` cycle, but as a registered (non-blocking) assignment, so it isn't visible until the next edge. Two signals that are supposed to be read together (a "valid" flag and the data it validates) were computed from the same event through pipelines of different depth (0 cycles vs. 1).

`CMP_INTER=1` (or higher) forces the real `x_inter` divider to run instead. Even fed `cfg_inter_i=0` at runtime — contributing zero interpolation bits, so the expected value is unchanged — `x_inter` still takes one cycle from `start_i` to `end_o`. That one cycle is exactly the margin `trig_time_adc_r` needed to settle before `tag_vld_o` (now gated by the *later* `x_inter_end`) samples it. The fix was a testbench parameter change, not an RTL change — `qick_time_tagger.sv`'s own default is `CMP_INTER=4`, so real deployments never take the zero-delay path this bit the test with.

The generalization: when a block exposes both a "this is valid now" pulse and the data it covers, and internally that pulse can be produced through **zero or more** pipeline stages depending on a parameter, picking the zero-stage configuration "to keep the test simple" can silently desynchronize the two — even though each one is individually correct for that configuration. Before trusting a same-cycle valid+data reading in a test, check whether the value's *own* update is combinational or registered relative to the same triggering event, and prefer whatever parameter value the real design actually deploys with over whatever configuration is cheapest to hand-compute an expected result for.

---

## 22. A behavioural model of a vendor IP must reproduce its valid timing, not just its latency number

`axis_kidsim_v3` passed all its SVUnit tests and did nothing on the RFSoC4x2: the output was the input on every
lane, `OUTSEL = 3` zeroed nothing, the carrier never turned. The DDS Compiler in it (`dds_phasegen_sincos_ow16_lat8`,
`Phase_Increment = Streaming`, no `TREADY`) was simulated with `dds_compiler_model`, whose pipeline ran every clock
and whose `m_axis_data_tvalid` was tied to 1. The `.xci` says `Latency = 8`, so the port counted the DDS as 8
clocks and set `kidsim_top`'s valid delay to match (`KIDSIM_LAT = 22`).

The real IP, run in xsim from its own simulation model (`dds_compiler_v6_0_28`, found in the generated project,
`<proj>.gen/sources_1/bd/<bd>/ip/<ip>/src/<variant>/sim/`), does something else: its pipeline moves only on the
input valid, the output valid comes out in the **same clock** as the input valid, and the word shown with it is
the output of the transaction 8 valids earlier. `Latency = 8` is a delay in *transactions*, not clocks. With the
real IP the kidsim datapath is 8 clocks shorter than the port assumed, so `kidsim_top`'s mux never saw the
processed sample's valid and always selected the bypass. The legacy RTL had the right numbers (2 and 14); the port
had "fixed" them to match the model.

What found it: simulating the packaged RTL with the vendor's own simulation model instead of the behavioural one
(`xvhdl -L dds_compiler_v6_0_28 <variant>.vhd`, `xelab -L dds_compiler_v6_0_28 -L xbip_utils_v3_0_15
-L axi_utils_v2_0_11 -L mult_gen_v12_0_24 -L xbip_dsp48_wrapper_v3_0_7 ...`; the libraries are precompiled in
`$XILINX_VIVADO/data/xsim/ip`). Two traps on the way: `mult_gen_v12_0` has its own `delay_line` entity, which
clashes with `qick`'s (rename ours in a scratch copy), and mixing timescaled and non-timescaled files needs
`xelab --timescale 1ns/1ps`.

The fix to the model (`PHASE_GATED = 1` in `dds_compiler_model`, set only by this variant) was checked by running
both side by side on 4000 clocks of random valids and pincs: identical valids, phase within 6/65536 turn. With it,
the old RTL fails the existing `kidsim_top` and `axis_kidsim_v3` tests, as it failed on the board.

The generalisation: when a behavioural model stands in for a vendor IP that has a `tvalid`, check against the
vendor's simulation model **how the output valid relates to the input valid** (every clock? same cycle? after N
clocks or N transactions?) for the exact configuration in the `.xci`, and model that. A latency number read from
the `.xci` does not say which of these it is, and a model that gets it wrong makes every test agree with the wrong
RTL. For a block that is fed sparse valids (here, one sample per `punct` frame), this is the difference between
working and doing nothing.

---

## 23. Check a vendor-IP model against the real IP with each consumer's actual input pattern

`dds_compiler_model`'s default mode (free-running, phase field taken as absolute, `pinc` ignored) was used by every
DDS Compiler wrapper in the repo, and every downstream suite passed. Compared against `dds_compiler_v6_0_28`
generated from each wrapper's own `.xci`, it was wrong for all six (errors ~full scale). The real core, as QICK
configures it (`Phase_Increment=Streaming`, `Phase_offset=Streaming`, `Resync=true`, no TREADY), keeps an
accumulator: per input transaction `acc = (resync ? 0 : acc) + pinc`, output `sin/cos(acc + poff)`, with
`tdata = {7'b0, resync, poff, pinc}`.

What made the model look right: QICK has two consumer patterns, and they drive the resync bit differently.
- `phase_ctrl_sgmux8` sends resync=1 every cycle with an absolute phase.
- `ctrl_sgv4`, `ctrl_sgv6`, `ctrl_ro_v2` and `ctrl_dyn_ro` pulse resync only when a descriptor loads, and let the
  core accumulate `pinc` in between.

A model that is off by one cycle for the first pattern also ignores accumulation completely for the second. Tests
that only check liveness ("output is nonzero", "tvalid rises") pass either way. `NEGATIVE_SINE` in one `.xci`
(`dds_compiler_readout`) was a third difference, found only because that variant alone failed the comparison.

The fix is the model's `PHASE_GATED=1, RESYNC=1` mode. It was checked per variant on three stimuli: resync every
cycle, resync only at segment starts, and the same with random valid gaps. Result: ≤ 19 counts error, identical
valid timing. Recipe: `create_ip` from the `.xci`'s own component parameters, then `generate_target simulation`,
`xvhdl -L dds_compiler_v6_0_28`, and run the model and the real core side by side.

The generalization: validate a vendor-IP model against the real IP's simulation model **per `.xci`** and **per
consumer input pattern** (which control bits toggle, and when), not once for the IP family. Also, `grep -r` does
not follow symlinks, and most `cores/lib/**/hdl/*.sv` files are symlinks into `firmware/rtl_lib/`, so use
`grep -R` when looking for a module's consumers.

---

## 24. A passing simulation doesn't mean synthesis can map the RAM, and XPM string parameters fail silently

`bram_tdp` was an inferred true-dual-port RAM: two `always_ff` ports, write-first (`doa_r <= dia` while writing),
reset with priority over enable. Every simulation suite passed. Vivado synthesis rejects the pattern whenever
**both ports actually write**:
- first `WARNING [Synth 8-6849] Infeasible attribute ram_style = "block"`
- then `ERROR [Synth 8-2914] Unsupported RAM template`

qick_processor's program, data and wave memories hit this, since both the core and the DMA write them.
Generators and buffers didn't, because they tie `web` to 0, which infers a simple dual-port RAM. The same template
written read-first maps to BRAM, so write-first on two write ports is the part Vivado can't infer.
`bram_tdp` is now `xpm_memory_tdpram`-backed with the same interface and semantics.

The XPM port hit a second trap. `CLOCKING_MODE("independent_clk")` is not a valid value: the valid ones are
`"common_clock"` and `"independent_clock"`. xpm_memory silently maps any unknown string to common clock
(`P_CLOCKING_MODE` falls through to 0). Both ports then run on `clka`, with no error or warning. An earlier XPM
version of this file had the same typo.

It only showed up as an irregular one-row lag in `sgv6_top`, whose two ports run on unrelated clocks. A
side-by-side xsim of the old inferred RAM against the XPM one pinned it down: equal clocks gave identical output,
and 10 ns vs 6.6 ns clocks made the XPM port-B output move on `clka` edges.

Rules:
- Any RAM/ROM change must run an out-of-context `synth_design` of the configuration that writes on both ports;
  xsim cannot tell you whether it maps.
- When replacing a primitive, compare old and new cycle by cycle in a tiny testbench with **unrelated clock
  periods**. Equal clocks hide clock-domain mistakes.
- Check every XPM string parameter against the XPM source (`xpm_memory.sv` has the `P_*` decode), not against
  memory.
- Tests that poke a memory by hierarchical name (`dut.x.ram[k]`) break when the implementation changes. The XPM
  array is `<inst>.u_xpm.xpm_memory_base_inst.mem`.

---

## 25. Queue at least two descriptors: single-descriptor tests can't see FIFO read semantics

The fusesoc `fifo_sync` is a plain first-word-fall-through FIFO: after a read, `dout` moves on to the next word.
The legacy QICK FIFO (`openquantumhardware/qick` `firmware/hdl/fifo_xpm.sv`, and the original `fifo.vhd`) behaves differently:
it shows the head word during the read cycle, then holds the word just read until the next read. Every legacy
descriptor controller latches the descriptor one cycle after `rd_en`, and depends on the legacy behaviour:
`ctrl_sgv6`, `ctrl_sgv4`, `ctrl_sgmux8`, `ctrl_dyn_ro` and `ctrl_ro_v2`.

With a plain FWFT FIFO, each descriptor was therefore played with the fields of the descriptor queued behind it.
`nsamp` was the exception, because it is taken at `rd_en`. This failed whenever two or more descriptors were
queued. Every test and bench passed anyway:
- The unit tests queue one descriptor at a time, or two identical ones.
- The dbg benches and the sgloop bench push descriptors from Python, milliseconds apart.

It showed up on the board, in the first real QickProgramV2 flat_top: three back-to-back descriptors, where the
plateau took the ramp-down's outsel and address and came out silent. Fix: `fifo_sync #(.HOLD_DOUT(1))` on the 8
descriptor FIFOs. Regression: `sgv6_top` `tc_flat_top_sequence`.

Rules:
- For any block fed from a FIFO, test at least two *different* entries queued back to back, and check that each
  one is consumed with its own fields.
- When porting a legacy block onto a new primitive (FIFO, RAM), diff the primitive's behaviour cycle by cycle
  against the legacy wrapper, not just against its datasheet. The legacy `fifo_xpm` was an XPM plus a 10-line
  workaround.

---

## 26. Drive the source past the end of the transaction, the way the real one does

`axis_streamer` passed 12/12 tests and hung on its first capture on the RFSoC4x2. Every one-shot test sent exactly
`NSAMP` words and then went quiet. The real source is an ADC: it keeps producing after the packet is complete, and
the write side only sees the end of the run a few clocks later. The words stored in that window were emitted after
the packet: a second short packet with `tlast` under `FLUSH = 1`, one stray beat under `FLUSH = 0`. The DMA was armed
for one transfer and never took them, so the block never reached DONE/IDLE. `tc11` already had a free-running source
(`send_words_freerun`), but only in continuous mode.

Rules:
- For every "stop after N" mode (one-shot, `NSAMP`, burst length), run at least one test where the source offers
  far more than N, as the deployed source does. Then check that exactly N come out, with nothing after, and that the
  block reaches its idle state with the sink still open.
- `expect_quiet()` after the last expected beat is what catches this. Stopping the stimulus at exactly N makes that
  check vacuous.
- Also stall the sink on the *last* beat while the source keeps running. That stall is where leftover words
  pile up, and where a loss counter can pick up samples that belonged to no transaction.

---

## 27. xsim hangs elaborating an event control on a clock picked by a run-time index

`axis_cdcsync_v1`'s testbench keeps two clock pairs in arrays (`logic sclk [2]`) and had helper tasks with
`@(posedge sclk[p])` and `@(posedge sclk[CP[c]])`, where `p`/`c` are task arguments or loop variables. xelab
compiled every module, then sat at 100 % CPU on the unit-test module for over 30 minutes with no message. Cut down
to the helpers alone it reported the real problem: `[XSIM 43-4398] Unable to find owning scope. Unresolved Hier
Name : c` followed by a SIGSEGV. The same `@(posedge sclk[P])` with `P` a localparam or genvar elaborates fine.

Rules:
- Never write an event control on an array element whose index is only known at run time. Pick the clock with an
  `if`/`case` in a small task (`wait_s(p)`: `if (p == 0) @(posedge sclk[0]); else @(posedge sclk[1]);`).
- If xelab runs for minutes on a testbench module with no progress, bisect by deleting blocks (checkers, drivers,
  tests, helpers) with a short `timeout`; the reduced design often prints the error the full one hangs on.
- Put the elaboration under a `timeout` in any unattended run: a hung xelab otherwise looks like a slow build.

---

## 28. xsim compares two wide queue elements wrong: copy them out first

`pimod_pfb`'s behavioural test logged 256-bit output words in a queue and counted frame flips with
`o_data[n] !== o_data[n-1]`. It counted 0 although the words alternated every 8 (printed side by side, and
`o_data[n] === wn` was 1). Reduced (Vivado 2025.2 xsim): for queue elements wider than 64 bits, `q[i] != q[j]` and
`q[i] !== q[j]` both evaluate to 0 even when the elements differ. An element against a plain variable (`q[i] !== a`)
is right, and so are elements of 64 bits or less. Nothing warns, and a check like this passes vacuously.

Rules:
- Never compare two elements of a queue (or, to be safe, of any dynamic array) of vectors wider than 64 bits with
  each other directly. Copy them into local variables first (`cur = q[n]; prev = q[n-1]; if (cur !== prev)`).
- A scoreboard that pops into a local struct and compares it with a DUT signal is fine; that is element vs.
  variable.
- When a "this changes" or "these differ" check passes suspiciously easily, force the difference once and check
  that it is seen.

---

## 29. Both sides of a CDC need the same reset, or the crossing invents a transfer

Found in `xcom_async_txrx`, a core still in development (2026-09-29). Its `u_cdc_rx_word` (`cdc_handshake`) crosses decoded frames
from the link RX clock to the dispatch clock; the source side is reset by `i_rx_rstn` and the destination side by
`i_rstn`. When the testbench pulses `i_rx_rstn` alone (what the board does when the RX link re-locks), `req_r`
returns to 0 while the destination's `req_sync_d` is still 1. `cdc_handshake` detects transfers as *toggles*, so
that asymmetry is indistinguishable from a real request: the destination fires `o_valid` and delivers whatever is
on the data bus. There it was an all-zeros word, decoded downstream as a broadcast command that was executed.
Every RX reset injected one phantom command. `cdc_handshake` 1.1.0 makes each side watch the other's reset.

Rules:
- A toggle-based handshake CDC assumes its two sides reset together. If they cannot, reset the destination from
  the source's reset (synchronized in), or use a level/`valid`-based scheme that has no hidden state.
- Test resets asymmetrically on purpose. A testbench that only ever asserts all resets at once cannot see this
  class of bug.
- An unexpected transfer whose payload is all zeros, right after a reset, is the signature: check `req_r` against
  `req_sync_d` at that moment rather than hunting the upstream data path.

