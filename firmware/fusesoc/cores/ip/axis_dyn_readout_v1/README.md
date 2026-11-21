# AXIS Dynamic Readout v1 (axis_dyn_readout_v1)

The tProc-controlled readout with 8 lanes: it takes 8 real ADC samples per clock, multiplies them by a complex DDS,
low-pass filters and decimates by 8, and produces one complex I/Q sample per clock. There are no registers: the
frequency, phase, length and output source arrive as descriptors on a stream from the tProcessor. It also exposes the
signal before the filter.

- Project: QICK, `qick:ip:axis_dyn_readout_v1:1.0.2` (module `axis_dyn_readout_v1`, `N_DDS = 8`)
- Driver: none in the PYNQ sense (no registers). The class `AxisDynReadoutV1` in `qick_lib/qick/drivers/readout.py`
  represents the block and its connections (`DOWNSAMPLING = 8`, `IQ_OFFSET = 0.0`); it is created by the averaging buffer
  that the readout feeds
- Siblings: `axis_readout_v3` (4 lanes, one output, rounds by truncation) and `axis_readout_v2` (registers instead of a
  descriptor stream). The descriptor format is the same
- Hardware bring-up: none of this fusesoc version (see U8)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 tProc --s0_axis (88-bit descriptor)--> FIFO (16 deep) --> DDS control (phase, frequency, output source)
                                                                    |
 ADC --s1_axis (8 x 16-bit real samples / clock)--> x complex DDS (8 lanes)
                                                     |------------------> m0_axis (8 x 32-bit complex, before filter)
                                                     v
                                     low-pass FIR, decimate by 8
                                                     |
                                     m1_axis (32-bit complex per clock: {imag[15:0], real[15:0]})
```

One clock (`aclk`) for everything. `outsel` in the descriptor chooses the output: the product (normal readout), the DDS
alone, the raw input (bypass), and (in the down-conversion block) zero.

## U2. Rules that are not obvious

- **Configuration is a stream.** A descriptor is 88 bits, pushed by the tProc into `s0_axis`; `s0_axis_tready` is low only
  while the 16-entry FIFO is full. Nothing can be read back.
- **Descriptor layout:**

  | bits | field | meaning |
  |---|---|---|
  | 87..84 | unused | |
  | 83 | `phrst` | reset the free-running sample counter that keeps the phase coherent |
  | 82 | `mode` | 1 = periodic (non-stop), 0 = run `nsamp` samples |
  | 81..80 | `outsel` | 0 product, 1 DDS only, 2 input (3 gives zero in the down-conversion block) |
  | 79..64 | `nsamp` | number of output samples |
  | 63..32 | `phase` | initial phase |
  | 31..0 | `freq` | phase increment (frequency) |

- **Phase is coherent across descriptors:** a free-running counter (advanced by 8 each clock) sets the phase of every lane,
  so changing the frequency does not jump the phase; `phrst` restarts it.
- **Modes.** In NSAMP mode the control runs a descriptor for `nsamp` samples and then waits for the next one; in periodic
  mode it does not wait. A descriptor lasts at least 3 clocks: `nsamp` 0, 1 and 2 run as 3 (`ctrl_dyn_ro` 1.0.1; qick_lib
  never sends less than 3). Before, they stopped the readout for about 2^32 clocks.
- **The product is rounded to nearest** (to Q1.15), unlike `axis_readout_v3`, which truncates. The driver class has no
  I/Q offset (`IQ_OFFSET = 0.0`).
- **No back-pressure.** The input is consumed every clock and `tvalid` is held up in the down-conversion block, so the
  consumers of `m0_axis` and `m1_axis` must always accept.

## U3. Data formats

- `s1_axis_tdata`: 8 x 16-bit signed real samples (lane 0 the earliest).
- `m1_axis_tdata`: `{imag[15:0], real[15:0]}`, one per clock at `fs / (decimation * 8)`.
- `m0_axis_tdata`: 8 x 32-bit `{imag, real}` per clock.
- Frequency: `f = freq * f_dds / 2^32` with `f_dds = fs / decimation`; use the software (`freq2reg_adc`,
  `declare_readout`), which knows the tile decimation.

## U4. Memories, throughput and limits

Only the 16-entry descriptor FIFO. One input word and one `m0` word per clock; one `m1` word per clock.

## U5. Python quick start

Nothing to instantiate by hand. `QickSoc` finds the block through the averaging buffer it feeds: the buffer's driver traces
back to a block of type `axis_dyn_readout_v1`, creates `AxisDynReadoutV1` for it, and reads which tProc port drives `s0_axis`
and which ADC feeds `s1_axis`. From a program:

```python
prog.declare_readout(ch=0, length=..., freq=..., gen_ch=..)      # the program sends the descriptors
```

## U6. Using it in a block design

- `s0_axis` <- a tProc output port (through `axis_tmux_v1` if the design multiplexes ports).
- `s1_axis` <- the RFDC ADC stream; `aclk` / `aresetn` = the ADC tile's stream clock.
- `m1_axis` -> an averaging buffer; `m0_axis` is optional (leave it unconnected if not needed).
- Parameter `N_DDS` = 8 (fixed by the filter).
- **No AXI-Lite interface:** do not connect `s_axi`; `rdl/axis_dyn_readout_v1_regmap.rdl` is an empty placeholder.

## U7. Gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Looking for registers | None | Configure from the program |
| Descriptors sent faster than the FIFO drains | `s0_axis_tready` low, the tProc stalls | Pace the program |
| Consumer that stalls `m0` / `m1` | Data lost | Always accept |
| Expecting `axis_readout_v3`'s output offset | This one rounds; no offset | Nothing to compensate |

## U8. Validation status

- **Simulation**: 4 SVUnit tests (reset state, raw input passthrough on `m0`, DDS-only output non-zero on `m0`, product
  reaching the decimated `m1`). They check that the data path is alive; they do **not** check the frequency accuracy or the
  FIR gain.
- **Hardware: validated on an RFSoC4x2 (2026-09-24)** with a debug bench, a one-channel reduction of `4x2/tpv2_std` built only from fusesoc IPs, driven by standard `QickSoc` + `AveragerProgramV2` programs: configured by the tProc (m1 wport -> cdcsync ->
  sg_translator), full-speed output into mr_buffer_et, decimated output into axis_avg_buffer; loopback pulses measured
  with the right width (0.297 us for 0.3 us), gain linearity 0.02 %, phase coherence with the generator (slope 1.0000); gen + readout frequency sweep 50-1000 MHz; readout
  frequency reconfigured by the tProc every shot (sinc selectivity, < 10 % at >= 10 MHz); `phrst` reproducible across
  runs to ~6.5 deg at 100 MHz (one 1/552.96 - 1/614.4 MHz step of the tProc -> ADC clock crossing).
  The bring-up fixed its packaging (`s0_axis`/`m0_axis` had no associated clock) and its descriptor FIFO read semantics
  (`HOLD_DOUT`).
- Not verified: absolute frequency accuracy, noise, the FIR response.
- **1.0.1 (timing at the 4x2 ADC x2 clock, 552.96 MHz).** The DDS is `dds_compiler_dyn_readout_lat9`
  (the same `.xci` with Latency 9: its phase accumulator DSP registers its C input) and the down-conversion data
  pipelines have no reset (`down_conversion_dynro` 1.1.0). Latency and output are those of 1.0.0:
  - the two down-conversion versions side by side (xsim 2025.2, 8 lanes, 1600 random descriptors of every `outsel`,
    `mode` and `phrst`, random samples, 4 resets; 165 840 clocks) give the same output and `fifo_rd_en` bit for bit,
    except during the first 6 clocks after a reset is released (1.0.0 still showed its reset zeros there);
  - the real DDS core (Vivado 2023.1 simulation model) at Latency 9 is the Latency 8 core one clock later: bit for bit
    with the phase dithering off; with the `.xci`'s phase dithering only the dither value applied to each sample
    differs (max 26, rms 8 counts of 32767).
  Board comparison with 1.0.0 on the RFSoC4x2 (pynq4x2-2, 2026-10-27, `4x2/tpv2_std` builds E9E6BDE with 1.0.0 and
  848634E with 1.0.1, loopback DAC_A -> ADC_C and DAC_B -> ADC_D):
  - `dyn_readout_4x2_dds_alignment.ipynb`, inside one MR capture (input, DDS-only and product segments): the product
    is the input times the DDS of the same sample in every run, 16 of 16 (2 loads x 2 pairs x 2 runs per bitstream):
    residual 13.5-14.6 counts at shift 0 against ~360 at +-1 sample and ~2700 at +-8 (one clock), the same for both;
  - `dyn_readout_4x2_compare.ipynb` (REF, NEW, REF2): plateau amplitude, DDS-only output (16615 counts in both),
    50-1000 MHz sweep, gain sweep, selectivity with the readout retuned every shot and raw ADC spectrum agree within
    the reload spread; the phase is stable within each load (< 0.7 deg over 6 runs).
  - Not comparable between bitstreams: the absolute gen -> readout phase (it changes at every load) and the decimated
    pulse edge measured from the readout trigger. `dyn_readout_4x2_edge_loads.ipynb` (8 alternating loads each) puts
    the 848634E edge 2.1 ns (pair 1-1) and 1.1 ns (pair 0-0) earlier than E9E6BDE's. The readout data path is the
    same RTL in both; the readout triggers are a false path between asynchronous clocks (`timing_paths.xdc`), so the
    clock in which the trigger is captured can change from build to build. That is a hypothesis, not measured.
  - Learned on the way: the DDS phase of a descriptor follows the readout's own time base since the last phase reset,
    not the descriptor itself, so the absolute DDS latency cannot be measured per descriptor on the board (it is the
    simulation result above).
- **1.0.2.** `ctrl_dyn_ro` 1.0.1: a descriptor with `nsamp` 0, 1 or 2 lasts 3 clocks instead of
  stopping the descriptor reads for about 2^32 clocks. Its tests now measure the length of every descriptor through a
  model of its FIFO, `fifo_sync` with `HOLD_DOUT` (`nsamp` 3 to 65535 exact, 0/1/2 give 3). Not rebuilt: qick_lib sends at least 3, so a qick_lib program
  runs the same on 1.0.1 bitstreams.

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `aclk`, `aresetn` | in | single clock domain |
| `s0_axis_tdata[87:0]`, `tvalid`, `tready` | | descriptor stream; `tready` low when the FIFO is full |
| `s1_axis_tdata[N_DDS*16-1:0]`, `tvalid`, `tready` | | ADC samples |
| `m0_axis_tdata[N_DDS*32-1:0]`, `tvalid`, `tready` | | before filter and decimation |
| `m1_axis_tdata[31:0]`, `tvalid`, `tready` | | decimated I/Q |

## Registers

None.

## Verification

`tests/axis_dyn_readout_v1_tests.sv`: `tc_reset_idle`, `tc_outsel_raw_passthrough_reaches_m0`,
`tc_dds_only_produces_nonzero_m0`, `tc_product_reaches_decimated_m1`. `make sim IP=axis_dyn_readout_v1`. The descriptor
lengths are checked in the `ctrl_dyn_ro` tests (`make sim IP=ctrl_dyn_ro`).

## Files

```
cores/ip/axis_dyn_readout_v1/
  README.md
  axis_dyn_readout_v1.core             # VLNV qick:ip:axis_dyn_readout_v1:1.0.2
  hdl/axis_dyn_readout_v1.sv           # wraps readout_top_dynro (rtl_lib/dsp)
  rdl/axis_dyn_readout_v1_regmap.rdl   # empty: no registers
  driver/axis_dyn_readout_v1.py        # AxisDynReadoutV1 lives in qick_lib/qick/drivers/readout.py
  tests/
```

Datapath sources: `rtl_lib/dsp/readout_top_dynro.sv`, `down_conversion_dynro.sv`, `fir_decim8_dynro.sv`,
`rtl_lib/ctrl/ctrl_dyn_ro.sv`.

## Open items

- Frequency-accuracy and latency checks on hardware against the legacy IP.
- Driver: the block has no registers, so `AxisDynReadoutV1` is not a PYNQ driver but a class the averaging buffer's driver
  creates from the block-design trace. Its handling will follow the `qick_time_tagger` flow (firmware/docs/user/BOARD_WORKFLOW.md,
  firmware/docs/developer/DRIVER.md), adapted to a register-less block; not started.
