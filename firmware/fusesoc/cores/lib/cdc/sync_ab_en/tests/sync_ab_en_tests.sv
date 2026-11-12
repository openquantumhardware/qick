//------------------------------------------------------------------------------
// Tests
//------------------------------------------------------------------------------

`SVTEST(test00_pulses_occur)
    // Let the free-running req/ack handshake complete several round trips.
    repeat (200) @(posedge tb_clk_a);
    `FAIL_IF_LOG(cnt_a_en == 0, "a_en_o never pulsed");
    `FAIL_IF_LOG(cnt_b_en == 0, "b_en_o never pulsed");
`SVTEST_END

`SVTEST(test01_a_en_pulse_is_single_cycle)
    int   violations;
    logic prev;

    violations = 0;
    prev = 1'b0;
    repeat (300) begin
        @(posedge tb_clk_a);
        if (tb_a_en && prev) violations++;
        prev = tb_a_en;
    end
    `FAIL_IF_LOG(violations > 0,
        $sformatf("a_en_o stayed high for >1 clk_a cycle, %0d violations", violations));
`SVTEST_END

`SVTEST(test02_b_en_pulse_is_single_cycle)
    int   violations;
    logic prev;

    violations = 0;
    prev = 1'b0;
    repeat (300) begin
        @(posedge tb_clk_b);
        if (tb_b_en && prev) violations++;
        prev = tb_b_en;
    end
    `FAIL_IF_LOG(violations > 0,
        $sformatf("b_en_o stayed high for >1 clk_b cycle, %0d violations", violations));
`SVTEST_END

`SVTEST(test03_pulse_counts_track_each_other)
    // Each full round trip produces exactly one a_en_o and one b_en_o pulse,
    // so over a long window the two counts can differ by at most the one
    // in-flight round trip at the sampling boundary.
    repeat (500) @(posedge tb_clk_a);
    `FAIL_UNLESS_LOG((cnt_a_en - cnt_b_en) inside {-1, 0, 1},
        $sformatf("a_en count (%0d) and b_en count (%0d) diverged", cnt_a_en, cnt_b_en));
`SVTEST_END
