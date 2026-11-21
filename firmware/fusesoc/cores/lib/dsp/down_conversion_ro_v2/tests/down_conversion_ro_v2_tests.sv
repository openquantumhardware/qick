// ============================================================================
// File: down_conversion_ro_v2_tests.sv
// Description: SVUnit test cases for down_conversion_ro_v2. Included by
//              down_conversion_ro_v2_tc00.sv.
// ============================================================================

`SVTEST(tc_ready_and_valid_tied_high)
    `FAIL_UNLESS(tb_s_axis_tready_o === 1'b1);
    `FAIL_UNLESS(tb_m_axis_tvalid_o === 1'b1);
`SVTEST_END

`SVTEST(tc_outsel_raw_input_passthrough)
    drive_const_input(16'sd12345);
    push_descriptor(build_descr(32'h0000_0000, 32'd0, 16'd100, 2'd2, 1'b1));
    repeat(10) @(posedge tb_clk);
    for (int i = 0; i < N_DDS; i++) begin
        `FAIL_UNLESS(lane_out(i) === {16'h0000, 16'sd12345});
    end
`SVTEST_END

`SVTEST(tc_outsel_zero_gives_zero_output)
    drive_const_input(16'sd12345);
    push_descriptor(build_descr(32'h0000_1000, 32'd0, 16'd100, 2'd3, 1'b1));
    repeat(10) @(posedge tb_clk);
    for (int i = 0; i < N_DDS; i++) begin
        `FAIL_UNLESS(lane_out(i) === 32'h0000_0000);
    end
`SVTEST_END

`SVTEST(tc_outsel_dds_only_produces_nonzero_output)
    bit found;
    int n;
    push_descriptor(build_descr(32'h1000_0000, 32'd0, 16'd100, 2'd1, 1'b1));
    found = 1'b0;
    for (n = 0; n < 20; n++) begin
        if (lane_out(0) !== 32'h0000_0000) begin
            found = 1'b1;
            break;
        end
        @(posedge tb_clk);
    end
    `FAIL_UNLESS(found);
`SVTEST_END

`SVTEST(tc_outsel_product_produces_nonzero_output)
    bit found;
    int n;
    drive_const_input(16'sd16384);
    push_descriptor(build_descr(32'h0000_0000, 32'd0, 16'd100, 2'd0, 1'b1));
    found = 1'b0;
    for (n = 0; n < 20; n++) begin
        if (lane_out(0) !== 32'h0000_0000) begin
            found = 1'b1;
            break;
        end
        @(posedge tb_clk);
    end
    `FAIL_UNLESS(found);
`SVTEST_END
