# AXIS register slice without backpressure (axis_register_slice_nb)

Delays an AXI4-Stream by `N` clocks through plain registers, with no handshake. It sits between the RFDC and the
QICK generators and readouts to break the long route to and from the converter tiles.

- VLNV: `qick:ip:axis_register_slice_nb:1.0.0` (module `axis_register_slice_nb`)
- Replaces: the legacy `QICK:QICK:axis_register_slice_nb:1.0` (openquantumhardware/qick `firmware/ip/axis_register_slice_nb`), with
  the same ports, parameters and behaviour
- Driver: none (no registers). QickSoc traces through it (`qick_lib/qick/ip.py`, `trace_back`/`trace_forward`).
- Used in: every standard Top project (111, 216, 4x2 `tpv1_std`/`tpv2_std` and variants)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 s_axis_tdata --> [reg] --> [reg] --> ... --> [reg] --> m_axis_tdata      (N registers, latency N clocks)
 s_axis_tready = 1                               m_axis_tvalid = 1
```

## U2. The rule that matters: there is no handshake

- `s_axis_tready` and `m_axis_tvalid` are **always 1**, also during reset.
- `s_axis_tvalid` and `m_axis_tready` are **ignored**. The registers shift on every clock, whatever the upstream
  and downstream say.

So it is only correct on a stream that never stalls and whose every clock carries a sample: RFDC ADC outputs
(always valid) into readouts (always ready), and generator outputs into the RFDC DAC inputs. Put it on a stream
with real backpressure (a DMA path, `sg_translator` to a generator's descriptor input) and data is lost or
duplicated without any error. Use Xilinx `axis_register_slice` there.

It exists instead of the Xilinx `axis_register_slice` on the converter paths because it has no skid buffer, no
output mux and no `TREADY` fan-out: only flip-flops, which the placer can spread between the RFDC tile and the
fabric. On a 4x2 debug bench the Xilinx slice between the ADC and the readout failed timing by 33 ps at
552.96 MHz and this one closed it (WNS +0.032 ns).

`aresetn` (synchronous, active low) clears every stage to 0, so the first `N` words after reset are 0.

## U3. Data formats

None: `m_axis_tdata` is `s_axis_tdata` delayed by `N` clocks, bit for bit.

## U4. Throughput and limits

One word per clock, latency `N` clocks. `N >= 1` (the legacy VHDL needed `N >= 2`).

## U5. Python quick start

Nothing to do: the IP has no registers. `QickSoc` follows it when tracing a generator or readout to its converter.

## U6. Using it in a block design

| Parameter | Default | Standard BDs |
|---|---|---|
| `B` (bits) | 16 | ADC side: 128 (8 samples x 16 bit). DAC side: 256 (16 samples x 16 bit) |
| `N` (stages) | 4 | ADC side: 2. DAC side: 4 |

- `aclk`: the clock of the stream it sits on (the RFDC `m*_axis_aclk` / `s*_axis_aclk` of that tile).
  `aresetn` from the reset synchronised to that clock.
- `B` is not propagated from the connected interfaces: set it to the stream width by hand.

## U7. Gotchas

| Symptom | Cause | What to do |
|---|---|---|
| Missing or repeated samples downstream | Used on a stream that stalls | Only use it on converter streams (U2) |
| Width mismatch warning in the BD | `B` left at 16 | Set `B` to the TDATA width |
| First `N` samples after reset are 0 | Reset clears the stages | Expected |

## U8. Validation status

| What | Where | Result |
|---|---|---|
| Legacy VHDL, same behaviour | every standard QICK firmware, many boards | In production for years |
| This SystemVerilog port | SVUnit (Part II) | 4/4, including the deployed `B=128, N=2` |
| This port in the standard BDs | `validate_bd_design`, Vivado 2025.2 | See the CHANGELOG entry |
| This port on hardware | -- | Not yet: the next bitstream built from these BDs will be the first |

---

# Part II -- Reference

## Ports

| Port | Dir | Width | Clock |
|---|---|---|---|
| `aclk` | in | 1 | -- |
| `aresetn` | in | 1 | `aclk` |
| `s_axis_tdata` | in | `B` | `aclk` |
| `s_axis_tvalid` | in | 1 | ignored |
| `s_axis_tready` | out | 1 | constant 1 |
| `m_axis_tdata` | out | `B` | `aclk` |
| `m_axis_tvalid` | out | 1 | constant 1 |
| `m_axis_tready` | in | 1 | ignored |

## Registers

None.

## Verification

`make sim IP=axis_register_slice_nb`: three instances side by side (`B=16,N=4` default, `B=128,N=2` as in the
standard BDs, `B=8,N=1` edge case), random data every clock, checked word by word against the input delayed by `N`:

- `tc_ready_valid_constant`: `tready`/`tvalid` are 1, also during reset
- `tc_latency_and_order`: 500 random words, exact delay `N`, in order
- `tc_ignores_tvalid_and_tready`: same with random `s_axis_tvalid` / `m_axis_tready`
- `tc_reset_clears_pipeline`: reset zeroes every stage, then data flows again

Checked to fail when the output is taken from the wrong stage.

## Files

```
cores/ip/axis_register_slice_nb/
  README.md
  axis_register_slice_nb.core
  hdl/axis_register_slice_nb.sv -> ../../../../../rtl_lib/ip/axis_register_slice_nb.sv
  tests/axis_register_slice_nb_tc00.sv, axis_register_slice_nb_tests.sv
```

## Open items

- First hardware run with the ported IP.
