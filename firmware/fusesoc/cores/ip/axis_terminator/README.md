# AXIS sink (axis_terminator)

An AXI4-Stream slave that accepts every beat and discards it (`s_axis_tready` is always 1). It closes an unused AXI4-Stream master output in a block design.

- VLNV: `qick:ip:axis_terminator:1.0.0` (module `axis_terminator`)
- Replaces: the legacy `QICK:QICK:axis_terminator:1.0` (openquantumhardware/qick `firmware/ip/axis_terminator`), with the same ports, parameters and
  behaviour
- Driver: none (no registers)
- Used in: 111 `tpv1_rfbv1_std`

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 s_axis_tready = 1   (tdata, tstrb, tlast, tvalid discarded)
```

## U2. The rules that are not obvious

- Everything sent to it is lost, without any indication.
- The clock and reset ports exist only so the block design can associate `s_axis` with a clock; they are unused.

## U3. Data formats

See U1.

## U4. Throughput and limits

One word per clock; no registers or memories to configure.

## U5. Python quick start

Nothing to do: the IP has no registers.

## U6. Using it in a block design

`DATA_WIDTH` (default 16, multiple of 8): set it to the width of the output it closes (256 in 111 `tpv1_rfbv1_std`). `s_axis_aclk`: the clock of that output.

## U7. Gotchas

| Symptom | Cause | What to do |
|---|---|---|
| Width mismatch warning in the BD | `DATA_WIDTH` left at 16 | Set it to the producer's TDATA width |

## U8. Validation status

| What | Where | Result |
|---|---|---|
| Legacy RTL, same behaviour | 111 tProc v1 QICK firmware | In production |
| This SystemVerilog port | SVUnit (Part II) | 1/1 |
| This port in the Top BDs | `validate_bd_design`, Vivado 2025.2 | 1 BD, see the CHANGELOG |
| This port on hardware | -- | Not yet |

---

# Part II -- Reference

## Ports

| Port | Dir | Width | Notes |
|---|---|---|---|
| `s_axis_aclk`, `s_axis_aresetn` | in | 1 | unused |
| `s_axis_tready` | out | 1 | constant 1 |
| `s_axis_tdata` | in | `DATA_WIDTH` | discarded |
| `s_axis_tstrb` | in | `DATA_WIDTH/8` | discarded |
| `s_axis_tlast`, `s_axis_tvalid` | in | 1 | discarded |

## Registers

None.

## Verification

`make sim IP=axis_terminator`: `tc_always_ready` (DATA_WIDTH 256 and 16, in and out of reset, random inputs). Checked to fail with `tready = 0`.

## Files

```
cores/ip/axis_terminator/
  README.md
  axis_terminator.core
  hdl/axis_terminator.sv -> ../../../../../rtl_lib/ip/axis_terminator.sv
  tests/axis_terminator_tc00.sv, axis_terminator_tests.sv
```

## Open items

- First hardware run with the ported IP.
