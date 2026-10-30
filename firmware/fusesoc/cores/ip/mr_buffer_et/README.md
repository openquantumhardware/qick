# Multi-Rate Buffer with External Trigger (mr_buffer_et)

A multi-channel, multi-rate capture buffer: `NM` parallel channels of `B` bits each, armed by software and started by
an **external hardware trigger**, capture `2**N` samples per channel at full write-side rate into `NM` independent
true-dual-port BRAMs; the whole captured window is then streamed out as a single AXI4-Stream burst on a second,
independent read clock. Used, among other things, to capture the I and Q lanes of a full-rate readout for DMA (the
deployed instance on ZCU216 has `NM = 2`, `N = 16`).

- Project: QICK, `qick:ip:mr_buffer_et:1.2.0` (wrapper module `mr_buffer_et`); core datapath `qick:mem:mr_buffer:1.0.0`
  (module `mr_buffer`)
- Driver: `MrBufferEt` in `qick_lib/qick/drivers/readout.py`, the class `QickSoc` uses for the MR buffer
  (`soc.mr_buf`, and `soc.mr_buffer_et_0`). It binds this core (`qick:ip:mr_buffer_et:1.2`) and the legacy IPs.
  `driver/mr_buffer_et.py` is an alias of that module (`firmware/docs/user/IP_INTEGRATION.md`). The standalone
  skeleton that used to live there bound the same VLNV and was removed on 2026-09-25.
- Hardware bring-up: **confirmed working end-to-end on a ZCU216** (arm -> external trigger -> capture-done -> DMA
  drain), with the monolithic (pre-1.2) driver -- see U8.

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
                 trigger ──CDC(cdc_gray_sync)──► trigger_resync (s_axis_aclk domain)
                    │
  s_axis (NM*B, s_axis_aclk) ──► [ NM x axis_to_bram_trig ] ──► [ NM x bram_tdp (true dual-port) ]
                                        armed by dw_capture_reg_resync                │ port B
                                                                                       ▼
                                                          [ bram_to_axis_nt ] ──► m_axis (B, m_axis_aclk)
                                                          armed by dr_start_reg_resync

  AXI4-Lite (s_axi_aclk) ──► DW_CAPTURE_REG / DR_START_REG / DEBUG_REG
                         ◄── STATUS_REG.CAPTURE_DONE (CDC'd back via cdc_bit_sync)
```

Typical use (loop-settling / snapshot capture over DMA):
1. Software writes `DW_CAPTURE = 1` -> arms all `NM` channel writers together.
2. `trigger` (external, asynchronous) fires -> each BRAM fills with `2**N` samples/channel at full write-side rate.
3. Software writes `DR_START = 1` -> drains the whole captured window out `m_axis` as one burst.
4. Downstream (an AXI DMA S2MM) consumes `NM * 2**N` beats, ending in `tlast`.

**Three independent clock domains:** `s_axi_aclk` (AXI4-Lite config), `s_axis_aclk` (write/capture datapath, e.g.
307.2 MHz), `m_axis_aclk` (read/drain datapath, e.g. 100 MHz, matched to a DMA/HP port).

**Output word order.** `TOTAL_WORDS = NM * 2**N` words per burst, `tlast` on the final beat, channel-interleaved:
word 0 is channel 0 at address 0, word 1 channel 1 at address 0, ..., word `NM` is channel 0 at address 1, and so on
up to word `NM*2**N - 1` (channel `NM-1` at address `2**N - 1`), which carries `tlast`.

## U2. Rules that are not obvious

- **Every `DR_START` pulse starts a full-window burst, always.** There is no partial-channel or partial-address
  readout: a read drains all `NM` channels and all `2**N` addresses every time. Consume the whole `TOTAL_WORDS` burst
  before pulsing `DR_START` again, or the next read sees stale data left in the output path.
- **`DW_CAPTURE` and `DR_START` are levels, not pulses**, and both need a low-then-high transition to arm/start
  again: de-assert and re-assert each one to allow a new capture or a new transfer (same convention as
  `axis_avg_buffer`'s `*_START_REG`).
- **`DW_CAPTURE_REG`/`DR_START_REG` cross clock domains inside `mr_buffer` itself**, via the core's own
  `cdc_gray_sync` instances (`sync_dw_capture`, `sync_dr_start`) into `s_axis_aclk` / `m_axis_aclk` respectively --
  the wrapper passes them through unsynchronised, on purpose, because the core already resynchronises them. The
  external `trigger` is treated the same way (`sync_trigger`, combined first with the debug force bit:
  `trigger_or_dbg = trigger | DEBUG_REG.FORCE_TRIGGER`).
- **`STATUS_REG.CAPTURE_DONE` is the AND of every channel's own `capture_done`** (`axis_to_bram_trig`'s), so it only
  goes high once *all* `NM` channels have finished; it clears when `DW_CAPTURE` is de-asserted (re-armed).
- **A firmware bug in version 1.0/1.1 returns junk data at the start of a transfer.** The monolithic driver's
  `_init_config` sets `self.cfg['junk_len'] = 8` for `mr_buffer_et:1.0` and 0 for anything else, and `transfer()`
  skips that many samples at the front of the returned array by default. This packaging is version **1.2**, after
  the fix per the driver's own version check -- but note the monolithic driver's `bindto` does not reach `1.2`
  anyway (see the driver note above), so this fact matters mainly if you port its logic into a new driver.
- **`s_axis_tready` requires every channel to be ready**, `= (&s_axis_tready_i) | FORCE_TREADY`: one slow channel
  writer stalls the whole input, unless the debug force bit is set.
- **`DEBUG_REG` is not synchronised at the point of use**; it relies on being quasi-static (a debug/bring-up
  register, not toggled during normal operation), unlike the level controls above which do get a real CDC.

## U3. Data formats

- `s_axis_tdata`: `NM * B` bits, `NM` channels packed side by side (a beat has one sample per channel).
- `m_axis_tdata`: `B` bits, one channel/address per beat, in the word order of U1.
- With the deployed ZCU216 configuration (`NM = 2`, `N = 16`, `B = 16`): `s_axis_tdata` is 32 bits, the drained
  buffer is `2 * 65536` int16 samples, and `data[0::2]` / `data[1::2]` give I and Q (an interleaved pair, matching
  the word order above).

## U4. Memories, throughput and limits

- `NM` independent true-dual-port BRAMs, each `2**N` deep and `B` bits wide (RTL defaults `NM = 8`, `N = 8`, `B = 16`;
  the deployed instance overrides them, see U3). `TOTAL_WORDS = NM * 2**N` per burst.
- Write side: one sample per channel per `s_axis_aclk` cycle once armed and triggered. Read side: one word per
  `m_axis_aclk` cycle, `TOTAL_WORDS` cycles per drain.
- `axis_to_bram_trig` (per channel) and `bram_to_axis_nt` (the reader) each contain their own internal `fifo_sync`
  (an XPM sync FIFO) between the AXI4-Stream side and the BRAM port -- not a direct combinational/registered path.

## U5. Python quick start

```python
from qick import QickSoc
soc = QickSoc(bitfile)                          # a debug bench without a tProc: QickSoc(bitfile, no_tproc=True)
mr = soc.mr_buffer_et_0                          # readout.MrBufferEt; mr.dma is traced from m_axis

data = mr.capture()                              # arm, software trigger, wait for CAPTURE_DONE, DMA the window
# data: (maxlen, 2) int16, maxlen = NM * 2**N

mr.arm()                                         # with the real trigger input instead:
assert mr.wait_capture(timeout=1.0)              # ... the trigger fires ...
data = mr.transfer()
```

- `arm()` writes DW_CAPTURE 0 then 1 (the 0 also clears CAPTURE_DONE).
- `force_trigger()` pulses `DEBUG_REG.FORCE_TRIGGER`.
- `capture_done()` and `wait_capture()` read `STATUS_REG`.
- These four exist on this `1.2` core only; on the legacy IP they raise.

With a tProc, `soc.arm_mr()` plus a program's `trigger(mr=True)` does the arming and triggering (U8).

## U6. Using it in a block design

- `s_axis` <- `NM` channels of a full-speed readout (through an `axis_switch` if several readouts share this
  buffer); `m_axis` -> an AXI DMA S2MM. `trigger` <- an external hardware trigger source (traced by the monolithic
  driver's `configure_connections`, which also finds the switch and the downstream readouts).
- Three clocks: `s_axi_aclk`, `s_axis_aclk`, `m_axis_aclk`, all independent (U1).
- Parameters: `NM`, `N`, `B` on the core; the wrapper's `.core` file also exposes `MRBUF_NM` / `MRBUF_N` as
  simulation-only `vlogdefine`s for exercising a deployed-size configuration in `make sim` (default 8/8, ZCU216 uses
  2/16 via the `test_deployed` fusesoc target).
- Constraints: `constraints/mr_buffer_et.xdc` declares one `set_clock_groups -asynchronous` across all three clocks
  (covering every CDC path, including the true-dual-port BRAM write<->read pair, on the strength of the
  `ASYNC_REG`-tagged synchroniser cells) plus a false path on `trigger`. `constraints/mr_buffer_et_ooc.xdc` gives OOC
  placeholder clocks (100 MHz, 307.2 MHz, 100 MHz -- the file's own comment calls the 100 MHz ones "~99 MHz", a
  label/value mismatch worth a one-line fix, not a constraint problem).
- **Driver binding:** `MrBufferEt` binds `qick:ip:mr_buffer_et:1.2` (see the driver note at the top).

## U7. Gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Not de-asserting `DW_CAPTURE`/`DR_START` between operations | The next arm/start never takes effect | Write 0, then 1, for every new capture/drain |
| Pulsing `DR_START` before the previous drain finished | The next read sees stale data | Consume the full `TOTAL_WORDS` burst first |
| Reading data from a version-1.0 build without skipping the junk prefix | The first 8 samples are garbage | Skip `junk_len` samples (0 on this 1.2 packaging, but check the version if you port the logic) |
| One channel's writer not ready | The whole input stalls (`s_axis_tready` is the AND of all channels) | Fix the slow channel, or set `DEBUG_REG.FORCE_TREADY` for bring-up |
| Toggling `DEBUG_REG` during normal operation | Not synchronised at the point of use | Treat it as bring-up/debug only |

## U8. Validation status

- **Hardware: this `1.2.0` packaging validated on an RFSoC4x2 (2026-09-24)** with a debug bench, a one-channel reduction of `4x2/tpv2_std` built only from fusesoc IPs, driven by standard `QickSoc` + `AveragerProgramV2` programs: `soc.arm_mr()` + a
  tProc trigger (`trigger(mr=True)`, tport 2) captured 8192 full-speed samples of the loopback pulse (0.300 us measured
  for 0.3 us); a raw-ADC capture (`outsel='input'`) has a clean spectrum, peak at 99.90 MHz for 100 MHz and
  55.8 dB SFDR, so the 8-sample word ordering is right. The monolithic driver was fixed to trace the fusesoc bus names (`s_axis`/`m_axis`).
  Earlier: confirmed end-to-end on a ZCU216 with the pre-1.2 driver against an earlier build.
- **Simulation**: core (`mr_buffer`) 11/11 SVUnit, wrapper (`mr_buffer_et`) 8/8, both lint clean. Core tests:
  basic write/read, multiple beats, re-arm for a second capture, a trigger before arm is ignored, no `tready` without
  a capture armed, the `tready` force override, `tlast` on the last word, `CAPTURE_DONE` asserting, two bursts drained
  from the same capture, the tail not lost on disarm, and a full window retiring without wraparound. The wrapper adds
  an AXI-Lite register round trip and drives the same scenarios through the register map. Driver register-layer
  pytest 4/4 (`test_reset_values`, `test_register_offsets`, `test_field_roundtrip`, `test_register_independence`),
  and 8 behaviour tests of `MrBufferEt` against a register-level model of the IP (`test_mr_buffer_et_driver.py`).
- Not verified: which board/target the current hardware validation exactly maps to beyond "ZCU216"; whether the
  clock-group-only CDC strategy (no per-cell `set_max_delay -datapath_only`, unlike some other IPs in this repo) is
  an intentional, sufficient choice for this design or worth tightening.

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `s_axi_*` | | AXI4-Lite slave (`s_axi_aclk`) |
| `trigger` | in | asynchronous external capture trigger |
| `s_axis_aclk`, `s_axis_aresetn`, `s_axis_tdata[NM*B-1:0]`, `tvalid`, `tready`, `tlast`, `tstrb` | | write/capture side |
| `m_axis_aclk`, `m_axis_aresetn`, `m_axis_tdata[B-1:0]`, `tvalid`, `tready`, `tlast`, `tstrb` | | read/drain side |
| `s_dbg_probe[31:0]`, `m_dbg_probe[31:0]` | out | debug probes, driven only when the `DEBUG` parameter is 1 (tied 0 otherwise) |

## Registers

The driver class `MrBufferEt` keeps a hand-written dictionary of this map, with the attribute names the software uses. `STATUS_REG` and `DEBUG_REG` exist only in this core: the legacy 1.0 and 1.1 keep a two-register dictionary (`DW_CAPTURE` 0, `DR_START` 1, as in their axi slave) and have no `regs`.

| Addr | Register | Field | Access | Description |
|---|---|---|---|---|
| 0x00 | `DW_CAPTURE_REG` | `DW_CAPTURE[0]` | RW | write 1 to arm the writer (all `NM` channels together) |
| 0x04 | `DR_START_REG` | `DR_START[0]` | RW | write 1 to drain the captured window as one burst |
| 0x08 | `STATUS_REG` | `CAPTURE_DONE[0]` | R | high once every channel has finished capturing |
| 0x3C | `DEBUG_REG` | `FORCE_TRIGGER[0]`, `FORCE_TREADY[1]` | RW | bring-up only, U2 |

Registers 0x0C-0x38 are unmapped (read 0). Source: `rdl/mr_buffer_et_regmap.rdl`. `axil_slv` is instantiated with
only `STATUS_REG` marked read-only.

## Internal architecture

**Core (`mr_buffer`, `qick:mem:mr_buffer`):** one `axis_to_bram_trig` per channel (arms on the resynchronised
`dw_capture`, starts capturing on the resynchronised `trigger`, writes `bram_tdp` port A); a single `bram_to_axis_nt`
concatenates every channel's `bram_tdp` port-B output and serialises the full window onto `m_axis` in the word order
of U1, armed by the resynchronised `dr_start`. `o_capture_done` is the AND-reduction of every channel's own
`capture_done`.

**Wrapper (`mr_buffer_et`):** `axil_slv` register bank (U3.2 register map); `DW_CAPTURE`/`DR_START`/`DEBUG` pass
through to the core unsynchronised (the core resynchronises the first two itself, U2); `STATUS.CAPTURE_DONE` is
brought back from `s_axis_aclk` to `s_axi_aclk` with a dedicated `cdc_bit_sync`.

Sub-cores: `cdc_gray_sync` (`qick:cdc:cdc_gray_sync`), `axis_to_bram_trig` (`qick:axi:axis_to_bram_trig`, contains an
internal `fifo_sync`), `bram_tdp` (`qick:mem:bram_tdp`), `bram_to_axis_nt` (`qick:axi:bram_to_axis_nt`, also
contains an internal `fifo_sync`), `cdc_bit_sync` (`qick:cdc:cdc_bit_sync`).

## Verification

`make lint IP=mr_buffer` / `make lint IP=mr_buffer_et` (both clean); `make sim IP=mr_buffer` (11/11, `tc00`-`tc10`) /
`make sim IP=mr_buffer_et` (8/8, `tc00`-`tc07`); driver pytest in
`cores/ip/mr_buffer_et/driver/tests/test_mr_buffer_et_regs.py` (4/4) and `test_mr_buffer_et_driver.py` (8/8, `MrBufferEt`
with pynq stubbed). `make sim IP=mr_buffer_et --MRBUF_NM=<n>
--MRBUF_N=<n>` (or the `test_deployed` fusesoc target, default `MRBUF_NM=2 MRBUF_N=16`) exercises a deployed-size
configuration instead of the RTL defaults.

## Files

```
cores/mem/mr_buffer/              (core datapath, referenced by the wrapper)
  hdl/mr_buffer.sv
  mr_buffer.core                  # VLNV qick:mem:mr_buffer:1.0.0
  tests/                          # 11 SVUnit tests
cores/ip/mr_buffer_et/
  README.md
  mr_buffer_et.core                # VLNV qick:ip:mr_buffer_et:1.2.0
  hdl/mr_buffer_et.sv              # axil_slv + cdc_bit_sync + mr_buffer
  rdl/mr_buffer_et_regmap.rdl
  driver/mr_buffer_et.py           # alias of qick_lib/qick/drivers/readout.py (MrBufferEt)
  driver/tests/test_mr_buffer_et_regs.py
  driver/tests/test_mr_buffer_et_driver.py
  constraints/mr_buffer_et.xdc, mr_buffer_et_ooc.xdc
  tests/                           # 8 SVUnit tests
  data/
```

## Open items

- Re-run the ZCU216 hardware validation of U8 against this exact `1.2.0` packaging, through the driver.
- Decide whether the clock-group-only CDC constraint strategy needs the more granular per-cell
  `set_max_delay -datapath_only` some other IPs in this repo use.
- Fix the `~99 MHz` label on the 100 MHz OOC placeholder clocks in `mr_buffer_et_ooc.xdc` (cosmetic).
