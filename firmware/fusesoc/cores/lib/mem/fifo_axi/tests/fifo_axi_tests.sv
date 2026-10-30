// ============================================================================
// File: fifo_axi_tests.sv
// Description: SVUnit test cases for fifo_axi. Included by fifo_axi_tc00.sv.
// ============================================================================

`SVTEST(tc_random_traffic_matches_the_legacy_fifo)
    // Write and read probabilities swept from "mostly write" to "mostly read":
    // the FIFO fills (full), empties (READ_LAST) and runs in between.
    for (int pw = 1; pw <= 9; pw += 2) begin
        for (int pr = 1; pr <= 9; pr += 2) begin
            repeat (300) step($urandom_range(9) < pw, $urandom_range(9) < pr, rand_word());
        end
    end
    step(1'b0, 1'b0, '0);
    repeat (10) @(posedge clk);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS(n_full > 100)
    `FAIL_UNLESS(n_pop > 1000)
`SVTEST_END

`SVTEST(tc_words_come_out_in_order_and_complete)
    logic [B-1:0] sent [$];
    logic [B-1:0] w;
    for (int n = 0; n < 200; n++) begin
        w = rand_word();
        // write when not full, read all the time
        @(negedge clk);
        if (!p_full) sent.push_back(w);
        step(!p_full, 1'b1, w);
    end
    step(1'b0, 1'b1, '0);
    repeat (20) @(posedge clk);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS_EQUAL(o_data.size(), sent.size())
    for (int n = 0; n < o_data.size() && n < sent.size(); n++) begin
        logic [B-1:0] a, b;
        a = o_data[n]; b = sent[n];
        `FAIL_UNLESS(a === b)
    end
`SVTEST_END

`SVTEST(tc_reset_in_the_middle_of_traffic)
    repeat (100) step($urandom_range(1), $urandom_range(1), rand_word());
    reset_dut();
    repeat (100) step($urandom_range(1), $urandom_range(1), rand_word());
    step(1'b0, 1'b0, '0);
    repeat (10) @(posedge clk);
    `FAIL_UNLESS_EQUAL(mism, 0)
`SVTEST_END
