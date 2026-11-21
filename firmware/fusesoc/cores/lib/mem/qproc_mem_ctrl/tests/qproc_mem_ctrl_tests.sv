// ============================================================================
// File: qproc_mem_ctrl_tests.sv
// Description: SVUnit test cases for qproc_mem_ctrl. Included by
//              qproc_mem_ctrl_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    `FAIL_IF(tb_busy_o !== 1'b0);
    `FAIL_IF(tb_ext_mem_we_o !== 1'b0);
`SVTEST_END

`SVTEST(tc_single_write_dmem)
    tb_mem_addr = 16'h0012;
    tb_mem_dt_i = 32'hDEAD_BEEF;
    start_mem(.op(1'b1), .sel(SEL_DMEM), .source(1'b1));
    wait_until_high(tb_end_single_o);
    `FAIL_UNLESS(tb_ext_mem_addr_o === 16'h0012);
    `FAIL_UNLESS(tb_ext_mem_w_dt_o === {136'd0, 32'hDEAD_BEEF});
    `FAIL_UNLESS(tb_busy_o === 1'b0); // single access does not go through dmem_ctrl's busy arbitration.
    stop_mem();
`SVTEST_END

`SVTEST(tc_single_write_pmem_is_suppressed_externally)
    tb_mem_addr = 16'h0003;
    tb_mem_dt_i = 32'hFFFF_FFFF;
    start_mem(.op(1'b1), .sel(SEL_PMEM), .source(1'b1));
    // The internal single-access engine still runs to completion...
    wait_until_high(tb_end_single_o);
    // ...but the external write strobe is gated to the DMEM bank only.
    `FAIL_IF(tb_ext_mem_we_o === 1'b1);
    stop_mem();
`SVTEST_END

`SVTEST(tc_single_read_dmem)
    tb_ext_mem_r_dt_i = {136'd0, 32'hCAFE_F00D};
    tb_mem_addr = 16'h0020;
    start_mem(.op(1'b0), .sel(SEL_DMEM), .source(1'b1));
    wait_until_high(tb_end_single_o);
    `FAIL_UNLESS(tb_mem_dt_o === 32'hCAFE_F00D);
    stop_mem();
`SVTEST_END

`SVTEST(tc_axis_write_wmem_field_packing)
    logic [31:0] l_freq   = 32'h1111_1111;
    logic [31:0] l_phase  = 32'h2222_2222;
    logic [31:0] l_env    = 32'h00_333333;
    logic [31:0] l_gain   = 32'h4444_4444;
    logic [31:0] l_length = 32'h5555_5555;
    logic [31:0] l_conf   = 32'h0000_6666;
    logic [167:0] expected;

    expected = {l_conf[15:0], l_length, l_gain, l_env[23:0], l_phase, l_freq};

    tb_mem_addr = 16'h0000;
    start_mem(.op(1'b1), .sel(SEL_WMEM), .source(1'b0));

    @(posedge tb_clk);
    tb_s_axis_tdata_i  = {64'd0, l_conf, l_length, l_gain, l_env, l_phase, l_freq};
    tb_s_axis_tvalid_i = 1'b1;
    tb_s_axis_tlast_i  = 1'b1;
    wait_until_high(tb_s_axis_tready_o);
    @(posedge tb_clk);
    tb_s_axis_tvalid_i = 1'b0;
    tb_s_axis_tlast_i  = 1'b0;

    `FAIL_UNLESS(tb_ext_mem_we_o === 1'b1);
    `FAIL_UNLESS(tb_ext_mem_w_dt_o === expected);

    stop_mem();
`SVTEST_END

`SVTEST(tc_axis_read_busy_and_data)
    tb_ext_mem_r_dt_i = {88'd0, 72'h1122_3344_5566_7788_99};
    tb_mem_addr = 16'h0000;
    tb_mem_len  = 16'h0001;
    start_mem(.op(1'b0), .sel(SEL_PMEM), .source(1'b0));

    wait_until_high(tb_busy_o);
    `FAIL_UNLESS(tb_busy_o === 1'b1);

    wait_until_high(tb_m_axis_tvalid_o);
    `FAIL_UNLESS(tb_m_axis_tdata_o[71:0] === 72'h1122_3344_5566_7788_99);
    `FAIL_UNLESS(tb_m_axis_tlast_o === 1'b1);

    stop_mem();
`SVTEST_END
