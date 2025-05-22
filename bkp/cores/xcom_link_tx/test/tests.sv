`SVTEST(test00_reset)

//`ASSERT_IMMEDIATE(tb_cb.tb_o_data  == '0);     
//repeat(5) @(tb_cb);
for (integer k = 0; k < 10; k = k + 1) begin
    tb_cb.tb_rstn <= 1'b0;
    @(tb_cb);
    tb_cb.tb_rstn <= 1'b1;
    @(tb_cb);
    //`ASSERT_IMMEDIATE(tb_cb.tb_o_data  == '0);     
end

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_8bit_data)

//tb_cb.tb_i_data   <= $urandom();     
tb_cb.tb_i_data   <= 32'h0000_FF0F;     
tb_cb.tb_i_valid  <= 1'b1;
tb_cb.tb_i_header <= 8'b0010_1010;//8-bit data width     
//N clock cycles in 1/0. Invalid values here 0 and 1. Bit LSB is always 0     
tb_cb.tb_i_cfg_tick <= 4'b0010;   
@(tb_cb);
tb_cb.tb_i_valid <= 1'b0;
repeat(50) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_16bit_data)

tb_cb.tb_i_data   <= $urandom();     
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_valid  <= 1'b1;
tb_cb.tb_i_header <= 8'b0100_1010;//8-bit data witdth     
//N clock cycles in 1/0. Invalid values here 0 and 1. Bit LSB is always 0     
tb_cb.tb_i_cfg_tick <= 4'b0010;   
@(tb_cb);
tb_cb.tb_i_valid <= 1'b0;
repeat(100) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test03_32bit_data)

tb_cb.tb_i_data   <= $urandom();     
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_valid  <= 1'b1;
tb_cb.tb_i_header <= 8'b0110_1010;//32-bit data witdth     
//N clock cycles in 1/0. Invalid values here 0 and 1. Bit LSB is always 0     
tb_cb.tb_i_cfg_tick <= 4'b0010;   
@(tb_cb);
tb_cb.tb_i_valid <= 1'b0;
repeat(100) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
//`SVTEST(test02_data)
//
//    random_data  = $urandom();     
//    @(tb_cb);
//    write_loc(random_data);
//
//    //`ASSERT_IMMEDIATE(tb_o_data  == k);     
//    repeat(10) @(tb_cb);
//     
//`SVTEST_END
//-------------------------------------------------------------------------------------------------//
