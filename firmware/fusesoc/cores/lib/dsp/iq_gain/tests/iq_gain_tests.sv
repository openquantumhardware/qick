// ============================================================================
// File: iq_gain_tests.sv
// Description: SVUnit test cases for iq_gain.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Reset / Idle
// ----------------------------------------------------------------------------
`SVTEST(tc_idle_zero)
    repeat(10) @(tb_cb);
    `FAIL_IF(tb_i_out !== '0);
    `FAIL_IF(tb_q_out !== '0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Latency check
// ----------------------------------------------------------------------------
`SVTEST(tc_latency_check)
    iq_t exp;
    tb_cb.tb_i_in   <= 16'sd1000;
    tb_cb.tb_q_in   <= 16'sd2000;
    tb_cb.tb_gain_i <= GAIN_UNITY; // Use the unity gain 0x7FFF
    tb_cb.tb_gain_q <= GAIN_UNITY;
    
    exp = golden_model(16'sd1000, 16'sd2000, GAIN_UNITY, GAIN_UNITY);

    @(tb_cb);
    tb_cb.tb_i_in   <= '0;
    tb_cb.tb_q_in   <= '0;

    // Verify that it doesn't arrive too early
    for (int i = 1; i < LATENCY + 1; i++) begin
        `FAIL_IF(tb_cb.tb_i_out === exp.i); 
        @(tb_cb);
    end
    
    // Exact latency
    `FAIL_IF(tb_cb.tb_i_out !== exp.i);
    `FAIL_IF(tb_cb.tb_q_out !== exp.q);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Unity Gain (Passthrough)
// ----------------------------------------------------------------------------
`SVTEST(tc_unity_gain)
    iq_t exp;
    tb_cb.tb_i_in   <= 16'sd12345; 
    tb_cb.tb_q_in   <= -16'sd15000;
    tb_cb.tb_gain_i <= GAIN_UNITY;
    tb_cb.tb_gain_q <= GAIN_UNITY;
    
    // Left the golden model define the exact value expected after rounding
    exp = golden_model(16'sd12345, -16'sd15000, GAIN_UNITY, GAIN_UNITY);

    repeat(LATENCY + 1) @(tb_cb);

    `FAIL_IF(tb_cb.tb_i_out !== exp.i);
    `FAIL_IF(tb_cb.tb_q_out !== exp.q);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: Mute (Gain = 0)
// ----------------------------------------------------------------------------
`SVTEST(tc_mute)
    tb_cb.tb_i_in   <= 16'sd32000;
    tb_cb.tb_q_in   <= -16'sd32000;
    tb_cb.tb_gain_i <= '0;
    tb_cb.tb_gain_q <= '0;

    repeat(LATENCY + 1) @(tb_cb);

    `FAIL_IF(tb_cb.tb_i_out !== '0);
    `FAIL_IF(tb_cb.tb_q_out !== '0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: Positive Saturation
// ----------------------------------------------------------------------------
`SVTEST(tc_sat_pos)
    iq_t exp;
    // In fixed-point fractional (Q1.15) the only way to saturate at the top
    // is to multiply two maximum negative numbers (-1.0 x -1.0)
    tb_cb.tb_i_in   <= MINV; // -32768
    tb_cb.tb_q_in   <= MINV; // -32768
    tb_cb.tb_gain_i <= MINV; // -1.0
    tb_cb.tb_gain_q <= MINV; // -1.0
    
    exp = golden_model(MINV, MINV, MINV, MINV);

    repeat(LATENCY + 1) @(tb_cb);

    `FAIL_IF(tb_cb.tb_i_out !== MAXV); // Should be limited to +32767
    `FAIL_IF(tb_cb.tb_q_out !== MAXV);
    `FAIL_IF(tb_cb.tb_i_out !== exp.i); // Double validation with the model
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: Negative Saturation / Bound Check
// ----------------------------------------------------------------------------
`SVTEST(tc_sat_neg)
    iq_t exp;
    // We check the lower limit by multiplying a maximum positive number by -1.0
    tb_cb.tb_i_in   <= MAXV; // +32767
    tb_cb.tb_q_in   <= MAXV; // +32767
    tb_cb.tb_gain_i <= MINV; // -1.0
    tb_cb.tb_gain_q <= MINV; // -1.0
    
    exp = golden_model(MAXV, MAXV, MINV, MINV);

    repeat(LATENCY + 1) @(tb_cb);

    `FAIL_IF(tb_cb.tb_i_out !== exp.i);
    `FAIL_IF(tb_cb.tb_q_out !== exp.q);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: Random Streaming
// ----------------------------------------------------------------------------
`SVTEST(tc_streaming_random)
    test_stream(1000);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: Integer gain (GAIN_SHIFT = GW-1): exact products and both clamps.
// ----------------------------------------------------------------------------
`SVTEST(tc_integer_gain)
    iq_t exp;
    // exact product, no scaling, no rounding
    tb_cb.tb_i_in   <= 16'sd3;
    tb_cb.tb_q_in   <= -16'sd7;
    tb_cb.tb_gain_i <= 16'sd5;
    tb_cb.tb_gain_q <= 16'sd9;
    repeat(LATENCY + 1) @(tb_cb);
    `FAIL_IF(tb_cb.tb_i_out_int !== 16'sd15);
    `FAIL_IF(tb_cb.tb_q_out_int !== -16'sd63);

    // 1000 * 100 = 100000 > MAXV: positive clamp (I). -1000 * 100: negative clamp (Q).
    tb_cb.tb_i_in   <= 16'sd1000;
    tb_cb.tb_q_in   <= -16'sd1000;
    tb_cb.tb_gain_i <= 16'sd100;
    tb_cb.tb_gain_q <= 16'sd100;
    exp = golden_model_int(16'sd1000, -16'sd1000, 16'sd100, 16'sd100);
    repeat(LATENCY + 1) @(tb_cb);
    `FAIL_IF(tb_cb.tb_i_out_int !== MAXV);
    `FAIL_IF(tb_cb.tb_q_out_int !== MINV);
    `FAIL_IF(tb_cb.tb_i_out_int !== exp.i);
    `FAIL_IF(tb_cb.tb_q_out_int !== exp.q);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 09: Integer gain, random streaming (inside and beyond int16, both signs).
// ----------------------------------------------------------------------------
`SVTEST(tc_integer_gain_random)
    test_stream_int(1000);
`SVTEST_END
