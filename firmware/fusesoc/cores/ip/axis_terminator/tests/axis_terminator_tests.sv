// ============================================================================
// File: axis_terminator_tests.sv
// Description: SVUnit test cases for axis_terminator.
// ============================================================================

// tready is 1 in and out of reset, whatever the master drives: every beat is
// accepted (and dropped).
`SVTEST(tc_always_ready)
    #1;
    `FAIL_UNLESS(r256 === 1'b1 && r16 === 1'b1);
    aresetn = 1'b1;
    for (int k = 0; k < 100; k++) begin
        d256 = {8{$urandom}}; s256 = $urandom; d16 = $urandom; s16 = $urandom;
        tlast = $urandom_range(0, 1); tvalid = $urandom_range(0, 1);
        @(posedge aclk); #1;
        `FAIL_UNLESS(r256 === 1'b1 && r16 === 1'b1);
    end
`SVTEST_END
