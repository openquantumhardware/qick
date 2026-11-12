///////////////////////////////////////////////////////////////////////////////
// cmult_tests.sv  —  SVUnit test cases for cmult
// Included inside cmult_unit_test between `SVUNIT_TESTS_BEGIN/END`.
///////////////////////////////////////////////////////////////////////////////

//-----------------------------------------------------------------------------
// TEST 1: Reset clears outputs.
//-----------------------------------------------------------------------------
`SVTEST(test_reset_clears_output)
    do_reset();
    `FAIL_UNLESS(o_valid === 1'b0);
    `FAIL_UNLESS(o_dout  === '0);
`SVTEST_END

//-----------------------------------------------------------------------------
// TEST 2: Latency is exactly LAT (=4).
//-----------------------------------------------------------------------------
`SVTEST(test_latency_is_four)
    int cnt;
    do_reset();
    @(posedge tb_clk);
    i_dina  <= pk(16'sh0100, 16'sh0000);
    i_dinb  <= pk(16'sh0100, 16'sh0000);
    i_valid <= 1'b1;
    @(posedge tb_clk);
    i_valid <= 1'b0;

    cnt = 0;
    fork : lw
        begin
            forever begin
                @(posedge tb_clk);
                cnt++;
                if (o_valid) disable lw;
                if (cnt > 20) begin `FAIL_IF_LOG(1, "o_valid never asserted") disable lw; end
            end
        end
    join
    `FAIL_UNLESS_LOG(cnt == LAT, $sformatf("latency exp %0d got %0d", LAT, cnt))
`SVTEST_END

//-----------------------------------------------------------------------------
// TEST 3: All four conjugation combinations match the golden model.
//   Drives random operands; checks each accepted output for a given (ca,cb).
//-----------------------------------------------------------------------------
`SVTEST(test_conj_combos_match_model)
    localparam int NS = 20;
    for (int combo = 0; combo < 4; combo++) begin
        logic ca = combo[0];
        logic cb = combo[1];
        logic [2*BIN-1:0]  da [NS], db [NS];
        logic [2*BOUT-1:0] exp [$];
        int got;

        do_reset();
        i_conja = ca; i_conjb = cb;

        for (int k = 0; k < NS; k++) begin
            // keep operands moderate to isolate arithmetic (not saturation)
            da[k] = pk($signed(16'($random)) >>> 2, $signed(16'($random)) >>> 2);
            db[k] = pk($signed(16'($random)) >>> 2, $signed(16'($random)) >>> 2);
            exp.push_back(model(da[k], db[k], ca, cb));
        end

        got = 0;
        fork
            begin
                for (int k = 0; k < NS; k++) begin
                    @(posedge tb_clk);
                    i_dina <= da[k]; i_dinb <= db[k]; i_valid <= 1'b1;
                end
                @(posedge tb_clk); i_valid <= 1'b0;
            end
            begin
                while (got < NS) begin
                    @(posedge tb_clk);
                    if (o_valid) begin
                        `FAIL_UNLESS_LOG(o_dout === exp[got],
                            $sformatf("combo(ca=%0d cb=%0d) k=%0d got %08h exp %08h",
                                      ca, cb, got, o_dout, exp[got]))
                        got++;
                    end
                end
            end
        join
    end
`SVTEST_END

//-----------------------------------------------------------------------------
// TEST 4: Packing / channel mapping. Multiply by 1 (real unit) => output equals
//   input requantized; verifies I stays I and Q stays Q ({Q,I} packing).
//-----------------------------------------------------------------------------
`SVTEST(test_packing_multiply_by_one)
    localparam int NS = 12;
    logic [2*BOUT-1:0] exp [$];
    logic [2*BIN-1:0]  da [NS];
    int got;
    // b = 1.0 + j0  => 0x7FFF ~ +1 in real, 0 in imag.
    logic [2*BIN-1:0] one = pk(16'sh7FFF, 16'sh0000);

    do_reset();
    i_conja = 1'b0; i_conjb = 1'b0;
    for (int k = 0; k < NS; k++) begin
        da[k] = pk(16'sh4000 - 16'(k*256), 16'sh2000 + 16'(k*128));
        exp.push_back(model(da[k], one, 1'b0, 1'b0));
    end

    got = 0;
    fork
        begin
            for (int k = 0; k < NS; k++) begin
                @(posedge tb_clk);
                i_dina <= da[k]; i_dinb <= one; i_valid <= 1'b1;
            end
            @(posedge tb_clk); i_valid <= 1'b0;
        end
        begin
            while (got < NS) begin
                @(posedge tb_clk);
                if (o_valid) begin
                    `FAIL_UNLESS_LOG(up_i(o_dout) === up_i(exp[got]),
                        $sformatf("I k=%0d got %0h exp %0h", got, up_i(o_dout), up_i(exp[got])))
                    `FAIL_UNLESS_LOG(up_q(o_dout) === up_q(exp[got]),
                        $sformatf("Q k=%0d got %0h exp %0h", got, up_q(o_dout), up_q(exp[got])))
                    got++;
                end
            end
        end
    join
`SVTEST_END

//-----------------------------------------------------------------------------
// TEST 5 (SATURATION / OVERFLOW): the imaginary path ad+bc sums two same-sign
//   full-scale products => exceeds +full-scale => must clamp to SAT_MAX (never
//   wrap). The real path ac-bd of the same operands is ~0. We (a) check the DUT
//   matches the golden model, and (b) assert the model genuinely saturated.
//-----------------------------------------------------------------------------
`SVTEST(test_saturation_fullscale)
    logic [2*BIN-1:0]  da, db;
    logic [2*BOUT-1:0] exp;
    logic signed [BIN-1:0] MP = MAX_POS_IN();   // +full-scale
    logic signed [BIN-1:0] MN = SAT_MIN_IN();   // -full-scale

    do_reset();
    i_conja = 1'b0; i_conjb = 1'b0;

    // Corner A: a=(MP + jMP), b=(MP + jMP)
    //   imag = ad+bc = MP*MP + MP*MP  -> ~+2.0  => +SAT on imag
    //   real = ac-bd = MP*MP - MP*MP  = 0
    da  = pk(MP, MP);
    db  = pk(MP, MP);
    exp = model(da, db, 1'b0, 1'b0);
    drive_one_and_check(da, db, exp);
    `FAIL_UNLESS_LOG(up_q(exp) === SAT_MAX,
        $sformatf("corner A: expected +SAT on imag, model gave %0h", up_q(exp)))

    // Corner B: a=(MP + jMN), b=(MN + jMP)  (drive imag strongly negative)
    //   imag = ad+bc = MP*MP + MN*MN -> large +  (still +SAT)  -- use signs to get -SAT:
    // Force -SAT on imag: a=(MP + jMN), b=(MP + jMN)
    //   imag = ad+bc = MP*MN + MN*MP = 2*(MP*MN) -> ~-2.0 => -SAT
    da  = pk(MP, MN);
    db  = pk(MP, MN);
    exp = model(da, db, 1'b0, 1'b0);
    drive_one_and_check(da, db, exp);
    `FAIL_UNLESS_LOG(up_q(exp) === SAT_MIN,
        $sformatf("corner B: expected -SAT on imag, model gave %0h", up_q(exp)))
`SVTEST_END

//-----------------------------------------------------------------------------
// TEST 6 (REGRESSION): bubbles vs continuous must match (feed-forward path).
//-----------------------------------------------------------------------------
`SVTEST(test_bubbles_match_continuous)
    localparam int NS = 16;
    logic [2*BIN-1:0]  da [NS], db [NS];
    logic [2*BOUT-1:0] out_cont [NS], out_bub [NS];
    int idx;

    for (int k = 0; k < NS; k++) begin
        da[k] = pk($signed(16'($random)) >>> 1, $signed(16'($random)) >>> 1);
        db[k] = pk($signed(16'($random)) >>> 1, $signed(16'($random)) >>> 1);
    end

    // continuous
    do_reset(); i_conja = 1'b0; i_conjb = 1'b0; idx = 0;
    fork
        begin
            for (int k = 0; k < NS; k++) begin
                @(posedge tb_clk); i_dina <= da[k]; i_dinb <= db[k]; i_valid <= 1'b1;
            end
            @(posedge tb_clk); i_valid <= 1'b0;
        end
        begin while (idx < NS) begin @(posedge tb_clk); if (o_valid) out_cont[idx++] = o_dout; end end
    join

    // bubbles
    do_reset(); i_conja = 1'b0; i_conjb = 1'b0; idx = 0;
    fork
        begin
            for (int k = 0; k < NS; k++) begin
                bubble(($unsigned($random) % 4));
                @(posedge tb_clk); i_dina <= da[k]; i_dinb <= db[k]; i_valid <= 1'b1;
                @(posedge tb_clk); i_valid <= 1'b0;
            end
        end
        begin while (idx < NS) begin @(posedge tb_clk); if (o_valid) out_bub[idx++] = o_dout; end end
    join

    for (int k = 0; k < NS; k++)
        `FAIL_UNLESS_LOG(out_bub[k] === out_cont[k],
            $sformatf("bubble mismatch @%0d cont %08h bub %08h", k, out_cont[k], out_bub[k]))
`SVTEST_END