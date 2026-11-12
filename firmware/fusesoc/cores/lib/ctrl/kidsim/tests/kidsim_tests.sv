// ============================================================================
// File: kidsim_tests.sv
// Description: SVUnit tests for the kidsim internal datapath. Included by tc00.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: OUTSEL=2 bypass — the marker appears at the output after the bypass
//   path latency = DDS_LATENCY + din_la_mux = 2 + 12 = 14.
// ----------------------------------------------------------------------------
`SVTEST(tc_outsel_bypass)
    localparam int BYPASS_LAT = 14;   // DDS_LATENCY(2) + din_la_mux(12)
    logic [31:0] marker;
    marker = pack_qi(16'sd1000, 16'sd2000);
    tb_cb.tb_outsel   <= 2'd2;
    tb_cb.tb_dds_freq <= 4000;
    tb_cb.tb_din_valid <= 1'b1;
    tb_cb.tb_din <= marker;
    @(tb_cb);
    tb_cb.tb_din <= '0;
    repeat(BYPASS_LAT) @(tb_cb);
    if (tb_dout !== marker) begin
        $display("BYPASS: exp 0x%08h got 0x%08h at lat %0d", marker, tb_dout, BYPASS_LAT);
        `FAIL_IF(1);
    end
    tb_cb.tb_din_valid <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: OUTSEL=3 -> output forced to 0.
// ----------------------------------------------------------------------------
`SVTEST(tc_outsel_off)
    tb_cb.tb_outsel   <= 2'd3;
    tb_cb.tb_dds_freq <= 4000;
    tb_cb.tb_din_valid <= 1'b1;
    tb_cb.tb_din <= pack_qi(16'sd1234, 16'sd5678);
    repeat(MAIN_LAT + 4) @(tb_cb);
    `FAIL_IF(tb_dout !== 32'h0000_0000);
    tb_cb.tb_din_valid <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: OUTSEL=0 CW pass-through — with a CONSTANT carrier and the IIR set
//   to pass-through (C0=0, C1=0, G~1.0), the demod*remod chain cancels:
//     dout = din * e^{-jw} * e^{+jw} = din   (within scale/round tolerance).
//   This proves the signal chain (prod0 -> iir -> prod1) is wired correctly
//   and that din_la aligns din with the carrier.
// ----------------------------------------------------------------------------
`SVTEST(tc_cw_passthrough)
    logic signed [15:0] din_i, din_q;
    int  err_i, err_q;
    din_i = 16'sd8000;
    din_q = 16'sd3000;
    // IIR pass-through
    tb_cb.tb_iir_c0 <= 16'sd0;
    tb_cb.tb_iir_c1 <= 16'sd0;
    tb_cb.tb_iir_g  <= 16'sd32767;   // ~1.0 in Q15
    // constant CW carrier (no ramp)
    tb_cb.tb_dds_freq  <= 16'd4000;
    tb_cb.tb_dds_bval  <= 16'd0;
    tb_cb.tb_dds_slope <= 16'd0;
    tb_cb.tb_dds_steps <= 16'd0;
    tb_cb.tb_dds_wait  <= 16'd0;
    tb_cb.tb_outsel    <= 2'd0;      // main signal path
    // drive constant din
    tb_cb.tb_din       <= pack_qi(din_q, din_i);
    tb_cb.tb_din_valid <= 1'b1;
    // let the pipeline fill and the carrier spin up well past MAIN_LAT
    repeat(MAIN_LAT + 20) @(tb_cb);
    // check several stabilized samples: dout ~= din (within tolerance)
    for (int c = 0; c < 8; c++) begin
        err_i = tb_dout_i - din_i;
        err_q = tb_dout_q - din_q;
        if (err_i < 0) err_i = -err_i;
        if (err_q < 0) err_q = -err_q;
        // tolerance: G~0.99997 + trunc + cmult round + sine quant. ~ a few %.
        if (!(err_i < 400 && err_q < 400)) begin
            $display("CW MISMATCH cyc=%0d: din=(%0d,%0d) dout=(%0d,%0d) err=(%0d,%0d)",
                     c, din_i, din_q, tb_dout_i, tb_dout_q, err_i, err_q);
            `FAIL_IF(1);
        end
        @(tb_cb);
    end
    tb_cb.tb_din_valid <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: OUTSEL=0 CHIRP end-to-end with a TIME-VARYING input (THE FIX).
//   A constant din cannot test din_la (all samples equal). Here din follows a
//   known slow ramp so each sample is distinct. With din_la = DDS_LATENCY the
//   input sample is aligned with the carrier instant, so demod*remod still
//   reconstructs din(t) throughout the chirp:  dout(t) ~= din(t - LAT).
//   We reconstruct the expected output by replaying the same din stream delayed
//   by MAIN_LAT and comparing (within numerical tolerance).
// ----------------------------------------------------------------------------
`SVTEST(tc_chirp_e2e_varying)
    localparam int NSAMP = 160;
    logic signed [15:0] din_i_q [0:NSAMP-1];   // expected I per input index
    logic signed [15:0] din_q_q [0:NSAMP-1];   // expected Q per input index
    int  wr_idx, rd_idx;
    int  err_i, err_q, worst;

    // IIR pass-through.
    tb_cb.tb_iir_c0 <= 16'sd0;
    tb_cb.tb_iir_c1 <= 16'sd0;
    tb_cb.tb_iir_g  <= 16'sd32767;
    // chirp.
    tb_cb.tb_dds_freq  <= 16'd4000;
    tb_cb.tb_dds_bval  <= 16'd1200;
    tb_cb.tb_dds_slope <= 16'd40;
    tb_cb.tb_dds_steps <= 16'd40;
    tb_cb.tb_dds_wait  <= 16'd2;
    tb_cb.tb_outsel    <= 2'd0;
    tb_cb.tb_din_valid <= 1'b1;

    worst = 0;
    wr_idx = 0;
    rd_idx = 0;

    // Fire the chirp a few cycles after starting the stream.
    fork
        // ---- driver: push a time-varying din (slow triangle-ish ramp) ----
        begin
            for (int k = 0; k < NSAMP; k++) begin
                // distinct, bounded, time-varying I/Q
                din_i_q[k] = 16'sd2000 + (k * 60);           // rising I
                din_q_q[k] = 16'sd6000 - (k * 30);           // falling Q
                tb_cb.tb_din <= pack_qi(din_q_q[k], din_i_q[k]);
                if (k == 15) tb_cb.tb_trigger <= 1'b1;       // fire chirp mid-stream
                @(tb_cb);
                if (k == 15) tb_cb.tb_trigger <= 1'b0;
            end
        end
        // ---- checker: after MAIN_LAT, output must replay din(t - MAIN_LAT) ----
        begin
            // wait for the first valid output that corresponds to input index 0
            repeat(MAIN_LAT) @(tb_cb);
            for (int k = 0; k < NSAMP - MAIN_LAT; k++) begin
                @(tb_cb);
                err_i = tb_dout_i - din_i_q[k];
                err_q = tb_dout_q - din_q_q[k];
                if (err_i < 0) err_i = -err_i;
                if (err_q < 0) err_q = -err_q;
                if (err_i > worst) worst = err_i;
                if (err_q > worst) worst = err_q;
                // If din_la is misaligned, the chirp demodulates the wrong
                // sample and this error blows up.
                if (!(err_i < 50 && err_q < 50)) begin
                    $display("CHIRP-VAR MISMATCH k=%0d: exp=(%0d,%0d) got=(%0d,%0d) err=(%0d,%0d)",
                             k, din_i_q[k], din_q_q[k], tb_dout_i, tb_dout_q, err_i, err_q);
                    `FAIL_IF(1);
                end
            end
        end
    join
    $display("CHIRP-VAR worst |err| = %0d (small => din aligned with carrier)", worst);
    tb_cb.tb_din_valid <= 1'b0;
`SVTEST_END