// ============================================================================
// File: dds_top_sgmux8_tests.sv
// Description: SVUnit test cases for dds_top_sgmux8. Included by
//              dds_top_sgmux8_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_clears_output)
    `FAIL_UNLESS(tb_dds_dout_o === '0);
`SVTEST_END

`SVTEST(tc_zero_gain_mutes_output)
    bit reached;
    // PINC/POFF nonzero but GAIN=0: the gain multiply must keep the output
    // at zero regardless of the DDS lane's own waveform.
    write_regs(32'h0100_0000, 32'h0000_0000, 16'h0000);
    repeat(40) @(posedge tb_clk);
    `FAIL_UNLESS(tb_dds_dout_o === '0);
`SVTEST_END

`SVTEST(tc_nonzero_gain_and_pinc_produces_output)
    bit reached;
    // With a nonzero phase increment and full-scale gain, lane 0 must
    // eventually produce a nonzero sample (liveness through the full
    // phase_ctrl -> dds_compiler -> gain pipeline).
    write_regs(32'h1000_0000, 32'h0000_0000, 16'h7FFF);
    wait_for_nonzero_output(40, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END

`SVTEST(tc_zero_pinc_full_gain_dc_output)
    bit reached;
    // PINC=0 keeps phase pinned to POFF's static value; a nonzero POFF at
    // full gain should still eventually produce a nonzero (DC) sample.
    write_regs(32'h0000_0000, 32'h4000_0000, 16'h7FFF);
    wait_for_nonzero_output(40, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END
