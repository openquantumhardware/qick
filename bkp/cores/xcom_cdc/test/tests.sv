`SVTEST(test00_reset)

//     `ASSERT_IMMEDIATE(tb_i_data  == '0);     
     repeat(5) @(cb);
        for (integer k = 0; k < 10; k = k + 1) begin
        cb.tb_time_rstn <= 1'b0;
        tb_core_rstn <= 1'b0;
        tb_ps_rstn   <= 1'b0;

        @(cb);

        cb.tb_time_rstn <= 1'b1;
        tb_core_rstn <= 1'b1;
        tb_ps_rstn   <= 1'b1;

        @(cb);

//     `ASSERT_IMMEDIATE(tb_o_data  == '0);     
     @(cb);
    end
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_core_data)

    tb_i_core_op    = 5'b0_1000;     
    tb_i_core_data1 = 32'h0000_0002;     
    tb_i_core_data2 = 32'h0000_0004;     
    tb_i_core_en    = 1'b1;     
    @(negedge tb_core_clk);
    tb_i_core_en    = 1'b0;     
    for (integer k = 0; k < 10; k = k + 1) begin
        tb_i_core_data1 = k;
        tb_i_core_data2 = k+1;
        @(negedge tb_core_clk);
        
        //if (k > 1) 
        //    `ASSERT_IMMEDIATE(tb_o_data  == k-1);     
    end
    repeat(5) @(negedge tb_core_clk);
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
//`SVTEST(test02_1bit_data)
//
//     tb_i_data  = 1'b1;     
//    @(cb);
//        for (integer k = 0; k < 10; k = k + 1) begin
//          tb_i_data = k;
//        @(cb);
//
//     `ASSERT_IMMEDIATE(tb_o_data  == k);     
//    end
//    repeat(10) @(cb);
//     
//`SVTEST_END
//-------------------------------------------------------------------------------------------------//
