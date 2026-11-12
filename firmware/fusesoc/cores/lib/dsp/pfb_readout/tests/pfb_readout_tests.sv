// ============================================================================
// File: pfb_readout_tests.sv
// Description: SVUnit test cases for pfb_readout. Included by
//              pfb_readout_tc00.sv.
// ============================================================================

`SVTEST(tc_tone_in_its_channel_comes_out_as_dc)
    // A tone at (k + d)/64 cycles per input sample, channel k selected, lands
    // at d/2 cycles per output sample (one output per 32 input samples); with
    // pinc = (d/2)*2^32 the output is a constant of magnitude ~A. Without the
    // DDS (pinc = 0) it rotates.
    int  k = 10;
    real d = 0.2, mi, mq, dev;
    foreach (id[i]) id[i] = {8'(k % 8), 8'(k / 8)};
    for (int s = 0; s < 2; s++) begin
        pinc[0] = (s == 0) ? 32'($rtoi(d / 2.0 * 4294967296.0)) : 32'd0;
        o_i.delete(); o_q.delete();
        tone((k + d) / 64.0, 3000.0, 3000);
        mi = 0; mq = 0; dev = 0;
        for (int n = 50; n < o_i.size(); n++) begin mi += o_i[n]; mq += o_q[n]; end
        mi /= (o_i.size() - 50); mq /= (o_q.size() - 50);
        for (int n = 50; n < o_i.size(); n++) dev += $sqrt((o_i[n] - mi) ** 2 + (o_q[n] - mq) ** 2);
        dev /= (o_i.size() - 50);
        `FAIL_UNLESS(o_i.size() > 300)   // 375 frames, fewer right after reset
        if (s == 0) begin
            `FAIL_UNLESS($sqrt(mi * mi + mq * mq) > 0.98 * 3000.0 && $sqrt(mi * mi + mq * mq) < 1.02 * 3000.0)
            `FAIL_UNLESS(dev < 2.0)
        end else begin
            `FAIL_UNLESS($sqrt(mi * mi + mq * mq) < 100.0)
            `FAIL_UNLESS(dev > 2500.0)
        end
    end
    `FAIL_UNLESS_EQUAL(mism, 0)
`SVTEST_END

`SVTEST(tc_each_output_follows_its_own_channel)
    // Output i on channel 5 + 7*i; a tone at the centre of output 3's channel
    // reaches output 3 only (the others under 1 %).
    real pw [8];
    foreach (id[i]) begin
        id[i]   = {8'((5 + 7 * i) % 8), 8'((5 + 7 * i) / 8)};
        pinc[i] = '0;
    end
    tone((5 + 7 * 3) / 64.0, 3000.0, 1500);
    for (int i = 0; i < 8; i++) pw[i] = 0.0;
    repeat (2000) begin
        tone((5 + 7 * 3) / 64.0, 3000.0, 1);
        @(negedge aclk);
        if (p8_v) for (int i = 0; i < 8; i++)
            pw[i] += real'($signed(p8_d[i][15:0])) ** 2 + real'($signed(p8_d[i][31:16])) ** 2;
    end
    for (int i = 0; i < 8; i++) if (i != 3) `FAIL_UNLESS(pw[i] < 1e-4 * pw[3])
    `FAIL_UNLESS(pw[3] > 0.0)
    `FAIL_UNLESS_EQUAL(mism, 0)
`SVTEST_END

`SVTEST(tc_random_matches_legacy_v3_v4)
    // Random input with gaps, ids/pinc/poff changing, resets; both NOUT = 8
    // (v4) and NOUT = 4 (v3) against their legacy wiring.
    for (int n = 0; n < 16000; n++) begin
        @(posedge aclk);
        s_tvalid <= ($urandom_range(19) != 0);
        for (int i = 0; i < 2 * L; i++) s_tdata[i*16 +: 16] <= 16'($signed(14'($urandom)));
        if ($urandom_range(299) == 0) begin
            int i = $urandom_range(7);
            id[i]   <= {8'($urandom_range(7)), 8'($urandom_range(7))};
            pinc[i] <= $urandom;
            poff[i] <= $urandom;
        end
        if ($urandom_range(3999) == 0) reset_dut();
    end
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS(n_valid > 1500)
`SVTEST_END
