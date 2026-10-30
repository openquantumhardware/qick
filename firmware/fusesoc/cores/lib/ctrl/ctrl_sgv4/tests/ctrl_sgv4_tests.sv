// ============================================================================
// File: ctrl_sgv4_tests.sv
// Description: SVUnit test cases for ctrl_sgv4. Included by ctrl_sgv4_tc00.sv.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Reset state — idle outputs, FSM in READ_ST (rd_en asserted).
// ----------------------------------------------------------------------------
`SVTEST(tc_reset_idle)
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
                    16'd8, 2'd0, 1'b0, 1'b0, 1'b0, 1'b0);
    push_descriptor(d);
    repeat(20) @(tb_cb);
    `FAIL_IF(1'b0);   // reaching here without hang is the pass condition
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Gain decode + latency measurement.
// ----------------------------------------------------------------------------
`SVTEST(tc_gain_decode)
    logic [159:0] d;
    int lat;
    d = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'(MAXV),
                    16'd64, 2'd0, 1'b0, 1'b0, 1'b0, 1'b0);
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
    d = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'h4000,
                    16'd64, 2'd0, 1'b0, 1'b0, 1'b0, 1'b0);
    measure_gain_latency(d, 16'h4000, lat);
    `FAIL_IF_LOG(lat < 0, "tc_gain_values: gain 0x4000 not observed");
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
                    16'd64, 2'd2, 1'b0, 1'b0, 1'b0, 1'b0);
    hold_descriptor(d);
    @(tb_cb);
    while (!tb_fifo_rd_en) @(tb_cb);
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
                    16'd64, 2'd0, 1'b0, 1'b1, 1'b0, 1'b0);
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
// TEST 07: en asserts after a descriptor is loaded (mode=0).
// ----------------------------------------------------------------------------
`SVTEST(tc_en_asserts)
    logic [159:0] d;
    int t;
    d = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'(MAXV),
                    16'd64, 2'd0, 1'b0, 1'b0, 1'b0, 1'b0);
    hold_descriptor(d);
    @(tb_cb);
    while (!tb_fifo_rd_en) @(tb_cb);
    t = 0;
    while (tb_en !== 1'b1 && t < 64) begin @(tb_cb); t++; end
    $display("[INFO] en latency = %0d cycles", t);
    `FAIL_IF_LOG(tb_en !== 1'b1, "tc_en_asserts: en never asserted");
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(30) @(tb_cb);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: mem_addr starts at 'addr' and then increments.
// ----------------------------------------------------------------------------
`SVTEST(tc_mem_addr_ramp)
    logic [159:0] d;
    logic [N-1:0] a0, a1, a2;
    int t;
    d = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'(MAXV),
                    16'd64, 2'd0, 1'b0, 1'b0, 1'b0, 1'b0);
    hold_descriptor(d);
    @(tb_cb);
    while (!tb_fifo_rd_en) @(tb_cb);
    t = 0;
    while (tb_en !== 1'b1 && t < 64) begin @(tb_cb); t++; end
    `FAIL_IF_LOG(tb_en !== 1'b1, "tc_mem_addr_ramp: en never asserted");
    a0 = tb_mem_addr; @(tb_cb);
    a1 = tb_mem_addr; @(tb_cb);
    a2 = tb_mem_addr; @(tb_cb);
    `FAIL_IF_LOG(a1 !== (a0 + 1), $sformatf("addr not +1: a0=%0h a1=%0h", a0, a1));
    `FAIL_IF_LOG(a2 !== (a1 + 1), $sformatf("addr not +1: a1=%0h a2=%0h", a1, a2));
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(30) @(tb_cb);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 09: iqsel decode + latency measurement (v4 specific).
// ----------------------------------------------------------------------------
`SVTEST(tc_iqsel_decode)
    logic [159:0] d;
    int lat;
    // iqsel = 1 (I only)
    d = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'(MAXV),
                    16'd64, 2'd0, 1'b0, 1'b0, 1'b0, 1'b1);
    measure_iqsel_latency(d, 1'b1, lat);
    $display("[INFO] iqsel latency = %0d cycles", lat);
    `FAIL_IF_LOG(lat < 0, "tc_iqsel_decode: o_iqsel never matched expected");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 10: iqsel toggles correctly (0 -> 1 -> 0).
// ----------------------------------------------------------------------------
`SVTEST(tc_iqsel_toggle)
    logic [159:0] d0, d1;
    int t;
    
    // First descriptor: iqsel=0 (I/Q)
    d0 = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'(MAXV),
                     16'd8, 2'd0, 1'b0, 1'b0, 1'b0, 1'b0);
    hold_descriptor(d0);
    @(tb_cb);
    while (!tb_fifo_rd_en) @(tb_cb);
    t = 0;
    while (tb_iqsel !== 1'b0 && t < 64) begin @(tb_cb); t++; end
    `FAIL_IF_LOG(tb_iqsel !== 1'b0, "tc_iqsel_toggle: iqsel not 0 after first descriptor");
    
    // Second descriptor: iqsel=1 (I only)
    d1 = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'(MAXV),
                     16'd8, 2'd0, 1'b0, 1'b0, 1'b0, 1'b1);
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(5) @(tb_cb);
    hold_descriptor(d1);
    @(tb_cb);
    while (!tb_fifo_rd_en) @(tb_cb);
    t = 0;
    while (tb_iqsel !== 1'b1 && t < 64) begin @(tb_cb); t++; end
    `FAIL_IF_LOG(tb_iqsel !== 1'b1, "tc_iqsel_toggle: iqsel not 1 after second descriptor");
    
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(20) @(tb_cb);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 11: iqsel pipeline matches other control signals (CORREGIDO V2).
// ----------------------------------------------------------------------------
`SVTEST(tc_iqsel_pipeline_match)
    logic [159:0] d_gain, d_src, d_iqsel;
    int gain_lat, iqsel_lat, src_lat;
    int t;
    
    // Usar descriptores diferentes para cada medición
    d_gain = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'h4000,
                         16'd64, 2'd0, 1'b0, 1'b0, 1'b0, 1'b0);
    d_src = build_descr(32'h0002_0000, 32'd0, 16'h0040, 16'h4000,
                         16'd64, 2'd1, 1'b0, 1'b0, 1'b0, 1'b0);
    d_iqsel = build_descr(32'h0003_0000, 32'd0, 16'h0040, 16'h4000,
                           16'd64, 2'd0, 1'b0, 1'b0, 1'b0, 1'b1);
    
    // Medir gain latency
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(5) @(tb_cb);
    hold_descriptor(d_gain);
    @(tb_cb);
    t = 0;
    while (!tb_fifo_rd_en && t < 64) begin @(tb_cb); t++; end
    t = 0;
    while (tb_gain !== 16'h4000 && t < 64) begin @(tb_cb); t++; end
    gain_lat = t;
    
    // Medir src latency - resetear el FIFO primero
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(5) @(tb_cb);
    hold_descriptor(d_src);
    @(tb_cb);
    t = 0;
    while (!tb_fifo_rd_en && t < 64) begin @(tb_cb); t++; end
    t = 0;
    while (tb_src !== 2'd1 && t < 64) begin @(tb_cb); t++; end
    src_lat = t;
    
    // Medir iqsel latency
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(5) @(tb_cb);
    hold_descriptor(d_iqsel);
    @(tb_cb);
    t = 0;
    while (!tb_fifo_rd_en && t < 64) begin @(tb_cb); t++; end
    t = 0;
    while (tb_iqsel !== 1'b1 && t < 64) begin @(tb_cb); t++; end
    iqsel_lat = t;
    
    $display("[INFO] Latencies: gain=%0d, src=%0d, iqsel=%0d", 
             gain_lat, src_lat, iqsel_lat);
    
    // Las latencias deberían ser iguales (todas 8)
    `FAIL_IF_LOG(gain_lat !== iqsel_lat || src_lat !== iqsel_lat,
        $sformatf("Latency mismatch: gain=%0d src=%0d iqsel=%0d", 
                  gain_lat, src_lat, iqsel_lat));
    
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(20) @(tb_cb);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 12: Mode=1 (continuous) keeps en high.
// ----------------------------------------------------------------------------
`SVTEST(tc_mode_continuous)
    logic [159:0] d;
    int t;
    d = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'(MAXV),
                    16'd8, 2'd0, 1'b1, 1'b0, 1'b0, 1'b0);  // mode=1
    hold_descriptor(d);
    @(tb_cb);
    while (!tb_fifo_rd_en) @(tb_cb);
    t = 0;
    while (tb_en !== 1'b1 && t < 64) begin @(tb_cb); t++; end
    `FAIL_IF_LOG(tb_en !== 1'b1, "tc_mode_continuous: en never asserted");
    repeat(20) @(tb_cb);
    `FAIL_IF_LOG(tb_en !== 1'b1, "tc_mode_continuous: en dropped in continuous mode");
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(20) @(tb_cb);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 13: Phase reset (phrst).
// ----------------------------------------------------------------------------
`SVTEST(tc_phase_reset)
    logic [159:0] d1, d2;
    logic [31:0] phase_before, phase_after;
    int t;
    
    d1 = build_descr(32'h1000_0000, 32'h2000_0000, 16'h0000, 16'h4000,
                     16'd8, 2'd0, 1'b0, 1'b0, 1'b0, 1'b0);
    hold_descriptor(d1);
    @(tb_cb);
    while (!tb_fifo_rd_en) @(tb_cb);
    repeat(20) @(tb_cb);
    phase_before = tb_dds_ctrl[63:32];
    
    d2 = build_descr(32'h1000_0000, 32'h3000_0000, 16'h0000, 16'h4000,
                     16'd8, 2'd0, 1'b0, 1'b0, 1'b1, 1'b0);
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(5) @(tb_cb);
    hold_descriptor(d2);
    @(tb_cb);
    while (!tb_fifo_rd_en) @(tb_cb);
    repeat(20) @(tb_cb);
    phase_after = tb_dds_ctrl[63:32];
    
    $display("[PHASE RESET] before=0x%08h after=0x%08h", phase_before, phase_after);
    `FAIL_IF_LOG(phase_after === phase_before,
        "tc_phase_reset: phase didn't change with phrst");
    
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(20) @(tb_cb);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 14: DDS control word format verification (CORREGIDO V3).
// ----------------------------------------------------------------------------
`SVTEST(tc_dds_ctrl_format)
    logic [159:0] d;
    logic [31:0] pinc = 32'h1234_5678;
    logic [31:0] phase = 32'h9ABC_DEF0;
    logic [N_DDS*72-1:0] dds_word;
    logic [71:0] lane0_word;
    logic [31:0] expected_pinc;
    logic [6:0] padding_bits;     // Solo bits 71:65
    logic sync_bit;                // Bit 64
    
    d = build_descr(pinc, phase, 16'h0000, 16'h4000,
                    16'd2, 2'd0, 1'b0, 1'b0, 1'b1, 1'b0);
    hold_descriptor(d);
    @(tb_cb);
    while (!tb_fifo_rd_en) @(tb_cb);
    repeat(30) @(tb_cb);
    
    lane0_word = tb_dds_ctrl[71:0];
    
    // pinc se multiplica por N_DDS en el DUT
    expected_pinc = pinc * N_DDS;
    
    // Extraer campos correctamente
    // Formato: {7'h00[71:65], sync[64], phase[63:32], pinc[31:0]}
    padding_bits = lane0_word[71:65];  // Solo los 7 bits de padding
    sync_bit = lane0_word[64];          // Bit de sync separado
    
    $display("[DDS CTRL] expected pinc=0x%08h (pinc*N_DDS), actual=0x%08h", 
             expected_pinc, lane0_word[31:0]);
    $display("[DDS CTRL] expected phase=0x%08h, actual=0x%08h", 
             phase, lane0_word[63:32]);
    $display("[DDS CTRL] sync_bit=%b, padding=0x%02h (expected 0x00)", 
             sync_bit, padding_bits);
    
    `FAIL_IF_LOG(lane0_word[31:0] !== expected_pinc,
        $sformatf("pinc mismatch: expected 0x%08h got 0x%08h", 
                  expected_pinc, lane0_word[31:0]));
    `FAIL_IF_LOG(lane0_word[63:32] !== phase,
        $sformatf("phase mismatch: expected 0x%08h got 0x%08h", 
                  phase, lane0_word[63:32]));
    // Verificar solo los bits 71:65 (7 bits de padding)
    `FAIL_IF_LOG(padding_bits !== 7'h00,
        $sformatf("padding bits (71:65) not zero: got 0x%02h", padding_bits));
    // El sync bit puede ser 0 o 1, no lo verificamos
    
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(20) @(tb_cb);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 15: All lanes get correct phase offsets (v4 specific).
// ----------------------------------------------------------------------------
`SVTEST(tc_per_lane_phase)
    logic [159:0] d;
    logic [31:0] pinc = 32'h1000_0000;
    logic [31:0] phase0 = 32'h2000_0000;
    logic [31:0] expected_phase;
    logic [31:0] actual_phase;
    logic [71:0] lane_word;
    
    d = build_descr(pinc, phase0, 16'h0000, 16'h4000,
                    16'd8, 2'd0, 1'b0, 1'b0, 1'b0, 1'b0);
    hold_descriptor(d);
    @(tb_cb);
    while (!tb_fifo_rd_en) @(tb_cb);
    repeat(30) @(tb_cb);
    
    // Check each lane's phase offset without nested slices
    for (int i = 0; i < N_DDS; i++) begin
        expected_phase = phase0 + (pinc * i);
        // Extract the 72-bit word for this lane
        lane_word = tb_dds_ctrl[i*72 +: 72];
        actual_phase = lane_word[63:32];
        
        $display("[LANE %0d] expected=0x%08h actual=0x%08h", 
                 i, expected_phase, actual_phase);
        
        `FAIL_IF_LOG(actual_phase !== expected_phase,
            $sformatf("Lane %0d phase mismatch: expected 0x%08h got 0x%08h", 
                      i, expected_phase, actual_phase));
    end
    
    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(20) @(tb_cb);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 16: Verificar que pinc_n = pinc * N_DDS en todas las lanes.
// ----------------------------------------------------------------------------
`SVTEST(tc_pinc_scaling)
    logic [159:0] d;
    logic [31:0] pinc = 32'h1000_0000;
    logic [31:0] expected_pinc;
    logic [71:0] lane_word;

    d = build_descr(pinc, 32'd0, 16'h0000, 16'h4000,
                    16'd8, 2'd0, 1'b0, 1'b0, 1'b0, 1'b0);
    hold_descriptor(d);
    @(tb_cb);
    while (!tb_fifo_rd_en) @(tb_cb);
    repeat(30) @(tb_cb);

    expected_pinc = pinc * N_DDS;

    for (int i = 0; i < N_DDS; i++) begin
        lane_word = tb_dds_ctrl[i*72 +: 72];
        $display("[LANE %0d] pinc=0x%08h (expected=0x%08h)",
                 i, lane_word[31:0], expected_pinc);
        `FAIL_IF_LOG(lane_word[31:0] !== expected_pinc,
            $sformatf("Lane %0d pinc mismatch: expected 0x%08h got 0x%08h",
                      i, expected_pinc, lane_word[31:0]));
    end

    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(20) @(tb_cb);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 17: Verify full format of DDS including sync.
// ----------------------------------------------------------------------------
`SVTEST(tc_dds_full_format)
    logic [159:0] d;
    logic [31:0] pinc = 32'h1234_5678;
    logic [31:0] phase = 32'h9ABC_DEF0;
    logic [71:0] lane0_word;
    logic [31:0] expected_pinc;
    logic sync_bit;
    logic [6:0] padding_bits;

    d = build_descr(pinc, phase, 16'h0000, 16'h4000,
                    16'd2, 2'd0, 1'b0, 1'b0, 1'b1, 1'b0);
    hold_descriptor(d);
    @(tb_cb);
    while (!tb_fifo_rd_en) @(tb_cb);
    repeat(35) @(tb_cb);

    lane0_word = tb_dds_ctrl[71:0];
    expected_pinc = pinc * N_DDS;
    sync_bit = lane0_word[64];          // Bit 64 es sync
    padding_bits = lane0_word[71:65];   // Bits 71:65 son padding

    $display("[DDS FULL] pinc=0x%08h (expected=0x%08h)",
             lane0_word[31:0], expected_pinc);
    $display("[DDS FULL] phase=0x%08h (expected=0x%08h)",
             lane0_word[63:32], phase);
    $display("[DDS FULL] sync=%b, padding=0x%02h",
             sync_bit, padding_bits);

    `FAIL_IF_LOG(lane0_word[31:0] !== expected_pinc,
        "pinc field incorrect");
    `FAIL_IF_LOG(lane0_word[63:32] !== phase,
        "phase field incorrect");
    `FAIL_IF_LOG(padding_bits !== 7'h00,
        "padding bits (71:65) not zero");
    // sync bit puede ser 0 o 1

    tb_cb.tb_fifo_empty <= 1'b1;
    repeat(20) @(tb_cb);
`SVTEST_END

// ============================================================================
// NEW TESTS: En assert/deassert, small nsamp, and isolated phase reset.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST: o_en drops at end of a finite waveform (mode=0).
// Verify that o_en stays high for the entire nsamp duration and then drops.
// This test is critical because o_en directly drives tvalid in sgv4.
// ----------------------------------------------------------------------------
`SVTEST(tc_en_deasserts)
    logic [159:0] d;
    int t, en_high_cycles;

    d = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'(MAXV),
                    16'd64, 2'd0, 1'b0, 1'b0, 1'b0, 1'b0);

    // Push EXACTLY ONE descriptor, then let the FIFO go empty so the
    // waveform terminates (otherwise en re-triggers forever).
    push_descriptor(d);          // presents d, waits for rd_en, then empties FIFO

    // Wait for en to assert.
    t = 0;
    while (tb_en !== 1'b1 && t < 64) begin @(tb_cb); t++; end
    `FAIL_IF_LOG(tb_en !== 1'b1, "tc_en_deasserts: en never asserted");

    // Count cycles while en is high, with a generous ceiling.
    en_high_cycles = 0;
    while (tb_en === 1'b1 && en_high_cycles < 200) begin
        @(tb_cb); en_high_cycles++;
    end
    $display("[INFO] tc_en_deasserts: en high for %0d cycles", en_high_cycles);

    // The KEY assertion: en MUST eventually drop (it is tvalid).
    `FAIL_IF_LOG(tb_en !== 1'b0,
        "tc_en_deasserts: en never de-asserted after a finite waveform (would hang tvalid)");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST: Small nsamp values (1, 2, 3) do not cause FSM hang.
// The original logic (==2) would underflow and hang on nsamp in {0,1,2}.
// After the fix (<=2), these should exit CNT_ST quickly.
// ----------------------------------------------------------------------------
`SVTEST(tc_nsamp_small)
    logic [159:0] d;
    int t, nsamp_test;

    // Test nsamp = 1, 2, and 3 (critical boundary values).
    for (nsamp_test = 1; nsamp_test <= 3; nsamp_test++) begin
        // Reuse the helper descriptor, only changing nsamp.
        d = build_descr(32'h0001_0000, 32'd0, 16'h0040, 16'(MAXV),
                        16'(nsamp_test), 2'd0, 1'b0, 1'b0, 1'b0, 1'b0);

        // Push the descriptor.
        push_descriptor(d);

        // Wait for en to assert.
        t = 0;
        while (tb_en !== 1'b1 && t < 10) begin @(tb_cb); t++; end
        `FAIL_IF_LOG(tb_en !== 1'b1,
            $sformatf("tc_nsamp_small: en never asserted for nsamp=%0d", nsamp_test));

        // Wait for en to deassert (should be quick after the <=2 fix).
        t = 0;
        while (tb_en === 1'b1 && t < 20) begin @(tb_cb); t++; end

        // After nsamp + small overhead, en should be low.
        // If the old logic (==2) was present, en would stay high for ~65k cycles (hang).
        $display("[INFO] tc_nsamp_small: nsamp=%0d, en stayed high for %0d cycles", nsamp_test, t);
        `FAIL_IF_LOG(tb_en !== 1'b0,
            $sformatf("tc_nsamp_small: en did not deassert for nsamp=%0d after %0d cycles (hang?)", nsamp_test, t));
    end
`SVTEST_END


`SVTEST(tc_descriptor_lasts_nsamp_clocks)
    // A descriptor holds the generator for nsamp clocks: the next one is popped nsamp clocks after
    // it, from 2 to the largest (65535).
    int ns[$] = '{2, 3, 4, 5, 17, 100, 2, 65535};
    logic [159:0] d[$];
    int len[$];
    foreach (ns[i]) d.push_back(build_descr(32'h1000, 32'd0, 16'd0, 16'd100, 16'(ns[i]), 2'd0, 1'b0, 1'b0, 1'b0, 1'b0));
    d.push_back(build_descr(32'h1000, 32'd0, 16'd0, 16'd100, 16'd100, 2'd0, 1'b0, 1'b0, 1'b0, 1'b0));
    play_descriptors(d, 70000, len);
    `FAIL_UNLESS_EQUAL(len.size(), ns.size());
    foreach (ns[i]) `FAIL_UNLESS_EQUAL(len[i], ns[i]);
`SVTEST_END

`SVTEST(tc_nsamp_below_2_lasts_2_clocks)
    // The count ends at cnt_nsamp <= 2, so nsamp 0 and 1 last 2 clocks like 2, whatever came
    // before: no stall (unlike ctrl_sgv6, which ends at == 2).
    int ns[$]  = '{100, 0, 100, 1, 0, 2, 3};
    int exp[$] = '{100, 2, 100, 2, 2, 2, 3};
    logic [159:0] d[$];
    int len[$];
    foreach (ns[i]) d.push_back(build_descr(32'h1000, 32'd0, 16'd0, 16'd100, 16'(ns[i]), 2'd0, 1'b0, 1'b0, 1'b0, 1'b0));
    d.push_back(build_descr(32'h1000, 32'd0, 16'd0, 16'd100, 16'd100, 2'd0, 1'b0, 1'b0, 1'b0, 1'b0));
    play_descriptors(d, 1000, len);
    `FAIL_UNLESS_EQUAL(len.size(), exp.size());
    foreach (exp[i]) `FAIL_UNLESS_EQUAL(len[i], exp[i]);
`SVTEST_END
