# Vector to single bits (qick_vec2bit)

Splits a vector into separate single-bit outputs `dout0`..`dout15` (`dout<i> = din[i]`). In the tProc v2 firmwares it fans a tProc data port out to individual trigger pins.

- VLNV: `qick:ip:qick_vec2bit:1.0.0` (module `qick_vec2bit`)
- Replaces: the legacy `QICK:QICK:qick_vec2bit:1.0` (openquantumhardware/qick `firmware/ip/qick_vec2bit`), with the same ports, parameters and
  behaviour
- Driver: none (no registers)
- Used in: 216 `tpv2_std_rfbv2`

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 din[IN_DW-1:0] --> dout0 = din[0], dout1 = din[1], ... dout15 = din[15]
```

## U2. The rules that are not obvious

- Combinational, no clock.
- `OUT_QTY` only chooses how many `dout` ports the block design shows (`dout<i>` for `i < OUT_QTY`); the RTL ignores it.
- If `IN_DW < 16`, the outputs above `IN_DW` are 0 (the legacy RTL read past the end of `din` there).
- **Keep the port names.** QickSoc traces trigger pins through this block by the number in `dout<i>` (`qick_lib/qick/ip.py`).

## U3. Data formats

See U1.

## U4. Throughput and limits

One word per clock; no registers or memories to configure.

## U5. Python quick start

Nothing to do: the IP has no registers.

## U6. Using it in a block design

`IN_DW` (default 16): width of the connected vector. `OUT_QTY` (default 4): number of outputs to show.

## U7. Gotchas

| Symptom | Cause | What to do |
|---|---|---|
| A `dout` port is missing in the BD | `OUT_QTY` too small | Raise `OUT_QTY` |

## U8. Validation status

| What | Where | Result |
|---|---|---|
| Legacy RTL, same behaviour | 216 tProc v2 QICK firmware (rfbv2) | In production |
| This SystemVerilog port | SVUnit (Part II) | 2/2, exhaustive against the legacy RTL |
| This port in the Top BDs | `validate_bd_design`, Vivado 2025.2 | 2 BDs, see the CHANGELOG |
| This port on hardware | -- | Not yet |

---

# Part II -- Reference

## Ports

| Port | Dir | Width | Notes |
|---|---|---|---|
| `din` | in | `IN_DW` | |
| `dout0`..`dout15` | out | 1 | `dout<i>` shown for `i < OUT_QTY` |

## Registers

None.

## Verification

`make sim IP=qick_vec2bit`: `tc_matches_legacy_exhaustive` (all 65536 inputs, equal to the legacy RTL in `tests/ref`), `tc_narrow_input_upper_outputs_zero` (IN_DW 8). Checked to fail with two outputs swapped.

## Files

```
cores/ip/qick_vec2bit/
  README.md
  qick_vec2bit.core
  qick_vec2bit.optional_interfaces.yaml     # dout<i> present when OUT_QTY > i
  tests/ref/qick_vec2bit_legacy.v           # golden model (legacy RTL)
  hdl/qick_vec2bit.sv -> ../../../../../rtl_lib/ip/qick_vec2bit.sv
  tests/qick_vec2bit_tc00.sv, qick_vec2bit_tests.sv
```

## Open items

- First hardware run with the ported IP.
