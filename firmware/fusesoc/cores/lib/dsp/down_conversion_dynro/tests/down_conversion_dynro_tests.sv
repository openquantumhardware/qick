// ============================================================================
// File: down_conversion_dynro_tests.sv
// Description: SVUnit test cases for down_conversion_dynro. Included by
//              down_conversion_dynro_tc00.sv.
// ============================================================================

`SVTEST(tc_ready_and_valid_tied_high)
    `FAIL_UNLESS(tb_s_axis_tready_o === 1'b1);
    `FAIL_UNLESS(tb_m_axis_tvalid_o === 1'b1);
`SVTEST_END

`SVTEST(tc_outsel_raw_input_passthrough)
    // outsel=2: raw input passthrough, {16'h0000, din_r4}.
    drive_const_input(16'sd12345);
    push_descriptor(build_descr(32'h0000_0000, 32'd0, 16'd100, 2'd2, 1'b1, 1'b0));
    repeat(10) @(posedge tb_clk);
    for (int i = 0; i < N_DDS; i++) begin
        `FAIL_UNLESS(lane_out(i) === {16'h0000, 16'sd12345});
    end
`SVTEST_END

`SVTEST(tc_outsel_zero_gives_zero_output)
    drive_const_input(16'sd12345);
    push_descriptor(build_descr(32'h0000_1000, 32'd0, 16'd100, 2'd3, 1'b1, 1'b0));
    repeat(10) @(posedge tb_clk);
    for (int i = 0; i < N_DDS; i++) begin
        `FAIL_UNLESS(lane_out(i) === 32'h0000_0000);
    end
`SVTEST_END

`SVTEST(tc_outsel_dds_only_produces_nonzero_output)
    bit found;
    int n;
    push_descriptor(build_descr(32'h1000_0000, 32'd0, 16'd100, 2'd1, 1'b1, 1'b0));
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
    push_descriptor(build_descr(32'h0000_0000, 32'd0, 16'd100, 2'd0, 1'b1, 1'b0));
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

// The product and the DDS-only output come from two taps of the DDS output pipeline (dds_dout_r1 into the
// multiplier, dds_dout_r3 to the mux). With a constant input X, every product sample must be the DDS sample of
// the same clock times X ((dds * X + 2^15) >> 16, as the RTL rounds), at a frequency where consecutive DDS samples differ by thousands of
// counts: a one-clock offset between the taps fails by far more than the rounding.
`SVTEST(tc_product_aligned_with_dds_output)
    localparam int K = 48;
    logic [31:0] dds_s  [K];
    logic [31:0] prod_s [K];
    int          err, max_err;
    drive_const_input(16'sd16384);   // 0.5
    for (int pass = 0; pass < 2; pass++) begin
        // Same descriptor and the same phase reset both times; only outsel differs (1 DDS only, 0 product).
        push_descriptor(build_descr(32'h0800_0000, 32'h1234_5678, 16'd2000, pass == 0 ? 2'd1 : 2'd0, 1'b0, 1'b1));
        repeat (40) @(posedge tb_clk);
        for (int k = 0; k < K; k++) begin
            @(posedge tb_clk); #1;
            if (pass == 0) dds_s[k] = lane_out(1); else prod_s[k] = lane_out(1);
        end
        repeat (2100) @(posedge tb_clk);
    end
    max_err = 0;
    for (int k = 0; k < K; k++) begin
        // product = (dds * X + 2^15) >> 16 with X = 2^14: (dds + 2) >> 2, per component.
        err = $signed(prod_s[k][15:0]) - (($signed(dds_s[k][15:0]) + 2) >>> 2);
        if (err < 0) err = -err;
        if (err > max_err) max_err = err;
        err = $signed(prod_s[k][31:16]) - (($signed(dds_s[k][31:16]) + 2) >>> 2);
        if (err < 0) err = -err;
        if (err > max_err) max_err = err;
    end
    `FAIL_UNLESS(max_err <= 1)
    `FAIL_UNLESS(dds_s[0] !== dds_s[1])   // the DDS really moves from clock to clock
`SVTEST_END

// Clocks from the descriptor pop (fifo_rd_en with a non-empty FIFO) to the first DDS-only output sample of that
// descriptor: 10 clocks, the same as 1.0.0 (the two versions give the same output and fifo_rd_en on every clock,
// checked side by side). The DDS restarts at phase 0 with
// pinc 0 here, so its first sample is the known cos/sin(0) word; before that the output is the previous
// descriptor's zero output (outsel 3).
`SVTEST(tc_dds_output_latency_from_descriptor)
    int n;
    push_descriptor(build_descr(32'h0, 32'h0, 16'd400, 2'd3, 1'b0, 1'b1));
    repeat (500) @(posedge tb_clk);
    @(negedge tb_clk);
    tb_fifo_dout_i  = build_descr(32'h0, 32'h0, 16'd400, 2'd1, 1'b0, 1'b1);
    tb_fifo_empty_i = 1'b0;
    wait (tb_fifo_rd_en_o === 1'b1);
    @(posedge tb_clk); #1;
    tb_fifo_empty_i = 1'b1;
    n = 1;
    while (lane_out(0) === 32'h0000_0000 && n < 40) begin
        @(posedge tb_clk); #1;
        n++;
    end
    `FAIL_UNLESS_EQUAL(n, 10)
    `FAIL_UNLESS_EQUAL(lane_out(0), {16'sd0, 16'sd32767})   // {sin(0), cos(0)}
`SVTEST_END
