//-------------------------------------------------------------------------------------------------//
// OBUFDS's behavioral sim model drives O = I and OB = ~I.
//-------------------------------------------------------------------------------------------------//
`SVTEST(test00_reset_value)
  `FAIL_IF(tb_o_diff_p !== '0);
  `FAIL_IF(tb_o_diff_n !== '1);
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_follows_i_se)
  for (int k = 0; k < 20; k++) begin
    logic [NB-1:0] pattern;
    pattern = $urandom();
    tb_i_se = pattern;
    #1;
    `FAIL_IF(tb_o_diff_p !== pattern);
    `FAIL_IF(tb_o_diff_n !== ~pattern);
  end
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_all_bits_independent)
  for (int b = 0; b < NB; b++) begin
    logic [NB-1:0] expected;
    tb_i_se = '0;
    tb_i_se[b] = 1'b1;
    expected = '0;
    expected[b] = 1'b1;
    #1;
    `FAIL_IF(tb_o_diff_p !== expected);
    `FAIL_IF(tb_o_diff_n !== ~expected);
  end
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
