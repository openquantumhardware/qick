# AXIS Average + Buffer (axis_avg_buffer)

The block that receives the readout's I/Q samples and keeps them for the PS: an **averager** that accumulates a window of
samples per trigger (the number you read out after many shots), and a **raw buffer** that stores the decimated samples of
one window. Both are armed from registers and started by a hardware trigger, usually from the tProcessor; the data are read
back through DMA. A third stream sends each accumulated result straight to the tProc.

- Project: QICK, `qick:ip:axis_avg_buffer:1.2.1` (module `axis_avg_buffer`, `N_AVG = 10`, `N_BUF = 10`, `B = 16`)
- Driver: class `AxisAvgBufferV1pt2` (base `AxisAvgBuffer`) in `qick_lib/qick/drivers/readout.py`; its `bindto` **already lists
  `qick:ip:axis_avg_buffer:1.2`**, so this packaging binds. Symlinked from `driver/axis_avg_buffer.py`; register-layer test in
  `driver/tests/`
- Sibling: `axis_weighted_buffer` (a matched-filter version of the same buffer)
- Hardware bring-up: none of this fusesoc version (see U8)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 readout m_axis --s_axis (I/Q samples, B bits each)--+--> averager (accumulate LEN samples per trigger) --> memory 2^N_AVG
                                                     |                       |--> m2_axis: each result as it is computed (to a tProc register)
                                                     +--> raw buffer (LEN decimated samples)          --> memory 2^N_BUF
 trigger (from the tProc) ------------------------------- starts an armed capture
 AXI4-Lite registers: arm, address, length, and a "data reader" per memory ----> m0_axis (averaged data), m1_axis (raw data) --> DMA
```

Capture on either memory starts when its `*_START_REG` is 1 **and** the trigger arrives. Reading is separate: the data-reader
registers stream a range of a memory out of `m0_axis` (averages) or `m1_axis` (raw), to be picked up by an AXI DMA.

## U2. Rules that are not obvious

- **The `*_START_REG` registers are levels, not pulses.** Software holds them at 1 through a whole capture and drops them to release
  the state machine. The driver's `enable()` sets them, `disable()` clears them, and `config_avg` / `config_buf` **disable
  first**.
- **Arm, then trigger.** Setting `AVG_START_REG` / `BUF_START_REG` only arms the capture; the trigger (a bit from the tProc, the
  `trigger_*` fields in the QICK config) starts it.
- **Two readouts of two memories, two DMAs.** The averaged data leave through `m0_axis`, the raw ones through `m1_axis`; each
  is enabled by its own `*_DR_START_REG`. The driver's `_start_transfer` / `_stop_transfer` handle that.
- **Lengths must stay below the memory size.** The driver refuses `length >= 2**N_AVG` (averaged) or `>= 2**N_BUF` (raw): the
  maximum is one less than the memory depth.
- **Even transfers.** The driver rounds a transfer length up to an even number and trims afterwards
  (`PAD_ODD_TRANSFERS = True`). That was the workaround for a legacy data-reader bug (`tlast` one beat early
  on an odd length, `tvalid` left high). The reader of this IP does not have it: odd lengths read correctly in simulation and
  on a board (U8). The padding stays because `AxisAvgBufferV1pt2` also binds the legacy 1.2 firmware, which may predate that
  fix. Set `PAD_ODD_TRANSFERS = False` on the driver object to request the exact length.
- **First-output-sample bug in IP versions up to 1.1.** Firmware older than 1.2 returned a wrong first sample of each transfer;
  the driver reads two extra samples and drops them (`FIRST_OUT_SAMPLE_BUG_FIX = False`). This IP is the 1.2 revision (bug
  fixed: the register map and RTL are identical to the legacy 1.2), and `AxisAvgBufferV1pt2` skips the workaround.
- **Photon (edge-counting) mode** (added in 1.1): `AVG_PHOTON_MODE_REG = 1` makes the averager count edges with a
  Schmitt-trigger hysteresis (`AVG_H_THRSH_REG` high, `AVG_L_THRSH_REG` low) instead of summing I/Q; `config_avg(...,
  edge_counting=True, high_threshold=..., low_threshold=...)` sets it.

## U3. Data formats

- Input `s_axis_tdata`: one complex sample, `{Q, I}` of `B` = 16 bits each, one per clock at the decimated rate.
- Averaged memory: each entry is a pair of 32-bit accumulated I and Q (the driver reads them as int32 pairs from a 64-bit
  buffer). The result is a **sum**, not a mean: divide by the number of shots and by `length` in software.
- Raw memory: each entry is `{Q, I}` int16 in one 32-bit word (the driver returns an (n, 2) int16 array).
- `m2_axis`: each accumulated result as soon as it is computed, to feed a tProc register.

## U4. Memories, throughput and limits

- Averaged memory `2**N_AVG` entries; raw memory `2**N_BUF` entries (default 1024 each). The packaged sizes are the
  `N_AVG` / `N_BUF` parameters; the driver reads them from the block design (`avg_maxlen`, `buf_maxlen`).
- One input sample per clock; DMA throughput is limited by the DMAs.

## U5. Python quick start

```python
buf = soc.axis_avg_buffer_0                 # normally driven by the QICK programs (AveragerProgram / V2)
buf.config_avg(address=0, length=100)       # disables, then sets the address and window length
buf.config_buf(address=0, length=100)
buf.enable(avg=True, buf=True)              # arm both; the tProc trigger starts the capture
# ... run the program, then:
iq_sum = buf.transfer_avg(address=0, length=100)   # (n, 2) int32: accumulated I, Q
iq_raw = buf.transfer_buf(address=0, length=100)   # (n, 2) int16: raw decimated I, Q
```

In practice the acquisition methods of the QICK programs call these.

## U6. Using it in a block design

- `s_axis` <- a readout's decimated output (`axis_readout_v2`, `axis_readout_v3`, `axis_dyn_readout_v1`, a PFB readout). The
  driver finds the readout by tracing this connection.
- `m0_axis` / `m1_axis` -> an AXI DMA each, through stream switches if the DMA is shared (the driver finds them); `m2_axis` ->
  a tProc input port if the program needs the results (optional).
- The trigger input comes from the tProc (a `vect2bits` bit or a trigger port); `s_axi` -> the PS interconnect.
- Parameters: `N_AVG`, `N_BUF` (memory depths), `B` (sample width).
- Clocks: `s_axi_aclk` (configuration), `s_axis_aclk` (capture), `m_axis_aclk` (read side); the last two may be the same clock.

## U7. Gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Arming without a trigger | Nothing is captured | Send the trigger from the program |
| Expecting a mean | The averaged data are sums | Divide by shots and `length` |
| `length` equal to the memory depth | `RuntimeError` | Use at most `depth - 1` |
| Old firmware (< 1.2) with a driver that skips the workaround | The first sample of each transfer is wrong | Use the class that matches the version (`AxisAvgBuffer` / `V1pt1` / `V1pt2`) |
| Forgetting to `disable()` between configurations | The FSM stays armed | `config_*` already disables |

## U8. Validation status

- **Simulation**: 8 SVUnit tests: reset state, register read-back, a raw-buffer capture and read-back, arming the averager
  without arming the buffer, and four on odd-length readouts (9, 7 and 1 samples from both readers: `tlast` on the last beat
  only, exactly N beats and nothing after, the data beat by beat, an odd read followed by even reads, a stall in front of the
  last beat). Those four fail against the reader with `tlast` one beat early and with one beat too many. The stimulus is
  driven `#TSU` after the clock edge (TESTBENCH_PATTERNS.md, section 19). One clock for `s_axis` and `m_axis`: independent
  clocks are covered by the `avg_top` / `buffer_top` tests.
- **Hardware**: RFSoC4x2, a debug bench (build 2026-09-22 `67644BA-dirty`), DAC0 looped
  into ADC0 through `axis_readout_v2`: both buffers capture the tone and the averaged magnitude is 100.0x the raw one for
  100 samples per average. Odd-length transfers (2026-10-12): 24 fixed cases (raw 1 to 499 samples, averaged
  1 to 19, several addresses) and 200 random ones, with the driver's padding off, 0 failed (95 % upper bound on the random
  set's failure rate: 1.5 %); the bytes moved by the DMA were checked to equal the exact length. That bitstream has the
  inferred `bram_tdp`, today's RTL uses `xpm_memory_tdpram` (same interface and latency); the reader, buffer and DMA path are
  unchanged.
- **1.2.1 (timing at 512 MHz, 111/tpv2_std)**: the averager registers `trigger_i`, `din_valid_i` and `din_i` on entry
  (the trigger with the data, so the first accumulated sample is the same one) and `mem_we_o`, `mem_addr_o` and `mem_di_o` on
  exit; `cnt > 1` is a registered flag. The write reaches the memory two clocks later and the averaged data are the same.
  `avg` tests 20 of 20: three new ones, two fix the window (a valid sample in the trigger cycle and one right after the window are
  not accumulated) and the strobe (one clock; none when `start_reg` drops in `WRITE_MEM_ST`), the third a held trigger; each register undone in the RTL
  fails a test (5 mutations; leaving `WAIT_TRIGGER_ST` on `trigger_i` or on its delayed copy is the same behaviour).
- **1.2.1 on the board (2026-11-09)**: RFSoC4x2, the same debug bench and a 100 MHz tone DAC0 -> ADC0, one load of each
  bitstream: a new build `E8E1A7B` (Vivado 2025.2, WNS +0.273 ns) and the one of 2026-09-22 (averager 1.0.0). Both: mean averaged
  magnitude / mean raw magnitude = 100.0 (the new one reads 0.2 % higher on both buffers; the I/Q phase differs between loads),
  and 24 fixed and 200 random exact-length transfers (102 odd), 0 failed in both (95 % upper bound on the failure rate 1.5 %).
  This bench cannot see a one-sample shift of the window (a constant tone sums the same) and does not use photon mode: both are
  covered in simulation only.
- Not verified: accumulation over many shots at the full trigger rate, photon mode against a real signal, the DMA readout of the
  full memories.

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `s_axi_*` | | AXI4-Lite slave (6-bit address, 15 registers) |
| `s_axis_aclk`, `s_axis_aresetn`, `s_axis_tdata[2*B-1:0]`, `tvalid`, `tready` | | I/Q input |
| `m_axis_aclk`, `m_axis_aresetn` | in | read-side clock and reset |
| `m0_axis_*` | out | averaged data to DMA |
| `m1_axis_*` | out | raw data to DMA |
| `m2_axis_*` | out | each accumulated result, to a tProc register |
| `trigger` | in | starts an armed capture |

## Registers

The driver class `AxisAvgBufferV1pt2` keeps a hand-written dictionary of this map, with the attribute names the software uses. Two names differ from the RDL: `avg_h_threshold_reg` / `avg_l_threshold_reg` are `AVG_H_THRSH_REG` / `AVG_L_THRSH_REG`. The indexes are the ones the driver has always used and the legacy `axi_slv_avg_buf.vhd` wires (AVG_START 0 ... BUF_DR_LEN 11, AVG_PHOTON_MODE 12, AVG_H_THRSH 13, AVG_L_THRSH 14). The versions 1.0 (twelve registers) and 1.1 share the base class but exist only as legacy firmware: no RDL, no `regs`, same map as before.

| Addr | Register | Description |
|---|---|---|
| 0x00 | `AVG_START_REG` | averager enable (bit 0, a level) |
| 0x04 | `AVG_ADDR_REG` | averager write start address |
| 0x08 | `AVG_LEN_REG` | samples to accumulate per result |
| 0x0C | `AVG_DR_START_REG` | averager data reader enable (bit 0) |
| 0x10 | `AVG_DR_ADDR_REG` | averager reader start address |
| 0x14 | `AVG_DR_LEN_REG` | averager reader sample count |
| 0x18 | `BUF_START_REG` | raw buffer enable (bit 0, a level) |
| 0x1C | `BUF_ADDR_REG` | raw buffer write start address |
| 0x20 | `BUF_LEN_REG` | raw samples to capture |
| 0x24 | `BUF_DR_START_REG` | raw reader enable (bit 0) |
| 0x28 | `BUF_DR_ADDR_REG` | raw reader start address |
| 0x2C | `BUF_DR_LEN_REG` | raw reader sample count |
| 0x30 | `AVG_PHOTON_MODE_REG` | 0 accumulate, 1 edge/photon counter (bit 0) |
| 0x34 | `AVG_H_THRSH_REG` | photon mode high threshold |
| 0x38 | `AVG_L_THRSH_REG` | photon mode low threshold |

Source: `rdl/axis_avg_buffer_regmap.rdl`.

## Verification

`tests/axis_avg_buffer_tests.sv`: `test_reset_idle`, `test_register_readback`, `test_buf_capture_and_readback`,
`test_avg_only_arms_avg_not_buf`, `test_buf_readout_odd_lengths`, `test_avg_readout_odd_lengths`,
`test_buf_odd_then_even_reads_same_capture`, `test_buf_odd_read_with_backpressure`. `make sim IP=axis_avg_buffer`.

## Files

```
cores/ip/axis_avg_buffer/
  README.md
  axis_avg_buffer.core               # VLNV qick:ip:axis_avg_buffer:1.2.1
  hdl/axis_avg_buffer.sv             # AXI-Lite wrapper + avg_top, buffer_top (rtl_lib)
  rdl/axis_avg_buffer_regmap.rdl
  driver/axis_avg_buffer.py -> qick_lib/qick/drivers/readout.py ; driver/tests/
  tests/
```

## Open items

- Driver: the `qick:ip:axis_avg_buffer:1.2` VLNV is already in `bindto`; what is left of the `qick_time_tagger` flow is the
  per-IP driver file and a board validation.
- More simulation depth: averaging over several triggers and photon mode.
