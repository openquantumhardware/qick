// ============================================================================
// File: qcore_mem_tests.sv
// Description: SVUnit test cases for qcore_mem. Included by qcore_mem_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    `FAIL_IF(tb_ps_r_dt_o !== 168'd0);
`SVTEST_END

`SVTEST(tc_pmem_write_read_via_ps_port)
    ps_write(SEL_PMEM, 16'h0003, {96'd0, 72'hAB_CDEF_0123_4567_89});
    ps_read(SEL_PMEM, 16'h0003);
    `FAIL_UNLESS(tb_ps_r_dt_o === {96'd0, 72'hAB_CDEF_0123_4567_89});
`SVTEST_END

`SVTEST(tc_pmem_write_via_ps_visible_on_core_port)
    ps_write(SEL_PMEM, 16'h0005, {96'd0, 72'h1122_3344_5566_7788_99});
    @(negedge tb_clk);
    tb_c_pmem_en_i   = 1'b1;
    tb_c_pmem_addr_i = 8'h05;
    @(negedge tb_clk); // BRAM read latency.
    `FAIL_UNLESS(tb_c_pmem_r_dt_o === 72'h1122_3344_5566_7788_99);
`SVTEST_END

`SVTEST(tc_dmem_write_read_via_core_port)
    @(negedge tb_clk);
    tb_c_dmem_we_i   = 1'b1;
    tb_c_dmem_addr_i = 8'h0A;
    tb_c_dmem_w_dt_i = 32'hDEAD_BEEF;
    @(negedge tb_clk);
    tb_c_dmem_we_i   = 1'b0;
    @(negedge tb_clk); // BRAM read latency (read is always enabled on port A).
    `FAIL_UNLESS(tb_c_dmem_r_dt_o === 32'hDEAD_BEEF);
`SVTEST_END

`SVTEST(tc_dmem_write_via_ps_visible_via_ps_readback)
    ps_write(SEL_DMEM, 16'h0007, {136'd0, 32'hCAFE_F00D});
    ps_read(SEL_DMEM, 16'h0007);
    `FAIL_UNLESS(tb_ps_r_dt_o === {136'd0, 32'hCAFE_F00D});
`SVTEST_END

`SVTEST(tc_wmem_write_read_via_ps_port)
    ps_write(SEL_WMEM, 16'h0002, 168'h1_2222_3333_4444_5555_6666_7777_8888_9999);
    ps_read(SEL_WMEM, 16'h0002);
    `FAIL_UNLESS(tb_ps_r_dt_o === 168'h1_2222_3333_4444_5555_6666_7777_8888_9999);
`SVTEST_END

`SVTEST(tc_wmem_write_via_ps_visible_on_core_port)
    ps_write(SEL_WMEM, 16'h0004, 168'hFEDC_BA98_7654_3210_0011_2233_4455_6677_88);
    @(negedge tb_clk);
    tb_c_wmem_addr_i = 8'h04;
    @(negedge tb_clk); // BRAM read latency (read is always enabled on wmem port A).
    `FAIL_UNLESS(tb_c_wmem_r_dt_o === 168'hFEDC_BA98_7654_3210_0011_2233_4455_6677_88);
`SVTEST_END

`SVTEST(tc_banks_are_isolated)
    ps_write(SEL_PMEM, 16'h0001, {96'd0, 72'hAAAA_AAAA_AAAA_AAAA_AA});
    ps_write(SEL_DMEM, 16'h0001, {136'd0, 32'hBBBB_BBBB});
    ps_read(SEL_PMEM, 16'h0001);
    `FAIL_UNLESS(tb_ps_r_dt_o === {96'd0, 72'hAAAA_AAAA_AAAA_AAAA_AA});
    ps_read(SEL_DMEM, 16'h0001);
    `FAIL_UNLESS(tb_ps_r_dt_o === {136'd0, 32'hBBBB_BBBB});
`SVTEST_END

`SVTEST(tc_sel_none_reads_zero)
    ps_write(SEL_PMEM, 16'h0000, {96'd0, 72'hFFFF_FFFF_FFFF_FFFF_FF});
    @(negedge tb_clk);
    tb_ps_sel_i = SEL_NONE;
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_ps_r_dt_o === 168'd0);
`SVTEST_END
