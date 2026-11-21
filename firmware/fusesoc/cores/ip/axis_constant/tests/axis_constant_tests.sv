// ============================================================================
// File: axis_constant_tests.sv
// Description: SVUnit test cases for axis_constant.
// ============================================================================

// Every output is 0 (tvalid = 0: nothing is ever sent), in and out of reset,
// whatever tready does.
`SVTEST(tc_outputs_always_zero)
    #1;
    `FAIL_UNLESS(all_zero());
    aresetn = 1'b1;
    for (int k = 0; k < 100; k++) begin
        tready = $urandom_range(0, 1);
        @(posedge aclk); #1;
        `FAIL_UNLESS(all_zero());
    end
`SVTEST_END
