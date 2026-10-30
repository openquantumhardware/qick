// ============================================================================
// File: tests.sv
// Description: Full test suite for the signed_comparator module.
// Included inside SVUNIT_TESTS_BEGIN/END
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 00: Greater Than (op = 0000)
// Expected: 1 if A > B, 0 otherwise. Tests positive, negative, and equal values.
// ----------------------------------------------------------------------------
`SVTEST(test_op_greater_than)
    // op = 4'b0000
    check_cond( 10,   5, 4'b0000, 1'b1); // + vs +
    check_cond(  5,  10, 4'b0000, 1'b0); // + vs + (fail)
    check_cond( 10,  10, 4'b0000, 1'b0); // Equal
    check_cond(  5,  -5, 4'b0000, 1'b1); // + vs -
    check_cond( -5,   5, 4'b0000, 1'b0); // - vs +
    check_cond( -2, -10, 4'b0000, 1'b1); // - vs - (-2 is greater than -10)
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 01: Greater or Equal (op = 0001)
// Expected: 1 if A >= B, 0 otherwise.
// ----------------------------------------------------------------------------
`SVTEST(test_op_greater_or_equal)
    // op = 4'b0001
    check_cond( 10,   5, 4'b0001, 1'b1); // A > B
    check_cond( 10,  10, 4'b0001, 1'b1); // A = B
    check_cond(  5,  10, 4'b0001, 1'b0); // A < B
    check_cond( -5,  -5, 4'b0001, 1'b1); // Negative equal
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Less Than (op = 0010)
// Expected: 1 if A < B, 0 otherwise.
// ----------------------------------------------------------------------------
`SVTEST(test_op_less_than)
    // op = 4'b0010
    check_cond(  5,  10, 4'b0010, 1'b1); // + vs +
    check_cond( 10,   5, 4'b0010, 1'b0); // + vs + (fail)
    check_cond( 10,  10, 4'b0010, 1'b0); // Equal
    check_cond( -5,   5, 4'b0010, 1'b1); // - vs +
    check_cond( -10, -2, 4'b0010, 1'b1); // - vs -
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Less or Equal (op = 0011)
// Expected: 1 if A <= B, 0 otherwise.
// ----------------------------------------------------------------------------
`SVTEST(test_op_less_or_equal)
    // op = 4'b0011
    check_cond(  5,  10, 4'b0011, 1'b1); // A < B
    check_cond( 10,  10, 4'b0011, 1'b1); // A = B
    check_cond( 10,   5, 4'b0011, 1'b0); // A > B
    check_cond( -5,  -5, 4'b0011, 1'b1); // Negative equal
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: Equal (op = 0100)
// Expected: 1 if A == B, 0 otherwise.
// ----------------------------------------------------------------------------
`SVTEST(test_op_equal)
    // op = 4'b0100
    check_cond( 100,  100, 4'b0100, 1'b1);
    check_cond( -50,  -50, 4'b0100, 1'b1);
    check_cond(  10,   11, 4'b0100, 1'b0);
    check_cond(   1,   -1, 4'b0100, 1'b0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: Not Equal (op = 0101)
// Expected: 1 if A != B, 0 otherwise.
// ----------------------------------------------------------------------------
`SVTEST(test_op_not_equal)
    // op = 4'b0101
    check_cond(  10,   11, 4'b0101, 1'b1);
    check_cond(   1,   -1, 4'b0101, 1'b1);
    check_cond( 100,  100, 4'b0101, 1'b0);
    check_cond( -50,  -50, 4'b0101, 1'b0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: Invalid OP (Default case)
// Expected: flag should be 0 for undefined operations.
// ----------------------------------------------------------------------------
`SVTEST(test_op_default)
    // op = 4'b1111 (or any value > 0101)
    // Even if A > B, the output should be 0 because op is invalid.
    check_cond( 10,   5, 4'b1111, 1'b0); 
    check_cond( 10,  10, 4'b1000, 1'b0); 
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: Reset behavior
// Expected: Inputs should not propagate if reset is active.
// ----------------------------------------------------------------------------
`SVTEST(test_reset_behavior)
    // Drive valid inputs for a TRUE condition (10 > 5)
    cb.tb_din_a <= 16'd10;
    cb.tb_din_b <= 16'd5;
    cb.tb_op    <= 4'b0000;
    
    // Assert reset
    cb.tb_rstn <= 1'b0;
    
    // Wait for the pipeline
    repeat(2) @(cb);
    
    // Output must be 0 because the internal registers were cleared by reset
    `FAIL_UNLESS_EQUAL(cb.tb_flag, 1'b0);
`SVTEST_END