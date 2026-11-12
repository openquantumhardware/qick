// ============================================================================
// File: sg_mixmux8_tests.sv
// Description: SVUnit test cases for sg_mixmux8. Included by
//              sg_mixmux8_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    `FAIL_UNLESS(tb_m_axis_tvalid_o === 1'b0);
    `FAIL_UNLESS(tb_s_axis_tready_o === 1'b1);
    `FAIL_UNLESS(tb_m_axis_tdata_o === '0);
`SVTEST_END

`SVTEST(tc_descriptor_produces_valid_output)
    bit reached;
    write_channel_regs(0, 32'h1000_0000, 32'h0000_0000, 16'h7FFF);
    push_descriptor(8'h01, 32'd20);
    wait_for_mvalid(1'b1, 40, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END

`SVTEST(tc_all_channels_masked_off_gives_zero_iq_output)
    bit reached;
    write_channel_regs(0, 32'h1000_0000, 32'h0000_0000, 16'h7FFF);
    push_descriptor(8'h00, 32'd20);
    wait_for_mvalid(1'b1, 40, reached);
    `FAIL_UNLESS(reached);
    `FAIL_UNLESS(tb_m_axis_tdata_o === '0);
`SVTEST_END

`SVTEST(tc_mvalid_deasserts_after_playback)
    bit reached;
    write_channel_regs(0, 32'h1000_0000, 32'h0000_0000, 16'h7FFF);
    push_descriptor(8'h01, 32'd4);
    wait_for_mvalid(1'b1, 40, reached);
    `FAIL_UNLESS(reached);
    wait_for_mvalid(1'b0, 30, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END

`SVTEST(tc_dc_carrier_gives_nonzero_real_lane)
    // PINC=0, POFF=0 -> phase pinned at 0 -> cos(0)=full-scale, sin(0)=0.
    // Lane 0's real (I) half-word of m_axis_tdata_o must go nonzero while
    // the imaginary (Q) half can legitimately stay near zero.
    bit reached;
    write_channel_regs(0, 32'h0000_0000, 32'h0000_0000, 16'h7FFF);
    push_descriptor(8'h01, 32'd20);
    wait_for_mvalid(1'b1, 40, reached);
    `FAIL_UNLESS(reached);
    `FAIL_UNLESS(tb_m_axis_tdata_o[15:0] !== 16'h0000);
`SVTEST_END
