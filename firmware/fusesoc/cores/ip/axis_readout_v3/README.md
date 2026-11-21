# AXIS Readout v3 (axis_readout_v3)

The tProc-controlled readout with 4 lanes: it takes 4 real ADC samples per clock, multiplies them by a complex DDS to
shift a chosen frequency to zero, low-pass filters and decimates by 4, and produces one complex I/Q sample per clock.
There are no registers: the frequency, phase, length and output source arrive as descriptors on a stream, sent by the
tProcessor as part of the program.

- Project: QICK, `qick:ip:axis_readout_v3:1.0.1` (module `axis_readout_v3`, `N = 4`)
- Driver: none in the PYNQ sense (no registers). The class `AxisReadoutV3` in `qick_lib/qick/drivers/readout.py`
  represents the block and its connections; it is created by the averaging buffer that the readout feeds (U5)
- Siblings: `axis_readout_v2` (registers, 8 lanes) and `axis_dyn_readout_v1` (tProc-configured, 8 lanes)
- Hardware bring-up: none of this fusesoc version (see U8)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 tProc --s0_axis (88-bit descriptor)--> FIFO (16 deep) --> DDS control (phase, frequency, output source)
                                                                    |
 ADC/resampler --s1_axis (4 x 16-bit real samples / clock)--> x complex DDS
                                                                    |
                                                        low-pass FIR, decimate by 4
                                                                    |
                                          m_axis (32-bit complex per clock: {imag[15:0], real[15:0]})
```

Everything runs on one clock (`aclk`). The output source (`outsel` in the descriptor) is the product (normal
readout), the DDS alone (debug) or the raw input.

## U2. Rules that are not obvious

- **Configuration is a stream.** A descriptor is 88 bits, pushed by the tProc into `s0_axis`; `s0_axis_tready` is low only
  while the 16-entry FIFO is full. Nothing can be read back.
- **Descriptor layout** (the same as `axis_dyn_readout_v1` / `axis_readout_v2`, whose registers build it):

  | bits | field | meaning |
  |---|---|---|
  | 87..84 | unused | |
  | 83 | `phrst` | reset the free-running sample counter that keeps the phase coherent |
  | 82 | `mode` | 1 = periodic (non-stop), 0 = run `nsamp` samples |
  | 81..80 | `outsel` | 0 product, 1 DDS only, 2 input |
  | 79..64 | `nsamp` | number of output samples |
  | 63..32 | `phase` | initial phase |
  | 31..0 | `freq` | phase increment (frequency) |

- **Phase is coherent across descriptors.** A free-running counter (advanced by the number of lanes each clock) is used to
  compute the phase of every lane, so changing the frequency does not jump the phase; `phrst` restarts that counter.
- **Modes.** In NSAMP mode the control runs a descriptor for `nsamp` samples and then waits for the next one; in
  periodic mode it does not wait. A descriptor lasts at least 3 clocks: `nsamp` 0, 1 and 2 run as 3 (`ctrl_dyn_ro`
  1.0.1, in 1.0.1 of this IP; qick_lib never sends less than 3). Before, they stopped the readout for about 2^32 clocks.
- **The product is truncated, not rounded.** Bits [30:15] of the 32-bit product are kept with no rounding constant (the
  other readouts round to nearest), which leaves a small DC offset in I and Q: the software class has `IQ_OFFSET = -0.5`
  (in counts of the decimated samples), the offset the software expects and subtracts when offset removal is enabled
  (`remove_offset` in the acquisition, `QickProgram` offset handling).
- **Output packing.** The FIR's 18-bit result per component is reduced to 16 bits by dropping the LSB and the top (sign
  duplicate) bit, i.e. bits [16:1] of each 18-bit field, then packed `{imag, real}`.
- **No back-pressure.** The input is consumed every clock (`s1_axis_tready` follows the datapath, and the down-conversion
  keeps `tvalid` up), so the consumer of `m_axis` must always accept.
- **Latency.** The down-conversion has a fixed pipeline (input samples are delayed by 12 clocks and `outsel` by 15 to line
  up with the DDS); the software accounts for the readout latency, do not compensate it by hand.

## U3. Data formats

- `s1_axis_tdata`: `N * 16` = 64 bits, four 16-bit signed real samples (lane 0 the earliest).
- `m_axis_tdata`: 32 bits `{imag[15:0], real[15:0]}`, one sample per clock. Output rate = `fs / (decimation * 4)`
  (`f_output` in the QICK config; `DOWNSAMPLING = 4` in the driver class).
- Frequency: `f = freq * f_dds / 2^32` with `f_dds = fs / decimation`. Use the software (`freq2reg_adc`,
  `declare_readout`), which knows the tile decimation.
- **Clock factor.** In the standard designs there is a 2x1 resampler between the RFDC and this readout, so the software
  doubles the fabric frequency it reports for this block (`cfg['f_fabric'] *= 2`); the readout sees 4 samples per clock at
  twice the RFDC's fabric clock.

## U4. Memories, throughput and limits

Only the 16-entry descriptor FIFO. One input word per clock and one output word per clock at 1/4 of the input sample
rate.

## U5. Python quick start

There is nothing to instantiate by hand. `QickSoc` finds the block through the averaging buffer it feeds: the buffer's
driver traces back to a block of type `axis_readout_v3`, creates `AxisReadoutV3` for it and reads which tProc port
drives `s0_axis` and which ADC feeds `s1_axis`. From a program you use:

```python
prog.declare_readout(ch=0, length=..., freq=..., gen_ch=..)      # AveragerProgramV2 / RAveragerProgram
```

and the program sends the descriptors.

## U6. Using it in a block design

- `s0_axis` <- a tProc output port (through `axis_tmux_v1` if the design multiplexes ports). The software follows this
  trace, so keep it a direct stream connection.
- `s1_axis` <- the RFDC ADC stream through the 2x1 resampler. `aclk` / `aresetn` = the fabric clock the resampler produces.
- `m_axis` -> an averaging buffer (`axis_avg_buffer` or `axis_weighted_buffer`).
- Parameter `N` = 4 (fixed by the filter).
- **The IP has no AXI-Lite interface:** do not connect `s_axi`. The `rdl/axis_readout_v3_regmap.rdl` is an empty
  placeholder that keeps the standard `rdl/` scaffold consistent.

## U7. Gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Looking for registers | There are none | Configure from the program (descriptors) |
| Ignoring the 2x fabric-clock factor | Time axis or frequencies off by 2 | Use the software's `f_fabric` for this block |
| Comparing I/Q with another readout at the LSB level | Offset of about -0.5 count (truncation) | The software subtracts `IQ_OFFSET` when offset removal is on; do not double-correct |
| Consumer that stalls `m_axis` | Data lost (no back-pressure) | Always accept |
| Descriptors sent faster than the FIFO drains | `s0_axis_tready` low, the tProc stalls | Pace the program |

## U8. Validation status

- **Simulation**: 4 SVUnit tests (reset state, raw input passthrough to `m_axis`, DDS-only output non-zero, product output
  non-zero). These check that the data path is alive; they do **not** check the frequency accuracy or the FIR gain.
- **Hardware**: this fusesoc packaging has not been built into a bitstream or run on a board. The datapath is a port of
  the legacy IP used by the tProc v2 firmwares.
- Not verified: frequency accuracy, the exact I/Q offset, the FIR response and the latency numbers against the legacy IP
  on a bitstream.

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `aclk`, `aresetn` | in | single clock domain |
| `s0_axis_tdata[87:0]`, `tvalid`, `tready` | | descriptor stream; `tready = ~fifo_full` |
| `s1_axis_tdata[N*16-1:0]`, `tvalid`, `tready` | | ADC samples |
| `m_axis_tdata[31:0]`, `tvalid`, `tready` | | decimated I/Q |

## Registers

None (see `rdl/axis_readout_v3_regmap.rdl`, an empty address map).

## Verification

`tests/axis_readout_v3_tests.sv`: `tc_reset_idle`, `tc_outsel_raw_passthrough_reaches_m_axis`,
`tc_dds_only_produces_nonzero_output`, `tc_product_produces_nonzero_output`. `make sim IP=axis_readout_v3`. The
descriptor lengths are checked in the `ctrl_dyn_ro` tests (`make sim IP=ctrl_dyn_ro`).

## Files

```
cores/ip/axis_readout_v3/
  README.md
  axis_readout_v3.core                 # VLNV qick:ip:axis_readout_v3:1.0.1
  hdl/axis_readout_v3.sv               # wraps readout_top_ro_v3 (rtl_lib/dsp)
  rdl/axis_readout_v3_regmap.rdl       # empty: no registers
  driver/axis_readout_v3.py            # AxisReadoutV3 lives in qick_lib/qick/drivers/readout.py
  tests/
```

Datapath sources: `rtl_lib/dsp/readout_top_ro_v3.sv`, `down_conversion_ro_v3.sv`, `fir_decim4_ro_v3.sv` (FIR from an `.xci`),
`rtl_lib/ctrl/ctrl_dyn_ro.sv` (descriptor control).

## Open items

- Frequency-accuracy and latency checks on hardware against the legacy IP.
- Driver: the block has no registers, so `AxisReadoutV3` is not a PYNQ driver but a class the averaging buffer's driver
  creates from the block-design trace. Its handling will follow the `qick_time_tagger` flow (firmware/docs/user/BOARD_WORKFLOW.md,
  firmware/docs/developer/DRIVER.md), adapted to a register-less block; not started.
