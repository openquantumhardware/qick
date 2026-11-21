# XCOM (xcom)

The board-to-board communication peripheral of a multi-board QICK system. Boards are connected by a synchronous serial
link (a clock and a data line, differential); through it a board can send 8-, 16- or 32-bit values to registers of another
board, set or clear its flags, write its memory, and **synchronise the time base and start or stop the tProcessor** of the
other boards. Commands come from the tProcessor (through the peripheral interface) or from Python (through AXI4-Lite).

- Project: QICK, `qick:ip:xcom:1.0.2` (module `xcom`; parameters `NCH = 2`, `SYNC = 1`, `LOOPBACK = 0`, `DEBUG = 1`)
- Driver: `QICK_Xcom` in `qick_lib/qick/drivers/xcom.py` does not bind `qick:ip:xcom:1.0` yet; no project of `firmware/Top` uses this core.
- 1.0.2 (2026-11-02): the RX data input (`xcom_clk_virt` -> `xcom_rx_clk_*`) is not timed: the link calibrates the IDELAY tap and
  the capture edge at run time, and the +-0.1 ns window of the input delays was never measured. RTL unchanged.
- 1.0.1 (2026-11-02): the constraints that use `i_time_clk`, `i_core_clk` or `i_ps_clk` are in `xcom_late.xdc` (processed LATE):
  in a block design those clocks did not exist yet when `xcom.xdc` was read, and Vivado dropped the constraints. The DDR data -> `i_clk`
  crossing of `xcom_link_rx` (`ddr_data_cdc_reg`) is bounded to one RX period. RTL unchanged.
- 1.0.0 (2026-10-29): `DEBUG_REG` is 32 bits (`xcom_txrx` 0.1.1): the tick, which made the bus 33 bits and lost its MSB, is
  out (it is `CFG_REG[3:0]`); bits `[31:29]` read 0.
- Fixed 2026-09-22: the Python command path used to repeat every command forever (see U2, U7, U8); simulation-verified, not
  yet run on a board.
- Hardware bring-up: none of this fusesoc version (see U8)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 tProc peripheral interface (core clock): en, op[4:0], data1, data2  --> ready, data1, data2, valid, flag
 Python AXI4-Lite (PS clock): CTRL, CFG, AXI_DATA1, AXI_DATA2, ADDR  --> read-only: BOARD_ID, FLAG, DT1, DT2, MEM, STATUS, DEBUG
        |                                                                   |
   command decoder --+-- LOCAL commands (op[4] = 1): set ID, write flag/register/memory, reset  -> this board
                     +-- NETWORK commands (op[4] = 0): send data, set/clear a flag, sync, start/stop, update time -> other boards
        |
   serial link (time clock): xcom_clk / xcom_data out (1 channel), in (NCH channels)      + differential buffers
        |
   to the processor: proc_start/stop, core_start/stop, time_rst, time_update(+data), 4-bit board id
```

Three clock domains cross inside the IP: the PS clock (registers), the core clock (tProc peripheral interface) and the time
clock (the serial link and the time control). `xcom_cdc` assumes `time_clk > core_clk > ps_clk`.

## U2. Rules that are not obvious

- **Commands are 5-bit opcodes.** The MSB of the opcode selects where it runs: `1` = a **local** command (on this board), `0` = a
  **network** command (sent to another board). The list, from the driver (`opcodes`):

  | opcode | name | | opcode | name |
  |---|---|---|---|---|
  | 0 | `XCOM_CLEAR_FLAG` | | 10 | `XCOM_UPDATE_DT8` |
  | 1 | `XCOM_SET_FLAG` | | 11 | `XCOM_QCTRL` (processor control) |
  | 2 / 3 | `XCOM_SEND_8BIT_1` / `_2` | | 12 | `XCOM_UPDATE_DT16` |
  | 4 / 5 | `XCOM_SEND_16BIT_1` / `_2` | | 14 | `XCOM_UPDATE_DT32` |
  | 6 / 7 | `XCOM_SEND_32BIT_1` / `_2` | | 16 | `XCOM_SET_ID` (local) |
  | 8 | `XCOM_QRST_SYNC` (time reset, in coordination with `i_sync`) | | 17 | `XCOM_WRITE_FLAG` (local) |
  | 9 | `XCOM_AUTO_ID` (automatic ID assignment) | | 18 / 19 | `XCOM_WRITE_REG` / `XCOM_WRITE_MEM` (local) |
  | | | | 31 | `XCOM_RST` (local) |

  Opcodes 13 and 15 are reserved for future use (`XCOM_RFU1`, `XCOM_RFU2`). The `_1` / `_2` suffix picks the destination register 1 or 2
  of the receiving board.
- **`CTRL_REG` layout:** bit 0 is the command-valid strobe from Python and bits `[5:1]` the opcode; the driver writes
  `1 + 2*opcode` after loading `AXI_DATA1` (destination board) and `AXI_DATA2` (data). Board numbers are 4 bits.
- **Fixed (2026-09-22): a Python command used to execute over and over, forever.** Two separate defects, both needed fixing:
  1. `CTRL_REG` never cleared itself: with `AUTO_CLEAR_BIT0` not set on this top's `axil_slv`, and the driver only ever writing
     `1 + 2*opcode` (never a separate 0), bit 0 stayed 1 after the first command. Fixed by adding `AUTO_CLEAR_BIT0 = 1'b1` to
     the `axil_slv` instance (the same parameter `qick_time_tagger`'s CTRL register uses), so `CTRL_REG` self-clears to 0 one
     `i_ps_clk` cycle after any nonzero write.
  2. Even with a genuinely one-clock strobe, `xcom_cmd`'s valid signal (`s_valid = i_ps_ctrl[0] | i_core_en`) reacted to the
     **level** of `i_ps_ctrl[0]`, not its edge (unlike `qtt_cmd`, which edge-detects its own AXI-side strobe as `p_en_r_t01`).
     `i_ps_ctrl[0]` reaches `xcom_cmd`'s clock (`i_time_clk`) through a plain 2-flop level synchroniser (`xcom_cdc`'s
     `cdc_bit_sync`) with no edge detection, so a pulse wide enough to cross safely (see item 3) was itself wide enough, once
     seen in the much faster `i_time_clk` domain, for `req_ack_cmd`'s request/acknowledge FSM to run several full round trips
     before the level dropped. Fixed by edge-detecting `i_ps_ctrl[0]` inside `xcom_cmd` (`ps_ctrl0_r` / `ps_valid_pulse`).
  3. The opcode bits (`CTRL[31:1]`) cross into `i_time_clk` with **no synchroniser at all**
     (`assign o_xcom_ctrl_sync[31:1] = i_xcom_ctrl[31:1]`), so the new `xcom_cmd_hold` core holds the strobe and the opcode
     stable for `HOLD` (6) `i_ps_clk` cycles, the same treatment `qick_time_tagger`'s `qtt_cmd_hold` gives its own CTRL
     register (whose command path lost about 6 % of its commands on hardware for a related reason; its README, U7).

     Confirmed in simulation with a bench that drives the AXI side (now a committed test, `test02_axi_command_executes_once`):
     before any fix, one write of `CTRL_REG` with `XCOM_SET_ID` raised the command counter by 13 in 300 `i_ps_clk` cycles and
     kept counting; with `AUTO_CLEAR_BIT0` alone (no edge detector) it dropped to 6 repeats, still wrong; with all three fixes,
     exactly 1.
- **`CFG_REG`** (synchronised into the time domain): bits `[3:0]` set the time of each bit, `2*(tick+1)` cycles of the time
  clock (`xcom_link_tx`; values above 10 act as 10), bit 8 the clock polarity, bit 9 the clock phase, bit 10 automatic phase,
  bit 28 disables the synchronisation (`XCOM_QRST_SYNC` does not wait for `i_sync`), bit 31 the internal loopback (only if the
  IP was built with `LOOPBACK = 1` and `DEBUG = 1`). `xcom_config()` writes it.
- **`TX_RX_DDR_REG`** (the DDR link): bits `[8:0]` the TX ODELAY taps, bit 11 the TX clock boost (twice the
  `xcom_clk` rate through the ODDR, about 215 MHz; the tick is then ignored), bit 15 a fixed test pattern (BIST), bits `[24:16]`
  the RX IDELAY taps (stepped to the value written). `tx_ddr_cfg()` and `rx_ddr_cfg()` write it, each keeping the other half.
  The legacy slave has no such register (index 5 reads 0).
- **The driver configures the IP when it is created** (`_init_firmware`, as the other QICK drivers do): no command pending,
  `xcom_config()` with its defaults (auto phase on, external sync off, tick 0) and `TX_RX_DDR` 0. Call `xcom_config()` after
  `QickSoc()` for another configuration.
- **Board IDs.** Each board has a 4-bit ID (`BOARD_ID_REG`, and `o_xcom_id` for LEDs); `XCOM_SET_ID` sets it locally and
  `XCOM_AUTO_ID` is the automatic assignment. The driver accepts destinations below 16 (its message says 1 to 15).
- **`LOOPBACK` is only built in if `DEBUG` is 1** (`LOOPBACK_EN = LOOPBACK & DEBUG`), and then it adds one internal channel.
- **`i_sync`** is an asynchronous external signal that the IP synchronises for the `XCOM_QRST_SYNC` command.

## U3. Data formats

- Serial header: bit 7 is used for synchronisation in places, bits `[6:5]` give the data length (`00` none, `01` 8 bit, `10` 16 bit,
  `11` 32 bit), bits `[3:0]` the memory id or board id. Then the data.
- `STATUS_REG` (as decoded by the driver's `print_status`): transmit state in bits `[1:0]` (IDLE, WVLD, WSYNC, WRDY), receive state
  in bits `[8:6]` (IDLE, HEADER, DATA, REQ, ACK), plus the ready flag, the board id and a receive data counter. `DEBUG_REG`
  exposes the command-decoder signals (`print_debug` in the driver lists them).

## U4. Memories, throughput and limits

- Up to `NCH` receive channels (default 2) and one transmit channel; the local memory written by `XCOM_WRITE_MEM` is read back
  through `MEM_REG`.
- The throughput is set by `CFG.tick` and the time clock. Commands are executed one at a time (`core_ready` tells the tProc when the
  IP can take a new one).

## U5. Python quick start

```python
x = soc.xcom_0                       # QICK_Xcom (needs a bitstream with this IP and the driver bound, see U6)
x.set_local_id(1)                    # this board's ID
x.send_word(0x1234, dst=2, reg=1)    # 32-bit value to register 1 of board 2
x.set_flag(dst=2); x.clear_flag(dst=2)
x.print_status(); x.print_debug()
```

Other driver methods: `send_byte`, `send_half_word`, `write_local_flag`, `auto_id`, `update_byte` and the generic
`run_cmd(cmd, dt1, dt2)`; `flag`, `dt1`, `dt2` read the received values. Configuration: `xcom_config()`, `tx_ddr_cfg()`,
`rx_ddr_cfg()` (U2). `x.regs` is the register model of the RDL, field by field (`x.regs.STATUS_REG.CMD_CNTR.read()`).

## U6. Using it in a block design

- **Peripheral interface:** `i_core_en/op/data1/data2` and `o_core_ready/data1/data2/valid/flag` connect to the tProcessor's
  peripheral port (core clock).
- **Control outputs:** `o_proc_start/stop`, `o_time_rst`, `o_time_update(+data)` (time clock) and `o_core_start/stop` (core clock) go
  to the processor.
- **Serial link:** differential pairs `i_xcom_clk_p/n`, `i_xcom_data_p/n` (`NCH` of each) and `o_xcom_clk_p/n`, `o_xcom_data_p/n`;
  the IP contains the differential buffers (`diff_in_nb` / `diff_out_nb`). Assign the pins and standards in the top constraints.
- **Clocks:** PS (`i_ps_clk`), core (`i_core_clk`) and time (`i_time_clk`), each with its reset, with the ordering of U1.
  `constraints/xcom.xdc` (RX clocks, RX input delays, DDR data crossing) and `xcom_late.xdc` (TX generated clocks and the
  crossings to and from the three clocks) cover the crossings.
- Debug probes `o_dbg_probe1..3` (32, 32 and 41 bits) for an ILA.
- **Driver binding:** `QICK_Xcom.bindto` lists `qick:ip:xcom:1.0` (this core), `QICK:QICK:xcom:1.0` (the packaged legacy IP, builds
  from December 2025 on) and `user.org:user:xcom_axil_slv:1.0`. The 2025 builds (`fnal:qick:xcom:1.0`, the VLNV the public driver
  binds) are not bound: an older RTL without the current `CFG` and DDR registers.

## U7. Gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Destination board out of range | `RuntimeError` from the driver | 4-bit IDs, below 16 |
| Sending before IDs are set | Commands go to the wrong board | `set_local_id` / `auto_id` first |
| Clock ordering `time > core > ps` violated | The crossing assumptions of `xcom_cdc` fail | Keep the ordering |
| Bitstream built before the 2026-09-22 fix | Any Python command repeats indefinitely (U2) | Rebuild with the fix (`AUTO_CLEAR_BIT0` + the edge detector in `xcom_cmd` + `xcom_cmd_hold`) |
| `LOOPBACK = 1` with `DEBUG = 0` | No loopback channel | Both are needed |

## U8. Validation status

- **Simulation**: the top-level bench (`tests/`) now drives the AXI side through an `axi4_lite_if` and has 3 tests: a reset test,
  a command sent from the core side, and `test02_axi_command_executes_once` (the repro for U2's fix). The blocks it is made of
  are tested separately under `cores/lib`: `xcom_cmd` (5 tests), `xcom_cmd_hold` (5), `xcom_txrx` (27), `xcom_link_rx` (4),
  `xcom_link_tx` (6), `xcom_qctrl` (5) and `xcom_cdc` (6). Lint clean.
- **Fixed and confirmed in simulation (2026-09-22)**: the Python command repeat of U2 (`AUTO_CLEAR_BIT0` + the edge detector in
  `xcom_cmd` + `xcom_cmd_hold`); one write of `CTRL_REG` now produces exactly one command. **Not run on a board.**
- **Hardware**: this fusesoc packaging has not been built into a bitstream or run on a board, and no `bd_*.tcl` under `Top/`
  instantiates it. The software driver comes from earlier firmwares. Two boards talking was exercised on the **legacy**
  XCOM bitstreams of 2026 (the ping-pong and the `QRST_SYNC` start); their numbers and the notebooks are kept
  outside this repository. They are the reference this packaging has to match, not a validation of it.
- Not verified: two boards talking and the time synchronisation **with this packaging**, timing at the target clocks.

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `i_ps_clk`, `i_ps_rstn`, `i_core_clk`, `i_core_rstn`, `i_time_clk`, `i_time_rstn` | in | clocks and resets |
| `i_core_en`, `i_core_op[4:0]`, `i_core_data1/2[31:0]` | in | tProc command |
| `o_core_ready`, `o_core_data1/2[31:0]`, `o_core_valid`, `o_core_flag` | out | to the tProc |
| `i_sync` | in | external synchronisation |
| `o_proc_start/stop`, `o_time_rst`, `o_time_update`, `o_time_update_data[31:0]` | out | time clock |
| `o_core_start`, `o_core_stop` | out | core clock |
| `o_xcom_id[3:0]` | out | board ID (for LEDs) |
| `i_xcom_clk_p/n[NCH-1:0]`, `i_xcom_data_p/n[NCH-1:0]`, `o_xcom_clk_p/n`, `o_xcom_data_p/n` | | serial link |
| `s_axi_*` | | AXI4-Lite slave (6-bit address, `i_ps_clk`) |
| `o_dbg_probe1/2[31:0]`, `o_dbg_probe3[40:0]` | out | debug |

## Registers

Byte address = 4 x index. Indices 6 to 15 are read-only.

| Index | Address | Register | Access | Description |
|---|---|---|---|---|
| 0 | 0x00 | `CTRL` | RW | bit 0 command strobe, bits `[5:1]` opcode |
| 1 | 0x04 | `CFG` | RW | link configuration (U2) |
| 2 | 0x08 | `AXI_DATA1` | RW | data 1 (destination board) |
| 3 | 0x0C | `AXI_DATA2` | RW | data 2 |
| 4 | 0x10 | `ADDR` | RW | address |
| 5 | 0x14 | `TX_RX_DDR` | RW | DDR link: TX/RX delays, TX clock boost, BIST (U2) |
| 6 | 0x18 | `BOARD_ID` | R | board ID |
| 7 | 0x1C | `FLAG` | R | flag |
| 8, 9 | 0x20, 0x24 | `DT1`, `DT2` | R | last received data |
| 10 | 0x28 | `MEM` | R | memory read-back |
| 11 | 0x2C | (reserved) | R | |
| 12, 13 | 0x30, 0x34 | `RX_DT`, `TX_DT` | R | debug data |
| 14 | 0x38 | `STATUS` | R | transmit / receive state |
| 15 | 0x3C | `DEBUG` | R | decoder signals; `[31:29]` 0 (legacy: the tick `[2:0]`) |

The fields are in `rdl/xcom_regmap.rdl`. The driver's attributes are `xcom_ctrl`, `xcom_cfg`, `axi_dt1`, `axi_dt2`, `axi_addr`,
`tx_rx_ddr`, `board_id`, `flag`, `dt1`, `dt2`, `mem`, `rx_dt`, `tx_dt`, `status`, `debug` (indices 0 to 10 and 12 to 15).

## Verification

Top-level bench `tests/tests.sv` + `xcom_tc00.sv` (3 tests, AXI side driven through `axi4_lite_if`), and the block benches
listed in U8. `make sim IP=xcom`.

Driver, off the board: `make driver-test IP=xcom` (`driver/tests/`: the register model of the RDL, and `QICK_Xcom` against a
fake register file: the map of the legacy driver pinned, the defaults written at creation, the bits of `xcom_config` /
`tx_ddr_cfg` / `rx_ddr_cfg` against the RDL fields, the order of a command, the decoding of `print_status` / `print_debug`).

## Files

```
cores/ip/xcom/
  README.md
  xcom.core                          # VLNV qick:ip:xcom:1.0.2
  hdl/xcom.sv                        # top: axil_slv (AUTO_CLEAR_BIT0) + xcom_cmd_hold + xcom_cdc + xcom_cmd + xcom_txrx +
                                      #      xcom_link_rx/tx + xcom_qctrl + diff buffers
  constraints/xcom.xdc, xcom_late.xdc, xcom_ooc.xdc
  tests/
  rdl/xcom_regmap.rdl                # register map (driver and docs only; the RTL decode is axil_slv)
  driver/xcom.py -> qick_lib/qick/drivers/xcom.py, driver/tests/
```

Blocks (cores in `cores/lib`): `utils/xcom_cmd`, `utils/xcom_cmd_hold`, `utils/xcom_txrx`, `utils/xcom_link_rx`, `utils/xcom_link_tx`, `utils/xcom_qctrl`,
`cdc/xcom_cdc`, `utils/diff_in_nb`, `utils/diff_out_nb`.

## Open items

- Board run of the driver with two boards, on this core and on a legacy bitstream.
- Board validation of the 2026-09-22 command-path fix (U2, U8).
- More assertions in the top-level bench (it still only checks the two things U8 lists); a two-board test.
- A debug Top project for it, as for the other IPs.
