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
`SVTEST(test01_send_data)

  //cb.tb_i_id <= 4'h1;
  SIM_TX();
  //cb.tb_i_id <= 4'h2;
  SIM_TX();
  //cb.tb_i_id <= 4'hA;
  SIM_TX();

repeat(5) @(cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
//`SVTEST(test01_8bit_data)
//
////cb.tb_i_data   <= $urandom();     
//cb.tb_i_data   <= 32'h0000_FF0F;     
//cb.tb_i_valid  <= 1'b1;
//cb.tb_i_header <= 8'b0010_1010;//8-bit data width     
////N clock cycles in 1/0. Invalid values here 0 and 1. Bit LSB is always 0     
//cb.tb_i_cfg_tick <= 4'b0010;   
//@(cb);
//cb.tb_i_valid <= 1'b0;
//repeat(50) @(cb);
//
//`SVTEST_END
////-------------------------------------------------------------------------------------------------//
//`SVTEST(test02_16bit_data)
//
//cb.tb_i_data   <= $urandom();     
////cb.tb_i_data   <= 32'h0000_0003;     
//cb.tb_i_valid  <= 1'b1;
//cb.tb_i_header <= 8'b0100_1010;//8-bit data witdth     
////N clock cycles in 1/0. Invalid values here 0 and 1. Bit LSB is always 0     
//cb.tb_i_cfg_tick <= 4'b0100;   
//@(cb);
//cb.tb_i_valid <= 1'b0;
//repeat(100) @(cb);
//
//`SVTEST_END
////-------------------------------------------------------------------------------------------------//
//`SVTEST(test03_32bit_data)
//
//cb.tb_i_data   <= $urandom();     
////cb.tb_i_data   <= 32'h0000_0003;     
//cb.tb_i_valid  <= 1'b1;
//cb.tb_i_header <= 8'b0110_1010;//32-bit data witdth     
////N clock cycles in 1/0. Invalid values here 0 and 1. Bit LSB is always 0     
//cb.tb_i_cfg_tick <= 4'b0101;   
//@(cb);
//cb.tb_i_valid <= 1'b0;
//repeat(400) @(cb);
//
//`SVTEST_END
//-------------------------------------------------------------------------------------------------//
//`SVTEST(test02_data)
//
//    random_data  = $urandom();     
//    @(cb);
//    write_loc(random_data);
//
//    //`ASSERT_IMMEDIATE(tb_o_data  == k);     
//    repeat(10) @(cb);
//     
//`SVTEST_END
//-------------------------------------------------------------------------------------------------//
