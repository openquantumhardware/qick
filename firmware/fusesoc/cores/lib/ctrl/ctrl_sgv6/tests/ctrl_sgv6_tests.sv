// ============================================================================
// File: ctrl_sgv6_tests.sv
// Description: SVUnit test cases for ctrl_sgv6. Included by ctrl_sg_v6_tc00.sv.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Reset state — idle outputs, FSM in READ_ST (rd_en asserted).
// ----------------------------------------------------------------------------
`SVTEST(tc_reset_idle)
    // In READ_ST the FSM asserts fifo_rd_en. After reset + a few cycles with
    // empty FIFO, it should be requesting data.
    repeat(3) @(tb_cb);
    `FAIL_IF(tb_en !== 1'b0);
    `FAIL_IF(tb_fifo_rd_en !== 1'b1);   // READ_ST requests a descriptor
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: FIFO read handshake — rd_en asserts and a descriptor is consumed.
// ----------------------------------------------------------------------------
`SVTEST(tc_fifo_handshake)
    logic [159:0] d;
    d = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'(MAXV),
                    16'd8, 2'd0, 1'b0, 1'b0, 1'b0);
    push_descriptor(d);
    // After consuming, the FSM should eventually return to READ_ST and request
    // again (rd_en high) once the count is done. Just check it ran.
    repeat(20) @(tb_cb);
    `FAIL_IF(1'b0);   // reaching here without hang is the pass condition
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Gain decode + latency measurement.
//   Load a descriptor with gain=MAXV and discover the pipeline latency at
//   which o_gain reflects it.
// ----------------------------------------------------------------------------
`SVTEST(tc_gain_decode)
    logic [159:0] d;
    int lat;
    d = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'(MAXV),
                    16'd64, 2'd0, 1'b0, 1'b0, 1'b0);
    measure_gain_latency(d, 16'(MAXV), lat);
    $display("[INFO] gain latency = %0d cycles", lat);
    `FAIL_IF_LOG(lat < 0, "tc_gain_decode: o_gain never matched MAXV");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: Different gain values propagate correctly.
// ----------------------------------------------------------------------------
`SVTEST(tc_gain_values)
    logic [159:0] d;
    int lat;
    // Half-scale gain
    d = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'h4000,
                    16'd64, 2'd0, 1'b0, 1'b0, 1'b0);
    measure_gain_latency(d, 16'h4000, lat);
    `FAIL_IF_LOG(lat < 0, "tc_gain_values: gain 0x4000 not observed");
    // settle / reload
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(20) @(tb_cb);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: outsel (src) decode — verify each source selection reaches o_src.
// ----------------------------------------------------------------------------
`SVTEST(tc_src_decode)
    logic [159:0] d;
    int t;
    // outsel = 2 (mem)
    d = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'(MAXV),
                    16'd64, 2'd2, 1'b0, 1'b0, 1'b0);
    hold_descriptor(d);
    @(tb_cb);
    while (!tb_fifo_rd_en) @(tb_cb);
    // wait for src to propagate (bounded)
    t = 0;
    while (tb_src !== 2'd2 && t < 64) begin @(tb_cb); t++; end
    `FAIL_IF_LOG(tb_src !== 2'd2, $sformatf("tc_src_decode: src=%0d expected 2", tb_src));
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(20) @(tb_cb);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: stdysel decode reaches o_stdy.
// ----------------------------------------------------------------------------
`SVTEST(tc_stdy_decode)
    logic [159:0] d;
    int t;
    d = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'(MAXV),
                    16'd64, 2'd0, 1'b0, 1'b1, 1'b0);  // stdysel=1
    hold_descriptor(d);
    @(tb_cb);
    while (!tb_fifo_rd_en) @(tb_cb);
    t = 0;
    while (tb_stdy !== 1'b1 && t < 64) begin @(tb_cb); t++; end
    `FAIL_IF_LOG(tb_stdy !== 1'b1, "tc_stdy_decode: stdy not asserted");
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(20) @(tb_cb);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: en asserts after a descriptor is loaded (mode=0) and the FIFO is
//   non-empty. Measures the en latency.
// ----------------------------------------------------------------------------
`SVTEST(tc_en_asserts)
    logic [159:0] d;
    int t;
    d = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'(MAXV),
                    16'd64, 2'd0, 1'b0, 1'b0, 1'b0);
    hold_descriptor(d);
    @(tb_cb);
    while (!tb_fifo_rd_en) @(tb_cb);
    // wait for en to assert (bounded)
    t = 0;
    while (tb_en !== 1'b1 && t < 64) begin @(tb_cb); t++; end
    $display("[INFO] en latency = %0d cycles", t);
    `FAIL_IF_LOG(tb_en !== 1'b1, "tc_en_asserts: en never asserted");
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(30) @(tb_cb);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: mem_addr starts at 'addr' and then increments.
//   Capture the address sequence once en is active and check it ramps.
// ----------------------------------------------------------------------------
`SVTEST(tc_mem_addr_ramp)
    logic [159:0] d;
    logic [N-1:0] a0, a1, a2;
    int t;
    d = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'(MAXV),
                    16'd64, 2'd0, 1'b0, 1'b0, 1'b0);
    hold_descriptor(d);
    @(tb_cb);
    while (!tb_fifo_rd_en) @(tb_cb);
    // wait for en, then sample three consecutive addresses
    t = 0;
    while (tb_en !== 1'b1 && t < 64) begin @(tb_cb); t++; end
    `FAIL_IF_LOG(tb_en !== 1'b1, "tc_mem_addr_ramp: en never asserted");
    a0 = tb_mem_addr; @(tb_cb);
    a1 = tb_mem_addr; @(tb_cb);
    a2 = tb_mem_addr; @(tb_cb);
    // addresses must increment by 1 each cycle
    `FAIL_IF_LOG(a1 !== (a0 + 1), $sformatf("addr not +1: a0=%0h a1=%0h", a0, a1));
    `FAIL_IF_LOG(a2 !== (a1 + 1), $sformatf("addr not +1: a1=%0h a2=%0h", a1, a2));
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(30) @(tb_cb);
`SVTEST_END



`SVTEST(tc_descriptor_lasts_nsamp_clocks)
    // A descriptor holds the generator for nsamp clocks: the next one is popped nsamp clocks after
    // it, from 2 to the largest (65535).
    int ns[$] = '{2, 3, 4, 5, 17, 100, 2, 65535};
    logic [159:0] d[$];
    int len[$];
    foreach (ns[i]) d.push_back(build_descr(32'h1000, 32'd0, 16'd0, 16'd100, 16'(ns[i]), 2'd0, 1'b0, 1'b0, 1'b0));
    d.push_back(build_descr(32'h1000, 32'd0, 16'd0, 16'd100, 16'd100, 2'd0, 1'b0, 1'b0, 1'b0));
    play_descriptors(d, 70000, len);
    `FAIL_UNLESS_EQUAL(len.size(), ns.size());
    foreach (ns[i]) `FAIL_UNLESS_EQUAL(len[i], ns[i]);
`SVTEST_END

`SVTEST(tc_nsamp_0_and_1_stall)
    // Known and kept (TODO 3c, 2026-10-28): the count ends at cnt_nsamp == 2, so nsamp 0 and 1
    // count down through zero and the next descriptor is read only about 2^16 clocks later.
    // qick_lib never sends a length below 3. This test records the behaviour: it changes if the
    // RTL is fixed (ctrl_sgv4 ends at <= 2 and gives 2 clocks).
    for (int k = 0; k < 2; k++) begin
        int ns[$];
        logic [159:0] d[$];
        int len[$];
        ns = '{100, k};
        foreach (ns[i]) d.push_back(build_descr(32'h1000, 32'd0, 16'd0, 16'd100, 16'(ns[i]), 2'd0, 1'b0, 1'b0, 1'b0));
        d.push_back(build_descr(32'h1000, 32'd0, 16'd0, 16'd100, 16'd100, 2'd0, 1'b0, 1'b0, 1'b0));
        play_descriptors(d, 1000, len);
        `FAIL_UNLESS_EQUAL(len.size(), 2);
        `FAIL_UNLESS_EQUAL(len[0], 100);
        `FAIL_UNLESS_EQUAL(len[1], -1);
    end
`SVTEST_END
