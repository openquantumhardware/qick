# AXI4-Stream Capture Buffer for DMA Readout (`streamer` / `axis_streamer`)

Dual-clock capture buffer that sits between a free-running data source (an ADC,
a decimator, any DSP chain output) and an AXI DMA. It stores an incoming
AXI4-Stream into an asynchronous FIFO and re-emits it as packets of `NSAMP`
beats, each terminated by `tlast` so the DMA can close a descriptor.

- Project: CONTROLLERS · VLNV: `qick:ctrl:streamer:1.0.1`, `qick:ip:axis_streamer:2.0.1`
- Author: @lharnaldi · Target: zcu216 (xczu49dr-ffvf1760-2-e)
- Status: **core 10/10 SVUnit (single-clock and dual-clock), wrapper 12/12
  SVUnit, both with the `axi4_stream_if` protocol assertions active. Buffer
  FIFO (`qick:mem:fifo_async`) 10/10 independently. Block-RAM configuration
  (`FIFO=1024 MEM=block`) verified on both.** Pending: lint, XDC, `.rdl` +
  driver, IP packaging. See §7.

---

## Table of Contents
1. [Overview](#1-overview)
2. [Core: `streamer`](#2-core-streamer)
3. [Wrapper: `axis_streamer`](#3-wrapper-axis_streamer)
4. [SIZING: FIFO depth ↔ AXI DMA configuration — READ THIS](#4-sizing-fifo-depth--axi-dma-configuration--read-this)
5. [PYNQ usage](#5-pynq-usage)
6. [Files & build](#6-files--build)
7. [Open items](#7-open-items)

---

## 1. Overview

```
                          AXI4-Lite (s_axi_aclk)
   Python (PYNQ) ──────────────► axil_slv ──► START/FLUSH/MODE/NSAMP
                                     ▲         │
                                LOST │  STATUS │ (6 × cdc_bit_sync)
                                     │         ▼
   ADC / DSP chain                ┌──────────────────────────┐
   ────────────────► s_axis ─────►│  fifo_async (fwft, XPM)  │
   (s_axis_aclk,                  │        N_FIFO deep       │
    free-running)                 └────────────┬─────────────┘
                                               │  (m_axis_aclk)
                                        ┌──────▼───────┐
                                        │ beat register│  tlast travels
                                        │ + packet FSM │  with the beat
                                        └──────┬───────┘
                                               ▼
                                            m_axis ──► AXI DMA (S2MM) ──► DDR
```

**Three clock domains**, all independent:

| Domain | Signal | Typical | Carries |
|--------|--------|---------|---------|
| Config | `s_axi_aclk` | 100 MHz | AXI4-Lite register access |
| Write | `s_axis_aclk` | 307.2 MHz | the sample stream from the source |
| Read | `m_axis_aclk` | 100–250 MHz | the packet stream to the DMA |

Typical use (one-shot snapshot over DMA):

1. SW polls `STATUS.IDLE`, writes `NSAMP` / `MODE` / `FLUSH`.
2. SW writes `START = 1` → the block arms and starts capturing.
3. The buffer fills at the source rate; the DMA drains at its own pace.
4. After `NSAMP` beats the final beat carries `tlast`, the DMA closes its
   descriptor, and `STATUS.DONE` goes high.
5. SW writes `START = 0`, polls `STATUS.IDLE`, then reads `LOST`.

### 1.1 What makes this block different from `mr_buffer_et`

Both capture and drain over DMA, but they solve different problems:

| | `mr_buffer_et` | `streamer` |
|---|---|---|
| Trigger | external hardware trigger | software `START` |
| Storage | `NM` × true-dual-port BRAM, addressed | single async FIFO, streaming |
| Channels | `NM` parallel, serialised on readout | one stream |
| Capture length | fixed `2**N` per channel | `NSAMP`, programmable at runtime |
| Readout | always the whole window | packets of `NSAMP`, repeatable |
| Continuous mode | no | yes (`MODE=1`) |

Use `mr_buffer_et` for a triggered multi-channel snapshot; use `streamer` for
software-controlled capture of a single stream with programmable packet
boundaries.

---

## 2. Core: `streamer`

### 2.1 Parameters

| Param | Default | Meaning |
|-------|---------|---------|
| `B_TDATA` | 16 | input `tdata` width |
| `B_TUSER` | 8 | input `tuser` width (side-channel, stored with the data) |
| `B_AXIS` | 32 | output `tdata` width; upper bits are zero-padded |
| `N_FIFO` | 16 | buffer depth, power of two, ≥ 16 — **see §4** |
| `FIFO_MEM_TYPE` | `"auto"` | XPM storage primitive. `"auto"` lets Vivado pick — LUTRAM when shallow, block RAM when deep. Override with `"distributed"` or `"block"`. See the note below on `"ultra"` |

> ⚠️ **Parameters forwarded to XPM must stay UNTYPED, and their defaults must be
> plain string literals.** Untyped, because XPM bit-slices these parameters as
> packed vectors and a SystemVerilog `string` is a dynamic type whose indexing
> means something else — that is what broke `fifo_sync`'s `USE_ADV_FEATURES`
> (commit *"fix a parameter passing to xpm instantiation"*). Plain literal,
> because Verible's `explicit-parameter-storage-type` rule exempts untyped
> parameters with a string-literal default but flags one whose default is an
> expression such as a ternary. Get both right and no lint waiver is needed.
>
> `"ultra"` (URAM) support depends on the XPM version — the doc header in the
> legacy `fifo_dc_axi` lists only `auto`/`block`/`distributed`. Check yours
> before relying on it.

Stored word width is `W_FIFO = B_TDATA + B_TUSER` (24 bits by default). The
output pads to `B_AXIS`, so `B_AXIS ≥ W_FIFO` is required.

### 2.2 Ports

```
s_axis_aclk, s_axis_aresetn          // write domain
s_axis_tvalid, s_axis_tready
s_axis_tdata [B_TDATA-1:0]
s_axis_tuser [B_TUSER-1:0]

m_axis_aclk, m_axis_aresetn          // read domain
m_axis_tvalid, m_axis_tready
m_axis_tdata [B_AXIS-1:0]
m_axis_tlast

start_reg, flush_reg, mode_reg       // control, level signals
nsamp_reg [31:0]
lost_reg  [31:0]                     // s_axis domain
o_status  [5:0]                      // MIXED domains, see §3.2
dbg_probe [31:0]                     // ILA probe
```

⚠️ Do not rename the `s_axis_*` / `m_axis_*` ports: Vivado infers the
AXI4-Stream interfaces from exactly these names during IP packaging.

### 2.3 FSM

```
IDLE ──(START & NSAMP≠0 & fifo_empty)──► RUN
RUN  ──(!START)───────────────────────► WAIT_END
RUN  ──(tlast delivered & MODE=0)─────► WAIT_END      (one-shot)
RUN  ──(tlast delivered & MODE=1)─────► RUN           (continuous)
WAIT_END ──(write side stopped & drained)──► END
END  ──(!START)───────────────────────► IDLE
```

`WAIT_END` behaviour depends on `FLUSH`:

- `FLUSH = 1` → the partial packet is drained and **its last beat carries
  `tlast`**, so the DMA closes the descriptor cleanly.
- `FLUSH = 0` → the partial packet is **discarded**. At most one beat escapes:
  the one already presented on the bus with `tvalid` high, which must complete
  its handshake because withdrawing `tvalid` would violate AXI4-Stream. This is
  a deliberate, documented deviation from the legacy implementation, which could
  only ever present a beat while `tready` was already high.

`FLUSH` only concerns a packet truncated by `START = 0`. A one-shot packet that
completed is not truncated: the source (an ADC) keeps producing after its last
word, and the write side only sees the end of the run a few `s_axis_aclk`
cycles later, so a few more words land in the FIFO. They belong to no packet.
Once the last word of the one-shot packet has been captured, the FIFO is read
and discarded whatever `FLUSH` says, and nothing follows the packet:

- in 1.0.0 they came out as a second, short packet with `tlast` (`FLUSH = 1`)
  or as one stray beat (`FLUSH = 0`). A DMA armed for one transfer never takes
  them, so the block stayed in `WAIT_END` and never reached `DONE`/`IDLE`
  (found on the RFSoC4x2, with a debug bench);
- a sink stalled on the last beat no longer lets the FIFO overrun behind it,
  so that stall does not show up in `LOST`.

### 2.4 Key design decisions (and why)

- **Output beat register carries `tlast` with the data.** `{last_dout, last_dv,
  last_cnt}` move together, so backpressure can never separate a beat from its
  end-of-packet marker. The legacy implementation recomputed `tlast`
  combinationally every cycle and could drop it if `tready` fell at the wrong
  moment.

- **`tvalid` never depends on `tready`.** The legacy `m_axis_tvalid = last_dv &
  (fifo_rd_en | last_cnt) & m_axis_tready` is illegal by spec and creates a
  combinational path across the interface. Here `tvalid = last_dv & last_rdy`,
  where `last_rdy` is registered and monotonic while a beat is held, so `tvalid`
  is asserted once per beat and never withdrawn without a handshake.

- **One-cycle stall when classifying a truncated packet.** During `RUN`, `tlast`
  is known at capture time (`cnt == NSAMP-1`). During a flush it is not: the held
  beat only becomes "the last one" once the FIFO has drained. `last_rdy` holds
  such a beat back for one cycle until `last_cnt` can be tagged. Same stall the
  legacy design had, expressed without the illegal `tready` dependency.

- **End of packet is detected on the beat actually delivered**, not on the cycle
  the word was popped (`last_cnt && out_hs`, not `cnt == NSAMP-1 && tvalid &&
  tready`). The old condition worked only by coincidence with the old `tvalid`.

- **Drain settling instead of a pulse synchroniser.** In an async FIFO `empty`
  is computed against the *synchronised* write pointer, so `empty == 1` does not
  prove nothing is in flight. The block requires `run_state_ack` (the run state
  round-tripped through the write domain) to be low **and** the FIFO to read
  empty continuously for `DRAIN_SETTLE = 4` cycles. This replaced a 3-stage
  synchroniser on `fifo_wr_en`, which is a *pulse train*: a one-cycle pulse in a
  307.2 MHz write domain can be missed entirely by a 100 MHz read clock.

- **`s_axis_tready = ~fifo_full`, never gated by the run state.** The block is a
  passive tap and must not stall its producer. Beats offered while idle are
  accepted on the bus and dropped silently — and are *not* counted in `LOST`,
  which only counts drops during a run.

- **`NSAMP = 0` keeps the block in `IDLE`.** Otherwise `cnt == NSAMP-1` would be
  `0xFFFFFFFF` and unreachable, hanging in `RUN` forever.

### 2.5 Latency and capacity

| Quantity | Value |
|----------|-------|
| Buffer capacity | `N_FIFO + 2` beats (`N_FIFO+1` in the fwft FIFO, 1 in the beat register) |
| Stop latency | `START` crosses two flops before the FSM sees it |

⚠️ **Stopping is not instantaneous.** After software writes `START = 0` the
block keeps streaming normally for several `m_axis_aclk` cycles. Always poll
`STATUS.IDLE`; never assume the output stops on the next beat.

The `N_FIFO + 2` figure is measured, not assumed: XPM gives `N+1` usable words
in first-word-fall-through mode (confirmed at `N_FIFO=16` → 17), plus the one
beat held in the output register.

### 2.6 What `LOST` actually counts — READ THIS

`LOST` increments once per **cycle** in which the source offers data while the
FIFO is full. It does **not** count distinct beats. The two coincide only for a
source that produces one new sample per clock and cannot be stalled — which is
the intended deployment:

```
samples offered  ==  samples stored  +  LOST          (free-running source)
```

Put a well-behaved AXI4-Stream master in front instead and the meaning changes:
that master holds one beat across every stalled cycle, so the same beat is
counted many times and nothing is actually lost. In that configuration `LOST`
measures backpressure, not loss.

⚠️ A free-running converter is **not** an AXI4-Stream master: it keeps changing
`tdata` while `tready` is low, violating `TDATA_STABLE`. The protocol simply
does not describe it. `tc11` models this source and switches the interface
assertions off for its duration.

Both interpretations are covered by tests that deliberately assert different
things about the same register: `tc05` (AXI master, backpressure) and `tc11`
(free-running source, `offered == stored + LOST`).

### 2.7 Buffer FIFO (`qick:mem:fifo_async`)

Wrapper around `xpm_fifo_async`, validated separately (10/10, `B=32`, `N=2048`,
both read modes, both clock ratios).

⚠️ `streamer` instantiates it with `READ_MODE = "fwft"` and the read datapath
**depends on that contract**: `dout` already holds the head word when `empty` is
low, and `rd_en` is a pop acknowledge. Switching to `"std"` shifts the entire
stream by one beat and loses the last word — it is not a drop-in change.

One bug found and fixed while validating it, relevant to any user of this FIFO:
XPM holds `wr_rst_busy` high for several cycles **after** `rst` deasserts and
silently drops every write in that window while `full` still reads 0. Since
`streamer` drives `s_axis_tready = ~fifo_full`, an upstream master would see
`tready = 1`, transfer, and the data would vanish. The wrapper now ORs
`wr_rst_busy` / `rd_rst_busy` into `full` / `empty`.

### 2.8 Verification (10/10 SVUnit)

```
make sim IP=streamer                              # single clock, 307.2 MHz
make sim IP=streamer ASYNC=1                      # s 307.2 MHz / m 100 MHz
make sim IP=streamer FIFO=1024 MEM=block          # block-RAM buffer
make sim IP=streamer ASYNC=1 FIFO=1024 MEM=block
```

| Test | What | Result |
|------|------|--------|
| tc00 idle | nothing emitted while disabled | PASS |
| tc01 oneshot_4 | payload + `tlast` on beat 3 | PASS |
| tc02 oneshot_1 | degenerate packet, `tlast` on beat 0 | PASS |
| tc03 continuous_3x2 | two packets, `tlast` at beats 2 and 5 | PASS |
| tc04 backpressure | random `tready`, payload and `tlast` survive | PASS |
| tc05 lost_samples | `LOST` == what the monitor saw dropped | PASS |
| tc06 flush_drains_partial | `FLUSH=1`, 5 beats drained, `tlast` on beat 4 | PASS |
| tc07 noflush_discards_partial | `FLUSH=0`, exactly 1 beat escapes, no `tlast` | PASS |
| tc08 nsamp_zero | stays in IDLE, does not hang | PASS |
| tc09 restart | two consecutive one-shot runs | PASS |

Testbench notes worth carrying to other blocks:

- **`START` is a level, not a pulse.** A two-cycle pulse makes the FSM leave
  `RUN` before anything streams. `start_block()` raises it and waits for
  `dbg_probe[3]` (`run_state_sclk`), which is the *write* side reporting that it
  has begun capturing. Data pushed before that is accepted on the bus and thrown
  away.
- **Do not use `axi4_stream_if.tb_master.burst_tx()` here.** It forces `tlast`
  on the last beat of every burst, which is wrong for a block that generates its
  own packet boundaries. `rx` also drives `tready` itself and fights any test
  that manages it. The TB drives the master from raw signals instead.
- **Never `disable fork` a master thread that may be mid-beat.** There is no
  legal way to abort an AXI4-Stream beat; killing the thread drops `tvalid`
  without a handshake and trips `AXIS_TVALID_STABLE`. Open the sink, wait for a
  `tx_done` flag, then tear down.
- **`-d SVUNIT` must be in `xelab_options`**, or the protocol assertions inside
  `axi4_stream_if` are never compiled. When they do fire, they also corrupt
  SVUnit's pass counter (a run reported `4294967290 of 10`) and abort each test
  a few cycles later, so fix assertion failures before reading anything else.
- Drive **every** signal the assertions look at, `tlast` and `tuser` included,
  or they sit at X and `ERRM_*_X` fires on every beat.

---

## 3. Wrapper: `axis_streamer`

AXI4-Lite configuration wrapper around `streamer`, adding the `s_axi_aclk`
domain and register-mapped control/status. Uses the repo-standard `axil_slv`
(`AXI_DW=32`, `AXI_AW=6`, `NUM_REGS=6`).

### 3.1 Register map

| Addr | Name | Bits | R/W | Notes |
|------|------|------|-----|-------|
| 0x00 | `START` | [0] | RW | **level** enable, not a pulse |
| 0x04 | `FLUSH` | [0] | RW | 1 = drain a partial packet with `tlast`, 0 = discard |
| 0x08 | `MODE` | [0] | RW | 0 = one-shot, 1 = continuous |
| 0x0C | `NSAMP` | [31:0] | RW | beats per packet; 0 keeps the block idle |
| 0x10 | `LOST` | [31:0] | RO | see §2.6; valid only while `STATUS.IDLE` |
| 0x14 | `STATUS` | [5:0] | RO | see below |

`STATUS` bits:

| Bit | Name | Meaning |
|-----|------|---------|
| 0 | `RUNNING` | the core is capturing and streaming |
| 1 | `DONE` | one-shot packet finished; clear `START` to return to idle |
| 2 | `IDLE` | safe to reconfigure, and `LOST` holds the last run's count |
| 3 | `OVERFLOW` | sticky; samples were lost this run or the last. Cleared automatically when a new run starts |
| 4 | `FIFO_FULL` | instantaneous, diagnostic |
| 5 | `FIFO_EMPTY` | instantaneous, diagnostic |

`RO_MASK` covers `LOST` and `STATUS` (bits 4 and 5 of the mask), served from
`i_slv_regs`; the writable registers echo back from `o_slv_regs`.

⚠️ The `.rdl` addresses and the RTL `localparam R_*` / `ST_*` indices are synced
**by hand**. Change one, change the other.

⚠️ From the `axis_pid` bitácora, applies here too: the signal wired to
`.i_reg_is_readonly` **must** be declared `[NUM_REGS-1:0]`. An undeclared name
becomes an implicit 1-bit wire, the RO mask is truncated, and writable registers
get corrupted.

### 3.2 CDC

**Config out (`s_axi_aclk` → datapath).** `START` is synchronised inside the
core with `cdc_bit_sync`. `MODE`, `FLUSH` and `NSAMP` are **not** synchronised:
the core samples them continuously while stopped, which is a multi-cycle path.
They are guaranteed stable by the documented software sequence (written before
`START`), but the path **must** be constrained in the XDC with `set_max_delay
-datapath_only` plus `set_bus_skew`, exactly like the `axis_pid` config MCP.
Without the skew constraint, a bus caught mid-change can be captured with mixed
bits.

**Status in (datapath → `s_axi_aclk`).** Each `STATUS` bit gets its own
`cdc_bit_sync` in a generate loop. They are therefore **not coherent with each
other** — you can read `RUNNING=0, DONE=0` during a transition. That is fine for
polling, and it is precisely why the register exposes decoded flags rather than
the raw 2-bit FSM encoding, whose bits could otherwise be caught in a
combination that never existed.

**`LOST`** crosses `s_axis_aclk` → `s_axi_aclk` with no handshake at all. It is
only updated when the block leaves `RUN`, so it is stable when read correctly,
but a read taken mid-run can return a torn value. Poll `STATUS.OVERFLOW` during
a run; read `LOST` afterwards.

### 3.3 Verification (13/13 SVUnit)

Three asynchronous clocks: `s_axi` 100 MHz, `s_axis` 150 MHz, `m_axis` 200 MHz.

```
make sim IP=axis_streamer
make sim IP=axis_streamer FIFO=1024 MEM=block
```

| Test | What | Result |
|------|------|--------|
| tc00 registers | defaults, readback, RO enforcement, register independence | PASS |
| tc01 oneshot_4 | payload + `tlast` through the full IP | PASS |
| tc02 oneshot_1 | single-beat packet | PASS |
| tc03 continuous_3x3 | three packets, `tlast` at beats 2, 5, 8 | PASS |
| tc04 backpressure | random `tready` on the DMA side | PASS |
| tc05 lost_and_overflow | `LOST` exact vs monitor, `OVERFLOW` sticky | PASS |
| tc06 flush_drains_partial | `FLUSH=1` drain with `tlast` | PASS |
| tc07 noflush_discards_partial | `FLUSH=0`, at most one beat escapes | PASS |
| tc08 nsamp_zero | refuses to start | PASS |
| tc09 restart_reconfigure | two runs, `NSAMP` changed in between | PASS |
| tc10 status_tracks_fsm | IDLE → RUNNING → DONE → IDLE, polled over AXI | PASS |
| tc11 freerun_source_lost | ADC-style source, `offered == stored + LOST` | PASS |
| tc12 oneshot_freerun_single_packet | ADC-style source in one-shot, `FLUSH` 1/0, sink stalled on the last beat: exactly `NSAMP` beats, one `tlast`, DONE, IDLE, `LOST = 0` | PASS |

The TB scoreboard is monitor-based: the input monitor records a beat only when
the core actually stored it (`dbg_probe[4] && !dbg_probe[7]`), the output monitor
checks payload, zero-padding and the beat index of every `tlast`. No test pushes
to the expected queue by hand, which removes the whole class of
"pushed at schedule time, the write never committed" desyncs.

---

## 4. SIZING: FIFO depth ↔ AXI DMA configuration — READ THIS

This is the section that decides whether your capture has gaps.

### 4.1 Two regimes, and only one of them is realistic at full rate

**Burst capture (`MODE = 0`, one-shot).** You capture `NSAMP` samples and drain
them at whatever pace the DMA manages. If `NSAMP ≤ buffer capacity`, the DMA
rate is **irrelevant** — the buffer absorbs the entire record and the drain is
leisurely. This is what the dual-clock design is for: fill fast, drain slow.

**Sustained streaming (`MODE = 1`, continuous).** The DMA must keep up with the
source *forever*. A FIFO only absorbs transient stalls; if the average sink rate
is below the source rate, the buffer fills and stays full no matter how deep it
is, and `LOST` grows linearly.

Do the arithmetic before choosing:

```
source rate  = f_s_axis  samples/s
sink rate    = f_m_axis × (one beat per sample)
byte rate    = f_m_axis × B_AXIS/8
```

With the QICK defaults (`B_AXIS = 32`, source at 307.2 MSPS):

```
1 beat = 4 bytes
307.2e6 × 4 = 1.23 GB/s sustained
```

A 32-bit AXI interface at ~300 MHz delivers exactly that in theory, i.e. you
would be asking the DMA for **100 % of its bandwidth with zero headroom** for
burst overhead, descriptor fetch and DDR contention. It does not hold up in
practice.

⚠️ Note also that one sample in produces one beat out. Running `m_axis_aclk`
*slower* than `s_axis_aclk` therefore **guarantees** overflow in continuous
mode — the dual-clock capability buys you a slow drain of a finite record, not a
rate conversion.

If you genuinely need sustained streaming at full rate, the fix is upstream of
this block: widen `B_AXIS` (64 or 128) and pack several samples per beat, or
decimate. Deepening the FIFO will not help.

### 4.2 Buffer capacity

```
capacity = N_FIFO + 2 beats
           └─ N_FIFO+1 in the fwft FIFO, +1 in the output beat register
```

Measured at `N_FIFO = 16` → 18 beats, in both clock configurations.

```
max gapless record = (N_FIFO + 2) / f_s_axis   seconds
```

### 4.3 Choosing `N_FIFO`

Storage is `W_FIFO = B_TDATA + B_TUSER` bits wide (24 by default). A RAMB36
configured 36 × 1024 holds 1024 words, so the block RAM cost is roughly
`N_FIFO / 1024` BRAM36 — Vivado picks the final geometry.

| `N_FIFO` | BRAM36 (24-bit) | Capacity | Record @ 307.2 MSPS |
|---------:|----------------:|---------:|--------------------:|
| 16 | 0 (LUTRAM) | 18 | 59 ns |
| 256 | 0 (LUTRAM) | 258 | 0.84 µs |
| 1024 | 1 | 1026 | 3.3 µs |
| 4096 | 4 | 4098 | 13.3 µs |
| 16384 | 16 | 16386 | 53.3 µs |
| 65536 | 64 | 65538 | 213 µs |

**Rule of thumb:** for one-shot capture, size `N_FIFO` to the longest record you
want to take in a single shot. For continuous mode (only viable if §4.1's
arithmetic closes), size it to the worst DMA stall you expect — descriptor
fetch, DDR refresh and AXI arbitration each cost on the order of hundreds of
nanoseconds to a few microseconds, so a few thousand samples of elasticity is a
sensible floor.

`FIFO_MEM_TYPE` defaults to `"auto"`, so Vivado picks: LUTRAM when shallow, block
above. Override it explicitly for `"ultra"` (URAM) if you go very deep — note
that a 24-bit word wastes two thirds of a 72-bit URAM.

⚠️ `N_FIFO` must be a power of two and ≥ 16 (XPM constraint).

### 4.4 Matching `NSAMP` to the DMA descriptor

The AXI DMA S2MM channel closes a descriptor when it sees `tlast`. This block
asserts `tlast` every `NSAMP` beats. **The two must agree**, or you get
"packet larger than buffer" errors or short descriptors.

```
bytes_per_packet = NSAMP × B_AXIS/8        # 4 bytes/beat with B_AXIS = 32
```

Going either direction:

| You fix… | Then set… |
|---|---|
| `NSAMP` (record length in samples) | DMA buffer length = `NSAMP × 4` bytes |
| DMA buffer length in bytes | `NSAMP = bytes / 4` |

The DMA's **Buffer Length Register width** must be wide enough for
`bytes_per_packet`: `ceil(log2(bytes + 1))` bits. The default of 14 bits caps a
transfer at 16 KB = 4096 beats — if you want `NSAMP = 16384` you need at least
17 bits, and it is a synthesis-time IP parameter, not something software can
change.

### 4.5 AXI DMA configuration checklist

Verify these against PG021 for your DMA version; they are the parameters this
block interacts with.

| Setting | Recommendation | Why |
|---|---|---|
| Buffer Length Register width | ≥ `ceil(log2(NSAMP × 4 + 1))` | otherwise `NSAMP` is silently capped |
| Stream data width (S2MM) | = `B_AXIS` | must match the block |
| Memory-map data width | ≥ stream width; 128 bit for an HP port | wider MM bursts amortise AXI overhead |
| Max burst size | 256 | fewer, longer bursts to DDR |
| Scatter-Gather | on, with cyclic descriptors, for `MODE = 1` | in simple mode there is a gap between transfers while software rearms, and data is lost in that gap |
| Allow unaligned transfers | not needed | the block emits aligned, fixed-size packets |

### 4.6 Worked examples

**A. One-shot 4096-sample snapshot at 307.2 MSPS**

```
N_FIFO = 4096          → capacity 4098 ≥ 4096   ✔ no gaps regardless of DMA rate
NSAMP  = 4096
DMA buffer = 4096 × 4  = 16384 bytes
Buffer Length Register width ≥ ceil(log2(16385)) = 15 bits
MODE = 0, FLUSH = 0
```
The DMA can be arbitrarily slow. `LOST` should read 0; if it does not, the
source was already running before `START` propagated.

**B. One-shot 16384-sample snapshot**

```
N_FIFO = 16384         → 16 BRAM36, capacity 16386      ✔
NSAMP  = 16384
DMA buffer = 65536 bytes
Buffer Length Register width ≥ 17 bits    ← the default 14 is NOT enough
```

**C. Continuous streaming — check first**

```
f_s_axis = 307.2 MHz, B_AXIS = 32 → 1.23 GB/s sustained
```
Do not attempt this configuration. Either decimate the source, or widen
`B_AXIS` and pack multiple samples per beat. If you do run it anyway, watch
`STATUS.OVERFLOW`: it will be set, and `LOST` will grow without bound.

### 4.7 Simulating a different buffer configuration

The functional suite runs at `N_FIFO = 16` on purpose — the overrun tests
deliberately fill the buffer, so a deep FIFO only lengthens the run without
covering more control logic, and depth itself is already covered by the
`fifo_async` suite. What *is* worth running once is a block-RAM build, because
first-word fall-through over BRAM adds internal output registers that LUTRAM
does not have:

```
make sim IP=streamer FIFO=1024 MEM=block
make sim IP=axis_streamer FIFO=1024 MEM=block
make sim-streamer-matrix          # both blocks × {16 auto, 1024 block}
```

`MEM` accepts `auto`, `distributed`, `block`, `ultra`. The depth and storage
type appear in the `[CFG]` line **and** in the SVUnit test-case name, so a
define that never reached `xvlog` is immediately visible. The overrun tests size
their stimulus off `N_FIFO`, so they stay meaningful at any depth.

---

## 5. PYNQ usage

The QICK driver is `AxisStreamer` (`cores/ip/axis_streamer/driver/axis_streamer.py`). It is not in `qick_lib` yet:
`make driver IP=axis_streamer` installs it locally (with its register model), and `QickSoc` binds
it to `qick:ip:axis_streamer:2.0`. Under `QickSoc` it finds its AXI DMA itself (`st.dma`, traced from `m_axis`),
and warns if the bitstream carries 2.0.0 (COREREVISION 0, the one-shot hang of §2.3).

```python
from qick import QickSoc

soc = QickSoc(bitfile=BIT, no_tproc=True)
st = soc.axis_streamer_0                    # AxisStreamer; st.dma is the DMA it feeds

# One-shot: IDLE -> configure -> arm the DMA -> START -> tlast -> DONE -> stop -> IDLE
beats = st.capture(4096)                    # raw beats, dtype st.beat_dtype (B_AXIS bits)
print(st.last_capture)                      # {'dma': True, 'done': True, 'idle': True, 'lost': 0}
tdata, tuser = st.decode(beats)             # split by B_TDATA / B_TUSER
z = st.iq(tdata)                            # I + jQ, for a {Q, I} 16+16 payload (axis_readout_v2)
```

`capture()` raises `RuntimeError` if the DMA does not close or the block does not return to IDLE. It brings the
block back to IDLE first.

The same sequence step by step, for continuous mode or a raw PYNQ `Overlay` (there, pass `dma=` or set `st.dma`,
since `configure_connections()` only runs under `QickSoc`):

```python
from pynq import allocate
from qick.drivers.axis_streamer import dma_wait, dma_reset

st.configure(nsamp, continuous=True, flush=True)   # raises unless IDLE
buf = allocate(shape=(nsamp,), dtype=st.beat_dtype)
st.dma.recvchannel.transfer(buf)                    # arm the DMA BEFORE start()
st.start()
dma_wait(st.dma, 1.0)                               # never dma.recvchannel.wait(): it hangs without tlast
...
idle, beats = st.recover()   # clears START, then takes what the stop left with spare transfers, until IDLE
lost = st.lost               # LOST is only meaningful once IDLE
```

`st.stop()` alone (clear START, wait for IDLE) is enough when nothing is left to emit, e.g. after a one-shot packet.
In continuous mode, clear START *before* arming a transfer for the leftovers, which is what `recover()` does. With
START still set, the block starts a new packet into that transfer, closes it on `tlast`, and presents the next beat
with nothing to take it. With `FLUSH = 0` that beat can never be withdrawn, so the block stays out of IDLE.
`status()`, `status_flags()` and `wait_status()` read STATUS; the register model is at `st.regs` (e.g.
`st.regs.STATUS_REG.IDLE.read()`).

⚠️ **Order matters**: arm the DMA before writing `START`. The block begins
capturing as soon as `START` propagates, and with the DMA not yet receiving, the
buffer starts filling immediately.

⚠️ `STATUS` bits are individually synchronised and not coherent with each other.
Poll one bit at a time; do not decode combinations.

---

## 6. Files & build

```
cores/lib/ctrl/streamer/
  README.md                     # this file
  streamer.core                 # VLNV qick:ctrl:streamer:1.0.1
  hdl/streamer.sv               # 10/10
  tests/streamer_tc00.sv        # SVUnit module, monitors, helpers
  tests/streamer_tests.sv       # SVTEST includes
cores/ip/axis_streamer/
  axis_streamer.core            # VLNV qick:ip:axis_streamer:2.0.1
  hdl/axis_streamer.sv          # 13/13
  tests/axis_streamer_tc00.sv
  tests/axis_streamer_tests.sv
  rdl/axis_streamer_regmap.rdl  # 6 regs, see §3.1
  driver/axis_streamer.py       # AxisStreamer (QICK driver), tests/ (regs + sequence, pynq stubbed)
  constraints/axis_streamer.xdc # 3 async domains + config MCP
  constraints/axis_streamer_ooc.xdc
cores/mem/fifo_async/           # buffer, validated separately (10/10)
```

Simulation knobs (`vlogdefine` via the Makefile):

| Make var | Define | Applies to | Default |
|---|---|---|---|
| `ASYNC=1` | `ASYNC_CLK` | `streamer` | 0 (single clock) |
| `FIFO=<n>` | `TB_N_FIFO` | both | 16 |
| `MEM=<type>` | `TB_MEM` | both | `auto` |
| `MODE=fwft` | `FWFT` | `fifo_async` | std |
| `DEPTH=`/`WIDTH=` | `TB_N`/`TB_B` | `fifo_async` | 2048 / 32 |

⚠️ `xelab_options` must include `-d SVUNIT` (protocol assertions) and
`-timescale=1ns/1ps` (a 307.2 MHz half-period is 1.6276 ns and rounds to 2 ns at
1 ns precision).

---

## 7. Open items

- [x] `fifo_async` parametrised (`READ_MODE`, `FIFO_MEMORY_TYPE`,
      `CDC_SYNC_STAGES`) + 10/10 across the config matrix
- [x] `wr_rst_busy` / `rd_rst_busy` folded into `full` / `empty`
- [x] `streamer` core rewritten (beat register, AXI-legal `tvalid`, drain
      settling) — 10/10 single-clock and dual-clock
- [x] `axis_streamer` wrapper + `STATUS` register — 13/13
- [x] Negative regressions confirming the tests are load-bearing
- [x] `FIFO_MEM_TYPE` parametrised; depth/memory-type simulation knobs, and the
      block-RAM path exercised end to end (`FIFO=1024 MEM=block` on both cores)
- [x] `make lint IP=streamer` and `make lint IP=axis_streamer`
- [x] XDC: `set_clock_groups -asynchronous` across the three domains;
      `set_max_delay -datapath_only` on `START` and the six `STATUS` syncs;
      `set_max_delay` + `set_bus_skew` on the `MODE`/`FLUSH`/`NSAMP` MCP;
      decide whether `LOST` gets a handshake or stays documented as
      "read only while `STATUS.IDLE`"
- [x] OOC clock definitions (`s_axi` 100 MHz, `s_axis` 307.2 MHz, `m_axis` TBD)
- [x] `.rdl` (6 regs) + PeakRDL driver + pytest — `LOST`/`STATUS` as `sw=r; hw=w`
- [ ] Choose the deployed `N_FIFO` and re-check the DMA Buffer Length Register
      width against §4.4
- [x] IP packaging (`component.xml` + `xgui`); verify `ip_packager` picks XDC
      from `constraints/` (known bug: it looked in `rtl_lib/ip`)
- [x] Live-hardware end-to-end capture (ADC → streamer → DMA → notebook): RFSoC4x2
      a debug bench, all 6 notebook steps PASS 2026-09-25 with 2.0.1. The first run found the
      one-shot hang fixed in 1.0.1/2.0.1 (§2.3)
- [x] QICK driver `AxisStreamer` (per-IP, like qick_time_tagger's): `capture()`, `configure()`/`start()`/
      `stop()`/`recover()`, DMA found by `configure_connections()`, 2.0.0 warning; 16/16 pytest off the board
- [x] Board run of the 4x2 notebook through the driver: ALL PASS 2026-09-25. Its first run found
      `recover()` arming the spare before clearing START (fixed, see §5)
- [ ] On the board a cut packet held 22 beats against 18 in simulation: confirm whether the AXI DMA S2MM
      buffers beats after a transfer closes (PG021) before using §4.2 for sizing
- [ ] Confirm the AXI DMA settings in §4.5 against PG021 for the version in use
