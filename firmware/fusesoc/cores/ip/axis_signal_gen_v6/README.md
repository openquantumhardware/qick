# Arbitrary Signal Generator v6 (axis_signal_gen_v6)

The waveform engine of the QICK v2 firmwares: it reads 160-bit pulse descriptors from the tProcessor, plays a per-lane
envelope from block RAM, up-converts it with `N_DDS` (16) parallel DDS carriers, applies a per-pulse gain with
saturation, and drives a 16-samples-per-clock AXI4-Stream bus straight into a DAC. Supersedes SG-v5 with a fixed-rate
output contract, a free-running phase reference (phase-coherent pulses without an explicit reset), and per-lane Q15
scaling with saturation.

- Project: QICK, `qick:ip:axis_signal_gen_v6:1.0.0` (module `axis_signal_gen_v6`, `N_DDS = 16` internally)
- Driver: `AxisSignalGen` in `qick_lib/qick/drivers/generator.py`, the `QickSoc` generator class (`soc.gens`), shared
  with v4/v5, with full `load()`/envelope-DMA support. It binds this core's `qick:ip:axis_signal_gen_v6:1.0` and the
  legacy vendors, and switches `env_full_scale` on for the fusesoc build. `driver/axis_signal_gen_v6.py` is an alias of
  that module (`firmware/docs/user/IP_INTEGRATION.md`). The standalone skeleton `AxisSignalGenV6` that used to
  live there bound the same VLNV and was removed on 2026-09-25.
- Hardware bring-up: see U8 (RFSoC4x2, driven by the fusesoc tProc v2).

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
                       AXI4-Lite (s_axi_aclk)
   Python / tProc ───────────► START_ADDR_REG, WE_REG   (envelope writer regs)
                                     │
   envelope samples                  ▼
   ───────────────► s0_axis ──► axis_to_bram_sg_nt ──► BRAM_real[0..15]  ┐
   (s0_axis_aclk,                (one-hot bank demux)   BRAM_imag[0..15]  │
    32-bit I/Q)                                                           │
                                                          shared mem_addrb ◄───┤
   descriptors                                                                 │
   ───────────────► s1_axis ──► fifo_sync ──► ctrl_sgv6 ──► sgv6 datapath ◄────┘
   (aclk, 160-bit)              (16 deep)     (sequencer)   envelope × DDS,
                                                            gain, saturation
                                                                  │
                                                                  ▼
                                                     m_axis ──► DAC (16 samples/clock)
```

**Three independent clock domains:**

| Domain | Signal | Role |
|---|---|---|
| Config | `s_axi_aclk` | envelope-writer registers (`START_ADDR`, `WE`) via AXI4-Lite |
| Write | `s0_axis_aclk` | envelope sample stream into BRAM port A |
| Datapath | `aclk` | descriptor FIFO, `ctrl_sgv6`, BRAM port B read, DDS, output |

The dual-clock BRAM (`bram_tdp`) resolves the write<->datapath crossing; `cdc_gray_sync` carries `WE` into the write
domain; the whole crossing set is covered by `set_clock_groups -asynchronous` across the three clocks in
`constraints/axis_signal_gen_v6.xdc`.

**Envelope memory layout.** 16 parallel banks, each 16 bits wide and `2**N` deep. Sample `k` of a waveform lives in
**bank `k mod 16`, row `k / 16`**. One output beat reads **one shared row** across all 16 banks, emitting samples
`[r*16 .. r*16+15]` in parallel: there is a single read address `mem_addrb` for every bank, so a frame straddling two
rows cannot come from the read side (U7).

Two synthesis modes (`GEN_DDS` parameter): `"TRUE"` up-converts with the DDS, `"FALSE"` is baseband envelope only.
Two envelope types (`ENVELOPE_TYPE`): `"COMPLEX"` (separate real/imag banks) or `"REAL"` (imag forced to zero). The
legacy `RNDQ_REG` is a deprecated no-op, kept only for register-map compatibility.

## U2. Rules that are not obvious

- **The descriptor arrives from the tProcessor, not from Python.** The 160-bit word on `s1_axis` is compiled by the
  `asm_v2` layer / generator manager from `AveragerProgramV2.add_pulse(...)` (`freq`, `phase`, `gain`, `envelope`,
  `style`, `length`, ...). The only PYNQ-side path into this block is the **envelope loader** -- a DMA into BRAM
  gated by `START_ADDR_REG` / `WE_REG`, which `AxisSignalGen.load()` drives.
- **`nsamp` in the descriptor is a per-cycle countdown, not a sample total.** `ctrl_sgv6` loads `cnt_nsamp_r` from it
  and decrements it once per `aclk`, returning to the read state when it reaches 2. A burst lasts ~`nsamp` **output
  beats**, and each beat emits 16 samples; confirm the `length_in_samples <-> nsamp` conversion in the software
  generator manager before trusting a raw `nsamp` as "samples" (U7, U8). Measured in the `ctrl_sgv6` tests: a
  descriptor lasts exactly `nsamp` clocks for `nsamp` 2 to 65535. **`nsamp` 0 and 1 stall the generator**: the countdown
  passes 2 and the next descriptor is read about 2^16 clocks later. qick_lib refuses lengths below 3; a raw descriptor
  must keep `nsamp` >= 2 (kept in the RTL).
- **`sgv6` is a fixed-rate source: `tready` is not honoured.** Once a descriptor starts, it emits one output beat per
  `aclk` for the whole burst, deliberately, because the real sink (a DAC) is always ready. **Do not place a blocking
  element downstream** (a FIFO that can fill, a DMA, a resampler that can stall) without adding a `tready`-gated
  global enable across the *entire* pipeline first -- a single output FIFO is not enough, the generator keeps
  producing and overruns it silently.
- **The phase is referenced to free-running time, not to the pulse start, unless `phrst = 1`.** The phase at output
  beat `r`, lane `i` is `phase_descriptor + pinc * (cnt_n(r) + i)`, where `cnt_n` is a **non-stop** counter
  (`cnt_n <= cnt_n + 16` every cycle) reset only on `sync_reg && phrst`. With `phrst = 0` this is exactly what makes
  separate pulses mutually phase-coherent -- but it also means a pulse's phase-0 crossing lands wherever the
  free-running count happens to be, which looks like a bug the first time you see it. Set `phrst = 1` when you need
  the first output beat to start at exactly `phase_descriptor` (measured: with `phrst=1` the crossing is on beat 0
  with no fractional latency; with `phrst=0` it can land several beats in).
- **The phase advance is split across two pieces of hardware, and getting this wrong silently doubles the output
  frequency.** Each lane's 72-bit DDS control word is `{7'h00, sync, phase_v1[i], pinc_n}`: the low 32 bits
  (`pinc_n = pinc * 16`) are the DDS Compiler's own streaming phase increment -- **the RTL never accumulates this
  term**, the IP does, once per beat. The high 32 bits (`phase_v1[i] = i*pinc + phase_0`) are the per-lane *offset*,
  added (not accumulated) by the IP every cycle, where `phase_0 = pinc * cnt_n_reg + phase_descriptor` and
  `cnt_n_reg` is a **snapshot** of `cnt_n`, latched once per pulse (`if (sync_reg_r1) cnt_n_reg <= cnt_n;` -- not an
  unconditional copy). If that gate is ever removed so `cnt_n_reg` follows `cnt_n` every cycle, the RTL accumulates
  as well as the DDS Compiler and the output frequency comes out at exactly double the request -- this shipped once
  (U7, U8) and was found on real hardware, not in simulation, because the simulation model of the DDS Compiler does
  not accumulate its own streaming phase the way the real Vivado IP does (U8).
- **Amplitude.** The envelope x DDS product quantises at `[30:15]` (full Q15 scale); the gain stage saturates to
  **+-MAXV = 32766** (not 32767) via a 17-bit rounded intermediate, clamping instead of wrapping, and sets the sticky
  `STATUS_REG.SATURATING` flag (clear it with `CTRL_REG.SAT_CLEAR`). A cosine reference model that uses 32767 will
  differ by 1 LSB at the peaks -- expected.

## U3. Data formats

The 160-bit descriptor on `s1_axis`:

| bits | field | width | meaning |
|---|---|---|---|
| 159..149 | -- | 11 | unused |
| 148 | `phrst` | 1 | phase reset (U2) |
| 147 | `stdysel` | 1 | steady-value select at the end of the waveform |
| 146 | `mode` | 1 | 1 = periodic / non-stop |
| 145..144 | `outsel` | 2 | output source: 0 product, 1 DDS only, 2 envelope only |
| 143..128 | `nsamp` | 16 | burst length, a per-cycle countdown (U2) |
| 127..112 | -- | 16 | unused |
| 111..96 | `gain` | 16 | output gain (signed) |
| 95..80 | -- | 16 | unused |
| 79..64 | `addr` | 16 | envelope start row in memory |
| 63..32 | `phase` | 32 | initial phase (`2^32` = 360 degrees) |
| 31..0 | `freq` | 32 | phase increment `pinc` (0 = DC, `2^31` = Nyquist) |

Output `m_axis_tdata`: 16 lanes of 16-bit signed samples per clock. Envelope memory words (loaded via `s0_axis`):
32-bit, I in `[15:0]`, Q in `[31:16]`, one word per BRAM row per bank (U1, U4).

## U4. Memories, throughput and limits

- Envelope memory: 16 banks x `2**N` rows (parameter `N`, packaged default matches the block design).
- Descriptor FIFO: 16 entries (`fifo_sync`).
- Output: 16 samples per `aclk` cycle, fixed rate, no back-pressure (U2).

## U5. Python quick start

```python
g = soc.axis_signal_gen_v6_0
g.regs.CTRL_REG.SAT_CLEAR.write(1)           # clear the sticky saturation flag
print(g.regs.STATUS_REG.SATURATING.read())
```

Envelopes are loaded by `AxisSignalGen.load()` over the AXI DMA and pulses are played by the tProc program
(`add_pulse`, compiled by `asm_v2`); registers are only needed for the saturation flag.

**Sweeping an envelope parameter (DRAG alpha, Gaussian sigma).** The envelope address is not sweepable in `asm_v2`, so
the sweep is a Python loop. Build the program once and per point only reload the samples at the same address, instead
of building a new program per point:

```python
prog = MyProgram(soccfg, reps=R, final_delay=..., cfg=cfg)           # built and compiled once
addr = prog.envelopes[gen_ch]['envs']['drag']['addr']
for data in envelopes:                                               # int16 samples, same length for every point
    soc.load_envelope(gen_ch, data=data.tolist(), addr=addr)
    iq = prog.acquire(soc, load_envelopes=False)
```

Measured on the RFSoC4x2 (384-sample DRAG, 21 points): fixed cost per point 20.5 ms with
a new program per point (12.4 ms of it is building and compiling), 7.5 ms with the reload above, 1.2 ms for a sweep in
the tProc loop. With 1000 reps and a 100 us relax delay the reload loop is 6 % slower than a real-time sweep; the
difference matters only for short relax delays or few reps.

## U6. Using it in a block design

- `s0_axis` <- an AXI DMA (through a stream switch if shared); `s1_axis` <- a tProc output port; `m_axis` -> the RFDC
  DAC stream (16 samples per clock), `aclk` = that DAC tile's stream clock.
- `s_axi` -> the PS interconnect, a separate clock domain.
- Parameters: `N` (envelope address width per bank), `GEN_DDS`, `ENVELOPE_TYPE` (U1).
- Constraints: `constraints/axis_signal_gen_v6.xdc` (+ `_ooc.xdc`) already declare the three clocks as an asynchronous
  group and a false path on the descriptor input; `axis_signal_gen_v6.clock_domains.yaml` tells the IP packager which
  clock/reset belongs to `s0_axis`.
- **Driver binding:** `AxisSignalGen` binds `qick:ip:axis_signal_gen_v6:1.0` (see the driver note at the top).

## U7. Gotchas

Found during the verification campaign; each one cost real debugging time, so read the ones that apply before
touching `ctrl_sgv6` or the phase datapath.

| Gotcha | What happens | What to do |
|---|---|---|
| Removing the `cnt_n_reg` gate (`if (sync_reg_r1) cnt_n_reg <= cnt_n;`) because simulation looks "frozen" | Real hardware plays every pulse at exactly double the requested frequency, with beat-rate images | Leave the gate; the simulation model of the DDS Compiler is not faithful (U8), not the RTL |
| Checking DDS values against a cosine model at an arbitrary `pinc` | Sign flips: the free-running phase offset rotates which beat you sampled | Use a beat-aligned `pinc` (a multiple of `2^28`) or a model invariant to starting phase (U8) |
| Assuming `phase = 0` at beat 0 | True only with `phrst = 1`; with `phrst = 0` the crossing can land several beats in | Set `phrst = 1` for an absolute phase reference (U2) |
| Lowering `m_axis_tready` and expecting stable `tdata`/`tvalid` | `tready` is not honoured; a compliant-master assertion would fire (by design) | Do not gate this source's output without pipeline-wide back-pressure (U2) |
| Loading an envelope with a driver that pre-asserts `tready` while idle | The first sample can be dropped by the loader, not the RTL, if the driver advances on a single clocking edge | Present the beat, hold `tvalid`, advance only when `tready` was sampled high (this was a testbench bug, not an RTL one, U8) |
| `RNDQ_REG` | No effect | Deprecated, ignore it |

## U8. Validation status

- **Hardware (RFSoC4x2, 2026-09-24):** driven by the fusesoc tProc v2 with a debug bench, a one-channel reduction of `4x2/tpv2_std` built only from fusesoc IPs, driven by standard `QickSoc` + `AveragerProgramV2` programs: const, gaussian `arb` and
  `flat_top` pulses, gain/phase sweeps, a 50-1000 MHz frequency sweep and `phrst`, all passing. That run found two bugs, both fixed: back-to-back descriptors played
  with the next descriptor's fields (descriptor FIFO read semantics, `fifo_sync` `HOLD_DOUT`; flat_top's plateau was
  silent), and qick_lib not following the full-scale envelope fix (flat_top plateau at half the ramps; now
  `env_full_scale`). Timing at 614.4 MHz: the complex product missed by -24 ps in the full design (two DSP ALUs per
  cycle); it was re-pipelined to one ALU per cycle, +80 ps out of context.
- **Simulation: 15 SVUnit tests, all passing**: `tc_reg_readback`, `tc_pure_tone_all_lanes`, `tc_phase_offset`,
  `tc_frequency_sweep_exact`, `tc_frequency_unaligned_across_beats` (passes since `dds_compiler_model` models the real
  core's accumulator, 4124ed5e), `tc_modulated_pulse_all_lanes`, `tc_envelope_only_all_lanes`, `tc_gain_scaling`,
  `tc_sat_status_reg`, `tc_gaussian_envelope`, `tc_fixed_rate_ignores_tready`, plus 4 diagnostic dumps. `sgv6_top`
  adds `tc_flat_top_sequence` (three different back-to-back descriptors). Lint clean
  (`make lint IP=axis_signal_gen_v6`).
- Not verified: `N_DDS` other than 16 on hardware; `outsel='input'` and periodic mode through the tProc.

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `s_axi_*` | | AXI4-Lite slave (`s_axi_aclk`) |
| `s0_axis_aclk`, `s0_axis_aresetn`, `s0_axis_tdata/tvalid/tready` | | envelope stream (32-bit) |
| `aclk`, `aresetn` | in | datapath clock and reset |
| `s1_axis_tdata[159:0]`, `tvalid`, `tready` | | descriptors; `tready = ~fifo_full` |
| `m_axis_tdata[255:0]`, `tvalid` | out | 16 x 16-bit samples per clock; `tready` ignored (U2) |

## Registers

The driver class `AxisSignalGen` keeps a hand-written dictionary of this map, with the attribute names the software uses (`start_addr_reg`, `we_reg`, `rndq_reg`). `START_ADDR_REG` and `WE_REG` (words 0 and 1) are wired in the legacy v4, v5 and v6 generators too; `RNDQ_REG` (word 2) only in the v4. `STATUS_REG` and `CTRL_REG` (words 3 and 4, the saturation flag) exist only in this core and have no attribute yet. The indexes are the ones the driver has always used.

| Addr | Register | Field | Access | Description |
|---|---|---|---|---|
| 0x00 | `START_ADDR_REG` | `START_ADDR[31:0]` | RW | envelope write start address |
| 0x04 | `WE_REG` | `WE[0]` | RW | envelope write enable (a level) |
| 0x08 | `RNDQ_REG` | `RNDQ[31:0]` | RW | deprecated dummy |
| 0x0C | `STATUS_REG` | `SATURATING[0]` | R | sticky: output was clamped to +-MAXV |
| 0x10 | `CTRL_REG` | `SAT_CLEAR[0]` | RW | write 1 to clear `SATURATING` |

Source: `rdl/axis_signal_gen_v6_regmap.rdl`. Same register shape as `axis_signal_gen_v4` (no `OUTSEL_REG`: `outsel` is
per-descriptor here, not a static register).

## Internal architecture

Two RTL layers: `sgv6_top` (`qick:dsp:sgv6_top`) assembles the memory subsystem around the `sgv6` (`qick:dsp:sgv6`)
datapath, which wraps `ctrl_sgv6` (the sequencer) and the per-lane arithmetic.

**`sgv6_top`:** `fifo_sync` (160-bit descriptor FIFO, depth 16, `fifo_wr_en = s1_axis_tvalid & s1_axis_tready` --
qualified on both handshake sides, not `tvalid` alone), `axis_to_bram_sg_nt` (envelope stream to shared BRAM write
port with one-hot bank select), 16 x `bram_tdp` real + 16 x imag (dual-port dual-clock, `OUT_REG_B = 1`, a 2-cycle
read latency matched to `sgv6`'s 2-cycle mux delay; real/imag of a lane share `mem_addrb`/`mem_en` so I and Q stay
coherent), and `sgv6` itself.

**`ctrl_sgv6`:** a two-state one-hot FSM (`READ_ST`: pop the FIFO when a descriptor is available or `mode` is set,
load `cnt_nsamp_r`; `CNT_ST`: decrement each cycle, return to `READ_ST` at 2), producing the per-lane DDS control
word, the envelope read address (`addr_cnt`, one row per beat), gain, `outsel`, `stdysel` and enable, each aligned to
the datapath latency through fixed pipelines. The phase-generation logic is described in U2.

**`sgv6`:** for each of 16 lanes, reads the envelope, multiplies by the DDS carrier (optionally), applies gain,
rounds with saturation, and drives 16 bits of the output bus; `outsel` selects product / DDS-only / envelope-only.
Fixed `delay_line`s align the DDS, memory, gain, `src`, `stdy` and `en` pipelines. `o_axis_tvalid = en_la_r`;
`o_sat = |sat_lane`.

Latency is not exhaustively documented here; the invariant is that every path is padded so the frame at `m_axis` is
internally consistent -- do not add or remove a register on one path without re-balancing the others.

## Verification

`tests/axis_signal_gen_v6_tests.sv` (11 tests) + 4 diagnostic-dump probe files (`dds_phase_probe.sv`,
`mem_skew_probe.sv`, `mem_write_probe.sv`, `write_startup_probe.sv`), included via `axis_signal_gen_v6_tc00.sv`. See
U8 for the current pass/fail breakdown. `make sim IP=axis_signal_gen_v6`, `make lint IP=axis_signal_gen_v6`.

Testbench notes worth carrying to other blocks (learned here the hard way):
- Sample the output through the clocking block (`m_if.s_cb.tdata`), never a raw `@(posedge aclk)` -- raw sampling
  catches the wrong beat.
- Value-check DDS tones only at beat-aligned frequencies (`pinc` a multiple of `2^28`), or use a model invariant to
  the starting phase, such as the sampled-cosine recurrence `x[n-1] + x[n+1] = 2*cos(2*pi*pinc/2^32) * x[n]`, which
  holds for any starting phase and survives pipeline latency and gain scaling -- `tc_frequency_unaligned_across_beats`
  uses it (and is the one currently failing for the reason in U8, not because the technique is wrong).
- The sink is a DAC, always ready: model `tready` tied high, and bracket the one deliberate `tready`-drop test with
  `$assertoff`/`$asserton` so the `axi4_stream_if` protocol assertions do not fire outside that window.
- A guarded capture must gate on `tvalid`; reading a fixed number of clocking-block ticks without checking it
  re-reads held or post-burst data.
- Dump raw signals and read them; fitting a phase model to output values alone repeatedly produced a plausible but
  wrong diagnosis on this block (U7's `cnt_n_reg` story).
- `-d SVUNIT` must be in `xelab_options`, or the `axi4_stream_if` protocol assertions never compile (and when they do
  fire, they can corrupt the SVUnit pass counter).

## Files

```
cores/ip/axis_signal_gen_v6/
  README.md
  axis_signal_gen_v6.core                  # VLNV qick:ip:axis_signal_gen_v6:1.0.0
  axis_signal_gen_v6.clock_domains.yaml    # clock/reset for s0_axis, read by the packager
  hdl/axis_signal_gen_v6.sv                # AXI-Lite wrapper (axil_slv) + sgv6_top (rtl_lib/dsp)
  rdl/axis_signal_gen_v6_regmap.rdl
  constraints/axis_signal_gen_v6.xdc, axis_signal_gen_v6_ooc.xdc
  driver/axis_signal_gen_v6.py             # alias of qick_lib/qick/drivers/generator.py (AxisSignalGen)
  driver/tests/test_axis_signal_gen_v6_regs.py
  tests/                                   # 11 tests + 4 diagnostic probes
  data/axis_signal_gen_v6.gtkw
```

Datapath: `rtl_lib/dsp/sgv6.sv`, `sgv6_top.sv`, `ctrl_sgv6.sv`, `rtl_lib/axi/axis_to_bram_sg_nt.sv`. Shared building
blocks (`bram_tdp`, `fifo_sync`, `delay_line`, `cdc_gray_sync`, `dds_compiler_signal_gen`) are verified in their own
suites; the sim model of the DDS Compiler is `dds_compiler_model.sv` (see U8 for its known limitation).

## Open items

- Behaviour pytest of `AxisSignalGen` (envelope load, saturation flags, `env_full_scale`), IP_INTEGRATION.md D4.
- Make `dds_compiler_model.sv` faithful to the real DDS Compiler's streaming-phase behaviour (accumulate the low bits
  *and* add the high bits as an offset), after making the phase tests phase-agnostic first (`
  tc_frequency_unaligned_across_beats` is the pattern) -- doing this before the tests are phase-agnostic breaks the
  whole suite, since it currently asserts absolute phase that a free-running accumulator does not guarantee.
- Confirm the `length <-> nsamp` (samples vs. beats) mapping in the `asm_v2` generator manager and reflect it here.
- Re-run a spectral validation of the phase datapath (requested frequency against measured, images, with the
  `cnt_n_reg` gate of U2 and U7) on an RFSoC board (4x2 or ZCU216) against the current sources.
