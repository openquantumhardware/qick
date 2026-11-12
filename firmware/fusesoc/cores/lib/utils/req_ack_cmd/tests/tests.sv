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
repeat(10) @(cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_net_req)
@(cb);
for (int j = 0; j < 16; j = j + 1) begin
  random_data = $urandom_range(0, 255);  
  write_loc(random_data, j);
end

repeat(10) @(cb);
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_loc_req)

//random_data  = 32'd8;
@(cb);
for (int j=16;j<32;j=j+1) begin
  random_data  = $urandom_range(0,32);     
  write_loc(random_data,j);
end

//`ASSERT_IMMEDIATE(tb_o_data  == k);     
repeat(10) @(cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
