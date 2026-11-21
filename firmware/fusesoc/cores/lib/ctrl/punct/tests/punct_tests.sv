// ============================================================================
// File: punct_tests.sv
// Description: SVUnit test cases for punct. Included by punct_tc00.sv.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Latency 2 — valid/last appear 2 cycles after the input.
// ----------------------------------------------------------------------------
`SVTEST(tc_latency)
    tb_cb.tb_id_reg <= 0;
    // one isolated valid+last pulse
    @(tb_cb);
    tb_cb.tb_din_valid <= 1'b1;
    tb_cb.tb_din_last  <= 1'b1;
    @(tb_cb);
    tb_cb.tb_din_valid <= 1'b0;
    tb_cb.tb_din_last  <= 1'b0;
    // cycle +1: not yet at output
    `FAIL_IF(tb_dout_valid !== 1'b0);
    @(tb_cb);
    // cycle +2: valid+last appear at output
    `FAIL_IF(tb_dout_valid !== 1'b1);
    `FAIL_IF(tb_dout_last  !== 1'b1);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Selects the right sample — o_dout_en high only on idx == ID_REG.
//   ID_REG = 2, frame length 5: en must be high exactly on the 3rd valid beat.
// ----------------------------------------------------------------------------
`SVTEST(tc_select_index)
    int  seen_en_idx;
    int  vbeat;
    seen_en_idx = -1;
    vbeat       = 0;
    tb_cb.tb_id_reg <= 2;
    fork
        send_frame(5);
        begin
            // watch the output for ~10 cycles, record which valid beat has en=1
            for (int c = 0; c < 12; c++) begin
                @(tb_cb);
                if (tb_dout_valid === 1'b1) begin
                    if (tb_dout_en === 1'b1) begin
                        if (seen_en_idx != -1) begin
                            $display("MULTIPLE en asserted (idx %0d and %0d)", seen_en_idx, vbeat);
                            `FAIL_IF(1);
                        end
                        seen_en_idx = vbeat;
                    end
                    vbeat++;
                end
            end
        end
    join
    if (seen_en_idx !== 2) begin
        $display("SELECT MISMATCH: en on valid-beat %0d, expected 2", seen_en_idx);
        `FAIL_IF(1);
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Counter wraps between frames — en fires at ID_REG in each frame,
//   i.e. the in-frame counter resets on last.
// ----------------------------------------------------------------------------
`SVTEST(tc_multi_frame)
    int en_count;
    int vbeat, frame_beat;
    en_count = 0;
    tb_cb.tb_id_reg <= 1;
    fork
        begin
            send_frame(4);   // frame A: idx 0..3
            send_frame(4);   // frame B: idx 0..3
        end
        begin
            vbeat = 0; frame_beat = 0;
            for (int c = 0; c < 16; c++) begin
                @(tb_cb);
                if (tb_dout_valid === 1'b1) begin
                    if (tb_dout_en === 1'b1) begin
                        // en must fire on in-frame index 1
                        if (frame_beat !== 1) begin
                            $display("FRAME en at wrong idx %0d (expected 1)", frame_beat);
                            `FAIL_IF(1);
                        end
                        en_count++;
                    end
                    // advance in-frame index, reset on last
                    if (tb_dout_last === 1'b1) frame_beat = 0;
                    else                        frame_beat++;
                    vbeat++;
                end
            end
        end
    join
    // en must have fired once per frame (2 frames).
    if (en_count !== 2) begin
        $display("MULTI-FRAME en_count %0d, expected 2", en_count);
        `FAIL_IF(1);
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: ID_REG = 0 — en fires on the first sample of the frame.
// ----------------------------------------------------------------------------
`SVTEST(tc_select_first)
    int seen_en_idx, vbeat;
    seen_en_idx = -1; vbeat = 0;
    tb_cb.tb_id_reg <= 0;
    fork
        send_frame(4);
        begin
            for (int c = 0; c < 10; c++) begin
                @(tb_cb);
                if (tb_dout_valid === 1'b1) begin
                    if (tb_dout_en === 1'b1 && seen_en_idx == -1) seen_en_idx = vbeat;
                    vbeat++;
                end
            end
        end
    join
    if (seen_en_idx !== 0) begin
        $display("SELECT-FIRST MISMATCH: en on beat %0d, expected 0", seen_en_idx);
        `FAIL_IF(1);
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: Long frames — the whole 16-bit index range.
//   ID_REG = 0xFFFF, 0xAAAA and 0x5555 select the last beat of a frame of ID+1
//   beats: every bit of the counter and of the index register toggles, and en
//   fires exactly once, on the last beat.
// ----------------------------------------------------------------------------
`SVTEST(tc_long_frame)
    logic [15:0] ids [3] = '{16'hFFFF, 16'hAAAA, 16'h5555};
    int n_en, first_en, last_en;
    foreach (ids[k]) begin
        set_id(ids[k]);
        frame_en_profile(int'(ids[k]) + 1, n_en, first_en, last_en);
        if (n_en !== 1 || first_en !== int'(ids[k])) begin
            $display("LONG FRAME id=0x%04h: en fired %0d times, first on beat %0d", ids[k], n_en, first_en);
            `FAIL_IF(1);
        end
        repeat(6) @(tb_cb);       // let the frame's last beat clear the counter
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: Frames longer than 65536 beats alias the index.
//   The in-frame counter is 16 bits wide and wraps, so with ID_REG = 1 a frame of
//   65538 beats has en on beat 1 and again on beat 65537. This documents the limit
//   (frames must be at most 65536 beats); it is not a feature.
// ----------------------------------------------------------------------------
`SVTEST(tc_counter_wraps_in_long_frame)
    int n_en, first_en, last_en;
    set_id(16'd1);
    frame_en_profile(65538, n_en, first_en, last_en);
    if (n_en !== 2 || first_en !== 1 || last_en !== 65537) begin
        $display("WRAP: en fired %0d times (first %0d, last %0d), expected 2 (1, 65537)", n_en, first_en, last_en);
        `FAIL_IF(1);
    end
`SVTEST_END
