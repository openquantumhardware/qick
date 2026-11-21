// ============================================================================
// File: buffer_top_tests.sv
// Description: Test suite for buffer_top module.
// Included inside SVUNIT_TESTS_BEGIN/END.
// All helper tasks are defined in buffer_top_tc00.sv (module scope).
//
// buffer block protocol reminder:
//   - start_reg must stay HIGH through TRIGGER_ST and MEMW_ST.
//   - trigger_i must be pulsed while start_reg is high.
//   - After MEMW_ST drop start_reg to release WAIT_TRIGGER_ST.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 00: Reset state — AXI output must be de-asserted after reset
// ----------------------------------------------------------------------------
`SVTEST(test_reset)
    `FAIL_IF(m_axis_if.tvalid !== 1'b0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 01: Capture + BRAM readout — 4 samples written verbatim, read back
// through the bram_to_axis data reader.
// ----------------------------------------------------------------------------
`SVTEST(test_capture_and_readback)
    logic [2*B-1:0] expected[4];
    logic [2*B-1:0] actual[];
    int timed_out;
    int tlast_errors;

    expected[0] = {16'h0000, 16'h0064}; // I=100
    expected[1] = {16'h0000, 16'h0065};
    expected[2] = {16'h0000, 16'h0066};
    expected[3] = {16'h0000, 16'h0067};

    buf_arm_and_trigger(N'(5), N'(4));

    inject_data(4, {16'h0000, 16'h0064});

    // Release FSM before draining (matches avg_top's own sequencing:
    // BUF_START must drop so a subsequent capture doesn't overwrite the
    // window while it's being read back).
    ctrl_axil_if.axi_write(BUF_START_REG, 32'h0);
    repeat(10) @(axis_cb);

    start_reader(N'(5), (N+1)'(4));
    read_m_data(4, actual, timed_out, tlast_errors, 500);

    if (timed_out) begin
        $display("[FAIL] test_capture_and_readback: timeout waiting for m data");
        `FAIL_IF(1);
    end
    if (tlast_errors) begin
        $display("[FAIL] test_capture_and_readback: %0d tlast error(s)", tlast_errors);
        `FAIL_IF(1);
    end

    verify_data(expected, actual, "test_capture_and_readback");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Two consecutive captures at different addresses — second
// capture's data must not be contaminated by the first.
// ----------------------------------------------------------------------------
`SVTEST(test_consecutive_captures)
    logic [2*B-1:0] expected[2];
    logic [2*B-1:0] actual[];
    int timed_out;
    int tlast_errors;

    // --- First capture ---
    buf_arm_and_trigger(N'(0), N'(2));
    inject_data(2, {16'h0000, 16'h000A}); // I=10, 11
    ctrl_axil_if.axi_write(BUF_START_REG, 32'h0);
    repeat(10) @(axis_cb);

    // --- Second capture (different address/data) ---
    buf_arm_and_trigger(N'(100), N'(2));
    inject_data(2, {16'h0000, 16'h0014}); // I=20, 21
    ctrl_axil_if.axi_write(BUF_START_REG, 32'h0);
    repeat(10) @(axis_cb);

    expected[0] = {16'h0000, 16'h0014};
    expected[1] = {16'h0000, 16'h0015};

    start_reader(N'(100), (N+1)'(2));
    read_m_data(2, actual, timed_out, tlast_errors, 500);

    if (timed_out) begin
        $display("[FAIL] test_consecutive_captures: timeout waiting for m data");
        `FAIL_IF(1);
    end

    verify_data(expected, actual, "test_consecutive_captures");
`SVTEST_END
