// ============================================================================
// File: matched_filter_tests.sv
// Description: SVUnit test cases for matched_filter.
//   I/Q packing: I in the lower B bits, Q in the upper B bits (din_i, dout_o
//   and the weight words alike).
// ============================================================================

`SVTEST(test_reset)
    `FAIL_IF(cb.tb_dout_valid_o)
    `FAIL_IF(cb.tb_trigger_o)
`SVTEST_END

// Constant weight and sample: checks the complex multiply and the truncation
// to the upper B bits.
`SVTEST(test_weighted_multiply)
    logic [2*B-1:0] expected;
    logic [2*B-1:0] actual;
    int i;

    // I = 0x4000 (16384), Q = 0x0000.
    cb.tb_dw_addr_reg <= '0;
    cb.tb_we_reg      <= 1'b1;
    repeat(4) @(cb);
    for (i = 0; i < 8; i++) begin
        wgt_if.tx({16'h0000, 16'h4000});
    end
    cb.tb_we_reg <= 1'b0;
    repeat(5) @(cb);

    pulse_trigger();

    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i        <= {16'h0000, 16'h4000};
    repeat(6) @(cb);
    cb.tb_din_valid_i <= 1'b0;

    // ac = 0x4000*0x4000 = 0x10000000 -> top 16 bits = 0x1000 (I).
    // bd = 0, ad = 0, bc = 0 -> Q = 0x0000.
    expected = {16'h0000, 16'h1000};

    wait_for_output(actual);
    `FAIL_UNLESS_EQUAL(actual, expected)
`SVTEST_END

// trunc_shift_reg: same constant weight/sample
// as test_weighted_multiply (ac = 0x10000000), but with the shift moved off
// its default of B. Shifting by B-1 keeps one extra bit of gain (doubles I);
// by B+1 drops one (halves I) -- confirms the shift is live, not just wired
// to a fixed default.
`SVTEST(test_configurable_truncation)
    logic [2*B-1:0] actual;
    int i;

    cb.tb_dw_addr_reg <= '0;
    cb.tb_we_reg      <= 1'b1;
    repeat(4) @(cb);
    for (i = 0; i < 8; i++) begin
        wgt_if.tx({16'h0000, 16'h4000});
    end
    cb.tb_we_reg <= 1'b0;
    repeat(5) @(cb);

    cb.tb_trunc_shift_reg <= 8'(B - 1);
    repeat(2) @(cb);
    pulse_trigger();
    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i        <= {16'h0000, 16'h4000};
    repeat(6) @(cb);
    cb.tb_din_valid_i <= 1'b0;
    wait_for_output(actual);
    `FAIL_UNLESS_EQUAL(actual, {16'h0000, 16'h2000})
    repeat(10) @(cb);

    cb.tb_trunc_shift_reg <= 8'(B + 1);
    repeat(2) @(cb);
    pulse_trigger();
    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i        <= {16'h0000, 16'h4000};
    repeat(6) @(cb);
    cb.tb_din_valid_i <= 1'b0;
    wait_for_output(actual);
    `FAIL_UNLESS_EQUAL(actual, {16'h0000, 16'h0800})
`SVTEST_END

// Complex product with the I/Q packing used by the rest of QICK:
// din = 0.5 + 0.25j, weight = 0.5 - 0.5j (Q15)
// din*weight = (0.25 + 0.125) + (-0.25 + 0.125)j = 0.375 - 0.125j
// Keeping the upper B bits of the 2B-bit product scales by 1/2 (as in
// test_weighted_multiply): I = 0.1875 (0x1800), Q = -0.0625 (0xF800).
// With the upper/lower halves swapped (v1.3) this reads as -1j times the
// product: I = -0.0625, Q = -0.1875.
`SVTEST(test_complex_multiply_iq_order)
    logic [2*B-1:0] expected;
    logic [2*B-1:0] actual;
    int i;

    cb.tb_dw_addr_reg <= '0;
    cb.tb_we_reg      <= 1'b1;
    repeat(4) @(cb);
    for (i = 0; i < 8; i++) begin
        wgt_if.tx({16'hC000, 16'h4000});        // Q = -0.5, I = 0.5
    end
    cb.tb_we_reg <= 1'b0;
    repeat(5) @(cb);

    pulse_trigger();

    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i        <= {16'h2000, 16'h4000}; // Q = 0.25, I = 0.5
    repeat(6) @(cb);
    cb.tb_din_valid_i <= 1'b0;

    expected = {16'hF800, 16'h1800};            // Q = -0.0625, I = 0.1875

    wait_for_output(actual);
    `FAIL_UNLESS_EQUAL(actual, expected)
`SVTEST_END

// The first weight loaded after WE_REG goes high must land at address 0
// (the start address), not be dropped.
`SVTEST(test_weight_load_first_word)
    int k;

    load_ramp_weights(4);
    for (k = 0; k < 4; k++)
        // bram_tdp is xpm_memory_tdpram-backed: its array is XPM's internal
        // xpm_memory_base_inst.mem (was bram_tdp.ram when it was inferred).
        `FAIL_UNLESS_EQUAL(dut.bram_envelope_iq_i.u_xpm.xpm_memory_base_inst.mem[k], {16'h0000, 16'((k+1)*256)})
`SVTEST_END

// Weight alignment: the n-th sample of the window must be multiplied by
// weight n, whether din_valid_i is continuous or has gaps. Weights are a ramp
// (weight k -> I (k+1)*256), the sample is constant 0x4000, so the output I
// is (k+1)*64 for the weight k it met. v1.3 gave weight n+2 in this port and
// n+1 in the legacy IP.
`SVTEST(test_weight_alignment)
    int strides[4] = '{1, 2, 3, 8};
    logic [2*B-1:0] outs[$];
    int s, n, bad;

    load_ramp_weights(32);
    cb.tb_len_reg <= 32'd12;
    repeat(2) @(cb);

    for (s = 0; s < 4; s++) begin
        run_window(12, strides[s], outs);
        `FAIL_UNLESS_EQUAL(outs.size(), 12)
        bad = 0;
        for (n = 0; n < outs.size(); n++) begin
            if (outs[n] !== {16'h0000, 16'((n+1)*64)}) begin
                if (bad == 0)
                    $display("[ALIGN] stride %0d: sample %0d met weight %0d (dout I = %0d)",
                             strides[s], n, $signed(outs[n][B-1:0]) / 64 - 1,
                             $signed(outs[n][B-1:0]));
                bad++;
            end
        end
        `FAIL_UNLESS_EQUAL(bad, 0)
        repeat(20) @(cb);
    end
`SVTEST_END

// dout_valid_o must be high only in the cycles dout_o holds a product: with a
// constant nonzero sample and weight, dout_o is never zero while
// dout_valid_o is high (v1.3 raised dout_valid_o one cycle early, so the
// first pulse of every window carried a stale value).
`SVTEST(test_valid_marks_product)
    logic [2*B-1:0] outs[$];
    int n;

    load_ramp_weights(8);
    cb.tb_len_reg <= 32'd4;
    repeat(2) @(cb);

    run_window(4, 1, outs);
    `FAIL_UNLESS_EQUAL(outs.size(), 4)
    for (n = 0; n < outs.size(); n++)
        `FAIL_IF_LOG(outs[n] === '0, $sformatf("dout_o is 0 on valid pulse %0d", n))
`SVTEST_END

// trigger_o lags trigger_i by TOTAL_LATENCY = ENV (2) + DSP (3) + OUT (1)
// = 6 register stages -- 7 clocking-block cycles counted from (and
// including) the cycle trigger_i first appears on the bus. dout_valid_o goes
// through the same delay, so trigger_o and the first product stay together.
`SVTEST(test_trigger_latency)
    int cycles;
    int timed_out;

    cb.tb_trigger_i <= 1'b1;
    @(cb);
    cb.tb_trigger_i <= 1'b0;

    cycles = 1;
    timed_out = 0;
    while (!cb.tb_trigger_o && !timed_out) begin
        @(cb);
        cycles++;
        if (cycles > 20) timed_out = 1;
    end
    `FAIL_IF_LOG(timed_out, "test_trigger_latency: trigger_o never asserted");
    if (!timed_out) `FAIL_UNLESS_EQUAL(cycles, 7)
`SVTEST_END
