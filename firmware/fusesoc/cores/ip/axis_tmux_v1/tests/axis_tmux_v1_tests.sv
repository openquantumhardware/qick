// ============================================================================
// File: axis_tmux_v1_tests.sv
// Description: SVUnit test cases for axis_tmux_v1. Included by
//              axis_tmux_v1_tc00.sv.
// ============================================================================

// Port and legacy RTL agree on tready, every existing output's tvalid and
// every data bit, for all four configurations.
`SVTEST(tc_matches_legacy)
    int errs [NC];
    for (int c = 0; c < NC; c++) errs[c] = 0;
    for (int k = 0; k < 2000; k++) begin
        step(($urandom_range(0, 3) == 0) ? 8'($urandom) : 8'($urandom_range(0, 7)), 1'($urandom));
        for (int c = 0; c < NC; c++) errs[c] += diff_bits(c);
    end
    for (int c = 0; c < NC; c++)
        `FAIL_UNLESS_LOG(errs[c] == 0,
            $sformatf("N=%0d B=%0d: %0d bits differ from the legacy RTL", CN[c], CB[c], errs[c]));
`SVTEST_END

// Two clocks after a word goes in, exactly output sel[2:0] (if < N) is valid,
// and every output shows the whole word, selection byte included.
`SVTEST(tc_routing_and_latency)
    int           errs;
    logic         exp_v;
    logic [167:0] exp_w;
    errs = 0;
    for (int k = 0; k < 1000; k++) begin
        step(8'($urandom_range(0, 7)), 1'($urandom));
        if (t_now >= 2) begin
            for (int c = 0; c < NC; c++) begin
                for (int i = 0; i < 8; i++) begin
                    exp_v = h_val[t_now-2] && (h_sel[t_now-2][2:0] == 3'(i)) && (i < CN[c]);
                    if (p_valid[c][i] !== exp_v) errs++;
                end
                // every output shows the whole word, selection byte on top
                exp_w = (168'(h_sel[t_now-2]) << (CB[c] - 8)) |
                        (168'(h_pay[t_now-2]) & ((168'(1) << (CB[c] - 8)) - 168'(1)));
                if (p_data[c][0] !== exp_w) errs++;
                if (p_data[c][CN[c]-1] !== p_data[c][0]) errs++;
            end
        end
    end
    `FAIL_UNLESS_LOG(errs == 0, $sformatf("%0d routing/latency mismatches", errs));
`SVTEST_END

// Only the low 3 bits of the selection byte count; a selection >= N reaches
// no output.
`SVTEST(tc_selection_rules)
    // sel = 8'h09 -> output 1 (upper bits ignored), on the N=8 instance
    step(8'h09, 1'b1); step(8'h00, 1'b0); step(8'h00, 1'b0);
    `FAIL_UNLESS(p_valid[3] === 8'b0000_0010);
    // sel = 3..7 on N=3 (c0): nothing valid, although tvalid was 1
    for (int s = 3; s < 8; s++) begin
        step(8'(s), 1'b1); step(8'h00, 1'b0); step(8'h00, 1'b0);
        `FAIL_UNLESS_LOG(p_valid[0] === 8'b0, $sformatf("sel=%0d on N=3 raised %b", s, p_valid[0]));
    end
    // outputs >= N never valid, whatever the selection (N=2, c2)
    for (int s = 0; s < 8; s++) begin
        step(8'(s), 1'b1); step(8'h00, 1'b0); step(8'h00, 1'b0);
        `FAIL_UNLESS(p_valid[2][7:2] === 6'b0);
    end
`SVTEST_END

// s_axis_tready is always 1; reset clears both stages.
`SVTEST(tc_ready_and_reset)
    for (int c = 0; c < NC; c++) `FAIL_UNLESS(p_tready[c] === 1'b1);
    step(8'h01, 1'b1);
    step(8'h01, 1'b1);
    aresetn <= 1'b0;
    @(posedge aclk); #TSU;
    for (int c = 0; c < NC; c++) begin
        `FAIL_UNLESS(p_valid[c] === 8'b0);
        `FAIL_UNLESS(p_data[c][0] === 168'b0);
        `FAIL_UNLESS(p_tready[c] === 1'b1);
    end
    aresetn <= 1'b1;
`SVTEST_END
