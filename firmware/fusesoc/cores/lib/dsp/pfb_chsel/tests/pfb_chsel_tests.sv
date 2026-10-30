// ============================================================================
// File: pfb_chsel_tests.sv
// Description: SVUnit test cases for pfb_chsel. Included by
//              pfb_chsel_tc00.sv.
// ============================================================================

`SVTEST(tc_picks_channel_k_once_per_frame)
    // id = {k % 8, k / 8} selects channel k: clock k/8, word k%8 of each
    // frame, one output per frame.
    int ks [] = '{0, 7, 8, 21, 42, 63};
    foreach (ks[j]) begin
        logic [B-1:0] got;
        @(posedge aclk);
        id <= {8'(ks[j] % 8), 8'(ks[j] / 8)};
        repeat (3) frame();         // settle on the new id
        o_data.delete();
        repeat (10) frame();
        @(posedge aclk);
        s_tlast <= 1'b0;             // frame() leaves the last tlast high
        repeat (4) @(posedge aclk);
        `FAIL_UNLESS(o_data.size() >= 10 && o_data.size() <= 11)   // + the last settle frame's
        foreach (o_data[n]) begin
            got = o_data[n];
            `FAIL_UNLESS_EQUAL(got[15:8], ks[j] / 8)
            `FAIL_UNLESS_EQUAL(got[7:0], ks[j] % 8)
        end
    end
    `FAIL_UNLESS_EQUAL(mism, 0)
`SVTEST_END

`SVTEST(tc_random_matches_legacy)
    // Irregular frames (tlast anywhere), random data and ids, including
    // indexes past L (X in both).
    for (int n = 0; n < 20000; n++) begin
        @(posedge aclk);
        s_tlast <= ($urandom_range(9) == 0);
        for (int w = 0; w < L; w++) s_tdata[w*B +: B] <= $urandom;
        if ($urandom_range(99) == 0) id <= {8'($urandom_range(9)), 8'($urandom_range(11))};
    end
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS(n_valid > 1500)
`SVTEST_END
