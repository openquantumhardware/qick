//-------------------------------------------------------------------------------------------------//
// IBUFDS's behavioral sim model passes the P leg straight through to O and
// ignores N (matching real differential-input semantics: N is just the
// complement of P on the board, only P carries the logical value).
//-------------------------------------------------------------------------------------------------//
`SVTEST(test00_reset_value)
  `FAIL_IF(tb_o_se !== '0);
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_follows_diff_p)
  for (int k = 0; k < 20; k++) begin
    logic [NB-1:0] pattern;
    pattern = $urandom();
    tb_i_diff_p = pattern;
    tb_i_diff_n = ~pattern;
    #1;
    `FAIL_IF(tb_o_se !== pattern);
  end
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_all_bits_independent)
  for (int b = 0; b < NB; b++) begin
    tb_i_diff_p = '0;
    tb_i_diff_n = '1;
    tb_i_diff_p[b] = 1'b1;
    tb_i_diff_n[b] = 1'b0;
    #1;
    `FAIL_IF(tb_o_se !== (1 << b));
  end
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
