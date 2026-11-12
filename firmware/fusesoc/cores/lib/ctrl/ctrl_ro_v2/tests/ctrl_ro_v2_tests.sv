// ============================================================================
// File: ctrl_ro_v2_tests.sv
// Description: SVUnit test cases for ctrl_ro_v2. Included by
//              ctrl_ro_v2_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    `FAIL_UNLESS(tb_fifo_rd_en_o === 1'b1);
    for (int i = 0; i < N_DDS; i++) begin
        `FAIL_UNLESS(lane_phase(i) === 32'd0);
        `FAIL_UNLESS(lane_pinc_n(i) === 32'd0);
    end
`SVTEST_END

`SVTEST(tc_pinc_n_field_matches_pinc_times_n)
    logic [63:0] expected;
    push_descriptor(build_descr(32'h0000_1000, 32'h0000_0000, 16'd100, 2'd0, 1'b1));
    expected = 64'h0000_1000 * N_DDS;
    for (int i = 0; i < N_DDS; i++) begin
        `FAIL_UNLESS(lane_pinc_n(i) === expected[31:0]);
    end
`SVTEST_END

`SVTEST(tc_lane_phase_offset_is_pinc_coherent)
    logic [31:0] phase0, phase1, diff;
    push_descriptor(build_descr(32'h0000_1000, 32'h0000_0000, 16'd100, 2'd0, 1'b1));
    phase0 = lane_phase(0);
    phase1 = lane_phase(1);
    diff   = phase1 - phase0;
    `FAIL_UNLESS(diff === 32'h0000_1000);
`SVTEST_END

`SVTEST(tc_phase_shifts_with_static_phase_reg)
    logic [31:0] phase0_before;
    logic [31:0] phase0_after;
    push_descriptor(build_descr(32'h0000_0000, 32'h0000_0000, 16'd100, 2'd0, 1'b1));
    phase0_before = lane_phase(0);
    push_descriptor(build_descr(32'h0000_0000, 32'h0000_0100, 16'd100, 2'd0, 1'b1));
    phase0_after = lane_phase(0);
    `FAIL_UNLESS((phase0_after - phase0_before) === 32'h0000_0100);
`SVTEST_END

`SVTEST(tc_outsel_reaches_output)
    bit reached;
    int n;
    @(negedge tb_clk);
    tb_fifo_dout_i  = build_descr(32'h0000_1000, 32'd0, 16'd100, 2'd2, 1'b1);
    tb_fifo_empty_i = 1'b0;
    wait (tb_fifo_rd_en_o === 1'b1);
    @(posedge tb_clk);
    @(negedge tb_clk);
    tb_fifo_empty_i = 1'b1;

    reached = 1'b0;
    for (n = 0; n < 20; n++) begin
        if (tb_outsel_o === 2'd2) begin
            reached = 1'b1;
            break;
        end
        @(posedge tb_clk);
    end
    `FAIL_UNLESS(reached);
`SVTEST_END

`SVTEST(tc_descriptor_lasts_nsamp_clocks)
    // A descriptor holds the readout for nsamp clocks: the next one is popped nsamp clocks after
    // it, for every nsamp from the minimum (3) to the largest (65535).
    int ns[$] = '{3, 4, 5, 17, 100, 3, 65535};
    logic [82:0] d[$];
    int len[$];
    foreach (ns[i]) d.push_back(build_descr(32'h0000_1000, 32'd0, 16'(ns[i]), 2'd0, 1'b0));
    d.push_back(build_descr(32'h0000_1000, 32'd0, 16'd100, 2'd0, 1'b0));
    play_descriptors(d, 70000, len);
    `FAIL_UNLESS_EQUAL(len.size(), ns.size());
    foreach (ns[i]) `FAIL_UNLESS_EQUAL(len[i], ns[i]);
`SVTEST_END

`SVTEST(tc_nsamp_below_3_lasts_3_clocks)
    // The controller sees a descriptor's nsamp one clock after the pop, so it cannot end one
    // shorter than 3 clocks. nsamp 0, 1 and 2 last 3 clocks, whatever came before; they must not
    // stall the readout (the end compare used to wrap to about 2^16 clocks).
    int ns[$]  = '{100, 0, 100, 1, 100, 2, 2, 3};
    int exp[$] = '{100, 3, 100, 3, 100, 3, 3, 3};
    logic [82:0] d[$];
    int len[$];
    foreach (ns[i]) d.push_back(build_descr(32'h0000_1000, 32'd0, 16'(ns[i]), 2'd0, 1'b0));
    d.push_back(build_descr(32'h0000_1000, 32'd0, 16'd100, 2'd0, 1'b0));
    play_descriptors(d, 1000, len);
    `FAIL_UNLESS_EQUAL(len.size(), exp.size());
    foreach (exp[i]) `FAIL_UNLESS_EQUAL(len[i], exp[i]);
`SVTEST_END
