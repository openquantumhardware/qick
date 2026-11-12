# AXIS Streamer (axis_streamer)

A passive tap that captures a stream (typically the ADC samples of a free-running converter) and hands it to a DMA in
packets of a chosen length: **one-shot** (one packet) or **continuous** (back-to-back packets). It never stalls its producer:
if the DMA does not keep up, samples are dropped and counted.

- Project: QICK, `qick:ip:axis_streamer:2.0.0` (module `axis_streamer`, `B_TDATA = 16`, `B_TUSER = 8`, `B_AXIS = 32`, `N_FIFO = 16`)
- Driver: class `AxisStreamer` in `cores/ip/axis_streamer/driver/axis_streamer.py`: a `DefaultIP` with the PeakRDL register
  model on `.regs`; only the generated skeleton exists, there are no high-level methods yet
- Hardware bring-up: none (see U8)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 source --s_axis (tdata 16 + tuser 8, tvalid)--> dual-clock FIFO (N_FIFO+1 words) --> output beat register --> m_axis (32-bit, tlast) --> DMA
                                  s_axis_tready = ~FIFO full (never gated by the run state)
 AXI4-Lite registers: START (level), FLUSH, MODE, NSAMP, LOST (read-only), STATUS (read-only)
```

While the block is running, the FIFO is filled from `s_axis` and drained to `m_axis` in packets of `NSAMP` beats, with `tlast`
on beat `NSAMP - 1`. While it is idle, beats offered on `s_axis` are dropped silently.

## U2. Rules that are not obvious

- **Sequence.** Write `NSAMP`, `MODE`, `FLUSH` **only while `STATUS.IDLE` is set**; write `START = 1`; in one-shot mode wait for the
  DMA to see `tlast` or poll `STATUS.DONE`; in continuous mode run until you choose to stop; write `START = 0`; **poll
  `STATUS.IDLE`**, then read `LOST`.
- **`START` is a level, not a pulse.** Hold it for the whole run; dropping it ends the run. In one-shot mode `DONE` means the
  packet finished: clear `START` to return to idle.
- **Stopping is not instantaneous.** `START` crosses several flops, so the core keeps streaming for a few cycles after the write
  retires. Never assume the output stopped: poll `STATUS.IDLE`.
- **`NSAMP = 0` keeps the block idle.**
- **`FLUSH`** decides what happens to a partial packet when the run ends: 1 = drain what is left and mark the last beat with
  `tlast`; 0 = discard it.
- **`LOST` counts cycles, not beats.** It counts the clock cycles in which the source offered data while the FIFO was full.
  For a free-running converter that cannot be stalled (the intended source), `samples offered = samples stored + LOST`, i.e.
  `LOST` is the number of dropped samples and a non-zero value means the record has gaps. With a well-behaved AXI4-Stream master
  in front (which holds one beat while `tready` is low) the same beat is counted many times and `LOST` measures back-pressure,
  not loss. `LOST` is latched when the run ends and is only meaningful while `STATUS.IDLE` is set (a read taken mid-run can be
  torn: it crosses the clock domains with no handshake); during a run poll `STATUS.OVERFLOW`.
- **Status bits are individually synchronised**, so they are not coherent with each other; that is fine for polling.
- **Capture depth.** The block absorbs `N_FIFO + 1` words in the FIFO plus one in the output register (18 with the default
  `N_FIFO = 16`), i.e. only a short DMA stall. A gapless record longer than that needs the sink to keep up on average; size
  `N_FIFO` for the worst expected DMA stall, not for the packet length.
- **Do not rename the `s_axis_*` / `m_axis_*` ports:** Vivado infers the AXI4-Stream interfaces from those names when the IP is
  packaged.
- **`MODE`, `FLUSH` and `NSAMP` are not synchronised into the capture clock.** They are guaranteed stable by the sequence above
  (written before `START`), but the path must be constrained in the XDC (`set_max_delay -datapath_only` and `set_bus_skew`),
  otherwise a bus caught mid-change could be captured with mixed bits. `constraints/axis_streamer.xdc` contains the
  `set_max_delay -datapath_only` exceptions and a note on `set_bus_skew`.

## U3. Data formats

- `s_axis`: `tdata[15:0]` and a side channel `tuser[7:0]`; both are stored.
- `m_axis_tdata`: 32 bits: `{8'b0, tuser[7:0], tdata[15:0]}` (the stored word is 24 bits, zero-extended). `m_axis_tlast` marks the last
  beat of a packet.
- `STATUS` (bits): 0 RUNNING, 1 DONE, 2 IDLE, 3 OVERFLOW (sticky, cleared when a new run starts), 4 FIFO_FULL and 5 FIFO_EMPTY
  (instantaneous, diagnostic).

## U4. Memories, throughput and limits

- FIFO of `N_FIFO + 1` words (the memory type follows the `FIFO_MEM_TYPE` parameter, `"auto"` by default).
- One beat per input clock; the output rate is whatever the DMA accepts. Sustained capture needs the DMA to keep up.

## U5. Python quick start

```python
s = overlay.axis_streamer_0                    # a DefaultIP with .regs (PeakRDL model)
s.regs.NSAMP_REG.NSAMP.write(1024)             # only while STATUS.IDLE
s.regs.MODE_REG.MODE.write(0)                  # one-shot
s.regs.FLUSH_REG.FLUSH.write(1)
s.regs.START_REG.START.write(1)
# ... start the DMA receive, wait for tlast ...
s.regs.START_REG.START.write(0)
while not s.regs.STATUS_REG.IDLE.read(): pass
lost = s.regs.LOST_REG.LOST.read()
```

(The register and field names are those of `rdl/axis_streamer_regmap.rdl`; the sequence is the one of U2.)

## U6. Using it in a block design

- `s_axis` <- the sample source (for example an ADC stream), `m_axis` -> an AXI DMA receive channel, `s_axi` -> the PS interconnect.
- Clocks: `s_axi_aclk` (registers) and the stream clocks; the output side and the input side use their own clocks (dual-clock
  FIFO). Constrain the configuration path as described in U2.
- Parameters: `B_TDATA`, `B_TUSER`, `B_AXIS`, `N_FIFO`, `FIFO_MEM_TYPE`.
- **Driver binding gotcha:** the skeleton driver has `bindto = ['qick:ip:axis_streamer:1.0']`, but the core is version `2.0.0` and the
  packager takes the IP version from the `.core` name (`2.0`), so a packaged block is `qick:ip:axis_streamer:2.0` and is **not
  bound** to the driver. Fix one of the two. (Checked by reading `ip_packager.py` and the driver; not by packaging.)

## U7. Gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Writing `NSAMP`/`MODE`/`FLUSH` while running | The core samples them continuously: torn value possible | Only while `IDLE` |
| Assuming the output stopped after `START = 0` | It keeps streaming a few cycles | Poll `STATUS.IDLE` |
| Reading `LOST` during a run | Torn value | Poll `STATUS.OVERFLOW`; read `LOST` when idle |
| `LOST` with a stallable source | It measures back-pressure, not loss | Only trust it for a free-running source |
| Long gapless record with a slow DMA | Samples dropped after ~18 beats of stall | Make sure the DMA keeps up |
| Beats offered while idle | Dropped, not counted in `LOST` | Start before the data you want |

## U8. Validation status

- **Simulation**: 12 SVUnit tests: register access, one-shot with 4 and with 1 beat, continuous 3 x 3, back-pressure, `LOST`/overflow,
  flush draining and not draining a partial packet, `NSAMP = 0`, restart and reconfigure, status tracking the state machine, and a
  free-running source losing samples.
- **Hardware**: this IP has not been built into a bitstream or used on a board, and no Top project instantiates it.
- Not verified: the XDC constraints on the configuration path in an implemented design, throughput against a real DMA.

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `s_axi_*` | | AXI4-Lite slave (6-bit address) |
| `s_axis_tdata[B_TDATA-1:0]`, `s_axis_tuser[B_TUSER-1:0]`, `tvalid`, `tready` | | source; `tready = ~fifo_full` |
| `m_axis_tdata[B_AXIS-1:0]`, `tvalid`, `tready`, `tlast` | | packets to the DMA |

## Registers

| Addr | Register | Field | Access | Description |
|---|---|---|---|---|
| 0x00 | `START_REG` | `START[0]` | RW | block enable, a level |
| 0x04 | `FLUSH_REG` | `FLUSH[0]` | RW | 1 drain a partial packet with `tlast`, 0 discard |
| 0x08 | `MODE_REG` | `MODE[0]` | RW | 0 one-shot, 1 continuous |
| 0x0C | `NSAMP_REG` | `NSAMP[31:0]` | RW | beats per packet; 0 keeps the block idle |
| 0x10 | `LOST_REG` | `LOST[31:0]` | R | cycles in which data was offered to a full FIFO, latched when the run ends |
| 0x14 | `STATUS_REG` | `RUNNING`, `DONE`, `IDLE`, `OVERFLOW`, `FIFO_FULL`, `FIFO_EMPTY` | R | see U3 |

Source: `rdl/axis_streamer_regmap.rdl`.

## Verification

`tests/axis_streamer_tests.sv` (12 tests, U8). `make sim IP=axis_streamer`.

## Files

```
cores/ip/axis_streamer/
  README.md
  axis_streamer.core                 # VLNV qick:ip:axis_streamer:2.0.0
  hdl/axis_streamer.sv               # AXI-Lite wrapper + streamer (rtl_lib/ctrl)
  rdl/axis_streamer_regmap.rdl
  constraints/axis_streamer.xdc, axis_streamer_ooc.xdc
  driver/axis_streamer.py            # skeleton DefaultIP driver
  tests/
```

## Open items

- Driver: high-level methods (start a capture, wait, read `LOST`) and the `bindto` version mismatch (U6); then the
  `qick_time_tagger` flow (per-IP driver, board validation).
- A Top project that uses it.
