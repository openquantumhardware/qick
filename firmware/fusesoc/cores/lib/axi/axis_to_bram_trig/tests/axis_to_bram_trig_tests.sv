// ============================================================================
// File: axis_to_bram_trig_tests.sv
// Description: SVUnit test cases for axis_to_bram_trig.
// Included by axis_to_bram_trig_tc00.sv.
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
// TEST 02: capture_reg=0 — trigger ignored, no writes
// ----------------------------------------------------------------------------
`SVTEST(test_no_capture_reg_ignores_trigger)
    pulse_trigger();
    repeat(10) @(tb_cb);
    `FAIL_IF(bram_if_i.we);
    `FAIL_IF(axis_if.tready);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Armed but no trigger — tready stays low
// ----------------------------------------------------------------------------
`SVTEST(test_armed_no_trigger_no_tready)
    arm();
    repeat(10) @(tb_cb);
    `FAIL_IF(axis_if.tready);
    `FAIL_IF(bram_if_i.we);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: Full capture — correct data written to BRAM addresses 0..DEPTH-1
// ----------------------------------------------------------------------------
`SVTEST(test_full_capture_data)
    logic [B-1:0] expected [DEPTH];
    logic [B-1:0] actual [];

    for (int i = 0; i < DEPTH; i++) expected[i] = B'(i + 1);

    arm();
    pulse_trigger();
    fork
        stream_data(DEPTH, B'(1));
        wait_capture_done();
    join

    read_mem(actual);
    verify_data(expected, actual, "test_full_capture_data");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: Full capture — addresses written sequentially 0..DEPTH-1
// ----------------------------------------------------------------------------
`SVTEST(test_full_capture_addresses)
    arm();
    pulse_trigger();

    fork
        stream_data(DEPTH, B'(1));
        begin
            for (int i = 0; i < DEPTH; i++) begin
                // Wait for rising edge where we is asserted
                @(posedge tb_clk iff bram_if_i.we);
                // Read addr directly — without skew from the clocking block
                if (bram_if_i.addr !== N'(i)) begin
                    $display("[FAIL] test_full_capture_addresses: addr[%0d]=0x%0h expected 0x%0h",
                             i, bram_if_i.addr, N'(i));
                    `FAIL_IF(1);
                end
            end
        end
    join
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: FSM stops after DEPTH writes — extra stream data discarded
// ----------------------------------------------------------------------------
`SVTEST(test_stops_at_depth)
    int extra_writes = 0;

    arm();
    pulse_trigger();

    fork
        stream_data(DEPTH * 2, B'(1));
        wait_capture_done();
    join_any;

    disable fork; // Stop stream_data if it continues sending after END_ST

    // After END_ST should not occur more writes
    repeat(30) @(tb_cb);

    // Verify that there were no spurious writes after DEPTH
    for (int i = 0; i < 10; i++) begin
        @(tb_cb);
        if (bram_if_i.we) extra_writes++;
    end

    `FAIL_IF(extra_writes > 0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: Re-arm after capture — second capture works correctly
// ----------------------------------------------------------------------------
`SVTEST(test_rearm_second_capture)
    logic [B-1:0] expected [DEPTH];
    logic [B-1:0] actual [];

    // First capture with value 0xAAAA
    arm();
    pulse_trigger();
    fork
        stream_data(DEPTH, B'(16'hAAAA));
        wait_capture_done();
    join
    disarm();

    // Clear BRAM model for second capture verification
    for (int i = 0; i < DEPTH; i++) mem[i] = '0;

    // Second capture with value 0xBBBB
    for (int i = 0; i < DEPTH; i++) expected[i] = B'(16'hBBBB + i);

    arm();
    pulse_trigger();
    fork
        stream_data(DEPTH, B'(16'hBBBB));
        wait_capture_done();
    join

    read_mem(actual);
    verify_data(expected, actual, "test_rearm_second_capture");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: Trigger before arm — stale trigger must not start capture
// ----------------------------------------------------------------------------
`SVTEST(test_trigger_before_arm_ignored)
    int early_writes = 0;

    // Trigger before arming — must be ignored
    pulse_trigger();
    repeat(5) @(tb_cb);

    // Arm — FSM goes to TRIGGER_ST, needs a fresh trigger
    arm();

    // No writes should occur without new trigger
    repeat(15) @(tb_cb) begin
        if (bram_if_i.we) early_writes++;
    end

    `FAIL_IF(early_writes > 0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 09: Reset during capture — stops all writes
// ----------------------------------------------------------------------------
`SVTEST(test_reset_during_capture)
    int writes_after_reset = 0;

    arm();
    pulse_trigger();

    // Send a few samples then reset
    axis_if.m_cb.tvalid <= 1'b1;
    axis_if.m_cb.tdata  <= B'(16'h1234);
    repeat(4) @(tb_cb);

    // Assert reset
    tb_cb.tb_rstn       <= 1'b0;
    axis_if.m_cb.tvalid <= 1'b0;
    repeat(5) @(tb_cb);
    tb_cb.tb_rstn <= 1'b1;
    repeat(20) @(tb_cb); // XPM FIFO settling

    // No writes should occur after reset
    repeat(10) @(tb_cb) begin
        if (bram_if_i.we) writes_after_reset++;
    end

    `FAIL_IF(writes_after_reset > 0);
    `FAIL_IF(axis_if.tready);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 10: mem_en always asserted
// ----------------------------------------------------------------------------
`SVTEST(test_mem_en_always_asserted)
    `FAIL_IF(!bram_if_i.en);
    arm();
    `FAIL_IF(!bram_if_i.en);
    pulse_trigger();
    `FAIL_IF(!bram_if_i.en);
    repeat(5) @(tb_cb);
    `FAIL_IF(!bram_if_i.en);
`SVTEST_END
