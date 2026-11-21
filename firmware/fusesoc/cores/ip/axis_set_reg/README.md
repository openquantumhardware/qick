# AXIS Set Reg (axis_set_reg)

A register on an AXI4-Stream bus: it captures every word it receives and holds the last one on a plain output
port. In tProcessor v1 designs it turns a tProc output port (a stream) into a level that can drive FPGA pins or
trigger bits.

- Project: QICK, `qick:ip:axis_set_reg:1.0.0` (module `axis_set_reg`)
- Driver: none (no registers; the QICK software only reads its connections from the block design, see U6)
- Legacy: the standard tProc v1 block designs (`Top/111/tpv1_rfbv1_std`) instantiate the old Vivado IP
  `QICK:QICK:axis_set_reg:1.0`; the software recognises the block by its module name, so either packaging is found
- Hardware bring-up: none of this fusesoc version (see U8)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 s_axis (DATA_WIDTH) --[tvalid]--> data register --> dout (DATA_WIDTH, held between words)
   tready = 1 always
```

Whenever `s_axis_tvalid` is high on a clock edge, `s_axis_tdata` is copied into an internal register; otherwise the
register keeps its value. `dout` is that register, so it changes one clock after the word was accepted and stays until
the next word. After reset it is 0.

## U2. Rules that are not obvious

- **It never applies back-pressure.** `s_axis_tready` is constant 1, so a producer that waits for `tready` is never
  stalled and a word sent while `tvalid` is high is always taken.
- **Only `tvalid` is looked at.** `tstrb` and `tlast` are ignored, and there is no notion of a packet: every valid beat
  overwrites the register.
- **`dout` is a level, not a pulse.** A value written once stays on the pins until another word arrives. To make a
  pulse the producer (the tProc program) has to write the value and then write 0.
- **Latency:** one clock from the beat to `dout`, on the same clock as the stream (`s_axis_aclk`); the output is
  synchronous to that clock, with no synchroniser, so use it in that domain or cross it yourself.

## U3. Data format

`dout` has the same width as the stream (`DATA_WIDTH`, default 16), bit for bit. In the standard designs `dout` goes
to a `vect2bits` / `qick_vec2bit` block that splits it into single-bit outputs (`dout0` ... `dout15`).

## U4. Memories, throughput and limits

No memory. One word per clock at most; it accepts a word on every cycle `tvalid` is high.

## U5. Python quick start

There is nothing to drive from Python: the block has no registers. What Python does is **read the wiring**: for a
tProc v1, `qick_lib/qick/drivers/tproc.py` follows each tProc output port (`m1_axis` ... `m8_axis`) to an
`axis_set_reg`, then follows its `dout` to a `vect2bits`, and records which FPGA pin each bit reaches
(`cfg['output_pins']`); `qick_lib/qick/ip.py` uses the same chain to find which tProc port and bit triggers a readout
buffer. The tProc program sets the pins by writing to its output port.

## U6. Using it in a block design

- `s_axis` (AXI4-Stream slave, `DATA_WIDTH` bits) connects to a tProc v1 output port; `s_axis_aclk` /
  `s_axis_aresetn` are the tProc's clock and reset.
- `dout` connects to `vect2bits` / `qick_vec2bit`, whose bit outputs go to top-level pins or to the trigger inputs of
  the readout buffers. **Keep the chain tProc port -> `axis_set_reg` -> `vect2bits`**: the software follows exactly that
  chain, and a different topology is not recognised (`trigger` bits cannot be found).
- Parameter: `DATA_WIDTH` (default 16; must be greater than 0).
- No constraints beyond the clock of the stream.

## U7. Gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Expecting a pulse | The pin stays high after one write | Write the value, then write 0 |
| Wiring something other than a `vect2bits` after `dout` | The software does not find the pins or trigger bits | Keep the standard chain (U6) |
| Reading `dout` in another clock domain | Metastability | Synchronise it |
| `tlast` / `tstrb` used to frame data | Ignored | Do not rely on them |

## U8. Validation status

- **Simulation only for this fusesoc version**: 4 SVUnit tests (`tready` always high, a single word captured, the value
  held through bubbles, back-to-back words) and a plain testbench `tests/tb_axis_set_reg.sv`.
- **Hardware**: the function is the same as the legacy IP that the tProc v1 standard firmwares use; this fusesoc
  packaging has not been built into a bitstream or run on a board.
- Not verified: behaviour with `DATA_WIDTH` other than 16 beyond what the simulation covers; reset behaviour in a full
  design.

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `s_axis_aclk`, `s_axis_aresetn` | in | clock and active-low reset of the stream and of `dout` |
| `s_axis_tdata[DATA_WIDTH-1:0]` | in | data word |
| `s_axis_tstrb[DATA_WIDTH/8-1:0]` | in | ignored |
| `s_axis_tlast` | in | ignored |
| `s_axis_tvalid` | in | capture strobe |
| `s_axis_tready` | out | constant 1 |
| `dout[DATA_WIDTH-1:0]` | out | registered data, 0 after reset |

## Registers

None.

## Verification

`tests/axis_set_reg_tests.sv` (SVUnit through `axis_set_reg_tc00.sv`): `test_tready_always_asserted`,
`test_single_word_capture`, `test_hold_value_during_bubbles`, `test_back_to_back_streaming`.
`make sim IP=axis_set_reg` runs them.

## Files

```
cores/ip/axis_set_reg/
  README.md
  axis_set_reg.core                 # VLNV qick:ip:axis_set_reg:1.0.0
  hdl/axis_set_reg.sv
  tests/axis_set_reg_tc00.sv, axis_set_reg_tests.sv, tb_axis_set_reg.sv
```

## Open items

- No driver and no register map by design: the software only reads the block's connections (U5), so there is no driver to
  migrate; the `qick:ip:` VLNV does not matter to it because it matches by module type name.
