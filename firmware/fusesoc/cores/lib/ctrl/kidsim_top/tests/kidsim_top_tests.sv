// ============================================================================
// File: kidsim_top_tests.sv
// Description: SVUnit tests for kidsim_top. Included by kidsim_top_tc00.sv.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: WE latch — before a WE, config stays at defaults (OUTSEL=2). After
//   a WE with OUTSEL=2, a marker bypasses to the output at TOP_LAT.
// ----------------------------------------------------------------------------
`SVTEST(tc_bypass_latency)
    logic [31:0] marker;
    marker = pack_qi(16'sd1234, 16'sd5678);
    write_config(2, 0, 4000, 0, 0, 32767);
    tb_cb.tb_din_valid <= 1'b1;
    tb_cb.tb_din <= marker;
    @(tb_cb);
    tb_cb.tb_din <= '0;
    repeat(TOP_LAT) @(tb_cb);
    if (tb_dout !== marker) begin
        $display("BYPASS: exp 0x%08h got 0x%08h at lat %0d", marker, tb_dout, TOP_LAT);
        `FAIL_IF(1);
    end
    tb_cb.tb_din_valid <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Default before WE — after reset, OUTSEL defaults to 2 (bypass), so
//   a marker still bypasses even without any configuration write.
// ----------------------------------------------------------------------------
`SVTEST(tc_default_bypass)
    logic [31:0] marker;
    marker = pack_qi(16'sd0777, 16'sd0333);
    // NO write_config -> defaults (outsel=2)
    tb_cb.tb_din_valid <= 1'b1;
    tb_cb.tb_din <= marker;
    @(tb_cb);
    tb_cb.tb_din <= '0;
    repeat(TOP_LAT) @(tb_cb);
    `FAIL_IF(tb_dout !== marker);
    tb_cb.tb_din_valid <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST: Frame streaming — a full frame streams through and comes out at the
//   output, valid/last aligned to the data (skew=0). With OUTSEL=0, punct
//   selecting one sample, IIR pass-through and CW carrier, every output sample
//   (processed or bypassed) matches its input within tolerance, and last
//   asserts on the final sample.
// ----------------------------------------------------------------------------
`SVTEST(tc_frame_streaming)
    localparam int FLEN = 6;
    localparam int BASE = 3000;
    logic [31:0] exp_frame [0:FLEN-1];
    int  k;
    // config: OUTSEL=0 (main), punct selects idx 2, CW carrier, IIR passthrough
    write_config(0, 2, 4000, 0, 0, 32767);
    for (int j = 0; j < FLEN; j++)
        exp_frame[j] = pack_qi(BASE + j, BASE + j + 100);

    k = 0;
    fork
        // driver
        send_frame(FLEN, BASE);
        // checker: sample the output only when dout_valid is high (skew=0 now).
        begin
            int exp_i, exp_q, err_i, err_q;
            for (int c = 0; c < TOP_LAT + FLEN + 12 && k < FLEN; c++) begin
                @(tb_cb);
                if (tb_dout_valid === 1'b1) begin
                    exp_i = signed'(exp_frame[k][15:0]);
                    exp_q = signed'(exp_frame[k][31:16]);
                    err_i = tb_dout_i - exp_i; if (err_i < 0) err_i = -err_i;
                    err_q = tb_dout_q - exp_q; if (err_q < 0) err_q = -err_q;
                    if (!(err_i < 50 && err_q < 50)) begin
                        $display("FRAME MISMATCH k=%0d: exp=(%0d,%0d) got=(%0d,%0d)",
                                 k, exp_i, exp_q, tb_dout_i, tb_dout_q);
                        `FAIL_IF(1);
                    end
                    // last must assert on the final sample of the frame
                    if (k == FLEN-1) begin
                        if (tb_dout_last !== 1'b1) begin
                            $display("FRAME last not asserted on final sample");
                            `FAIL_IF(1);
                        end
                    end else begin
                        if (tb_dout_last !== 1'b0) begin
                            $display("FRAME last asserted early at k=%0d", k);
                            `FAIL_IF(1);
                        end
                    end
                    k++;
                end
            end
        end
    join
    if (k !== FLEN) begin
        $display("FRAME: got %0d valid beats, expected %0d", k, FLEN);
        `FAIL_IF(1);
    end
    tb_cb.tb_din_valid <= 1'b0;
`SVTEST_END

// Diagnóstico: latencia de valid, dato-bypass (OUTSEL=2) y dato-processed (OUTSEL=0)
`SVTEST(tc_measure_both_paths)
    int v_lat, dbyp_lat, dproc_lat;
    logic [31:0] marker;
    marker = pack_qi(16'sd1000, 16'sd2000);

    // --- bypass path ---
    write_config(2, 0, 4000, 0, 0, 32767);   // OUTSEL=2
    v_lat = -1; dbyp_lat = -1;
    tb_cb.tb_din_valid <= 1'b1; tb_cb.tb_din <= marker;
    @(tb_cb);
    tb_cb.tb_din_valid <= 1'b0; tb_cb.tb_din <= '0;
    for (int c = 1; c < 32; c++) begin
        @(tb_cb);
        if (v_lat==-1 && tb_dout_valid===1'b1) v_lat = c;
        if (dbyp_lat==-1 && tb_dout===marker)  dbyp_lat = c;
    end

    // --- processed path (OUTSEL=0, CW, passthrough): dout ~= din ---
    write_config(0, 0, 4000, 0, 0, 32767);   // OUTSEL=0, punct_id=0 (first sample)
    dproc_lat = -1;
    repeat(40) @(tb_cb);   // let carrier spin up
    tb_cb.tb_din_valid <= 1'b1; tb_cb.tb_din <= marker;
    @(tb_cb);
    tb_cb.tb_din_valid <= 1'b0; tb_cb.tb_din <= '0;
    for (int c = 1; c < 40; c++) begin
        @(tb_cb);
        // processed sample ~= marker (within tolerance)
        if (dproc_lat==-1 &&
            (tb_dout_i > 1900 && tb_dout_i < 2100) &&
            (tb_dout_q > 900  && tb_dout_q < 1100)) dproc_lat = c;
    end

    $display("PATHS: valid_lat=%0d  bypass_data_lat=%0d  processed_data_lat=%0d",
             v_lat, dbyp_lat, dproc_lat);
    $display("SKEW valid-vs-bypass=%0d  valid-vs-processed=%0d",
             dbyp_lat - v_lat, dproc_lat - v_lat);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST: punct selects exactly one sample of a frame (board failure, 2026-09-22).
//   A 16-sample frame with OUTSEL=3 (zero) and PUNCT_ID=5: only sample 5 goes
//   through the resonator path, so exactly that output sample is 0 and the
//   others are the input. With KIDSIM_LAT=22 (DDS counted as 8 clocks) the mux
//   never saw kidsim's valid and no sample was zeroed -- what the RFSoC4x2
//   showed on the debug bench.
// ----------------------------------------------------------------------------
`SVTEST(tc_punct_zeroes_one_sample)
    localparam int FLEN = 16;
    localparam int P    = 5;
    localparam int BASE = 1000;
    int k, nzero;
    write_config(3, 0, 4000, 0, 0, 32767);
    prime_dds();
    write_config(3, P, 4000, 0, 0, 32767);
    k = 0; nzero = 0;
    fork
        send_frame(FLEN, BASE);
        begin
            for (int c = 0; c < TOP_LAT + FLEN + 12 && k < FLEN; c++) begin
                @(tb_cb);
                if (tb_dout_valid === 1'b1) begin
                    if (k == P) begin
                        if (tb_dout !== 32'h0) begin
                            $display("PUNCT: sample %0d exp 0 got 0x%08h", k, tb_dout);
                            `FAIL_IF(1);
                        end
                    end else if (tb_dout !== pack_qi(BASE + k, BASE + k + 100)) begin
                        $display("PUNCT: sample %0d exp bypass 0x%08h got 0x%08h",
                                 k, pack_qi(BASE + k, BASE + k + 100), tb_dout);
                        `FAIL_IF(1);
                    end
                    k++;
                end
            end
        end
    join
    `FAIL_IF(k !== FLEN);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST: sparse one-sample frames each advance the carrier by one step
//   (board failure, 2026-09-22). OUTSEL=1, FREQ=0x1000 (22.5 deg per step),
//   one-sample frames 30 clocks apart: every output is the carrier (full
//   scale) and consecutive outputs differ by 22.5 deg -- the DDS advances once
//   per selected sample, not per clock.
// ----------------------------------------------------------------------------
`SVTEST(tc_sparse_frames_step_carrier)
    localparam int NB = 12;
    logic [31:0] outs [$];
    real a0, a1, st, mag;
    write_config(1, 0, 16'h1000, 0, 0, 32767);
    prime_dds();
    fork
        for (int b = 0; b < NB; b++) begin
            tb_cb.tb_din_valid <= 1'b1;
            tb_cb.tb_din_last  <= 1'b1;
            tb_cb.tb_din       <= pack_qi(1000, 1000);
            @(tb_cb);
            tb_cb.tb_din_valid <= 1'b0;
            tb_cb.tb_din_last  <= 1'b0;
            repeat(30) @(tb_cb);
        end
        for (int c = 0; c < NB * 31 + TOP_LAT + 4; c++) begin
            @(tb_cb);
            if (tb_dout_valid === 1'b1) outs.push_back(tb_dout);
        end
    join
    `FAIL_IF(outs.size() !== NB);
    for (int b = 0; b < outs.size(); b++) begin
        mag = $sqrt(real'($signed(outs[b][15:0])) ** 2 + real'($signed(outs[b][31:16])) ** 2);
        if (mag < 32000.0 || mag > 33500.0) begin
            $display("SPARSE: output %0d |carrier| = %0.0f (I=%0d Q=%0d)", b, mag,
                     $signed(outs[b][15:0]), $signed(outs[b][31:16]));
            `FAIL_IF(1);
        end
        if (b > 0) begin
            a0 = $atan2($signed(outs[b-1][31:16]), $signed(outs[b-1][15:0]));
            a1 = $atan2($signed(outs[b][31:16]),   $signed(outs[b][15:0]));
            st = (a1 - a0) * 180.0 / 3.14159265358979;
            if (st < -180.0) st += 360.0;
            if (st >  180.0) st -= 360.0;
            if (st < 22.3 || st > 22.7) begin
                $display("SPARSE: step %0d = %0.2f deg, exp 22.50", b, st);
                `FAIL_IF(1);
            end
        end
    end
`SVTEST_END
