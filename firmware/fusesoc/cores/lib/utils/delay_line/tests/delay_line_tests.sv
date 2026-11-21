// ============================================================================
// File: delay_line_tests.sv
// Description: SVUnit test cases for delay_line. Included by delay_line_tc00.sv.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Reset clears the output to 0.
// ----------------------------------------------------------------------------
`SVTEST(tc_reset_zero)
    `FAIL_IF(tb_data_o !== '0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Exact N-cycle latency for a single impulse.
//   Drive a value for one cycle, then 0. The value must appear on the output
//   exactly N cycles after it was applied.
// ----------------------------------------------------------------------------
`SVTEST(tc_single_impulse_latency)
    logic [M-1:0] val = 16'hABCD;
    @(tb_cb);
    tb_cb.tb_data_i <= val;
    @(tb_cb);
    tb_cb.tb_data_i <= '0;
    // After applying 'val' at the edge above, it takes N cycles to reach o_data.
    // We already consumed 1 cycle, so wait N-1 more, then it must be present.
    repeat(N-1) @(tb_cb);
    `FAIL_IF(tb_data_o !== val);
    // The next cycle it should be gone (back to 0, since we drove 0 after).
    @(tb_cb);
    `FAIL_IF(tb_data_o !== '0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Continuous stream matches a reference queue (delayed by N).
// ----------------------------------------------------------------------------
`SVTEST(tc_stream_reference)
    logic [M-1:0] model [$];   // reference pipeline
    logic [M-1:0] sample;
    logic [M-1:0] expected;
    // Prime the model with N zeros (current pipeline contents after reset)
    for (int i = 0; i < N; i++) model.push_back('0);
    for (int i = 0; i < 64; i++) begin
        sample = $urandom_range(0, (1<<M)-1);
        @(tb_cb);
        tb_cb.tb_data_i <= sample;
        // expected output this cycle = value that entered N cycles ago
        expected = model.pop_front();
        model.push_back(sample);
        // o_data is sampled (input #1step) reflecting the value before this edge
        if (tb_data_o !== expected) begin
            $display("STREAM MISMATCH step %0d: exp 0x%0h got 0x%0h",
                     i, expected, tb_data_o);
            `FAIL_IF(1);
        end
    end
    tb_cb.tb_data_i <= '0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: Constant input propagates and holds after N cycles.
// ----------------------------------------------------------------------------
`SVTEST(tc_constant_hold)
    logic [M-1:0] val = 16'h5A5A;
    @(tb_cb);
    tb_cb.tb_data_i <= val;
    // wait the latency
    repeat(N) @(tb_cb);
    // now the output must be the constant and stay there
    repeat(5) @(tb_cb) begin
        `FAIL_IF(tb_data_o !== val);
    end
    tb_cb.tb_data_i <= '0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: Reset mid-stream clears the pipeline.
// ----------------------------------------------------------------------------
`SVTEST(tc_reset_midstream)
    logic [M-1:0] val = 16'hF0F0;
    @(tb_cb);
    tb_cb.tb_data_i <= val;
    repeat(2) @(tb_cb);
    // assert reset
    tb_cb.tb_rstn   <= 1'b0;
    tb_cb.tb_data_i <= '0;
    repeat(N+1) @(tb_cb);
    `FAIL_IF(tb_data_o !== '0);
    tb_cb.tb_rstn <= 1'b1;
    repeat(2) @(tb_cb);
    `FAIL_IF(tb_data_o !== '0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: Explicit latency measurement — inject a unique marker and count the
//   exact number of cycles until it appears on the output. Confirms latency == N
//   with a direct measurement (documented for downstream latency budgeting).
// ----------------------------------------------------------------------------
`SVTEST(tc_measure_latency)
    logic [M-1:0] marker = 16'hBEEF & ((1<<M)-1);
    int lat;
    lat = -1;
    tb_cb.tb_data_i <= marker;      // apply marker
    @(tb_cb);                        // it is captured at THIS edge -> counts as cycle 1
    tb_cb.tb_data_i <= '0;
    for (int c = 1; c < N + 8; c++) begin
        if (lat == -1 && tb_data_o === marker) lat = c;
        @(tb_cb);
    end
    $display("DELAY_LINE latency measured = %0d (parameter N = %0d)", lat, N);
    `FAIL_IF(lat !== N);
`SVTEST_END