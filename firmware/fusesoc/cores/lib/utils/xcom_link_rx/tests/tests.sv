`SVTEST(test00_reset)

`ASSERT_IMMEDIATE(cb.tb_o_data  == '0);     
repeat(5) @(cb);
for (integer k = 0; k < 10; k = k + 1) begin
  cb.tb_rstn <= 1'b0;
  @(cb);
  cb.tb_rstn <= 1'b1;
  @(cb);
  `ASSERT_IMMEDIATE(cb.tb_o_data  == '0);     
  @(cb);
end

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_rx_data)

cb.tb_i_id <= 4'h1;
SIM_TX();
cb.tb_i_id <= 4'h2;
SIM_TX();
cb.tb_i_id <= 4'hA;
SIM_TX();

repeat(5) @(cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
