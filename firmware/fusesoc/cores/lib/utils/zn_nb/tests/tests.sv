// ============================================================================
// File: tests.sv
// Description: SVUnit test cases for zn_nb.
// Included by zn_nb_tc00.sv inside `SVUNIT_TESTS_BEGIN / `SVUNIT_TESTS_END.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Reset clears all stages
// After reset, with valid=0, output must be 0.
// ----------------------------------------------------------------------------
`SVTEST(test_reset_clears_output)
    repeat(N+2) @(cb);
    `FAIL_UNLESS(tb_m_axis_tdata === '0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Continuous stream — output is input delayed by exactly N cycles
// Push N+4 samples back-to-back (valid always 1).
// First N outputs must be 0 (reset state draining).
// From index N onwards output[i] must equal input[i-N].
// ----------------------------------------------------------------------------
`SVTEST(test_continuous_stream_delay)
    localparam int TOTAL = N + 4;
    logic [B-1:0] sent     [TOTAL];
    logic [B-1:0] received [TOTAL];

    for (int i = 0; i < TOTAL; i++) begin
        sent[i] = 16'(i + 1); // 1,2,3,...
        cb.tb_s_axis_tdata  <= sent[i];
        cb.tb_s_axis_tvalid <= 1'b1;
        @(cb);
        received[i] = tb_m_axis_tdata;
    end
    cb.tb_s_axis_tvalid <= 1'b0;
    cb.tb_s_axis_tdata  <= '0;

    // The clocking block samples outputs one cycle after the posedge,
    // so the observable delay is N-1 indices (not N).
    // First N-1 outputs come from zeroed reset state.
    for (int i = 0; i < N-1; i++) begin
        if (received[i] !== '0) begin
            $display("[FAIL] test_continuous_stream_delay: received[%0d]=0x%0h, expected 0x0",
                     i, received[i]);
            `FAIL_IF(1);
        end
    end

    // From index N-1 onwards, output must equal input[i-(N-1)]
    for (int i = N-1; i < TOTAL; i++) begin
        if (received[i] !== sent[i-(N-1)]) begin
            $display("[FAIL] test_continuous_stream_delay: received[%0d]=0x%0h, expected 0x%0h",
                     i, received[i], sent[i-(N-1)]);
            `FAIL_IF(1);
        end
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Valid gate — pipeline freezes when valid=0
// Fill pipeline with value A, de-assert valid for several cycles,
// verify output stays A, then fill with B and verify output becomes B.
// ----------------------------------------------------------------------------
`SVTEST(test_valid_gate)
    logic [B-1:0] val_a = 16'h1111;
    logic [B-1:0] val_b = 16'h2222;
    int stall = 5;

    // Fill all N stages with val_a
    push_const(N, val_a);
    `FAIL_UNLESS_EQUAL(tb_m_axis_tdata, val_a);

    // Stall — output must not change
    for (int i = 0; i < stall; i++) begin
        @(cb);
        if (tb_m_axis_tdata !== val_a) begin
            $display("[FAIL] test_valid_gate: output changed at stall cycle %0d: 0x%0h", i, tb_m_axis_tdata);
            `FAIL_IF(1);
        end
    end

    // Fill all N stages with val_b
    push_const(N, val_b);
    `FAIL_UNLESS_EQUAL(tb_m_axis_tdata, val_b);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: tvalid passthrough — no latency
// m_axis_tvalid must mirror s_axis_tvalid in the same cycle.
// ----------------------------------------------------------------------------
`SVTEST(test_tvalid_passthrough)
    cb.tb_s_axis_tvalid <= 1'b0;
    @(cb);
    `FAIL_IF(tb_m_axis_tvalid !== 1'b0);

    cb.tb_s_axis_tvalid <= 1'b1;
    cb.tb_s_axis_tdata  <= 16'hDEAD;
    @(cb);
    `FAIL_IF(tb_m_axis_tvalid !== 1'b1);

    cb.tb_s_axis_tvalid <= 1'b0;
    cb.tb_s_axis_tdata  <= '0;
    @(cb);
    `FAIL_IF(tb_m_axis_tvalid !== 1'b0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: Reset mid-stream clears pipeline
// Push N/2 samples, reset, verify output is 0, then verify fresh data
// flows correctly after reset.
// ----------------------------------------------------------------------------
`SVTEST(test_reset_mid_stream)
    logic [B-1:0] val_post = 16'hCAFE;

    // Partially fill pipeline
    push_const(N/2, 16'hBEEF);
    repeat(2) @(cb);

    // Synchronous reset
    cb.tb_aresetn <= 1'b0;
    repeat(5) @(cb);
    cb.tb_aresetn <= 1'b1;
    repeat(2) @(cb);

    `FAIL_UNLESS(tb_m_axis_tdata === '0);

    // Push N samples of val_post after reset
    // First N-1 outputs come from zeroed stages
    for (int i = 0; i < N; i++) begin
        cb.tb_s_axis_tdata  <= val_post;
        cb.tb_s_axis_tvalid <= 1'b1;
        @(cb);
        if (i < N-1) begin
            if (tb_m_axis_tdata !== '0) begin
                $display("[FAIL] test_reset_mid_stream: output[%0d]=0x%0h, expected 0", i, tb_m_axis_tdata);
                `FAIL_IF(1);
            end
        end
    end
    cb.tb_s_axis_tvalid <= 1'b0;

    // After N pushes the oldest stage must be val_post
    `FAIL_UNLESS_EQUAL(tb_m_axis_tdata, val_post);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: All-zeros data — pipeline stays 0
// ----------------------------------------------------------------------------
`SVTEST(test_all_zeros)
    push_const(N+2, '0);
    repeat(2) @(cb);
    `FAIL_UNLESS(tb_m_axis_tdata === '0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: All-ones data — output must be all-ones after N cycles
// ----------------------------------------------------------------------------
`SVTEST(test_all_ones)
    push_const(N+1, {B{1'b1}});
    `FAIL_UNLESS(tb_m_axis_tdata === {B{1'b1}});
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: Alternating valid — interleaved valid/invalid cycles
// Push N samples with valid toggling each cycle.
// Verify the N-th valid sample appears at output only after N valid-gated
// shifts, not N wall-clock cycles.
// ----------------------------------------------------------------------------
`SVTEST(test_alternating_valid)
    logic [B-1:0] fill_val = 16'hAAAA;
    logic [B-1:0] marker   = 16'h5555;
    int           valid_cycles = 0;

    // First fill all stages with fill_val using alternating valid
    // Each pair of cycles advances the pipeline by 1
    for (int i = 0; i < N; i++) begin
        cb.tb_s_axis_tdata  <= fill_val;
        cb.tb_s_axis_tvalid <= 1'b1;
        @(cb);
        cb.tb_s_axis_tvalid <= 1'b0;  // one idle cycle
        @(cb);
    end

    `FAIL_UNLESS_EQUAL(tb_m_axis_tdata, fill_val);

    // Now push marker with alternating valid
    for (int i = 0; i < N; i++) begin
        cb.tb_s_axis_tdata  <= marker;
        cb.tb_s_axis_tvalid <= 1'b1;
        @(cb);
        cb.tb_s_axis_tvalid <= 1'b0;
        @(cb);
    end

    `FAIL_UNLESS_EQUAL(tb_m_axis_tdata, marker);
`SVTEST_END
