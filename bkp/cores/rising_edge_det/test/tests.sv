`SVTEST(test00_reset)

     `ASSERT_IMMEDIATE(tb_i_data  == '0);     
     @(cb);
     for (integer k = 0; k < 10; k = k + 1) begin
     cb.tb_rstn <= 1'b0;

     @(cb);

     cb.tb_rstn <= 1'b1;

     @(cb);

     `ASSERT_IMMEDIATE(cb.tb_o_data  == '0);     
     @(negedge tb_clk);
    end
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_1bit_data)

    cb.tb_i_data  <= 1'b0;     
    @(cb);
    for (integer k = 0; k < 10; k = k + 1) begin
        cb.tb_i_data <= k;
        repeat($urandom_range(1,100))@(cb);
        //`ASSERT_IMMEDIATE(tb_o_data  == k);     
    end
    repeat(5) @(cb);
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_8bit_data)

    cb.tb_i_data  <= 8'hAB;     
    @(cb);
        for (integer k = 0; k < 10; k = k + 1) begin
          cb.tb_i_data <= k;
          repeat(5)@(cb);
          //`ASSERT_IMMEDIATE(tb_o_data  == k);     
    end
    repeat(10) @(cb);
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
