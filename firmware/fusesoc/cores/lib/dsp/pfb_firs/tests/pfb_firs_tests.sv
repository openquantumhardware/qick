// ============================================================================
// File: pfb_firs_tests.sv
// Description: SVUnit test cases for pfb_firs. Included by pfb_firs_tc00.sv.
// ============================================================================

`SVTEST(tc_continuous_stream_locks_and_matches_legacy)
    // The deployed case: a continuous source. The framing locks within the
    // first few hundred clocks: no missing-tlast events after that, and tlast
    // on every 8th output.
    int since_last = 0, bad_period = 0, n_last = 0;
    repeat (1000) step(1'b1);
    n_sync = 0;
    fork
        repeat (8000) step(1'b1);
        repeat (8000) @(negedge aclk) if (p_tvalid) begin
            since_last++;
            if (p_tlast) begin
                if (n_last > 0 && since_last != 8) bad_period++;
                n_last++;
                since_last = 0;
            end
        end
    join
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS_EQUAL(n_sync, 0)
    `FAIL_UNLESS_EQUAL(bad_period, 0)
    `FAIL_UNLESS(n_last > 900)
`SVTEST_END

`SVTEST(tc_gaps_and_resets_match_legacy)
    // Random input gaps (the framing slips and relocks) and resets.
    for (int n = 0; n < 20000; n++) begin
        step($urandom_range(9) != 0);
        if ($urandom_range(4999) == 0) reset_dut();
    end
    repeat (40) step(1'b0);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS(n_valid > 15000)
    `FAIL_UNLESS(n_sync > 0)
`SVTEST_END
