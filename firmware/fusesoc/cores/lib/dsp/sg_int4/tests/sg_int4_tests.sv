// ============================================================================
// File: sg_int4_tests.sv
// Description: SVUnit test cases for sg_int4. Included by sg_int4_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    `FAIL_UNLESS(tb_m_axis_tvalid_o === 1'b0);
    `FAIL_UNLESS(tb_fifo_rd_en_o === 1'b1);
`SVTEST_END

`SVTEST(tc_dds_only_descriptor_produces_valid_output)
    bit reached;
    // outsel=1 (DDS only): doesn't depend on the FIR/envelope path settling.
    push_descriptor(build_descr(32'h1000_0000, 32'd0, 16'd0, 16'sd32767,
                                 16'd10, 2'd1, 1'b0, 1'b0, 1'b0));
    wait_for_mvalid(1'b1, 60, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END

`SVTEST(tc_envelope_only_descriptor_produces_nonzero_output)
    bit reached;
    // outsel=2 (envelope/FIR only, no DDS): with a constant nonzero envelope
    // sample (see tb_env_real/imag in setup), the interpolated output must
    // eventually go nonzero.
    push_descriptor(build_descr(32'h0000_0000, 32'd0, 16'd0, 16'sd32767,
                                 16'd10, 2'd2, 1'b0, 1'b0, 1'b0));
    wait_for_mvalid(1'b1, 60, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END

`SVTEST(tc_product_descriptor_produces_valid_output)
    bit reached;
    // outsel=0 (DDS x envelope product): exercises the full complex-product
    // path.
    push_descriptor(build_descr(32'h1000_0000, 32'd0, 16'd0, 16'sd32767,
                                 16'd10, 2'd0, 1'b0, 1'b0, 1'b0));
    wait_for_mvalid(1'b1, 60, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END

`SVTEST(tc_mvalid_deasserts_after_playback)
    bit reached;
    push_descriptor(build_descr(32'h1000_0000, 32'd0, 16'd0, 16'sd32767,
                                 16'd4, 2'd1, 1'b0, 1'b0, 1'b0));
    wait_for_mvalid(1'b1, 60, reached);
    `FAIL_UNLESS(reached);
    wait_for_mvalid(1'b0, 60, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END

`SVTEST(tc_zero_gain_mutes_dds_only_output)
    push_descriptor(build_descr(32'h1000_0000, 32'd0, 16'd0, 16'sd0,
                                 16'd10, 2'd1, 1'b0, 1'b0, 1'b0));
    repeat(60) @(posedge tb_clk);
    `FAIL_UNLESS(tb_m_axis_tdata_o === '0);
`SVTEST_END
