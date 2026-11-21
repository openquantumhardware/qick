//--------------------------------------------------------------------------
// test00: Reset state
//   After reset, dout must be zero; zero_a/zero_b must assert (inputs=0).
//--------------------------------------------------------------------------
`SVTEST(test00_reset_state)
    `FAIL_IF_LOG($isunknown(tb_dout),   "dout should not be X/Z after reset");
    `FAIL_IF_LOG($isunknown(tb_zero_a), "zero_a should not be X/Z after reset");
    `FAIL_IF_LOG($isunknown(tb_zero_b), "zero_b should not be X/Z after reset");
    `FAIL_UNLESS_LOG(tb_dout   == '0,   "dout should be 0 after reset");
    `FAIL_UNLESS_LOG(tb_zero_a == 1'b1, "zero_a should assert when din_a=0");
    `FAIL_UNLESS_LOG(tb_zero_b == 1'b1, "zero_b should assert when din_b=0");
`SVTEST_END

//--------------------------------------------------------------------------
// test01: Arithmetic ADD routed correctly (op[3]=1)
//   Verify that the arithmetic unit result reaches dout when op[3]=1.
//--------------------------------------------------------------------------
`SVTEST(test01_arith_add)
    logic [B-1:0] a, b, expected;

    a        = 16'd100;
    b        = 16'd200;
    expected = 16'd300;

    apply_arith(a, b, alu_pkg::ARITH_ADD);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("ARITH ADD fail: %0d + %0d = expected 0x%04h, got 0x%04h",
            a, b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test02: Arithmetic SUB routed correctly (op[3]=1)
//--------------------------------------------------------------------------
`SVTEST(test02_arith_sub)
    logic [B-1:0] a, b, expected;

    a        = 16'd500;
    b        = 16'd300;
    expected = 16'd200;

    apply_arith(a, b, alu_pkg::ARITH_SUB);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("ARITH SUB fail: %0d - %0d = expected 0x%04h, got 0x%04h",
            a, b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test03: Arithmetic MUL routed correctly (op[3]=1)
//   Product uses lower B/2 bits of each operand.
//--------------------------------------------------------------------------
`SVTEST(test03_arith_mul)
    logic [B-1:0]   a, b, expected;
    logic [B/2-1:0] a_lo, b_lo;

    a        = 16'h0007;
    b        = 16'h0008;
    a_lo     = a[B/2-1:0];
    b_lo     = b[B/2-1:0];
    expected = B'(a_lo * b_lo); // 7 * 8 = 56

    apply_arith(a, b, alu_pkg::ARITH_MUL);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("ARITH MUL fail: lower(%0d) * lower(%0d) = expected 0x%04h, got 0x%04h",
            a, b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test04: Bitwise AND routed correctly (op[3]=0)
//--------------------------------------------------------------------------
`SVTEST(test04_bitw_and)
    logic [B-1:0] a, b, expected;

    a        = 16'hF0F0;
    b        = 16'hFF00;
    expected = a & b; // 0xF000

    apply_bitw(a, b, alu_pkg::BITW_AND);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("BITW AND fail: 0x%04h & 0x%04h = expected 0x%04h, got 0x%04h",
            a, b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test05: Bitwise OR routed correctly (op[3]=0)
//--------------------------------------------------------------------------
`SVTEST(test05_bitw_or)
    logic [B-1:0] a, b, expected;

    a        = 16'hF0F0;
    b        = 16'h0F0F;
    expected = a | b; // 0xFFFF

    apply_bitw(a, b, alu_pkg::BITW_OR);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("BITW OR fail: 0x%04h | 0x%04h = expected 0x%04h, got 0x%04h",
            a, b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test06: Bitwise XOR routed correctly (op[3]=0)
//--------------------------------------------------------------------------
`SVTEST(test06_bitw_xor)
    logic [B-1:0] a, b, expected;

    a        = 16'hAAAA;
    b        = 16'hFFFF;
    expected = a ^ b; // 0x5555

    apply_bitw(a, b, alu_pkg::BITW_XOR);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("BITW XOR fail: 0x%04h ^ 0x%04h = expected 0x%04h, got 0x%04h",
            a, b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test07: Bitwise NOT routed correctly (op[3]=0)
//   NOT operates on din_b only (RTL spec).
//--------------------------------------------------------------------------
`SVTEST(test07_bitw_not)
    logic [B-1:0] a, b, expected;

    a        = 16'hDEAD; // ignored for NOT
    b        = 16'h00FF;
    expected = ~b;        // 0xFF00

    apply_bitw(a, b, alu_pkg::BITW_NOT);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("BITW NOT fail: ~0x%04h = expected 0x%04h, got 0x%04h",
            b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test08: Bitwise left shift routed correctly (op[3]=0)
//--------------------------------------------------------------------------
`SVTEST(test08_bitw_lshift)
    logic [B-1:0] a, b, expected;

    a        = 16'h0001;
    b        = 16'd4;
    expected = a << b; // 0x0010

    apply_bitw(a, b, alu_pkg::BITW_LSHIFT);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("BITW LSHIFT fail: 0x%04h << %0d = expected 0x%04h, got 0x%04h",
            a, b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test09: Bitwise right shift routed correctly (op[3]=0)
//--------------------------------------------------------------------------
`SVTEST(test09_bitw_rshift)
    logic [B-1:0] a, b, expected;

    a        = 16'h8000;
    b        = 16'd3;
    expected = a >> b; // 0x1000

    apply_bitw(a, b, alu_pkg::BITW_RSHIFT);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("BITW RSHIFT fail: 0x%04h >> %0d = expected 0x%04h, got 0x%04h",
            a, b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test10: Zero detection with non-zero inputs
//   zero_a and zero_b must deassert when inputs are non-zero.
//--------------------------------------------------------------------------
`SVTEST(test10_zero_detection_nonzero)
    cb.tb_din_a <= 16'hABCD;
    cb.tb_din_b <= 16'h1234;
    @(cb);
    `FAIL_UNLESS_LOG(tb_zero_a == 1'b0,
        "zero_a should be 0 for non-zero din_a");
    `FAIL_UNLESS_LOG(tb_zero_b == 1'b0,
        "zero_b should be 0 for non-zero din_b");
`SVTEST_END

//--------------------------------------------------------------------------
// test11: Cross-unit back-to-back (ARITH then BITW)
//   Switch from arithmetic to bitwise unit with no idle cycles between.
//   Verifies that op_rrr selector tracks the operation switch correctly.
//--------------------------------------------------------------------------
`SVTEST(test11_cross_unit_back_to_back)
    logic [B-1:0] res_arith, res_bitw;

    res_arith = 16'd10 + 16'd20; // ADD  = 30
    res_bitw  = 16'hF0 & 16'h0F; // AND  = 0x00

    // Issue arithmetic ADD first
    apply_arith(16'd10, 16'd20, alu_pkg::ARITH_ADD);
    `FAIL_UNLESS_LOG(tb_dout == res_arith,
        $sformatf("Cross-unit ARITH ADD fail: expected 0x%04h, got 0x%04h",
            res_arith, tb_dout));

    // Switch to bitwise AND immediately after
    apply_bitw(16'hF0, 16'h0F, alu_pkg::BITW_AND);
    `FAIL_UNLESS_LOG(tb_dout == res_bitw,
        $sformatf("Cross-unit BITW AND fail: expected 0x%04h, got 0x%04h",
            res_bitw, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test12: Signed arithmetic SUB via top-level routing
//   End-to-end check: negative result through arithmetic unit path.
//--------------------------------------------------------------------------
`SVTEST(test12_arith_signed_sub)
    logic signed [B-1:0] a, b;
    logic [B-1:0]        expected;

    a        = 16'sd5;
    b        = 16'sd20;
    expected = B'(a - b); // -15 in two's complement

    apply_arith(B'(a), B'(b), alu_pkg::ARITH_SUB);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("Signed SUB fail: 5 - 20 = expected 0x%04h, got 0x%04h",
            expected, tb_dout));
`SVTEST_END
