// ============================================================================
// File: weighted_buffer_tests.sv
// Description: SVUnit test cases for weighted_buffer.
//   I/Q packing: I in the lower B bits, Q in the upper B bits.
// ============================================================================

`SVTEST(test_reset_idle)
    `FAIL_UNLESS_EQUAL(m0_if.tvalid, 1'b0)
    `FAIL_UNLESS_EQUAL(m1_if.tvalid, 1'b0)
    `FAIL_UNLESS_EQUAL(m2_if.tvalid, 1'b0)
`SVTEST_END

// Constant weight and sample: the buffer must hold the FILTERED product in
// every captured sample, starting with the first one (v1.3 captured a stale
// value first, because matched_filter raised its valid one cycle early).
`SVTEST(test_weighted_buf_readback)
    logic [2*B-1:0] expected;
    logic [2*B-1:0] actual[$];
    int i;

    // I = 0x4000 (16384), Q = 0x0000.
    load_constant_weight({16'h0000, 16'h4000});

    tb_avg_len_reg = 32'd3;   // matched_filter's window length
    arm_buf(8'd0, 8'd3);
    pulse_trigger();
    inject_data(3, {16'h0000, 16'h4000});

    // ac = 0x4000*0x4000 -> top 16 bits = 0x1000 (I); Q stays 0.
    expected = {16'h0000, 16'h1000};

    read_buf(3, actual);
    `FAIL_UNLESS_EQUAL(actual.size(), 3)
    for (i = 0; i < actual.size(); i++)
        `FAIL_UNLESS_EQUAL(actual[i], expected)

    tb_buf_start_reg = 1'b0;
    repeat(5) @(posedge tb_clk);
`SVTEST_END

// End-to-end alignment: buf[n] must be sample n times weight n.
// Two passes, each with continuous s_axis_tvalid and with gaps:
//  - weights w[k] = (k+1)/128, constant sample 0.5: buf[n] I = (n+1)*64
//    tells which weight sample n met;
//  - constant weight 0.5, samples d[n] = (n+1)/128: buf[n] I = (n+1)*64
//    tells which sample landed in buf[n].
// v1.3 read weight n+2 in this port (n+1 in the legacy IP).
`SVTEST(test_weight_alignment_in_buffer)
    int strides[2] = '{1, 3};
    logic [2*B-1:0] actual[$];
    int mode, s, n, bad;

    for (mode = 0; mode < 2; mode++) begin
        if (mode == 0) load_ramp_weight(16);
        else           load_constant_weight({16'h0000, 16'h4000}, 16);

        for (s = 0; s < 2; s++) begin
            tb_avg_len_reg = 32'd12;
            arm_buf(8'd0, 8'd12);
            stream_window(12, strides[s], mode == 1);
            read_buf(12, actual);
            tb_buf_start_reg = 1'b0;
            repeat(10) @(posedge tb_clk);

            `FAIL_UNLESS_EQUAL(actual.size(), 12)
            bad = 0;
            for (n = 0; n < actual.size(); n++) begin
                if (actual[n] !== {16'h0000, 16'((n+1)*64)}) begin
                    if (bad == 0)
                        $display("[ALIGN-BUF] %s, stride %0d: buf[%0d] I = %0d, expected %0d",
                                 mode == 0 ? "ramp weights" : "ramp data", strides[s], n,
                                 $signed(actual[n][B-1:0]), (n+1)*64);
                    bad++;
                end
            end
            `FAIL_UNLESS_EQUAL(bad, 0)
        end
    end
`SVTEST_END

// Confirm the shared trigger fans out to avg too (arm avg only, not buf) --
// proves matched_filter's trigger_o (DSP-latency compensated) reaches both
// sub-blocks through the same composition path as avg_buffer's own test.
// With the first sample no longer stale, the sum is exact: 3 * 0x1000.
`SVTEST(test_weighted_avg_arms_on_shared_trigger)
    int timed_out;
    int timeout;

    load_constant_weight({16'h0000, 16'h4000});

    arm_avg(8'd0, 32'd3);
    pulse_trigger();
    inject_data(3, {16'h0000, 16'h4000});

    tb_avg_dr_addr_reg  = '0;
    tb_avg_dr_len_reg   = 9'd1;
    tb_avg_dr_start_reg = 1'b1;

    m0_if.tready = 1'b1;
    timed_out = 0;
    timeout = 0;
    while (!m0_if.tvalid && !timed_out) begin
        @(posedge tb_clk);
        timeout++;
        if (timeout > 500) timed_out = 1;
    end
    `FAIL_IF_LOG(timed_out, "test_weighted_avg_arms_on_shared_trigger: timed out waiting for m0_axis data")
    if (!timed_out) `FAIL_UNLESS_EQUAL(m0_if.tdata, {32'd0, 32'h0000_3000})

    tb_avg_dr_start_reg = 1'b0;
    repeat(5) @(posedge tb_clk);
`SVTEST_END
