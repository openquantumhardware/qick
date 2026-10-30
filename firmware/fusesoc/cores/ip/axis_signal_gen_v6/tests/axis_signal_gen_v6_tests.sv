// ============================================================================
// File: axis_signal_gen_v6_tests.sv  (rev 3)
//
// Datapath is correct: every functional test below passes at beat-aligned
// carrier frequencies. The two rev-2 diagnostics (carrier_beat_parity,
// probe_first_beat_index) were REMOVED - they assumed a multi-beat advancing
// burst, but with nsamp = N_DDS the burst is a SINGLE beat, so a capture that
// does not gate on tvalid re-reads held data (frame1 == frame0). See
// dds_phase_probe.sv for the corrected, tvalid-guarded characterization that
// measures the burst length and the carrier startup offset instead of
// assuming them.
//
// Real cause of the original "sign flip": a fixed one-beat (N_DDS-sample)
// carrier startup phase offset (base = N_DDS*pinc), invisible when
// N_DDS*pinc = 0 (mod 2^32) - i.e. at beat-aligned frequencies, which is
// exactly why every test here uses pinc a multiple of 2^28.
//
// REQUIRES in tc00 (unchanged):
//   - assign m_if.tready = 1'b1;   at module level (fixed-rate sink)
//   - assign m_if.tlast  = 1'b0;
//   - s0_if / s1_if masters reset via m_reset() before reset is released
// ============================================================================


// ----------------------------------------------------------------------------
// TEST 01: Register readback via AXI-Lite.
// ----------------------------------------------------------------------------
`SVTEST(tc_reg_readback)
    logic [31:0] rd;
    reg_write(REG_START_ADDR, 32'h0000_00AB);
    reg_read (REG_START_ADDR, rd);
    `FAIL_IF_LOG(rd !== 32'h0000_00AB,
        $sformatf("tc_reg_readback: START_ADDR got 0x%08h", rd));
    reg_write(REG_WE, 32'h1);
    reg_read (REG_WE, rd);
    `FAIL_IF_LOG(rd[0] !== 1'b1, $sformatf("tc_reg_readback: WE got 0x%08h", rd));
    reg_write(REG_WE, 32'h0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: DDS-only pure tone - beat-aligned pinc = 2^28.
// ----------------------------------------------------------------------------
`SVTEST(tc_pure_tone_all_lanes)
    logic [15:0]        re [], im [];
    logic signed [15:0] lanes [N_DDS];
    logic [159:0]       d;
    logic [31:0]        pinc = 32'h1000_0000;   // 2^28
    int                 exp_v;

    const_envelope(N_DDS, 16'h0000, re, im);
    load_envelope(N_DDS, re, im);

    d = build_descr(pinc, 32'd0, 16'd0, 16'(MAXV),
                    16'd16, 2'd1 /*DDS*/, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    wait_output_frame(lanes);

    for (int i = 0; i < N_DDS; i++) begin
        exp_v = ref_cos(i * pinc);
        `FAIL_IF_LOG(!near(int'(lanes[i]), exp_v, LANE_TOL),
            $sformatf("tc_pure_tone_all_lanes: lane %0d got %0d expected %0d (phase 0x%08h)",
                      i, int'(lanes[i]), exp_v, i * pinc));
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Phase offset - beat-aligned pinc, +90 deg descriptor phase.
// ----------------------------------------------------------------------------
`SVTEST(tc_phase_offset)
    logic [15:0]        re [], im [];
    logic signed [15:0] lanes [N_DDS];
    logic [159:0]       d;
    logic [31:0]        pinc  = 32'h1000_0000;   // 2^28
    logic [31:0]        phase = 32'h4000_0000;   // +90 degrees
    int                 exp_v;

    const_envelope(N_DDS, 16'h0000, re, im);
    load_envelope(N_DDS, re, im);

    d = build_descr(pinc, phase, 16'd0, 16'(MAXV),
                    16'd16, 2'd1, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    wait_output_frame(lanes);

    for (int i = 0; i < N_DDS; i++) begin
        exp_v = ref_cos(i * pinc + phase);
        `FAIL_IF_LOG(!near(int'(lanes[i]), exp_v, LANE_TOL),
            $sformatf("tc_phase_offset: lane %0d got %0d expected %0d",
                      i, int'(lanes[i]), exp_v));
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: Frequency sweep - all pinc beat-aligned (multiples of 2^28).
// ----------------------------------------------------------------------------
`SVTEST(tc_frequency_sweep_exact)
    logic [15:0]        re [], im [];
    logic signed [15:0] lanes [N_DDS];
    logic [159:0]       d;
    logic [31:0]        pincs [3] = '{32'h1000_0000, 32'h2000_0000, 32'h3000_0000};
    int                 exp_v;

    const_envelope(N_DDS, 16'h0000, re, im);
    load_envelope(N_DDS, re, im);

    foreach (pincs[j]) begin
        d = build_descr(pincs[j], 32'd0, 16'd0, 16'(MAXV),
                        16'd16, 2'd1, 1'b0, 1'b0, 1'b0);
        queue_descriptor(d);
        wait_output_frame(lanes);
        for (int i = 0; i < N_DDS; i++) begin
            exp_v = ref_cos(i * pincs[j]);
            `FAIL_IF_LOG(!near(int'(lanes[i]), exp_v, LANE_TOL),
                $sformatf("tc_frequency_sweep_exact: pinc 0x%08h lane %0d got %0d expected %0d",
                          pincs[j], i, int'(lanes[i]), exp_v));
        end
        repeat (30) @(posedge aclk);
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04b: Frequency with a pinc that is NOT beat-aligned.
//
// Every pinc in tc_frequency_sweep_exact is a multiple of 2^28 = 2^32/N_DDS,
// so the phase advances a whole number of turns per beat and every output
// frame is identical. Those tests therefore cannot see whether the phase
// accumulator carries N_DDS*pinc from one beat to the next: a design that
// restarted it every frame, or that only produced frequencies modulo the
// beat rate (fs/N_DDS), would pass them all.
//
// Checking absolute phase here does not work -- the first frame out of the
// pipeline is not sample 0, and the offset is not a documented constant. So
// this uses the second-order recurrence a sampled cosine obeys,
//
//     x[n-1] + x[n+1] = 2*cos(2*pi*pinc/2^32) * x[n]
//
// which holds for any starting phase and any amplitude. That makes it immune
// to pipeline latency and to gain scaling, and it is checked straight across
// the frame boundaries -- exactly where a missing beat-to-beat carry breaks
// it while every within-frame check still passes.
// ----------------------------------------------------------------------------
`SVTEST(tc_frequency_unaligned_across_beats)
    logic [15:0]        re [], im [];
    logic signed [15:0] frames [][N_DDS];
    logic [159:0]       d;
    logic [31:0]        pinc = 32'h0AAA_AAAB;   // 2^32/24, not beat-aligned
    int                 nframes = 4;
    int                 nsm;
    real                k, lhs, rhs, tol;
    int                 x [];
    bit                 all_same;

    const_envelope(N_DDS, 16'h0000, re, im);
    load_envelope(N_DDS, re, im);

    // nsamp has to outlast the frames we capture: the counter decrements
    // once per aclk and returns at 2.
    d = build_descr(pinc, 32'd0, 16'd0, 16'(MAXV),
                    16'd64, 2'd1, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    capture_frames(frames, nframes);

    // Reported separately and first: identical frames mean the accumulator
    // never advances, which is a different fault from a wrong advance and is
    // much easier to read as one line than as sixty failing samples.
    all_same = 1;
    for (int r = 1; r < nframes; r++)
        for (int i = 0; i < N_DDS; i++)
            if (frames[r][i] !== frames[0][i]) all_same = 0;
    `FAIL_IF_LOG(all_same,
        "tc_frequency_unaligned_across_beats: every frame identical -- the phase accumulator is not carrying across beats, so the output frequency is only defined modulo the beat rate")

    // Flatten to one sample stream so the recurrence crosses frame edges.
    nsm = nframes * N_DDS;
    x = new[nsm];
    for (int r = 0; r < nframes; r++)
        for (int i = 0; i < N_DDS; i++)
            x[r*N_DDS + i] = int'(frames[r][i]);

    k   = 2.0 * $cos(2.0 * PI * real'(pinc) / (2.0 ** 32));
    tol = 4.0 * real'(LANE_TOL);   // three terms, each quantised

    for (int n = 1; n < nsm - 1; n++) begin
        lhs = real'(x[n-1]) + real'(x[n+1]);
        rhs = k * real'(x[n]);
        `FAIL_IF_LOG(((lhs - rhs) > tol) || ((rhs - lhs) > tol),
            $sformatf("tc_frequency_unaligned_across_beats: recurrence broken at sample %0d (frame %0d lane %0d): x[n-1]+x[n+1]=%0.1f, 2cos(w)x[n]=%0.1f",
                      n, n/N_DDS, n%N_DDS, lhs, rhs));
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: Modulated pulse - constant envelope * carrier, beat-aligned pinc.
// ----------------------------------------------------------------------------
`SVTEST(tc_modulated_pulse_all_lanes)
    logic [15:0]        re [], im [];
    logic signed [15:0] lanes [N_DDS];
    logic [159:0]       d;
    logic [31:0]        pinc = 32'h1000_0000;   // 2^28
    logic [15:0]        env  = 16'h4000;
    int                 exp_v;

    const_envelope(N_DDS*2, env, re, im);
    load_envelope(N_DDS*2, re, im);

    d = build_descr(pinc, 32'd0, 16'd0, 16'(MAXV),
                    16'd16, 2'd0 /*product*/, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    wait_output_frame(lanes);

    for (int i = 0; i < N_DDS; i++) begin
        exp_v = (ref_cos(i * pinc) * int'(env)) / 32768;
        `FAIL_IF_LOG(!near(int'(lanes[i]), exp_v, LANE_TOL*2),
            $sformatf("tc_modulated_pulse_all_lanes: lane %0d got %0d expected ~%0d",
                      i, int'(lanes[i]), exp_v));
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: Envelope-only (src=2). GREEN - one-sample mem-skew compensation
// (re[i+1]) left as-is pending the characterization probe.
// ----------------------------------------------------------------------------
`SVTEST(tc_envelope_only_all_lanes)
    logic [15:0]        re [], im [];
    logic signed [15:0] lanes [N_DDS];
    logic [159:0]       d;
    int                 exp_v;

    re = new[N_DDS*2]; im = new[N_DDS*2];
    for (int i = 0; i < N_DDS; i++) begin
        int val = 16'(1000 + i * 1000);
        re[i]         = val;
        re[i + N_DDS] = val;
        im[i]         = 16'h0000;
        im[i + N_DDS] = 16'h0000;
    end
    load_envelope(N_DDS, re, im);

    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV),
                    16'd16, 2'd2 /*mem*/, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    wait_output_frame(lanes);

    for (int i = 0; i < N_DDS; i++) begin
        exp_v = (int'(re[i]) * MAXV) / 32768;   
        `FAIL_IF_LOG(!near(int'(lanes[i]), exp_v, LANE_TOL),
            $sformatf("tc_envelope_only_all_lanes: lane %0d got %0d expected ~%0d",
                      i, int'(lanes[i]), exp_v));
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: Gain scaling - half gain gives half output (ratio), beat-aligned.
// ----------------------------------------------------------------------------
`SVTEST(tc_gain_scaling)
    logic [15:0]        re [], im [];
    logic signed [15:0] full [N_DDS];
    logic signed [15:0] half [N_DDS];
    logic [159:0]       d;
    logic [31:0]        pinc = 32'h1000_0000;   // 2^28

    const_envelope(N_DDS*2, 16'h4000, re, im);
    load_envelope(N_DDS*2, re, im);

    d = build_descr(pinc, 32'd0, 16'd0, 16'(MAXV),
                    16'd16, 2'd0, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    wait_output_frame(full);

    repeat (30) @(posedge aclk);

    d = build_descr(pinc, 32'd0, 16'd0, 16'(MAXV/2),
                    16'd16, 2'd0, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    wait_output_frame(half);

    for (int i = 0; i < N_DDS; i++)
        `FAIL_IF_LOG(!near(int'(half[i]), int'(full[i])/2, LANE_TOL*2),
            $sformatf("tc_gain_scaling: lane %0d full=%0d half=%0d",
                      i, int'(full[i]), int'(half[i])));
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: Saturation status register.
// ----------------------------------------------------------------------------
`SVTEST(tc_sat_status_reg)
    logic [15:0]  re [], im [];
    logic [31:0]  status;
    logic [159:0] d;

    reg_write(REG_CTRL, 32'h1);
    reg_write(REG_CTRL, 32'h0);
    repeat (20) @(posedge aclk);

    const_envelope(N_DDS*4, 16'h8000, re, im);
    load_envelope(N_DDS*4, re, im);
    d = build_descr(32'd0, 32'd0, 16'd0, 16'h7FFF, 16'd16, 2'd0, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    repeat (150) @(posedge aclk);

    repeat (20) @(posedge s_axi_aclk);
    reg_read(REG_STATUS, status);
    `FAIL_IF_LOG(status[0] !== 1'b1, "tc_sat_status_reg: sticky not set");

    reg_write(REG_CTRL, 32'h1);
    reg_write(REG_CTRL, 32'h0);
    repeat (20) @(posedge s_axi_aclk);
    reg_read(REG_STATUS, status);
    `FAIL_IF_LOG(status[0] !== 1'b0, "tc_sat_status_reg: sticky not cleared");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 09: Gaussian envelope shape. GREEN - one-sample skew comp left as-is.
// ----------------------------------------------------------------------------
`SVTEST(tc_gaussian_envelope)
    logic [15:0]        re [], im [];
    logic signed [15:0] lanes [N_DDS];
    logic [159:0]       d;
    real                center, sigma, g;
    int                 peak_idx, peak_val;
    int val;

    re = new[N_DDS]; im = new[N_DDS];
    center = (real'(N_DDS) - 1.0) / 2.0; //simmetric about centre
    sigma  = real'(N_DDS) / 6.0;

    for (int k = 0; k < N_DDS; k++) begin
        g = $exp(-0.5 * ((real'(k) - center) / sigma) ** 2);
        val = $rtoi(g * real'(MAXV));
        re[k]         = val;
        re[k + N_DDS] = val;
        im[k]                       = 16'h0000;
        im[k + N_DDS]               = 16'h0000;
    end
    load_envelope(N_DDS, re, im);

    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV),
                    16'd16, 2'd2, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);
    wait_output_frame(lanes);

    peak_idx = 0; peak_val = -40000;
    for (int i = 0; i < N_DDS; i++)
        if (int'(lanes[i]) > peak_val) begin
            peak_val = int'(lanes[i]); peak_idx = i;
        end

    `FAIL_IF_LOG(peak_idx < 6 || peak_idx > 9,
        $sformatf("tc_gaussian_envelope: peak at lane %0d, expected near centre", peak_idx));
    `FAIL_IF_LOG(int'(lanes[0]) > peak_val/4,
        "tc_gaussian_envelope: edge lane too large");

    for (int k = 0; k < N_DDS/2; k++)
        `FAIL_IF_LOG(!near(int'(lanes[k]), int'(lanes[N_DDS-1-k]), 1024),
            $sformatf("tc_gaussian_envelope: asymmetric at lane %0d vs %0d", k, N_DDS-1-k));
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 10: Fixed-rate contract (corrected) - production is independent of
// tready. Run the SAME descriptor twice over an equal window, once tready
// high, once tready forced low, and require the same valid-beat count. Robust
// to the actual burst length. A long burst (nsamp=128) keeps the 8-cycle
// window fully inside the burst so the check is meaningful. AXIS master-
// stability assertions are disabled only for the forced-low window and
// re-armed after a generous drain (tready high, stream settled) so no clocked
// assertion window straddles the release edge (the rev-2 failure mode).
// ----------------------------------------------------------------------------
`SVTEST(tc_fixed_rate_ignores_tready)
    logic [15:0]  re [], im [];
    logic [159:0] d;
    int           cnt_hi, cnt_lo, i;

    const_envelope(N_DDS, 16'h4000, re, im);
    load_envelope(N_DDS, re, im);
    d = build_descr(32'h1000_0000, 32'd0, 16'd0, 16'(MAXV),
                    16'd128 /*long burst*/, 2'd1, 1'b0, 1'b0, 1'b0);

    // Reference run: tready high (hardware regime).
    queue_descriptor(d);
    i = 0; while (!m_if.tvalid && i < 400) begin @(posedge aclk); i++; end
    `FAIL_IF_LOG(!m_if.tvalid, "tc_fixed_rate_ignores_tready: burst never started (hi)");
    cnt_hi = 0;
    for (i = 0; i < 8; i++) begin if (m_if.tvalid) cnt_hi++; @(posedge aclk); end

    repeat (80) @(posedge aclk);   // fully drain

    // Test run: tready forced low over the same window.
    queue_descriptor(d);
    i = 0; while (!m_if.tvalid && i < 400) begin @(posedge aclk); i++; end
    `FAIL_IF_LOG(!m_if.tvalid, "tc_fixed_rate_ignores_tready: burst never started (lo)");

    $assertoff(0, m_if);           // this output is a deliberate non-compliant master
    force m_if.tready = 1'b0;
    cnt_lo = 0;
    for (i = 0; i < 8; i++) begin if (m_if.tvalid) cnt_lo++; @(posedge aclk); end
    release m_if.tready;
    repeat (30) @(posedge aclk);   // drain with tready high before re-arming
    $asserton(0, m_if);

    `FAIL_IF_LOG(cnt_lo != cnt_hi,
        $sformatf("tc_fixed_rate_ignores_tready: not fixed-rate: %0d beats with tready HIGH vs %0d with tready LOW",
                  cnt_hi, cnt_lo));
    `FAIL_IF_LOG(cnt_hi < 6,
        $sformatf("tc_fixed_rate_ignores_tready: reference burst too short (%0d beats) - raise nsamp", cnt_hi));
`SVTEST_END