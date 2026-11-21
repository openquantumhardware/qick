// ============================================================================
// File: qcore_reg_bank_tests.sv
// Description: SVUnit test cases for qcore_reg_bank. Included by
//              qcore_reg_bank_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    tb_rs_D_addr_i[0] = 7'b000_0000; // bank 00, addr 0 -> hardwired zero
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_rs_D_dt_o[0] === 32'd0);
    `FAIL_UNLESS(tb_reg_cfg_o  === 8'd0);
    `FAIL_UNLESS(tb_reg_ctrl_o === 8'd0);
    `FAIL_UNLESS(tb_out_time_o === 32'd0);
    `FAIL_UNLESS(tb_out_addr_o === '0);
    `FAIL_UNLESS(tb_out_wreg_o === 168'd0);
    `FAIL_UNLESS(tb_sreg_dt_o[0] === 32'd0);
    `FAIL_UNLESS(tb_sreg_dt_o[1] === 32'd0);
`SVTEST_END

`SVTEST(tc_dreg_write_read)
    reg_write(addr_dreg(5), 32'hDEAD_BEEF);
    tb_rs_D_addr_i[0] = addr_dreg(5);
    tb_rs_A_addr_i[0] = {1'b1, 1'b0, 4'd5}; // bit5=1 selects dreg bank on the A port
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_rs_D_dt_o[0] === 32'hDEAD_BEEF);
    `FAIL_UNLESS(tb_rs_A_dt_o[0] === 32'hDEAD_BEEF);
`SVTEST_END

`SVTEST(tc_sreg_special_bank_write_read)
    reg_write(addr_sreg_special(0), 32'hCAFE_F00D);
    tb_rs_D_addr_i[0] = addr_sreg_special(0);
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_rs_D_dt_o[0]   === 32'hCAFE_F00D);
    `FAIL_UNLESS(tb_sreg_dt_o[0]   === 32'hCAFE_F00D);

    reg_write(addr_sreg_special(2), 32'h1111_2222); // sreg_dt[2] -> out_time_o
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_out_time_o === 32'h1111_2222);

    reg_write(addr_sreg_special(3), 32'h0000_00AB); // sreg_dt[3] -> out_addr_o[PMEM_AW-1:0]
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_out_addr_o === 8'hAB);
`SVTEST_END

`SVTEST(tc_sreg_cfg_ctrl_write_and_selfclear)
    reg_write(ADDR_SREG_CFG, 32'h00A5_003C); // cfg=8'h3C, ctrl=8'hA5
    `FAIL_UNLESS(tb_reg_cfg_o  === 8'h3C);
    `FAIL_UNLESS(tb_reg_ctrl_o === 8'hA5);

    // ctrl is a one-shot strobe: it self-clears the cycle after the write
    // (cfg has no such auto-clear).
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_reg_cfg_o  === 8'h3C);
    `FAIL_UNLESS(tb_reg_ctrl_o === 8'h00);
`SVTEST_END

`SVTEST(tc_wreg_write_read)
    reg_write(addr_wreg(2), 32'h1122_3344);
    tb_rs_D_addr_i[0] = addr_wreg(2);
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_rs_D_dt_o[0] === 32'h1122_3344);
`SVTEST_END

`SVTEST(tc_wave_we_loads_all_wregs)
    tb_wave_dt_i = 168'h1_2222_3333_4444_5555_6666_7777_8888_9999;
    @(negedge tb_clk);
    tb_wave_we_i = 1'b1;
    @(negedge tb_clk);
    tb_wave_we_i = 1'b0;
    `FAIL_UNLESS(tb_out_wreg_o === 168'h1_2222_3333_4444_5555_6666_7777_8888_9999);
`SVTEST_END

`SVTEST(tc_external_sfr_direct_read)
    tb_reg_arith_i     = 32'hA000_0001;
    tb_reg_div_i[0]    = 32'hA000_0002;
    tb_reg_div_i[1]    = 32'hA000_0003;
    tb_tproc_ext_i[0]  = 32'hA000_0004;
    tb_tproc_ext_i[1]  = 32'hA000_0005;
    tb_reg_port_i[0]   = 32'hA000_0006;
    tb_reg_port_i[1]   = 32'hA000_0007;
    tb_status_i        = 32'hA000_0008;
    tb_time_dt_i       = 32'hA000_0009;
    @(negedge tb_clk);
    tb_rs_D_addr_i[0] = 7'd3;  #1; `FAIL_UNLESS(tb_rs_D_dt_o[0] === 32'hA000_0001); // reg_arith_i
    tb_rs_D_addr_i[0] = 7'd4;  #1; `FAIL_UNLESS(tb_rs_D_dt_o[0] === 32'hA000_0002); // reg_div_i[0]
    tb_rs_D_addr_i[0] = 7'd5;  #1; `FAIL_UNLESS(tb_rs_D_dt_o[0] === 32'hA000_0003); // reg_div_i[1]
    tb_rs_D_addr_i[0] = 7'd6;  #1; `FAIL_UNLESS(tb_rs_D_dt_o[0] === 32'hA000_0004); // tproc_ext_i[0]
    tb_rs_D_addr_i[0] = 7'd7;  #1; `FAIL_UNLESS(tb_rs_D_dt_o[0] === 32'hA000_0005); // tproc_ext_i[1]
    tb_rs_D_addr_i[0] = 7'd8;  #1; `FAIL_UNLESS(tb_rs_D_dt_o[0] === 32'hA000_0006); // reg_port_i[0]
    tb_rs_D_addr_i[0] = 7'd9;  #1; `FAIL_UNLESS(tb_rs_D_dt_o[0] === 32'hA000_0007); // reg_port_i[1]
    tb_rs_D_addr_i[0] = 7'd10; #1; `FAIL_UNLESS(tb_rs_D_dt_o[0] === 32'hA000_0008); // status_i
    tb_rs_D_addr_i[0] = 7'd11; #1; `FAIL_UNLESS(tb_rs_D_dt_o[0] === 32'hA000_0009); // time_dt_i
`SVTEST_END

`SVTEST(tc_lfsr_load_overrides_lfsr)
    reg_write(ADDR_LFSR_LOAD, 32'hABCD_1234);
    `FAIL_UNLESS(tb_lfsr_o === 32'hABCD_1234);
`SVTEST_END
