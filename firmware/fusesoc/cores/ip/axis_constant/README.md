# AXIS tie-off master (axis_constant)

An AXI4-Stream master that never sends anything: every output is 0, so `m_axis_tvalid` stays 0. It closes an unused AXI4-Stream slave input in a block design.

- VLNV: `qick:ip:axis_constant:1.0.0` (module `axis_constant`)
- Replaces: the legacy `QICK:QICK:axis_constant:1.0` (openquantumhardware/qick `firmware/ip/axis_constant`), with the same ports, parameters and
  behaviour
- Driver: none (no registers)
- Used in: 111 `tpv1_rfbv1_std`, `tpv1_rfbv2_std`; 216 `tpv1_simple_bd`, `tpv2_1ch_xcom_mts` (2023.1 BD)

Replaces also the unused library core `qick:axi:axis_constant` (an earlier port with an SV-interface port, which could not be packaged as an IP), removed in the same change.

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 m_axis_tdata = 0, m_axis_tstrb = 0, m_axis_tlast = 0, m_axis_tvalid = 0   (m_axis_tready ignored)
```

## U2. The rules that are not obvious

- Nothing is ever transferred. Use it only where the consumer tolerates an input that never becomes valid.
- The clock and reset ports exist only so the block design can associate `m_axis` with a clock; they are unused.

## U3. Data formats

See U1.

## U4. Throughput and limits

One word per clock; no registers or memories to configure.

## U5. Python quick start

Nothing to do: the IP has no registers.

## U6. Using it in a block design

`DATA_WIDTH` (default 16, multiple of 8): set it to the width of the input it closes (64 and 160 in the 111 BDs). `m_axis_aclk`: the clock of that input.

## U7. Gotchas

| Symptom | Cause | What to do |
|---|---|---|
| Width mismatch warning in the BD | `DATA_WIDTH` left at 16 | Set it to the consumer's TDATA width |

## U8. Validation status

| What | Where | Result |
|---|---|---|
| Legacy RTL, same behaviour | 111 tProc v1 QICK firmwares | In production |
| This SystemVerilog port | SVUnit (Part II) | 1/1 |
| This port in the Top BDs | `validate_bd_design`, Vivado 2025.2 | 4 BDs, see the CHANGELOG |
| This port on hardware | -- | Not yet |

---

# Part II -- Reference

## Ports

| Port | Dir | Width | Notes |
|---|---|---|---|
| `m_axis_aclk`, `m_axis_aresetn` | in | 1 | unused |
| `m_axis_tready` | in | 1 | ignored |
| `m_axis_tdata` | out | `DATA_WIDTH` | 0 |
| `m_axis_tstrb` | out | `DATA_WIDTH/8` | 0 |
| `m_axis_tlast`, `m_axis_tvalid` | out | 1 | 0 |

## Registers

None.

## Verification

`make sim IP=axis_constant`: `tc_outputs_always_zero` (DATA_WIDTH 64 and 160, in and out of reset, random `tready`). Checked to fail with `tvalid = 1`.

## Files

```
cores/ip/axis_constant/
  README.md
  axis_constant.core
  hdl/axis_constant.sv -> ../../../../../rtl_lib/ip/axis_constant.sv
  tests/axis_constant_tc00.sv, axis_constant_tests.sv
```

## Open items

- First hardware run with the ported IP.
