// ============================================================================
// File: qcore_ctrl_hazard_tests.sv
// Description: SVUnit test cases for qcore_ctrl_hazard. Included by
//              qcore_ctrl_hazard_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    #1;
    `FAIL_IF(tb_bubble_id_o);
    `FAIL_IF(tb_bubble_rd_o);
    `FAIL_UNLESS(tb_reg_d_dt_o[0] === 32'd0);
    `FAIL_UNLESS(tb_reg_a_dt_o[0] === 32'd0);
`SVTEST_END

`SVTEST(tc_dport_forward_from_x1_alu)
    tb_rs_d_addr_i[0] = 7'd5;
    tb_x1_reg_i = '{we: 1'b1, r_wave_we: 1'b0, addr: 7'd5, src: 2'b00, port_re: 1'b0};
    tb_x1_alu_dt_i = 32'hA1A1_A1A1;
    #1;
    `FAIL_IF(tb_bubble_rd_o); // ALU result is available combinationally, no stall
    @(posedge tb_clk);
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_reg_d_dt_o[0] === 32'hA1A1_A1A1);
`SVTEST_END

`SVTEST(tc_dport_forward_from_x1_dmem_stalls)
    tb_rs_d_addr_i[0] = 7'd5;
    tb_x1_reg_i = '{we: 1'b1, r_wave_we: 1'b0, addr: 7'd5, src: 2'b01, port_re: 1'b0};
    #1;
    `FAIL_UNLESS(tb_bubble_rd_o); // DMEM data not back yet -> bubble
`SVTEST_END

`SVTEST(tc_dport_forward_from_x2_dmem_no_stall)
    tb_rs_d_addr_i[0] = 7'd6;
    tb_x2_reg_i = '{we: 1'b1, r_wave_we: 1'b0, addr: 7'd6, src: 2'b01, port_re: 1'b0};
    tb_x2_dmem_dt_i = 32'hB2B2_B2B2;
    #1;
    `FAIL_IF(tb_bubble_rd_o); // X2-stage DMEM data is already valid
    @(posedge tb_clk);
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_reg_d_dt_o[0] === 32'hB2B2_B2B2);
`SVTEST_END

`SVTEST(tc_dport_no_forward_passthrough)
    tb_rs_d_addr_i[0] = 7'd9;
    tb_rs_d_dt_i[0]   = 32'hC3C3_C3C3;
    @(posedge tb_clk);
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_reg_d_dt_o[0] === 32'hC3C3_C3C3);
`SVTEST_END

`SVTEST(tc_aport_forward_from_x1_alu)
    tb_rs_a_addr_i[0] = 6'd5;
    tb_x1_reg_i = '{we: 1'b1, r_wave_we: 1'b0, addr: 7'd5, src: 2'b00, port_re: 1'b0};
    tb_x1_alu_dt_i = 32'hD4D4_D4D4;
    #1;
    `FAIL_IF(tb_bubble_rd_o);
    @(posedge tb_clk);
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_reg_a_dt_o[0] === 32'hD4D4_D4D4);
`SVTEST_END

`SVTEST(tc_aport_forward_from_x1_dmem_stalls)
    tb_rs_a_addr_i[0] = 6'd5;
    tb_x1_reg_i = '{we: 1'b1, r_wave_we: 1'b0, addr: 7'd5, src: 2'b01, port_re: 1'b0};
    #1;
    `FAIL_UNLESS(tb_bubble_rd_o);
`SVTEST_END

`SVTEST(tc_wmem_after_wave_write_stalls_id)
    tb_id_wmem_we = 1'b1;
    tb_x1_reg_i   = '{we: 1'b0, r_wave_we: 1'b1, addr: 7'd0, src: 2'b00, port_re: 1'b0};
    #1;
    `FAIL_UNLESS(tb_bubble_id_o);
`SVTEST_END

`SVTEST(tc_flag_used_after_flag_we_stalls_id)
    tb_id_flag_used = 1'b1;
    tb_flag_we      = 1'b1;
    #1;
    `FAIL_UNLESS(tb_bubble_id_o);
`SVTEST_END

`SVTEST(tc_flag_used_after_cfg_write_stalls_id)
    tb_id_flag_used = 1'b1;
    tb_x1_reg_i = '{we: 1'b0, r_wave_we: 1'b0, addr: 7'b000_0010, src: 2'b00, port_re: 1'b0}; // s_cfg addr
    #1;
    `FAIL_UNLESS(tb_bubble_id_o);
`SVTEST_END

`SVTEST(tc_jump_after_saddr_write_stalls_id)
    tb_x1_reg_i = '{we: 1'b0, r_wave_we: 1'b0, addr: 7'b000_1111, src: 2'b00, port_re: 1'b0}; // s_addr
    tb_id_jmp_i = 1'b1;
    #1;
    `FAIL_UNLESS(tb_bubble_id_o);
`SVTEST_END

`SVTEST(tc_rand_access_always_stalls_id)
    tb_rd_reg_i = '{we: 1'b0, r_wave_we: 1'b0, addr: 7'b000_0001, src: 2'b00, port_re: 1'b0}; // s_rand write
    #1;
    `FAIL_UNLESS(tb_bubble_id_o);

    tb_rd_reg_i = NO_REG;
    tb_rs_d_addr_i[0] = 7'b000_0001; // s_rand read
    #1;
    `FAIL_UNLESS(tb_bubble_id_o);
`SVTEST_END

`SVTEST(tc_core_rdt_read_after_peripheral_stalls_rd)
    tb_rs_d_addr_i[0] = 7'b000_0110; // core_r_dt (address 6 or 7)
    tb_x1_periph_use  = 1'b1;
    #1;
    `FAIL_UNLESS(tb_bubble_rd_o);
`SVTEST_END

// Regression for openquantumhardware/qick#359: PA/PB hangs when s6/s7 are
// used as A/B source registers. The stall above must also fire when the
// same core_r_dt read reaches the hazard unit through rs_a_addr_i (PA/PB's
// DATA_A/DATA_B, or ARITH's RsA/RsB) instead of rs_d_addr_i -- without a
// stall here, the instruction reads stale/racing core_r_dt data instead of
// the peripheral result it just requested, which is what produced the hang.
`SVTEST(tc_core_rdt_read_via_aport_after_peripheral_stalls_rd)
    tb_rs_a_addr_i[0] = 6'b00_0111; // core_r_dt (address 6 or 7), s7 this time
    tb_x1_periph_use  = 1'b1;
    #1;
    `FAIL_UNLESS(tb_bubble_rd_o);
`SVTEST_END

// The same read, but the peripheral instruction is the READER itself (rd_periph_use is the instruction in RD, whose sources are
// rs_*_addr_i): there is nothing earlier to wait for. A PA/PB with s6/s7 as a source used to wait for the result of the command it
// was about to send, forever (openquantumhardware/qick#359). The two tests above only had the peripheral instruction ahead (X1),
// so they passed while the core hung; qick_processor_prog_tests has the same case as a program.
`SVTEST(tc_core_rdt_read_by_a_peripheral_instruction_itself_does_not_stall_via_dport)
    tb_rs_d_addr_i[0] = 7'b000_0110; // s6, data section
    tb_rd_periph_use  = 1'b1;
    #1;
    `FAIL_IF(tb_bubble_rd_o);
`SVTEST_END

`SVTEST(tc_core_rdt_read_by_a_peripheral_instruction_itself_does_not_stall_via_aport)
    tb_rs_a_addr_i[0] = 6'b00_0111;  // s7, address section
    tb_rd_periph_use  = 1'b1;
    #1;
    `FAIL_IF(tb_bubble_rd_o);
`SVTEST_END

`SVTEST(tc_status_read_by_a_peripheral_instruction_itself_does_not_stall)
    tb_rs_d_addr_i[0] = 7'b000_1010; // s10 status
    tb_rd_periph_use  = 1'b1;
    #1;
    `FAIL_IF(tb_bubble_rd_o);
`SVTEST_END

`SVTEST(tc_stime_read_by_a_peripheral_instruction_itself_does_not_stall)
    tb_rs_d_addr_i[0] = 7'b000_1011; // s11 time_usr
    tb_rd_periph_use  = 1'b1;
    #1;
    `FAIL_IF(tb_bubble_rd_o);
`SVTEST_END

`SVTEST(tc_port_read_after_dport_rd_stalls_rd)
    tb_rs_d_addr_i[0] = 7'b000_1000; // in_port (address 8 or 9)
    tb_rd_reg_i = '{we: 1'b0, r_wave_we: 1'b0, addr: 7'd0, src: 2'b00, port_re: 1'b1};
    #1;
    `FAIL_UNLESS(tb_bubble_rd_o);
`SVTEST_END

`SVTEST(tc_status_read_after_cfg_write_stalls_rd)
    tb_rs_d_addr_i[0] = 7'b000_1010; // status
    tb_x1_reg_i = '{we: 1'b0, r_wave_we: 1'b0, addr: 7'b000_0010, src: 2'b00, port_re: 1'b0}; // s_cfg addr
    #1;
    `FAIL_UNLESS(tb_bubble_rd_o);
`SVTEST_END

`SVTEST(tc_stime_read_after_peripheral_stalls_rd)
    tb_rs_d_addr_i[0] = 7'b000_1011; // time_usr
    tb_x2_periph_use  = 1'b1;
    #1;
    `FAIL_UNLESS(tb_bubble_rd_o);
`SVTEST_END
