# `qick_periph_loopback`: test peripheral for the QP1 / QP2 ports of the tProc v2

Answers a `PA` / `PB` command with a function of its operands after a fixed delay. It exists to test the peripheral ports of the tProc: command, wait for new data, read both words, branch on the QP1 flag, clear the flag.

- VLNV: `qick:ip:qick_periph_loopback:1.0.0` (module `qick_periph_loopback`, source `rtl_lib/ip/qick_periph_loopback.sv`)
- Kind: IP core (it was a `qick:utils` library core until it had to be a block in a Top): one clock (`clk_i`, the tProc `c_clk`), asynchronous
  active-low reset (`rst_ni`), no AXI; the tProc's `QPeriphA` / `QPeriphB` connect to its `qick_peripheral` slave interface
  (`qick_periph_loopback.bus_interfaces.yaml`, `.clock_domains.yaml`). `cmd_cnt_o` / `drop_cnt_o` are plain 32-bit ports (the bench reads them with GPIOs).
- Status: SVUnit 6/6 on its own; used by the `qick_processor` bench with two instances (QP1 delay 3, QP2 delay 5); packages with `make package IP=qick_periph_loopback`;
  in the RFSoC4x2 debug bench of the tProc v2 (BD validated, validation notebook). Run on the RFSoC4x2 (2026-10-13): all notebook steps pass.

## Behaviour

| | |
|---|---|
| Command | taken on a clock with `en_i` high and `rdy_o` high |
| `rdy_o` | high when it can take a command; low while working |
| Result | `DELAY` clocks after the command clock, `vld_o` pulses for one clock; `dt1_o = a + b` (wraps), `dt2_o = c ^ d ^ op`; held after the pulse |
| `flag_o` | bit 0 of operand `a` of the last command (the tProc branches on it with `flag='a'`) |
| `en_i` while busy | **dropped**, counted in `drop_cnt_o` (the tProc does not stall on `rdy`: three `PA` back to back give one command and two drops) |
| Observation | `cmd_cnt_o` commands taken, `drop_cnt_o` commands dropped (both 32 bit, for a register or an ILA) |

Ports follow the packaged `qick_processor`: `en_i` <- `qpN_en_o`, `op_i` <- `qpN_op_o`, `a..d_i` <- `qpN_a..d_dt_o`, `rdy_o` -> `qpN_rdy_i`,
`dt1_o`/`dt2_o` -> `qpN_dt1_i`/`qpN_dt2_i`, `vld_o` -> `qpN_vld_i`, `flag_o` -> `qp1_flag_i` or, from tProc v2 revision 29, `qp2_flag_i` (before that QP2 had no flag input and `flag_o` is left open on `QPeriphB`).

| Parameter | Default | Meaning |
|---|---|---|
| `DELAY` | 3 | clocks from the command to `vld_o` (>= 1) |

## Verification

`make sim IP=qick_periph_loopback`: reset state; the result on `vld_o` exactly `DELAY` clocks after the command with `rdy_o` low in between (DELAY 1 and 3 side by
side); the flag follows bit 0 of `a`; the sum wraps; a command while busy is dropped and counted without disturbing the one in progress; a command right after
`rdy_o` goes high is taken. Verible and Verilator `-Wall` clean for `DELAY` 1, 2, 3, 8. **Not verified:** synthesis, hardware, back-to-back commands from a tProc
running at its own clock ratio (the bench has one clock).

With the tProc (`cores/ip/qick_processor/tests`, `tc_loopback_*`): a program built with the `QickProgramV2` macros runs on the real core, the answer is read
through `s_core_r1/s_core_r2`, the conditional jump on the QP1 flag is taken only when the flag is set, `CLEAR qpa` clears `QPA_DT_NEW`.
