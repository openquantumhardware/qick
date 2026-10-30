// ============================================================================
// File: axis_kidsim_v3_tests.sv
// Description: SVUnit tests for axis_kidsim_v3. Included by *_tc00.sv.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Per-lane data routing (all lanes bypass). Each lane's input
//   sub-word must appear on its own output sub-word after TOP_LAT.
// ----------------------------------------------------------------------------
`SVTEST(tc_lane_routing)
    logic [32*L-1:0] word_in;
    logic [32*L-1:0] word_out;
    logic            last;
    // configure every lane to bypass (OUTSEL=2)
    for (int ln = 0; ln < L; ln++)
        config_lane(ln, 2, 4000, 0, 0, 32767, 0);
    // build a distinct marker per lane, packed into one AXIS word
    word_in = '0;
    for (int ln = 0; ln < L; ln++)
        word_in[ln*32 +: 32] = pack_qi(1000 + ln, 2000 + ln);
    // send one beat, then let the pipeline drain and capture the output beat
    fork
        s_axis.tx(word_in, 1'b0);            // one input beat
        begin
            m_axis.rx(word_out, last);       // first output beat
        end
    join
    for (int ln = 0; ln < L; ln++) begin
        logic [31:0] exp;
        exp = word_in[ln*32 +: 32];
        if (word_out[ln*32 +: 32] !== exp) begin
            $display("ROUTING lane %0d: exp 0x%08h got 0x%08h",
                     ln, exp, word_out[ln*32 +: 32]);
            `FAIL_IF(1);
        end
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: WE addressing — a write with ADDR=k only configures lane k. Set
//   lane 1 to OUTSEL=3 (output 0) while the others stay bypass; check only
//   lane 1 is zeroed on the output.
// ----------------------------------------------------------------------------
`SVTEST(tc_we_addressing)
    logic [32*L-1:0] word_in;
    logic [32*L-1:0] word_out;
    logic            last;
    for (int ln = 0; ln < L; ln++)
        config_lane(ln, 2, 4000, 0, 0, 32767, 0);   // all bypass
    config_lane(1, 3, 4000, 0, 0, 32767, 0);         // lane 1 -> OUTSEL=3 (zero)
    prime_dds();

    word_in = '0;
    for (int ln = 0; ln < L; ln++)
        word_in[ln*32 +: 32] = pack_qi(1000 + ln, 2000 + ln);
    fork
        s_axis.tx(word_in, 1'b0);
        m_axis.rx(word_out, last);
    join
    for (int ln = 0; ln < L; ln++) begin
        logic [31:0] exp;
        exp = (ln == 1) ? 32'h0 : word_in[ln*32 +: 32];
        if (word_out[ln*32 +: 32] !== exp) begin
            $display("WE-ADDR lane %0d: exp 0x%08h got 0x%08h",
                     ln, exp, word_out[ln*32 +: 32]);
            `FAIL_IF(1);
        end
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: m_axis valid/last follow lane 0. Send a beat with tlast=1; the
//   output beat must carry tlast=1 (from lane 0), captured by rx().
// ----------------------------------------------------------------------------
`SVTEST(tc_mvalid_lane0)
    logic [32*L-1:0] word_out;
    logic            last;
    for (int ln = 0; ln < L; ln++)
        config_lane(ln, 2, 4000, 0, 0, 32767, 0);
    fork
        s_axis.tx('0, 1'b1);                  // beat with tlast=1
        m_axis.rx(word_out, last);
    join
    // rx() only returns on a valid beat, so reaching here means m_axis.tvalid
    // asserted. Check tlast propagated from lane 0.
    `FAIL_IF(last !== 1'b1);
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 04: OUTSEL=0 pass-through, CONSTANT carrier (freq=0). Isolates the IIR /
//   cmult chain from any DDS rotation. With C0=C1=0, G=32767 the processed
//   output must recover the input within a few LSB. If this passes but TEST 05
//   fails, the fault is in the rotating-carrier (DDS/demod-remod) path.
// ----------------------------------------------------------------------------
`SVTEST(tc_passthrough_dc)
    logic [32*L-1:0] word_in;
    logic [32*L-1:0] word_out;
    logic            last;
    localparam int   TOL_LSB = 6;

    // OUTSEL=0 (processed), freq=0 (constant carrier), punct_id=0, unity IIR.
    for (int ln = 0; ln < L; ln++)
        config_lane(ln, 0, 0, 0, 0, 32767, 0);
    prime_dds();

    word_in = '0;
    for (int ln = 0; ln < L; ln++)
        word_in[ln*32 +: 32] = pack_qi(2000 + ln, 1000 + ln);

    fork
        s_axis.tx(word_in, 1'b0);            // single selected beat (frame idx 0)
        m_axis.rx(word_out, last);
    join

    `FAIL_UNLESS(compare_word_tol(word_out, word_in, TOL_LSB));
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: OUTSEL=0 pass-through, ROTATING carrier (freq=4000). Exercises the
//   full demod * remod cancellation with a non-trivial carrier phase. The
//   e^{-jw} e^{+jw}=1 identity is exact in the RTL (remod reuses the same
//   carrier sample delayed by 8), so the output must still recover the input
//   within a few LSB (now including sin/cos quantization).
// ----------------------------------------------------------------------------
`SVTEST(tc_passthrough_rf)
    logic [32*L-1:0] word_in;
    logic [32*L-1:0] word_out;
    logic            last;
    localparam int   TOL_LSB = 6;

    for (int ln = 0; ln < L; ln++)
        config_lane(ln, 0, 4000, 0, 0, 32767, 0);
    prime_dds();

    word_in = '0;
    for (int ln = 0; ln < L; ln++)
        word_in[ln*32 +: 32] = pack_qi(2000 + ln, 1000 + ln);

    fork
        s_axis.tx(word_in, 1'b0);
        m_axis.rx(word_out, last);
    join

    `FAIL_UNLESS(compare_word_tol(word_out, word_in, TOL_LSB));
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: OUTSEL=1 carrier is alive and unit-magnitude. Select the DDS carrier
//   on lane 0, send one beat, and check the output sample has magnitude near
//   full-scale: I^2 + Q^2 ~= (32767)^2. This confirms the DDS actually produces
//   a carrier on the selected path (the current TB never selects it). Uses a
//   loose magnitude band because of sin/cos quantization.
// ----------------------------------------------------------------------------
`SVTEST(tc_carrier_alive)
    logic [32*L-1:0] word_out;
    logic            last;
    logic signed [15:0] ci, cq;
    real mag2, lo, hi;

    for (int ln = 0; ln < L; ln++)
        config_lane(ln, 1, 4000, 0, 0, 32767, 0);   // OUTSEL=1 = carrier
    prime_dds();

    fork
        s_axis.tx('0, 1'b0);
        m_axis.rx(word_out, last);
    join

    ci   = word_out[0 +: 16];        // cos (I)
    cq   = word_out[16 +: 16];       // sin (Q)
    mag2 = real'(int'(ci)*int'(ci) + int'(cq)*int'(cq));
    lo   = 0.90 * 32767.0 * 32767.0; // +/-10% band on |carrier|^2
    hi   = 1.10 * 32767.0 * 32767.0;
    if (!(mag2 >= lo && mag2 <= hi)) begin
        $display("CARRIER lane0: I=%0d Q=%0d  |.|^2=%0.0f  band=[%0.0f,%0.0f]",
                ci, cq, mag2, lo, hi);
        `FAIL_IF(1);
    end
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 07: Pole ringdown -- |y1| decays by C1 per valid sample (tau = 1/(1-C1)
//   samples). The datapath advances only on valid input samples, so with a
//   contiguous stream this is also C1 per clock. Contiguous charge, then
//   contiguous zero-drive; prints the curve.
// ----------------------------------------------------------------------------
`SVTEST(tc_ringdown_pole)
    localparam int  C1_REG = 29491;               // 0.9 in Q15
    localparam real C1_R   = 29491.0/32768.0;
    localparam int  DRIVE  = 8000;
    real m0, mn, cref, expected, rel;

    force s_axis.tready = 1'b1;
    force m_axis.tready = 1'b1;

    for (int ln = 0; ln < L; ln++)
        config_lane(ln, 0, 0, 0, C1_REG, 32767, 0);   // OUTSEL=0, freq=0, high-Q

    stream_hold(0, DRIVE, 200);                        // contiguous charge to SS
    stream_hold(0, 0,      25);                        // zero drive; flush to pure decay

    @(negedge clk); m0 = y1mag_l0();
    cref = 1.0;
    for (int n = 1; n <= 10; n++) begin
        @(negedge clk);
        mn  = y1mag_l0();
        cref = cref * C1_R;                              // C1^n, iterative
        $display("  decay clk %0d: |y1|=%0.1f  ratio=%0.4f  C1^%0d=%0.4f",
                 n, mn, mn/m0, n, cref);
    end
    @(negedge clk); s_axis.tvalid <= 1'b0;

    expected = m0 * cpow(C1_R, 10);
    $display("RINGDOWN: |y1_0|=%0.1f  |y1_10|=%0.1f  expected=%0.1f", m0, mn, expected);
    `FAIL_IF(m0 < 1000.0);                             // well above the ~13 bias floor
    rel = (mn - expected) / expected;
    `FAIL_UNLESS((rel < 0.12) && (rel > -0.12));

    release s_axis.tready;
    release m_axis.tready;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: Frequency jump preserves the stored field (condition 2). The IIR
//   state (the intracavity field) changes only on valid samples: with the
//   stream stopped it must hold, and a DDS-frequency register write (the jump)
//   must not touch it. Then, driving zeros again, it must keep decaying at C1
//   per sample from where it was.
// ----------------------------------------------------------------------------
`SVTEST(tc_jump_state_preserved)
    localparam int  C1_REG = 29491;
    localparam real C1_R   = 29491.0/32768.0;
    localparam int  DRIVE  = 8000;
    localparam int  NDEC   = 10;
    real m_before, m_after, m_dec, expected, rel;
    int  nsamp;

    force s_axis.tready = 1'b1;
    force m_axis.tready = 1'b1;

    for (int ln = 0; ln < L; ln++)
        config_lane(ln, 0, 4000, 0, C1_REG, 32767, 0);    // ground freq f_g

    stream_hold(0, DRIVE, 200);                            // charge
    stream_hold(0, 0,      5);                             // start the decay
    @(negedge clk); s_axis.tvalid <= 1'b0;                 // stop the stream
    repeat(TOP_LAT + 4) @(negedge clk);                    // drain in-flight samples

    m_before = y1mag_l0();
    jump_freq(0, 8000, 0, C1_REG, 32767, 0);               // f_g -> f_e, same pole
    repeat(TOP_LAT + 4) @(negedge clk);
    m_after = y1mag_l0();
    $display("JUMP: |y1| before %0.1f, after the write %0.1f (no samples in between)",
             m_before, m_after);
    `FAIL_IF(m_before < 2000.0);
    rel = (m_after - m_before) / m_before;
    `FAIL_UNLESS((rel < 0.001) && (rel > -0.001));         // field untouched by the jump

    nsamp = 0;                                             // count the samples that enter
    fork
        begin
            stream_hold(0, 0, NDEC);                       // zero-drive samples
            @(negedge clk); s_axis.tvalid <= 1'b0;
        end
        repeat(NDEC + 3) @(posedge clk) if (s_axis.tvalid === 1'b1) nsamp++;
    join
    repeat(TOP_LAT + 4) @(negedge clk);
    m_dec    = y1mag_l0();
    expected = m_after * cpow(C1_R, nsamp);
    $display("JUMP: after %0d more samples |y1| = %0.1f, expected %0.1f", nsamp, m_dec, expected);
    rel = (m_dec - expected) / expected;
    `FAIL_UNLESS((rel < 0.05) && (rel > -0.05));           // decay continues at C1 per sample

    release s_axis.tready;
    release m_axis.tready;
`SVTEST_END
