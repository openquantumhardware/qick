// ============================================================================
// File: pimod_pfb_tests.sv
// Description: SVUnit test cases for pimod_pfb. Included by pimod_pfb_tc00.sv.
// ============================================================================

`SVTEST(tc_odd_lanes_negated_every_other_frame)
    // A constant word, streamed continuously with tready high (as deployed):
    // outputs alternate T words as they are and T words with the odd lanes
    // negated (-2^15 saturating to 2^15 - 1 on lane 1's I).
    logic [W-1:0] w, wn;
    int flips = 0;
    for (int i = 0; i < L; i++) begin
        logic signed [15:0] vi, vq;
        vi = (i == 1) ? 16'sh8000 : 16'(100 * (i + 1));
        vq = 16'(-37 * (i + 1));
        w[2*i*16 +: 16]     = vi;
        w[(2*i+1)*16 +: 16] = vq;
        wn[2*i*16 +: 16]     = (i % 2) ? ((vi == 16'sh8000) ? 16'sh7fff : -vi) : vi;
        wn[(2*i+1)*16 +: 16] = (i % 2) ? -vq : vq;
    end
    for (int n = 0; n < 20 * T; n++) step(1'b1, n % T == T - 1, w);
    step(1'b0, 1'b0, '0);
    repeat (10) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS(o_data.size() >= 18 * T)
    for (int n = 0; n < o_data.size(); n++) begin
        // Copy out of the queue first: xsim returned 0 for
        // o_data[n] !== o_data[n-1] on these 256-bit elements even when they
        // differed.
        logic [W-1:0] cur, prev;
        cur = o_data[n];
        `FAIL_UNLESS(cur === w || cur === wn)
        if (n > 0) begin
            prev = o_data[n-1];
            if (cur !== prev) begin
                flips++;
                `FAIL_UNLESS_EQUAL(n % T, 0)
            end
        end
    end
    `FAIL_UNLESS(flips >= 17)
`SVTEST_END

`SVTEST(tc_random_handshake_matches_legacy)
    // Random tvalid and tready, random data with full-scale values, resets.
    for (int n = 0; n < 20000; n++) begin
        step($urandom_range(3) != 0, $urandom_range(7) == 0, rand_word());
        m_tready <= ($urandom_range(4) != 0);
        if ($urandom_range(4999) == 0) reset_dut();
    end
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS(n_valid > 10000)
`SVTEST_END
