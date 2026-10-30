//------------------------------------------------------------------------------
// Tests
//------------------------------------------------------------------------------

`SVTEST(test00_reset_ready)
    `FAIL_UNLESS_LOG(tb_ready == 1'b1, "Should be ready (idle) after reset");
`SVTEST_END

`SVTEST(test01_a_mul_b)
    run_arith(32'sd10, 32'sd3, 32'sd0, 32'sd0, 5'd0);   // sel=0: A*B
    `FAIL_UNLESS_LOG(tb_result == 64'sd30,
        $sformatf("A*B: expected 30, got %0d", tb_result));
`SVTEST_END

`SVTEST(test02_apd_mul_b_plus_c)
    run_arith(32'sd10, 32'sd3, 32'sd100, 32'sd5, 5'd4);  // sel=4: (A+D)*B+C
    `FAIL_UNLESS_LOG(tb_result == 64'sd145,
        $sformatf("(A+D)*B+C: expected 145, got %0d", tb_result));
`SVTEST_END

`SVTEST(test03_ready_low_for_exactly_four_cycles)
    // Inherited from the original `arith`: ready_o is gated by a fixed
    // working/working_r/working_r2/working_r3 chain, 4 cycles, independent
    // of the DSP macro's own (behavioral-model) latency.
    int cycles_low;

    tb_a      = 32'sd7;
    tb_b      = 32'sd6;
    tb_c      = 32'sd0;
    tb_d      = 32'sd0;
    tb_alu_op = 5'd0;
    tb_start  = 1'b1;
    @(posedge tb_clk);
    tb_start = 1'b0;

    cycles_low = 0;
    while (tb_ready == 1'b0) begin
        cycles_low++;
        @(posedge tb_clk);
    end
    `FAIL_UNLESS_LOG(cycles_low == 4,
        $sformatf("Expected ready_o low for 4 cycles, was low for %0d", cycles_low));
`SVTEST_END

`SVTEST(test04_negative_result_sign_extends_to_64_bits)
    run_arith(32'sd5, 32'sd2, 32'sd100, 32'sd0, 5'd2);  // sel=2: A*B-C = 10-100 = -90
    `FAIL_UNLESS_LOG(tb_result == -64'sd90,
        $sformatf("A*B-C: expected -90, got %0d", tb_result));
`SVTEST_END
