# AXIS tProcessor v1 (axis_tprocv1)

The **timed processor** of the QICK v1 firmwares: a small processor that runs a program from a program memory and, at times
counted in clock cycles, sends **pulse descriptors** to the signal generators, triggers to the readouts and values to digital
outputs, and can read the results that come back. It has a data memory, four input streams and eight output streams. The
program is written with the QICK assembler (`qick_lib/qick/asm_v1.py`), not in this repository's RTL.

- Project: QICK, `qick:ip:axis_tprocv1:1.0.1` (module `axis_tprocv1`; parameters `PMEM_N = 16`, `DMEM_N = 10`)
- **Legacy name:** the deployed IP and the software call this block **`axis_tproc64x32_x8`** (64-bit program words, 32-bit data,
  8 outputs). The class `AxisTProc64x32_x8` in `qick_lib/qick/drivers/tproc.py` is its driver. The core also has a register-model
  skeleton, `Axis_tprocv1`, in `cores/ip/axis_tprocv1/driver/axis_tprocv1.py` (not a PYNQ class: `configure(read_cb, write_cb)`)
- Hardware bring-up: none of this fusesoc version (see U8)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference. The instruction set is
documented with the assembler, not here.

---

# Part I -- Using the IP

## U1. What it does

```
 PS: AXI4-Lite ------> registers (start, DMEM DMA control) + single access to the data memory (upper address window)
 program memory (external BRAM, 64-bit words) <--pmem_addr / pmem_do--+
                                                                       v
                              tProcessor core (aclk) --- data memory (2^DMEM_N x 32 bit, dual-port) ---- DMA: s0_axis / m0_axis
                                    |   inputs : s1..s4_axis  (64 bit)      <- readout results / peripherals
                                    |   outputs: m1..m8_axis  (160 bit)     -> generators, triggers, digital pins (axis_set_reg)
                                 start input (optional external start)
```

The program memory is **not inside the IP**: the core reads it through `pmem_addr` / `pmem_do`, a 64-bit-wide BRAM (normally an
AXI BRAM controller that the PS also writes). Program and data memory are loaded by the PS.

## U2. Rules that are not obvious

- **Start.** `START_SRC_REG` selects the source: 0 internal (`START_REG`), 1 external (the `start` input). In both cases the
  start triggers on a **rising edge**: a low level arms it (the processor is in its "init" or "end" state) and a high level fires
  it. The driver's `start()` writes `START_REG = 0` then `1`; `start_src()` writes `START_REG = 0` before changing the source, so
  a change of source cannot start the processor. Starting has no effect if the processor is not in the init or end state.
- **Stopping is done by rewriting the program.** There is no stop register: `reset()` fills the program memory with the "end"
  instruction (writes the high half of every 64-bit word) so the processor runs into it; it takes about 1 ms. The driver caches
  the last program (`binprog`) so `reload_program()` can rewrite it afterwards.
- **Two ways to reach the data memory.**
  1. **Single access from AXI**: the register file lives in the lowest 256 bytes of the AXI address space; the data memory is the
     window above it. The word address is `(byte_address - 256) / 4`, which the driver expresses as `array[addr + NREG]` with
     `NREG = 64`. Writes are always full 32-bit words (no byte strobes).
  2. **DMA**: `MEM_MODE_REG` (0 = read memory to `m0_axis`, 1 = write from `s0_axis`), `MEM_ADDR_REG`, `MEM_LEN_REG`, then
     `MEM_START_REG = 1`. The driver's `load_dmem` / `read_dmem` do this and set `MEM_START_REG` back to 0.
  An arbiter keeps the memory coherent.
- **A single access while a DMA transfer is running returns `SLVERR`** (2'b10 on read and write responses) instead of blocking
  the bus. Do not use `single_read` / `single_write` while `MEM_START_REG = 1`.
- **Memory sizes.** Data memory: `2**DMEM_N` words of 32 bits (1024 by default; the driver stores `dmem_size`). Program memory: the
  driver measures it from the mapped BRAM (`pmem_size = mmio.length // 8`); `PMEM_N` is the depth of the core's address in 64-bit
  words, and the address port is a byte address (`pmem_addr` has its low 3 bits at zero), so the core can address up to
  `2**(PMEM_N-3)` program words (8192 for `PMEM_N = 16`) — derived from the RTL, check it against the BRAM you connect.
- **Streams.** `s1..s4_axis` carry 64-bit input words; `m1..m8_axis` carry 160-bit output words (the generators' descriptors
  are 160 bits wide). Channel numbering used by the software: output `mN_axis` is channel `N - 1`, input `sN_axis` is channel `N - 1`
  (`port2ch`), because port 0 belongs to the data-memory DMA. An output wired to an `axis_set_reg` becomes digital pins.
- **Timing clock.** `aclk` is the processor's clock and the time base of the program (`f_time` in the QICK config); the AXI side
  and the data-memory port A run on `s_axi_aclk`. Two clock domains, so the memory port B and port A are on different clocks.

## U3. Data formats

- Program: 64-bit words written by `load_bin_program`, which reshapes the assembler's output into 32-bit halves for the mapped
  memory. Data memory: 32-bit words. Output: 160-bit descriptors whose layout depends on the block that receives them.
- Registers: `START_SRC_REG`, `START_REG`, `MEM_MODE_REG`, `MEM_START_REG` (bit 0 each), `MEM_ADDR_REG`, `MEM_LEN_REG`
  (32 bits); two reserved registers.

## U4. Memories, throughput and limits

- Data memory `2**DMEM_N` x 32 bit; program memory external.
- One instruction per `aclk` cycle is the design intent of the timed processor; the achievable pulse rate is set by the program
  and the receiving blocks' FIFOs. (Not measured here.)

## U5. Python quick start

```python
tp = soc.axis_tproc64x32_x8_0          # the name the software expects (see U6)
tp.load_bin_program(prog_binary, None) # normally QickProgram.load_program does this
tp.start_src("internal")
tp.start()                             # START_REG 0 -> 1
tp.reset()                             # ~1 ms: fills the program memory with "end"
tp.single_write(addr=5, data=123); tp.single_read(5)        # one data-memory word over AXI
tp.load_dmem(np.arange(100, dtype=np.int32), addr=0)         # DMA write
data = tp.read_dmem(addr=0, length=100)                      # DMA read
```

## U6. Using it in a block design

- **Naming: keep the legacy IP name.** The software identifies the processor by the *type name* `axis_tproc64x32_x8`
  (`asm_v1.py`, `qick_asm.py`, the generator and readout drivers' connection tracing, and `qick.py`, which expects an instance
  called `axis_tproc64x32_x8_0`) and binds the driver by `bindto`, which lists `user.org:user:axis_tproc64x32_x8:1.0` and
  `QICK:QICK:axis_tproc64x32_x8:1.0`. A block packaged from this core is `qick:ip:axis_tprocv1:1.0`, which none of that finds. Either
  package it under the old name (see the VLNV / bindto note in `firmware/docs/developer/DRIVER.md`) or change those places. Not done yet.
- `s_axi` -> the PS interconnect; `pmem_addr` / `pmem_do` -> the program-memory BRAM; `s0_axis` / `m0_axis` -> an AXI DMA for the
  data memory; `s1..s4_axis` <- the readout / peripheral outputs; `m1..m8_axis` -> generators, `axis_set_reg` blocks and buffers'
  triggers.
- `aclk` = the processor clock; `s_axi_aclk` = the PS clock (asynchronous). `s0_axis_aclk`, `m0_axis_aclk` and their resets are
  interface-only (not connected inside).
- `axis_tprocv1.clock_domains.yaml` tells the packager which clock/reset belongs to which stream interface.
- Parameters: `PMEM_N`, `DMEM_N`.

## U7. Gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Package name `axis_tprocv1` | The software does not recognise the processor or bind its driver | Keep `axis_tproc64x32_x8` (U6) |
| `single_read` / `single_write` during a DMA | `SLVERR` | Wait for `MEM_START_REG = 0` |
| Trying to stop with a register | There is none | `reset()` (about 1 ms) |
| Changing the start source while `START_REG = 1` | Could start the processor | `start_src()` clears `START_REG` first |
| Assuming the program memory is in the IP | It is external | Connect a BRAM to `pmem_*` |
| Writing a byte of a data-memory word | Not supported (no strobes) | Write full words |

## U8. Validation status

- **Simulation**: 10 SVUnit tests on the AXI side and the data memory: register reset values, register round trip, single
  write/read of the data memory, several distinct addresses, the boundary address, AXIS write then single read, single write
  then AXIS read, AXIS write then AXIS read, `SLVERR` while a transfer is running, and `OKAY` when idle. **The instruction
  execution of the core is not covered by this bench.**
- **Hardware**: this fusesoc packaging has not been built into a bitstream or run on a board. The tProc v1 standard firmwares use
  the legacy IP (`axis_tproc64x32_x8`); the datapath here is a port of it.
- Not verified: program execution against the legacy IP, the timing of the outputs, `PMEM_N` versus the real program memory.

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `s_axi_*` (32-bit address), `s_axi_aclk`, `s_axi_aresetn` | | registers and data-memory window |
| `s0_axis_*` | in | data-memory write stream (32-bit; clock/reset interface-only) |
| `m0_axis_*` | out | data-memory read stream (32-bit, with `tlast`) |
| `aclk`, `aresetn` | in | processor clock and reset |
| `start` | in | external start |
| `pmem_addr[PMEM_N-1:0]`, `pmem_do[63:0]` | | program memory (byte address, low 3 bits zero) |
| `s1..s4_axis` (`tdata[63:0]`, `tvalid`, `tready`) | in | inputs |
| `m1..m8_axis` (`tdata[159:0]`, `tvalid`, `tready`) | out | outputs |

## Registers

The driver class `AxisTProc64x32_x8` keeps a hand-written dictionary of this map, with the attribute names the software uses (`tp.start_reg`, `tp.mem_len_reg`, ...).. `tp.regs` is the register model for field access. `RESERVED0/1` (words 6, 7) have no attribute. The data memory above `NREG` is a window of the AXI slave, not a register: it stays `array[addr + NREG]`. The indexes are the ones the driver has always used on the legacy firmware (`QICK:QICK:axis_tproc64x32_x8:1.0`).

| Addr | Register | Field | Description |
|---|---|---|---|
| 0x00 | `START_SRC_REG` | bit 0 | 0 internal start, 1 external start |
| 0x04 | `START_REG` | bit 0 | internal start (0 init, 1 start), rising edge |
| 0x08 | `MEM_MODE_REG` | bit 0 | 0 AXIS read (memory to `m0_axis`), 1 AXIS write (`s0_axis` to memory) |
| 0x0C | `MEM_START_REG` | bit 0 | 0 stop / single access allowed, 1 execute the AXIS transfer |
| 0x10 | `MEM_ADDR_REG` | 32 bit | starting sample address of the transfer |
| 0x14 | `MEM_LEN_REG` | 32 bit | number of samples |
| 0x18, 0x1C | `RESERVED0/1` | | |

The register region is the first 256 bytes; the data memory starts at byte 256. Source: `rdl/axis_tprocv1_regmap.rdl`.

## Verification

`tests/axis_tprocv1_tests.sv`: `tc00_register_reset`, `tc01_register_roundtrip`, `tc02_dmem_single_write_read`,
`tc03_dmem_single_multi`, `tc04_dmem_boundary`, `tc05_axis_write_then_single_read`, `tc06_single_write_then_axis_read`,
`tc07_axis_write_then_axis_read`, `tc08_slverr_when_busy`, `tc09_okay_when_idle`. `make sim IP=axis_tprocv1`.

## Files

```
cores/ip/axis_tprocv1/
  README.md
  axis_tprocv1.core                  # VLNV qick:ip:axis_tprocv1:1.0.1
  axis_tprocv1.clock_domains.yaml    # clock/reset per AXIS interface, read by the packager
  hdl/axis_tprocv1.sv                # top; the AXI4-Lite slave is the library core qick:axi:axi_slv_tprocv1
  rdl/axis_tprocv1_regmap.rdl
  constraints/axis_tprocv1.xdc, axis_tprocv1_ooc.xdc
  driver/axis_tprocv1.py             # register-model skeleton (the PYNQ driver is AxisTProc64x32_x8 in tproc.py)
  tests/
```

## Open items

- The IP name / VLNV / `bindto` question of U6 (a decision, and the same for the software's type-name checks).
- Driver: follow the `qick_time_tagger` flow (per-IP driver, `qick:ip:` VLNV, board validation), keeping the assembler-facing
  methods of `AxisTProc64x32_x8`.
- A test that runs a small program through the core.
