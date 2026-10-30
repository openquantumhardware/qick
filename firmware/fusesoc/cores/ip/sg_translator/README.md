# tProc v2 descriptor translator (sg_translator)

Takes the 168-bit descriptor that a tProc v2 wave port emits and re-packs it into the descriptor format of one
kind of generator or readout. It is the glue between `qick_processor`'s `m*_axis` wave ports and the `s1_axis`
(generators) or `s0_axis` (tProc-configured readouts) descriptor inputs.

- VLNV: `qick:ip:sg_translator:1.0.0` (module `sg_translator`)
- Replaces: the legacy `QICK:QICK:sg_translator:1.0` (openquantumhardware/qick `firmware/ip/qick_sg_translator`), with the same
  interfaces, parameter and behaviour
- Driver: none (no registers). QickSoc traces through it by type name `sg_translator` and interface `s_tproc_axis`
  (`qick_lib/qick/ip.py`).
- Used in: every tProc v2 Top project (111/4x2/216 `tpv2_std`, 216 `tpv2_demo`, `tpv2_1ch`, `tpv2_std_rfbv2`)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 qick_processor m<k>_axis --> s_tproc_axis --[re-pack for OUT_TYPE]--> m_gen_v6_axis      (OUT_TYPE 0)
                                                                    m_int4_axis        (OUT_TYPE 1)
                                                                    m_mux4_axis        (OUT_TYPE 2)
                                                                    m_readout_v3_axis  (OUT_TYPE 3)
```

Combinational: no clock cycles, no registers. `aclk` and `aresetn` exist for the block design only.

## U2. The rules that are not obvious

- **One output per instance.** `OUT_TYPE` selects which output exists in the block design; the other three are
  hidden (their ports are still in the RTL, with `tvalid = 0`).
- **`s_tproc_axis_tready` is the selected output's `tready`.** Backpressure from the generator or readout reaches
  the tProc wave port unchanged, so this block must not be separated from its consumer by an
  `axis_register_slice_nb` (which ignores `tready`). Use Xilinx `axis_register_slice` if a register stage is needed,
  as the standard BDs do.
- **Fields are truncated.** The tProc descriptor carries 32-bit length, gain and a 24-bit address; the gen_v6 and
  readout descriptors take 16 bits of length and gain, and int4 takes 16 bits of every field. Upper bits are dropped
  without saturation.
- `m_readout_v3_axis` is also the descriptor format of `axis_dyn_readout_v1`; the standard BDs use `OUT_TYPE = 3`
  for it.

## U3. Data formats

tProc v2 wave-port word (`s_tproc_axis_tdata`, 168 bit):

| Bits | 167..152 | 151..120 | 119..88 | 87..64 | 63..32 | 31..0 |
|---|---|---|---|---|---|---|
| Field | CONF | LENGTH | GAIN | ENV (address) | PHASE | FREQ |

CONF: bit 4 `phrst`, bit 3 `stdysel`, bit 2 `mode`, bits 1..0 `outsel`.

`m_gen_v6_axis_tdata` (160 bit, `OUT_TYPE = 0`):

| 159..149 | 148 | 147 | 146 | 145..144 | 143..128 | 127..112 | 111..96 | 95..80 | 79..64 | 63..32 | 31..0 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | phrst | stdysel | mode | outsel | LENGTH[15:0] | 0 | GAIN[15:0] | 0 | ENV[15:0] | PHASE | FREQ |

`m_int4_axis_tdata` (88 bit, `OUT_TYPE = 1`):

| 87..85 | 84 | 83 | 82 | 81..80 | 79..64 | 63..48 | 47..32 | 31..16 | 15..0 |
|---|---|---|---|---|---|---|---|---|---|
| 0 | phrst | stdysel | mode | outsel | LENGTH[15:0] | GAIN[15:0] | ENV[15:0] | PHASE[15:0] | FREQ[15:0] |

`m_mux4_axis_tdata` (40 bit, `OUT_TYPE = 2`): `{CONF[7:0] (tone mask), LENGTH[31:0]}`.

`m_readout_v3_axis_tdata` (88 bit, `OUT_TYPE = 3`):

| 87..84 | 83 | 82 | 81..80 | 79..64 | 63..32 | 31..0 |
|---|---|---|---|---|---|---|
| 0 | phrst | mode | outsel | LENGTH[15:0] | PHASE | FREQ |

## U4. Throughput and limits

One descriptor per clock (combinational pass-through). Limits are the field truncations in U2.

## U5. Python quick start

Nothing to do: the IP has no registers. `QickSoc` uses it to find which tProc wave port drives each generator
and readout.

## U6. Using it in a block design

- `OUT_TYPE`: 0 for `axis_signal_gen_v6`, 1 for `axis_sg_int4_v1/v2`, 2 for `axis_sg_mux4_*`, 3 for
  `axis_readout_v3` / `axis_dyn_readout_v1`. Default 0.
- `aclk` / `aresetn`: the tProc timing clock and its reset, the same clock as the wave port and the consumer's
  descriptor input.

## U7. Gotchas

| Symptom | Cause | What to do |
|---|---|---|
| Output interface missing in the BD | `OUT_TYPE` selects another one | Set `OUT_TYPE` (U6) |
| Long pulses come out short | LENGTH above 16 bits is dropped | Split the pulse; gen_v6/readout lengths are 16 bit |
| Descriptors lost or repeated | A no-backpressure slice between the translator and its consumer | Use a slice that honours `tready` (U2) |

## U8. Validation status

| What | Where | Result |
|---|---|---|
| Legacy Verilog, same behaviour | every tProc v2 QICK firmware | In production |
| This SystemVerilog port | SVUnit against the legacy RTL (Part II) | 5/5, bit-exact on 2000 random descriptors per OUT_TYPE |
| This port in the Top BDs | `validate_bd_design`, Vivado 2025.2 | See the CHANGELOG entry |
| This port on hardware | -- | Not yet: the next tProc v2 bitstream built from these BDs will be the first |

---

# Part II -- Reference

## Ports

| Port | Dir | Width | Notes |
|---|---|---|---|
| `aclk`, `aresetn` | in | 1 | unused inside (combinational), for the BD |
| `s_tproc_axis_tdata/tvalid/tready` | in/in/out | 168/1/1 | tProc v2 wave port |
| `m_gen_v6_axis_*` | out/out/in | 160/1/1 | `OUT_TYPE = 0` |
| `m_int4_axis_*` | out/out/in | 88/1/1 | `OUT_TYPE = 1` |
| `m_mux4_axis_*` | out/out/in | 40/1/1 | `OUT_TYPE = 2` |
| `m_readout_v3_axis_*` | out/out/in | 88/1/1 | `OUT_TYPE = 3` |

The legacy file named the ports `s_axis_*` and `m_readout_axis_*` under the interface names `s_tproc_axis` and
`m_readout_v3_axis`. Here the ports carry the interface names, so the packager infers the legacy interface names;
block designs connect by interface, so nothing changes for them.

## Registers

None.

## Verification

`make sim IP=sg_translator`, one instance per `OUT_TYPE`, each next to the legacy RTL (`tests/ref/
sg_translator_legacy.v`, the original file with only the module renamed):

- `tc_matches_legacy_all_out_types`: every output bit equal to the legacy RTL, 2000 random inputs per OUT_TYPE
- `tc_only_selected_output_valid`: only the selected output carries `tvalid`
- `tc_tready_follows_selected_output`: `s_tproc_axis_tready` is the selected output's `tready`
- `tc_field_layout`: layouts against a reference written from the descriptor tables (not from the legacy code)
- `tc_gen_v6_example`: one readable descriptor, field by field

Checked to fail when two CONF bits are swapped in the int4 layout.

## Files

```
cores/ip/sg_translator/
  README.md
  sg_translator.core
  sg_translator.optional_interfaces.yaml     # OUT_TYPE selects the output interface
  hdl/sg_translator.sv -> ../../../../../rtl_lib/ip/sg_translator.sv
  tests/sg_translator_tc00.sv, sg_translator_tests.sv
  tests/ref/sg_translator_legacy.v           # golden model (legacy RTL)
```

## Open items

- First hardware run with the ported IP.
