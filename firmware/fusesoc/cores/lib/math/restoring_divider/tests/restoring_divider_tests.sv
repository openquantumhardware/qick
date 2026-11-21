//------------------------------------------------------------------------------
// Tests
//------------------------------------------------------------------------------

`SVTEST(test00_reset_ready)
    `FAIL_UNLESS_LOG(tb_ready == 1'b1, "Divider should be ready (idle) after reset");
`SVTEST_END

`SVTEST(test01_simple_division_with_remainder)
    run_division(32'd100, 32'd7);
    `FAIL_UNLESS_LOG(tb_quotient == 32'd14,
        $sformatf("100/7 quotient: expected 14, got %0d", tb_quotient));
    `FAIL_UNLESS_LOG(tb_remainder == 32'd2,
        $sformatf("100/7 remainder: expected 2, got %0d", tb_remainder));
`SVTEST_END

`SVTEST(test02_exact_division)
    run_division(32'd100, 32'd5);
    `FAIL_UNLESS_LOG(tb_quotient == 32'd20,
        $sformatf("100/5 quotient: expected 20, got %0d", tb_quotient));
    `FAIL_UNLESS_LOG(tb_remainder == 32'd0,
        $sformatf("100/5 remainder: expected 0, got %0d", tb_remainder));
`SVTEST_END

`SVTEST(test03_divide_by_one)
    run_division(32'd12345, 32'd1);
    `FAIL_UNLESS_LOG(tb_quotient == 32'd12345,
        $sformatf("12345/1 quotient: expected 12345, got %0d", tb_quotient));
    `FAIL_UNLESS_LOG(tb_remainder == 32'd0,
        $sformatf("12345/1 remainder: expected 0, got %0d", tb_remainder));
`SVTEST_END

`SVTEST(test04_zero_dividend)
    run_division(32'd0, 32'd5);
    `FAIL_UNLESS_LOG(tb_quotient == 32'd0, "0/5 quotient should be 0");
    `FAIL_UNLESS_LOG(tb_remainder == 32'd0, "0/5 remainder should be 0");
`SVTEST_END

`SVTEST(test05_ready_falls_during_computation)
    tb_a     = 32'd100;
    tb_b     = 32'd3;
    tb_start = 1'b1;
    @(posedge tb_clk);
    tb_start = 1'b0;
    @(posedge tb_clk);
    `FAIL_IF_LOG(tb_ready == 1'b1, "ready_o should be low while dividing");
    wait (tb_ready == 1'b1);
`SVTEST_END

`SVTEST(test06_quotient_msb_always_zero_inherited_quirk)
    // Documented inherited quirk (see restoring_divider.sv header): the
    // FSM never runs the "working" iteration for bit index DW-1, so
    // div_quotient_o[31] always reads 0 even when the true quotient needs
    // it. 0xFFFFFFFF / 1 mathematically has quotient bit 31 set.
    run_division(32'hFFFFFFFF, 32'd1);
    `FAIL_UNLESS_LOG(tb_quotient == 32'h7FFFFFFF,
        $sformatf("Expected quirked quotient 0x7FFFFFFF (bit 31 stuck at 0), got 0x%08h",
                  tb_quotient));
`SVTEST_END
