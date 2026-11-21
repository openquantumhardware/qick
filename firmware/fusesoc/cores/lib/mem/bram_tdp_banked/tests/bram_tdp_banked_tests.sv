// ============================================================================
// File: bram_tdp_banked_tests.sv
// Description: SVUnit test cases for bram_tdp_banked.
// ============================================================================

`SVTEST(tc_same_port_a_readback)
    en_a = 1'b1; we_a = 1'b1;
    addr_a = 4'h0; din_a = 32'h1234_5678;
    @(posedge clk_a); #TSU;

    en_a = 1'b1; we_a = 1'b0;
    addr_a = 4'h0;
    @(posedge clk_a); #TSU;

    `FAIL_IF(dout_a !== 32'h1234_5678);
`SVTEST_END

`SVTEST(tc_same_port_b_readback)
    en_b = 1'b1; we_b = 1'b1;
    addr_b = 4'h2; din_b = 32'hCAFE_BABE;
    @(posedge clk_b); #TSU;

    en_b = 1'b1; we_b = 1'b0;
    addr_b = 4'h2;
    @(posedge clk_b); #TSU;

    `FAIL_IF(dout_b !== 32'hCAFE_BABE);
`SVTEST_END

`SVTEST(tc_cross_dual_clk)
    en_a = 1'b1; we_a = 1'b1;
    addr_a = 4'hA; din_a = 32'hA5A5_5A5A;
    @(posedge clk_a); #TSU;

    en_a = 1'b0; we_a = 1'b0;
    @(posedge clk_a); #TSU;

    en_b = 1'b1; we_b = 1'b0;
    addr_b = 4'hA;
    repeat (10) @(posedge clk_b); #TSU;

    `FAIL_IF(dout_b !== 32'hA5A5_5A5A);
`SVTEST_END

`SVTEST(tc_delayed_read)
    en_a = 1'b1; we_a = 1'b1;
    addr_a = 4'h0; din_a = 32'hAAAA_BBBB;
    @(posedge clk_a); #TSU;

    en_a = 1'b0; we_a = 1'b0;
    repeat (5) @(posedge clk_a);

    en_a = 1'b1; we_a = 1'b0;
    addr_a = 4'h0;
    @(posedge clk_a); #TSU;

    `FAIL_IF(dout_a !== 32'hAAAA_BBBB);
`SVTEST_END

`SVTEST(tc_multi_write_same_port)
    en_a = 1'b1; we_a = 1'b1;
    addr_a = 4'h1; din_a = 32'h1111_1111;
    repeat (1) @(posedge clk_a);
    addr_a = 4'h1; din_a = 32'h1111_1111; // rewrite same addr
    repeat (1) @(posedge clk_a);

    en_a = 1'b1; we_a = 1'b0;
    addr_a = 4'h1;
    repeat (1) @(posedge clk_a);

    `FAIL_IF(dout_a !== 32'h1111_1111);
`SVTEST_END
