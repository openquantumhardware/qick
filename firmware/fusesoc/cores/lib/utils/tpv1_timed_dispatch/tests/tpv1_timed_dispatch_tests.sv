//--------------------------------------------------------------------------
// test00: Reset state
//   After reset, all outputs must be deasserted and well-defined.
//--------------------------------------------------------------------------
`SVTEST(test00_reset_state)
    `FAIL_IF_LOG($isunknown(tb_fifo_rd_en),    "fifo_rd_en should not be X/Z");
    `FAIL_IF_LOG($isunknown(tb_waitt),         "waitt should not be X/Z");
    `FAIL_IF_LOG($isunknown(tb_m_axis_tvalid), "tvalid should not be X/Z");
    `FAIL_UNLESS_LOG(tb_waitt         == 1'b0, "waitt should be deasserted after reset");
    `FAIL_UNLESS_LOG(tb_m_axis_tvalid == 1'b0, "tvalid should be deasserted after reset");
`SVTEST_END

//--------------------------------------------------------------------------
// test01: FIFO read enable asserts when FIFO is not empty
//   In READ_ST, DUT must assert fifo_rd_en as soon as fifo_empty goes low.
//--------------------------------------------------------------------------
`SVTEST(test01_fifo_rd_en_on_nonempty)
    // FIFO starts empty — DUT sits in READ_ST asserting rd_en
    `FAIL_UNLESS_LOG(tb_fifo_rd_en == 1'b1,
        "fifo_rd_en should assert in READ_ST even before data arrives");

    // Present a NOP word; DUT should consume it and return to READ_ST
    cb.tb_fifo_dout  <= build_word('0, '0, '0, '0, '0, 48'd0, OP_NOP);
    cb.tb_fifo_empty <= 1'b0;
    @(cb); // Clock 1: DUT samples fifo_empty = 0
    @(cb); // Clock 2: DUT enters WAIT_ST, testbench can now sample updated rd_en
    
    `FAIL_UNLESS_LOG(tb_fifo_rd_en == 1'b0,
        "fifo_rd_en should deassert once DUT leaves READ_ST");
    cb.tb_fifo_empty <= 1'b1;
`SVTEST_END
    
//--------------------------------------------------------------------------
// test02: Timestamp gating — instruction held until t_cnt reaches t_inst
//   DUT must stay in WAIT_ST and not dispatch until t_cnt >= t_inst.
//--------------------------------------------------------------------------
`SVTEST(test02_timestamp_gating)
    logic [215:0] word;
    logic [47:0]  t_target;

    t_target = 48'd10;
    word = build_word(32'hDEAD_BEEF, '0, '0, '0, '0, t_target, OP_SETI);

    // t_cnt starts at 0; present instruction
    present_instruction(word);

    // DUT is now in WAIT_ST; tvalid must stay low while t_cnt < t_inst
    cb.tb_t_cnt <= 48'd5;
    repeat(3) @(cb);
    `FAIL_UNLESS_LOG(tb_m_axis_tvalid == 1'b0,
        "tvalid must not assert before t_cnt reaches t_inst");

    // Advance t_cnt to reach the timestamp
    advance_time(t_target);
    @(cb); // FSM transitions to SETI_ST
    `FAIL_UNLESS_LOG(tb_m_axis_tvalid == 1'b1,
        "tvalid must assert once t_cnt >= t_inst");
`SVTEST_END

//--------------------------------------------------------------------------
// test03: SETI opcode (0x13)
//   Single-cycle output: tdata = {128'b0, p0}. No tready dependency.
//--------------------------------------------------------------------------
`SVTEST(test03_seti)
    logic [215:0]  word;
    logic [159:0]  expected_tdata;

    word = build_word(32'hCAFE_BABE, '0, '0, '0, '0, 48'd0, OP_SETI);
    expected_tdata = {128'b0, 32'hCAFE_BABE};

    cb.tb_t_cnt <= 48'd100; // t_cnt already past any timestamp
    present_instruction(word);
    @(cb); // WAIT_ST -> SETI_ST

    `FAIL_UNLESS_LOG(tb_m_axis_tvalid == 1'b1,
        "SETI: tvalid must assert in SETI_ST");
    `FAIL_UNLESS_LOG(tb_m_axis_tdata == expected_tdata,
        $sformatf("SETI: tdata mismatch: expected 0x%040h, got 0x%040h",
            expected_tdata, tb_m_axis_tdata));

    @(cb); // SETI_ST -> READ_ST (single cycle, no tready dependency)
    `FAIL_UNLESS_LOG(tb_m_axis_tvalid == 1'b0,
        "SETI: tvalid must deassert after single cycle");
`SVTEST_END

//--------------------------------------------------------------------------
// test04: SET opcode (0x51)
//   Single-cycle output: tdata = {p4, p3, p2, p1, p0}. No tready dependency.
//--------------------------------------------------------------------------
`SVTEST(test04_set)
    logic [215:0]  word;
    logic [159:0]  expected_tdata;

    word = build_word(
        32'h0000_0001,  // p0
        32'h0000_0002,  // p1
        32'h0000_0003,  // p2
        32'h0000_0004,  // p3
        32'h0000_0005,  // p4
        48'd0,
        OP_SET
    );
    expected_tdata = {32'h5, 32'h4, 32'h3, 32'h2, 32'h1};

    cb.tb_t_cnt <= 48'd100;
    present_instruction(word);
    @(cb); // WAIT_ST -> SET_ST

    `FAIL_UNLESS_LOG(tb_m_axis_tvalid == 1'b1,
        "SET: tvalid must assert in SET_ST");
    `FAIL_UNLESS_LOG(tb_m_axis_tdata == expected_tdata,
        $sformatf("SET: tdata mismatch: expected 0x%040h, got 0x%040h",
            expected_tdata, tb_m_axis_tdata));

    @(cb); // SET_ST -> READ_ST
    `FAIL_UNLESS_LOG(tb_m_axis_tvalid == 1'b0,
        "SET: tvalid must deassert after single cycle");
`SVTEST_END

//--------------------------------------------------------------------------
// test05: SETBI opcode (0x1A)
//   Blocking output: DUT holds tvalid until tready asserted.
//   tdata = {128'b0, p0}.
//--------------------------------------------------------------------------
`SVTEST(test05_setbi_tready_gating)
    logic [215:0] word;
    logic [159:0] expected_tdata;

    word = build_word(32'hABCD_1234, '0, '0, '0, '0, 48'd0, OP_SETBI);
    expected_tdata = {128'b0, 32'hABCD_1234};

    cb.tb_t_cnt         <= 48'd100;
    cb.tb_m_axis_tready <= 1'b0; // Hold tready low initially
    present_instruction(word);
    @(cb); // WAIT_ST -> SETBI_ST

    // tvalid asserted, tready low: DUT must hold in SETBI_ST
    repeat(3) @(cb);
    `FAIL_UNLESS_LOG(tb_m_axis_tvalid == 1'b1,
        "SETBI: tvalid must stay asserted while tready=0");
    `FAIL_UNLESS_LOG(tb_m_axis_tdata == expected_tdata,
        $sformatf("SETBI: tdata mismatch: expected 0x%040h, got 0x%040h",
            expected_tdata, tb_m_axis_tdata));

    // Assert tready: DUT must transition to READ_ST next cycle
    cb.tb_m_axis_tready <= 1'b1;
    @(cb);
    @(cb);
    `FAIL_UNLESS_LOG(tb_m_axis_tvalid == 1'b0,
        "SETBI: tvalid must deassert after tready handshake");
`SVTEST_END

//--------------------------------------------------------------------------
// test06: SETB opcode (0x58)
//   Blocking output with full 160-bit payload; same tready gating as SETBI.
//--------------------------------------------------------------------------
`SVTEST(test06_setb_tready_gating)
    logic [215:0] word;
    logic [159:0] expected_tdata;

    word = build_word(
        32'hAAAA_0001,  // p0
        32'hBBBB_0002,  // p1
        32'hCCCC_0003,  // p2
        32'hDDDD_0004,  // p3
        32'hEEEE_0005,  // p4
        48'd0,
        OP_SETB
    );
    expected_tdata = {32'hEEEE_0005, 32'hDDDD_0004,
                      32'hCCCC_0003, 32'hBBBB_0002, 32'hAAAA_0001};

    cb.tb_t_cnt         <= 48'd100;
    cb.tb_m_axis_tready <= 1'b0;
    present_instruction(word);
    @(cb); // WAIT_ST -> SETB_ST

    repeat(2) @(cb);
    `FAIL_UNLESS_LOG(tb_m_axis_tvalid == 1'b1,
        "SETB: tvalid must stay asserted while tready=0");
    `FAIL_UNLESS_LOG(tb_m_axis_tdata == expected_tdata,
        $sformatf("SETB: tdata mismatch: expected 0x%040h, got 0x%040h",
            expected_tdata, tb_m_axis_tdata));

    cb.tb_m_axis_tready <= 1'b1;
    @(cb);
    @(cb);
    `FAIL_UNLESS_LOG(tb_m_axis_tvalid == 1'b0,
        "SETB: tvalid must deassert after tready handshake");
`SVTEST_END

//--------------------------------------------------------------------------
// test07: WAITI opcode (0x15)
//   DUT must assert waitt and hold until waitt_ack received.
//--------------------------------------------------------------------------
`SVTEST(test07_waiti)
    logic [215:0] word;

    word = build_word('0, '0, '0, '0, '0, 48'd0, OP_WAITI);

    cb.tb_t_cnt     <= 48'd100;
    cb.tb_waitt_ack <= 1'b0;
    present_instruction(word);
    @(cb); // WAIT_ST -> WAIT_ACK_ST

    repeat(3) @(cb);
    `FAIL_UNLESS_LOG(tb_waitt == 1'b1,
        "WAITI: waitt must assert and hold until ack");
    `FAIL_UNLESS_LOG(tb_m_axis_tvalid == 1'b0,
        "WAITI: tvalid must remain deasserted during wait");

    cb.tb_waitt_ack <= 1'b1;
    @(cb);
    @(cb);
    `FAIL_UNLESS_LOG(tb_waitt == 1'b0,
        "WAITI: waitt must deassert after ack");
    cb.tb_waitt_ack <= 1'b0;
`SVTEST_END

//--------------------------------------------------------------------------
// test08: WAIT opcode (0x54)
//   Same behavior as WAITI — both route to WAIT_ACK_ST.
//--------------------------------------------------------------------------
`SVTEST(test08_wait)
    logic [215:0] word;

    word = build_word('0, '0, '0, '0, '0, 48'd0, OP_WAIT);

    cb.tb_t_cnt     <= 48'd100;
    cb.tb_waitt_ack <= 1'b0;
    present_instruction(word);
    @(cb); // WAIT_ST -> WAIT_ACK_ST

    `FAIL_UNLESS_LOG(tb_waitt == 1'b1,
        "WAIT: waitt must assert in WAIT_ACK_ST");

    cb.tb_waitt_ack <= 1'b1;
    @(cb);
    @(cb);
    `FAIL_UNLESS_LOG(tb_waitt == 1'b0,
        "WAIT: waitt must deassert after ack");
    cb.tb_waitt_ack <= 1'b0;
`SVTEST_END

//--------------------------------------------------------------------------
// test09: Unknown opcode
//   Unrecognized opcodes must be silently consumed: no tvalid, no waitt,
//   DUT returns immediately to READ_ST.
//--------------------------------------------------------------------------
`SVTEST(test09_unknown_opcode)
    logic [215:0] word;

    word = build_word(32'hDEAD_DEAD, '0, '0, '0, '0, 48'd0, OP_NOP);

    cb.tb_t_cnt <= 48'd100;
    present_instruction(word);
    @(cb); // WAIT_ST -> READ_ST (default branch)

    `FAIL_UNLESS_LOG(tb_m_axis_tvalid == 1'b0,
        "Unknown opcode: tvalid must not assert");
    `FAIL_UNLESS_LOG(tb_waitt == 1'b0,
        "Unknown opcode: waitt must not assert");
    `FAIL_UNLESS_LOG(tb_fifo_rd_en == 1'b1,
        "Unknown opcode: DUT must return to READ_ST (rd_en=1)");
`SVTEST_END

//--------------------------------------------------------------------------
// test10: Sequential instructions
//   Two consecutive SETI instructions dispatched one after the other,
//   verifying that DUT correctly cycles through READ_ST between them.
//--------------------------------------------------------------------------
`SVTEST(test10_sequential_instructions)
    logic [215:0] word_a, word_b;
    logic [159:0] expected_a, expected_b;

    word_a     = build_word(32'h1111_1111, '0, '0, '0, '0, 48'd0, OP_SETI);
    word_b     = build_word(32'h2222_2222, '0, '0, '0, '0, 48'd0, OP_SETI);
    expected_a = {128'b0, 32'h1111_1111};
    expected_b = {128'b0, 32'h2222_2222};

    cb.tb_t_cnt <= 48'd100;

    // First instruction
    present_instruction(word_a);
    @(cb);
    `FAIL_UNLESS_LOG(tb_m_axis_tdata == expected_a,
        $sformatf("Seq test01: tdata mismatch A: got 0x%040h", tb_m_axis_tdata));

    // Second instruction
    present_instruction(word_b);
    @(cb);
    `FAIL_UNLESS_LOG(tb_m_axis_tdata == expected_b,
        $sformatf("Seq test02: tdata mismatch B: got 0x%040h", tb_m_axis_tdata));
`SVTEST_END

//--------------------------------------------------------------------------
// test11: Timestamp exact boundary
//   Verify dispatch occurs when t_cnt == t_inst (not strictly greater).
//--------------------------------------------------------------------------
`SVTEST(test11_timestamp_exact_boundary)
    logic [215:0] word;
    logic [47:0]  t_target;

    t_target = 48'd42;
    word = build_word(32'hBEEF_CAFE, '0, '0, '0, '0, t_target, OP_SETI);

    cb.tb_t_cnt <= 48'd41; // one below target
    present_instruction(word);

    // Held in WAIT_ST
    @(cb);
    `FAIL_UNLESS_LOG(tb_m_axis_tvalid == 1'b0,
        "Boundary: must not dispatch at t_cnt = t_inst - 1");

    // Exact match
    advance_time(t_target);
    @(cb);
    `FAIL_UNLESS_LOG(tb_m_axis_tvalid == 1'b1,
        "Boundary: must dispatch at t_cnt == t_inst");
`SVTEST_END
