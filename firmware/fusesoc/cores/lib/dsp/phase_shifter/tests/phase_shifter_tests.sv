// ============================================================================
// File: phase_shifter_tests.sv
// Description: SVUnit test cases for phase_shifter.
//   Validates basic rotations, latency mapping, saturation, and pipelining.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Reset / idle — outputs stay 0 out of reset.
// ----------------------------------------------------------------------------
`SVTEST(tc_idle_zero)
    repeat(10) @(tb_cb);
    `FAIL_IF(tb_i_out !== '0);
    `FAIL_IF(tb_q_out !== '0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Latency check — single pulse takes exactly LATENCY cycles.
// ----------------------------------------------------------------------------
`SVTEST(tc_latency_check)
    iq_t exp;
    tb_cb.tb_i_in  <= 10000;
    tb_cb.tb_q_in  <= -5000;
    tb_cb.tb_phase <= '0; // 0 degrees
    exp = golden_model(10000, -5000, 0);
    
    @(tb_cb);
    tb_cb.tb_i_in  <= '0;
    tb_cb.tb_q_in  <= '0;

    // Check pipeline cycles before output is ready (should be old/reset data)
    for (int i = 1; i < LATENCY; i++) begin
        `FAIL_IF(tb_i_out === exp.i); // Hasn't arrived yet
        @(tb_cb);
    end

    // At exact LATENCY cycle, data should emerge
    `FAIL_IF(tb_i_out !== exp.i);
    `FAIL_IF(tb_q_out !== exp.q);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: 0 degrees phase rotation (Passthrough roughly equal to input)
// ----------------------------------------------------------------------------
`SVTEST(tc_phase_0)
    tb_cb.tb_i_in  <= 15000;
    tb_cb.tb_q_in  <= -15000;
    tb_cb.tb_phase <= 16'h0000; // 0 degrees
    
    repeat(LATENCY + 1) @(tb_cb);
    
    // Golden model checks exact bit-level matching, but it should be very close to input
    `FAIL_IF(tb_i_out !== golden_model(15000, -15000, 0).i);
    `FAIL_IF(tb_q_out !== golden_model(15000, -15000, 0).q);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: 90 degrees phase rotation (I_out = -Q_in, Q_out = I_in)
// ----------------------------------------------------------------------------
`SVTEST(tc_phase_90)
    tb_cb.tb_i_in  <= 10000;
    tb_cb.tb_q_in  <= 5000;
    tb_cb.tb_phase <= 16'h4000; // 16384 = pi/2
    
    repeat(LATENCY + 1) @(tb_cb);
    
    `FAIL_IF(tb_i_out !== golden_model(10000, 5000, 16'h4000).i);
    `FAIL_IF(tb_q_out !== golden_model(10000, 5000, 16'h4000).q);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: 180 degrees phase rotation (I_out = -I_in, Q_out = -Q_in)
// ----------------------------------------------------------------------------
`SVTEST(tc_phase_180)
    tb_cb.tb_i_in  <= 12000;
    tb_cb.tb_q_in  <= -8000;
    tb_cb.tb_phase <= 16'h8000; // 32768 = pi
    
    repeat(LATENCY + 1) @(tb_cb);
    
    `FAIL_IF(tb_i_out !== golden_model(12000, -8000, 16'h8000).i);
    `FAIL_IF(tb_q_out !== golden_model(12000, -8000, 16'h8000).q);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: Saturation limits (Force mathematical overflow to trigger clamps)
// ----------------------------------------------------------------------------
`SVTEST(tc_saturation)
    // Driving max values at ~45 degrees (both I and Q project positively,
    // creating a value ~ 1.414x greater than MAXV, triggering saturation)
    tb_cb.tb_i_in  <= 32767;  // MAXV
    tb_cb.tb_q_in  <= -32768; // MINV
    tb_cb.tb_phase <= 16'h2000; // ~45 deg
    
    repeat(LATENCY + 1) @(tb_cb);
    
    `FAIL_IF(tb_i_out !== 32767); // Should be explicitly clamped to +32767
    
    // Test negative saturation
    tb_cb.tb_i_in  <= -32768; // MINV
    tb_cb.tb_q_in  <= 32767;  // MAXV
    tb_cb.tb_phase <= 16'h2000; // ~45 deg
    
    repeat(LATENCY + 1) @(tb_cb);
    
    `FAIL_IF(tb_i_out !== -32768); // Should be explicitly clamped to -32768
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: Random pipelined streaming.
//   Feeds continuous random data for 500 cycles without gaps to ensure pipeline
//   registers do not corrupt neighboring data.
// ----------------------------------------------------------------------------
`SVTEST(tc_streaming_random)
    test_stream(500);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: Every ROM entry.
//   Sweeps the 2048 phase addresses, each with a cos probe and a sin probe,
//   against a reference table built outside the RTL (round(32767*cos/sin)).
//   Before this the TB overwrote the DUT's ROM with its own, so the table in
//   phase_shifter.sv was never checked in simulation.
// ----------------------------------------------------------------------------
`SVTEST(tc_rom_sweep)
    test_rom_sweep();
`SVTEST_END
