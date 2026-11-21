// ============================================================================
// File: pfb_ddsprod_tests.sv
// Description: SVUnit test cases for pfb_ddsprod. Included by
//              pfb_ddsprod_tc00.sv.
// ============================================================================

`SVTEST(tc_tone_at_the_dds_frequency_comes_out_as_dc)
    // The DDS produces exp(-j*(poff + pinc*n)) per input sample n (Negative
    // Sine). An input tone A*exp(j*2*pi*f*n) with pinc = f*2^32 comes out as
    // a constant of magnitude ~A (the DDS is full scale, bits [30:15] keep
    // A*32767/2^15).
    real f = 0.0731, amp = 6000.0, ph = 0.0;
    real mi = 0.0, mq = 0.0, dev = 0.0;
    int  n0;
    @(posedge aclk);
    pinc <= 32'($rtoi(f * 4294967296.0));
    poff <= 32'h1234_5678;
    repeat (40) @(posedge aclk);        // let the registers settle
    for (int n = 0; n < 3000; n++) begin
        @(posedge aclk);
        s_tvalid <= 1'b1;
        s_tdata  <= {16'($rtoi(amp * $sin(ph))), 16'($rtoi(amp * $cos(ph)))};
        ph += 2.0 * PI * f;
    end
    @(posedge aclk);
    s_tvalid <= 1'b0;
    repeat (60) @(posedge aclk);
    n0 = 100;                           // skip the pipeline fill
    for (int n = n0; n < o_i.size(); n++) begin mi += o_i[n]; mq += o_q[n]; end
    mi /= (o_i.size() - n0); mq /= (o_q.size() - n0);
    for (int n = n0; n < o_i.size(); n++)
        dev = (($sqrt((o_i[n] - mi) ** 2 + (o_q[n] - mq) ** 2)) > dev) ? $sqrt((o_i[n] - mi) ** 2 + (o_q[n] - mq) ** 2) : dev;
    `FAIL_UNLESS(o_i.size() > 2900)
    `FAIL_UNLESS($sqrt(mi * mi + mq * mq) > 0.98 * amp && $sqrt(mi * mi + mq * mq) < 1.01 * amp)
    `FAIL_UNLESS(dev < 4.0)
    `FAIL_UNLESS_EQUAL(mism, 0)
`SVTEST_END

`SVTEST(tc_random_matches_legacy)
    // Random data, random valid gaps, pinc/poff changing now and then.
    for (int n = 0; n < 20000; n++) begin
        @(posedge aclk);
        s_tvalid <= ($urandom_range(3) != 0);
        s_tdata  <= $urandom;
        if ($urandom_range(499) == 0) pinc <= $urandom;
        if ($urandom_range(499) == 0) poff <= $urandom;
    end
    repeat (60) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS(n_valid > 14000)
`SVTEST_END
