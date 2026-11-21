# AXIS Signal Generator, 8 tones, v1 (axis_sg_mux8_v1)

A multi-tone generator: eight independent sine waves, each with its own frequency, phase and gain set through registers,
summed into one real output stream. The tProcessor chooses, pulse by pulse, **which of the eight tones are on** (an 8-bit
mask) and for how long. There is no envelope memory: a pulse is a burst of the selected tones at constant amplitude.

- Project: QICK, `qick:ip:axis_sg_mux8_v1:1.0.0` (module `axis_sg_mux8_v1`, `N_DDS = 2`)
- Driver: class `AxisSgMux8V1` (base `AbsMuxSignalGen`) in `qick_lib/qick/drivers/generator.py` (symlinked from
  `driver/axis_sg_mux8_v1.py`); register-layer test in `driver/tests/`
- Sibling: `axis_sg_mixmux8_v1` has the same registers and descriptor but produces complex (I/Q) output for a DAC mixer
- Hardware bring-up: none of this fusesoc version (see U8)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 Python/AXI: PINC0..7, POFF0..7, GAIN0..7, WE ------------------------------------+
                                                                                  v
 tProc --s_axis (40-bit {mask[7:0], nsamp[31:0]})--> FIFO (16 deep) --> control --> mask, enable
                                                                                  |
   8 x [ DDS (frequency, phase) x gain ] --mask--> adder tree (8 -> 1) --> shift by tone count --> m_axis (N_DDS x 16-bit)
```

Each of the eight waves has its own DDS lanes (`N_DDS` interleaved lanes per wave); a wave is forced to zero unless its
mask bit is set. The enabled waves are added by a three-stage tree and the sum is scaled back to 16 bits.

## U2. Rules that are not obvious

- **Two ways to configure it.** The *tones* (frequency, phase, gain) are static AXI registers; the *pulse* (which tones, how
  long) is a descriptor from the tProc. Changing a register does not play anything; a descriptor without configured tones
  plays silence.
- **`WE_REG` is a level, and the registers are latched continuously while it is high.** The datapath follows
  `PINC/POFF/GAIN` for as long as `WE = 1`; the driver's `update()` writes `WE = 1` and then `WE = 0`, which latches the
  current values once. Writing the tone registers and leaving `WE = 0` changes nothing.
- **Amplitude depends on how many tones are enabled.** The sum of the enabled waves is shifted right by an amount taken from
  the number of mask bits set, from a table ported as is from the legacy IP; for 5 to 8 tones the shift is 3 bits. So the
  amplitude of one tone changes when other tones are switched on. Set the gains for the mask you will use, and check the
  result on a scope or spectrum analyser.
- **Gain** is a signed Q1.15 value in the lower 16 bits of `GAINx_REG`; the driver's default is `MAXV` (`2**15 - 2`) and
  `set_tones_int` sets the gain of unused tones to 0.
- **Descriptor** (40 bits): `{mask[7:0], nsamp[31:0]}`; `nsamp` is the number of output clocks the mask is applied.
  Between two descriptor reads a descriptor takes `nsamp` + 2 clocks (measured in the `ctrl_sgmux8` tests). **`nsamp` 0
  stalls the generator**: the count is already past 0 when the new `nsamp` is seen, so the next descriptor is read only
  after the 32-bit counter wraps (about 2^32 clocks). qick_lib sends at least 3; a raw descriptor must keep `nsamp` >= 1
  (kept in the RTL).
- **Phase is coherent** across pulses (a free-running counter feeds the DDS lanes), so tones keep their relative phase.
- **Latency:** 4 clocks from the descriptor pop to the output.

## U3. Data formats

- `PINCx_REG`: 32-bit phase increment (`B_DDS = 32`); `POFFx_REG`: 32-bit phase offset (`B_PHASE = 32`); `GAINx_REG`:
  signed Q1.15 in bits [15:0].
- Output `m_axis_tdata`: `N_DDS * 16` bits, signed 16-bit real samples, `N_DDS` per clock.

## U4. Memories, throughput and limits

- No envelope memory. 8 tones maximum (`N_TONES = 8`).
- Descriptor FIFO: 16 entries.

## U5. Python quick start

```python
gen = soc.axis_sg_mux8_v1_0
gen.set_tones(freqs=[10, 20, 30], gains=[0.3, 0.3, 0.3], phases=[0, 0, 0])   # debug helper: MHz, gain -1..1, degrees
```

`set_tones_int(tones)` takes the integer values (`freq_int`, `gain_int`, `phase_int`) produced by `QickProgram.declare_gen`,
zeroes the gain of any unused tone and calls `update()`. Playing a pulse is done from a program.

## U6. Using it in a block design

- `s_axis` <- a tProc output port; `m_axis` -> the RFDC DAC stream; `aclk` = that DAC tile's stream clock.
- `s_axi` -> the PS interconnect (`s_axi_aclk`), a separate clock domain.
- Parameter `N_DDS` (interleaved lanes per wave, default 2).
- **Driver binding today:** `AxisSgMux8V1.bindto` (monolithic `generator.py`) lists `user.org:user:` and `QICK:QICK:` only, so a
  `qick:ip:axis_sg_mux8_v1:1.0` block is not bound until the VLNV is added. The drivers of the IPs will follow the
  `qick_time_tagger` flow (firmware/docs/user/BOARD_WORKFLOW.md, firmware/docs/developer/DRIVER.md).

## U7. Gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Writing tones without `update()` | Nothing changes | `update()` (WE 1 then 0) |
| Leaving `WE = 1` | The datapath follows every register write | End with `WE = 0` |
| Switching tones on and off | The amplitude of the others shifts | Calibrate for the mask in use |
| More than 8 tones | `RuntimeError: Too many tones defined for this mux generator.` | Use at most 8, or a second generator |
| Expecting an envelope | None | Use `axis_signal_gen_v6` / `axis_sg_int4_v2` |

## U8. Validation status

- **Simulation**: 6 SVUnit tests: reset state, AXI register round trip, `WE_REG` is a plain level (not self-clearing), a
  descriptor produces valid output, all tones masked off gives zero output, `m_axis_tvalid` drops after playback. The
  frequency, gain and the tone-count scaling are **not** checked numerically.
- **Hardware**: this fusesoc version has not been built into a bitstream or run on a board.
- Not verified: tone frequency and amplitude accuracy, the amplitude versus the number of tones, spurs.

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `s_axi_*` | | AXI4-Lite slave |
| `aclk`, `aresetn` | in | datapath clock and reset |
| `s_axis_tdata[39:0]`, `tvalid`, `tready` | | pulse descriptors |
| `m_axis_tdata[N_DDS*16-1:0]`, `tvalid`, `tready` | | output |

## Registers

The driver class `AxisSgMux8V1` keeps a hand-written dictionary of this map, with the attribute names the software uses (`pinc0_reg` ... `pinc7_reg`, `poff0_reg` ... , `gain0_reg` ... , `we_reg`; `pincN_reg` is `regs.pinc_regfile[N]`). The indexes are the ones the driver has always used and the legacy `axi_slv.v` wires (PINC 0 to 7, POFF 8 to 15, GAIN 16 to 23, WE 24). The legacy-only muxes of the same base class (`axis_sg_mux4_v2`, `v3`) have no RDL and still compute their map from `N_TONES` and `HAS_*`. RFSoC4x2 2026-10-27, board clone at `a31f5f92`: the register-level check of the driver passes (map equal to the old one, `regs` and the attributes reaching the same word through `poff_regfile[7]`); `axis_sg_mux8_v1_hw_validation.ipynb` with this change: not reported yet; bitstream file and md5 not recorded.

| Addr | Register | Access | Description |
|---|---|---|---|
| 0x00-0x1C | `PINC0_REG` .. `PINC7_REG` | RW | phase increment, tones 0-7 |
| 0x20-0x3C | `POFF0_REG` .. `POFF7_REG` | RW | phase offset, tones 0-7 |
| 0x40-0x5C | `GAIN0_REG` .. `GAIN7_REG` | RW | signed Q1.15 gain in bits [15:0] |
| 0x60 | `WE_REG` (`WE[0]`) | RW | write enable (a level; registers latched while high) |

Source: `rdl/axis_sg_mux8_v1_regmap.rdl`. The driver's register order is `pinc0..7`, `poff0..7`, `gain0..7`, `we`.

## Verification

`tests/axis_sg_mux8_v1_tests.sv` (6 tests, U8). `make sim IP=axis_sg_mux8_v1`.

## Files

```
cores/ip/axis_sg_mux8_v1/
  README.md
  axis_sg_mux8_v1.core               # VLNV qick:ip:axis_sg_mux8_v1:1.0.0
  hdl/axis_sg_mux8_v1.sv             # AXI-Lite wrapper + sg_mux8 (rtl_lib/dsp)
  rdl/axis_sg_mux8_v1_regmap.rdl
  driver/axis_sg_mux8_v1.py -> qick_lib/qick/drivers/generator.py ; driver/tests/
  tests/
```

Datapath: `rtl_lib/dsp/sg_mux8.sv`, `dds_top_sgmux8.sv`, `rtl_lib/ctrl/ctrl_sgmux8.sv`, `phase_ctrl_sgmux8.sv`.

## Open items

- Driver: move to the `qick_time_tagger` flow (per-IP driver, `qick:ip:` VLNV in `bindto`, board validation).
- The tone-count scaling table is ported as is; a numeric check of the amplitude against the legacy IP is missing.
