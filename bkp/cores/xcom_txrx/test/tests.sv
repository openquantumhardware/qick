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

tb_cb.tb_i_data   <= $urandom();     
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_req    <= 1'b1;
tb_cb.tb_i_header <= 8'b0010_1010;//8-bit data witdth     
@(tb_cb);
tb_cb.tb_i_req <= 1'b0;
repeat(50) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_16bit_data)

tb_cb.tb_i_data   <= $urandom();     
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_req    <= 1'b1;
tb_cb.tb_i_header <= 8'b0100_1010;//8-bit data witdth     
@(tb_cb);
tb_cb.tb_i_req <= 1'b0;
repeat(100) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test03_32bit_data)

tb_cb.tb_i_data   <= $urandom();     
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_req  <= 1'b1;
tb_cb.tb_i_header <= 8'b0110_1010;//32-bit data witdth     
@(tb_cb);
tb_cb.tb_i_req <= 1'b0;
repeat(100) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test04_cmd_sync)

tb_cb.tb_i_data   <= $urandom();     
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_req  <= 1'b1;
tb_cb.tb_i_header <= 8'b1000_1010;//sync command     
@(tb_cb);
tb_cb.tb_i_req <= 1'b0;
repeat(200) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
