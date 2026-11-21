// ============================================================================
// File: axis_resampler_2x1_v1_tests.sv
// Description: SVUnit test cases for axis_resampler_2x1_v1.
// ============================================================================

// Equal to the legacy RTL on every clock, with valid words at random intervals
// of two clocks or more.
`SVTEST(tc_matches_legacy)
    int  errs;
    logic last_v;
    errs = 0; last_v = 1'b0;
    for (int k = 0; k < 3000; k++) begin
        last_v = !last_v && ($urandom_range(0, 2) != 0);
        step(last_v);
        if (p_tdata !== l_tdata || p_tvalid !== l_tvalid || p_tready !== l_tready) errs++;
    end
    `FAIL_UNLESS_LOG(errs == 0, $sformatf("%0d clocks differ from the legacy RTL", errs));
`SVTEST_END

// A word sampled at edge k comes out as its low half after edge k+2 and its
// high half after edge k+3, both valid; nothing else is valid.
`SVTEST(tc_low_then_high_half)
    int   errs;
    logic exp_v;
    errs = 0;
    for (int k = 0; k < 1000; k++) begin
        step((k % 2) == 0);
        // input driven after edge t_now is sampled at edge t_now+1
        // (after edge t_now: low half of the word driven 3 edges ago, high half of 4 ago)
        if (t_now >= 5) begin
            exp_v = h_val[t_now-3] || h_val[t_now-4];
            if (p_tvalid !== exp_v) errs++;
            if (h_val[t_now-3] && p_tdata !== h_data[t_now-3][0 +: N/2*B])     errs++;
            if (h_val[t_now-4] && p_tdata !== h_data[t_now-4][N/2*B +: N/2*B]) errs++;
        end
    end
    `FAIL_UNLESS_LOG(errs == 0, $sformatf("%0d mismatches in the half-word sequence", errs));
`SVTEST_END

// tready is always 1; reset clears the output.
`SVTEST(tc_ready_and_reset)
    `FAIL_UNLESS(p_tready === 1'b1);
    step(1'b1); step(1'b0); step(1'b0); step(1'b0);   // low half out 3 edges after the drive
    `FAIL_UNLESS(p_tvalid === 1'b1);
    aresetn <= 1'b0;
    @(posedge aclk); #TSU;
    `FAIL_UNLESS(p_tvalid === 1'b0 && p_tdata === '0 && p_tready === 1'b1);
    aresetn <= 1'b1;
`SVTEST_END
