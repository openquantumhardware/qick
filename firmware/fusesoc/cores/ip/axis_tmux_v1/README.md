# AXIS demultiplexer by top byte (axis_tmux_v1)

Sends each input word to one of `N` outputs, chosen by a selection field inside the word itself. In the tProc v2
firmwares it lets one tProc wave port configure several tProc-controlled readouts: the tProc writes the readout
number into the top byte of the descriptor, and only that readout's descriptor input sees `tvalid`.

- VLNV: `qick:ip:axis_tmux_v1:1.0.0` (module `axis_tmux_v1`)
- Replaces: the legacy `QICK:QICK:axis_tmux_v1:1.0` (openquantumhardware/qick `firmware/ip/axis_tmux_v1`), with the same ports,
  parameters and behaviour (wrapper and `tmux` merged into one module)
- Driver: none (no registers). QickSoc recognises it by type name when tracing a generator or readout back to the
  tProc (`qick_lib/qick/drivers/generator.py`, `readout.py`): the output index is the selection value to use.
- Used in: 216 `tpv2_std`, `tpv2_std_rfbv2`, `tpv2_demo`, `tpv2_1ch`, `tpv2_1ch_xcom_mts` (`B = 168`, `N = 3` or 4)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 s_axis (B bits) --[reg]--[reg]--+--> m0_axis   tvalid = (sel == 0)
                                 +--> m1_axis   tvalid = (sel == 1)
                                 ...            (N outputs)
   sel = word[B-1 -: 8][2:0]     +--> m<N-1>_axis
```

## U2. The rules that are not obvious

- **The selection is inside the data.** `sel` is the low 3 bits of the word's top byte
  (`s_axis_tdata[B-8 +: 3]`). The other 5 bits of that byte are ignored: a top byte of `0x09` selects output 1.
- **The word is not changed.** Every output shows the whole word, selection byte included; only `tvalid` differs.
  The consumer must ignore the top byte (the readout descriptors leave those bits unused).
- **A selection with no output drops the word.** `sel >= N` raises no `tvalid`, and nothing reports it.
- **No backpressure.** `s_axis_tready` is always 1 and the outputs have no `tready`. The consumers must accept a
  word on any clock (the tProc-configured readouts' descriptor FIFOs do).
- **Latency 2 clocks** from `s_axis` to the outputs. Synchronous active-low reset clears both stages.

## U3. Data formats

`s_axis_tdata`: `[B-1:B-8]` selection byte (only `[B-8+2:B-8]` used), `[B-9:0]` payload. In the tProc v2 BDs
(`B = 168`) the selection byte is the top byte of the wave-port CONF field.

## U4. Throughput and limits

One word per clock. `N` from 1 to 8; `B >= 8`.

## U5. Python quick start

Nothing to do on the IP. QickSoc finds the tmux between the tProc and a readout and uses the output index as the
selection value in the readout's descriptor.

## U6. Using it in a block design

| Parameter | Default | Standard BDs |
|---|---|---|
| `N` (outputs) | 2 | 3 or 4 |
| `B` (bits) | 16 | 168 (the tProc v2 wave-port width) |

`m<i>_axis` exists only for `i < N`. `aclk`/`aresetn`: the clock of the tProc wave port and of the consumers.

## U7. Gotchas

| Symptom | Cause | What to do |
|---|---|---|
| A readout never gets its configuration | Its output index is `>= N`, or the selection byte is wrong | Check `N` and the tProc channel mapping |
| Consumer sees unexpected high bits | The selection byte is not stripped | Expected; the consumer ignores them |

## U8. Validation status

| What | Where | Result |
|---|---|---|
| Legacy RTL, same behaviour | every 216 tProc v2 QICK firmware | In production |
| This SystemVerilog port | SVUnit against the legacy RTL (Part II) | 4/4, bit-exact at N=3/4 B=168, N=2 B=16, N=8 B=32 |
| This port in the Top BDs | `validate_bd_design`, Vivado 2025.2 | See the CHANGELOG entry |
| This port on hardware | -- | Not yet |

---

# Part II -- Reference

## Ports

| Port | Dir | Width | Notes |
|---|---|---|---|
| `aclk`, `aresetn` | in | 1 | |
| `s_axis_tdata/tvalid/tready` | in/in/out | B/1/1 | `tready` constant 1 |
| `m<i>_axis_tdata/tvalid`, i = 0..7 | out | B/1 | present for `i < N`; no `tready` |

## Registers

None.

## Verification

`make sim IP=axis_tmux_v1`, four configurations side by side (N=3 B=168, N=4 B=168, N=2 B=16, N=8 B=32), each next
to the legacy RTL (`tests/ref/axis_tmux_v1_legacy.sv`, the original files with only the module names changed):

- `tc_matches_legacy`: tready, every existing output's tvalid and data equal to the legacy RTL, 2000 random words
- `tc_routing_and_latency`: exactly output `sel` is valid two clocks later; every output shows the whole word
- `tc_selection_rules`: only 3 bits of the top byte count; `sel >= N` reaches nothing; outputs `>= N` never valid
- `tc_ready_and_reset`: `tready` is 1; reset clears both stages

Checked to fail when the selection is taken one stage early.

## Files

```
cores/ip/axis_tmux_v1/
  README.md
  axis_tmux_v1.core
  axis_tmux_v1.optional_interfaces.yaml     # m<i>_axis present when N > i
  hdl/axis_tmux_v1.sv -> ../../../../../rtl_lib/ip/axis_tmux_v1.sv
  tests/axis_tmux_v1_tc00.sv, axis_tmux_v1_tests.sv
  tests/ref/axis_tmux_v1_legacy.sv          # golden model (legacy RTL)
```

## Open items

- First hardware run with the ported IP.
