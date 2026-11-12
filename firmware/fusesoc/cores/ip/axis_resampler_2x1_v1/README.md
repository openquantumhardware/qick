# 2:1 lane resampler (axis_resampler_2x1_v1)

Turns a stream of N-lane words that is valid every other clock into a stream of N/2-lane words valid on every clock: each input word comes out as its low half, then its high half.

- VLNV: `qick:ip:axis_resampler_2x1_v1:1.0.0` (module `axis_resampler_2x1_v1`)
- Replaces: the legacy `QICK:QICK:axis_resampler_2x1_v1:1.0` (openquantumhardware/qick `firmware/ip/axis_resampler_2x1_v1`), with the same ports, parameters and
  behaviour
- Driver: none (no registers)
- Used in: 216 `tpv2_demo` (between the RFDC ADC and `axis_readout_v3`)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 s_axis (N lanes, valid every other clock) --> m_axis (N/2 lanes): low half, then high half
```

## U2. The rules that are not obvious

- **The input must be valid at most every other clock.** A faster input corrupts the output, and nothing reports it (the legacy IP carries the same warning).
- Timing: for a word sampled at edge k, the low half is on the output after edge k+2 and the high half after edge k+3, both with `m_axis_tvalid = 1`.
- No backpressure: `s_axis_tready` is always 1, `m_axis_tready` is ignored.
- Synchronous active-low reset clears the pipeline.

## U3. Data formats

See U1.

## U4. Throughput and limits

One word per clock; no registers or memories to configure.

## U5. Python quick start

Nothing to do: the IP has no registers.

## U6. Using it in a block design

`B` (default 16) bits per lane, `N` (default 8) input lanes (even). `aclk`: the stream clock. The 216 demo uses the defaults.

## U7. Gotchas

| Symptom | Cause | What to do |
|---|---|---|
| Every other output word wrong | The input is valid on consecutive clocks | Feed it a half-rate stream only |

## U8. Validation status

| What | Where | Result |
|---|---|---|
| Legacy RTL, same behaviour | 216 tProc v2 demo firmware | In production |
| This SystemVerilog port | SVUnit (Part II) | 3/3, against the legacy RTL |
| This port in the Top BDs | `validate_bd_design`, Vivado 2025.2 | 2 BDs, see the CHANGELOG |
| This port on hardware | -- | Not yet |

---

# Part II -- Reference

## Ports

| Port | Dir | Width | Notes |
|---|---|---|---|
| `aclk`, `aresetn` | in | 1 | |
| `s_axis_tdata/tvalid/tready` | in/in/out | `N*B`/1/1 | `tready` constant 1 |
| `m_axis_tdata/tvalid/tready` | out/out/in | `N/2*B`/1/1 | `tready` ignored |

## Registers

None.

## Verification

`make sim IP=axis_resampler_2x1_v1` (B=16, N=8): `tc_matches_legacy` (every clock equal to the legacy RTL in `tests/ref`, random valid gaps of two clocks or more), `tc_low_then_high_half`, `tc_ready_and_reset`. Checked to fail with the halves swapped.

## Files

```
cores/ip/axis_resampler_2x1_v1/
  README.md
  axis_resampler_2x1_v1.core
  tests/ref/axis_resampler_2x1_v1_legacy.sv  # golden model (legacy RTL)
  hdl/axis_resampler_2x1_v1.sv -> ../../../../../rtl_lib/ip/axis_resampler_2x1_v1.sv
  tests/axis_resampler_2x1_v1_tc00.sv, axis_resampler_2x1_v1_tests.sv
```

## Open items

- First hardware run with the ported IP.
