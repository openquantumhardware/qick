///////////////////////////////////////////////////////////////////////////////
// iir_iq_tests.sv  —  SVUnit test cases for iir_iq
// Included inside iir_iq_unit_test between `SVUNIT_TESTS_BEGIN/END`.
///////////////////////////////////////////////////////////////////////////////

//-----------------------------------------------------------------------------
// TEST 1: Reset clears outputs.
//-----------------------------------------------------------------------------
`SVTEST(test_reset_clears_output)
    i_c0 = 16'sh2000; i_c1 = 16'sh4000; i_g = 16'sh4000;
    do_reset();
    `FAIL_UNLESS(o_valid === 1'b0);
    `FAIL_UNLESS(o_data  === '0);
`SVTEST_END

//-----------------------------------------------------------------------------
// TEST 2: Latency is exactly LAT (=4).
//-----------------------------------------------------------------------------
`SVTEST(test_latency_is_four)
    int cnt;
    i_c0 = 16'sh0000; i_c1 = 16'sh0000; i_g = 16'sh7FFF;
    do_reset();

    @(posedge tb_clk);
    i_data  <= pack_iq(16'sh0100, 16'sh0200);
    i_valid <= 1'b1;
    @(posedge tb_clk);
    i_valid <= 1'b0;

    cnt = 0;
    fork : lat_watch
        begin
            forever begin
                @(posedge tb_clk);
                cnt++;
                if (o_valid) disable lat_watch;
                if (cnt > 20) begin
                    `FAIL_IF_LOG(1, "o_valid never asserted")
                    disable lat_watch;
                end
            end
        end
    join
    `FAIL_UNLESS_LOG(cnt == LAT,
        $sformatf("expected latency %0d, got %0d", LAT, cnt))
`SVTEST_END

//-----------------------------------------------------------------------------
// TEST 3 (KEY): Channel independence + { Q, I } packing.
//   Drive DIFFERENT sequences on I and Q; each output half must match its own
//   golden model. Catches cross-coupling and endianness/packing errors.
//-----------------------------------------------------------------------------
`SVTEST(test_channel_independence)
    localparam int NS = 20;
    logic signed [B-1:0] stim_i [NS];
    logic signed [B-1:0] stim_q [NS];
    logic signed [B-1:0] exp_i  [$];
    logic signed [B-1:0] exp_q  [$];
    int got;

    i_c0 = 16'sh2000;   // 0.25
    i_c1 = 16'sh6000;   // 0.75
    i_g  = 16'sh7FFF;
    do_reset();

    // Distinct stimuli per channel (Q different from I on purpose).
    for (int k = 0; k < NS; k++) begin
        stim_i[k] = $signed(16'($random)) >>> 2;
        stim_q[k] = $signed(16'($random)) >>> 2;
    end

    // Golden per channel.
    for (int k = 0; k < NS; k++) begin
        exp_i.push_back(ref_step(0, stim_i[k]));
        exp_q.push_back(ref_step(1, stim_q[k]));
    end

    got = 0;
    fork
        begin
            for (int k = 0; k < NS; k++) begin
                @(posedge tb_clk);
                i_data  <= pack_iq(stim_i[k], stim_q[k]);
                i_valid <= 1'b1;
            end
            @(posedge tb_clk);
            i_valid <= 1'b0;
        end
        begin
            while (got < NS) begin
                @(posedge tb_clk);
                if (o_valid) begin
                    `FAIL_UNLESS_LOG(unpack_i(o_data) === exp_i[got],
                        $sformatf("I sample %0d: got %0h exp %0h",
                                  got, unpack_i(o_data), exp_i[got]))
                    `FAIL_UNLESS_LOG(unpack_q(o_data) === exp_q[got],
                        $sformatf("Q sample %0d: got %0h exp %0h",
                                  got, unpack_q(o_data), exp_q[got]))
                    got++;
                end
            end
        end
    join
`SVTEST_END

//-----------------------------------------------------------------------------
// TEST 4: One channel active, the other held at zero => zero output on the
//   idle channel (extra guard against cross-coupling / packing swap).
//-----------------------------------------------------------------------------
`SVTEST(test_q_idle_stays_zero)
    localparam int NS = 24;
    logic signed [B-1:0] exp_i [$];
    int got;

    i_c0 = 16'sh1000; i_c1 = 16'sh6000; i_g = 16'sh7FFF;
    do_reset();

    for (int k = 0; k < NS; k++)
        exp_i.push_back(ref_step(0, (k==0) ? 16'sh0400 : 16'sh0000)); // impulse on I
    // Q model stays at zero (never stimulated) => expect 0.

    got = 0;
    fork
        begin
            for (int k = 0; k < NS; k++) begin
                @(posedge tb_clk);
                i_data  <= pack_iq((k==0)?16'sh0400:16'sh0000, 16'sh0000);
                i_valid <= 1'b1;
            end
            @(posedge tb_clk);
            i_valid <= 1'b0;
        end
        begin
            while (got < NS) begin
                @(posedge tb_clk);
                if (o_valid) begin
                    `FAIL_UNLESS_LOG(unpack_i(o_data) === exp_i[got],
                        $sformatf("I %0d: got %0h exp %0h",
                                  got, unpack_i(o_data), exp_i[got]))
                    `FAIL_UNLESS_LOG(unpack_q(o_data) === '0,
                        $sformatf("Q %0d should be 0, got %0h",
                                  got, unpack_q(o_data)))
                    got++;
                end
            end
        end
    join
`SVTEST_END

//-----------------------------------------------------------------------------
// TEST 5 (REGRESSION): bubbles vs continuous must match, both channels.
//-----------------------------------------------------------------------------
`SVTEST(test_bubbles_match_continuous)
    localparam int NS = 16;
    logic signed [B-1:0] si [NS], sq [NS];
    logic [2*B-1:0] out_cont [NS];
    logic [2*B-1:0] out_bub  [NS];
    int idx;

    i_c0 = 16'sh1999; i_c1 = 16'sh6666; i_g = 16'sh7FFF;

    for (int k = 0; k < NS; k++) begin
        si[k] = $signed(16'($random)) >>> 2;
        sq[k] = $signed(16'($random)) >>> 2;
    end

    // Pass A: continuous.
    do_reset();
    idx = 0;
    fork
        begin
            for (int k = 0; k < NS; k++) begin
                @(posedge tb_clk);
                i_data  <= pack_iq(si[k], sq[k]);
                i_valid <= 1'b1;
            end
            @(posedge tb_clk);
            i_valid <= 1'b0;
        end
        begin
            while (idx < NS) begin
                @(posedge tb_clk);
                if (o_valid) out_cont[idx++] = o_data;
            end
        end
    join

    // Pass B: same stimulus with bubbles.
    do_reset();
    idx = 0;
    fork
        begin
            for (int k = 0; k < NS; k++) begin
                bubble(($unsigned($random) % 4));
                @(posedge tb_clk);
                i_data  <= pack_iq(si[k], sq[k]);
                i_valid <= 1'b1;
                @(posedge tb_clk);
                i_valid <= 1'b0;
            end
        end
        begin
            while (idx < NS) begin
                @(posedge tb_clk);
                if (o_valid) out_bub[idx++] = o_data;
            end
        end
    join

    for (int k = 0; k < NS; k++)
        `FAIL_UNLESS_LOG(out_bub[k] === out_cont[k],
            $sformatf("bubble mismatch @%0d: cont %08h bub %08h",
                      k, out_cont[k], out_bub[k]))
`SVTEST_END