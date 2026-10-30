// ============================================================================
// File: axis_register_slice_nb_tests.sv
// Description: SVUnit test cases for axis_register_slice_nb. Included by
//              axis_register_slice_nb_tc00.sv.
// ============================================================================

// No handshake: tready/tvalid are constant 1, also while in reset.
`SVTEST(tc_ready_valid_constant)
    `FAIL_UNLESS(def_tready === 1'b1 && adc_tready === 1'b1 && one_tready === 1'b1);
    `FAIL_UNLESS(def_tvalid === 1'b1 && adc_tvalid === 1'b1 && one_tvalid === 1'b1);
    aresetn <= 1'b0;
    @(posedge aclk); #TSU;
    `FAIL_UNLESS(def_tready === 1'b1 && adc_tready === 1'b1 && one_tready === 1'b1);
    `FAIL_UNLESS(def_tvalid === 1'b1 && adc_tvalid === 1'b1 && one_tvalid === 1'b1);
    aresetn <= 1'b1;
`SVTEST_END

// Every output word is the input word exactly N clocks earlier, in order,
// for each parametrisation (including the deployed B=128, N=2).
`SVTEST(tc_latency_and_order)
    int errs;
    errs = 0;
    for (int k = 0; k < 500; k++) begin
        step_random();
        if (def_tdata !== expected(4)[15:0]) errs++;
        if (adc_tdata !== expected(2))       errs++;
        if (one_tdata !== expected(1)[7:0])  errs++;
    end
    `FAIL_UNLESS_LOG(errs == 0, $sformatf("%0d output words did not match input delayed by N", errs));
`SVTEST_END

// The pipeline keeps shifting whatever the handshake inputs say: s_axis_tvalid
// and m_axis_tready are ignored (legacy behaviour).
`SVTEST(tc_ignores_tvalid_and_tready)
    int errs;
    errs = 0;
    for (int k = 0; k < 300; k++) begin
        s_tvalid <= $urandom_range(0, 1);
        m_tready <= $urandom_range(0, 1);
        step_random();
        if (def_tdata !== expected(4)[15:0]) errs++;
        if (adc_tdata !== expected(2))       errs++;
        if (one_tdata !== expected(1)[7:0])  errs++;
    end
    `FAIL_UNLESS_LOG(errs == 0, $sformatf("%0d mismatches with random tvalid/tready", errs));
`SVTEST_END

// aresetn clears every stage: after reset the first N outputs are 0, then the
// new data comes through.
`SVTEST(tc_reset_clears_pipeline)
    for (int k = 0; k < 10; k++) step_random();
    `FAIL_UNLESS(def_tdata !== 16'h0 || adc_tdata !== '0);   // data is flowing
    aresetn <= 1'b0;
    @(posedge aclk); #TSU;
    `FAIL_UNLESS(def_tdata === 16'h0);
    `FAIL_UNLESS(adc_tdata === 128'h0);
    `FAIL_UNLESS(one_tdata === 8'h0);
    aresetn <= 1'b1;
    // Restart the scoreboard from the reset state (all stages 0).
    t_now = 0;
    hist[0] = '0;
    s_tdata <= '0;
    for (int k = 0; k < 20; k++) begin
        step_random();
        `FAIL_UNLESS(def_tdata === expected(4)[15:0]);
        `FAIL_UNLESS(adc_tdata === expected(2));
        `FAIL_UNLESS(one_tdata === expected(1)[7:0]);
    end
`SVTEST_END
