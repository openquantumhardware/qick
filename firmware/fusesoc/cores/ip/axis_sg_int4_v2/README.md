# AXIS Signal Generator, interpolated x4, v2 (axis_sg_int4_v2)

An arbitrary-waveform generator whose envelope memory is **one sample per address** and whose output is **interpolated by
4** with a low-pass FIR: the envelope is stored at a quarter of the DAC rate and the filter reconstructs four samples per
clock. Multiplied by a 32-bit DDS carrier and a gain, it drives a DAC that has its own digital mixer. Pulses are described
by 160-bit descriptors sent by the tProcessor; the envelope is loaded through a DMA stream.

- Project: QICK, `qick:ip:axis_sg_int4_v2:1.0.0` (module `axis_sg_int4_v2`, `N = 16`, `N_DDS = 4`)
- Driver: class `AxisSgInt4V2` (base `AbsIntSignalGen`) in `qick_lib/qick/drivers/generator.py` (symlinked from
  `driver/axis_sg_int4_v2.py`); register-layer test in `driver/tests/`
- Hardware bring-up: none of this fusesoc version (see U8)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 Python/DMA --s0_axis (envelope, 32-bit {Q,I})--> BRAM (2^N words, one sample per address) <-- START_ADDR_REG, WE_REG
 tProc      --s1_axis (160-bit descriptor)--> FIFO (16 deep) --> control (address, gain, source, phase)
                                                                    |
   envelope --> FIR x4 interpolation (21 taps) --> x DDS (4 lanes) x gain --> m_axis (4 x {imag,real} 16-bit per clock)
```

Three clock domains: AXI4-Lite (`s_axi_aclk`), envelope stream (`s0_axis_aclk`), everything else (`aclk`).

## U2. Rules that are not obvious

- **Descriptor:** the same 160-bit layout as `axis_signal_gen_v4` (this IP reuses its control block): `freq[31:0]`,
  `phase[63:32]`, `addr[79:64]`, `gain[111:96]`, `nsamp[143:128]`, `outsel[145:144]`, `mode[146]`, `stdysel[147]`,
  `phrst[148]`. The output source is: 0 DDS x envelope, 1 DDS only, 2 envelope only, 3 zero.
- **The envelope is interpolated, so it is short.** The memory holds `2**N` samples (65536 for N = 16); each stored sample
  becomes four output samples, so an envelope covers four times as many DAC samples as it has words. `nsamp` counts fabric
  clocks. `nsamp` 0, 1 and 2 all last 2 clocks (`ctrl_sgv4` ends its count at `<= 2`, measured in its tests): no stall,
  unlike `axis_signal_gen_v6`.
- **Overshoot: the driver scales envelopes to 0.9 of full scale.** The interpolation filter can exceed the maximum of its
  input (a square pulse overshoots its rising edge by about 10 %), and this IP has **no saturation logic**, so the output
  would wrap to a big negative spike. The driver class sets `MAXV_SCALE = 0.9` so the default maximum amplitude is 0.9 of
  int16. Do not load envelopes at full scale by hand.
- **No scaling or saturation fix.** Unlike `axis_signal_gen_v4` / `v6`, the product keeps the legacy quantisation
  (`[31:16]`) and the output is not clamped: this port preserves the deployed behaviour. Applying the family-wide fix is a
  candidate follow-up, not done.
- **Only two registers.** `START_ADDR_REG` and `WE_REG`; there is no status, no rounding select. `WE_REG` is a level:
  `load()` writes the start address, sets `WE = 1`, streams the envelope, sets `WE = 0`.
- **The FIR is a Xilinx FIR Compiler core** in the real design (`fir_0.xci`, 21 taps, interpolate by 4); for simulation and
  lint the repository uses a behavioural model that is not bit-exact to the core.
- **The DAC mixer is part of the frequency.** `HAS_MIXER = True` in the driver: this generator is used with the RFDC's
  digital mixer (`set_mixer_freq`), and the software takes the mixer frequency into account when it computes the DDS word for a
  requested output frequency.

## U3. Data formats

- Envelope words: `{Q[31:16], I[15:0]}`, int16 each (the driver packs an (n, 2) int16 array).
- Output `m_axis_tdata`: `N_DDS * 32` = 128 bits: four lanes, each `{imag[15:0], real[15:0]}`.
- `B_DDS = B_PHASE = 32` in this v2 (the v1 had 16 bits). Frequency `f = freq * fs / 2^32`; use `QickConfig.freq2reg`.
- `FS_INTERPOLATION = 4` in the driver class.

## U4. Memories, throughput and limits

- Envelope memory: `2**N` words (`maxlen = 2**N`, one word per address).
- Descriptor FIFO: 16 entries.
- Output: four complex samples per `aclk` cycle.

## U5. Python quick start

```python
gen = soc.axis_sg_int4_v2_0                   # instance name depends on the block design
gen.load(np.stack([i_samples, q_samples], axis=1).astype(np.int16), addr=0)
# playback is done by the tProc program (QickProgram.pulse), which sends the descriptors
```

## U6. Using it in a block design

- `s0_axis` <- an AXI DMA (through a stream switch if shared), `s1_axis` <- a tProc output port, `m_axis` -> the RFDC DAC
  stream (a DAC tile with its mixer enabled), `aclk` = that tile's stream clock.
- `s_axi` -> the PS interconnect. Parameters `N` (envelope address width) and `N_DDS` (4, fixed by the FIR).
- Constraints: `constraints/axis_sg_int4_v2.xdc` (+ `_ooc.xdc`); treat the three clocks as asynchronous.
- **Driver binding today:** `AxisSgInt4V2.bindto` (monolithic `generator.py`) lists `user.org:user:` and `QICK:QICK:`
  only, so a `qick:ip:axis_sg_int4_v2:1.0` block is not bound until the VLNV is added. The drivers of the IPs will follow
  the `qick_time_tagger` flow (firmware/docs/user/BOARD_WORKFLOW.md, firmware/docs/developer/DRIVER.md).

## U7. Gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Envelope at full scale | Interpolation overshoot wraps into a large spike | Keep the 0.9 factor |
| Assuming a saturating output | It does not saturate | Leave headroom |
| Envelope length in DAC samples | It is 4x the word count | Plan `nsamp` in clocks |
| Looking for `STATUS_REG` / `RNDQ_REG` | Not in this IP | Only `START_ADDR_REG`, `WE_REG` |
| Mixer frequency changed behind the software's back | Output frequency differs from the requested one | Set it through `set_mixer_freq` |

## U8. Validation status

- **Simulation**: 5 SVUnit tests: reset state, AXI register round trip, a DDS-only descriptor giving valid output, an
  envelope loaded and played back giving non-zero output, and `m_axis_tvalid` dropping after playback. They show the path is
  alive; they do **not** check the interpolation response or the spectrum (the FIR is a behavioural model).
- **Hardware**: this fusesoc version has not been built into a bitstream or run on a board.
- Not verified: the interpolation filter response, overshoot behaviour, the amplitude accuracy.

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `s_axi_*` | | AXI4-Lite slave, 6-bit address |
| `s0_axis_*` | | envelope stream (its own clock) |
| `aclk`, `aresetn` | in | datapath clock and reset |
| `s1_axis_tdata[159:0]`, `tvalid`, `tready` | | descriptors |
| `m_axis_tdata[N_DDS*32-1:0]`, `tvalid`, `tready` | | interpolated complex output |

## Registers

The driver class `AxisSgInt4V2` keeps a hand-written dictionary of this map, with the attribute names the software uses (`start_addr_reg`, `we_reg`). The indexes are the ones the driver has always used and the legacy `axi_slv.vhd` wires (`START_ADDR_REG` = word 0, `WE_REG` = word 1). `AxisSgInt4V1` shares the base class but exists only as legacy firmware: it has no RDL, no `regs`, and keeps the same two registers.

| Addr | Register | Field | Access | Description |
|---|---|---|---|---|
| 0x00 | `START_ADDR_REG` | `START_ADDR[31:0]` | RW | envelope write start address |
| 0x04 | `WE_REG` | `WE[0]` | RW | envelope write enable (a level) |

Source: `rdl/axis_sg_int4_v2_regmap.rdl`.

## Verification

`tests/axis_sg_int4_v2_tests.sv`: `tc_reset_idle`, `tc_axi_register_round_trip`,
`tc_dds_only_descriptor_produces_valid_output`, `tc_envelope_load_and_playback_produces_nonzero_output`,
`tc_mvalid_deasserts_after_playback`. `make sim IP=axis_sg_int4_v2`.

## Files

```
cores/ip/axis_sg_int4_v2/
  README.md
  axis_sg_int4_v2.core               # VLNV qick:ip:axis_sg_int4_v2:1.0.0
  hdl/axis_sg_int4_v2.sv             # AXI-Lite wrapper + sg_int4_top (rtl_lib/dsp)
  rdl/axis_sg_int4_v2_regmap.rdl
  constraints/axis_sg_int4_v2.xdc, axis_sg_int4_v2_ooc.xdc
  driver/axis_sg_int4_v2.py -> qick_lib/qick/drivers/generator.py ; driver/tests/
  tests/
```

Datapath: `rtl_lib/dsp/sg_int4.sv`, `sg_int4_top.sv`, `fir_interp4_sgint.sv` (sim model), `rtl_lib/ctrl/ctrl_sgv4.sv`.

## Open items

- Driver: move to the `qick_time_tagger` flow (per-IP driver, `qick:ip:` VLNV in `bindto`, board validation).
- Apply (or consciously decline) the scaling and saturation fixes that `axis_signal_gen_v4` / `v6` received.
