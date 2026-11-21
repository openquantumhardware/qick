# I/Q lane interleaver (axis_reorder_iq_v1)

Reorders a word of L I samples followed by L Q samples into L interleaved (Q, I) pairs, the order a PFB expects.

- VLNV: `qick:ip:axis_reorder_iq_v1:1.0.0` (module `axis_reorder_iq_v1`)
- Replaces: the legacy `QICK:QICK:axis_reorder_iq_v1:1.0` (openquantumhardware/qick `firmware/ip/axis_reorder_iq_v1`), with the same ports, parameters and
  behaviour
- Driver: none (no registers)
- Used in: no Top project at the moment

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 in:  Q[L-1] ... Q[1] Q[0] I[L-1] ... I[1] I[0]
 out: Q[L-1] I[L-1] ... Q[1] I[1] Q[0] I[0]
```

## U2. The rules that are not obvious

- Combinational: `m_axis_tvalid = s_axis_tvalid`, `s_axis_tready = 1`, `m_axis_tready` ignored.

## U3. Data formats

See U1.

## U4. Throughput and limits

One word per clock; no registers or memories to configure.

## U5. Python quick start

Nothing to do: the IP has no registers.

## U6. Using it in a block design

`B` (default 16) bits per I or Q sample, `L` (default 4) lanes. `aclk`: the stream clock (unused inside).

## U7. Gotchas

| Symptom | Cause | What to do |
|---|---|---|
| I and Q swapped downstream | Input not in the `{Q..., I...}` order | Check the producer's lane order |

## U8. Validation status

| What | Where | Result |
|---|---|---|
| Legacy RTL, same behaviour | (not used in the current firmwares) | In production |
| This SystemVerilog port | SVUnit (Part II) | 2/2, against the legacy RTL |
| This port in the Top BDs | `validate_bd_design`, Vivado 2025.2 | not used in any BD |
| This port on hardware | -- | Not yet |

---

# Part II -- Reference

## Ports

| Port | Dir | Width | Notes |
|---|---|---|---|
| `aclk`, `aresetn` | in | 1 | unused (combinational) |
| `s_axis_tdata/tvalid/tready` | in/in/out | `2*B*L`/1/1 | `tready` constant 1 |
| `m_axis_tdata/tvalid/tready` | out/out/in | `2*B*L`/1/1 | `tready` ignored |

## Registers

None.

## Verification

`make sim IP=axis_reorder_iq_v1` (L=4 and 8): `tc_matches_legacy` (2000 random words, equal to the legacy RTL in `tests/ref`), `tc_interleave_example`. Checked to fail with I and Q swapped.

## Files

```
cores/ip/axis_reorder_iq_v1/
  README.md
  axis_reorder_iq_v1.core
  tests/ref/axis_reorder_iq_v1_legacy.sv    # golden model (legacy RTL)
  hdl/axis_reorder_iq_v1.sv -> ../../../../../rtl_lib/ip/axis_reorder_iq_v1.sv
  tests/axis_reorder_iq_v1_tc00.sv, axis_reorder_iq_v1_tests.sv
```

## Open items

- First hardware run with the ported IP.
