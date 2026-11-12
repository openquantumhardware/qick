// ============================================================================
// File: qproc_inport_reg_tests.sv
// Description: SVUnit test cases for qproc_inport_reg. Included by
//              qproc_inport_reg_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    `FAIL_IF(tb_port_tnew_o !== 16'h0000);
`SVTEST_END

`SVTEST(tc_latch_on_valid_sets_new_flag)
    push_data(0, 64'hDEAD_BEEF_0000_0001);
    `FAIL_UNLESS(tb_port_tnew_o[0] === 1'b1);
    `FAIL_UNLESS(tb_port_tdata_o[0] === 64'hDEAD_BEEF_0000_0001);
`SVTEST_END

`SVTEST(tc_ports_are_independent)
    push_data(0, 64'h1111_1111_1111_1111);
    push_data(1, 64'h2222_2222_2222_2222);
    `FAIL_UNLESS(tb_port_tnew_o === 16'b11);
    `FAIL_UNLESS(tb_port_tdata_o[0] === 64'h1111_1111_1111_1111);
    `FAIL_UNLESS(tb_port_tdata_o[1] === 64'h2222_2222_2222_2222);
`SVTEST_END

`SVTEST(tc_clear_deasserts_new_flag)
    push_data(0, 64'hAAAA_AAAA_AAAA_AAAA);
    `FAIL_UNLESS(tb_port_tnew_o[0] === 1'b1);
    pulse_clear();
    `FAIL_IF(tb_port_tnew_o[0] === 1'b1);
`SVTEST_END

`SVTEST(tc_clear_does_not_erase_latched_data)
    push_data(0, 64'hBEEF_BEEF_BEEF_BEEF);
    pulse_clear();
    `FAIL_UNLESS(tb_port_tdata_o[0] === 64'hBEEF_BEEF_BEEF_BEEF);
`SVTEST_END

`SVTEST(tc_valid_wins_over_simultaneous_clear)
    push_data(0, 64'h1234_5678_0000_0000);
    @(negedge tb_clk);
    tb_clear = 1'b1;
    tb_port_tvalid_i[0] = 1'b1;
    tb_port_tdata_i[0]  = 64'hCAFE_CAFE_0000_0000;
    @(negedge tb_clk);
    tb_clear = 1'b0;
    tb_port_tvalid_i[0] = 1'b0;
    `FAIL_UNLESS(tb_port_tnew_o[0] === 1'b1);
    `FAIL_UNLESS(tb_port_tdata_o[0] === 64'hCAFE_CAFE_0000_0000);
`SVTEST_END

`SVTEST(tc_unused_bits_of_tnew_are_zero)
    push_data(0, 64'h1);
    push_data(1, 64'h1);
    `FAIL_IF(tb_port_tnew_o[15:2] !== 14'b0);
`SVTEST_END
