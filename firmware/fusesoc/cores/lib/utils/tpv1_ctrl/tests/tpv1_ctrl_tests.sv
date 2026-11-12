//--------------------------------------------------------------------------
// test00: Reset and startup sequence
//   INIT → PC_RST → START_MC → FETCH → DECODE control signal checks.
//--------------------------------------------------------------------------
`SVTEST(test00_startup_sequence)
    // After reset: all control outputs should be safe/deasserted
    `FAIL_IF_LOG($isunknown(cb.tb_ir_en),     "ir_en X/Z after reset");
    `FAIL_IF_LOG($isunknown(cb.tb_pc_en),     "pc_en X/Z after reset");
    `FAIL_IF_LOG($isunknown(cb.tb_reg_wen),   "reg_wen X/Z after reset");
    `FAIL_UNLESS_LOG(cb.tb_ir_en   == 1'b0,   "ir_en should be 0 in INIT_ST");
    `FAIL_UNLESS_LOG(cb.tb_pc_en   == 1'b0,   "pc_en should be 0 in INIT_ST");
    `FAIL_UNLESS_LOG(cb.tb_pc_rst  == 1'b0,   "pc_rst should be 0 in INIT_ST");
    `FAIL_UNLESS_LOG(cb.tb_reg_wen == 1'b0,   "reg_wen should be 0 in INIT_ST");
    `FAIL_UNLESS_LOG(cb.tb_t_en    == 1'b1,   "t_en should be 1 by default");

    // Start processor: INIT → PC_RST_ST
    drive_start(1);
    `FAIL_UNLESS_LOG(cb.tb_pc_rst == 1'b1,    "pc_rst must assert in PC_RST_ST");
    `FAIL_UNLESS_LOG(cb.tb_t_en   == 1'b1,    "t_en should still be 1 in PC_RST_ST");

    @(cb); // now in START_MC_ST
    `FAIL_UNLESS_LOG(cb.tb_pc_rst == 1'b0,    "pc_rst must deassert in START_MC_ST");
    `FAIL_UNLESS_LOG(cb.tb_t_en   == 1'b0,    "t_en must deassert in START_MC_ST");

    @(cb); // now in FETCH_ST
    `FAIL_UNLESS_LOG(cb.tb_ir_en  == 1'b1,    "ir_en must assert in FETCH_ST");
    `FAIL_UNLESS_LOG(cb.tb_pc_en  == 1'b1,    "pc_en must assert in FETCH_ST");
    `FAIL_UNLESS_LOG(cb.tb_pc_src == 1'b0,    "pc_src must be 0 (PC+1) in FETCH_ST");
    `FAIL_UNLESS_LOG(cb.tb_t_en   == 1'b1,    "t_en must re-assert in FETCH_ST");

    @(cb); // now in DECODE_ST
    `FAIL_UNLESS_LOG(cb.tb_ir_en  == 1'b0,    "ir_en must deassert in DECODE_ST");
    `FAIL_UNLESS_LOG(cb.tb_pc_en  == 1'b0,    "pc_en must deassert in DECODE_ST");
`SVTEST_END

//--------------------------------------------------------------------------
// test01: MATHI instruction (4-cycle ALU pipeline)
//   alu_src_b=imm (2'b00) for cycles 0-3; reg write on cycle 3.
//--------------------------------------------------------------------------
`SVTEST(test01_mathi)
    bring_to_decode(OP_MATHI); // now in MATHI0_ST

    // MATHI0, MATHI1, MATHI2: alu_src_b=imm, no write
    repeat(3) begin
        `FAIL_UNLESS_LOG(tb_alu_src_b == 2'b00,
            $sformatf("MATHI pipeline: alu_src_b should be imm(00), got %02b", tb_alu_src_b));
        `FAIL_UNLESS_LOG(tb_reg_wen == 1'b0,
            "MATHI pipeline: reg_wen should be 0 during pipeline stages");
        @(cb);
    end

    // MATHI3: write-back
    `FAIL_UNLESS_LOG(tb_alu_src_b == 2'b00, "MATHI3: alu_src_b should still be imm");
    `FAIL_UNLESS_LOG(tb_reg_wen   == 1'b1,  "MATHI3: reg_wen must assert for write-back");
    `FAIL_UNLESS_LOG(tb_reg_src   == 3'b001,"MATHI3: reg_src should be ALU out (001)");
    `FAIL_UNLESS_LOG(tb_ir_en     == 1'b1,  "MATHI3: ir_en must assert (fetch-decode overlap)");
    `FAIL_UNLESS_LOG(tb_pc_en     == 1'b1,  "MATHI3: pc_en must assert");
`SVTEST_END

//--------------------------------------------------------------------------
// test02: MATH instruction (4-cycle, alu_src_b=D1)
//--------------------------------------------------------------------------
`SVTEST(test02_math)
    bring_to_decode(OP_MATH); // MATH0_ST

    repeat(3) begin
        `FAIL_UNLESS_LOG(tb_alu_src_b == 2'b01,
            $sformatf("MATH pipeline: alu_src_b should be D1(01), got %02b", tb_alu_src_b));
        `FAIL_UNLESS_LOG(tb_reg_wen == 1'b0, "MATH pipeline: no write before MATH3");
        @(cb);
    end

    // MATH3: write-back
    `FAIL_UNLESS_LOG(tb_alu_src_b == 2'b01, "MATH3: alu_src_b should be D1");
    `FAIL_UNLESS_LOG(tb_reg_wen   == 1'b1,  "MATH3: reg_wen must assert");
    `FAIL_UNLESS_LOG(tb_reg_src   == 3'b001,"MATH3: reg_src should be ALU out");
`SVTEST_END

//--------------------------------------------------------------------------
// test03: BITWI instruction (4-cycle, alu_src_b=imm)
//--------------------------------------------------------------------------
`SVTEST(test03_bitwi)
    bring_to_decode(OP_BITWI);

    repeat(3) begin
        `FAIL_UNLESS_LOG(tb_alu_src_b == 2'b00, "BITWI pipeline: alu_src_b=imm");
        `FAIL_UNLESS_LOG(tb_reg_wen   == 1'b0,  "BITWI pipeline: no write yet");
        @(cb);
    end

    `FAIL_UNLESS_LOG(tb_reg_wen == 1'b1,   "BITWI3: reg_wen must assert");
    `FAIL_UNLESS_LOG(tb_reg_src == 3'b001, "BITWI3: reg_src = ALU out");
`SVTEST_END

//--------------------------------------------------------------------------
// test04: PUSHI instruction
//   Single cycle: push reg to stack, load imm into reg, advance PC.
//--------------------------------------------------------------------------
`SVTEST(test04_pushi)
    bring_to_decode(OP_PUSHI); // PUSHI0_ST

    `FAIL_UNLESS_LOG(tb_stack_en  == 1'b1,  "PUSHI: stack_en must assert");
    `FAIL_UNLESS_LOG(tb_stack_op  == 1'b1,  "PUSHI: stack_op must be push (1)");
    `FAIL_UNLESS_LOG(tb_reg_wen   == 1'b1,  "PUSHI: reg_wen must assert (load imm into $rb)");
    `FAIL_UNLESS_LOG(tb_reg_src   == 3'b000,"PUSHI: reg_src must be imm (000)");
    `FAIL_UNLESS_LOG(tb_ir_en     == 1'b1,  "PUSHI: ir_en must assert");
    `FAIL_UNLESS_LOG(tb_pc_en     == 1'b1,  "PUSHI: pc_en must assert");
`SVTEST_END

//--------------------------------------------------------------------------
// test05: POPI instruction (3 cycles: pop → latch → write-back)
//--------------------------------------------------------------------------
`SVTEST(test05_popi)
    bring_to_decode(OP_POPI); // POPI0_ST

    // POPI0: initiate pop
    `FAIL_UNLESS_LOG(tb_stack_en == 1'b1,  "POPI0: stack_en must assert");
    `FAIL_UNLESS_LOG(tb_stack_op == 1'b0,  "POPI0: stack_op must be pop (0)");
    `FAIL_UNLESS_LOG(tb_reg_wen  == 1'b0,  "POPI0: no write yet");
    @(cb); // → POPI1_ST

    // POPI1: stack data available on output, drive to reg_src
    `FAIL_UNLESS_LOG(tb_reg_src == 3'b010, "POPI1: reg_src must be stack (010)");
    `FAIL_UNLESS_LOG(tb_reg_wen == 1'b0,   "POPI1: no write yet");
    @(cb); // → POPI2_ST

    // POPI2: write-back
    `FAIL_UNLESS_LOG(tb_reg_src == 3'b010, "POPI2: reg_src must be stack");
    `FAIL_UNLESS_LOG(tb_reg_wen == 1'b1,   "POPI2: reg_wen must assert");
    `FAIL_UNLESS_LOG(tb_ir_en   == 1'b1,   "POPI2: ir_en must assert");
    `FAIL_UNLESS_LOG(tb_pc_en   == 1'b1,   "POPI2: pc_en must assert");
`SVTEST_END

//--------------------------------------------------------------------------
// test06: PUSHI with stack full → ERR_STACK_ST
//--------------------------------------------------------------------------
`SVTEST(test06_pushi_stack_full)
    cb.tb_stack_full <= 1'b1;
    bring_to_decode(OP_PUSHI); // PUSHI0_ST

    @(cb); // PUSHI0 → ERR_STACK_ST (stack_full=1)

    // In ERR_STACK_ST: no active control outputs
    `FAIL_UNLESS_LOG(tb_reg_wen  == 1'b0, "ERR_STACK: reg_wen should be 0");
    `FAIL_UNLESS_LOG(tb_stack_en == 1'b0, "ERR_STACK: stack_en should be 0");
    cb.tb_stack_full <= 1'b0;
`SVTEST_END

//--------------------------------------------------------------------------
// test07: LOOPNZ — branch taken (alu_zero=0)
//   pc_en must assert and be qualified by ~alu_zero.
//--------------------------------------------------------------------------
`SVTEST(test07_loopnz_taken)
    cb.tb_alu_zero <= 1'b0; // loop counter not zero → take branch
    bring_to_decode(OP_LOOPNZ); // LOOPNZ0_ST

    // LOOPNZ0, LOOPNZ1, LOOPNZ2: pc_src=jump, alu_src_b=-1
    repeat(3) begin
        `FAIL_UNLESS_LOG(tb_pc_src    == 1'b1,  "LOOPNZ: pc_src must be jump (1)");
        `FAIL_UNLESS_LOG(tb_pc_en     == 1'b1,  "LOOPNZ: pc_en must be 1 when ~alu_zero");
        `FAIL_UNLESS_LOG(tb_alu_src_b == 2'b10, "LOOPNZ: alu_src_b must be -1 (10)");
        @(cb);
    end

    // LOOPNZ3: write decremented value
    `FAIL_UNLESS_LOG(tb_reg_wen == 1'b1,   "LOOPNZ3: reg_wen must assert");
    `FAIL_UNLESS_LOG(tb_reg_src == 3'b001, "LOOPNZ3: reg_src must be ALU out");
`SVTEST_END

//--------------------------------------------------------------------------
// test08: LOOPNZ — branch not taken (alu_zero=1)
//   FSM must jump directly to FETCH_ST; pc_en must be gated off.
//--------------------------------------------------------------------------
`SVTEST(test08_loopnz_not_taken)
    cb.tb_alu_zero <= 1'b1; // counter reached zero → skip
    bring_to_decode(OP_LOOPNZ); // LOOPNZ0_ST

    // pc_en must be 0 when alu_zero=1 in LOOPNZ0
    `FAIL_UNLESS_LOG(tb_pc_en == 1'b0,
        "LOOPNZ not-taken: pc_en must be gated off when alu_zero=1");

    @(cb); // LOOPNZ0 → FETCH_ST (zero branch)
    `FAIL_UNLESS_LOG(tb_ir_en == 1'b1, "After LOOPNZ skip: should be in FETCH_ST (ir_en=1)");
    cb.tb_alu_zero <= 1'b0;
`SVTEST_END

//--------------------------------------------------------------------------
// test09: CONDJ — branch taken (cond_flag=1)
//--------------------------------------------------------------------------
`SVTEST(test09_condj_taken)
    cb.tb_cond_flag <= 1'b1;
    bring_to_decode(OP_CONDJ); // CONDJ0_ST

    // CONDJ0: evaluate condition (no visible output change)
    @(cb); // → CONDJ1_ST

    // CONDJ1: pc_en & pc_src gated by cond_flag
    `FAIL_UNLESS_LOG(tb_pc_src == 1'b1, "CONDJ1 taken: pc_src must be jump (1)");
    `FAIL_UNLESS_LOG(tb_pc_en  == 1'b1, "CONDJ1 taken: pc_en must be 1 when cond_flag=1");
    @(cb); // → CONDJ2_ST

    // CONDJ2: one more cycle before FETCH
    @(cb); // → FETCH_ST
    `FAIL_UNLESS_LOG(tb_ir_en == 1'b1, "After CONDJ taken: should reach FETCH_ST");
    cb.tb_cond_flag <= 1'b0;
`SVTEST_END

//--------------------------------------------------------------------------
// test10: CONDJ — branch not taken (cond_flag=0)
//--------------------------------------------------------------------------
`SVTEST(test10_condj_not_taken)
    cb.tb_cond_flag <= 1'b0;
    bring_to_decode(OP_CONDJ); // CONDJ0_ST

    @(cb); // → CONDJ1_ST
    // pc_en gated off by ~cond_flag
    `FAIL_UNLESS_LOG(tb_pc_en == 1'b0,
        "CONDJ1 not-taken: pc_en must be 0 when cond_flag=0");

    @(cb); // CONDJ1 → FETCH_ST (skip CONDJ2)
    `FAIL_UNLESS_LOG(tb_ir_en == 1'b1,
        "CONDJ not-taken: should advance directly to FETCH_ST");
`SVTEST_END

//--------------------------------------------------------------------------
// test11: SETI — fifo not full (immediate dispatch)
//--------------------------------------------------------------------------
`SVTEST(test11_seti)
    cb.tb_fifo_full <= 1'b0;
    bring_to_decode(OP_SETI); // SETI0_ST

    // SETI0: alut_src_b=imm, no FIFO write yet
    `FAIL_UNLESS_LOG(tb_alut_src_b  == 1'b1, "SETI0: alut_src_b must be imm (1)");
    `FAIL_UNLESS_LOG(tb_fifo_wr_en  == 1'b0, "SETI0: fifo_wr_en must be 0");
    @(cb); // → SETI1_ST

    // SETI1: write to FIFO, advance to FETCH
    `FAIL_UNLESS_LOG(tb_alut_src_b == 1'b1, "SETI1: alut_src_b still imm");
    `FAIL_UNLESS_LOG(tb_fifo_wr_en == 1'b1, "SETI1: fifo_wr_en must assert");
    @(cb); // → FETCH_ST (fifo not full)
    `FAIL_UNLESS_LOG(tb_ir_en == 1'b1, "After SETI: should reach FETCH_ST");
`SVTEST_END

//--------------------------------------------------------------------------
// test12: SETI — FIFO full stall then release
//--------------------------------------------------------------------------
`SVTEST(test12_seti_fifo_stall)
    cb.tb_fifo_full <= 1'b1; // stall
    bring_to_decode(OP_SETI);
    @(cb); // → SETI1_ST

    // Hold in SETI1 while fifo_full
    repeat(3) begin
        `FAIL_UNLESS_LOG(cb.tb_fifo_wr_en == 1'b1, "SETI1 stall: fifo_wr_en asserted");
        @(cb);
    end

    // Release FIFO
    cb.tb_fifo_full <= 1'b0;
    @(cb); // sync simulation
    @(cb); // → FETCH_ST
    `FAIL_UNLESS_LOG(cb.tb_ir_en == 1'b1, "After SETI stall release: FETCH_ST");
`SVTEST_END

//--------------------------------------------------------------------------
// test13: WAITI — wait for timed_ictrl ack
//--------------------------------------------------------------------------
`SVTEST(test13_waiti)
    cb.tb_fifo_full <= 1'b0;
    cb.tb_waitt     <= 1'b0;
    bring_to_decode(OP_WAITI); // WAITI0_ST

    `FAIL_UNLESS_LOG(tb_alut_src_b == 1'b1, "WAITI0: alut_src_b=imm");
    @(cb); // → WAITI1_ST

    `FAIL_UNLESS_LOG(tb_fifo_wr_en == 1'b1, "WAITI1: fifo_wr_en must assert");
    @(cb); // → WAIT_ACK_ST (fifo not full)

    // WAIT_ACK_ST: assert waitt_ack, hold until waitt arrives
    repeat(3) @(cb);
    `FAIL_UNLESS_LOG(tb_waitt_ack == 1'b1,
        "WAIT_ACK_ST: waitt_ack must assert while waiting");

    // timed_ictrl signals completion
    cb.tb_waitt <= 1'b1;
    @(cb); // → FETCH_ST
    @(cb);
    `FAIL_UNLESS_LOG(tb_ir_en == 1'b1, "After waitt: should reach FETCH_ST");
    cb.tb_waitt <= 1'b0;
`SVTEST_END

//--------------------------------------------------------------------------
// test14: SYNCI instruction
//--------------------------------------------------------------------------
`SVTEST(test14_synci)
    bring_to_decode(OP_SYNCI); // SYNCI0_ST

    `FAIL_UNLESS_LOG(tb_alut_src_b == 1'b1,  "SYNCI0: alut_src_b=imm");
    `FAIL_UNLESS_LOG(tb_t_sync_en  == 1'b0,  "SYNCI0: t_sync_en not yet");
    @(cb); // → SYNCI1_ST

    `FAIL_UNLESS_LOG(tb_alut_src_b == 1'b1, "SYNCI1: alut_src_b=imm");
    `FAIL_UNLESS_LOG(tb_t_sync_en  == 1'b1, "SYNCI1: t_sync_en must assert");
    `FAIL_UNLESS_LOG(tb_ir_en      == 1'b1, "SYNCI1: ir_en must assert");
    `FAIL_UNLESS_LOG(tb_pc_en      == 1'b1, "SYNCI1: pc_en must assert");
`SVTEST_END

//--------------------------------------------------------------------------
// test15: SYNC instruction (register-based sync)
//--------------------------------------------------------------------------
`SVTEST(test15_sync)
    bring_to_decode(OP_SYNC); // SYNC0_ST

    `FAIL_UNLESS_LOG(tb_alut_src_b == 1'b0, "SYNC0: alut_src_b=reg (0)");
    @(cb); // → SYNC1_ST

    `FAIL_UNLESS_LOG(tb_alut_src_b == 1'b0, "SYNC1: alut_src_b=reg");
    `FAIL_UNLESS_LOG(tb_t_sync_en  == 1'b1, "SYNC1: t_sync_en must assert");
`SVTEST_END

//--------------------------------------------------------------------------
// test16: MEMRI — read memory at immediate address (3 cycles)
//--------------------------------------------------------------------------
`SVTEST(test16_memri)
    bring_to_decode(OP_MEMRI); // MEMRI0_ST

    // MEMRI0, MEMRI1: address presented, no write-back
    repeat(2) begin
        `FAIL_UNLESS_LOG(tb_dmem_we  == 1'b0,  "MEMRI0/1: dmem_we=0 (read)");
        `FAIL_UNLESS_LOG(tb_addr_src == 1'b0,  "MEMRI0/1: addr_src=imm (0)");
        `FAIL_UNLESS_LOG(tb_reg_wen  == 1'b0,  "MEMRI0/1: no write-back yet");
        @(cb);
    end

    // MEMRI2: write-back
    `FAIL_UNLESS_LOG(tb_reg_wen  == 1'b1,   "MEMRI2: reg_wen must assert");
    `FAIL_UNLESS_LOG(tb_reg_src  == 3'b100, "MEMRI2: reg_src=memory (100)");
    `FAIL_UNLESS_LOG(tb_dmem_we  == 1'b0,   "MEMRI2: still reading");
    `FAIL_UNLESS_LOG(tb_addr_src == 1'b0,   "MEMRI2: addr_src=imm");
    `FAIL_UNLESS_LOG(tb_ir_en    == 1'b1,   "MEMRI2: ir_en must assert");
`SVTEST_END

//--------------------------------------------------------------------------
// test17: MEMWI — write memory at immediate address (1 cycle)
//--------------------------------------------------------------------------
`SVTEST(test17_memwi)
    bring_to_decode(OP_MEMWI); // MEMWI0_ST

    `FAIL_UNLESS_LOG(tb_dmem_we  == 1'b1, "MEMWI: dmem_we must assert (write)");
    `FAIL_UNLESS_LOG(tb_addr_src == 1'b0, "MEMWI: addr_src=imm");
    `FAIL_UNLESS_LOG(tb_ir_en    == 1'b1, "MEMWI: ir_en must assert");
    `FAIL_UNLESS_LOG(tb_pc_en    == 1'b1, "MEMWI: pc_en must assert");
`SVTEST_END

//--------------------------------------------------------------------------
// test18: MEMR / MEMW — register address variants
//--------------------------------------------------------------------------
//--------------------------------------------------------------------------
// test18: MEMR / MEMW — register address variants
//--------------------------------------------------------------------------
`SVTEST(test18_memr_memw)
    // ---- 1. MEMR (read with address form register) ----
    bring_to_decode(OP_MEMR);
    $display("DEBUG: bring_to_decode done, state = %s", u_dut.state.name);

    // Wait for entering into MEMR0_ST
    while (u_dut.state.name != "MEMR0_ST") @(cb);
    @(cb); // stabilization
    `FAIL_UNLESS_LOG(u_dut.addr_src == 1'b1, "MEMR0: addr_src=reg");
    `FAIL_UNLESS_LOG(u_dut.dmem_we  == 1'b0, "MEMR0: dmem_we=0");

    while (u_dut.state.name != "MEMR1_ST") @(cb);
    @(cb);
    `FAIL_UNLESS_LOG(u_dut.addr_src == 1'b1, "MEMR1: addr_src=reg");
    `FAIL_UNLESS_LOG(u_dut.dmem_we  == 1'b0, "MEMR1: dmem_we=0");

    while (u_dut.state.name != "MEMR2_ST") @(cb);
    @(cb);
    `FAIL_UNLESS_LOG(u_dut.reg_wen  == 1'b1, "MEMR2: reg_wen must assert");
    `FAIL_UNLESS_LOG(u_dut.addr_src == 1'b1, "MEMR2: addr_src=reg");

    // ---- 2. MEMW (write with address from register) ----
    // Change opcode while we are in MEMR2_ST to be ready in DECODE_ST
    cb.tb_opcode <= OP_MEMW;

    // Wait for DUT came back from DECODE_ST (with the new opcode already sampled)
    while (u_dut.state.name != "DECODE_ST") @(cb);
    @(cb); // An extra cycle for decoding and pass to MEMW0_ST

    // Wait for entering into MEMW0_ST
    while (u_dut.state.name != "MEMW0_ST") @(cb);
    @(cb);
    `FAIL_UNLESS_LOG(u_dut.dmem_we  == 1'b1, "MEMW: dmem_we must assert");
    `FAIL_UNLESS_LOG(u_dut.addr_src == 1'b1, "MEMW: addr_src=reg");
    `FAIL_UNLESS_LOG(u_dut.ir_en    == 1'b1, "MEMW: ir_en must assert");

    // Wait for getting back to DECODE_ST (optional)
    while (u_dut.state.name != "DECODE_ST") @(cb);
`SVTEST_END

//--------------------------------------------------------------------------
// test19: REGWI instruction
//--------------------------------------------------------------------------
`SVTEST(test19_regwi)
    bring_to_decode(OP_REGWI);

    `FAIL_UNLESS_LOG(tb_reg_wen == 1'b1,   "REGWI: reg_wen must assert");
    `FAIL_UNLESS_LOG(tb_reg_src == 3'b000, "REGWI: reg_src=imm (000)");
    `FAIL_UNLESS_LOG(tb_ir_en   == 1'b1,   "REGWI: ir_en must assert");
    `FAIL_UNLESS_LOG(tb_pc_en   == 1'b1,   "REGWI: pc_en must assert");
`SVTEST_END

//--------------------------------------------------------------------------
// test20: READ instruction (read from s_axis input port)
//--------------------------------------------------------------------------
`SVTEST(test20_read)
    bring_to_decode(OP_READ);

    `FAIL_UNLESS_LOG(tb_reg_wen == 1'b1,   "READ: reg_wen must assert");
    `FAIL_UNLESS_LOG(tb_reg_src == 3'b011, "READ: reg_src=s_axis (011)");
    `FAIL_UNLESS_LOG(tb_ir_en   == 1'b1,   "READ: ir_en must assert");
    `FAIL_UNLESS_LOG(tb_pc_en   == 1'b1,   "READ: pc_en must assert");
`SVTEST_END

//--------------------------------------------------------------------------
// test21: END instruction → END_ST then back to INIT
//--------------------------------------------------------------------------
`SVTEST(test21_end)
    bring_to_decode(OP_END); // → END_ST

    // In END_ST: no active control signals
    `FAIL_UNLESS_LOG(tb_reg_wen    == 1'b0, "END_ST: reg_wen should be 0");
    `FAIL_UNLESS_LOG(tb_fifo_wr_en == 1'b0, "END_ST: fifo_wr_en should be 0");

    // De-assert start → FSM returns to INIT_ST
    cb.tb_start <= 1'b0;
    @(cb);
    `FAIL_UNLESS_LOG(tb_pc_rst  == 1'b0, "INIT_ST: pc_rst should be 0");
    `FAIL_UNLESS_LOG(tb_pc_en   == 1'b0, "INIT_ST: pc_en should be 0");
`SVTEST_END

//--------------------------------------------------------------------------
// test22: Unknown opcode → ERR_INSTR_ST → END_ST
//--------------------------------------------------------------------------
`SVTEST(test22_unknown_opcode)
    bring_to_decode(OP_UNKNOWN); // → ERR_INSTR_ST

    // ERR_INSTR_ST: no active outputs
    `FAIL_UNLESS_LOG(tb_reg_wen    == 1'b0, "ERR_INSTR: reg_wen should be 0");
    `FAIL_UNLESS_LOG(tb_fifo_wr_en == 1'b0, "ERR_INSTR: fifo_wr_en should be 0");
    `FAIL_UNLESS_LOG(tb_waitt_ack  == 1'b0, "ERR_INSTR: waitt_ack should be 0");

    @(cb); // ERR_INSTR_ST → END_ST
    cb.tb_start <= 1'b0;
    @(cb); // END_ST → INIT_ST
    `FAIL_UNLESS_LOG(tb_pc_en == 1'b0, "After error recovery: back in INIT_ST");
`SVTEST_END

//--------------------------------------------------------------------------
// test23: SET instruction (register-based, alut_src_b=0)
//--------------------------------------------------------------------------
`SVTEST(test23_set)
    cb.tb_fifo_full <= 1'b0;
    bring_to_decode(OP_SET); // SET0_ST

    `FAIL_UNLESS_LOG(tb_alut_src_b == 1'b0, "SET0: alut_src_b=reg (0)");
    `FAIL_UNLESS_LOG(tb_fifo_wr_en == 1'b0, "SET0: fifo_wr_en must be 0");
    @(cb); // → SET1_ST

    `FAIL_UNLESS_LOG(tb_alut_src_b == 1'b0, "SET1: alut_src_b=reg");
    `FAIL_UNLESS_LOG(tb_fifo_wr_en == 1'b1, "SET1: fifo_wr_en must assert");
    @(cb); // → FETCH_ST
    `FAIL_UNLESS_LOG(tb_ir_en == 1'b1, "After SET: should reach FETCH_ST");
`SVTEST_END
