# tProcV1 — Verification & Program Generation Guide

Verification environment for the QICK tProcessor V1 (`tprocv1`): SVUnit test
suite, instruction encoders, Python assembler, and file-based program loading.

## Table of Contents
1. [Quick Start](#quick-start)
2. [Instruction Encoding](#instruction-encoding)
3. [Operand to Datapath Mapping](#operand-to-datapath-mapping)
4. [Timing & Latency Notes](#timing--latency-notes)
5. [Python Assembler](#python-assembler)
6. [Loading Programs from Files](#loading-programs-from-files)
7. [FuseSoC .core Setup](#fusesoc-core-setup)
8. [Writing Robust Tests](#writing-robust-tests)
9. [Running the Suite](#running-the-suite)

---

## Quick Start

```bash
# 1. Generate a program
python3 tproc_asm.py --pmem tests/data/pmem.hex --dmem tests/data/dmem.hex --pad 32

# 2. Run the full test suite (loads pmem.hex/dmem.hex in test17)
fusesoc --cores-root cores --cores-root common \
        --cores-root generators run --target test --tool xsim tprocv1

# 3. Inspect results
cat build/qick_processors_tprocv1_1.0.0/test-xsim/dmem_out.hex
```

---

## Instruction Encoding

All instructions are **64-bit words**. Field layout:

### I-Type (immediate)
```
[63:56] opcode | [55:53] page | [52:50] ch | [49:46] oper |
[45:41] rd     | [40:36] rs1  | [35:31] rs2 | [30:0]  imm
```

### J-Type (jump)
```
[63:56] opcode | [55:53] page | [52:50] 000 | [49:46] oper |
[45:41] rd     | [40:36] rs1  | [35:31] rs2 | [30:16] 0 | [15:0] addr
```

### R-Type (register)
```
[63:56] opcode | [55:53] page | [52:50] ch  | [49:46] oper |
[45:41] rd     | [40:36] rs1  | [35:31] rs2 | [30:26] rs3 | [25:21] rs4 |
[20:16] rs5    | [15:11] rs6  | [10:6]  rs7 | [5:0]   0
```

### Opcodes
| Type | Mnemonic | Opcode |
|------|----------|--------|
| I | pushi | 0x10 |
| I | popi  | 0x11 |
| I | mathi | 0x12 |
| I | seti  | 0x13 |
| I | synci | 0x14 |
| I | waiti | 0x15 |
| I | bitwi | 0x16 |
| I | memri | 0x17 |
| I | memwi | 0x18 |
| I | regwi | 0x19 |
| I | setbi | 0x1A |
| J | loopnz| 0x30 |
| J | condj | 0x31 |
| J | end   | 0x3F |
| R | math  | 0x50 |
| R | set   | 0x51 |
| R | sync  | 0x52 |
| R | read  | 0x53 |
| R | wait  | 0x54 |
| R | bitw  | 0x55 |
| R | memr  | 0x56 |
| R | memw  | 0x57 |
| R | setb  | 0x58 |

### Operation field (oper, 4 bits)
| Arithmetic | Code | Bitwise | Code | Condition (condj) | Code |
|------------|------|---------|------|-------------------|------|
| ADD | 0b1000 | AND | 0b0000 | GT | 0b0000 |
| SUB | 0b1001 | OR  | 0b0001 | GE | 0b0001 |
| MUL | 0b1010 | XOR | 0b0010 | LT | 0b0010 |
|     |        | NOT | 0b0011 | LE | 0b0011 |
|     |        | LSH | 0b0100 | EQ | 0b0100 |
|     |        | RSH | 0b0101 | NE | 0b0101 |

---

## Operand to Datapath Mapping

**This is the most important table for writing correct programs.**

| Field | Bits    | Regfile port    | Feeds                                          |
|-------|---------|-----------------|------------------------------------------------|
| `rd`  | [45:41] | addr7 (write)   | Write-back destination register                |
| `rs1` | [40:36] | addr0 -> dout0  | alu_a, dmem_addr, comparator a, stack din      |
| `rs2` | [35:31] | addr1 -> dout1  | alu_b, dmem_di (memwi), comparator b           |

### Per-instruction operand placement (verified against passing tests)
| Pseudo-op | Operand placement |
|-----------|-------------------|
| `regwi(rd, imm)`        | destination in `rd` |
| `mathi(rd, rs1, imm)`   | source in `rs1` (reg_dout0 -> alu_a) |
| `memwi(rsrc, addr)`     | source in `rs2` (reg_dout1 -> dmem_di) |
| `memri(rd, addr)`       | destination in `rd` |
| `loopnz(rcnt, addr)`    | counter in `rs1` (reg_dout0 -> alu zero) |
| `condj(a, b, addr)`     | a in `rs1`, b in `rs2` (comparator a/b) |

> **WARNING: `r0` is hard-wired to zero in every page. Never use `r0` to hold data.**

---

## Timing & Latency Notes

| Element | Latency | Notes |
|---------|---------|-------|
| start -> FSM | 2 cycles | `cdc_gray_sync #(.N(2))`; handled by `start_and_sync()` |
| regfile read | 1 cycle | `pnum_r` pipeline |
| comparator | 1 cycle | registered inputs |
| ALU | registered out | use multi-cycle MATH/MATHI states |

**CONDJ / LOOPNZ:** `cond_flag` / `alu_zero` are only valid after the regfile +
comparator/ALU latency (~2 cycles). The FSM evaluates in CONDJ1/LOOPNZ0, but the
jump target appears on `pmem_addr` only at the following `FETCH_ST`. When testing,
verify control signals at the decision state and the jump effect at the next FETCH.

---

## Python Assembler

`tproc_asm.py` builds program/data hex files compatible with `$readmemh`.

### Generate the example program
```bash
python3 tproc_asm.py --pmem pmem.hex --dmem dmem.hex --pad 32
```

### Write your own program
```python
from tproc_asm import *

prog = [
    regwi(1, 0xABCD),            # r1 = 0xABCD
    memwi(1, 10),                # mem[10] = r1
    regwi(2, 5),                 # r2 = 5
    loopnz(2, addr=2),           # if r2!=0: r2--, jump to [2]
    memwi(2, 11),                # mem[11] = r2 (=0 after loop)
    end(),
]
write_pmem("tests/data/pmem.hex", prog, pad_to=32)
write_dmem("tests/data/dmem.hex", {3: 0x0A}, size=16)
```

### Pseudo-op reference
| Function | Effect |
|----------|--------|
| `regwi(rd, imm)` | rd = imm |
| `mathi(rd, rs1, imm, oper)` | rd = rs1 op imm |
| `bitwi(rd, rs1, imm, oper)` | rd = rs1 (bitop) imm |
| `memwi(rsrc, addr)` | mem[addr] = rsrc |
| `memri(rd, addr)` | rd = mem[addr] |
| `loopnz(rcnt, addr)` | if rcnt != 0: rcnt--, jump |
| `condj(a, b, addr, cond)` | if a (cond) b: jump |
| `read(rd, ch, upper)` | rd = s{ch}_axis |
| `seti(ch, rsrc, t)` | timed set |
| `synci(t)` / `waiti(ch, t)` | timed sync / wait |
| `end()` | terminate |

---

## Loading Programs from Files

### Testbench tasks
```systemverilog
load_pmem_hex("pmem.hex");          // clears to OP_END, then $readmemh
load_dmem_hex("dmem.hex");          // clears to 0, then $readmemh
dump_dmem_hex("dmem_out.hex", 16);  // dump final data memory
```

### Example test
```systemverilog
`SVTEST(test17_run_from_file)
    load_pmem_hex("pmem.hex");
    load_dmem_hex("dmem.hex");
    start_and_sync();
    wait_for_end(500);
    `FAIL_UNLESS_LOG(dmem_array[10] == 32'hABCD,
        $sformatf("dmem[10]=0x%08h", dmem_array[10]));
    dump_dmem_hex("dmem_out.hex", 16);
`SVTEST_END
```

> `$readmemh` ignores `//` and `/* */` comments, blank lines, and supports
> `@address` directives, so commented hex files are safe.

---

## FuseSoC .core Setup

Add a `test_data` fileset and include it in the `test` target:
```yaml
filesets:
  test_data:
    files:
      - tests/data/pmem.hex : {file_type: user, copyto: pmem.hex}
      - tests/data/dmem.hex : {file_type: user, copyto: dmem.hex}

targets:
  test:
    filesets: [rtl, tb, test_data]
    toplevel: tprocv1
```

- `file_type: user` -> not compiled as HDL.
- `copyto: pmem.hex` -> copied to the sim build dir, so `$readmemh("pmem.hex")` works.

Verify after a run:
```bash
ls build/qick_processors_tprocv1_1.0.0/test-xsim/*.hex
```

---

## Writing Robust Tests

**Avoid clocking-block skew** by sampling FSM state on the clock edge:
```systemverilog
fork
  begin : wait_st
    do @(posedge tb_clk); while (u_dut.ctrl_i.state !== TARGET_ST);
  end
  begin : timeout
    repeat(100) @(posedge tb_clk);
    `FAIL_UNLESS_LOG(1'b0, "Timeout waiting for TARGET_ST");
  end
join_any
disable fork;
```

**Three common pitfalls** (all encountered & solved):
1. **Skew** — `@(cb)` samples before the edge, use `@(posedge tb_clk)`.
2. **r0 = 0** — never store data in r0.
3. **Operand fields** — confirm rd/rs1/rs2 placement against the mapping table.

Always check **both** control intent (signals) and observable effect
(`pmem_addr`, `dmem_array`, registers).

---

## Running the Suite

```bash
# Vivado xsim
fusesoc ... run --target test --tool xsim tprocv1

# Verilator
fusesoc ... run --target test --tool verilator tprocv1
```

### Current status: 18/18 passing
```
test00 startup          test09 memwi/memri      test15 end
test01 regwi            test10 synci            test16 unknown_opcode
test02 mathi            test11 seti             test17 run_from_file
test03 bitwi            test12 waiti
test04 pushi/popi       test13 seti_axis_output
test05 stack_not_empty  test14 read_axis
test06 loopnz_taken
test07 condj_taken
test08 condj_not_taken
```
