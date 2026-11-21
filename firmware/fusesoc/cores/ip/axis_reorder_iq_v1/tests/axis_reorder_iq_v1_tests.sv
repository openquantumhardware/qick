// ============================================================================
// File: axis_reorder_iq_v1_tests.sv
// Description: SVUnit test cases for axis_reorder_iq_v1.
// ============================================================================

// Equal to the legacy RTL on random words and valids, both lane counts.
`SVTEST(tc_matches_legacy)
    int errs;
    errs = 0;
    for (int k = 0; k < 2000; k++) begin
        din = {8{$urandom}}; vin = $urandom_range(0, 1); #1;
        if (p4 !== l4 || pv4 !== lv4 || pr4 !== lr4) errs++;
        if (p8 !== l8 || pv8 !== lv8 || pr8 !== lr8) errs++;
    end
    `FAIL_UNLESS_LOG(errs == 0, $sformatf("%0d words differ from the legacy RTL", errs));
`SVTEST_END

// Readable example, L = 4: I lanes 0x1110..0x1113, Q lanes 0x2220..0x2223 ->
// output lane k = {Q[k], I[k]}; tvalid passes through, tready is 1.
`SVTEST(tc_interleave_example)
    din = '0;
    for (int k = 0; k < 4; k++) begin
        din[16*k +: 16]      = 16'h1110 + 16'(k);   // I[k]
        din[64 + 16*k +: 16] = 16'h2220 + 16'(k);   // Q[k]
    end
    vin = 1'b1; #1;
    for (int k = 0; k < 4; k++)
        `FAIL_UNLESS(p4[32*k +: 32] === {16'h2220 + 16'(k), 16'h1110 + 16'(k)});
    `FAIL_UNLESS(pv4 === 1'b1 && pr4 === 1'b1);
    vin = 1'b0; #1;
    `FAIL_UNLESS(pv4 === 1'b0);
`SVTEST_END
