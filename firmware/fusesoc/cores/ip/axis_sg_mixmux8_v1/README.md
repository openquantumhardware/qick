# AXIS Signal Generator, 8 tones with I/Q output, v1 (axis_sg_mixmux8_v1)

The complex version of `axis_sg_mux8_v1`: eight independent tones, each with its own frequency, phase and gain set through
registers, summed into one **complex (I/Q)** output stream that feeds a DAC with its digital mixer. The tProcessor chooses,
pulse by pulse, which of the eight tones are on (an 8-bit mask) and for how long. There is no envelope memory.

- Project: QICK, `qick:ip:axis_sg_mixmux8_v1:1.0.0` (module `axis_sg_mixmux8_v1`, `N_DDS = 2`)
- Driver: class `AxisSgMixMux8V1` (base `AbsMuxSignalGen`) in `qick_lib/qick/drivers/generator.py` (symlinked from
  `driver/axis_sg_mixmux8_v1.py`); register-layer test in `driver/tests/`
- Same registers, descriptor and wrapper as `axis_sg_mux8_v1` (the legacy sources of the two are identical apart from the
  datapath and the output width); read its README for the shared rules
- Hardware bring-up: none of this fusesoc version (see U8)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 Python/AXI: PINC0..7, POFF0..7, GAIN0..7, WE --------------------------------+
 tProc --s_axis (40-bit {mask[7:0], nsamp[31:0]})--> FIFO (16) --> control --> mask, enable
   8 x [ complex DDS (I and Q) x gain ] --mask--> adder tree (I and Q) --> shift by tone count --> m_axis (N_DDS x {imag,real})
```

## U2. Rules that are not obvious

- **Descriptor length** (`{mask[7:0], nsamp[31:0]}`, the controller of `axis_sg_mux8_v1`, `ctrl_sgmux8`):
  Between two descriptor reads a descriptor takes `nsamp` + 2 clocks (measured in the `ctrl_sgmux8` tests). **`nsamp` 0
  stalls the generator**: the count is already past 0 when the new `nsamp` is seen, so the next descriptor is read only
  after the 32-bit counter wraps (about 2^32 clocks). qick_lib sends at least 3; a raw descriptor must keep `nsamp` >= 1
  (kept in the RTL).

The rules of `axis_sg_mux8_v1` apply unchanged: static tone registers plus a descriptor per pulse; `WE_REG` is a level that
latches the registers while high (the driver's `update()` writes 1 then 0); the amplitude of a tone depends on how many
tones are enabled (a shift table taken from the number of mask bits); the phase is coherent across pulses; the latency is 4
clocks. What is different:

- **Complex output.** Every wave carries an independent I and Q, so the adder tree and the count-dependent scaling are
  duplicated for both components, and the output is `N_DDS * 32` bits wide.
- **Meant for a DAC digital mixer.** `HAS_MIXER = True` in the driver class: the software includes the RFDC mixer frequency
  when it computes the DDS words for a requested frequency.
- **Gain, frequency and phase:** `B_DDS = B_PHASE = 32`, gain signed Q1.15 in bits [15:0] of `GAINx_REG`, default
  `MAXV = 2**15 - 2`, unused tones get gain 0 in `set_tones_int`.

## U3. Data formats

- Registers as in `axis_sg_mux8_v1`.
- Output `m_axis_tdata`: `N_DDS * 32` bits, `N_DDS` lanes of `{imag[15:0], real[15:0]}`.

## U4. Memories, throughput and limits

No envelope memory; 8 tones maximum; descriptor FIFO of 16 entries.

## U5. Python quick start

```python
gen = soc.axis_sg_mixmux8_v1_0
gen.set_tones(freqs=[-5, 5], gains=[0.4, 0.4], phases=[0, 90])    # debug helper; frequencies may be negative
```

Positive and negative frequencies are allowed (the output is complex). Playing a pulse is done from a program.

## U6. Using it in a block design

- `s_axis` <- a tProc output port; `m_axis` -> the RFDC DAC stream of a tile with the digital mixer enabled; `aclk` = that
  tile's stream clock; `s_axi` -> the PS interconnect (a separate clock domain).
- Parameter `N_DDS` (default 2).
- **Driver binding today:** `AxisSgMixMux8V1.bindto` (monolithic `generator.py`) lists `user.org:user:` and `QICK:QICK:`
  only, so a `qick:ip:axis_sg_mixmux8_v1:1.0` block is not bound until the VLNV is added. The drivers of the IPs will follow
  the `qick_time_tagger` flow (firmware/docs/user/BOARD_WORKFLOW.md, firmware/docs/developer/DRIVER.md).

## U7. Gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Writing tones without `update()` | Nothing changes | `update()` |
| Leaving `WE = 1` | The datapath follows every register write | End with `WE = 0` |
| Switching tones on and off | The amplitude of the others shifts | Calibrate for the mask in use |
| Real-output DAC path | This IP outputs I/Q | Use `axis_sg_mux8_v1` |

## U8. Validation status

- **Simulation**: 6 SVUnit tests: reset state, AXI register round trip, a descriptor produces valid output, all tones masked
  off gives zero I/Q, `m_axis_tvalid` drops after playback, and a DC carrier gives a non-zero real lane. Frequency,
  amplitude and the tone-count scaling are **not** checked numerically.
- **Hardware**: this fusesoc version has not been built into a bitstream or run on a board.
- Not verified: tone accuracy, I/Q balance, amplitude versus the number of tones, image rejection.

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `s_axi_*` | | AXI4-Lite slave |
| `aclk`, `aresetn` | in | datapath clock and reset |
| `s_axis_tdata[39:0]`, `tvalid`, `tready` | | pulse descriptors |
| `m_axis_tdata[N_DDS*32-1:0]`, `tvalid`, `tready` | | I/Q output |

## Registers

The driver takes the word index of each register from this map: `AxisSgMixMux8V1` reads `axis_sg_mixmux8_v1_regmap_pkg` (generated from `rdl/axis_sg_mixmux8_v1_regmap.rdl`, installed in `qick_lib/qick/rdl_pkgs/` by `make driver IP=axis_sg_mixmux8_v1`; `make driver-check` fails if the committed copy no longer matches the RDL) and keeps the attribute names the software uses (`pinc0_reg` ... `pinc7_reg`, `poff0_reg` ... , `gain0_reg` ... , `we_reg`; `pincN_reg` is `regs.pinc_regfile[N]`); `regs` is the register model for field access. The indexes are the ones the driver has always used and the legacy `axi_slv.v` wires, identical to `axis_sg_mux8_v1` (PINC 0 to 7, POFF 8 to 15, GAIN 16 to 23, WE 24); a test pins the old dictionary.

Identical to `axis_sg_mux8_v1`: `PINC0..7_REG` (0x00-0x1C), `POFF0..7_REG` (0x20-0x3C), `GAIN0..7_REG` (0x40-0x5C),
`WE_REG` (0x60). Source: `rdl/axis_sg_mixmux8_v1_regmap.rdl`.

## Verification

`tests/axis_sg_mixmux8_v1_tests.sv` (6 tests, U8). `make sim IP=axis_sg_mixmux8_v1`.

## Files

```
cores/ip/axis_sg_mixmux8_v1/
  README.md
  axis_sg_mixmux8_v1.core            # VLNV qick:ip:axis_sg_mixmux8_v1:1.0.0
  hdl/axis_sg_mixmux8_v1.sv          # AXI-Lite wrapper + sg_mixmux8 (rtl_lib/dsp)
  rdl/axis_sg_mixmux8_v1_regmap.rdl
  driver/axis_sg_mixmux8_v1.py -> qick_lib/qick/drivers/generator.py ; driver/tests/
  tests/
```

Datapath: `rtl_lib/dsp/sg_mixmux8.sv`, `dds_top_mixmux8.sv`; control shared with mux8 (`ctrl_sgmux8.sv`).

## Open items

- Driver: move to the `qick_time_tagger` flow (per-IP driver, `qick:ip:` VLNV in `bindto`, board validation).
- A numeric check of the tone-count scaling against the legacy IP is missing.
