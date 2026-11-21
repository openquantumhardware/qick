//------------------------------------------------------------------------------
// Tests
// a=10, b=3, c=100, d=5 unless noted otherwise.
//------------------------------------------------------------------------------

`SVTEST(tc_sel0_a_mul_b)
    check_instr(4'd0, 27'sd10, 18'sd3, 32'sd100, 27'sd5, 46'sd30, "A*B");
`SVTEST_END

`SVTEST(tc_sel1_a_mul_b_plus_c)
    check_instr(4'd1, 27'sd10, 18'sd3, 32'sd100, 27'sd5, 46'sd130, "A*B+C");
`SVTEST_END

`SVTEST(tc_sel2_a_mul_b_minus_c)
    check_instr(4'd2, 27'sd10, 18'sd3, 32'sd100, 27'sd5, -46'sd70, "A*B-C");
`SVTEST_END

`SVTEST(tc_sel3_apd_mul_b)
    check_instr(4'd3, 27'sd10, 18'sd3, 32'sd100, 27'sd5, 46'sd45, "(A+D)*B");
`SVTEST_END

`SVTEST(tc_sel4_apd_mul_b_plus_c)
    check_instr(4'd4, 27'sd10, 18'sd3, 32'sd100, 27'sd5, 46'sd145, "(A+D)*B+C");
`SVTEST_END

`SVTEST(tc_sel5_apd_mul_b_minus_c)
    check_instr(4'd5, 27'sd10, 18'sd3, 32'sd100, 27'sd5, -46'sd55, "(A+D)*B-C");
`SVTEST_END

`SVTEST(tc_sel6_dma_mul_b)
    check_instr(4'd6, 27'sd10, 18'sd3, 32'sd100, 27'sd5, -46'sd15, "(D-A)*B");
`SVTEST_END

`SVTEST(tc_sel7_dma_mul_b_plus_c)
    check_instr(4'd7, 27'sd10, 18'sd3, 32'sd100, 27'sd5, 46'sd85, "(D-A)*B+C");
`SVTEST_END

`SVTEST(tc_sel8_dma_mul_b_minus_c)
    check_instr(4'd8, 27'sd10, 18'sd3, 32'sd100, 27'sd5, -46'sd115, "(D-A)*B-C");
`SVTEST_END

`SVTEST(tc_negative_operands)
    // A=-4, B=7, C=-2, D=0 -> A*B+C = -28 + (-2) = -30
    check_instr(4'd1, -27'sd4, 18'sd7, -32'sd2, 27'sd0, -46'sd30, "A*B+C (negative operands)");
`SVTEST_END

`SVTEST(tc_default_sel_is_zero)
    check_instr(4'd9, 27'sd10, 18'sd3, 32'sd100, 27'sd5, 46'sd0, "sel=9 (unused) -> 0");
`SVTEST_END
