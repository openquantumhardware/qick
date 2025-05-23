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
`SVTEST(test01_net_req)

    //random_data  = $urandom_range(0,32);     
    random_data  = 32'd8;
    @(tb_cb);
    for (int j=0;j<16;j=j+1) begin
        write_loc(random_data,j);
    end
 
    //`ASSERT_IMMEDIATE(tb_o_data  == k);     
    repeat(10) @(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_loc_req)

    random_data  = $urandom_range(0,32);     
    //random_data  = 32'd8;
    @(tb_cb);
    for (int j=16;j<32;j=j+1) begin
        write_loc(random_data,j);
    end
 
    //`ASSERT_IMMEDIATE(tb_o_data  == k);     
    repeat(10) @(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
