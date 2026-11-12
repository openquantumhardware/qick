# DDR4 buffer (axis_buffer_ddr)

Writes an AXI4-Stream to DDR4 when triggered, and reads a block of DDR4 back out on an AXI4-Stream. Used behind the
readouts to capture long records (the avg_buffer's `decimated` data, or raw ADC) that do not fit in the FPGA memory;
the host then reads them from the DDR4.

- VLNV: `qick:ip:axis_buffer_ddr:1.1.4` (module `axis_buffer_ddr`)
- Replaces: the legacy `QICK:QICK:axis_buffer_ddr:1.1` (openquantumhardware/qick `firmware/ip/axis_buffer_ddr`), with the same
  ports, parameters, register map and behaviour
- Driver: `readout.AxisBufferDdrV1pt1` (`qick_lib/qick/drivers/readout.py`), bound to the `qick:ip` VLNV;
  `driver/axis_buffer_ddr.py` is an alias of that module
- Used in: 111, 4x2, 2x4 and 216 `tpv1_std` / `tpv2_std` (and 216 `tpv2_std_rfbv2`, `tpv2_demo`)
- Built from: `qick:axi:axi_mst_write`, `qick:axi:axi_mst_read` (each with a `qick:mem:fifo_axi` and a
  `qick:cdc:cdc_bit_sync`) and `qick:axi:axil_slv`

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 write:  s_axis --> FIFO (63 words) --> AXI4 master AW/W/B --> DDR4     (WSTART, trigger, WADDR, WNBURST)
 read:   DDR4 --> AXI4 master AR/R --> FIFO (63 words) --> m_axis       (RSTART, RADDR, RLENGTH)
```

Both channels run on `aclk`; the registers are on `s_axi_aclk`. The write channel stores `WNBURST` bursts of
`BURST_SIZE + 1` beats of `DATA_WIDTH` bits; the read channel reads one burst of `RLENGTH` beats.

## U2. The rules that are not obvious

- **Set the words, then the start bit.** `RADDR`, `RLENGTH`, `WADDR` and `WNBURST` are read when the FSM sees the
  start bit (through a 2-flop synchronizer); the words themselves cross without one. The offsets are bytes from
  `TARGET_SLAVE_BASE_ADDR`.
- **Clear the start bit between transfers.** The read FSM waits for `RSTART = 0` before it can start again; the write
  FSM waits for `WSTART = 0`, `trigger = 0` and the FIFO empty. Clearing `WSTART` while the write waits for the trigger
  disarms it.
- **Check `WSTATUS_REG` after a write.** `BRESP_ERR` says that the memory answered a burst with an error response; the write
  goes on, the record is incomplete. The driver does not read it.
- **The write waits for the `trigger` level**, not an edge, after `WSTART`. Words offered before it are not stored
  (`s_axis_tready` stays high, the FIFO write is gated by the FSM): start the stream with the trigger.
- **`WNBURST` is the number of bursts; 0 writes one.**
- **Reads of any length are split.** `RLENGTH` beats are read in INCR bursts of at most 256 beats that never cross a
  4 kB boundary; 0 reads nothing.
- **Writes: keep each burst inside a 4 kB page.** A write burst is `BURST_SIZE + 1` beats; the burst size has to
  divide 4096 (checked at elaboration) and `WADDR` has to be a multiple of it (software; the driver writes from 0).
- **Words are dropped before the trigger and after the last burst, on purpose.** `s_axis_tready` stays high there so
  that the sink does not stall the other consumers of the stream (the broadcaster feeds the avg_buffer too). From the
  address phase of the first burst on, every word offered is stored, burst boundaries included.
- **No `tlast` on `m_axis`** (always 0) and `tstrb` is all ones.
- **The driver skips 0 junk samples with this block** (`AxisBufferDdrV1pt1`); the 1.0 block (`axis_buffer_ddr_v1`) needs
  `junk_len = 50 * DATA_WIDTH / 32 + 1`.

## U3. Data formats

`s_axis_tdata`, `m_axi_wdata`, `m_axi_rdata` and `m_axis_tdata` are `DATA_WIDTH` bits (256 or 512 in the standard BDs);
the DDR4 stores the words in the order of the stream. The driver views the DDR4 as 32-bit words.

## U4. Throughput and limits

One word per `aclk` on each stream, if the DDR4 controller accepts it; the FIFOs hold 63 words each. The AXI ID is
fixed at 0, the burst is INCR with `awsize`/`arsize` = the full bus width, `awprot = arprot = 3'b010`, no cache bits.

## U5. Python quick start

```python
soc = QickSoc(bitfile)
ddr = soc.ddr4_buf              # AxisBufferDdrV1pt1: the driver finds the DDR4 controller and the readout behind it
# through QickSoc: soc.arm_ddr4(ch, nt) / soc.get_ddr4(nt), see the driver
```

## U6. Using it in a block design

| Parameter | Default | Standard BDs |
|---|---|---|
| `TARGET_SLAVE_BASE_ADDR` | `0x40000000` | `0x00000000` |
| `ID_WIDTH` | 1 | 1 |
| `DATA_WIDTH` | 256 | 512 (4x2: 512; check the BD) |
| `BURST_SIZE` | 15 | 15 |
| `DEBUG` | 0 | unused |

| Clock / reset | Interfaces |
|---|---|
| `s_axi_aclk` / `s_axi_aresetn` | `s_axi` |
| `aclk` / `aresetn` | `m_axi` (to the DDR4 through a SmartConnect), `s_axis`, `m_axis`, `trigger` |

There is no constraints file (as in the legacy IP).

## U7. Gotchas

| Symptom | Cause | What to do |
|---|---|---|
| The write never starts | No `trigger` after `WSTART`, or `WSTART` was not cleared after the last write | Clear both, then arm again |
| The write never ends | `WNBURST = 0` | Use 1 or more |
| First words of a record are junk | The 1.0 block's junk-samples bug (the driver adds `junk_len`) | Use the 1.1 block |
| A read returns the previous record | `RSTART` still 1 | Clear it, set the words, set it again |

## U8. Validation status

| What | Where | Result |
|---|---|---|
| Legacy RTL, same behaviour | the standard 111 / 4x2 / 2x4 / 216 builds | In production |
| This IP against the legacy RTL | SVUnit (Part II) | 17/17, every output equal on every clock where the legacy behaviour is kept |
| This IP in the Top BDs | `validate_bd_design` | See the CHANGELOG entry |
| This IP on hardware | A debug bench (counters to the PL DDR4 at 500 MHz and at a word every clock; `m_axis` read back through a DMA) | 11/11 PASS on the RFSoC4x2 (2026-11-04, `.bit` md5 `a506662b`...): 64 bursts at a word every clock, 0 lines lost; reads of 16, 600 and 40 beats (across 4 kB) through `m_axis`, 0 words different; a read of 0 beats reads nothing |

---

# Part II -- Reference

## Ports

| Port | Dir | Width | Notes |
|---|---|---|---|
| `s_axi_*` | | | AXI4-Lite, 8-bit address, `s_axi_aclk` |
| `aclk`, `aresetn` | in | 1 | datapath clock and reset |
| `trigger` | in | 1 | level; starts an armed write (2-flop synchronizer) |
| `m_axi_*` | | | AXI4 master to the DDR4 (`DATA_WIDTH`, `ID_WIDTH`) |
| `s_axis_*` | | DATA_WIDTH | stream to store; `tready` = FIFO not full |
| `m_axis_*` | | DATA_WIDTH | block read back; `tvalid` = FIFO not empty |
| `mst_write_probe_dbg`, `mst_read_probe_dbg` | out | 32 | FSM and FIFO state of the two channels |

## Registers

The driver class `AxisBufferDdrV1pt1` keeps a hand-written dictionary of this map, with the attribute names the software uses (`rstart_reg`, `raddr_reg`, `rlength_reg`, `wstart_reg`, `waddr_reg`, `wnburst_reg`). The indexes are those of the legacy `axi_slv.v`; `WSTATUS_REG` is not in the dictionary.

64 x 32-bit read/write registers (axil_slv; byte strobes honoured), reset 0. Used:

| Offset | Name (driver) | RTL name | Meaning |
|---|---|---|---|
| `0x00` | `rstart_reg` | `RSTART_REG` | [0] read start |
| `0x04` | `raddr_reg` | `RADDR_REG` | read byte offset from `TARGET_SLAVE_BASE_ADDR` |
| `0x08` | `rlength_reg` | `RLENGTH_REG` | beats of the read burst |
| `0x0C` | `wstart_reg` | `WSTART_REG` | [0] write start (armed, waits for `trigger`) |
| `0x10` | `waddr_reg` | `WADDR_REG` | write byte offset |
| `0x14` | `wnburst_reg` | `WNBURST_REG` | number of write bursts |
| `0x18` | `wstatus_reg` | `WSTATUS_REG` | read only; [0] a write burst got an error response |

`0x1C..0xFC` are plain storage (as in the legacy slave).

## Differences from the legacy RTL

Six bugs of the legacy RTL are fixed; everything else is the legacy behaviour, clock by clock (the co-simulation below).

- **No stream word is lost between two bursts** (`axi_mst_write` 1.0.1). The legacy writer did not enable the FIFO write in
  `NBURST_ST` (the cycle between two bursts) while `s_axis_tready` was high: every burst boundary lost the word offered in
  that cycle (measured: every word lost inside a capture was offered in `NBURST_ST`).
- **`WNBURST = 0` ends** (`axi_mst_write` 1.0.2). The legacy compared the burst count for equality after the first
  response, so 0 never ended; now `>=`, and 0 writes one burst.
- **Reads longer than 256 beats are not truncated** (`axi_mst_read` 1.0.1). `arlen` is 8 bits: the legacy took
  `RLENGTH - 1` modulo 256 (600 beats read 88).
- **Reads do not cross 4 kB, and a length of 0 reads nothing** (`axi_mst_read` 1.0.1). The legacy issued one burst of any
  length at any address (an AXI violation across a 4 kB boundary) and read 256 beats for a length of 0.

- **Clearing `WSTART` disarms the write** (`axi_mst_write` 1.0.3). The legacy stayed armed: a `WSTART` cleared while it
  waited for the trigger did not stop the next trigger from writing.
- **A write error response is reported** (`axi_mst_write` 1.0.3). The legacy ignored `BRESP`. The new `WSTATUS_REG` (0x18,
  read only, `BRESP_ERR`) is set by a burst answered with SLVERR or DECERR and cleared when the next write starts; the write
  is not aborted. In the legacy block that word is plain storage.

For a read of 1 to 256 beats inside a 4 kB page the read master is the legacy one. The golden model in `tests/ref` is the
legacy RTL with the write-side fixes that change its outputs (`axi_mst_write_legacy.sv`: the FIFO write enable, the burst
count compare and the disarm); the read-side fixes have their
own tests that do not compare with the legacy RTL.

## Verification

`make sim IP=axis_buffer_ddr` (DATA_WIDTH 64, BURST_SIZE 7; the whole legacy `axis_buffer_ddr`, `tests/ref` (with the one-line fix below), gets the same
inputs; a behavioural AXI4 memory answers the master with random ready/valid/backpressure):

- `tc_registers_match_the_legacy_slave`: 2000 random register operations with random byte strobes on the storage registers
  (reads of all 64); every AXI4-Lite output, every register handed to the masters, every AXI4 master output, both
  streams and both debug probes equal on every clock; reads equal to a byte-lane model
- `tc_random_transfers_match_the_legacy_rtl`: 12 random legal reads (1 to 40 beats) and writes (1 to 3 bursts) with random
  handshake rates, trigger and stream timing; equal on every clock, no AXI burst across 4 kB
- `tc_register_map_reaches_the_masters`: the six registers reach the two masters
- `tc_write_after_the_trigger_fills_memory`: 3 bursts of 8 beats at 0x100: 3 AW, 24 W, 24 consecutive stream words (none
  lost at the burst boundaries), nothing written after the last burst
- `tc_read_returns_the_memory_block`: 16 beats at 0x80 equal the memory block
- `tc_read_with_backpressure_and_slow_responses`: 100 beats with `m_axis_tready` at 40 % and slow AR/R
- `tc_two_writes_in_a_row_and_slow_memory`: two writes, slow AW/W/B
- `tc_reset_in_the_middle_of_a_transfer`: both resets in the middle of a write, then a read
- `tc_read_of_more_than_256_beats_is_split` (600 beats: 256 + 256 + 88), `tc_read_across_4kB_is_split` (16 + 24),
  `tc_read_of_zero_beats_reads_nothing`, `tc_write_of_zero_bursts_writes_one_and_ends`: the four fixes, on data and on the
  AXI bursts (the compare with the legacy RTL is off in the first three)
- `tc_clearing_wstart_before_the_trigger_disarms`: `WSTART` cleared while armed, then a trigger: no write; armed again: one
- `tc_error_response_sets_wstatus_until_the_next_write`: SLVERR on every burst sets `WSTATUS_REG`, the write completes, a
  write to the register does nothing, the next good write clears it (the compare with the legacy RTL is off: it has no status)
- `tc_read_from_an_unaligned_address_still_makes_progress_and_keeps_4kB`: RADDR 4 bytes before a boundary (not supported, but
  the split must finish and stay inside the page)
- `tc_read_whose_last_beat_waits_for_a_full_fifo`: 80 beats, the stream held and drained slowly, so the last beat waits for a
  full FIFO; equal to the legacy RTL on every clock
- `tc_write_waits_for_the_trigger_to_fall_before_it_can_end`: `WSTART` cleared with the trigger still high: the writer stays
  in `END_ST` until the trigger falls

Sub-blocks: `qick:mem:fifo_axi` is checked against the legacy VHDL (`fifo_axi` + `rd2axi` + `fifo`); the two masters are
checked through this IP (their legacy modules are part of the golden model).

## Files

```
cores/ip/axis_buffer_ddr/
  README.md
  axis_buffer_ddr.core
  axis_buffer_ddr.clock_domains.yaml
  driver/axis_buffer_ddr.py -> qick_lib/qick/drivers/readout.py
  driver/tests/                            # register-layer pytest (make driver)
  hdl/axis_buffer_ddr.sv -> ../../../../../rtl_lib/ip/axis_buffer_ddr.sv
  rdl/                                     # regmap (docs, driver tests)
  tests/axis_buffer_ddr_tc00.sv, axis_buffer_ddr_tests.sv
  tests/ref/                               # legacy RTL (golden model): top, masters, axi_slv, FIFO VHDL
```

## Open items

- Run on the board (D5/D6 of firmware/docs/user/IP_INTEGRATION.md): a standard build with the DDR4 (ZCU216 / RFSoC4x2).
