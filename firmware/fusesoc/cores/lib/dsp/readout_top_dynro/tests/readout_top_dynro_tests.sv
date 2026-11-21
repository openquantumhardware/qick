// ============================================================================
// File: readout_top_dynro_tests.sv
// Description: SVUnit test cases for readout_top_dynro. Included by
//              readout_top_dynro_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    `FAIL_UNLESS(tb_s_axis_tready === 1'b1);
    `FAIL_UNLESS(tb_m0_axis_tvalid === 1'b1);
    // The FIR Compiler raises m_axis_data_tvalid 67 clocks after the first valid block (it is
    // not high right after reset), so wait for it.
    `FAIL_UNLESS(tb_m1_axis_tvalid === 1'b0);
    repeat (80) @(posedge tb_clk);
    `FAIL_UNLESS(tb_m1_axis_tvalid === 1'b1);
    `FAIL_UNLESS(tb_fifo_full === 1'b0);
`SVTEST_END

`SVTEST(tc_outsel_raw_passthrough_reaches_m0)
    drive_const_input(16'sd12345);
    push_descriptor(build_descr(32'h0000_0000, 32'd0, 16'd100, 2'd2, 1'b1, 1'b0));
    repeat(10) @(posedge tb_clk);
    for (int i = 0; i < N_DDS; i++)
        `FAIL_UNLESS(m0_lane(i) === {16'h0000, 16'sd12345});
`SVTEST_END

`SVTEST(tc_dds_only_produces_nonzero_m0)
    bit found;
    int n;
    push_descriptor(build_descr(32'h1000_0000, 32'd0, 16'd100, 2'd1, 1'b1, 1'b0));
    found = 1'b0;
    for (n = 0; n < 20; n++) begin
        if (m0_lane(0) !== 32'h0000_0000) begin
            found = 1'b1;
            break;
        end
        @(posedge tb_clk);
    end
    `FAIL_UNLESS(found);
`SVTEST_END

`SVTEST(tc_product_reaches_decimated_m1)
    // Drive a constant input + a low-frequency DDS product long enough for
    // the decimating FIR's 15-block history to fill and its 67 clocks of latency
    // (the FIR Compiler's, as the model has it since 1.0.1) to pass, then confirm the
    // decimated output has gone nonzero.
    bit found;
    int n;
    drive_const_input(16'sd16384);
    push_descriptor(build_descr(32'h0000_0000, 32'd0, 16'd200, 2'd0, 1'b1, 1'b0));
    found = 1'b0;
    for (n = 0; n < 200; n++) begin
        if (tb_m1_axis_tdata !== 32'h0000_0000) begin
            found = 1'b1;
            break;
        end
        @(posedge tb_clk);
    end
    `FAIL_UNLESS(found);
`SVTEST_END
