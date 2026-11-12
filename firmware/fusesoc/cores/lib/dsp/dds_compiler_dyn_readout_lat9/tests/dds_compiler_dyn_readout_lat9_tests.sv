// ============================================================================
// File: dds_compiler_dyn_readout_lat9_tests.sv
// Description: SVUnit test cases for dds_compiler_dyn_readout_lat9. Included by dds_compiler_dyn_readout_lat9_tc00.sv.
// ============================================================================

// The first output comes 9 clocks after tvalid rises (8 for the latency-8 variant).
`SVTEST(tc_first_valid_nine_clocks_after_input)
    int n9 = -1, n8 = -1;
    repeat (12) drive(1'b0, 1'b0, '0, '0);
    drive(1'b1, 1'b1, 32'h0, 32'h0100_0000);
    for (int k = 1; k <= 12; k++) begin
        @(posedge tb_clk); #1;
        if (tb_v8 && n8 < 0) n8 = k;
        if (tb_v9 && n9 < 0) n9 = k;
        drive(1'b1, 1'b0, 32'h0, 32'h0100_0000);
    end
    `FAIL_UNLESS_EQUAL(n8, 8)
    `FAIL_UNLESS_EQUAL(n9, 9)
`SVTEST_END

// With tvalid high every clock (the dyn readout after reset), the latency-9 output is the
// latency-8 output one clock later, bit for bit: segments with a resync at the start, a resync
// every clock, and a new pinc without a resync. Compared on the clocks where the input was valid
// in that clock and the one before: at a valid edge the model (like the real core) moves per
// transaction, not per clock.
`SVTEST(tc_output_is_latency8_output_one_clock_later)
    logic [31:0] d8_d;
    logic        v8_d;
    logic        iv_d = 1'b0;
    int          n_cmp = 0, n_bad = 0;
    logic [31:0] pinc, poff;
    int          len;
    repeat (12) drive(1'b0, 1'b0, '0, '0);
    fork
        begin : check
            forever begin
                @(posedge tb_clk); #1;
                if (tb_tvalid && iv_d) begin
                    n_cmp++;
                    if (tb_v9 !== v8_d || tb_d9 !== d8_d) n_bad++;
                end
                v8_d = tb_v8;
                d8_d = tb_d8;
                iv_d = tb_tvalid;
            end
        end
        begin : stim
            for (int s = 0; s < 600; s++) begin
                pinc = $urandom(); poff = $urandom(); len = $urandom_range(1, 40);
                case (s % 3)
                    0: begin drive(1'b1, 1'b1, poff, pinc); repeat (len - 1) drive(1'b1, 1'b0, poff, pinc); end
                    1: repeat (len) drive(1'b1, 1'b1, $urandom(), $urandom());
                    2: begin drive(1'b1, 1'b1, poff, pinc); repeat (len) drive(1'b1, 1'b0, poff, $urandom()); end
                endcase
            end
            repeat (12) drive(1'b1, 1'b0, poff, pinc);
        end
    join_any
    disable fork;
    `FAIL_UNLESS(n_cmp > 10000)
    `FAIL_UNLESS_EQUAL(n_bad, 0)
`SVTEST_END
