// ============================================================================
// File: sg_int4_top_tests.sv
// Description: SVUnit test cases for sg_int4_top. Included by
//              sg_int4_top_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    `FAIL_UNLESS(m_if.tvalid === 1'b0);
    `FAIL_UNLESS(s1_if.tready === 1'b1);
    // s0_if.tready stays low until the writer is armed via we_reg
    // (capture_reg) -- axis_to_bram_sg's own INIT_ST behavior, not tested
    // here (covered by axis_to_bram_sg's own testbench).
`SVTEST_END

`SVTEST(tc_dds_only_descriptor_produces_valid_output)
    bit reached;
    // outsel=1 (DDS only): doesn't depend on the envelope memory being
    // pre-loaded.
    queue_descriptor(build_descr(32'h1000_0000, 32'd0, 16'd0, 16'sd32767,
                                  16'd10, 2'd1, 1'b0, 1'b0, 1'b0));
    wait_for_mvalid(1'b1, 80, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END

`SVTEST(tc_envelope_load_and_playback_produces_nonzero_output)
    bit reached;
    logic [15:0] re [], im [];
    const_envelope(8, 16'sd16384, re, im);
    load_envelope(8, re, im);
    // outsel=2 (envelope/FIR only): exercises the full s0_axis -> BRAM ->
    // FIR -> m_axis path.
    queue_descriptor(build_descr(32'h0000_0000, 32'd0, 16'd0, 16'sd32767,
                                  16'd10, 2'd2, 1'b0, 1'b0, 1'b0));
    wait_for_mvalid(1'b1, 80, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END

`SVTEST(tc_mvalid_deasserts_after_playback)
    bit reached;
    queue_descriptor(build_descr(32'h1000_0000, 32'd0, 16'd0, 16'sd32767,
                                  16'd4, 2'd1, 1'b0, 1'b0, 1'b0));
    wait_for_mvalid(1'b1, 80, reached);
    `FAIL_UNLESS(reached);
    wait_for_mvalid(1'b0, 80, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END
