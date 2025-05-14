`SVTEST(test00_reset)

//`ASSERT_IMMEDIATE(cb.tb_o_data  == '0);     
//repeat(5) @(cb);
for (integer k = 0; k < 10; k = k + 1) begin
    cb.tb_rstn <= 1'b0;
    @(cb);
    cb.tb_rstn <= 1'b1;
    @(cb);
    //`ASSERT_IMMEDIATE(cb.tb_o_data  == '0);     
end

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_8bit_data)

cb.tb_i_data   <= $urandom();     
//cb.tb_i_data   <= 32'h0000_0003;     
cb.tb_i_req    <= 1'b1;
cb.tb_i_header <= 8'b0010_1010;//8-bit data witdth     
@(cb);
cb.tb_i_req <= 1'b0;
repeat(50) @(cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_16bit_data)

cb.tb_i_data   <= $urandom();     
//cb.tb_i_data   <= 32'h0000_0003;     
cb.tb_i_req    <= 1'b1;
cb.tb_i_header <= 8'b0100_1010;//8-bit data witdth     
@(cb);
cb.tb_i_req <= 1'b0;
repeat(100) @(cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test03_32bit_data)

cb.tb_i_data   <= $urandom();     
//cb.tb_i_data   <= 32'h0000_0003;     
cb.tb_i_req  <= 1'b1;
cb.tb_i_header <= 8'b0110_1010;//32-bit data witdth     
@(cb);
cb.tb_i_req <= 1'b0;
repeat(100) @(cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test04_cmd_sync)

cb.tb_i_data   <= $urandom();     
//cb.tb_i_data   <= 32'h0000_0003;     
cb.tb_i_req  <= 1'b1;
cb.tb_i_header <= 8'b1000_1010;//sync command     
@(cb);
cb.tb_i_req <= 1'b0;
repeat(200) @(cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
