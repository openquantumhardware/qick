// ============================================================================
// File: dds_phase_ctrl_tests.sv
// Description: SVUnit tests for dds_phase_ctrl. Included by *_tc00.sv.
//   LAT = 5 cycles from pulse_trigger() to pinc(0) (cdc_bit_sync 2 + ramp_gen
//   + pipeline 2), calibrated via trace.
// ============================================================================


// ----------------------------------------------------------------------------
// TEST 01: Idle — before any trigger, pinc == FREQ_REG (mod_out = 0).
// ----------------------------------------------------------------------------
`SVTEST(tc_idle_base_freq)
    longint freq = 12345;
    set_params(freq, 0, 0, 0, 0);
    tb_cb.tb_din_valid <= 1'b1;
    repeat(8) @(tb_cb);
    `FAIL_IF(tb_dout_valid !== 1'b1);
    `FAIL_IF(tb_dout       !== {16'b0, freq[15:0]});
    tb_cb.tb_din_valid <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Basic chirp, W=0 — pinc(n) = FREQ_REG - ramp(n) for n in [0, N].
// ----------------------------------------------------------------------------
`SVTEST(tc_basic_chirp_w0)
    longint freq = 20000, b = 1000, m = 100;
    int     n = 6;
    logic [31:0] exp;
    set_params(freq, b, m, n, 0);
    tb_cb.tb_din_valid <= 1'b1;
    pulse_trigger();
    repeat(LAT) @(tb_cb);
    for (int nn = 0; nn <= n; nn++) begin
        exp = golden_dout(freq, b, m, nn);
        if (tb_dout !== exp) begin
            $display("CHIRP MISMATCH n=%0d: exp 0x%08h got 0x%08h", nn, exp, tb_dout);
            `FAIL_IF(1);
        end
        `FAIL_IF(tb_dout_valid !== 1'b1);
        @(tb_cb);
    end
    tb_cb.tb_din_valid <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Bubbles / continuity — with gaps in din_valid the chirp must NOT
//   jump when valid resumes. We wait until the chirp reaches the output (first
//   pinc != FREQ_REG), then check the sequence of VALID beats matches the
//   golden ramp in order, regardless of bubble cycles between them.
// ----------------------------------------------------------------------------
`SVTEST(tc_bubbles_continuity)
    longint freq = 20000, b = 1000, m = 100;
    int     n = 6;
    int     nn;
    logic [31:0] exp;
    logic [31:0] base;
    logic        started;
    set_params(freq, b, m, n, 0);
    base = {16'b0, freq[15:0]};

    tb_cb.tb_din_valid <= 1'b0;
    pulse_trigger();

    nn      = 0;
    started = 1'b0;
    for (int c = 0; c < 300 && nn <= n; c++) begin
        // 2 on, 1 off -> create bubbles
        tb_cb.tb_din_valid <= (c % 3 != 2);
        @(tb_cb);
        if (tb_dout_valid === 1'b1) begin
            // Wait for the chirp to actually reach the output (leave idle base).
            if (!started) begin
                if (tb_dout !== base) started = 1'b1;
            end
            if (started) begin
                exp = golden_dout(freq, b, m, nn);
                if (tb_dout !== exp) begin
                    $display("BUBBLE MISMATCH beat %0d: exp 0x%08h got 0x%08h", nn, exp, tb_dout);
                    `FAIL_IF(1);
                end
                nn++;
            end
        end
    end
    `FAIL_IF(nn !== n + 1);   // all N+1 chirp samples emitted, in order, no jumps
    tb_cb.tb_din_valid <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: Return to base — after the chirp completes, pinc settles back to
//   FREQ_REG (ramp -> 0).
// ----------------------------------------------------------------------------
`SVTEST(tc_return_to_base)
    longint freq = 20000, b = 1000, m = 100;
    int     n = 4;
    set_params(freq, b, m, n, 0);
    tb_cb.tb_din_valid <= 1'b1;
    pulse_trigger();
    repeat(LAT + n + 6) @(tb_cb);
    `FAIL_IF(tb_dout !== {16'b0, freq[15:0]});
    tb_cb.tb_din_valid <= 1'b0;
`SVTEST_END