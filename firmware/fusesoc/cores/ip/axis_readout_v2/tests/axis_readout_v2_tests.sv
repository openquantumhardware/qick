// ============================================================================
// File: axis_readout_v2_tests.sv
// Description: SVUnit test cases for axis_readout_v2. Included by
//              axis_readout_v2_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    `FAIL_UNLESS(s_if.tready === 1'b1);
    `FAIL_UNLESS(m0_if.tvalid === 1'b1);
    `FAIL_UNLESS(m1_if.tvalid === 1'b1);
`SVTEST_END

`SVTEST(tc_axi_register_round_trip)
    logic [31:0] data;
    reg_write(ADDR_FREQ, 32'h1234_5678);
    reg_read(ADDR_FREQ, data);
    `FAIL_UNLESS(data === 32'h1234_5678);

    reg_write(ADDR_NSAMP, 32'h0000_00AB);
    reg_read(ADDR_NSAMP, data);
    `FAIL_UNLESS(data === 32'h0000_00AB);
`SVTEST_END

`SVTEST(tc_outsel_raw_passthrough_reaches_m0)
    drive_const_input(16'sd12345);
    push_descriptor(32'h0000_0000, 32'd0, 16'd100, 2'd2, 1'b1);
    repeat(10) @(posedge aclk);
    for (int i = 0; i < N_DDS; i++)
        `FAIL_UNLESS(m0_lane(i) === {16'h0000, 16'sd12345});
`SVTEST_END

`SVTEST(tc_dds_only_produces_nonzero_m0)
    bit found;
    int n;
    push_descriptor(32'h1000_0000, 32'd0, 16'd100, 2'd1, 1'b1);
    found = 1'b0;
    for (n = 0; n < 20; n++) begin
        if (m0_lane(0) !== 32'h0000_0000) begin
            found = 1'b1;
            break;
        end
        @(posedge aclk);
    end
    `FAIL_UNLESS(found);
`SVTEST_END

`SVTEST(tc_product_reaches_decimated_m1)
    bit found;
    int n;
    drive_const_input(16'sd16384);
    push_descriptor(32'h0000_0000, 32'd0, 16'd200, 2'd0, 1'b1);
    found = 1'b0;
    for (n = 0; n < 40; n++) begin
        if (m1_if.tdata !== 32'h0000_0000) begin
            found = 1'b1;
            break;
        end
        @(posedge aclk);
    end
    `FAIL_UNLESS(found);
`SVTEST_END
