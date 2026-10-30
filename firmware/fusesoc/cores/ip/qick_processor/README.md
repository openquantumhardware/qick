# QICK tProcessor v2 (qick_processor)

The **timed processor** of the QICK v2 firmwares: a small processor (one or two cores) that runs a program from an internal
program memory and, at times counted in clock cycles, sends pulse descriptors to signal generators, reads back readout
results, drives digital outputs and trigger pins, and talks to peripherals (`xcom`, custom peripherals A/B) through a
dedicated port each. The program is written with the QICK v2 assembler (`qick_lib/qick/asm_v2.py`), not in this repository's
RTL. This is the packaged-IP wrapper; the core itself is `tprocv2` / `qcore_cpu` in `rtl_lib`.

- Project: QICK, `qick:ip:qick_processor:1.0.0` (module `qick_processor`)
- **Legacy name and VLNV:** the deployed IP and the software call this block **`qick_processor`** too, but with vendor/library
  `Fermi:user` or `QICK:QICK` and **version `2.0`**, not `1.0`. The driver class `Axis_QICK_Proc` in
  `qick_lib/qick/drivers/tproc.py` has `bindto = ['Fermi:user:qick_processor:2.0', 'QICK:QICK:qick_processor:2.0']`; a block
  packaged from this core is `qick:ip:qick_processor:1.0`, which is **not bound** until the VLNV (including the version) is
  added.
- Hardware bring-up: none of this fusesoc version (see U8)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference. The instruction set is
documented with the assembler, not here.

---

# Part I -- Using the IP

## U1. What it does

```
 PS: AXI4-Lite --> TPROC_CTRL (one-shot pulses), TPROC_CFG, memory bulk/single access, CORE_CFG, READ_SEL, status/debug
 s0..s15_axis (64 bit, in) <---- readout results / peripherals   |   m0..m15_axis (160 bit, out) ----> generators
 trig_0..31_o -------------------------------------------------- trigger pins
 port_0..N_dt_o -------------------------------------------------- digital-output ports (through qick_vec2bit)
 qnet_*, qcom_*, qp1_*, qp2_* ------------------------------------ dedicated peripheral ports (xcom, custom peripherals)
 external: ext_flag_i, proc_start_i, proc_stop_i (level, synchronised and edge-detected inside), t_time_abs_o
```

Only the first `IN_PORT_QTY` / `OUT_TRIG_QTY` / `OUT_DPORT_QTY` / `OUT_WPORT_QTY` of the fixed `s*_axis` / `m*_axis` / `trig_*_o`
/ `port_*_dt_o` pins are wired to the core; the rest are tied off (unused input `tready` high, unused output `tvalid` low,
unused trigger pins 0) so Vivado's IP packager can still infer fixed bus interfaces from a flat, maximal pinout.

## U2. Rules that are not obvious

- **`TPROC_CTRL` is a one-shot register, unlike most other IPs in this repository.** Any nonzero write **self-clears to 0 one
  clock later**: treat every write as a pulse, not a level to hold. Bits: 0 `T_RST` (time reset+run), 1 `TIME_UPDT`, 2 `START`
  (core+time reset, run), 3 `STOP`, 4 `C_START` (core reset, run), 5 `C_STOP`, 6 `P_RST`, 7 `RUN`, 8 `P_PAUSE`, 9 `P_FREEZE`,
  10 `STEP` (core+time), 11 `C_STEP`, 12 `T_STEP`, 13 `AXI_FLAG_SET`, 14 `AXI_FLAG_CLR`. The driver writes one bit value per
  call (e.g. `start()` writes `tproc_ctrl = 4`); it does not need to clear it afterwards.
- **`TPROC_CFG` is a level register**, unlike `TPROC_CTRL`: bits `[6:0]` pass through to the memory-access controller
  (`qproc_mem_ctrl`: bit 0 `MEM_START`, bit 1 `MEM_OPERATION`, bits `[3:2]` `MEM_TYPE` 00 none/01 pmem/10 dmem/11 wmem, bit 4
  `MEM_SOURCE` 0 AXI/1 single, bits `[6:5]` `MEM_BANK`), bits `[11:9]` select the net/external command source, bit 10 also
  selects `proc_start_i` / `proc_stop_i` as the start source (see `start_src('external')`), bits 13/14 the AXI/internal flag
  select. It is *not* self-clearing: leave it at the value you want in effect.
- **Bulk memory access (PMEM/DMEM/WMEM) works only through DMA**, and only one memory/direction combination at a time via the
  `MEM_TYPE`/`MEM_OPERATION` bits of `TPROC_CFG`: the driver's `load_mem` / `read_mem` set `MEM_ADDR`, `MEM_LEN`, pack `TPROC_CFG`
  bits `[3:0]` to one of `{pmem: 7/5, dmem: 11/9, wmem: 15/13}` (write/read), run the DMA, then clear those bits. The DMA transfer
  width is 256 bits (8 x int32) regardless of the memory's real word width; the driver trims the unused columns (`width` 3 for
  pmem, 1 for dmem, 6 for wmem) unless `truncate=False`.
- **Single-word memory access** goes through `MEM_DT_I` (write) / `MEM_DT_O` (read) with `MEM_ADDR` and the same `TPROC_CFG`
  encoding, `MEM_SOURCE = 1`.
- **Read-back mux.** `TPROC_R_DT1` / `TPROC_R_DT2` do not have a fixed meaning: `READ_SEL` (bits `[3:0]`) chooses which internal
  source they mirror (see `qick_processor.sv`'s "AXI_REG TPROC_R_DT source selection"); set it before reading.
- **External start/stop pins are debounced in this wrapper, not in the core.** `proc_start_i` / `proc_stop_i` are levels,
  synchronised with `cdc_reg_sync` and edge-detected into one-shot pulses before reaching the core (mirrors `qproc_ctrl`'s own
  `PS_TPROC_CTRL` handling); they only take effect once `TPROC_CFG[10]` selects the external source.
- **`CORE_ID_REG` always reads 9** (a fixed core/version identifier, not `self['revision']`, which the software reads from
  Vivado's `COREREVISION` IP metadata instead).
- **The `QNET`/`QCOM`/`CUSTOM_PERIPH`/`IO_CTRL`/`CALL_DEPTH` parameters are inert in this RTL** (the stack depth is fixed at 8 in
  `qcore_cpu`'s `tpv2_stack` instance) but are still declared, because the driver's `_init_config` reads them unconditionally
  from the packaged IP's parameter metadata; dropping `CALL_DEPTH` would make the driver raise `KeyError` at load time.
- **`start_src('external')` needs `revision >= 23`** in the driver; it raises otherwise.

## U3. Data formats

- Program, data and weight memories: 8 x 32-bit words per DMA beat (256 bits), see U2.
- Output descriptors (`mN_axis`, 160 bit) match the generators' descriptor format (see e.g. `axis_signal_gen_v4`'s README).
- Input words (`sN_axis`, 64 bit): readout results / peripheral data.
- `t_time_abs_o` (48 bit): the processor's absolute time; `TIME_USR_REG` mirrors the current user time (absolute minus a
  reference) to the PS.

## U4. Memories, throughput and limits

- Program memory `2**PMEM_AW`, data memory `2**DMEM_AW`, weight memory `2**WMEM_AW` words (driver: `pmem_size`, `dmem_size`,
  `wmem_size`); `2**REG_AW` general-purpose data registers (`dreg_qty`).
- `IN_PORT_QTY` input streams, `OUT_TRIG_QTY` trigger pins, `OUT_DPORT_QTY` digital-output ports (`OUT_DPORT_DW` bits each),
  `OUT_WPORT_QTY` waveform (generator) output streams; `FIFO_DEPTH` sets the output-queue depth (`2**FIFO_DEPTH`).
- **Core speed, measured in simulation** (`qproc_core` tests `tc_instruction_cost_table` and the `tc_wport_wr_*` rate tests;
  cycles of `c_clk_i`, so the time is cycles / `c_clk_i`):

  | instruction | cycles |
  |---|---|
  | `NOP`, `REG_WR` (also a dependent chain), `TEST`, `TIME`, `DMEM_WR`, `FLAG`, `ARITH`, `DIV` (issue) | 1 |
  | `REG_WR` from `s_rand`, `REG_WR r_wave wmem`, `WMEM_WR` | 2 |
  | taken `JUMP`; a loaded value used by the next instruction | 3 |
  | `TEST` + conditional `JUMP`, not taken / taken | 4 / 6 |
  | consecutive wave-port writes (`WPORT_WR`) | 1 apart (one gap of 2 early on several ports) |
  | consecutive trigger writes (`TRIG`) | 2 apart |

  Two things follow. Straight-line (unrolled) code is what the core is fast at, while a loop iteration (`WAIT`, `TIME`,
  counter, `TEST`, taken `JUMP`) is about 15 cycles: 75 ns at 200 MHz whatever the requested pulse period. The pulse rate of
  an unrolled train is then limited downstream of the core (generator and dispatcher, about 10 ns per pulse in the QICKEmu
  configuration) and by the FIFOs: `2**FIFO_DEPTH` words per port hold the part of a train that the core pushes ahead of time.
  `firmware/notebooks/tproc_pulse_rate/` reproduces the train measurements (emulator and board).
- Two port writes used to be held 3 cycles apart (`stall_id_wp`, since fixed). The wave word of the instruction
  waiting in X2 is now held across a FIFO-full pause instead (`wmem_r_dt_hold` in `qcore_cpu.sv`), with the same regression test
  (`tc_pulse_train_fifo_full_pause_resume_keeps_wave_words`) and a set of pause stimuli with three different clocks
  (`qick_processor_pause_tests.sv`). Not yet checked in context (timing of a full design) or on the board. The IP revision stays 27 on purpose (same ISA; `asm_v2` refuses other revisions).

## U5. Python quick start

```python
tp = soc.qick_processor_0             # needs the VLNV fixed, see U6
tp.load_bin_program(binprog, None)    # normally QickProgramV2.load_program does this
tp.load_mem('wmem', weights)          # DMA, with readback check
tp.start_src('internal')
tp.start()                            # tproc_ctrl = 4 (one-shot)
tp.reset()                            # tproc_ctrl = 64
data = tp.read_mem('dmem', length=100, addr=0)
```

`Axis_QICK_Proc.__str__()` / `info()` print the compiled-in configuration (memory sizes, port counts, peripherals present,
debug level, clocks).

## U6. Using it in a block design

- **Naming: keep the legacy VLNV including its version.** The software matches this driver by `bindto`
  (`Fermi:user:qick_processor:2.0` / `QICK:QICK:qick_processor:2.0`); a packaged `qick:ip:qick_processor:1.0` block is not
  recognised until the VLNV is added (or the version bumped to match). Unlike `axis_tprocv1`, the *type name* itself
  (`qick_processor`) already matches what `qick_asm.py` expects (`{'axis_tproc64x32_x8':'v1', 'qick_processor':'v2'}`); only the
  vendor/library/version differ.
- **Clocks:** `t_clk_i` (time base), `c_clk_i` (core), `ps_clk_i` (AXI4-Lite), each with its own active-low reset.
- **Streams:** `s0..s15_axis` (64 bit) from readouts/peripherals, `m0..m15_axis` (160 bit) to generators; only
  `IN_PORT_QTY` / `OUT_WPORT_QTY` are actually wired, the rest tie off.
- **Digital I/O:** `trig_0..31_o` (only the first `OUT_TRIG_QTY`), `port_0..N_dt_o` (only the first `OUT_DPORT_QTY`, each
  `OUT_DPORT_DW` bits) -- typically to `qick_vec2bit` for individual pins, the v2 analogue of v1's `axis_set_reg` chain.
- **Peripheral ports:** `qnet_*` (xcom-style network op/data + ready/valid/flag), `qcom_*` (a simpler op/data port), `qp1_*` /
  `qp2_*` (4-word custom peripheral ports A/B). Present in the pinout regardless of `QNET`/`QCOM`/`CUSTOM_PERIPH` (U2).
- **External control:** `ext_flag_i`, `proc_start_i`, `proc_stop_i` (levels; U2), `t_time_abs_o` / `pulse_sync_o` outputs.
- `s_axi` -> the PS interconnect (`ps_clk_i`).

## U7. Gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Package `qick:ip:qick_processor:1.0` without fixing `bindto`/version | The driver does not bind | Match the VLNV (U6) |
| Holding `TPROC_CTRL` high like a level register | Only the first cycle matters; it self-clears | Treat every write as a pulse |
| Reading `TPROC_R_DT1/2` without setting `READ_SEL` first | Stale or wrong source | Set `READ_SEL`, then read |
| Single access during a bulk DMA transfer, or vice versa | Undefined per `TPROC_CFG`'s shared encoding | Finish one operation before starting the other |
| `start_src('external')` on an old core | `RuntimeError` (needs revision >= 23) | Check `tp['revision']` |
| Dropping `CALL_DEPTH` (or the other inert parameters) when repackaging | Driver `KeyError` at load | Keep them declared |

## U8. Validation status

- **Simulation**: 42 SVUnit tests (38 + the 4 pause stimuli of `qick_processor_pause_tests.sv`). Seven check reset state (`TPROC_CTRL` 0, `CORE_ID` 9), unused input ports still drive `tready` high, the
  unused wave-output port tied to not-valid, unused trigger pins tied to 0, an AXI register round trip, `START` reaching `RUN`, and
  the external `proc_start_i` pin. Five **run programs** assembled with the repo's assembler (`tests/data/gen_prog.py`) and loaded the way the
  driver does (AXI registers + DMA stream): a constant on a data port, a counted loop with a conditional jump, `PA`/`PB` reaching the `qp1`/`qp2`
  pins with op code and four operands, and `CLEAR qpa` / `CLEAR qpb` clearing only their own new-data flag. One more checks that the two flags are set
  independently. Three more run a PA program built with the `QickProgramV2` macros against two `qick_periph_loopback` peripherals on `qp1` / `qp2`
  (answer through `s_core_r1/r2`, a conditional jump on the QP1 flag in both directions, `CLEAR qpa`, and a PA issued while the peripheral is busy being dropped), and two
  check the single-word memory access sequence. Three more run programs of the old `qick_testbench`: the 16 data registers (each takes its
  own value and then `s_zero`) and `PA`/`PB` with `s6`/`s7` as a source operand, in the data section (R1, R2) and in the address section (R3, R4):
  openquantumhardware/qick#359, **which hung the core until `qcore_ctrl_hazard` 1.0.1** (the instruction waited for its own peripheral write;
  confirmed on the RFSoC4x2 on 2026-10-15: bitstream `B3294A9` hangs both programs, `C8D037C` with 1.0.1 completes them).
  Twelve (`tc_nb_*`) run the programs of the hardware notebook
  (`tests/data/periph_programs.py`, lowered for the board's 4096-word program memory, jumps through `s15`) against the two loopbacks: PA, PB and both back
  to back with 32-bit wrap and op 31, independent `CLEAR` in both orders (they fail against the RTL before the QP2 clear fix), `-if(F)` on `flg_qpa` both ways, six
  commands back to back on each port (PA: 2 taken, 4 dropped with DELAY 3; PB: 1 taken, 5 dropped with DELAY 5), `ext_flag_i` level and a rising edge ending a polling loop. Four more cover the QP2 flag of revision 29: `-if(F)` on `flg_qpb` both ways and the two
  flag sources not crossing (QP1 set / QP2 clear and the reverse).
  Dual-core mode, `qnet`/`qcom` and the full set of instructions are not covered.
- **Hardware: validated on an RFSoC4x2 (2026-09-24)** with a debug bench, a one-channel reduction of `4x2/tpv2_std` built only from fusesoc IPs, driven by standard `QickSoc` + `AveragerProgramV2` programs. All 8 steps pass: QickSoc discovery,
  program/data/wave memory DMA round trip, timed pulses + readout triggers, gain and phase sweeps in tProc loops
  (0.02 % linearity residual, phase slope 1.0000), `read_input` of the average buffer bit-exact against its DMA, the
  MR-buffer trigger, and a real-time conditional pulse (`read_and_jump` on the average-buffer input) played exactly
  below its threshold. The bring-up fixed three packaging/infrastructure bugs: no clock interfaces and no DMA TREADY in
  the package, `COREREVISION` 1 instead of 27 (now the `.core` patch, `1.0.27`), and `bram_tdp` not synthesizable as a
  true dual-port RAM (now XPM).
- **QP1 / QP2 and `ext_flag_i` on hardware (RFSoC4x2, 2026-10-13):** the same Top with `qick_periph_loopback` on both ports and `ext_flag_i` behind a GPIO, the validation
  notebook: all steps pass (PA, PB, both, independent `CLEAR`, `-if(F)` on `flg_qpa` and, on the revision 29 bitstream, `flg_qpb`,
  a command while busy, `ext_flag_i` level and edge, soak). Summary only was kept (see the Top README).
- Not verified: `qnet`/`qcom` end to end on hardware (`qp1`/`qp2` are verified, above), dual-core mode,
  external start/stop pins on hardware.

## U9. Writing a custom peripheral (QP1 / QP2)

`PA` / `PB` send a command to the block on `QPeriphA` (`qp1_*`) / `QPeriphB` (`qp2_*`); it answers with two words and a flag.
[`qick_periph_loopback`](../qick_periph_loopback/README.md) is the reference: a complete peripheral with its packaging and tests,
run with this core on the RFSoC4x2. Start from a copy of it.

- **Clock:** the ports are on `c_clk_i`. A peripheral that runs on another clock crosses the command and the answer itself
  (the `qick:cdc:*` cores).
- **Command:** `qpN_en_o` is high for one clock per `PA` / `PB`, with `qpN_op_o` (5 bit) and `qpN_a..d_dt_o` (the four 32-bit
  registers of the instruction) valid in that clock only.
- **Ready:** `qpN_rdy_i` only reaches `s_status` (bits 8 / 10); the tProc does not wait for it. A command that arrives while the
  peripheral is busy is the peripheral's to handle (the loopback drops it and counts it).
- **Answer:** a one-clock `qpN_vld_i` pulse with `qpN_dt1_i` / `qpN_dt2_i`. The tProc latches both words and sets `QPA_DT_NEW` /
  `QPB_DT_NEW` (`s_status` bits 9 / 11) until `CLEAR qpa` / `CLEAR qpb`.
- **Flag:** `qp1_flag_i`, and `qp2_flag_i` from revision 29, is a level that the conditional jumps test (`-if(F)` / `-if(NF)`)
  once the flag source selects it.
- **Software:** `QickProgramV2.periph_write('a', op, a, b, c, d)`, `periph_wait`, `periph_read`, `periph_config(flag='a')` and
  `periph_clear` (`qick_lib/qick/asm_v2.py`); the instructions are in sections 5.8.6 to 5.8.8 of the tProc v2 TRM.
- **Registers:** a peripheral that needs registers from Python adds an `axil_slv` (`qick:axi:axil_slv`), as `axis_constant_iq`
  does, and a driver class ([IP_INTEGRATION.md](../../../../docs/user/IP_INTEGRATION.md)).
- **Packaging:** a `qick:ip` core ([NEW_CORE.md](../../../../docs/developer/NEW_CORE.md)) whose `<ip>.bus_interfaces.yaml` maps its
  ports to the slave side of `QICK:QICK:qick_peripheral:1.0` (bus definition in `firmware/ip/qick_interfaces`) and whose
  `<ip>.clock_domains.yaml` puts that interface on the core clock. The block design then connects `QPeriphA` to it as one
  interface. `QPeriphB` of a revision before 29 has no flag pin: leave the peripheral's flag open there.

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `s_axi_*` | | AXI4-Lite slave (`ps_clk_i`) |
| `t_clk_i`, `t_resetn`, `c_clk_i`, `c_resetn`, `ps_clk_i`, `ps_resetn` | in | time, core and AXI clocks/resets |
| `ext_flag_i`, `proc_start_i`, `proc_stop_i` | in | external control (levels, U2) |
| `time_rst_i`, `time_init_i`, `time_updt_i`, `time_dt_i[31:0]` | in | external time control |
| `t_time_abs_o[47:0]`, `pulse_sync_o` | out | absolute time, sync pulse |
| `core_start_i`, `core_stop_i` | in | external core control |
| `qnet_*`, `qcom_*`, `qp1_*`, `qp2_*` | | peripheral ports (op/data/ready/valid/flag, widths vary) |
| `s0..s15_axis` (`tdata[63:0]`) | in | data inputs; only the first `IN_PORT_QTY` wired |
| `m0..m15_axis` (`tdata[159:0]`) | out | descriptors; only the first `OUT_WPORT_QTY` wired |
| `trig_0..31_o` | out | trigger pins; only the first `OUT_TRIG_QTY` wired |
| `port_0..N_dt_o` (`OUT_DPORT_DW` bits) | out | digital-output ports; only the first `OUT_DPORT_QTY` wired |

## Registers

The driver takes the word index of each register from this map: `Axis_QICK_Proc` reads `qick_processor_regmap_pkg` (generated from `rdl/qick_processor_regmap.rdl`, installed in `qick_lib/qick/rdl_pkgs/` by `make driver IP=qick_processor`; `make driver-check` fails if the committed copy no longer matches the RDL) and keeps the attribute names notebooks and `QickSoc` use (`tp.tproc_cfg`, `tp.axi_w_dt1`, ...). `tp.regs` is the register model for field access (`tp.regs.TPROC_CFG_REG.CFG.read()`, `tp.regs.CORE_ID_REG.read()`). `CORE_ID_REG` has no attribute: in legacy firmware word 9 is a plain read/write register. The map of the legacy axi slave also has 16 words, and the driver has used the same indexes on legacy and ported firmware.

| Addr | Register | Access | Description |
|---|---|---|---|
| 0x00 | `TPROC_CTRL_REG` | RW (self-clears) | one-shot control pulses (U2) |
| 0x04 | `TPROC_CFG_REG` | RW | configuration (U2) |
| 0x08 | `MEM_ADDR_REG` | RW | bulk memory access start address |
| 0x0C | `MEM_LEN_REG` | RW | bulk memory access length (samples) |
| 0x10 | `MEM_DT_I_REG` | RW | single-word memory write data |
| 0x14 | `TPROC_W_DT1_REG` | RW | general-purpose write data 1 (time-update offset, etc.) |
| 0x18 | `TPROC_W_DT2_REG` | RW | general-purpose write data 2 |
| 0x1C | `CORE_CFG_REG` | RW | per-core LFSR config, bits `[1:0]` core0, `[3:2]` core1 |
| 0x20 | `READ_SEL_REG` | RW | `TPROC_R_DT1/2` source select |
| 0x24 | `CORE_ID_REG` | RO | fixed core/version id, always 9 |
| 0x28 | `MEM_DT_O_REG` | RO | single-word memory read data |
| 0x2C | `TPROC_R_DT1_REG` | RO | read-back word 1 (source: `READ_SEL`) |
| 0x30 | `TPROC_R_DT2_REG` | RO | read-back word 2 (source: `READ_SEL`) |
| 0x34 | `TIME_USR_REG` | RO | current user time |
| 0x38 | `TPROC_STATUS_REG` | RO | status snapshot (live only if `DEBUG >= 1`) |
| 0x3C | `TPROC_DEBUG_REG` | RO | debug bus, source `READ_SEL[1:0]` (live only if `DEBUG >= 1`) |

Source: `rdl/qick_processor_regmap.rdl`.

## Verification

`tests/qick_processor_tests.sv` (and `tests/qick_processor_prog_tests.sv` for the ones that run programs): `tc_reset_idle`, `tc_unused_input_ports_tie_ready_high`, `tc_unused_wave_port_tied_off`,
`tc_unused_trigger_pins_tied_off`, `tc_axi_register_round_trip`, `tc_axi_start_reaches_run`,
`tc_external_proc_start_pin_reaches_run`, and, running assembled programs: `tc_prog_dport_write`, `tc_prog_counted_loop`,
`tc_prog_pa_pb_reach_the_pins`, `tc_qp_new_data_flags_set_independently`, `tc_prog_clear_qpb_clears_only_qpb`,
`tc_prog_clear_qpa_clears_only_qpa`, `tc_prog_pa_pb_with_s6_s7_in_the_data_section_does_not_hang`,
`tc_prog_pa_pb_with_s6_s7_in_the_address_section_does_not_hang`, `tc_prog_all_data_registers_take_a_value_and_zero`. `make sim IP=qick_processor`.

### What the old `qick_testbench` covered, and where it is now

`qick_testbench` (a Vivado simulation project, `firmware/testbench/qick_testbench`) was removed: it was driven by hand, loaded programs exported from
the notebooks as `.mem` files and had no checks, only waveforms. Its nine scenarios:

| Scenario | Where it is covered now |
|---|---|
| `test_tproc_basic`: all data registers | `tc_prog_all_data_registers_take_a_value_and_zero` (this core) |
| `test_tproc_basic`: due time with reference time `2**M` and `time_abs` `2**N`, M, N up to 47 | `qproc_dispatcher` (`tc_*_across_an_upper_bit`, `tc_wave_waits_for_time_across_the_top_bit`), `qproc_ctrl` (`tc_time_ref_*`, `tc_time_usr_*`), `qproc_time_ctrl` (`tc_free_run_carries_across_bit_32`) |
| `test_issue359` (PA/PB with `s6`/`s7`) | `tc_prog_pa_pb_with_s6_s7_*` (this core), `qcore_ctrl_hazard` (`tc_*_itself_does_not_stall*`) |
| `test_issue53` / `test_fast_short_pulses` (wave words that the generator FIFO cannot take) | `qproc_dispatcher` `tc_wave_dispatch_waits_for_tready`, `tc_pulse_train_fifo_full_pause_resume_keeps_wave_words`, `qick_processor_pause_tests.sv` |
| `test_issue361` (average/decimated buffer, `tready` toggling) | not a processor scenario: `axis_avg_buffer` (`test_buf_odd_read_with_backpressure`); the exact program of the issue is **not** replayed |
| `test_basic_pulses`, `test_many_envelopes`, `test_randomized_benchmarking`, `test_qubit_emulator` | **not covered in simulation**: they need the tProc, `axis_signal_gen_v6` and the readout together (and the qubit emulator model). The tProc side of them (pulse trains, loops, calls) is what the tests above exercise; the whole chain is validated on the board (debug bench, U8) |

## Files

```
cores/ip/qick_processor/
  README.md
  qick_processor.core                # VLNV qick:ip:qick_processor:1.0.0
  hdl/qick_processor.sv              # flat-pinout wrapper + axi4_lite_if bridge around the tprocv2/qcore_cpu core
  rdl/qick_processor_regmap.rdl
  constraints/qick_processor.xdc, qick_processor_ooc.xdc
  driver/qick_processor.py           # the PYNQ driver is Axis_QICK_Proc in qick_lib/qick/drivers/tproc.py
  tests/                             # SVUnit bench; tests/data/gen_prog.py assembles the programs the tests run
  issues/                            # open issues (README.md is the index)
```

## Open items

- The VLNV / `bindto` version mismatch of U6 (a decision, same kind of issue as `axis_tprocv1`'s name mismatch).
- Driver: follow the `qick_time_tagger` flow (per-IP driver, `qick:ip:` VLNV, board validation), keeping the assembler-facing
  methods of `Axis_QICK_Proc`. The register map already comes from the RDL package; RFSoC4x2 2026-10-27 (bitstream `qick_processor_dbg_rev29`, `.bit` md5 `cc66639d1b40679afaa64740e8d82f39`, `.hwh` md5 `41e6c22f893b3b9fcaa7c0c6fa8f2edb`, the revision 29 build of 2026-10-13): `qick_processor_periph_hw_validation.ipynb` ALL PASS (steps 0 to 8, 5b included, board clone at `7450f1ba`), same counts as the run with the hand-written map; `qick_processor_hw_validation.ipynb` ALL PASS (steps 0 to 7 and 9 to 13, board clone after pulling `b92a416ed`). After the register code became a mixin shared with `axis_tprocv1` (`214b519c1`), the driver-check cell and the peripheral notebook (ALL PASS, steps 0 to 8) were run again on the same bitstream file, board clone at `214b519c`; the regression notebook was re-run later on the shared module (`qick/rdl_regs.py`, board clone at `fdd4625d`): ALL PASS, with step 5 (phase sweep: slope 0.9999 deg/deg, |IQ| spread 0.33 %) run separately because it was not in the printed summary. Not run with this change: the ZCU216.
- Coverage of dual-core mode, `qnet`/`qcom` and the rest of the instruction set by program-running tests (the bench of `tests/` can now do it); the QP
  ports on hardware (`issues/04`).
