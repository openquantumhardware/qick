// ============================================================================
// File: axis_sg_int4_v2_tests.sv
// Description: SVUnit test cases for axis_sg_int4_v2. Included by
//              axis_sg_int4_v2_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    `FAIL_UNLESS(m_if.tvalid === 1'b0);
    `FAIL_UNLESS(s1_if.tready === 1'b1);
`SVTEST_END

`SVTEST(tc_axi_register_round_trip)
    logic [31:0] data;
    reg_write(REG_START_ADDR, 32'h0000_00AB);
    reg_read(REG_START_ADDR, data);
    `FAIL_UNLESS(data === 32'h0000_00AB);

    reg_write(REG_WE, 32'd1);
    reg_read(REG_WE, data);
    `FAIL_UNLESS(data === 32'd1);
    reg_write(REG_WE, 32'd0);
    reg_read(REG_WE, data);
    `FAIL_UNLESS(data === 32'd0);
`SVTEST_END

`SVTEST(tc_dds_only_descriptor_produces_valid_output)
    bit reached;
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
