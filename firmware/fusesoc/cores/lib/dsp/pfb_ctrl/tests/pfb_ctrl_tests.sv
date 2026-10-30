// ============================================================================
// File: pfb_ctrl_tests.sv
// Description: SVUnit test cases for pfb_ctrl. Included by pfb_ctrl_tc00.sv.
// ============================================================================

`SVTEST(tc_config_goes_out_once_after_reset)
    // cfg_en and tready high from reset: words 0..N-1 on N consecutive clocks,
    // tlast on the last, then nothing more.
    logic [7:0] seen [$];
    int last_at = -1;
    repeat (80) @(negedge aclk) if (p_cv[0]) begin
        seen.push_back(p_cd[0]);
        if (p_cl[0]) last_at = seen.size() - 1;
    end
    `FAIL_UNLESS_EQUAL(seen.size(), 8)
    foreach (seen[i]) `FAIL_UNLESS_EQUAL(seen[i], i)
    `FAIL_UNLESS_EQUAL(last_at, 7)
    `FAIL_UNLESS_EQUAL(n_cfg[1], 16)
    `FAIL_UNLESS_EQUAL(mism, 0)
`SVTEST_END

`SVTEST(tc_config_waits_for_tready_then_ignores_it)
    // tready low holds the start; once started, a low tready does not pause
    // the sequence. cfg_en low then high starts it again, but the word
    // counter was not cleared: it runs on from N through its 8-bit wrap back
    // to N-1, so the second packet is 256 words (legacy behaviour; the PFB
    // ties cfg_en high).
    @(posedge aclk);
    cfg_tready <= 1'b0;
    reset_dut();
    n_cfg[0] = 0;   // drop what setup's own reset sent
    repeat (20) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(n_cfg[0], 0)
    cfg_tready <= 1'b1;
    @(posedge aclk);
    cfg_tready <= 1'b0;
    repeat (30) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(n_cfg[0], 8)
    cfg_tready <= 1'b1;
    cfg_en <= 1'b0;
    repeat (3) @(posedge aclk);
    cfg_en <= 1'b1;
    repeat (300) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(n_cfg[0], 8 + 256)
    `FAIL_UNLESS_EQUAL(mism, 0)
`SVTEST_END

`SVTEST(tc_fr_sync_shifts_the_frame_by_one)
    // fr_out on every Nth accepted output; after fr_sync the next one comes
    // N+1 accepted outputs later, and fr_sync is ignored for 10*N clocks.
    int t [$];
    int k = 0;
    fork
        repeat (400) begin
            @(negedge aclk);
            if (p_fr[0]) t.push_back(k);
            k++;
        end
        begin
            repeat (100) @(posedge aclk);
            fr_sync <= 1'b1;
            @(posedge aclk);
            fr_sync <= 1'b0;
            repeat (20) @(posedge aclk);
            fr_sync <= 1'b1;   // inside the 80-clock wait: ignored
            @(posedge aclk);
            fr_sync <= 1'b0;
        end
    join
    begin
        int shifts = 0;
        for (int i = 1; i < t.size(); i++) begin
            `FAIL_UNLESS(t[i] - t[i-1] == 8 || t[i] - t[i-1] == 9)
            if (t[i] - t[i-1] == 9) shifts++;
        end
        `FAIL_UNLESS_EQUAL(shifts, 1)
    end
    `FAIL_UNLESS_EQUAL(mism, 0)
`SVTEST_END

`SVTEST(tc_random_matches_legacy)
    // Everything random: config tready and cfg_en, tvalid/tready, fr_sync
    // pulses, and resets now and then.
    for (int n = 0; n < 20000; n++) begin
        @(posedge aclk);
        cfg_tready <= ($urandom_range(3) != 0);
        if ($urandom_range(199) == 0) cfg_en <= ~cfg_en;
        tvalid  <= ($urandom_range(4) != 0);
        tready  <= ($urandom_range(4) != 0);
        fr_sync <= ($urandom_range(49) == 0);
        if ($urandom_range(2999) == 0) begin
            aresetn <= 1'b0;
            @(posedge aclk);
            aresetn <= 1'b1;
        end
    end
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS(n_cfg[0] > 16)
    `FAIL_UNLESS(n_fr[0] > 1000)
    `FAIL_UNLESS(n_fr[1] > 500)
`SVTEST_END
