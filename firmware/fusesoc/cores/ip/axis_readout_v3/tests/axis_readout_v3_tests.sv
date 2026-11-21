// ============================================================================
// File: axis_readout_v3_tests.sv
// Description: SVUnit test cases for axis_readout_v3. Included by
//              axis_readout_v3_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    `FAIL_UNLESS(s0_if.tready === 1'b1);
    `FAIL_UNLESS(s1_if.tready === 1'b1);
    `FAIL_UNLESS(m_if.tvalid === 1'b1);
`SVTEST_END

`SVTEST(tc_outsel_raw_passthrough_reaches_m_axis)
    drive_const_input(16'sd12345);
    push_descriptor(build_descr(32'h0000_0000, 32'd0, 16'd200, 2'd2, 1'b1, 1'b0));
    repeat(40) @(posedge aclk);
    `FAIL_UNLESS(m_if.tdata !== 32'h0000_0000);
`SVTEST_END

`SVTEST(tc_dds_only_produces_nonzero_output)
    bit found;
    int n;
    push_descriptor(build_descr(32'h1000_0000, 32'd0, 16'd200, 2'd1, 1'b1, 1'b0));
    found = 1'b0;
    for (n = 0; n < 60; n++) begin
        if (m_if.tdata !== 32'h0000_0000) begin
            found = 1'b1;
            break;
        end
        @(posedge aclk);
    end
    `FAIL_UNLESS(found);
`SVTEST_END

`SVTEST(tc_product_produces_nonzero_output)
    bit found;
    int n;
    drive_const_input(16'sd16384);
    push_descriptor(build_descr(32'h0000_0000, 32'd0, 16'd200, 2'd0, 1'b1, 1'b0));
    found = 1'b0;
    for (n = 0; n < 60; n++) begin
        if (m_if.tdata !== 32'h0000_0000) begin
            found = 1'b1;
            break;
        end
        @(posedge aclk);
    end
    `FAIL_UNLESS(found);
`SVTEST_END
