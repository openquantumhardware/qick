// ============================================================================
// File: axis_to_bram_sg_tests.sv
// Description: SVUnit test cases for axis_to_bram_sg.
// Included by axis_to_bram_sg_tc00.sv.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Reset — no writes, tready low
// ----------------------------------------------------------------------------
`SVTEST(test_reset_no_write)
    repeat(5) @(tb_cb);
    `FAIL_IF(bram_if_i.we);
    `FAIL_IF(axis_if.tready);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: capture_reg=0 — tready never asserts
// ----------------------------------------------------------------------------
`SVTEST(test_idle_no_tready)
    tb_cb.tb_capture_reg <= 1'b0;
    repeat(10) @(tb_cb);
    `FAIL_IF(axis_if.tready);
    `FAIL_IF(bram_if_i.we);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Enable writer — tready asserts after FSM reaches WAIT_TVALID_ST
// ----------------------------------------------------------------------------
`SVTEST(test_enable_asserts_tready)
    enable_writer(32'd0);
    repeat(2) @(tb_cb);
    `FAIL_IF(!axis_if.tready);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: Single write — correct address and data in BRAM
// Pipeline of 3 stages: BRAM sees data 3 cycles after handshake.
// ----------------------------------------------------------------------------
`SVTEST(test_single_write)
    enable_writer(32'd10);
    stream_data(1, B'(16'hABCD));
    wait_pipeline();
    verify_mem(10, B'(16'hABCD), "test_single_write");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: Sequential writes — addresses auto-increment from start_addr
// ----------------------------------------------------------------------------
`SVTEST(test_address_increment)
    localparam int COUNT = 8;
    localparam int START = 5;

    enable_writer(32'(START));
    stream_data(COUNT, B'(16'h0001));
    wait_pipeline();

    for (int i = 0; i < COUNT; i++)
        verify_mem(START + i, B'(16'h0001 + i), "test_address_increment");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: Data pipeline — mem data matches sent data in order
// ----------------------------------------------------------------------------
`SVTEST(test_data_pipeline)
    localparam int COUNT = 4;

    enable_writer(32'd0);
    stream_data(COUNT, B'(16'h0010));
    wait_pipeline();

    for (int i = 0; i < COUNT; i++)
        verify_mem(i, B'(16'h0010 + i), "test_data_pipeline");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: Start address register — two bursts at different addresses
// ----------------------------------------------------------------------------
`SVTEST(test_start_addr_register)
    localparam int START_A = 20;
    localparam int START_B = 50;

    enable_writer(32'(START_A));
    stream_data(2, B'(16'hAAAA));
    wait_pipeline();
    verify_mem(START_A,     B'(16'hAAAA), "test_start_addr_A[0]");
    verify_mem(START_A + 1, B'(16'hAAAB), "test_start_addr_A[1]");
    disable_writer();

    enable_writer(32'(START_B));
    stream_data(2, B'(16'hBBBB));
    wait_pipeline();
    verify_mem(START_B,     B'(16'hBBBB), "test_start_addr_B[0]");
    verify_mem(START_B + 1, B'(16'hBBBC), "test_start_addr_B[1]");
    disable_writer();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: tvalid gap — FSM returns to WAIT_TVALID_ST, no spurious writes
// Send 2 samples, stall valid, send 2 more.
// Verify all 4 end up in consecutive BRAM addresses.
// ----------------------------------------------------------------------------
`SVTEST(test_tvalid_gap)
    enable_writer(32'd0);

    // First 2 samples
    stream_data(2, B'(16'h0001));

    // Gap: valid=0 for 5 cycles — FSM goes to WAIT_TVALID_ST
    repeat(5) @(tb_cb);

    // Resume: 2 more samples
    stream_data(2, B'(16'h0003));
    wait_pipeline();

    // All 4 samples consecutive in BRAM from addr 0
    verify_block(0, 4, B'(16'h0001), "test_tvalid_gap");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 09: Disable mid-stream — FSM returns to INIT_ST, writes stop
// ----------------------------------------------------------------------------
`SVTEST(test_disable_stops_writes)
    int writes_after = 0;

    enable_writer(32'd0);

    // Send 3 samples
    stream_data(3, B'(16'h0001));

    // Disable
    disable_writer();

    // No writes should occur after disable settled
    for (int i = 0; i < 10; i++) begin
        @(tb_cb);
        if (bram_if_i.we) writes_after++;
    end

    `FAIL_IF(writes_after > 0);
    `FAIL_IF(axis_if.tready);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 10: Reset during operation — writes stop, FSM returns to INIT_ST
// ----------------------------------------------------------------------------
`SVTEST(test_reset_during_operation)
    int writes_after_reset = 0;

    enable_writer(32'd0);

    axis_if.m_cb.tvalid <= 1'b1;
    axis_if.m_cb.tdata  <= B'(16'h1234);
    repeat(3) @(tb_cb);

    // Bajar capture_reg Y resetear
    tb_cb.tb_capture_reg <= 1'b0;
    tb_cb.tb_rstn        <= 1'b0;
    axis_if.m_cb.tvalid  <= 1'b0;
    repeat(5) @(tb_cb);
    tb_cb.tb_rstn <= 1'b1;
    repeat(10) @(tb_cb); // más margen para CDC

    for (int i = 0; i < 5; i++) begin
        @(tb_cb);
        if (bram_if_i.we) writes_after_reset++;
    end

    `FAIL_IF(writes_after_reset > 0);
    `FAIL_IF(axis_if.tready);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 11: bram.en always asserted
// ----------------------------------------------------------------------------
`SVTEST(test_bram_en_always_asserted)
    `FAIL_IF(!bram_if_i.en);
    enable_writer(32'd0);
    `FAIL_IF(!bram_if_i.en);
    stream_data(2, B'(1));
    `FAIL_IF(!bram_if_i.en);
    disable_writer();
    `FAIL_IF(!bram_if_i.en);
`SVTEST_END
