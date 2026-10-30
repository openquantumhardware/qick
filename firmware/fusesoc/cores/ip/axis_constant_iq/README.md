# AXIS Constant IQ (axis_constant_iq)

Streams a constant I/Q value to an RF-DAC. With the DAC's mixer (its NCO) set to a frequency, the DAC outputs a
continuous-wave tone at that frequency whose amplitude and phase come from the I/Q value. There is no waveform
memory and no tProcessor involved: write two numbers, get a tone.

- Project: QICK, `qick:ip:axis_constant_iq:1.0.0`
- Driver: `AxisConstantIQ` in `qick_lib/qick/drivers/generator.py`, the constant-IQ channel class of `QickSoc`
  (listed in `soc.iqs`). The same class serves the legacy IP (`user.org:user` / `QICK:QICK:axis_constant_iq:1.0`).
  `cores/ip/axis_constant_iq/driver/axis_constant_iq.py` is an alias of that module (see
  `firmware/docs/user/IP_INTEGRATION.md`).
- Hardware bring-up: RFSoC4x2, a debug bench; validated (see U8). The board runs until
  2026-09-25 used a separate standalone class, `AxisConstantIq`. It bound the same VLNV and took the IP out of
  `soc.iqs`, so it was merged into `AxisConstantIQ` (`get_iq()`, clipping in `set_iq()`).

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference (ports,
registers, verification, files).

---

# Part I -- Using the IP

## U1. What it does

```
 AXI4-Lite ----> REAL_REG (I) --+
                 IMAG_REG (Q) --+--[latch on rising edge of WE]--> m_axis  (128 bit, constant)
                 WE_REG --------+                                     |
                                                                      v
                                        RFDC DAC block --> mixer (NCO at f) --> analog tone at f
```

## U2. How it works, and the rules that are not obvious

### Setting the amplitude: use `set_iq`

`set_iq(i, q)` (U5) writes `REAL_REG` and `IMAG_REG` (signed 16 bit, scaled by `MAXV = 2**15 - 2`) and then calls
`update()`.

**`WE` is edge-sensitive and does not clear itself.** The I/Q values reach the output only on a *rising edge* of
`WE_REG.WE` (after it is synchronised to the stream clock). Writing `1` when it is already `1` does nothing, so
software has to write `1` and then `0` for every update; `update()` does exactly that. Writing the registers by
hand and leaving `WE = 1` updates the output only the first time (during the first bring-up this made a gain sweep
look constant). (An earlier version of the RDL called `WE` a "self-clearing pulse"; that was wrong and is fixed.)

The tone amplitude is linear in `set_iq`: on the RFSoC4x2 loopback (DAC to ADC, 100 MHz) the amplitude at the ADC was
0.006, 0.250, 0.500 and 1.000 of the full-gain value for gains 0, 0.25, 0.5 and 1.

### Setting the frequency: the DAC mixer, at run time

The frequency is not a property of this IP. It is the NCO of the RFDC DAC block, and QICK sets it at run time:

```python
soc.rf.set_mixer_freq('00', 100.0, blocktype='dac')     # DAC channel '00' (tile 0, block 0), MHz
soc.rf._get_block('dac', '00').MixerSettings['Freq']    # the NCO rounds to its step: read back the real value
```

This works **only if the DAC mixer is FINE** (`MixerType = 2` in `MixerSettings`). In the block design that is
`CONFIG.DAC_Mixer_Type00 {2}` (Vivado's values follow `xrfdc`: 1 COARSE, 2 FINE, 3 OFF). With a COARSE mixer
(`DAC_Mixer_Type00 {1}`, the value the standard 4x2 projects use because their generators make the tone digitally)
`set_mixer_freq` raises `RuntimeError: ... mixer is not enabled` and the tone is fixed at a fraction of the DAC sample
rate (`CoarseMixFreq = 4` is fs/4, 614.4 MHz at 2457.6 MS/s). A bitstream can be checked from Python before
trusting it:

```python
print(soc.rf._get_block('dac', '00').MixerSettings)     # MixerType 2 = FINE
```

The configuration that was validated: DAC tile at 2457.6 MS/s, interpolation 2, 8 words per fabric clock
(fabric clock 307.2 MHz), `DAC_Mixer_Type {2}`, `DAC_Mode {0}`; the readback shows `MixerMode = 2` (complex to real).

## U3. Data formats

The output stream is 4 identical lanes of `{Q[15:0], I[15:0]}` (128 bit, `NUM_CHANNELS = 4`), the format the RFDC
DAC expects at 8 real samples per clock. `m_axis_tvalid` is low after reset and goes high, for good, after the first
update; `m_axis_tready` is ignored and `tlast` is 0.

## U4. Memories, throughput and limits

There is no memory and no tProcessor. The stream carries one constant 128-bit word per stream clock once the first update has been made, so the throughput is the DAC's own sample rate and there is nothing to configure. `m_axis_tready` is ignored: the IP never stalls.

## U5. Python quick start

```python
sg = soc.axis_constant_iq_0                  # instance name depends on the block design
sg.set_iq(1.0, 1.0)                          # I and Q as a fraction of full scale, -1 to 1
sg.get_iq()                                  # -> (1.0, 1.0)
```

The mixer frequency (U2) is set from `soc.rf`:

```python
soc.rf.set_mixer_freq('00', 100.0, blocktype='dac')     # DAC channel '00' (tile 0, block 0), MHz
soc.rf._get_block('dac', '00').MixerSettings['Freq']    # the NCO rounds to its step: read back the real value
```

```python
print(soc.rf._get_block('dac', '00').MixerSettings)     # MixerType 2 = FINE
```

## U6. Using it in a block design

- **`m_axis`** (128 bit) goes to the RFDC DAC block's `s<tile>0_axis` interface; **`m_axis_aclk` /
  `m_axis_aresetn` must be that DAC tile's AXI-stream clock** (`clk_dac0` at 307.2 MHz on the RFSoC4x2, where the
  DAC tile has `out_div = 1`). Use the same clock and reset as the RFDC's `s0_axis_aclk`.
- **`s_axi`** (AXI4-Lite) on the PS clock; the clocks are independent, `WE` is synchronised internally.
- Parameters: `IQ_WIDTH` 16 and `NUM_CHANNELS` 4 (they fix the 128-bit stream; do not change them for a 16-bit,
  8-sample RFDC interface).
- Give each DAC its own instance; several instances can share the AXI interconnect.
- Add the two clock domains to the design's `timing.xdc` as asynchronous groups (`clk_axi` vs `clk_dacN`).
- Warning printed by `QickSoc` on the RFSoC4x2/2x4 about `DAC_AVTT` and VOP mode: expected, the board hard-wires 2.5 V.

## U7. Gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Register writes without a `WE` pulse | Output stuck at the first value | Use `set_iq()` / `update()` |
| Loading the firmware with `QickSoc` | The driver's `_init_firmware()` sets I = Q = full scale and latches it, so the DAC outputs a full-scale tone at its NCO frequency right away | Call `set_iq(0, 0)` first if the output must stay quiet |
| COARSE DAC mixer | `set_mixer_freq` raises; tone fixed at fs/4 | Build with `DAC_Mixer_Type {2}` |
| Hog project not recreated after a block-design change | The bitstream keeps the old mixer type | `./Hog/Do CREATE <board>/<project>` again, then build |
| Capturing the tone with the time tagger's sample store | Only the first ~8 windows are continuous; peaks do not follow the tone | Arm about 1 ms and analyse the first windows (`qick_time_tagger` README, U4) |
| `set_iq(1, 1)` | I and Q both at full scale; the complex magnitude is larger than either | No clipping was seen at the ADC in the loopback test; reduce the gain if the DAC output saturates |
| Stream clock is not the DAC tile's fabric clock | RFDC and IP out of rate | U6 |


## U8. Validation status

Validated on an RFSoC4x2 with a debug bench (DAC0 looped into ADC0 through a T with an oscilloscope, the
`qick_time_tagger`'s sample store used to capture):

| check | result |
|---|---|
| tone at NCO = 100 MHz | peak 100.1 MHz, SNR 65 dB, strongest spur -41.8 dBc |
| gain 0 / 0.25 / 0.5 / 1 | 0.006 / 0.250 / 0.500 / 1.000 of full scale |
| NCO sweep 20 / 50 / 100 / 200 / 400 MHz | peaks at 0.0082 / 0.0204 / 0.0407 / 0.0813 / 0.1627 cycles per sample (expected 0.0081 / 0.0203 / 0.0407 / 0.0814 / 0.1628), spurs -41 to -55 dBc |
| oscilloscope on the DAC output | tone at the programmed frequency (10 MHz and 100 MHz seen) |

The time tagger's debug bench uses two instances (DAC0 at 10 MHz, DAC2 at 40 MHz) as loopback tone sources.
Simulation: SVUnit for the RTL; driver pytest: 4 register-layer tests plus 6 behaviour tests of `AxisConstantIQ` (WE edge, clipping, readback, register offsets against the RDL).

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `s_axi_*` | | AXI4-Lite slave (`axil_slv`, 32-bit, registers below), `s_axi_aclk` / `s_axi_aresetn` |
| `m_axis_aclk`, `m_axis_aresetn` | in | stream clock and reset |
| `m_axis_tdata[127:0]` | out | 4 x `{Q[15:0], I[15:0]}` |
| `m_axis_tvalid` | out | low until the first update, then high |
| `m_axis_tlast` | out | always 0 |
| `m_axis_tready` | in | ignored |

## Registers

The driver takes the word index of each register from this map: `AxisConstantIQ` reads `axis_constant_iq_regmap_pkg` (generated from `rdl/axis_constant_iq_regmap.rdl`, installed in `qick_lib/qick/rdl_pkgs/` by `make driver IP=axis_constant_iq`; `make driver-check` fails if the committed copy no longer matches the RDL) and keeps the attribute names the software uses (`real_reg`, `imag_reg`, `we_reg`); `regs` is the register model for field access. The indexes are the ones the driver has always used and the legacy `axi_slv.vhd` wires (`REAL_REG` = word 0, `IMAG_REG` = word 1, `WE_REG` = word 2); a test pins the old dictionary.

| Addr | Register | Field | Access | Description |
|---|---|---|---|---|
| 0x00 | `REAL_REG` | `I[15:0]` | RW | signed I component |
| 0x04 | `IMAG_REG` | `Q[15:0]` | RW | signed Q component |
| 0x08 | `WE_REG` | `WE[0]` | RW | rising edge latches I/Q into the output; not self-clearing |

The register map is `rdl/axis_constant_iq_regmap.rdl` (used for the driver and documentation; the RTL uses the
shared `axil_slv`, not a generated register block).

## Verification

- RTL: SVUnit testbench in `tests/` (`axis_constant_iq_tc00.sv`, `axis_constant_iq_tests.sv`), `make sim IP=axis_constant_iq`.
- Driver: 4 register-layer tests (`driver/tests/test_axis_constant_iq_regs.py`) and 6 behaviour tests of `AxisConstantIQ` with `pynq` stubbed (`test_axis_constant_iq_driver.py`): the `WE` edge, clipping, readback, register offsets against the RDL. `make driver-test IP=axis_constant_iq`.
- Hardware: the table in U8.

## Files

```
cores/ip/axis_constant_iq/
  README.md                                  # this file
  axis_constant_iq.core                      # VLNV qick:ip:axis_constant_iq:1.0.0
  hdl/axis_constant_iq.sv -> ../../../../rtl_lib/ip/axis_constant_iq.sv
  rdl/axis_constant_iq_regmap.rdl            # register map (docs + driver)
  driver/axis_constant_iq.py                 # alias of qick_lib/qick/drivers/generator.py (AxisConstantIQ)
  driver/tests/test_axis_constant_iq_regs.py # register-layer pytest
  driver/tests/test_axis_constant_iq_driver.py # behaviour pytest of AxisConstantIQ (pynq stubbed)
  tests/                                     # SVUnit testbench
  constraints/axis_constant_iq.xdc, axis_constant_iq_ooc.xdc
```

## Open items

- Not verified: any board other than the RFSoC4x2 (the hardware validation in U8 is DAC0 and ADC0 of that board only).
