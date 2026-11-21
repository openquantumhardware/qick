// ============================================================================
// File: dds_chirp_tests.sv
// Description: SVUnit tests for dds_chirp. Included by dds_chirp_tc00.sv.
//   The DDS model accumulates pinc (streaming), so the output is a real
//   sine/cosine. We verify frequency via the phase step dphi between samples.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Base carrier at rest — no trigger, DDS runs at FREQ_REG.
//   dphi per cycle must be constant = 2*pi*FREQ_REG / 2^16 (within tol).
// ----------------------------------------------------------------------------
`SVTEST(tc_base_carrier)
    real ang, ang_prev, dphi, exp_dphi;
    int  freq = 4000;
    set_params(freq, 0, 0, 0, 0);
    tb_cb.tb_din_valid <= 1'b1;
    repeat(20) @(tb_cb);              // fill pipeline + spin up accumulator
    exp_dphi = 2.0*3.14159265 * real'(freq) / 65536.0;
    ang_prev = sample_angle();
    @(tb_cb);
    for (int c = 0; c < 8; c++) begin
        ang  = sample_angle();
        dphi = ang - ang_prev;
        if (dphi >  3.14159265) dphi -= 2.0*3.14159265;
        if (dphi < -3.14159265) dphi += 2.0*3.14159265;
        if (!( (dphi - exp_dphi) < 0.02 && (exp_dphi - dphi) < 0.02 )) begin
            $display("BASE dphi MISMATCH cyc=%0d: exp %0.4f got %0.4f", c, exp_dphi, dphi);
            `FAIL_IF(1);
        end
        ang_prev = ang;
        @(tb_cb);
    end
    tb_cb.tb_din_valid <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Chirp rising — during the ramp the instantaneous frequency (dphi)
//   increases. We collect dphi over a window covering the chirp and require:
//   (a) the max dphi is strictly greater than the base dphi (freq rose), and
//   (b) within the ramp span dphi is monotonically non-decreasing.
//   Robust to exact latency (no hard LAT needed).
// ----------------------------------------------------------------------------
`SVTEST(tc_chirp_rising)
    real ang, ang_prev, dphi;
    real base_dphi, max_dphi;
    real dphi_hist [$];
    int  freq = 4000, b = 800, m = 200;
    int  n = 8;
    set_params(freq, b, m, n, 0);
    base_dphi = 2.0*3.14159265 * real'(freq) / 65536.0;   // ~0.3835
    max_dphi  = 0.0;
    tb_cb.tb_din_valid <= 1'b1;
    pulse_trigger();
    ang_prev = sample_angle();
    @(tb_cb);
    // Observe a window wide enough to cover latency + base + chirp + settle.
    for (int c = 0; c < 30; c++) begin
        ang  = sample_angle();
        dphi = ang - ang_prev;
        if (dphi >  3.14159265) dphi -= 2.0*3.14159265;
        if (dphi < -3.14159265) dphi += 2.0*3.14159265;
        // ignore the startup zone where the carrier hasn't begun (dphi ~ 0)
        if (dphi > 0.1) begin
            dphi_hist.push_back(dphi);
            if (dphi > max_dphi) max_dphi = dphi;
        end
        ang_prev = ang;
        @(tb_cb);
    end
    tb_cb.tb_din_valid <= 1'b0;

    // (a) the chirp pushed the frequency above the base.
    if (!(max_dphi > base_dphi + 0.02)) begin
        $display("CHIRP did not rise: max_dphi %0.4f <= base %0.4f", max_dphi, base_dphi);
        `FAIL_IF(1);
    end
    // (b) there is a rising run within the collected samples (chirp segment).
    begin
        int rising_run, best_run;
        real prev;
        rising_run = 0; best_run = 0; prev = -1.0;
        foreach (dphi_hist[k]) begin
            if (dphi_hist[k] + 0.001 >= prev) rising_run++;
            else rising_run = 0;
            if (rising_run > best_run) best_run = rising_run;
            prev = dphi_hist[k];
        end
        if (!(best_run >= n)) begin  // a monotone rising segment at least N long
            $display("CHIRP no monotone rising run of length %0d (best %0d)", n, best_run);
            `FAIL_IF(1);
        end
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03 (WAVE VIEW): long, slow chirp so the analog sine/cosine sweep is
//   clearly visible in the VCD. Not a pass/fail check on values -- it just
//   drives a nice long chirp and always passes. Open dds_chirp.vcd and look at
//   dut.tb_cos / dut.tb_sin (or o_dout) to see the frequency ramp up and settle.
//
//   Params chosen for visibility:
//     freq  = 1500  -> low base carrier (slow oscillation, easy to see)
//     B     = 1200  -> chirp starts well below base (pinc0 = 300)
//     M     = 40    -> gentle slope
//     N     = 60    -> many steps -> long sweep
//     W     = 8     -> hold each step 8 cycles -> slow, smooth ramp
//   Total sweep span ~ N*(W+1) cycles plus latency and tail.
// ----------------------------------------------------------------------------
`SVTEST(tc_chirp_waveview)
    int freq = 1500, b = 1200, m = 40;
    int n = 60, w = 8;
    set_params(freq, b, m, n, w);
    tb_cb.tb_din_valid <= 1'b1;

    // Let the base carrier run a while first (so the VCD shows the flat base
    // frequency before the chirp starts).
    repeat(80) @(tb_cb);

    // Fire the chirp.
    pulse_trigger();

    // Run long enough to cover the full ramp (N*(W+1) ~ 540) + latency + tail,
    // so we see: base -> rising chirp -> settle back to base.
    repeat(700) @(tb_cb);

    // Optional: fire a second time to show retrigger behaviour in the wave.
    pulse_trigger();
    repeat(700) @(tb_cb);

    tb_cb.tb_din_valid <= 1'b0;
    repeat(20) @(tb_cb);

    // No value check -- this test is for waveform inspection only.
    `FAIL_IF(0);
`SVTEST_END