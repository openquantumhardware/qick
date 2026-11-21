// ============================================================================
// File: sgv6_top_tests.sv  (rewrite)
//
// The previous version of this file ended every test in `FAIL_IF(1'b0)`: the
// tests printed burst lengths and peaks and could not fail. They were
// $display harnesses, not tests.
//
// Two things changed here:
//
//  1. Every test asserts. Nothing prints-and-passes.
//  2. The stimulus distinguishes outcomes. A constant envelope cannot tell
//     row 0 from row 3 — if the datapath slips by one row every sample still
//     reads 0x4000 and only the burst edge betrays it. Every test that cares
//     about placement loads a ramp in which each (row, bank) pair is unique.
//
// Envelope memory layout (via axis_to_bram_sg_nt one-hot demux):
//   stream sample k -> bank (k % N_DDS), row (k / N_DDS)
// Output beat r presents row r across all N_DDS lanes.
//
// ============================================================================


// ----------------------------------------------------------------------------
// TEST 01: Reset — no output, descriptor queue accepting, writer idle.
// ----------------------------------------------------------------------------
`SVTEST(tc_reset_idle)
    repeat (5) @(posedge tb_aclk);
    `FAIL_IF_LOG(tb_m_tvalid !== 1'b0,
        "tc_reset_idle: m_axis_tvalid asserted with no descriptor queued");
    `FAIL_IF_LOG(tb_s1_tready !== 1'b1,
        "tc_reset_idle: descriptor FIFO not ready after reset");
    `FAIL_IF_LOG(tb_s0_tready !== 1'b0,
        "tc_reset_idle: envelope writer accepting with we_reg low");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Envelope placement — THE alignment test.
//
// Loads NROWS distinct rows and reads them straight back with outsel=mem, so
// nothing but the memory path is involved. Every beat of every lane is
// checked against the value that was written there.
//
// This is the test the old tc_alignment_check was trying to be. With a
// constant envelope a one-row slip is invisible except at the burst edge;
// with a ramp it shows up in beat 0, lane 0, with the row number readable
// straight out of the high byte of the wrong value.
// ----------------------------------------------------------------------------
`SVTEST(tc_envelope_placement_mem)
    localparam int NROWS = 4;
    localparam int NSAMP = 8;
    logic [N_DDS*16-1:0] beats [$];
    logic [159:0]        d;
    int                  got, exp_v;

    load_ramp(NROWS);

    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV),
                    16'(NSAMP), 2'd2 /*mem*/, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    capture_burst(beats);

    `FAIL_IF_LOG(beats.size() == 0,
        "tc_envelope_placement_mem: burst never started");

    for (int r = 0; r < NROWS && r < beats.size(); r++) begin
        for (int l = 0; l < N_DDS; l++) begin
            got   = int'(lane(beats[r], l));
            exp_v = scale_gain(env_val(r, l), MAXV);
            `FAIL_IF_LOG(!close(got, exp_v),
                $sformatf("tc_envelope_placement_mem: beat %0d lane %0d: expected ~%0d (row %0d bank %0d) got %0d%s",
                          r, l, exp_v, r, l, got,
                          (r == 0) ? "  <-- beat 0 wrong means the memory read is misaligned" : ""));
        end
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Burst length — nsamp determines the beat count exactly, and the
// output goes quiet afterwards instead of trailing extra beats.
// ----------------------------------------------------------------------------
`SVTEST(tc_burst_length_matches_nsamp)
    localparam int NSAMP = 8;
    logic [N_DDS*16-1:0] beats [$];
    logic [159:0]        d;

    load_ramp(4);

    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV),
                    16'(NSAMP), 2'd2, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    capture_burst(beats);

    `FAIL_IF_LOG(beats.size() !== NSAMP,
        $sformatf("tc_burst_length_matches_nsamp: burst was %0d beats, expected %0d",
                  beats.size(), NSAMP));

    repeat (20) @(posedge tb_aclk);
    `FAIL_IF_LOG(tb_m_tvalid !== 1'b0,
        "tc_burst_length_matches_nsamp: tvalid still asserted after the burst");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04 : rows past the loaded envelope read back as silence.
//
// The previous version loaded 2 rows and expected rows 2..5 to be zero. They
// were not — the preceding test had loaded 4 rows and the envelope memory
// survives between SVUnit tests. It failed on leftovers, not on the DUT.
//
// This version writes the entire window the burst will read, so the result
// does not depend on what any earlier test left behind.
// ----------------------------------------------------------------------------
`SVTEST(tc_rows_past_envelope_are_silent)
    localparam int NROWS = 2;
    localparam int NSAMP = 6;
    logic [N_DDS*16-1:0] beats [$];
    logic [159:0]        d;
    int                  got, exp_v;

    load_window(NROWS, NSAMP);

    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV),
                    16'(NSAMP), 2'd2 /*mem*/, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    capture_n_beats(beats, NSAMP);

    `FAIL_IF_LOG(beats.size() !== NSAMP,
        $sformatf("tc_rows_past_envelope_are_silent: got %0d beats, expected %0d",
                  beats.size(), NSAMP));

    for (int r = 0; r < NSAMP; r++) begin
        for (int l = 0; l < N_DDS; l++) begin
            got   = int'(lane(beats[r], l));
            exp_v = (r < NROWS) ? scale_gain(env_val(r, l), MAXV) : 0;
            `FAIL_IF_LOG(!close(got, exp_v),
                $sformatf("tc_rows_past_envelope_are_silent: beat %0d lane %0d expected ~%0d got %0d",
                          r, l, exp_v, got));
        end
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: Gain scaling — halving the gain halves the output.
// A ratio check needs no knowledge of the datapath's absolute scaling, so it
// stays valid even if the rounding rule changes.
// ----------------------------------------------------------------------------
`SVTEST(tc_gain_scaling)
    localparam int NSAMP = 4;
    logic [N_DDS*16-1:0] full [$];
    logic [N_DDS*16-1:0] half [$];
    logic [159:0]        d;
    int                  a, b;

    load_ramp(4);

    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV),
                    16'(NSAMP), 2'd2, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    capture_burst(full);

    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV/2),
                    16'(NSAMP), 2'd2, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    capture_burst(half);

    `FAIL_IF_LOG(full.size() == 0 || half.size() == 0,
        "tc_gain_scaling: one of the bursts never started");

    for (int l = 0; l < N_DDS; l++) begin
        a = int'(lane(full[0], l));
        b = int'(lane(half[0], l));
        `FAIL_IF_LOG(!close(b, a/2),
            $sformatf("tc_gain_scaling: lane %0d: full=%0d half=%0d, expected half ~= %0d",
                      l, a, b, a/2));
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: Zero gain silences the output without stopping the burst.
// ----------------------------------------------------------------------------
`SVTEST(tc_zero_gain_is_silent)
    localparam int NSAMP = 4;
    logic [N_DDS*16-1:0] beats [$];
    logic [159:0]        d;

    load_ramp(4);

    d = build_descr(32'd0, 32'd0, 16'd0, 16'd0 /*gain*/,
                    16'(NSAMP), 2'd2, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    capture_burst(beats);

    `FAIL_IF_LOG(beats.size() !== NSAMP,
        $sformatf("tc_zero_gain_is_silent: burst was %0d beats, expected %0d — zero gain must silence the output, not suppress the burst",
                  beats.size(), NSAMP));

    for (int r = 0; r < beats.size(); r++)
        for (int l = 0; l < N_DDS; l++)
            `FAIL_IF_LOG(lane(beats[r], l) !== 16'h0000,
                $sformatf("tc_zero_gain_is_silent: beat %0d lane %0d = 0x%04h",
                          r, l, lane(beats[r], l)));
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: Product mode, constant envelope — the output must be constant
// across the beats that were actually loaded.
//
// This is the old tc_alignment_check's intent, with two fixes: the burst is
// limited to loaded rows so the zero tail cannot masquerade as a failure, and
// the constancy is asserted rather than printed. The absolute value depends on
// the behavioural DDS, so it is taken from beat 0 and the rest is compared to
// it — no knowledge of the DDS model required.
// ----------------------------------------------------------------------------
`SVTEST(tc_product_mode_constant)
    localparam int NROWS = 4;
    localparam int NSAMP = 4;
    logic [15:0]  re [N_DDS*4];
    logic [15:0]  im [N_DDS*4];
    logic [N_DDS*16-1:0] beats [$];
    logic [159:0] d;
    int           ref_v;

    for (int k = 0; k < N_DDS*NROWS; k++) begin
        re[k] = 16'h4000;
        im[k] = 16'h0000;
    end
    load_envelope(N_DDS*NROWS, re, im);

    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV),
                    16'(NSAMP), 2'd0 /*product*/, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    capture_burst(beats);

    `FAIL_IF_LOG(beats.size() !== NSAMP,
        $sformatf("tc_product_mode_constant: burst was %0d beats, expected %0d",
                  beats.size(), NSAMP));

    ref_v = int'(lane(beats[0], 0));
    `FAIL_IF_LOG(ref_v == 0,
        "tc_product_mode_constant: beat 0 lane 0 is zero — with a constant envelope over loaded rows the output should never be silent");

    for (int r = 0; r < beats.size(); r++)
        for (int l = 0; l < N_DDS; l++)
            `FAIL_IF_LOG(!close(int'(lane(beats[r], l)), ref_v),
                $sformatf("tc_product_mode_constant: beat %0d lane %0d = %0d, expected ~%0d",
                          r, l, int'(lane(beats[r], l)), ref_v));
`SVTEST_END

//// ----------------------------------------------------------------------------
//// TEST 08: backpressure mid-burst.
////
//// The previous version sampled tdata in the same edge in which it drove
//// tready low. tready is still high at that edge, so the DUT legitimately
//// completes one more handshake and presents the next beat — the testbench was
//// off by one and blamed the DUT for correct behaviour.
////
//// tready driven low at edge T takes effect after T. The DUT sees it at T+1 and
//// holds from then on. So: drive low, let one edge pass, THEN latch the
//// reference and start checking.
//// ----------------------------------------------------------------------------
//`SVTEST(tc_backpressure_mid_burst)
//    localparam int NSAMP = 8;
//    logic [N_DDS*16-1:0] beats [$];
//    logic [N_DDS*16-1:0] held;
//    logic [159:0]        d;
//    int                  t;
//
//    load_window(4, NSAMP);
//
//    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV),
//                    16'(NSAMP), 2'd2, 1'b0, 1'b0, 1'b0);
//    queue_descriptor(d);
//
//    t = 0;
//    while (!tb_m_tvalid && t < 400) begin @(posedge tb_aclk); t++; end
//    `FAIL_IF_LOG(!tb_m_tvalid, "tc_backpressure_mid_burst: burst never started");
//
//    beats.push_back(tb_m_tdata);
//    @(posedge tb_aclk);
//
//    tb_m_tready <= 1'b0;
//    @(posedge tb_aclk);          // tready is low from here on; the DUT has stopped
//    held = tb_m_tdata;           // whatever it is holding is what it must keep
//
//    repeat (10) begin
//        @(posedge tb_aclk);
//        `FAIL_IF_LOG(tb_m_tvalid !== 1'b1,
//            "tc_backpressure_mid_burst: tvalid dropped while tready was low");
//        `FAIL_IF_LOG(tb_m_tdata !== held,
//            "tc_backpressure_mid_burst: tdata changed while tready was low");
//    end
//
//    tb_m_tready <= 1'b1;
//    @(posedge tb_aclk);
//
//    // The held beat is still pending, so it counts towards the total
//    while (tb_m_tvalid && beats.size() < NSAMP + 4) begin
//        beats.push_back(tb_m_tdata);
//        @(posedge tb_aclk);
//    end
//
//    `FAIL_IF_LOG(beats.size() !== NSAMP,
//        $sformatf("tc_backpressure_mid_burst: %0d beats in total, expected %0d — 
//                  a stall must delay the burst, not shorten it",
//                  beats.size(), NSAMP));
//`SVTEST_END

                  // ----------------------------------------------------------------------------
// TEST 08 (replaces tc_backpressure_mid_burst): fixed-rate contract.
//
// sgv6 is a fixed-rate source: it does NOT honor i_axis_tready. In sgv6_top the
// output drives an axis_register_slice in non-blocking mode (tready always
// high) into the DACs, so this is correct by design, not a defect.
//
// This test pins that contract in place of testing back-pressure the DUT was
// never built to obey. Dropping tready mid-burst must NOT stall the stream: the
// beats keep coming, one per cycle, and the full burst still lands in nsamp
// cycles. If someone later makes the generator honor tready, this test will
// fail and force a deliberate decision rather than a silent behaviour change.
//
// It also documents WHY there is no back-pressure test: put a blocking element
// downstream and you lose data here, because nothing throttles the generator.
// ----------------------------------------------------------------------------
`SVTEST(tc_fixed_rate_ignores_tready)
    localparam int NSAMP = 8;
    logic [N_DDS*16-1:0] beats [$];
    logic [159:0]        d;
    int                  t;
    int                  valid_cycles;

    load_window(4, NSAMP);

    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV),
                    16'(NSAMP), 2'd2, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);

    // Wait for the burst to start
    t = 0;
    while (!tb_m_tvalid && t < 400) begin @(posedge tb_aclk); t++; end
    `FAIL_IF_LOG(!tb_m_tvalid, "tc_fixed_rate_ignores_tready: burst never started");

    // Deassert tready for the rest of the burst — a compliant slave would
    // stall here; this fixed-rate source must not.
    tb_m_tready <= 1'b0;

    // Count valid beats while tready is held low. The generator keeps going,
    // so tvalid stays high and a fresh beat appears every cycle.
    valid_cycles = 0;
    beats.delete();
    for (int i = 0; i < NSAMP + 4; i++) begin
        if (tb_m_tvalid) begin
            beats.push_back(tb_m_tdata);
            valid_cycles++;
        end
        @(posedge tb_aclk);
    end

    tb_m_tready <= 1'b1;

    // The burst ran to completion despite tready being low the whole time.
    `FAIL_IF_LOG(valid_cycles < NSAMP,
        $sformatf("tc_fixed_rate_ignores_tready: only %0d valid beats with tready low, expected the full %0d — the generator is NOT supposed to stall",
                  valid_cycles, NSAMP));

    // Consecutive beats advance (no repeats), confirming the stream really did
    // free-run rather than holding one value.
    `FAIL_IF_LOG(beats[0] === beats[1],
        "tc_fixed_rate_ignores_tready: beat did not advance while tready was low — the generator appears to be honoring tready, which breaks the fixed-rate assumption sgv6_top's downstream (non-blocking register slice) relies on");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 09 : two descriptors back to back.
//
// The previous version used capture_burst, which stops when tvalid drops. The
// two bursts run with no gap between them, so it captured 4+6=10 beats as one
// burst and reported the first as being the wrong length. Taking exactly the
// expected number of beats keeps the boundary meaningful.
// ----------------------------------------------------------------------------
`SVTEST(tc_two_descriptors)
    localparam int NSAMP_A = 4;
    localparam int NSAMP_B = 6;
    logic [N_DDS*16-1:0] a [$];
    logic [N_DDS*16-1:0] b [$];
    logic [159:0]        d;

    load_window(8, 8);

    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV),
                    16'(NSAMP_A), 2'd2, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV),
                    16'(NSAMP_B), 2'd2, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);

    capture_n_beats(a, NSAMP_A);
    capture_n_beats(b, NSAMP_B);

    `FAIL_IF_LOG(a.size() !== NSAMP_A || b.size() !== NSAMP_B,
        $sformatf("tc_two_descriptors: got %0d and %0d beats, expected %0d and %0d",
                  a.size(), b.size(), NSAMP_A, NSAMP_B));

    // Both descriptors start from address 0, so the two bursts must agree
    // beat for beat over their common length. A descriptor pushed twice, or a
    // burst that does not restart cleanly, shows up here.
    for (int r = 0; r < NSAMP_A; r++)
        `FAIL_IF_LOG(a[r] !== b[r],
            $sformatf("tc_two_descriptors: bursts disagree at beat %0d", r));

    // And the output must go quiet once both are done
    repeat (20) @(posedge tb_aclk);
    `FAIL_IF_LOG(tb_m_tvalid !== 1'b0,
        "tc_two_descriptors: still streaming after both descriptors completed");
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST: flat_top sequence -- the three back-to-back descriptors asm_v2 sends
// for a flat_top pulse: product ramp-up (envelope rows) -> dds plateau ->
// product ramp-down. Found on the board (debug bench): the
// plateau came out ~silent although the ramp-down arrived on time. The plateau
// must hold the level of a lone const (outsel=dds) pulse with the same gain on
// every one of its beats.
// ----------------------------------------------------------------------------
`SVTEST(tc_flat_top_sequence)
    localparam int NRAMP = 12;
    localparam int NFLAT = 184;
    localparam int GAIN  = MAXV / 2;
    logic [N_DDS*16-1:0] c [$];
    logic [N_DDS*16-1:0] s [$];
    logic [159:0]        d;
    int                  ref_v, got, nbad;

    load_flat(2 * NRAMP, 16'h4000);

    // reference: a lone const pulse (outsel=dds) at the same gain
    d = build_descr(32'd0, 32'd0, 16'd0, 16'(GAIN), 16'(NFLAT), 2'd1 /*dds*/, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    capture_n_beats(c, NFLAT);
    `FAIL_IF_LOG(c.size() !== NFLAT, "tc_flat_top_sequence: const reference burst incomplete");
    ref_v = int'($signed(lane(c[NFLAT/2], 0)));
    `FAIL_IF_LOG(ref_v == 0, "tc_flat_top_sequence: const reference is silent");
    repeat (40) @(posedge tb_aclk);

    // flat_top: ramp-up, plateau, ramp-down, queued back to back
    d = build_descr(32'd0, 32'd0, 16'd0, 16'(GAIN), 16'(NRAMP), 2'd0 /*product*/, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    d = build_descr(32'd0, 32'd0, 16'd0, 16'(GAIN), 16'(NFLAT), 2'd1 /*dds*/, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    d = build_descr(32'd0, 32'd0, 16'(NRAMP), 16'(GAIN), 16'(NRAMP), 2'd0 /*product*/, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    capture_n_beats(s, 2 * NRAMP + NFLAT);
    `FAIL_IF_LOG(s.size() !== 2 * NRAMP + NFLAT,
        $sformatf("tc_flat_top_sequence: got %0d beats, expected %0d", s.size(), 2 * NRAMP + NFLAT));

    nbad = 0;
    for (int r = NRAMP; r < NRAMP + NFLAT; r++) begin
        got = int'($signed(lane(s[r], 0)));
        if (!close(got, ref_v)) begin
            if (nbad < 6) $display("tc_flat_top_sequence: plateau beat %0d lane 0 = %0d, expected %0d", r - NRAMP, got, ref_v);
            nbad++;
        end
    end
    `FAIL_IF_LOG(nbad != 0,
        $sformatf("tc_flat_top_sequence: %0d of %0d plateau beats differ from the const level %0d",
                  nbad, NFLAT, ref_v));
`SVTEST_END
