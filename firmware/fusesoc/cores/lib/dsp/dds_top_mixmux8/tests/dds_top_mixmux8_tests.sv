// ============================================================================
// File: dds_top_mixmux8_tests.sv
// Description: SVUnit test cases for dds_top_mixmux8. Included by
//              dds_top_mixmux8_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_clears_output)
    `FAIL_UNLESS(tb_dds_dout_o === '0);
`SVTEST_END

`SVTEST(tc_zero_gain_mutes_both_iq)
    // PINC/POFF nonzero but GAIN=0: both I and Q must stay at zero.
    write_regs(32'h0100_0000, 32'h0000_0000, 16'h0000);
    repeat(40) @(posedge tb_clk);
    `FAIL_UNLESS(tb_dds_dout_o === '0);
`SVTEST_END

`SVTEST(tc_nonzero_gain_and_pinc_produces_output)
    bit reached;
    write_regs(32'h1000_0000, 32'h0000_0000, 16'h7FFF);
    wait_for_nonzero_output(40, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END

`SVTEST(tc_zero_pinc_full_gain_dc_carrier_has_nonzero_i)
    bit reached;
    // PINC=0, POFF=0 -> phase pinned at 0 -> cos(0)=full-scale, sin(0)=0.
    // With full gain, lane 0's I (cos) must eventually go nonzero.
    write_regs(32'h0000_0000, 32'h0000_0000, 16'h7FFF);
    wait_for_nonzero_output(40, reached);
    `FAIL_UNLESS(reached);
    `FAIL_UNLESS(lane_i(0) !== 16'h0000);
`SVTEST_END
