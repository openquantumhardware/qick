//--------------------------------------------------------------------------
// test00: Reset state
//   After reset, dout must be zero and must not be X/Z.
//--------------------------------------------------------------------------
`SVTEST(test00_reset_state)
    `FAIL_IF_LOG($isunknown(tb_dout), "dout should not be X/Z after reset");
    `FAIL_UNLESS_LOG(tb_dout == '0, "dout should be 0 after reset");
`SVTEST_END

//--------------------------------------------------------------------------
// test01: AND operation
//   Verify dout = din_a & din_b after 2-cycle pipeline latency.
//--------------------------------------------------------------------------
`SVTEST(test01_and)
    logic [B-1:0] a, b, expected;

    a        = 16'hF0F0;
    b        = 16'hFF00;
    expected = a & b; // 0xF000

    apply_op(a, b, alu_pkg::BITW_AND);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("AND fail: 0x%04h & 0x%04h = expected 0x%04h, got 0x%04h",
            a, b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test02: OR operation
//   Verify dout = din_a | din_b after 2-cycle pipeline latency.
//--------------------------------------------------------------------------
`SVTEST(test02_or)
    logic [B-1:0] a, b, expected;

    a        = 16'hF0F0;
    b        = 16'h0F0F;
    expected = a | b; // 0xFFFF

    apply_op(a, b, alu_pkg::BITW_OR);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("OR fail: 0x%04h | 0x%04h = expected 0x%04h, got 0x%04h",
            a, b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test03: XOR operation
//   Verify dout = din_a ^ din_b after 2-cycle pipeline latency.
//--------------------------------------------------------------------------
`SVTEST(test03_xor)
    logic [B-1:0] a, b, expected;

    a        = 16'hAAAA;
    b        = 16'hFFFF;
    expected = a ^ b; // 0x5555

    apply_op(a, b, alu_pkg::BITW_XOR);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("XOR fail: 0x%04h ^ 0x%04h = expected 0x%04h, got 0x%04h",
            a, b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test04: NOT operation
//   NOT operates on din_b_r only (as per RTL). Verify dout = ~din_b.
//--------------------------------------------------------------------------
`SVTEST(test04_not)
    logic [B-1:0] a, b, expected;

    a        = 16'hDEAD; // din_a is ignored for NOT
    b        = 16'h00FF;
    expected = ~b;        // 0xFF00

    apply_op(a, b, alu_pkg::BITW_NOT);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("NOT fail: ~0x%04h = expected 0x%04h, got 0x%04h",
            b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test05: Left shift operation
//   Verify dout = din_a << din_b (shift amount from din_b value).
//--------------------------------------------------------------------------
`SVTEST(test05_lshift)
    logic [B-1:0] a, b, expected;

    a        = 16'h0001;
    b        = 16'd4;    // shift amount = 4
    expected = a << b;   // 0x0010

    apply_op(a, b, alu_pkg::BITW_LSHIFT);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("LSHIFT fail: 0x%04h << %0d = expected 0x%04h, got 0x%04h",
            a, b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test06: Right shift operation
//   Verify dout = din_a >> din_b (logical, unsigned shift).
//--------------------------------------------------------------------------
`SVTEST(test06_rshift)
    logic [B-1:0] a, b, expected;

    a        = 16'h8000;
    b        = 16'd3;    // shift amount = 3
    expected = a >> b;   // 0x1000

    apply_op(a, b, alu_pkg::BITW_RSHIFT);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("RSHIFT fail: 0x%04h >> %0d = expected 0x%04h, got 0x%04h",
            a, b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test07: Shift by zero
//   Shifting by zero must return the original value unchanged.
//--------------------------------------------------------------------------
`SVTEST(test07_shift_by_zero)
    logic [B-1:0] a, expected;

    a        = 16'hABCD;
    expected = a; // no shift

    apply_op(a, '0, alu_pkg::BITW_LSHIFT);
    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("LSHIFT by 0 fail: expected 0x%04h, got 0x%04h", expected, tb_dout));

    apply_op(a, '0, alu_pkg::BITW_RSHIFT);
    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("RSHIFT by 0 fail: expected 0x%04h, got 0x%04h", expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test08: AND with all-zeros mask (identity for AND-zero)
//   AND with all zeros must produce zero regardless of din_a.
//--------------------------------------------------------------------------
`SVTEST(test08_and_zero_mask)
    apply_op(16'hFFFF, 16'h0000, alu_pkg::BITW_AND);

    `FAIL_UNLESS_LOG(tb_dout == '0,
        $sformatf("AND zero mask fail: expected 0x0000, got 0x%04h", tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test09: Default opcode
//   Any opcode not listed in the case statement must produce dout=0.
//--------------------------------------------------------------------------
`SVTEST(test09_default_op)
    apply_op(16'hFFFF, 16'hFFFF, 4'hF); // Undefined opcode

    `FAIL_UNLESS_LOG(tb_dout == '0,
        $sformatf("Default op fail: undefined opcode should yield 0, got 0x%04h", tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test10: Pipeline latency isolation
//   Result must NOT appear after 1 cycle and MUST appear after 2 cycles.
//--------------------------------------------------------------------------
`SVTEST(test10_pipeline_latency)
    logic [B-1:0] a, b, expected;

    a        = 16'hF0F0;
    b        = 16'h0F0F;
    expected = a | b; // 0xFFFF via OR

    cb.tb_din_a <= a;
    cb.tb_din_b <= b;
    cb.tb_op    <= alu_pkg::BITW_OR;
    @(cb); // Cycle 1: inputs registered

    `FAIL_IF_LOG(tb_dout == expected,
        "Pipeline: result should NOT appear at dout after only 1 cycle");

    @(cb); // Cycle 2: dout_r latched
    @(cb); // Sample dout_rr

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("Pipeline: expected 0x%04h at dout after 2 cycles, got 0x%04h",
            expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test11: Back-to-back operations
//   Consecutive different operations must not corrupt each other.
//--------------------------------------------------------------------------
`SVTEST(test11_back_to_back)
    logic [B-1:0] res_and, res_or;

    res_and = 16'hF0F0 & 16'hFF00; // 0xF000
    res_or  = 16'hF0F0 | 16'hFF00; // 0xFFF0

    apply_op(16'hF0F0, 16'hFF00, alu_pkg::BITW_AND);
    `FAIL_UNLESS_LOG(tb_dout == res_and,
        $sformatf("Back-to-back AND fail: expected 0x%04h, got 0x%04h", res_and, tb_dout));

    apply_op(16'hF0F0, 16'hFF00, alu_pkg::BITW_OR);
    `FAIL_UNLESS_LOG(tb_dout == res_or,
        $sformatf("Back-to-back OR fail: expected 0x%04h, got 0x%04h", res_or, tb_dout));
`SVTEST_END
