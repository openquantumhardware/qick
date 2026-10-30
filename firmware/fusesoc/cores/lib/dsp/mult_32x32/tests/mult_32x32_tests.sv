// ============================================================================
// File: mult_32x32_tests.sv
// Description: SVUnit test cases for mult_32x32. Included by mult_32x32_tc00.sv.
// ============================================================================

`SVTEST(tc_zero_times_zero)
    mult_and_wait(32'd0, 32'd0);
    `FAIL_UNLESS(tb_dout === 64'd0);
`SVTEST_END

`SVTEST(tc_small_product)
    mult_and_wait(32'd6, 32'd7);
    `FAIL_UNLESS(tb_dout === 64'd42);
`SVTEST_END

`SVTEST(tc_identity)
    mult_and_wait(32'hDEAD_BEEF, 32'd1);
    `FAIL_UNLESS(tb_dout === 64'h0000_0000_DEAD_BEEF);
`SVTEST_END

`SVTEST(tc_full_scale)
    // Largest 32-bit unsigned x itself: 0xFFFFFFFF^2 = 0xFFFFFFFE00000001.
    mult_and_wait(32'hFFFF_FFFF, 32'hFFFF_FFFF);
    `FAIL_UNLESS(tb_dout === 64'hFFFF_FFFE_0000_0001);
`SVTEST_END

`SVTEST(tc_pipeline_latency_is_six)
    // Drive a nonzero product, then confirm dout is still 0 for the first
    // 5 cycles and only becomes correct on cycle 6.
    @(negedge tb_clk);
    tb_din_a = 32'd3;
    tb_din_b = 32'd5;
    repeat(5) @(posedge tb_clk);
    @(negedge tb_clk);
    `FAIL_IF(tb_dout === 64'd15);
    @(posedge tb_clk);
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_dout === 64'd15);
`SVTEST_END

`SVTEST(tc_back_to_back_products)
    @(negedge tb_clk);
    tb_din_a = 32'd2;
    tb_din_b = 32'd3;
    @(posedge tb_clk);
    @(negedge tb_clk);
    tb_din_a = 32'd10;
    tb_din_b = 32'd10;
    repeat(5) @(posedge tb_clk);
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_dout === 64'd6);
    @(posedge tb_clk);
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_dout === 64'd100);
`SVTEST_END
