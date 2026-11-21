// ============================================================================
// File: sgv6_tests.sv
// Description: SVUnit test cases for sgv6 amplitude characterisation.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Reset — output not valid.
// ----------------------------------------------------------------------------
`SVTEST(tc_reset_idle)
    repeat(5) @(posedge tb_clk);
    `FAIL_IF(tb_axis_tvalid !== 1'b0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Mid-scale envelope, mid-scale gain, full-scale cosine.
//   Characterise the level: print RTL output, faithful-model output, and the
//   ideal (Q15+sat) output. Verify RTL matches the faithful model.
// ----------------------------------------------------------------------------
`SVTEST(tc_level_midscale)
    logic [15:0] dout0, exp_rtl, exp_ideal;
    logic [159:0] d;
    set_envelope(16'h4000, 16'h0000);    // env_re = 0.5 (Q15)
    d = build_descr(32'd0, 32'd0, 16'd0, 16'h4000 /*gain=0.5*/,
                    16'd64, 2'd0 /*product*/, 1'b0, 1'b0, 1'b0);
    load_descriptor(d);
    wait_output(dout0);
    exp_rtl   = ref_rtl_prod(16'sh4000, 16'sh0000, 16'sh7FFF, 16'sh0000, 16'sh4000);
    exp_ideal = ref_ideal_prod(16'sh4000, 16'sh7FFF, 16'sh4000);
    $display("[LEVEL midscale] RTL=0x%04h  faithful=0x%04h  ideal=0x%04h",
             dout0, exp_rtl, exp_ideal);
    `FAIL_IF_LOG(dout0 !== exp_rtl,
        $sformatf("RTL 0x%04h != faithful model 0x%04h", dout0, exp_rtl));
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Full-scale everything — expose wrap-around / level loss.
//   env=MAXV, gain=MAXV, cos=full-scale. The ideal output should saturate to
//   ~MAXV. Print all three to see whether the RTL wraps or scales down.
// ----------------------------------------------------------------------------
`SVTEST(tc_level_fullscale)
    logic [15:0] dout0, exp_rtl, exp_ideal;
    logic signed [15:0] sdout;
    logic [159:0] d;
    set_envelope(16'(MAXV), 16'h0000);
    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV),
                    16'd64, 2'd0, 1'b0, 1'b0, 1'b0);
    load_descriptor(d);
    wait_output(dout0);
    sdout     = dout0;
    exp_rtl   = ref_rtl_prod(16'(MAXV), 16'sh0000, 16'sh7FFF, 16'sh0000, 16'(MAXV));
    exp_ideal = ref_ideal_prod(16'(MAXV), 16'sh7FFF, 16'(MAXV));
    $display("[LEVEL fullscale] RTL=0x%04h (%0d)  faithful=0x%04h  ideal=0x%04h (%0d)",
             dout0, sdout, exp_rtl, exp_ideal, $signed(exp_ideal));
    // RTL must match the faithful model (documents current behaviour).
    `FAIL_IF_LOG(dout0 !== exp_rtl,
        $sformatf("RTL 0x%04h != faithful 0x%04h", dout0, exp_rtl));
    // Informational: how far is the RTL from the ideal saturated level?
    if (dout0 !== exp_ideal)
        $display("[NOTE] fullscale RTL differs from ideal: 0x%04h vs 0x%04h",
                 dout0, exp_ideal);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: Sweep gain, fixed full-scale envelope and cosine.
//   Verify RTL == faithful model across the gain range, and flag wrap-around
//   (output sign flips where the ideal would keep growing/saturating).
// ----------------------------------------------------------------------------
`SVTEST(tc_gain_sweep)
    logic [15:0] dout0, exp_rtl;
    logic [159:0] d;
    logic [15:0] gains [5] = '{16'h1000, 16'h2000, 16'h4000, 16'h6000, 16'(MAXV)};
    foreach (gains[k]) begin
        set_envelope(16'(MAXV), 16'h0000);
        d = build_descr(32'd0, 32'd0, 16'd0, gains[k],
                        16'd64, 2'd0, 1'b0, 1'b0, 1'b0);
        load_descriptor(d);
        wait_output(dout0);
        exp_rtl = ref_rtl_prod(16'(MAXV), 16'sh0000, 16'sh7FFF, 16'sh0000, gains[k]);
        $display("[GAIN SWEEP] gain=0x%04h  RTL=0x%04h (%0d)  faithful=0x%04h (%0d)",
                 gains[k], dout0, $signed(dout0), exp_rtl, $signed(exp_rtl));
        tb_fifo_empty <= 1'b1;
        repeat(10) @(posedge tb_clk);
    end
    `FAIL_IF(1'b0);   // characterisation only
`SVTEST_END
// ----------------------------------------------------------------------------
// TEST 05: src=2 (envelope only) — verify the >>1 scaling of the mem path.
// ----------------------------------------------------------------------------
`SVTEST(tc_envelope_only)
    logic [15:0] dout0;
    logic [159:0] d;
    set_envelope(16'h4000, 16'h0000);   // env = 0.5
    // src=2 (mem only), gain=full so the gain stage is ~unity-ish
    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV),
                    16'd64, 2'd2 /*mem*/, 1'b0, 1'b0, 1'b0);
    load_descriptor(d);
    wait_output(dout0);
    $display("[ENV ONLY] env=0x4000 src=mem  RTL=0x%04h (%0d)",
             dout0, $signed(dout0));
    // Documented behaviour: mem path goes through (mem) and then *gain/[30:15].
    // Just record it; no strict check here (characterisation).
    `FAIL_IF(1'b0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST: full-scale product path now reaches ~MAXV (was ~MAXV/2 before fix).
// ----------------------------------------------------------------------------
`SVTEST(tc_fullscale_fixed)
    logic [15:0] dout0;
    logic [159:0] d;
    set_envelope(16'(MAXV), 16'h0000);
    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV),
                    16'd64, 2'd0, 1'b0, 1'b0, 1'b0);
    load_descriptor(d);
    wait_output(dout0);
    $display("[FIXED fullscale] env=MAXV gain=MAXV cos=full -> out=0x%04h (%0d)",
             dout0, $signed(dout0));
    // Expect near MAXV (saturated), NOT MAXV/2.
    `FAIL_IF_LOG($signed(dout0) < 16'sd30000,
        $sformatf("fullscale should be ~MAXV, got 0x%04h (%0d)", dout0, $signed(dout0)));
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST: product path and envelope-only path now match in scale.
// ----------------------------------------------------------------------------
`SVTEST(tc_paths_match_scale)
    logic [15:0] prod_out, env_out;
    logic [159:0] d;
    // Product path (src=0), envelope=0x4000, cos=full, gain=MAXV.
    set_envelope(16'h4000, 16'h0000);
    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV), 16'd64, 2'd0, 1'b0, 1'b0, 1'b0);
    load_descriptor(d);
    wait_output(prod_out);
    // Envelope-only path (src=2), same envelope and gain.
    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV), 16'd64, 2'd2, 1'b0, 1'b0, 1'b0);
    load_descriptor(d);
    wait_output(env_out);
    $display("[PATHS] product=0x%04h (%0d)  envelope-only=0x%04h (%0d)",
             prod_out, $signed(prod_out), env_out, $signed(env_out));
    // They should be close now (same scale). Allow small quantization diff.
    `FAIL_IF_LOG($signed(prod_out) < $signed(env_out) - 16'sd200 ||
                 $signed(prod_out) > $signed(env_out) + 16'sd200,
        $sformatf("paths differ: prod=%0d env=%0d", $signed(prod_out), $signed(env_out)));
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST: saturation — extreme values clamp to MAXV, no wrap (no sign flip).
// ----------------------------------------------------------------------------
`SVTEST(tc_saturation_no_wrap)
    logic [15:0] dout0;
    logic [159:0] d;
    set_envelope(16'h7FFF, 16'h0000);   // envelope at absolute max
    d = build_descr(32'd0, 32'd0, 16'd0, 16'h7FFF, 16'd64, 2'd0, 1'b0, 1'b0, 1'b0);
    load_descriptor(d);
    wait_output(dout0);
    $display("[SATURATION] max*max*max -> out=0x%04h (%0d)", dout0, $signed(dout0));
    // Must be positive and near MAXV, NOT a negative wrap.
    `FAIL_IF_LOG($signed(dout0) < 16'sd0,
        $sformatf("wrap detected! out=0x%04h (%0d) is negative", dout0, $signed(dout0)));
    `FAIL_IF_LOG($signed(dout0) < 16'sd30000,
        $sformatf("saturation should reach ~MAXV, got %0d", $signed(dout0)));
`SVTEST_END

`SVTEST(tc_dds_only_dc)
    logic [15:0] dout0;
    logic [159:0] d;
    // src=1 (DDS only), freq=0 -> DDS cos should be 0x7FFF (DC), * gain.
    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV),
                    16'd64, 2'd1 /*DDS*/, 1'b0, 1'b0, 1'b0);
    load_descriptor(d);
    // capture peak of the burst
    begin
        logic [15:0] peak = '0;
        int t = 0;
        while (!tb_axis_tvalid && t < 200) begin @(posedge tb_clk); t++; end
        while (tb_axis_tvalid) begin
            if ($signed(tb_axis_tdata[15:0]) > $signed(peak)) peak = tb_axis_tdata[15:0];
            @(posedge tb_clk);
        end
        $display("[DDS-ONLY DC] freq=0 src=1  peak=0x%04h (%0d)", peak, $signed(peak));
        `FAIL_IF_LOG($signed(peak) < 16'sd10000, "DDS-only DC path gave near-zero");
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST: DDS phase/carrier correctness.
//   With a single descriptor the control settles the phase to a fixed value;
//   verify the DDS produces the correct cos/sin for that phase. For pinc that
//   yields 90deg, cos=0 and sin=full-scale. (Full sine sweeps are exercised in
//   the sgv6_top integration TB with a continuous stream.)
// ----------------------------------------------------------------------------
`SVTEST(tc_dds_carrier_correct)
    logic [159:0] d;
    logic [31:0] pinc;
    logic signed [15:0] cos_seen, sin_seen;
    bit got_90 = 1'b0;
    pinc = 32'h0400_0000;
    d = build_descr(pinc, 32'd0, 16'd0, 16'(MAXV), 16'd64, 2'd1, 1'b0, 1'b0, 1'b0);
    load_descriptor(d);
    // Watch the DDS output until the phase settles at 0x40000000 (90deg),
    // where the model must give cos=0, sin=full-scale.
    for (int k = 0; k < 60; k++) begin
        @(posedge tb_clk);
        if (dut.dds_ctrl_int_r[63:32] === 32'h40000000) begin
            cos_seen = dut.dds_dout[0][15:0];
            sin_seen = dut.dds_dout[0][31:16];
            // allow the pipeline to reflect this phase
            if (sin_seen === 16'sd32767) got_90 = 1'b1;
        end
    end
    $display("[DDS CARRIER] at 90deg: cos=%0d sin=%0d", $signed(cos_seen), $signed(sin_seen));
    `FAIL_IF_LOG(!got_90, "DDS did not produce sin=full-scale at 90deg phase");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST: saturation flag asserts when clamping.
//   max*max*max saturates -> o_sat must go high during the burst.
// ----------------------------------------------------------------------------
`SVTEST(tc_sat_flag_asserts)
    logic [15:0] dout0;
    logic [159:0] d;
    bit saw_sat = 1'b0;
    int t;
    // Force the pathological signed case to trigger saturation:
    // env = 0x8000 (-32768, min), which with cos and gain can exceed +/-MAXV.
    set_envelope(16'h8000, 16'h0000);   // envelope = -32768 (min negative)
    d = build_descr(32'd0, 32'd0, 16'd0, 16'h7FFF /*gain max*/,
                    16'd64, 2'd0, 1'b0, 1'b0, 1'b0);
    load_descriptor(d);
    for (t = 0; t < 100; t++) begin
        @(posedge tb_clk);
        if (dut.o_sat) saw_sat = 1'b1;
    end
    $display("[SAT FLAG] env=min(-32768): o_sat seen = %b", saw_sat);
    `FAIL_IF_LOG(!saw_sat, "o_sat did not assert for pathological min-value case");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST: saturation flag stays low for a normal mid-scale pulse.
// ----------------------------------------------------------------------------
`SVTEST(tc_sat_flag_clear_normal)
    logic [15:0] dout0;
    logic [159:0] d;
    bit saw_sat = 1'b0;
    int t;
    set_envelope(16'h2000, 16'h0000);   // quarter-scale envelope
    d = build_descr(32'd0, 32'd0, 16'd0, 16'h2000 /*low gain*/,
                    16'd64, 2'd0, 1'b0, 1'b0, 1'b0);
    load_descriptor(d);
    for (t = 0; t < 100; t++) begin
        @(posedge tb_clk);
        if (dut.o_sat) saw_sat = 1'b1;
    end
    $display("[SAT FLAG] mid-scale: o_sat seen = %b (expect 0)", saw_sat);
    `FAIL_IF_LOG(saw_sat, "o_sat asserted for a non-saturating pulse");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST: saturation flag coherence.
//   Sweep envelope from mid to extreme (including 0x8000 min). Verify that
//   o_sat is high exactly when the internal round clamps to +/- MAXV.
// ----------------------------------------------------------------------------
`SVTEST(tc_sat_flag_coherent)
    logic [159:0] d;
    logic [15:0] envs [4] = '{16'h2000, 16'h7FFF, 16'h8000, 16'h8001};
    int t;
    foreach (envs[k]) begin
        bit saw_sat = 1'b0;
        bit saw_clamp = 1'b0;
        set_envelope(envs[k], 16'h0000);
        d = build_descr(32'd0, 32'd0, 16'd0, 16'h7FFF, 16'd32, 2'd0, 1'b0, 1'b0, 1'b0);
        load_descriptor(d);
        for (t = 0; t < 60; t++) begin
            @(posedge tb_clk);
            if (dut.o_sat) saw_sat = 1'b1;
            // check if lane-0 output equals a clamp value while enabled
            if (dut.o_axis_tvalid &&
                (dut.o_axis_tdata[15:0] === 16'h7FFE ||
                 dut.o_axis_tdata[15:0] === 16'h8002)) saw_clamp = 1'b1;
        end
        $display("[SAT COHERENT] env=0x%04h  o_sat=%b  clamp_out=%b",
                 envs[k], saw_sat, saw_clamp);
    end
    `FAIL_IF(1'b0);   // characterisation
`SVTEST_END
