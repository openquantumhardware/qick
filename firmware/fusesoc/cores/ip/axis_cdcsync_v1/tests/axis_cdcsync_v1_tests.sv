// ============================================================================
// File: axis_cdcsync_v1_tests.sv
// Description: SVUnit test cases for axis_cdcsync_v1. Included by
//              axis_cdcsync_v1_tc00.sv.
// ============================================================================

`SVTEST(tc_random_traffic_matches_legacy)
    // Random tvalid on every channel and random tready on every output, on
    // both clock pairs; pair 1 reads slower than it writes, so its FIFO also
    // runs full.
    s_auto = '{1, 1};
    m_auto = '{1, 1};
    repeat (4000) @(posedge sclk[0]);
    drain();

    for (int c = 0; c < NC; c++) begin
        `FAIL_UNLESS_LOG(n_push[c] > 200, $sformatf("c%0d: only %0d words", c, n_push[c]))
        `FAIL_UNLESS_LOG(n_pop[c] == n_push[c],
                         $sformatf("c%0d: %0d pushed, %0d popped", c, n_push[c], n_pop[c]))
        `FAIL_UNLESS_LOG(sb_q[c].size() == 0, $sformatf("c%0d: %0d words left", c, sb_q[c].size()))
    end
    `FAIL_UNLESS_EQUAL(total(cmp_err), 0)
    `FAIL_UNLESS_EQUAL(total(sb_err), 0)
    `FAIL_UNLESS_EQUAL(total(unused_err), 0)
`SVTEST_END

`SVTEST(tc_back_to_back_words_are_all_delivered)
    // Every channel valid on every write edge, every output ready. Pair 0
    // reads twice as fast as it writes, so tready never drops there.
    int ready_low = 0;
    fork
        begin
            @(posedge sclk[0]);
            vld[0] <= '1;
            for (int n = 0; n < 500; n++) begin
                for (int i = 0; i < 16; i++) dat[0][i] <= rand168();
                @(posedge sclk[0]);
            end
            vld[0] <= '0;
        end
        repeat (500) @(negedge sclk[0]) if (!p_sready[0][0]) ready_low++;
    join
    drain();

    `FAIL_UNLESS_EQUAL(ready_low, 0)
    for (int c = 0; c < 5; c++) begin
        `FAIL_UNLESS_LOG(n_push[c] == 500 && n_pop[c] == 500,
                         $sformatf("c%0d: %0d pushed, %0d popped", c, n_push[c], n_pop[c]))
    end
    `FAIL_UNLESS_EQUAL(total(cmp_err), 0)
    `FAIL_UNLESS_EQUAL(total(sb_err), 0)
`SVTEST_END

`SVTEST(tc_full_fifo_holds_tready_low)
    // Pair 1 with every output held not ready: the FIFO fills, tready drops
    // and stays low, and nothing accepted is lost once the outputs open.
    int accepted;
    rdy[1] = '0;
    @(posedge sclk[1]);
    vld[1] <= '1;
    for (int n = 0; n < 60; n++) begin
        for (int i = 0; i < 16; i++) dat[1][i] <= rand168();
        @(posedge sclk[1]);
    end
    vld[1] <= '0;
    repeat (4) @(posedge sclk[1]);
    accepted = n_push[5];

    `FAIL_IF(p_sready[5][0])
    `FAIL_UNLESS_LOG(accepted >= 15 && accepted <= 18,
                     $sformatf("%0d words accepted by a 16-deep FIFO", accepted))
    `FAIL_UNLESS_EQUAL(n_pop[5], 0)

    drain();
    `FAIL_UNLESS_EQUAL(n_pop[5], accepted)
    `FAIL_UNLESS_EQUAL(total(cmp_err), 0)
    `FAIL_UNLESS_EQUAL(total(sb_err), 0)
`SVTEST_END

`SVTEST(tc_one_stalled_output_holds_the_word)
    // c0 (N = 4): m1 not ready. The word stays at the head: m0, m2 and m3
    // keep tvalid high (the same word, again and again) until m1 takes it.
    int held = 0, wait_n = 0;
    rdy[0] = 16'hFFFD;
    push_word(0, 16'h000F);
    // The word crosses the FIFO's synchronizers first.
    while (p_mvalid[0][3:0] != 4'hF && wait_n < 100) begin @(negedge mclk[0]); wait_n++; end
    `FAIL_UNLESS(wait_n < 100)
    repeat (40) @(negedge mclk[0]) if (p_mvalid[0][3:0] == 4'hF) held++;
    `FAIL_UNLESS_EQUAL(held, 40)
    `FAIL_UNLESS_EQUAL(n_pop[0], 0)

    @(posedge mclk[0]);
    rdy[0] <= '1;
    repeat (4) @(posedge mclk[0]);
    `FAIL_UNLESS_EQUAL(n_pop[0], 1)
    `FAIL_UNLESS_EQUAL(p_mvalid[0][3:0], 4'h0)
    `FAIL_UNLESS_EQUAL(total(cmp_err), 0)
    `FAIL_UNLESS_EQUAL(total(sb_err), 0)
`SVTEST_END

`SVTEST(tc_partial_word_raises_only_its_channels)
    // Only s2 valid: on c0 (N = 4) only m2 rises; on c1 (N = 2) channel 2 is
    // not part of the IP, so nothing is written at all.
    int seen = 0;
    push_word(0, 16'h0004);
    repeat (20) @(negedge mclk[0]) if (p_mvalid[0] != 0) begin
        seen++;
        `FAIL_UNLESS_EQUAL(p_mvalid[0], 16'h0004)
    end
    `FAIL_UNLESS_EQUAL(seen, 1)
    `FAIL_UNLESS_EQUAL(n_push[1], 0)
    `FAIL_UNLESS_EQUAL(n_pop[1], 0)
    `FAIL_UNLESS_EQUAL(total(cmp_err), 0)
    `FAIL_UNLESS_EQUAL(total(sb_err), 0)
`SVTEST_END

`SVTEST(tc_tready_low_while_the_fifo_leaves_reset)
    // The one intended difference: right after s_axis_aresetn is released,
    // xpm_fifo_async drops writes while wr_rst_busy. The port holds tready
    // low for that window; the legacy IP showed tready high.
    int port_low = 0, legacy_low = 0;
    cmp_en = 1'b0;
    srstn <= 1'b0;
    repeat (30) @(posedge mclk[1]);
    srstn <= 1'b1;
    repeat (20) @(negedge sclk[0]) begin
        if (!p_sready[0][0]) port_low++;
        if (!l_sready[0][0]) legacy_low++;
    end
    `FAIL_UNLESS(port_low > 0)
    `FAIL_UNLESS_EQUAL(legacy_low, 0)

    repeat (2000) begin
        if (p_sready[0][0]) break;
        @(posedge sclk[0]);
    end
    `FAIL_UNLESS(p_sready[0][0])
`SVTEST_END
