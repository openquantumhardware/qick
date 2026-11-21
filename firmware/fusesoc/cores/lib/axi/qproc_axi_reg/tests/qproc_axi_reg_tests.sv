// ============================================================================
// File: qproc_axi_reg_tests.sv
// Description: SVUnit test cases for qproc_axi_reg. Included by
//              qproc_axi_reg_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    `FAIL_IF(tb_tproc_ctrl_o !== 16'h0000);
    `FAIL_IF(tb_mem_addr_o   !== 16'h0000);
    `FAIL_IF(tb_core_cfg_o   !== 8'h00);
`SVTEST_END

`SVTEST(tc_write_read_tproc_cfg)
    axi_if.axi_write(ADDR_TPROC_CFG, 32'h0000_ABCD);
    `FAIL_UNLESS(tb_tproc_cfg_o === 16'hABCD);
`SVTEST_END

`SVTEST(tc_write_mem_addr_and_len)
    axi_if.axi_write(ADDR_MEM_ADDR, 32'h0000_1234);
    axi_if.axi_write(ADDR_MEM_LEN,  32'h0000_5678);
    `FAIL_UNLESS(tb_mem_addr_o === 16'h1234);
    `FAIL_UNLESS(tb_mem_len_o  === 16'h5678);
`SVTEST_END

`SVTEST(tc_write_32bit_registers)
    axi_if.axi_write(ADDR_MEM_DT_I,    32'hDEAD_BEEF);
    axi_if.axi_write(ADDR_TPROC_W_DT1, 32'h1111_2222);
    axi_if.axi_write(ADDR_TPROC_W_DT2, 32'h3333_4444);
    `FAIL_UNLESS(tb_mem_dt_i_o    === 32'hDEAD_BEEF);
    `FAIL_UNLESS(tb_tproc_w_dt1_o === 32'h1111_2222);
    `FAIL_UNLESS(tb_tproc_w_dt2_o === 32'h3333_4444);
`SVTEST_END

`SVTEST(tc_write_8bit_registers)
    axi_if.axi_write(ADDR_CORE_CFG, 32'h0000_00A5);
    axi_if.axi_write(ADDR_READ_SEL, 32'h0000_005A);
    `FAIL_UNLESS(tb_core_cfg_o === 8'hA5);
    `FAIL_UNLESS(tb_read_sel_o === 8'h5A);
`SVTEST_END

`SVTEST(tc_readback_matches_write)
    logic [31:0] rd_data;
    axi_if.axi_write(ADDR_MEM_DT_I, 32'hCAFE_F00D);
    axi_if.axi_read(ADDR_MEM_DT_I, rd_data);
    `FAIL_UNLESS(rd_data === 32'hCAFE_F00D);
`SVTEST_END

`SVTEST(tc_version_id_is_read_only)
    logic [31:0] rd_data;
    // Attempt to write, then confirm the read-back is still the fixed id.
    axi_if.axi_write(ADDR_VERSION_ID, 32'hFFFF_FFFF);
    axi_if.axi_read(ADDR_VERSION_ID, rd_data);
    `FAIL_UNLESS(rd_data === 32'd9);
`SVTEST_END

`SVTEST(tc_status_inputs_pass_through)
    logic [31:0] rd_data;
    tb_mem_dt_o_i     = 32'h1111_1111;
    tb_tproc_r_dt1_i  = 32'h2222_2222;
    tb_tproc_r_dt2_i  = 32'h3333_3333;
    tb_time_usr_i     = 32'h4444_4444;
    tb_tproc_status_i = 32'h5555_5555;
    tb_tproc_debug_i  = 32'h6666_6666;

    axi_if.axi_read(ADDR_MEM_DT_O, rd_data);
    `FAIL_UNLESS(rd_data === 32'h1111_1111);
    axi_if.axi_read(ADDR_TPROC_R_DT1, rd_data);
    `FAIL_UNLESS(rd_data === 32'h2222_2222);
    axi_if.axi_read(ADDR_TPROC_R_DT2, rd_data);
    `FAIL_UNLESS(rd_data === 32'h3333_3333);
    axi_if.axi_read(ADDR_TIME_USR, rd_data);
    `FAIL_UNLESS(rd_data === 32'h4444_4444);
    axi_if.axi_read(ADDR_TPROC_STATUS, rd_data);
    `FAIL_UNLESS(rd_data === 32'h5555_5555);
    axi_if.axi_read(ADDR_TPROC_DEBUG, rd_data);
    `FAIL_UNLESS(rd_data === 32'h6666_6666);
`SVTEST_END

`SVTEST(tc_tproc_ctrl_auto_clears)
    logic [31:0] rd_data;
    axi_if.axi_write(ADDR_TPROC_CTRL, 32'h0000_0001);
    // By the time the write's bus handshake fully completes, the
    // one-shot pulse should already have self-cleared.
    axi_if.axi_read(ADDR_TPROC_CTRL, rd_data);
    `FAIL_UNLESS(rd_data === 32'h0000_0000);
    `FAIL_UNLESS(tb_tproc_ctrl_o === 16'h0000);
`SVTEST_END

`SVTEST(tc_tproc_ctrl_rewrite_after_clear)
    axi_if.axi_write(ADDR_TPROC_CTRL, 32'h0000_0002);
    `FAIL_UNLESS(tb_tproc_ctrl_o === 16'h0000); // Already cleared by the time write() returns.
    axi_if.axi_write(ADDR_TPROC_CTRL, 32'h0000_0004);
    `FAIL_UNLESS(tb_tproc_ctrl_o === 16'h0000);
`SVTEST_END
