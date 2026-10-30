// ============================================================================
// File: qick_vec2bit_tests.sv
// Description: SVUnit test cases for qick_vec2bit.
// ============================================================================

// dout<i> = din[i], equal to the legacy RTL, on every 16-bit input pattern.
`SVTEST(tc_matches_legacy_exhaustive)
    int errs;
    errs = 0;
    for (int v = 0; v < 65536; v++) begin
        din = 16'(v); #1;
        if (p16 !== l16 || p16 !== din) errs++;
    end
    `FAIL_UNLESS_LOG(errs == 0, $sformatf("%0d input patterns differ", errs));
`SVTEST_END

// With IN_DW = 8, dout0..7 follow din and dout8..15 are 0.
`SVTEST(tc_narrow_input_upper_outputs_zero)
    for (int v = 0; v < 256; v++) begin
        din = 16'(v); #1;
        `FAIL_UNLESS(p8 === {8'h00, 8'(v)});
    end
`SVTEST_END
