`SVTEST(test00_reset)

     `ASSERT_IMMEDIATE(tb_i_data  == '0);     
     repeat(5) @(negedge tb_clk);
        for (integer k = 0; k < 10; k = k + 1) begin
        tb_rstn = 1'b0;

        @(negedge tb_clk);

        tb_rstn = 1'b1;

        @(negedge tb_clk);

     `ASSERT_IMMEDIATE(tb_o_data  == '0);     
     @(negedge tb_clk);
    end
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_32bit_data)

    tb_i_data  = 1'b1;     
    @(negedge tb_clk);
    for (integer k = 0; k < 10; k = k + 1) begin
        tb_i_data = k;
        @(negedge tb_clk);
        
        //if (k > 1) 
        //    `ASSERT_IMMEDIATE(tb_o_data  == k-1);     
    end
    repeat(5) @(negedge tb_clk);
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
//`SVTEST(test02_1bit_data)
//
//     tb_i_data  = 1'b1;     
//    @(negedge tb_clk);
//        for (integer k = 0; k < 10; k = k + 1) begin
//          tb_i_data = k;
//        @(negedge tb_clk);
//
//     `ASSERT_IMMEDIATE(tb_o_data  == k);     
//    end
//    repeat(10) @(negedge tb_clk);
//     
//`SVTEST_END
//-------------------------------------------------------------------------------------------------//
