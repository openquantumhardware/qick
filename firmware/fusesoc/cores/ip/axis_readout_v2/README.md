# AXIS Readout v2 (axis_readout_v2)

The PS-configured readout: it takes the ADC samples (8 real samples per clock), multiplies them by a complex numerically
controlled oscillator (DDS) to shift a chosen frequency to zero, low-pass filters and decimates by 8, and produces one
complex I/Q sample per clock. The frequency, phase and output source are set through AXI4-Lite registers from Python.

- Project: QICK, `qick:ip:axis_readout_v2:1.0.1` (module `axis_readout_v2`, `N_DDS = 8`)
- Driver: `AxisReadoutV2` in `qick_lib/qick/drivers/readout.py` (`cores/ip/axis_readout_v2/driver/axis_readout_v2.py` is a
  symlink to that file). Register-layer test: `driver/tests/test_axis_readout_v2_regs.py`
- Siblings: `axis_readout_v3` (4 lanes, tProc-configured) and `axis_dyn_readout_v1` (8 lanes, tProc-configured) share the
  descriptor format and the datapath ideas; see their READMEs
- Hardware bring-up: none of this fusesoc version (see U8)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 ADC (s_axis, 8 x 16-bit real samples / clock)
      |
      v   x  DDS (8 lanes, complex, frequency/phase from a descriptor)
   product  --------------------------------------> m0_axis (8 x 32-bit complex, BEFORE filter and decimation)
      |
      v   low-pass FIR + decimate by 8
   m1_axis  (1 x 32-bit complex per clock:  {imag[15:0], real[15:0]})

 AXI4-Lite registers --> descriptor --> FIFO (16 deep) --> DDS control
```

Each write of the registers followed by a pulse on `WE_REG` pushes one *descriptor* (frequency, phase, number of samples,
output source, mode) into a small FIFO; the DDS control logic pops them. The output source (`OUTSEL`) chooses what goes
to the outputs: the product (normal readout), the DDS alone (debug: shows the local oscillator), or the raw input
(bypass).

## U2. Rules that are not obvious

- **`WE_REG` is a level, not a pulse, and not self-clearing.** A descriptor is pushed on its **rising edge**. Write the
  parameters, then write `WE = 1` and then `WE = 0` (the driver's `update()` does this). Leaving `WE` at 1 and rewriting
  the other registers updates nothing.
- **Edge detected in the datapath clock.** `WE` is synchronised into `aclk` (the ADC-side clock) before its edge is
  taken, so consecutive updates have to be spaced by more than a couple of clock periods of the slower clock; Python
  timing is always enough.
- **Frequency word.** `FREQ` is a 32-bit phase increment: the DDS runs at the ADC sample rate divided by the tile
  decimation (`f_dds` in the QICK config), so `f = FREQ * f_dds / 2^32`. Use `QickConfig.freq2reg_adc` /
  `set_all_int` (below) rather than computing it by hand.
- **Modes.** `MODE = 0` (NSAMP): the descriptor runs for `NSAMP` samples and the control then waits for the next
  descriptor. `MODE = 1` (periodic): the control does not wait; it keeps running. The driver's default is periodic
  (`mode_reg = 1`, `nsamp_reg = 10`). A descriptor lasts at least 3 clocks: `NSAMP` 0, 1 and 2 run as 3 (`ctrl_ro_v2`
  1.0.1). Before, they stopped the descriptor reads for about 2^16 clocks, so a new register update was not applied.
- **Phase.** `PHASE` is the initial phase of the DDS; the phase is kept coherent across descriptor updates (a free-running
  sample counter is used), so changing the frequency does not jump the phase unless a phase reset is requested. The phase
  reset flag (bit 83 of the descriptor) exists in the datapath but **there is no register for it in this IP**: the
  descriptor built from the registers has `phrst = 0`.
- **Two outputs.** `m0_axis` (8 complex samples per clock) is the signal before the filter; `m1_axis` is the decimated one
  the buffers consume. Leave `m0_axis` unconnected if you do not need it.
- **Output scale.** The down-conversion product is rounded to nearest (the `axis_readout_v3` truncates instead, which
  gives it a small offset); the driver class has `IQ_OFFSET = 0.0`, i.e. no offset is compensated in software.

## U3. Data formats

- `s_axis_tdata`: 8 x 16-bit signed samples, lane 0 the earliest.
- `m1_axis_tdata`: `{imag[15:0], real[15:0]}`, one sample per clock at the decimated rate:
  output rate = `fs / (decimation * 8)` (the software's `f_output`).
- `m0_axis_tdata`: 8 x 32-bit `{imag, real}`, 8 per clock.
- Descriptor (88 bits) as built from the registers: `{mode, outsel[1:0], nsamp[15:0], phase[31:0], freq[31:0]}` (the
  layout is shared with the tProc-streamed readouts, which also carry `phrst`).

## U4. Memories, throughput and limits

Only the descriptor FIFO (16 words). One input word is accepted per clock (`s_axis_tready` follows the datapath).
If descriptors are pushed faster than the control pops them the FIFO can fill; the registers have no way to see the
full flag, so pace the updates.

## U5. Python quick start

```python
ro = soc.axis_readout_v2_0            # instance name depends on the block design
ro.set_all(f=100.0, sel='product')    # debug helper: MHz; normally QickProgram.declare_readout() does this
ro.update()                           # WE 1 -> 0: push the descriptor written into the registers
```

`set_all_int(regs)` takes the dictionary from `QickConfig.calc_ro_regs()`, sets outsel/freq/phase, `nsamp_reg = 10`,
`mode_reg = 1`, and calls `update()` **twice** (the source notes that the readout sometimes needs an extra update to
configure everything correctly, seen with a downconversion frequency of 0).

## U6. Using it in a block design

- `s_axis` <- the RFDC ADC AXI-stream (8 samples per clock); `aclk` / `aresetn` = the ADC tile's stream clock (the same
  as the RFDC's `m0_axis_aclk`).
- `m1_axis` -> an averaging buffer (`axis_avg_buffer`); `m0_axis` is optional.
- `s_axi` -> the PS AXI interconnect; `s_axi_aclk` may be the PS clock (the registers cross into `aclk`).
- Parameter: `N_DDS` = 8 (fixed by the filter).
- Add the two clock domains (`s_axi_aclk`, `aclk`) as asynchronous groups in the design's `timing.xdc`.
- **Driver binding today:** `AxisReadoutV2.bindto` (in the monolithic `readout.py`) lists only
  `user.org:user:axis_readout_v2:1.0` and `QICK:QICK:axis_readout_v2:1.0`. A block packaged from this core has the VLNV
  `qick:ip:axis_readout_v2:1.0` and is **not bound to the driver** (it falls back to `DefaultIP`) until the VLNV is
  added. The drivers of the IPs will be handled the way `qick_time_tagger`'s was (firmware/docs/user/BOARD_WORKFLOW.md, firmware/docs/developer/DRIVER.md): a driver owned by the IP, bound to its `qick:ip:` VLNV, auto-imported by `qick.py` and validated on a board.

## U7. Gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Writing registers without pulsing `WE` | Nothing changes | `update()` (WE 1 then 0) |
| Leaving `WE` at 1 | Later updates are ignored | End every update with `WE = 0` |
| `qick:ip:` block not bound to the driver | `soc.<block>` is a `DefaultIP`, no `update()` | Add the VLNV to `bindto` |
| Computing `FREQ` from the wrong rate | Tone off by the tile decimation | Use `freq2reg_adc` / `calc_ro_regs` |
| Pushing many descriptors quickly | FIFO of 16 can overflow silently | Pace the writes |

## U8. Validation status

- **Simulation**: 5 SVUnit tests (reset state, AXI register round trip, raw input passthrough on `m0`, DDS-only output
  non-zero on `m0`, product reaching the decimated `m1`) and the register-layer driver test.
- **Hardware**: this fusesoc packaging has not been built into a bitstream or run on a board. The legacy IP with the same
  registers is what the software's `AxisReadoutV2` driver was written against.
- Not verified: the frequency accuracy and the noise of the readout against a reference tone, the FIR response, the
  behaviour of the descriptor FIFO when full.
- **1.0.1.** `ctrl_ro_v2` 1.0.1: `NSAMP` 0, 1 or 2 lasts 3 clocks instead of stopping the descriptor
  reads for about 2^16 clocks. Its tests measure the length of every descriptor through a model of its FIFO, `fifo_sync` with `HOLD_DOUT` (`NSAMP` 3 to
  65535 exact, 0/1/2 give 3).

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `s_axi_*` | | AXI4-Lite slave (32-bit, 6-bit address), `s_axi_aclk` / `s_axi_aresetn` |
| `aclk`, `aresetn` | in | datapath clock and reset |
| `s_axis_tdata[N_DDS*16-1:0]`, `tvalid`, `tready` | | ADC input |
| `m0_axis_tdata[N_DDS*32-1:0]`, `tvalid`, `tready` | | before filter and decimation |
| `m1_axis_tdata[31:0]`, `tvalid`, `tready` | | decimated I/Q |

## Registers

The driver takes the word index of each register from this map: `AxisReadoutV2` reads `axis_readout_v2_regmap_pkg` (generated from `rdl/axis_readout_v2_regmap.rdl`, installed in `qick_lib/qick/rdl_pkgs/` by `make driver IP=axis_readout_v2`; `make driver-check` fails if the committed copy no longer matches the RDL) and keeps the attribute names the software uses (`freq_reg`, `phase_reg`, `nsamp_reg`, `outsel_reg`, `mode_reg`, `we_reg`); `regs` is the register model for field access. The indexes are the ones the driver has always used and the legacy `axi_slv.vhd` wires (FREQ 0, PHASE 1, NSAMP 2, OUTSEL 3, MODE 4, WE 5); a test pins the old dictionary. A write to the registers only takes effect on a rising edge of `WE_REG` (`update()`).

| Addr | Register | Field | Access | Description |
|---|---|---|---|---|
| 0x00 | `FREQ_REG` | `FREQ[31:0]` | RW | phase increment |
| 0x04 | `PHASE_REG` | `PHASE[31:0]` | RW | initial phase |
| 0x08 | `NSAMP_REG` | `NSAMP[15:0]` | RW | number of output samples |
| 0x0C | `OUTSEL_REG` | `OUTSEL[1:0]` | RW | 0 product, 1 DDS only, 2 input (bypass) |
| 0x10 | `MODE_REG` | `MODE[0]` | RW | 0 NSAMP, 1 periodic |
| 0x14 | `WE_REG` | `WE[0]` | RW | rising edge pushes one descriptor; not self-clearing |

Source: `rdl/axis_readout_v2_regmap.rdl`.

## Verification

`tests/axis_readout_v2_tests.sv`: `tc_reset_idle`, `tc_axi_register_round_trip`, `tc_outsel_raw_passthrough_reaches_m0`,
`tc_dds_only_produces_nonzero_m0`, `tc_product_reaches_decimated_m1`. `make sim IP=axis_readout_v2`. The descriptor
lengths are checked in the `ctrl_ro_v2` tests (`make sim IP=ctrl_ro_v2`).

## Files

```
cores/ip/axis_readout_v2/
  README.md
  axis_readout_v2.core                       # VLNV qick:ip:axis_readout_v2:1.0.1
  hdl/axis_readout_v2.sv -> rtl_lib/ip/...   # AXI-Lite wrapper (axil_slv) + readout_top_ro_v2 datapath
  rdl/axis_readout_v2_regmap.rdl
  driver/axis_readout_v2.py -> qick_lib/qick/drivers/readout.py
  driver/tests/test_axis_readout_v2_regs.py
  tests/
```

## Open items

- Driver: to be moved to the `qick_time_tagger` flow (per-IP driver in `driver/`, `qick:ip:axis_readout_v2:1.0` in
  `bindto`, board validation); today it is a symlink into the monolithic `readout.py`.
- No register for the phase-reset flag of the descriptor.
