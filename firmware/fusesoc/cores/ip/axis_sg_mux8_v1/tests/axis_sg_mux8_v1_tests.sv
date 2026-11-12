// ============================================================================
// File: axis_sg_mux8_v1_tests.sv
// Description: SVUnit test cases for axis_sg_mux8_v1. Included by
//              axis_sg_mux8_v1_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    `FAIL_UNLESS(m_if.tvalid === 1'b0);
    `FAIL_UNLESS(s_if.tready === 1'b1);
`SVTEST_END

`SVTEST(tc_axi_register_round_trip)
    logic [31:0] data;
    reg_write(ADDR_PINC0, 32'h1234_5678);
    reg_read(ADDR_PINC0, data);
    `FAIL_UNLESS(data === 32'h1234_5678);

    reg_write(ADDR_POFF0, 32'hAABB_CCDD);
    reg_read(ADDR_POFF0, data);
    `FAIL_UNLESS(data === 32'hAABB_CCDD);

    reg_write(ADDR_GAIN0, 32'h0000_7FFF);
    reg_read(ADDR_GAIN0, data);
    `FAIL_UNLESS(data === 32'h0000_7FFF);
`SVTEST_END

`SVTEST(tc_we_reg_is_a_plain_level_not_self_clearing)
    logic [31:0] data;
    reg_write(ADDR_WE, 32'd1);
    reg_read(ADDR_WE, data);
    `FAIL_UNLESS(data === 32'd1);
    reg_write(ADDR_WE, 32'd0);
    reg_read(ADDR_WE, data);
    `FAIL_UNLESS(data === 32'd0);
`SVTEST_END

`SVTEST(tc_descriptor_produces_valid_output)
    bit reached;
    write_channel0(32'h1000_0000, 32'h0000_0000, 16'h7FFF);
    queue_descriptor(8'h01, 32'd20);
    wait_for_mvalid(1'b1, 40, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END

`SVTEST(tc_all_channels_masked_off_gives_zero_output)
    bit reached;
    write_channel0(32'h1000_0000, 32'h0000_0000, 16'h7FFF);
    queue_descriptor(8'h00, 32'd20);
    wait_for_mvalid(1'b1, 40, reached);
    `FAIL_UNLESS(reached);
    `FAIL_UNLESS(m_if.tdata === '0);
`SVTEST_END

`SVTEST(tc_mvalid_deasserts_after_playback)
    bit reached;
    write_channel0(32'h1000_0000, 32'h0000_0000, 16'h7FFF);
    queue_descriptor(8'h01, 32'd4);
    wait_for_mvalid(1'b1, 40, reached);
    `FAIL_UNLESS(reached);
    wait_for_mvalid(1'b0, 30, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END
