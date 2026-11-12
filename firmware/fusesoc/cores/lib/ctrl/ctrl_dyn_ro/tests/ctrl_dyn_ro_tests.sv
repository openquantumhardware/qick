// ============================================================================
// File: ctrl_dyn_ro_tests.sv
// Description: SVUnit test cases for ctrl_dyn_ro. Included by
//              ctrl_dyn_ro_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    `FAIL_UNLESS(tb_fifo_rd_en === 1'b1);
    for (int i = 0; i < N; i++) begin
        `FAIL_UNLESS(lane_phase(i) === 32'd0);
        `FAIL_UNLESS(lane_pinc_n(i) === 32'd0);
    end
`SVTEST_END

`SVTEST(tc_pinc_n_field_matches_pinc_times_n)
    // pinc_N = (PINC * N) mod 2^32 -- independent of the free-running cnt_n
    // counter, so it is exactly predictable once the write has propagated.
    logic [63:0] expected;
    push_descriptor(build_descr(32'h0000_1000, 32'h0000_0000, 16'd100, 2'd0, 1'b1, 1'b0));
    expected = 64'h0000_1000 * N;
    for (int i = 0; i < N; i++) begin
        `FAIL_UNLESS(lane_pinc_n(i) === expected[31:0]);
    end
`SVTEST_END

`SVTEST(tc_lane_phase_offset_is_pinc_coherent)
    // Phase-coherence invariant: lane i's phase equals lane 0's phase plus
    // i*PINC (mod 2^32) at any given output cycle.
    logic [31:0] phase0, phase1, diff;
    push_descriptor(build_descr(32'h0000_1000, 32'h0000_0000, 16'd100, 2'd0, 1'b1, 1'b0));
    phase0 = lane_phase(0);
    phase1 = lane_phase(1);
    diff   = phase1 - phase0;
    `FAIL_UNLESS(diff === 32'h0000_1000);
`SVTEST_END

`SVTEST(tc_phase_shifts_with_static_phase_reg)
    // Changing the descriptor's static phase field (with PINC=0) shifts
    // every lane's phase by the same amount.
    logic [31:0] phase0_before;
    logic [31:0] phase0_after;
    push_descriptor(build_descr(32'h0000_0000, 32'h0000_0000, 16'd100, 2'd0, 1'b1, 1'b0));
    phase0_before = lane_phase(0);
    push_descriptor(build_descr(32'h0000_0000, 32'h0000_0100, 16'd100, 2'd0, 1'b1, 1'b0));
    phase0_after = lane_phase(0);
    `FAIL_UNLESS((phase0_after - phase0_before) === 32'h0000_0100);
`SVTEST_END

`SVTEST(tc_outsel_reaches_output)
    bit reached;
    int n;
    @(negedge tb_clk);
    tb_fifo_dout  = build_descr(32'h0000_1000, 32'd0, 16'd100, 2'd2, 1'b1, 1'b0);
    tb_fifo_empty = 1'b0;
    wait (tb_fifo_rd_en === 1'b1);
    @(posedge tb_clk);
    @(negedge tb_clk);
    tb_fifo_empty = 1'b1;

    reached = 1'b0;
    for (n = 0; n < 20; n++) begin
        if (tb_outsel === 2'd2) begin
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
    logic [87:0] d[$];
    int len[$];
    foreach (ns[i]) d.push_back(build_descr(32'h0000_1000, 32'd0, 16'(ns[i]), 2'd0, 1'b0, 1'b0));
    d.push_back(build_descr(32'h0000_1000, 32'd0, 16'd100, 2'd0, 1'b0, 1'b0));
    play_descriptors(d, 70000, len);
    `FAIL_UNLESS_EQUAL(len.size(), ns.size());
    foreach (ns[i]) `FAIL_UNLESS_EQUAL(len[i], ns[i]);
`SVTEST_END

`SVTEST(tc_nsamp_below_3_lasts_3_clocks)
    // The controller sees a descriptor's nsamp one clock after the pop, so it cannot end one
    // shorter than 3 clocks. nsamp 0, 1 and 2 last 3 clocks, whatever came before; they must not
    // stall the readout (the end compare used to wrap to about 2^32 clocks).
    int ns[$]  = '{100, 0, 100, 1, 100, 2, 2, 3};
    int exp[$] = '{100, 3, 100, 3, 100, 3, 3, 3};
    logic [87:0] d[$];
    int len[$];
    foreach (ns[i]) d.push_back(build_descr(32'h0000_1000, 32'd0, 16'(ns[i]), 2'd0, 1'b0, 1'b0));
    d.push_back(build_descr(32'h0000_1000, 32'd0, 16'd100, 2'd0, 1'b0, 1'b0));
    play_descriptors(d, 1000, len);
    `FAIL_UNLESS_EQUAL(len.size(), exp.size());
    foreach (exp[i]) `FAIL_UNLESS_EQUAL(len[i], exp[i]);
`SVTEST_END

`SVTEST(tc_phrst_restarts_the_phase)
    // phrst restarts the free-running time counter with the descriptor, so lane 0 starts at the
    // descriptor's phase however long ago the last one came. Without phrst the phase also carries
    // pinc * (time since the last restart), a different value after a wait.
    logic [31:0] p1, p2, p3;
    push_descriptor(build_descr(32'h0000_1000, 32'h0000_0100, 16'd100, 2'd0, 1'b1, 1'b1));
    p1 = lane_phase(0);
    repeat (37) @(posedge tb_clk);
    push_descriptor(build_descr(32'h0000_1000, 32'h0000_0100, 16'd100, 2'd0, 1'b1, 1'b1));
    p2 = lane_phase(0);
    repeat (37) @(posedge tb_clk);
    push_descriptor(build_descr(32'h0000_1000, 32'h0000_0100, 16'd100, 2'd0, 1'b1, 1'b0));
    p3 = lane_phase(0);
    `FAIL_UNLESS_EQUAL(p1, 32'h0000_0100);
    `FAIL_UNLESS_EQUAL(p2, 32'h0000_0100);
    `FAIL_UNLESS(p3 !== 32'h0000_0100);
`SVTEST_END
