// ----------------------------------------------------------------------------
// TEST 00: Verification of static flow control policy (Constant Ready)
// The slave must never apply back-pressure. s_axis_tready must be always 1.
// ----------------------------------------------------------------------------
`SVTEST(test_tready_always_asserted)
    // We read through the clocking block of the interface
    `FAIL_UNLESS_EQUAL(axis_if.m_cb.tready, 1'b1);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 01: Capture of a single word (1-cycle latency)
// At the next cycle after asserting tvalid, dout must reflect the data.
// ----------------------------------------------------------------------------
`SVTEST(test_single_word_capture)
    axis_if.tx(16'hABCD, 1'b1); 
    
    // We need to advance the clock of our CB to see the registered data
    // because tx() ends exactly in the cycle when it is transmitted.
    @(cb); 
    
    `FAIL_UNLESS_EQUAL(cb.tb_dout, 16'hABCD);
    
    axis_if.send_bubble();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Ignore data when tvalid is low (Bubbles in the stream)
// If tvalid falls to 0, dout must persistently retain the last valid value.
// ----------------------------------------------------------------------------
`SVTEST(test_hold_value_during_bubbles)
    axis_if.tx(16'h1111); // Valid word
    
    // We generate a bubble of 4 cycles in the interface
    axis_if.send_bubble(4);
    
    @(cb);
    // dout should not have changed
    `FAIL_UNLESS_EQUAL(cb.tb_dout, 16'h1111);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Consecutive transfers Back-to-Back
// ----------------------------------------------------------------------------
`SVTEST(test_back_to_back_streaming)
    axis_if.tx(16'h1234);
    // Note: Since we are using cb.tb_dout, we need to advance the clock or use the raw signal (tb_dout)
    `FAIL_UNLESS_EQUAL(tb_dout, 16'h1234); // Using raw to avoid the extra @(cb)
    
    axis_if.tx(16'h5678);
    `FAIL_UNLESS_EQUAL(tb_dout, 16'h5678);
    
    axis_if.tx(16'h9ABC);
    `FAIL_UNLESS_EQUAL(tb_dout, 16'h9ABC);
    
    axis_if.send_bubble();
`SVTEST_END
