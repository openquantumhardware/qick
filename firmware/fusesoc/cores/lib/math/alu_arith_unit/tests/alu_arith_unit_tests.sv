//--------------------------------------------------------------------------
// test00: Reset state
//   After reset, dout must be zero and zero_a/zero_b must assert (inputs=0).
//--------------------------------------------------------------------------
`SVTEST(test00_reset_state)
    // rstn already deasserted by setup; inputs are zero
    `FAIL_IF_LOG($isunknown(tb_zero_a), "zero_a should not be X/Z after reset");
    `FAIL_IF_LOG($isunknown(tb_zero_b), "zero_b should not be X/Z after reset");
    `FAIL_UNLESS_LOG(tb_zero_a == 1'b1, "zero_a should be 1 when din_a=0");
    `FAIL_UNLESS_LOG(tb_zero_b == 1'b1, "zero_b should be 1 when din_b=0");
    `FAIL_UNLESS_LOG(tb_dout   == '0,   "dout should be 0 after reset");
`SVTEST_END

//--------------------------------------------------------------------------
// test01: ADD operation
//   Verify dout = din_a + din_b after 2-cycle pipeline latency.
//--------------------------------------------------------------------------
`SVTEST(test01_add)
    logic [B-1:0] a, b;
    logic [B-1:0] expected;

    a        = 16'd100;
    b        = 16'd200;
    expected = 16'd300;

    apply_op(a, b, alu_pkg::ARITH_ADD);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("ADD fail: %0d + %0d = expected 0x%04h, got 0x%04h",
            a, b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test02: SUB operation
//   Verify dout = din_a - din_b after 2-cycle pipeline latency.
//--------------------------------------------------------------------------
`SVTEST(test02_sub)
    logic [B-1:0] a, b;
    logic [B-1:0] expected;

    a        = 16'd500;
    b        = 16'd300;
    expected = 16'd200;

    apply_op(a, b, alu_pkg::ARITH_SUB);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("SUB fail: %0d - %0d = expected 0x%04h, got 0x%04h",
            a, b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test03: MUL operation
//   Verify dout = din_a[B/2-1:0] * din_b[B/2-1:0].
//   Product uses lower B/2 bits of each operand (as per RTL spec).
//--------------------------------------------------------------------------
`SVTEST(test03_mul)
    logic [B-1:0]   a, b;
    logic [B-1:0]   expected;
    logic [B/2-1:0] a_lo, b_lo;

    a    = 16'h0005; // lower 8 bits = 5
    b    = 16'h0006; // lower 8 bits = 6
    a_lo = a[B/2-1:0];
    b_lo = b[B/2-1:0];
    expected = B'(a_lo * b_lo); // 5 * 6 = 30

    apply_op(a, b, alu_pkg::ARITH_MUL);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("MUL fail: lower(%0d) * lower(%0d) = expected 0x%04h, got 0x%04h",
            a, b, expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test04: Signed ADD (negative result)
//   Verify signed addition wraps correctly in two's complement.
//--------------------------------------------------------------------------
`SVTEST(test04_signed_add_negative)
    logic signed [B-1:0] a, b;
    logic [B-1:0]        expected;

    a        = 16'sd10;
    b        = -16'sd30;   // two's complement negative
    expected = B'(a + b);  // = -20 in two's complement

    apply_op(B'(a), B'(b), alu_pkg::ARITH_ADD);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("Signed ADD fail: 10 + (-30): expected 0x%04h, got 0x%04h",
            expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test05: Signed SUB (negative result)
//   Verify signed subtraction where result underflows into negative range.
//--------------------------------------------------------------------------
`SVTEST(test05_signed_sub_negative)
    logic signed [B-1:0] a, b;
    logic [B-1:0]        expected;

    a        = 16'sd5;
    b        = 16'sd20;
    expected = B'(a - b); // = -15 in two's complement

    apply_op(B'(a), B'(b), alu_pkg::ARITH_SUB);

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("Signed SUB fail: 5 - 20: expected 0x%04h, got 0x%04h",
            expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test06: Zero detection combinational response
//   zero_a and zero_b are combinational; verify they respond within the
//   same cycle as input changes, independent of the pipeline.
//--------------------------------------------------------------------------
`SVTEST(test06_zero_detection)
    // Drive non-zero values first
    cb.tb_din_a <= 16'hABCD;
    cb.tb_din_b <= 16'h1234;
    @(cb);
    `FAIL_UNLESS_LOG(tb_zero_a == 1'b0, "zero_a should be 0 for non-zero din_a");
    `FAIL_UNLESS_LOG(tb_zero_b == 1'b0, "zero_b should be 0 for non-zero din_b");

    // Set din_a to zero, din_b remains non-zero
    cb.tb_din_a <= '0;
    @(cb);
    `FAIL_UNLESS_LOG(tb_zero_a == 1'b1, "zero_a should assert when din_a=0");
    `FAIL_UNLESS_LOG(tb_zero_b == 1'b0, "zero_b should remain 0");

    // Set din_b to zero as well
    cb.tb_din_b <= '0;
    @(cb);
    `FAIL_UNLESS_LOG(tb_zero_a == 1'b1, "zero_a should remain asserted");
    `FAIL_UNLESS_LOG(tb_zero_b == 1'b1, "zero_b should assert when din_b=0");
`SVTEST_END

//--------------------------------------------------------------------------
// test07: Default opcode (undefined op)
//   Any opcode not mapped in the case statement must produce dout=0.
//--------------------------------------------------------------------------
`SVTEST(test07_default_op)
    logic [B-1:0] a, b;

    a = 16'hFFFF;
    b = 16'hFFFF;

    apply_op(a, b, 4'hF); // Undefined opcode

    `FAIL_UNLESS_LOG(tb_dout == '0,
        $sformatf("Default op fail: undefined opcode should yield 0, got 0x%04h", tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test08: Pipeline latency isolation
//   Confirm that the output only reflects the result after exactly 2 cycles,
//   not 1 or 3, by checking intermediate values explicitly.
//--------------------------------------------------------------------------
`SVTEST(test08_pipeline_latency)
    logic [B-1:0] a, b;
    logic [B-1:0] expected;

    a        = 16'd10;
    b        = 16'd20;
    expected = 16'd30; // ADD result

    cb.tb_din_a <= a;
    cb.tb_din_b <= b;
    cb.tb_op    <= alu_pkg::ARITH_ADD;
    @(cb); // Cycle 1: inputs registered

    // After 1 cycle: dout_r holds result, dout_rr still old
    `FAIL_IF_LOG(tb_dout == expected,
        "Pipeline: result should NOT appear at dout after only 1 cycle");

    @(cb); // Cycle 2: dout_r -> dout_rr
    @(cb); // Sample after second register stage

    `FAIL_UNLESS_LOG(tb_dout == expected,
        $sformatf("Pipeline: expected 0x%04h at dout after 2 cycles, got 0x%04h",
            expected, tb_dout));
`SVTEST_END

//--------------------------------------------------------------------------
// test09: Back-to-back operations
//   Verify that consecutive operations through the pipeline do not corrupt
//   each other (no data hazard in the 2-stage chain).
//--------------------------------------------------------------------------
`SVTEST(test09_back_to_back)
    logic [B-1:0] res_add, res_sub;

    res_add = 16'd50 + 16'd70; // = 120
    res_sub = 16'd50 - 16'd70; // = -20 (two's complement)

    // Issue ADD
    apply_op(16'd50, 16'd70, alu_pkg::ARITH_ADD);
    `FAIL_UNLESS_LOG(tb_dout == res_add,
        $sformatf("Back-to-back ADD fail: expected 0x%04h, got 0x%04h", res_add, tb_dout));

    // Issue SUB immediately after (no idle cycles)
    apply_op(16'd50, 16'd70, alu_pkg::ARITH_SUB);
    `FAIL_UNLESS_LOG(tb_dout == B'(res_sub),
        $sformatf("Back-to-back SUB fail: expected 0x%04h, got 0x%04h", B'(res_sub), tb_dout));
`SVTEST_END
