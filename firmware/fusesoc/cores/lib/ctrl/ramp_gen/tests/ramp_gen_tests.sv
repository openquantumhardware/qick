// ============================================================================
// File: ramp_gen_tests.sv
// Description: SVUnit test cases for ramp_gen. Included by ramp_gen_tc00.sv.
//   Timing: after pulse_trigger() there is one cycle with o_y=0 (INIT->CNT
//   transition); then y(0)=B appears. So each test does ONE @(tb_cb) after
//   pulse_trigger() before checking y(0).
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Reset / idle — before any trigger the output is 0 (INIT state).
// ----------------------------------------------------------------------------
`SVTEST(tc_idle_zero)
    tb_cb.tb_en <= 1'b1;
    repeat(5) @(tb_cb);
    `FAIL_IF(tb_y !== '0);
    tb_cb.tb_en <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Basic ramp, W=0 (one step per cycle), no saturation.
//   y(n) = B - n*M for n in [0, N], checked step-by-step.
// ----------------------------------------------------------------------------
`SVTEST(tc_basic_ramp_w0)
    longint b = 1000, m = 100;
    int     n = 8;
    longint exp;
    set_params(b, m, n, 0);
    tb_cb.tb_en <= 1'b1;
    pulse_trigger();
    @(tb_cb);                      // skip the INIT->CNT cycle (o_y=0); next is y(0)=B
    for (int nn = 0; nn <= n; nn++) begin
        exp = golden_y(b, m, nn);
        if (signed'(tb_y) !== signed'(exp[DATA_W-1:0])) begin
            $display("W0 MISMATCH n=%0d: exp %0d got %0d", nn, exp, signed'(tb_y));
            `FAIL_IF(1);
        end
        @(tb_cb);
    end
    tb_cb.tb_en <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: WAIT=1 timing — one WAIT cycle per step; value holds an extra cycle.
// ----------------------------------------------------------------------------
`SVTEST(tc_wait_one)
    longint b = 2000, m = 50;
    int     n = 4;
    longint exp;
    set_params(b, m, n, 1);
    tb_cb.tb_en <= 1'b1;
    pulse_trigger();
    @(tb_cb);
    for (int nn = 0; nn <= n; nn++) begin
        exp = golden_y(b, m, nn);
        if (signed'(tb_y) !== signed'(exp[DATA_W-1:0])) begin
            $display("W1 step MISMATCH n=%0d: exp %0d got %0d", nn, exp, signed'(tb_y));
            `FAIL_IF(1);
        end
        @(tb_cb);
        if (nn < n) begin
            // WAIT state: output must hold the same value one extra cycle.
            if (signed'(tb_y) !== signed'(exp[DATA_W-1:0])) begin
                $display("W1 hold MISMATCH n=%0d: exp %0d got %0d", nn, exp, signed'(tb_y));
                `FAIL_IF(1);
            end
            @(tb_cb);
        end
    end
    tb_cb.tb_en <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: ms saturation, positive — n*M overflows high and clamps.
//   M=10000, N=6 -> ms would reach 60000 > 32767, clamps to 32767.
// ----------------------------------------------------------------------------
`SVTEST(tc_ms_sat_pos)
    longint b = 0, m = 10000;
    int     n = 6;
    longint exp;
    set_params(b, m, n, 0);
    tb_cb.tb_en <= 1'b1;
    pulse_trigger();
    @(tb_cb);
    for (int nn = 0; nn <= n; nn++) begin
        exp = golden_y(b, m, nn);
        if (signed'(tb_y) !== signed'(exp[DATA_W-1:0])) begin
            $display("MS+SAT MISMATCH n=%0d: exp %0d got %0d", nn, exp, signed'(tb_y));
            `FAIL_IF(1);
        end
        @(tb_cb);
    end
    tb_cb.tb_en <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: ms saturation, negative — n*M overflows low and clamps.
// ----------------------------------------------------------------------------
`SVTEST(tc_ms_sat_neg)
    longint b = 0, m = -10000;
    int     n = 6;
    longint exp;
    set_params(b, m, n, 0);
    tb_cb.tb_en <= 1'b1;
    pulse_trigger();
    @(tb_cb);
    for (int nn = 0; nn <= n; nn++) begin
        exp = golden_y(b, m, nn);
        if (signed'(tb_y) !== signed'(exp[DATA_W-1:0])) begin
            $display("MS-SAT MISMATCH n=%0d: exp %0d got %0d", nn, exp, signed'(tb_y));
            `FAIL_IF(1);
        end
        @(tb_cb);
    end
    tb_cb.tb_en <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: bs saturation — B - ms overflows even when ms itself does not.
//   B=30000, M=-4000, N=3 -> ms(3)=-12000 (no sat), B-ms=42000 -> clamps.
// ----------------------------------------------------------------------------
`SVTEST(tc_bs_sat)
    longint b = 30000, m = -4000;
    int     n = 3;
    longint exp;
    set_params(b, m, n, 0);
    tb_cb.tb_en <= 1'b1;
    pulse_trigger();
    @(tb_cb);
    for (int nn = 0; nn <= n; nn++) begin
        exp = golden_y(b, m, nn);
        if (signed'(tb_y) !== signed'(exp[DATA_W-1:0])) begin
            $display("BS-SAT MISMATCH n=%0d: exp %0d got %0d", nn, exp, signed'(tb_y));
            `FAIL_IF(1);
        end
        @(tb_cb);
    end
    tb_cb.tb_en <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: Enable gating — with en=0 the ramp does not advance (value holds).
//   Note: the hold-check is only meaningful for n < N. At n==N the ramp has
//   completed and the output legitimately returns to 0 (END), so we don't
//   assert a hold on the final sample.
// ----------------------------------------------------------------------------
`SVTEST(tc_enable_gating)
    longint b = 500, m = 25;
    int     n = 5;
    longint exp;
    set_params(b, m, n, 0);
    tb_cb.tb_en <= 1'b1;
    pulse_trigger();
    @(tb_cb);
    for (int nn = 0; nn <= n; nn++) begin
        exp = golden_y(b, m, nn);
        if (signed'(tb_y) !== signed'(exp[DATA_W-1:0])) begin
            $display("GATE step MISMATCH n=%0d: exp %0d got %0d", nn, exp, signed'(tb_y));
            `FAIL_IF(1);
        end
        if (nn < n) begin
            // pause: en=0 for a few cycles, value must not change
            // (only meaningful while the ramp is still running, i.e. n < N).
            tb_cb.tb_en <= 1'b0;
            repeat(3) begin
                @(tb_cb);
                if (signed'(tb_y) !== signed'(exp[DATA_W-1:0])) begin
                    $display("GATE hold MISMATCH n=%0d: exp %0d got %0d", nn, exp, signed'(tb_y));
                    `FAIL_IF(1);
                end
            end
            // resume for the next step
            tb_cb.tb_en <= 1'b1;
            @(tb_cb);
        end
    end
    tb_cb.tb_en <= 1'b0;
`SVTEST_END
// ----------------------------------------------------------------------------
// TEST 08: Retrigger — run a ramp to END, verify it returns to 0, then a new
//   trigger starts a fresh ramp with no residue from the previous run.
// ----------------------------------------------------------------------------
`SVTEST(tc_retrigger)
    longint b0 = 1000, m0 = 100;
    longint b1 = -800, m1 = -60;
    int     n0 = 4, n1 = 5;
    longint exp;

    // --- first ramp ---
    set_params(b0, m0, n0, 0);
    tb_cb.tb_en <= 1'b1;
    pulse_trigger();
    @(tb_cb);
    for (int nn = 0; nn <= n0; nn++) begin
        exp = golden_y(b0, m0, nn);
        if (signed'(tb_y) !== signed'(exp[DATA_W-1:0])) begin
            $display("RT r0 MISMATCH n=%0d: exp %0d got %0d", nn, exp, signed'(tb_y));
            `FAIL_IF(1);
        end
        @(tb_cb);
    end
    // after END the output must be 0
    repeat(3) @(tb_cb);
    `FAIL_IF(tb_y !== '0);

    // --- second ramp, different params ---
    set_params(b1, m1, n1, 0);
    pulse_trigger();
    @(tb_cb);
    for (int nn = 0; nn <= n1; nn++) begin
        exp = golden_y(b1, m1, nn);
        if (signed'(tb_y) !== signed'(exp[DATA_W-1:0])) begin
            $display("RT r1 MISMATCH n=%0d: exp %0d got %0d", nn, exp, signed'(tb_y));
            `FAIL_IF(1);
        end
        @(tb_cb);
    end
    tb_cb.tb_en <= 1'b0;
`SVTEST_END