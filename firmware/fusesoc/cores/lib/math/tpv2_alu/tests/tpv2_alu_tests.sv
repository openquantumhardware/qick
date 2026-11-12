// ============================================================================
// File: tpv2_alu_tests.sv
// Description: SVUnit test cases for tpv2_alu. Included by tpv2_alu_tc00.sv.
// ============================================================================

// ---------------------------------------------------------------------------
// ARITHMETIC group
// ---------------------------------------------------------------------------

`SVTEST(tc_add_basic)
    apply(32'd10, 32'd20, TPV2_ALU_ADD);
    check(32'd30, 1'b0, 1'b0, 1'b0, "10+20");
`SVTEST_END

`SVTEST(tc_add_zero_result)
    apply(32'd0, 32'd0, TPV2_ALU_ADD);
    check(32'd0, 1'b1, 1'b0, 1'b0, "0+0 -> zero");
`SVTEST_END

`SVTEST(tc_add_carry)
    // 0xFFFFFFFF + 1 = 0x1_00000000 : low32=0, carry=1
    apply(32'hFFFFFFFF, 32'd1, TPV2_ALU_ADD);
    check(32'd0, 1'b1, 1'b1, 1'b0, "FFFFFFFF+1 -> carry, zero32");
`SVTEST_END

`SVTEST(tc_add_negative_sign)
    // -1 + -1 = -2 (0xFFFFFFFE), sign=1
    apply(-32'sd1, -32'sd1, TPV2_ALU_ADD);
    check(-32'sd2, 1'b0, 1'b1, 1'b1, "(-1)+(-1) -> sign, carry");
`SVTEST_END

`SVTEST(tc_sub_basic)
    apply(32'd50, 32'd20, TPV2_ALU_SUB);
    check_res(32'd30, "50-20");
`SVTEST_END

`SVTEST(tc_sub_zero)
    apply(32'd42, 32'd42, TPV2_ALU_SUB);
    check_res(32'd0, "42-42 -> 0");
    `FAIL_IF(z_o !== 1'b1);
`SVTEST_END

`SVTEST(tc_sub_negative)
    apply(32'd20, 32'd50, TPV2_ALU_SUB);
    check_res(-32'sd30, "20-50 -> -30");
    `FAIL_IF(s_o !== 1'b1);
`SVTEST_END

`SVTEST(tc_and)
    apply(32'hF0F0_FF00, 32'h0FF0_0F0F, TPV2_ALU_AND);
    check_res(32'h00F0_0F00, "AND");
`SVTEST_END

`SVTEST(tc_asr)
    // arithmetic shift right of a negative number keeps sign
    apply(-32'sd16, 32'd2, TPV2_ALU_ASR);   // -16 >>> 2 = -4
    check_res(-32'sd4, "ASR -16>>2");
`SVTEST_END

`SVTEST(tc_abs_negative)
    apply(32'd0, -32'sd123, TPV2_ALU_ABS);
    check_res(32'd123, "abs(-123)");
`SVTEST_END

`SVTEST(tc_abs_positive)
    apply(32'd0, 32'sd123, TPV2_ALU_ABS);
    check_res(32'sd123, "abs(123)");
`SVTEST_END

`SVTEST(tc_msh)
    // high half of A moved to low half
    apply(32'hABCD_1234, 32'd0, TPV2_ALU_MSH);
    check_res(32'h0000_ABCD, "MSH");
`SVTEST_END

`SVTEST(tc_lsh)
    apply(32'hABCD_1234, 32'd0, TPV2_ALU_LSH);
    check_res(32'h0000_1234, "LSH");
`SVTEST_END

`SVTEST(tc_swap)
    apply(32'hABCD_1234, 32'd0, TPV2_ALU_SWAP);
    check_res(32'h1234_ABCD, "SWAP");
`SVTEST_END

`SVTEST(tc_sub_borrow)
    // 20 - 50 (unsigned): borrow -> carry/borrow flag = 1
    apply(32'd20, 32'd50, TPV2_ALU_SUB);
    `FAIL_IF(c_o !== 1'b1);   // borrow
    `FAIL_IF(s_o !== 1'b1);   // negative result
`SVTEST_END

`SVTEST(tc_sub_no_borrow)
    // 50 - 20: no borrow -> carry/borrow = 0
    apply(32'd50, 32'd20, TPV2_ALU_SUB);
    check_res(32'd30, "50-20");
    `FAIL_IF(c_o !== 1'b0);
`SVTEST_END

// ---------------------------------------------------------------------------
// LOGIC group
// ---------------------------------------------------------------------------

`SVTEST(tc_not)
    apply(32'h0F0F_0F0F, 32'd0, TPV2_ALU_NOT);
    check_res(32'hF0F0_F0F0, "NOT A");
`SVTEST_END

`SVTEST(tc_or)
    apply(32'hF0F0_0000, 32'h0F0F_0000, TPV2_ALU_OR);
    check_res(32'hFFFF_0000, "OR");
`SVTEST_END

`SVTEST(tc_xor)
    apply(32'hFFFF_0000, 32'h0F0F_0F0F, TPV2_ALU_XOR);
    check_res(32'hF0F0_0F0F, "XOR");
`SVTEST_END

`SVTEST(tc_cat)
    apply(32'h1111_ABCD, 32'h2222_1234, TPV2_ALU_CAT);
    check_res(32'hABCD_1234, "CAT {A[15:0],B[15:0]}");
`SVTEST_END

`SVTEST(tc_zero_const)
    apply(32'hDEAD_BEEF, 32'hCAFE_F00D, TPV2_ALU_ZERO);
    check_res(32'd0, "const 0");
    `FAIL_IF(z_o !== 1'b1);
`SVTEST_END

`SVTEST(tc_parity_even)
    // A = 0x3 -> two ones -> parity (reduction XOR) = 0
    apply(32'h0000_0003, 32'd0, TPV2_ALU_PAR);
    check_res(32'd0, "parity even");
`SVTEST_END

`SVTEST(tc_parity_odd)
    // A = 0x7 -> three ones -> parity = 1
    apply(32'h0000_0007, 32'd0, TPV2_ALU_PAR);
    check_res(32'd1, "parity odd");
`SVTEST_END

`SVTEST(tc_lsl)
    apply(32'h0000_0001, 32'd4, TPV2_ALU_LSL);
    check_res(32'h0000_0010, "1 << 4");
`SVTEST_END

`SVTEST(tc_lsr)
    apply(32'h0000_0010, 32'd4, TPV2_ALU_LSR);
    check_res(32'h0000_0001, "0x10 >> 4");
`SVTEST_END

// ---------------------------------------------------------------------------
// Flag corner cases
// ---------------------------------------------------------------------------

`SVTEST(tc_sign_flag_msb)
    // result with MSB set -> sign flag
    apply(32'h8000_0000, 32'd0, TPV2_ALU_OR);
    `FAIL_IF(s_o !== 1'b1);
    `FAIL_IF(z_o !== 1'b0);
`SVTEST_END

`SVTEST(tc_carry_only_addsub)
    // AND that yields 0 must NOT set carry (carry only meaningful for add/sub)
    apply(32'h0000_0000, 32'hFFFF_FFFF, TPV2_ALU_AND);
    check_res(32'd0, "AND -> 0");
    `FAIL_IF(c_o !== 1'b0);
    `FAIL_IF(z_o !== 1'b1);
`SVTEST_END
