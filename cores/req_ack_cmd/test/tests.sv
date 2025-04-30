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

tb_cb.tb_i_data  <= 1'b1;     
tb_cb.tb_i_valid <= 1'b1;
@(tb_cb);
tb_cb.tb_i_valid <= 1'b0;
repeat(5) @(tb_cb);

tb_cb.tb_i_op <= 5'b1000_0;
@(tb_cb);
for (integer k = 0; k < 10; k = k + 1) begin
    tb_cb.tb_i_data <= k;
    @(tb_cb);

    //if (k > 1) 
    //    `ASSERT_IMMEDIATE(tb_o_data  == k-1);     
end
repeat(5) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_data)

    random_data  = $urandom();     
    @(tb_cb);
    write_loc(random_data);

    //`ASSERT_IMMEDIATE(tb_o_data  == k);     
    repeat(10) @(tb_cb);
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
