`SVTEST(test00_reset)

`ASSERT_IMMEDIATE(tb_cb.tb_o_data  == '0);     
repeat(5) @(tb_cb);
for (integer k = 0; k < 10; k = k + 1) begin
    tb_cb.tb_rstn <= 1'b0;
    @(tb_cb);
    tb_cb.tb_rstn <= 1'b1;
    @(tb_cb);
    `ASSERT_IMMEDIATE(tb_cb.tb_o_data  == '0);     
    @(tb_cb);
end

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_32bit_data)

  tb_cb.tb_i_id <= 4'b0001;
  SIM_TX();
  tb_cb.tb_i_id <= 4'b0010;
  SIM_TX();
  tb_cb.tb_i_id <= 4'b1010;
  SIM_TX();

repeat(5) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
