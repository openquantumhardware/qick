//------------------------------------------------------------------------------
// Test cases for tprocv1
//
// Conventions:
//   - itype()/jtype()/rtype() for instruction encoding.
//   - State polling via observable control signals (not state.name).
//   - 'prog' (not 'program') — reserved SV keyword.
//   - DUT slave inputs  (s0..s3): drive via axis_if.m_cb.tdata/tvalid
//   - DUT master outputs (m0..m7): read via axis_if.s_cb.tdata/tvalid,
//                                   tready already driven high in setup().
//   - start_and_sync() handles cdc_gray_sync 2-cycle delay.
//   - Each test preloads only what it needs; rest of pmem = OP_END.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// test00: Reset and startup sequence
//   Verify control signal sequence PC_RST → START_MC → FETCH → DECODE.
//------------------------------------------------------------------------------
`SVTEST(test00_startup_sequence)
    `FAIL_IF_LOG($isunknown(u_dut.ir_en_i),   "ir_en X/Z after reset");
    `FAIL_IF_LOG($isunknown(u_dut.pc_en_i),   "pc_en X/Z after reset");
    `FAIL_IF_LOG($isunknown(u_dut.reg_wen_i), "reg_wen X/Z after reset");
    `FAIL_UNLESS_LOG(u_dut.ir_en_i  == 1'b0,  "ir_en=0 in INIT_ST");
    `FAIL_UNLESS_LOG(u_dut.pc_en_i  == 1'b0,  "pc_en=0 in INIT_ST");
    `FAIL_UNLESS_LOG(u_dut.pc_rst_i == 1'b0,  "pc_rst=0 in INIT_ST");
    `FAIL_UNLESS_LOG(u_dut.t_cnt_en == 1'b1,  "t_cnt_en=1 by default in INIT_ST");

    drive_start(1'b1);
    repeat(2) @(cb); // 2 sync (already taken into account in drive_start) + INIT→PC_RST propagation

    `FAIL_UNLESS_LOG(u_dut.pc_rst_i == 1'b1, "pc_rst must assert in PC_RST_ST");
    `FAIL_UNLESS_LOG(u_dut.t_cnt_en == 1'b1, "t_cnt_en stays 1 in PC_RST_ST");

    @(cb); // → START_MC_ST
    `FAIL_UNLESS_LOG(u_dut.pc_rst_i == 1'b0, "pc_rst deasserts in START_MC_ST");
    `FAIL_UNLESS_LOG(u_dut.t_cnt_en == 1'b0, "t_cnt_en deasserts in START_MC_ST");

    @(cb); // → FETCH_ST
    `FAIL_UNLESS_LOG(u_dut.ir_en_i  == 1'b1, "ir_en asserts in FETCH_ST");
    `FAIL_UNLESS_LOG(u_dut.pc_en_i  == 1'b1, "pc_en asserts in FETCH_ST");
    `FAIL_UNLESS_LOG(u_dut.pc_src_i == 1'b0, "pc_src=0 (PC+1) in FETCH_ST");
    `FAIL_UNLESS_LOG(u_dut.t_cnt_en == 1'b1, "t_cnt_en reasserts in FETCH_ST");

    @(cb); // → DECODE_ST
    `FAIL_UNLESS_LOG(u_dut.ir_en_i == 1'b0, "ir_en deasserts in DECODE_ST");
    `FAIL_UNLESS_LOG(u_dut.pc_en_i == 1'b0, "pc_en deasserts in DECODE_ST");
    repeat(4) @(cb); 
`SVTEST_END

//------------------------------------------------------------------------------
// test01: REGWI — write immediate to register
//   Observable: reg_wen=1, reg_src=000 (imm) in REGWI0_ST.
//------------------------------------------------------------------------------
`SVTEST(test01_regwi)
    pmem_array[0] = itype(OP_REGWI, 3'd0, 3'd0, 4'd0, 5'd1, 5'd0, 5'd0, 31'h1234);

    start_and_sync(); // now in DECODE_ST

    @(cb); // → REGWI0_ST
    `FAIL_UNLESS_LOG(u_dut.reg_wen_i == 1'b1,   "REGWI: reg_wen must assert");
    `FAIL_UNLESS_LOG(u_dut.reg_src_i == 3'b000, "REGWI: reg_src=imm (000)");
    `FAIL_UNLESS_LOG(u_dut.ir_en_i   == 1'b1,   "REGWI: ir_en asserts (fetch-overlap)");
    `FAIL_UNLESS_LOG(u_dut.pc_en_i   == 1'b1,   "REGWI: pc_en asserts");
`SVTEST_END

//------------------------------------------------------------------------------
// test02: MATHI — immediate arithmetic (4-cycle ALU pipeline)
//   oper=ADD, ra=1, rb=0 (r0=0 after reset), imm=100
//   Observable: alu_src_b=imm for 4 cycles; reg_wen on MATHI3_ST.
//------------------------------------------------------------------------------
`SVTEST(test02_mathi)
    pmem_array[0] = itype(OP_MATHI, 3'd0, 3'd0, ARITH_ADD, 5'd1, 5'd0, 5'd0, 31'd100);

    start_and_sync(); // in DECODE_ST

    @(cb); // MATHI0_ST
    `FAIL_UNLESS_LOG(u_dut.alu_src_b_i == 2'b00, "MATHI0: alu_src_b=imm (00)");
    `FAIL_UNLESS_LOG(u_dut.reg_wen_i   == 1'b0,  "MATHI0: no write-back yet");
    @(cb); // MATHI1_ST
    `FAIL_UNLESS_LOG(u_dut.alu_src_b_i == 2'b00, "MATHI1: alu_src_b=imm");
    @(cb); // MATHI2_ST
    `FAIL_UNLESS_LOG(u_dut.alu_src_b_i == 2'b00, "MATHI2: alu_src_b=imm");
    @(cb); // MATHI3_ST — write-back
    `FAIL_UNLESS_LOG(u_dut.reg_wen_i   == 1'b1,   "MATHI3: reg_wen must assert");
    `FAIL_UNLESS_LOG(u_dut.reg_src_i   == 3'b001, "MATHI3: reg_src=ALU out (001)");
    `FAIL_UNLESS_LOG(u_dut.alu_src_b_i == 2'b00,  "MATHI3: alu_src_b still imm");
`SVTEST_END

//------------------------------------------------------------------------------
// test03: BITWI — immediate bitwise OR (4-cycle)
//   oper=OR(0001), ra=1, rb=0, imm=0xF0F0
//------------------------------------------------------------------------------
`SVTEST(test03_bitwi)
    pmem_array[0] = itype(OP_BITWI, 3'd0, 3'd0, 4'b0001, 5'd1, 5'd0, 5'd0, 31'hF0F0);

    start_and_sync();
    @(cb); // BITWI0_ST
    `FAIL_UNLESS_LOG(u_dut.alu_src_b_i == 2'b00, "BITWI0: alu_src_b=imm");
    `FAIL_UNLESS_LOG(u_dut.reg_wen_i   == 1'b0,  "BITWI0: no write-back yet");
    repeat(2) @(cb); // BITWI1, BITWI2
    @(cb); // BITWI3_ST
    `FAIL_UNLESS_LOG(u_dut.reg_wen_i == 1'b1,   "BITWI3: reg_wen must assert");
    `FAIL_UNLESS_LOG(u_dut.reg_src_i == 3'b001, "BITWI3: reg_src=ALU out");
`SVTEST_END

//------------------------------------------------------------------------------
// test04: PUSHI / POPI — stack round-trip
//   pushi: push r0, load r1=0x5A5A
//   popi:  pop into r2
//------------------------------------------------------------------------------
`SVTEST(test04_pushi_popi)
    pmem_array[0] = itype(OP_PUSHI, 3'd0, 3'd0, 4'd0, 5'd1, 5'd0, 5'd0, 31'h5A5A);
    pmem_array[1] = itype(OP_POPI,  3'd0, 3'd0, 4'd0, 5'd2, 5'd0, 5'd0, 31'd0);

    start_and_sync(); // in DECODE_ST for PUSHI

    @(cb); // → PUSHI0_ST
    `FAIL_UNLESS_LOG(u_dut.stack_en_i == 1'b1,   "PUSHI: stack_en must assert");
    `FAIL_UNLESS_LOG(u_dut.stack_op_i == 1'b1,   "PUSHI: stack_op=push (1)");
    `FAIL_UNLESS_LOG(u_dut.reg_wen_i  == 1'b1,   "PUSHI: reg_wen asserts (load imm→rb)");
    `FAIL_UNLESS_LOG(u_dut.reg_src_i  == 3'b000, "PUSHI: reg_src=imm (000)");

    // Wait for next FETCH_ST (PUSHI is single-cycle)
    wait_for_ir_en(20);
    @(cb); // DECODE for POPI
    @(cb); // → POPI0_ST
    `FAIL_UNLESS_LOG(u_dut.stack_en_i == 1'b1, "POPI0: stack_en must assert");
    `FAIL_UNLESS_LOG(u_dut.stack_op_i == 1'b0, "POPI0: stack_op=pop (0)");
    @(cb); // POPI1_ST
    `FAIL_UNLESS_LOG(u_dut.reg_src_i == 3'b010, "POPI1: reg_src=stack (010)");
    @(cb); // POPI2_ST
    `FAIL_UNLESS_LOG(u_dut.reg_wen_i == 1'b1,   "POPI2: reg_wen must assert");
    `FAIL_UNLESS_LOG(u_dut.reg_src_i == 3'b010, "POPI2: reg_src=stack (010)");
`SVTEST_END

//------------------------------------------------------------------------------
// test05: Stack non-empty after PUSHI
//   tpv1_stack depth=256; full overflow tested in tpv1_stack unit TB.
//   Here: verify empty→non-empty transition after one PUSHI.
//------------------------------------------------------------------------------
`SVTEST(test05_stack_not_empty)
    pmem_array[0] = itype(OP_PUSHI, 3'd0, 3'd0, 4'd0, 5'd1, 5'd0, 5'd0, 31'hABCD);

    `FAIL_UNLESS_LOG(u_dut.stack_empty_i == 1'b1, "Stack should be empty before start");

    start_and_sync();
    @(cb); // → PUSHI0_ST

    `FAIL_UNLESS_LOG(u_dut.stack_en_i == 1'b1, "PUSHI: stack_en must assert");
    `FAIL_UNLESS_LOG(u_dut.stack_op_i == 1'b1, "PUSHI: stack_op=push (1)");

    @(cb); // push completes; sp decrements
    `FAIL_UNLESS_LOG(u_dut.stack_empty_i == 1'b0,
        "Stack must be non-empty after one PUSHI");
    `FAIL_UNLESS_LOG(u_dut.stack_full_i  == 1'b0,
        "Stack must not be full after one PUSHI (depth=256)");
`SVTEST_END

//------------------------------------------------------------------------------
// test06: LOOPNZ — branch taken (counter ≠ 0)
//   addr0: regwi r0=2
//   addr1: loopnz r0, addr=1  (self-loop; counter decrements each pass)
//   Observable: pc_src=1, alu_src_b=10 (-1) in LOOPNZ0_ST.
//------------------------------------------------------------------------------
`SVTEST(test06_loopnz_taken)
    // itype: opcode, page, channel, oper, rd(addr7), rs1(addr0), rs2(addr1), imm
    // We write a 2 in r1 (rd = 5'd1)
    pmem_array[0] = itype(OP_REGWI,  3'd0, 3'd0, 4'd0, 5'd1, 5'd0, 5'd0, 31'd2);
    
    // jtype: opcode, page, oper, rd(addr7), rs1(addr0), rs2(addr1), imm
    // We evaluate r1 (rs1 = 5'd1)
    pmem_array[1] = jtype(OP_LOOPNZ, 3'd0, ARITH_ADD, 5'd0, 5'd1, 5'd0, 16'd1);
    pmem_array[2] = {OP_END, 56'b0};

    start_and_sync();

    wait_for_reg_wen(20);   
    `FAIL_UNLESS_LOG(u_dut.reg_wen_i == 1'b1, "REGWI should write r1=2");

    wait_for_ir_en(20);     
    @(cb);                  
    @(cb);                  
    @(cb);                  

    // Verify in LOOPNZ1_ST where alu_zero already is correct
    `FAIL_UNLESS_LOG(u_dut.pc_src_i    == 1'b1,  "LOOPNZ1: pc_src=1 (jump)");
    `FAIL_UNLESS_LOG(u_dut.pc_en_i     == 1'b1,  "LOOPNZ1: pc_en=1 when r1!=0");
    `FAIL_UNLESS_LOG(u_dut.alu_src_b_i == 2'b10, "LOOPNZ1: alu_src_b=-1 (decrement)");
`SVTEST_END

//------------------------------------------------------------------------------
// test07: CONDJ — taken (r1=10 > r2=5, oper=GT)
//
//   Waits for FSM states by sampling on @(posedge clk) to avoid clocking-block
//   sampling skew. Verifies control intent in CONDJ1_ST and the observable
//   jump effect (pmem_addr == 7) at the following FETCH_ST.
//------------------------------------------------------------------------------
`SVTEST(test07_condj_taken)
    pmem_array[0] = itype(OP_REGWI, 3'd0, 3'd0, 4'd0, 5'd1, 5'd0, 5'd0, 31'd10);
    pmem_array[1] = itype(OP_REGWI, 3'd0, 3'd0, 4'd0, 5'd2, 5'd0, 5'd0, 31'd5);
    pmem_array[2] = jtype(OP_CONDJ, 3'd0, COND_GT, 5'd0, 5'd1, 5'd2, 16'd7);
    pmem_array[7] = {OP_END, 56'b0};

    start_and_sync();

    // Wait for the FSM to reach CONDJ1_ST, sampling directly on the clock edge.
    fork
        begin : wait_condj1
            do @(posedge tb_clk); while (u_dut.ctrl_i.state !== CONDJ1_ST);
        end
        begin : timeout1
            repeat (100) @(posedge tb_clk);
            `FAIL_UNLESS_LOG(1'b0,"Timeout waiting for CONDJ1_ST");
        end
    join_any
    disable fork;

    // We are now in CONDJ1_ST — check control intent
    `FAIL_UNLESS_LOG(u_dut.ctrl_i.state == CONDJ1_ST,
        "FSM should be in CONDJ1_ST");
    `FAIL_UNLESS_LOG(u_dut.pc_src_i == 1'b1,
        "CONDJ taken: pc_src=1 in CONDJ1");
    `FAIL_UNLESS_LOG(u_dut.pc_en_i  == 1'b1,
        "CONDJ taken: pc_en=1 in CONDJ1");
    `FAIL_UNLESS_LOG(u_dut.cond_flag_i == 1'b1,
        "CONDJ: cond_flag=1 for r1=10 > r2=5");

    // Wait for the next FETCH_ST and confirm the jump target on pmem_addr.
    fork
        begin : wait_fetch
            do @(posedge tb_clk); while (u_dut.ctrl_i.state !== FETCH_ST);
        end
        begin : timeout2
            repeat (100) @(posedge tb_clk);
            `FAIL_UNLESS_LOG(1'b0,"Timeout waiting for FETCH_ST after CONDJ");
        end
    join_any
    disable fork;

    `FAIL_UNLESS_LOG(u_dut.pmem_addr == 8'd7,
        "CONDJ taken: PC jumped to address 7");
`SVTEST_END

//------------------------------------------------------------------------------
// test08: CONDJ — not taken (r1=3 > r2=8 is false with GT)
//   Expected: cond_flag=0, jump NOT taken, PC advances to the next
//   instruction (pmem_addr == 3) instead of jumping to the target (7).
//------------------------------------------------------------------------------
`SVTEST(test08_condj_not_taken)
    // Write 3 into r1, 8 into r2  (r0 is hard-wired to zero, never use as data)
    pmem_array[0] = itype(OP_REGWI, 3'd0, 3'd0, 4'd0, 5'd1, 5'd0, 5'd0, 31'd3);
    pmem_array[1] = itype(OP_REGWI, 3'd0, 3'd0, 4'd0, 5'd2, 5'd0, 5'd0, 31'd8);
    // condj: ra=r1 (ir[40:36]), rb=r2 (ir[35:31]), GT, addr=7
    // Evaluates r1 > r2  ->  3 > 8  ->  FALSE  -> jump NOT taken
    pmem_array[2] = jtype(OP_CONDJ, 3'd0, COND_GT, 5'd0, 5'd1, 5'd2, 16'd7);
    // Next sequential instruction (addr 3) ends the program if jump not taken
    pmem_array[3] = {OP_END, 56'b0};
    // Target (would only be reached if the jump were taken)
    pmem_array[7] = {OP_END, 56'b0};

    start_and_sync();

    // Wait for CONDJ1_ST, sampling on the clock edge to avoid skew.
    fork
        begin : wait_condj1
            do @(posedge tb_clk); while (u_dut.ctrl_i.state !== CONDJ1_ST);
        end
        begin : timeout1
            repeat (100) @(posedge tb_clk);
            `FAIL_UNLESS_LOG(1'b0, "Timeout waiting for CONDJ1_ST");
        end
    join_any
    disable fork;

    // In CONDJ1_ST the condition is false: cond_flag must be 0,
    // and pc_en is gated off (no jump).
    `FAIL_UNLESS_LOG(u_dut.cond_flag_i == 1'b0,
        "CONDJ not-taken: cond_flag=0 for 3 > 8 (false)");
    `FAIL_UNLESS_LOG(u_dut.pc_en_i == 1'b0,
        "CONDJ not-taken: pc_en gated off by ~cond_flag");

    // Observable effect: PC advances sequentially (does NOT jump to 7).
    fork
        begin : wait_fetch
            do @(posedge tb_clk); while (u_dut.ctrl_i.state !== FETCH_ST);
        end
        begin : timeout2
            repeat (100) @(posedge tb_clk);
            `FAIL_UNLESS_LOG(1'b0, "Timeout waiting for FETCH_ST after CONDJ");
        end
    join_any
    disable fork;

    `FAIL_UNLESS_LOG(u_dut.pmem_addr == 8'd3,
        "CONDJ not-taken: PC advanced to next instruction (addr 3), did not jump to 7");
`SVTEST_END

//------------------------------------------------------------------------------
// test09: MEMWI / MEMRI — data memory write and read back
//   regwi r1=0xABCD; memwi mem[5]=r1; memri r2=mem[5]
//   Observable: dmem_we asserts in MEMWI0_ST; reg_wen/reg_src in MEMRI2_ST.
//   The TB memory model verifies the write.
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
// test09: MEMWI / MEMRI — data memory write and read back
//------------------------------------------------------------------------------
`SVTEST(test09_memwi_memri)
    // regwi r1 = 0xABCD
    pmem_array[0] = itype(OP_REGWI, 3'd0, 3'd0, 4'd0, 5'd1, 5'd0, 5'd0, 31'hABCD);

    // memwi mem[5] = r1.  Source register goes in the rc field (ir[35:31]),
    // because dmem_di = reg_dout1_i and reg_addr1_i = ir[35:31].
    //                                        ra    rb    rc    imm
    pmem_array[1] = itype(OP_MEMWI, 3'd0, 3'd0, 4'd0, 5'd0, 5'd0, 5'd1, 31'd5);

    // memri r2 = mem[5].  Destination register goes in ra (ir[45:41] = addr7).
    pmem_array[2] = itype(OP_MEMRI, 3'd0, 3'd0, 4'd0, 5'd2, 5'd0, 5'd0, 31'd5);
    pmem_array[3] = {OP_END, 56'b0};

    start_and_sync();

    // MEMWI: wait for MEMWI0_ST and verify the write controls
    fork
        begin : wait_memwi0
            do @(posedge tb_clk); while (u_dut.ctrl_i.state !== MEMWI0_ST);
        end
        begin : to_memwi0
            repeat (100) @(posedge tb_clk);
            `FAIL_UNLESS_LOG(1'b0, "Timeout waiting for MEMWI0_ST");
        end
    join_any
    disable fork;

    `FAIL_UNLESS_LOG(u_dut.dmem_we == 1'b1,
        "MEMWI: dmem_we must assert in MEMWI0_ST");
    `FAIL_UNLESS_LOG(u_dut.dmem_addr_src == 1'b0,
        "MEMWI: addr_src=imm (0)");

    // MEMRI: wait for MEMRI2_ST and verify the read-back controls
    fork
        begin : wait_memri2
            do @(posedge tb_clk); while (u_dut.ctrl_i.state !== MEMRI2_ST);
        end
        begin : to_memri2
            repeat (100) @(posedge tb_clk);
            `FAIL_UNLESS_LOG(1'b0, "Timeout waiting for MEMRI2_ST");
        end
    join_any
    disable fork;

    `FAIL_UNLESS_LOG(u_dut.reg_wen_i == 1'b1,
        "MEMRI2: reg_wen must assert");
    `FAIL_UNLESS_LOG(u_dut.reg_src_i == 3'b100,
        "MEMRI2: reg_src=memory (100)");

    // Margin for the synchronous memory write to settle
    repeat (2) @(posedge tb_clk);
    `FAIL_UNLESS_LOG(dmem_array[5] == 32'hABCD,
        $sformatf("dmem[5] should be 0xABCD, got 0x%08h", dmem_array[5]));
`SVTEST_END
//------------------------------------------------------------------------------
// test10: SYNCI — sync master clock to immediate
//   Observable: t_cnt_sync_en asserts in SYNCI1_ST; alut_src_b=1 (imm).
//------------------------------------------------------------------------------
`SVTEST(test10_synci)
    pmem_array[0] = itype(OP_SYNCI, 3'd0, 3'd0, 4'd0, 5'd0, 5'd0, 5'd0, 31'd256);

    start_and_sync();
    @(cb); // SYNCI0_ST
    `FAIL_UNLESS_LOG(u_dut.alut_src_b_i  == 1'b1, "SYNCI0: alut_src_b=imm");
    `FAIL_UNLESS_LOG(u_dut.t_cnt_sync_en == 1'b0,  "SYNCI0: sync_en not yet");
    @(cb); // SYNCI1_ST
    `FAIL_UNLESS_LOG(u_dut.t_cnt_sync_en == 1'b1, "SYNCI1: t_sync_en must assert");
    `FAIL_UNLESS_LOG(u_dut.alut_src_b_i  == 1'b1, "SYNCI1: alut_src_b still imm");
`SVTEST_END

//------------------------------------------------------------------------------
// test11: SETI — timed set to channel 0
//   Observable: alut_src_b=1 in SETI0; fifo_wr_en asserts in SETI1_ST.
//------------------------------------------------------------------------------
`SVTEST(test11_seti)
    pmem_array[0] = itype(OP_SETI, 3'd0, 3'd0, 4'd0, 5'd1, 5'd0, 5'd0, 31'd100);

    start_and_sync();
    @(cb); // SETI0_ST
    `FAIL_UNLESS_LOG(u_dut.alut_src_b_i   == 1'b1, "SETI0: alut_src_b=imm");
    `FAIL_UNLESS_LOG(u_dut.fifo_wr_en_mux == 1'b0, "SETI0: fifo_wr_en not yet");
    @(cb); // SETI1_ST
    `FAIL_UNLESS_LOG(u_dut.alut_src_b_i   == 1'b1, "SETI1: alut_src_b=imm");
    `FAIL_UNLESS_LOG(u_dut.fifo_wr_en_mux == 1'b1, "SETI1: fifo_wr_en must assert");
`SVTEST_END

//------------------------------------------------------------------------------
// test12: WAITI — timed wait on channel 0 with timestamp=0
//   Since t_cnt > 0 by the time the instruction executes, the dispatch
//   resolves immediately.
//   Observable: fifo_wr_en in WAITI1; waitt_ack_mux in WAIT_ACK_ST.
//------------------------------------------------------------------------------
`SVTEST(test12_waiti)
    pmem_array[0] = itype(OP_WAITI, 3'd0, 3'd0, 4'd0, 5'd0, 5'd0, 5'd0, 31'd0);

    start_and_sync();
    @(cb); // WAITI0_ST
    `FAIL_UNLESS_LOG(u_dut.alut_src_b_i == 1'b1, "WAITI0: alut_src_b=imm");
    @(cb); // WAITI1_ST (fifo write, then → WAIT_ACK_ST)
    `FAIL_UNLESS_LOG(u_dut.fifo_wr_en_mux == 1'b1, "WAITI1: fifo_wr_en must assert");

    // Wait for WAIT_ACK_ST: waitt_ack_mux asserts
    begin
        automatic int cnt = 0;
        while (!u_dut.waitt_ack_mux && cnt < 50) begin
            @(cb); cnt++;
        end
    end
    `FAIL_UNLESS_LOG(u_dut.waitt_ack_mux == 1'b1, "WAIT_ACK: waitt_ack_mux must assert");

    // Wait for FSM to return to FETCH_ST (ir_en asserts)
    wait_for_ir_en(100);
    `FAIL_UNLESS_LOG(u_dut.ir_en_i == 1'b1, "After wait ack: processor returned to FETCH_ST");
`SVTEST_END

//------------------------------------------------------------------------------
// test13: SETI → AXIS master output via timed_ictrl
//   The timed_ictrl dispatches the instruction on m0_axis once t_cnt >= t_inst.
//   With t_inst=0 and t_cnt already > 0 at execution time, dispatch is immediate.
//   Observable: m0_axis.s_cb.tvalid asserts; tdata[31:0] = reg value (0).
//------------------------------------------------------------------------------
`SVTEST(test13_seti_axis_output)
    logic [159:0] received;

    // seti ch=0: dispatch r1 (=0 after reset) at t=0
    pmem_array[0] = itype(OP_SETI, 3'd0, 3'd0, 4'd0, 5'd1, 5'd0, 5'd0, 31'd0);

    start_and_sync();
    // Let SETI execute and FIFO dispatch
    repeat(20) @(cb);

    // Check that m0_axis received a transaction
    // (tready already high from setup; tvalid should have pulsed)
    // We poll for tvalid on the master output
    begin
        automatic int cnt = 0;
        // tvalid may have already fired; check s_cb sample
        while (!m0_axis.s_cb.tvalid && cnt < 50) begin
            @(m0_axis.s_cb); cnt++;
        end
        received = m0_axis.s_cb.tdata;
    end
    // For SETI: tdata = {128'b0, p0} where p0 = reg_dout0 = r_ra = r1 = 0
    `FAIL_UNLESS_LOG(received[31:0] == 32'h0,
        $sformatf("SETI m0 tdata[31:0] should be 0, got 0x%08h", received[31:0]));
    `FAIL_UNLESS_LOG(received[159:32] == '0,
        "SETI m0 tdata[159:32] should be 0 (upper bits zeroed for seti)");
`SVTEST_END

//------------------------------------------------------------------------------
// test14: READ — capture AXIS slave data into register
//   Drive data on s0_axis (TB is master, uses m_cb).
//   Observable: reg_wen=1, reg_src=011 (s_axis) in READ0_ST.
//   din_i should carry lower 32 bits (oper≠0b1010).
//------------------------------------------------------------------------------
`SVTEST(test14_read_axis)
    // Pre-load s0_axis with a known value via m_cb
    // axis_set_reg in the DUT holds the value until the processor reads it.
    s0_axis.m_cb.tdata  <= 64'hDEAD_BEEF_1234_5678;
    s0_axis.m_cb.tvalid <= 1'b1;
    @(s0_axis.m_cb);
    // Wait for axis_set_reg to latch (tready asserts when DUT is ready)
    // For now just hold valid high; axis_set_reg accepts on first tvalid.

    pmem_array[0] = itype(OP_READ, 3'd0, 3'd0, 4'd0, 5'd0, 5'd0, 5'd0, 31'd0);

    start_and_sync();
    @(cb); // READ0_ST

    `FAIL_UNLESS_LOG(u_dut.reg_wen_i == 1'b1,   "READ: reg_wen must assert");
    `FAIL_UNLESS_LOG(u_dut.reg_src_i == 3'b011, "READ: reg_src=s_axis (011)");
    // oper=0 (not 0b1010) → lower 32 bits selected
    `FAIL_UNLESS_LOG(u_dut.din_i == 32'h1234_5678,
        $sformatf("READ: din_i should be lower 32 bits 0x12345678, got 0x%08h", u_dut.din_i));

    s0_axis.m_cb.tvalid <= 1'b0;
    s0_axis.m_cb.tdata  <= '0;
`SVTEST_END

//------------------------------------------------------------------------------
// test15: END → INIT_ST after start deasserted
//   Observable: all active outputs deassert; pc_en=0 after start pulled low.
//------------------------------------------------------------------------------
`SVTEST(test15_end)
    pmem_array[0] = {OP_END, 56'b0};

    start_and_sync();
    wait_for_end(50);

    `FAIL_UNLESS_LOG(u_dut.reg_wen_i      == 1'b0, "END: reg_wen deasserted");
    `FAIL_UNLESS_LOG(u_dut.stack_en_i     == 1'b0, "END: stack_en deasserted");
    `FAIL_UNLESS_LOG(u_dut.fifo_wr_en_mux == 1'b0, "END: fifo_wr_en deasserted");
    `FAIL_UNLESS_LOG(u_dut.dmem_we        == 1'b0, "END: dmem_we deasserted");

    // Deassert start → FSM returns to INIT_ST after cdc_gray_sync
    cb.tb_start <= 1'b0;
    repeat(6) @(cb); // cdc_gray_sync delay + transition
    `FAIL_UNLESS_LOG(u_dut.pc_en_i  == 1'b0, "INIT_ST: pc_en=0");
    `FAIL_UNLESS_LOG(u_dut.pc_rst_i == 1'b0, "INIT_ST: pc_rst=0");
`SVTEST_END

//------------------------------------------------------------------------------
// test16: Unknown opcode → ERR_INSTR_ST → END_ST
//   Observable: all active outputs deassert within a few cycles.
//------------------------------------------------------------------------------
`SVTEST(test16_unknown_opcode)
    pmem_array[0] = {8'hFF, 56'b0}; // opcode 0xFF not in tpv1_ctrl

    start_and_sync();
    wait_for_end(30);

    `FAIL_UNLESS_LOG(u_dut.reg_wen_i      == 1'b0, "ERR/END: reg_wen deasserted");
    `FAIL_UNLESS_LOG(u_dut.fifo_wr_en_mux == 1'b0, "ERR/END: fifo_wr_en deasserted");
    `FAIL_UNLESS_LOG(u_dut.waitt_ack_mux  == 1'b0, "ERR/END: waitt_ack deasserted");
    `FAIL_UNLESS_LOG(u_dut.stack_en_i     == 1'b0, "ERR/END: stack_en deasserted");
`SVTEST_END

//------------------------------------------------------------------------------
// test17: run a program loaded from external hex files
//   - Loads pmem.hex (instructions) and optionally dmem.hex (initial data)
//   - Runs until the processor reaches END (idle)
//   - Verifies expected results in data memory and/or registers
//------------------------------------------------------------------------------
`SVTEST(test17_run_from_file)
    // Load the program (and optional initial data) from disk
    load_pmem_hex("pmem.hex");
    load_dmem_hex("dmem.hex");   // omit if your program doesn't need preloaded data

    start_and_sync();

    // Run until the FSM reaches the terminal/idle condition
    wait_for_end(500);

    // ----- Self-checking against expected results -----
    // Example: the program should have written 0x12345678 into dmem[10]
    `FAIL_UNLESS_LOG(dmem_array[10] == 32'h12345678,
        $sformatf("dmem[10] expected 0x12345678, got 0x%08h", dmem_array[10]));

    // Optionally dump the final memory state for offline inspection
    dump_dmem_hex("dmem_out.hex", 16);
`SVTEST_END