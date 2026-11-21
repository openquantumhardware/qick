///////////////////////////////////////////////////////////////////////////////
// iir_1p1z_tests.sv  —  SVUnit test cases for iir_1p1z
// Included inside iir_1p1z_unit_test between `SVUNIT_TESTS_BEGIN/END`.
///////////////////////////////////////////////////////////////////////////////

//-----------------------------------------------------------------------------
// TEST 1: Reset clears outputs.
//-----------------------------------------------------------------------------
`SVTEST(test_reset_clears_output)
    i_c0 = 16'sh2000; i_c1 = 16'sh4000; i_g = 16'sh4000;
    do_reset();
    `FAIL_UNLESS(o_valid === 1'b0);
    `FAIL_UNLESS(o_data  === '0);
`SVTEST_END

//-----------------------------------------------------------------------------
// TEST 2: Output latency is exactly LAT (=4) valid cycles.
//   Push a single valid, count clocks until o_valid rises.
//-----------------------------------------------------------------------------
`SVTEST(test_latency_is_four)
    int cnt;
    i_c0 = 16'sh0000; i_c1 = 16'sh0000; i_g = 16'sh7FFF;
    do_reset();

    // Drive one valid pulse aligned to a clock edge.
    @(posedge tb_clk);
    i_data  <= 16'sh0100;
    i_valid <= 1'b1;
    @(posedge tb_clk);
    i_valid <= 1'b0;

    // i_valid was high for the cycle sampled at the edge above => that is t=0.
    // Count edges until o_valid asserts.
    cnt = 0;
    fork : latency_watch
        begin
            forever begin
                @(posedge tb_clk);
                cnt++;
                if (o_valid) disable latency_watch;
                if (cnt > 20) begin
                    `FAIL_IF_LOG(1, "o_valid never asserted")
                    disable latency_watch;
                end
            end
        end
    join
    // o_valid appears LAT cycles after the sampled valid.
    `FAIL_UNLESS_LOG(cnt == LAT,
        $sformatf("expected latency %0d, got %0d", LAT, cnt))
`SVTEST_END

//-----------------------------------------------------------------------------
// TEST 3: Impulse response matches the golden model (continuous valid).
//   Feed-forward + feedback exercised. G=1.0 (0x7FFF ~ +1), C0, C1 set.
//-----------------------------------------------------------------------------
`SVTEST(test_impulse_matches_model)
    logic signed [B-1:0] stim [];
    logic signed [B-1:0] exp_q [$];
    int  n;

    i_c0 = 16'sh2000;   // 0.25
    i_c1 = 16'sh6000;   // 0.75  (stable pole)
    i_g  = 16'sh7FFF;   // ~1.0
    do_reset();

    // Impulse then zeros.
    n = 24;
    stim = new[n];
    stim[0] = 16'sh0400;                 // impulse amplitude
    for (int k = 1; k < n; k++) stim[k] = '0;

    // Pre-compute golden outputs.
    for (int k = 0; k < n; k++) exp_q.push_back(ref_step(stim[k]));

    // Drive continuously and check each accepted output.
    fork
        // producer
        begin
            for (int k = 0; k < n; k++) begin
                @(posedge tb_clk);
                i_data  <= stim[k];
                i_valid <= 1'b1;
            end
            @(posedge tb_clk);
            i_valid <= 1'b0;
        end
        // consumer: on every o_valid, pop expected and compare
        begin
            int got = 0;
            while (got < n) begin
                @(posedge tb_clk);
                if (o_valid) begin
                    `FAIL_UNLESS_LOG(o_data === exp_q[got],
                        $sformatf("sample %0d: got %0h exp %0h",
                                  got, o_data, exp_q[got]))
                    got++;
                end
            end
        end
    join
`SVTEST_END

//-----------------------------------------------------------------------------
// TEST 4 (REGRESSION for the begin/end bug):
//   The SAME input sequence produces the SAME outputs whether driven
//   back-to-back or with random valid bubbles. Fails on the original RTL
//   (state y1_r1a/y1_r1b and xn_r1/y0_r1 desync under bubbles).
//-----------------------------------------------------------------------------
`SVTEST(test_bubbles_match_continuous)
    localparam int NS = 16;
    logic signed [B-1:0] stim [NS];
    logic signed [B-1:0] out_cont [NS];
    logic signed [B-1:0] out_bub  [NS];
    int idx;

    i_c0 = 16'sh1999;   // ~0.2
    i_c1 = 16'sh6666;   // ~0.8 (stable)
    i_g  = 16'sh7FFF;

    // Deterministic pseudo-random stimulus.
    for (int k = 0; k < NS; k++)
        stim[k] = $signed(16'($random)) >>> 2;   // keep some headroom

    // ---- Pass A: continuous valid ----
    do_reset();
    idx = 0;
    fork
        begin
            for (int k = 0; k < NS; k++) begin
                @(posedge tb_clk);
                i_data  <= stim[k];
                i_valid <= 1'b1;
            end
            @(posedge tb_clk);
            i_valid <= 1'b0;
        end
        begin
            while (idx < NS) begin
                @(posedge tb_clk);
                if (o_valid) out_cont[idx++] = o_data;
            end
        end
    join

    // ---- Pass B: same stimulus, bubbles between samples ----
    do_reset();
    idx = 0;
    fork
        begin
            for (int k = 0; k < NS; k++) begin
                // 0..3 bubble cycles before each sample
                bubble(($unsigned($random) % 4));
                @(posedge tb_clk);
                i_data  <= stim[k];
                i_valid <= 1'b1;
                @(posedge tb_clk);
                i_valid <= 1'b0;
            end
        end
        begin
            while (idx < NS) begin
                @(posedge tb_clk);
                if (o_valid) out_bub[idx++] = o_data;
            end
        end
    join

    // ---- Compare: bubble path must equal continuous path ----
    for (int k = 0; k < NS; k++)
        `FAIL_UNLESS_LOG(out_bub[k] === out_cont[k],
            $sformatf("bubble mismatch @%0d: cont %0h bub %0h",
                      k, out_cont[k], out_bub[k]))
`SVTEST_END

//-----------------------------------------------------------------------------
// TEST 5: DC gain sanity. For a step input, steady-state should approach
//   G*(1-C0)/(1-C1) * x  (within fixed-point tolerance). Cross-checked
//   against the golden model to stay bit-exact.
//-----------------------------------------------------------------------------
`SVTEST(test_dc_step_matches_model)
    logic signed [B-1:0] exp_last;
    localparam int NS = 40;

    i_c0 = 16'sh1000;   // 0.125
    i_c1 = 16'sh6000;   // 0.75
    i_g  = 16'sh4000;   // 0.5
    do_reset();

    // Golden: run the model on the step to get the expected settled value.
    for (int k = 0; k < NS; k++) exp_last = ref_step(16'sh0200);

    // DUT: same step, continuous valid, capture the last accepted output.
    fork
        begin
            for (int k = 0; k < NS; k++) begin
                @(posedge tb_clk);
                i_data  <= 16'sh0200;
                i_valid <= 1'b1;
            end
            @(posedge tb_clk);
            i_valid <= 1'b0;
        end
        begin
            int got = 0;
            logic signed [B-1:0] last;
            while (got < NS) begin
                @(posedge tb_clk);
                if (o_valid) begin last = o_data; got++; end
            end
            `FAIL_UNLESS_LOG(last === exp_last,
                $sformatf("DC settle: got %0h exp %0h", last, exp_last))
        end
    join
`SVTEST_END

//-----------------------------------------------------------------------------
// TEST 6: Feed-back saturation. With a pole close to +1 (C1 high) and a large
//   sustained input, the loop state y1 would overflow BA bits. Without
//   saturation it WRAPS (a big positive value flips negative -> glitch). With
//   the fix it clamps monotonically. We check the DUT matches the SATURATED
//   reference and that the output never wraps (no sign flip once it is high).
//-----------------------------------------------------------------------------
`SVTEST(test_feedback_saturation)
    localparam int NS = 60;
    logic signed [B-1:0] x;
    logic signed [B-1:0] exp_q [$];
    // aggressive pole + high gain + large input to force loop overflow
    i_c0 = 16'sh0000;   // no zero, isolate the pole
    i_c1 = 16'sh7999;   // ~0.95 (very close to +1)
    i_g  = 16'sh7FFF;   // ~1.0
    x    = 16'sh6000;   // large positive step

    do_reset();
    ref_reset_sat();

    // Golden (saturated) expected values.
    for (int k = 0; k < NS; k++) exp_q.push_back(ref_step_sat(x));

    fork
        // producer: sustained large step
        begin
            for (int k = 0; k < NS; k++) begin
                @(posedge tb_clk);
                i_data  <= x;
                i_valid <= 1'b1;
            end
            @(posedge tb_clk);
            i_valid <= 1'b0;
        end
        // consumer: match saturated model + no-wrap check
        begin
            int got = 0;
            logic signed [B-1:0] prev;
            prev = '0;
            while (got < NS) begin
                @(posedge tb_clk);
                if (o_valid) begin
                    // 1) matches the saturated reference exactly
                    `FAIL_UNLESS_LOG(o_data === exp_q[got],
                        $sformatf("sat sample %0d: got %0h exp %0h",
                                  got, o_data, exp_q[got]))
                    // 2) no catastrophic wrap: once the output is large positive
                    //    it must not suddenly flip to large negative.
                    if (got > 5 && prev > 16'sh4000) begin
                        `FAIL_IF_LOG(o_data < -16'sh4000,
                            $sformatf("WRAP detected @%0d: prev %0h now %0h",
                                      got, prev, o_data))
                    end
                    prev = o_data;
                    got++;
                end
            end
        end
    join
`SVTEST_END