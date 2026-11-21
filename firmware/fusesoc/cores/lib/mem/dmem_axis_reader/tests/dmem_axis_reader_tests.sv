// ============================================================================
// File: dmem_axis_reader_tests.sv
// Description: SVUnit test cases for dmem_axis_reader.
// Included by dmem_axis_reader_tc00.sv.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Reset — FSM in INIT, no tvalid, no ack
// ----------------------------------------------------------------------------
`SVTEST(test_reset_idle)
    repeat(5) @(tb_cb);
    `FAIL_IF(u_dut.state !== INIT_ST);
    `FAIL_IF(axis_if.tvalid);
    `FAIL_IF(tb_exec_ack_o);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: No exec — FSM stays in INIT, no stream activity
// ----------------------------------------------------------------------------
`SVTEST(test_idle_no_exec)
    set_tready(1'b1);
    repeat(10) @(tb_cb);
    `FAIL_IF(u_dut.state !== INIT_ST);
    `FAIL_IF(axis_if.tvalid);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Single-word read — one beat, tlast asserted, correct data
// ----------------------------------------------------------------------------
`SVTEST(test_single_word_read)
    logic [B-1:0] expected [];
    logic [B-1:0] actual [];
    logic         saw_tlast;
    preload_mem(0, 1, B'(16'hABCD));
    expected = new[1];
    expected[0] = 16'hABCD;
    start_read(N'(0), N'(1));
    collect_stream(1, actual, saw_tlast);
    verify_data(expected, actual, "test_single_word_read");
    `FAIL_IF(!saw_tlast);
    wait_state(END_ST);
    finish_read();
    wait_state(INIT_ST);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: Multi-word read — sequential data streamed correctly
// ----------------------------------------------------------------------------
`SVTEST(test_multi_word_read)
    localparam int LEN = 8;
    logic [B-1:0] expected [];
    logic [B-1:0] actual [];
    logic         saw_tlast;
    preload_mem(0, LEN, B'(16'h1000));
    expected = new[LEN];
    for (int i = 0; i < LEN; i++) expected[i] = 16'h1000 + B'(i);
    start_read(N'(0), N'(LEN));
    collect_stream(LEN, actual, saw_tlast);
    verify_data(expected, actual, "test_multi_word_read");
    `FAIL_IF(!saw_tlast);
    wait_state(END_ST);
    finish_read();
    wait_state(INIT_ST);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: Read from non-zero start address
// ----------------------------------------------------------------------------
`SVTEST(test_read_offset_address)
    localparam int LEN  = 4;
    localparam int ADDR = 10'h040;
    logic [B-1:0] expected [];
    logic [B-1:0] actual [];
    logic         saw_tlast;
    preload_mem(ADDR, LEN, B'(16'h5500));
    expected = new[LEN];
    for (int i = 0; i < LEN; i++) expected[i] = 16'h5500 + B'(i);
    start_read(N'(ADDR), N'(LEN));
    collect_stream(LEN, actual, saw_tlast);
    verify_data(expected, actual, "test_read_offset_address");
    `FAIL_IF(!saw_tlast);
    wait_state(END_ST);
    finish_read();
    wait_state(INIT_ST);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: tlast only on last beat — count tlast assertions == 1
// ----------------------------------------------------------------------------
`SVTEST(test_tlast_only_last_beat)
    localparam int LEN = 5;
    int beats     = 0;
    int tlast_cnt = 0;
    preload_mem(0, LEN, B'(16'h2000));
    start_read(N'(0), N'(LEN));
    set_tready(1'b1);
    while (beats < LEN) begin
        @(axis_if.s_cb);
        if (axis_if.s_cb.tvalid && axis_if.tready) begin
            if (axis_if.s_cb.tlast) tlast_cnt++;
            beats++;
        end
    end
    set_tready(1'b0);
    `FAIL_IF(tlast_cnt != 1);
    wait_state(END_ST);
    finish_read();
    wait_state(INIT_ST);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: Backpressure — tready toggling does not lose/duplicate data
// ----------------------------------------------------------------------------
`SVTEST(test_backpressure)
    localparam int LEN = 8;
    logic [B-1:0] expected [LEN];
    logic [B-1:0] actual [$];
    int idx = 0;
    logic saw_tlast = 1'b0;
    for (int i = 0; i < LEN; i++) expected[i] = 16'h3000 + B'(i);
    preload_mem(0, LEN, B'(16'h3000));
    start_read(N'(0), N'(LEN));
    // Toggle tready: accept one beat, stall one cycle, repeat
    while (idx < LEN) begin
        set_tready(1'b1);
        @(axis_if.s_cb);
        if (axis_if.s_cb.tvalid && axis_if.tready) begin
            actual.push_back(axis_if.s_cb.tdata);
            if (axis_if.s_cb.tlast) saw_tlast = 1'b1;
            idx++;
        end
        // stall
        set_tready(1'b0);
        repeat(2) @(axis_if.s_cb);
    end
    set_tready(1'b0);
    `FAIL_IF(actual.size() != LEN);
    for (int i = 0; i < LEN; i++) begin
        if (actual[i] !== expected[i]) begin
            $display("MISMATCH test_backpressure [%0d]: exp 0x%0h got 0x%0h",
                     i, expected[i], actual[i]);
            `FAIL_IF(1);
        end
    end
    `FAIL_IF(!saw_tlast);
    wait_state(END_ST);
    finish_read();
    wait_state(INIT_ST);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: tvalid only asserted during SEND_ST
// ----------------------------------------------------------------------------
`SVTEST(test_tvalid_only_in_send)
    localparam int LEN = 4;
    preload_mem(0, LEN, B'(16'h4000));
    // Before exec: tvalid must be low
    `FAIL_IF(axis_if.tvalid);
    start_read(N'(0), N'(LEN));
    // During LOAD states tvalid must remain low
    wait_state(LOAD0_ST);
    `FAIL_IF(axis_if.tvalid);
    wait_state(LOAD1_ST);
    `FAIL_IF(axis_if.tvalid);
    // Stream out
    set_tready(1'b1);
    wait_state(ACK_ST);
    set_tready(1'b0);
    wait_state(END_ST);
    finish_read();
    wait_state(INIT_ST);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 09: exec_ack handshake — ACK asserted, returns to INIT on exec low
// ----------------------------------------------------------------------------
`SVTEST(test_exec_ack_handshake)
    localparam int LEN = 3;
    logic [B-1:0] actual [];
    logic         saw_tlast;
    preload_mem(0, LEN, B'(16'h6000));
    start_read(N'(0), N'(LEN));
    collect_stream(LEN, actual, saw_tlast);
    // FSM should reach ACK then END
    wait_state(END_ST);
    // exec still high -> stays in END
    repeat(5) @(tb_cb) `FAIL_IF(u_dut.state !== END_ST);
    finish_read();
    wait_state(INIT_ST);
    `FAIL_IF(u_dut.state !== INIT_ST);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 10: Back-to-back reads — second transaction after first completes
// ----------------------------------------------------------------------------
`SVTEST(test_back_to_back_reads)
    localparam int LEN = 4;
    logic [B-1:0] expected [];
    logic [B-1:0] actual [];
    logic         saw_tlast;
    // First read
    preload_mem(0, LEN, B'(16'h7000));
    expected = new[LEN];
    for (int i = 0; i < LEN; i++) expected[i] = 16'h7000 + B'(i);
    start_read(N'(0), N'(LEN));
    collect_stream(LEN, actual, saw_tlast);
    verify_data(expected, actual, "test_back_to_back_reads (1st)");
    wait_state(END_ST);
    finish_read();
    wait_state(INIT_ST);
    // Second read at different address
    preload_mem(10'h080, LEN, B'(16'h8000));
    expected = new[LEN];
    for (int i = 0; i < LEN; i++) expected[i] = 16'h8000 + B'(i);
    start_read(N'(10'h080), N'(LEN));
    collect_stream(LEN, actual, saw_tlast);
    verify_data(expected, actual, "test_back_to_back_reads (2nd)");
    wait_state(END_ST);
    finish_read();
    wait_state(INIT_ST);
`SVTEST_END