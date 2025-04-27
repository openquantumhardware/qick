`SVTEST(test00_reset)

     `ASSERT_IMMEDIATE(tb_i_data  == '0);     
     `ASSERT_IMMEDIATE(tb_i_valid == 1'b0);     
     `ASSERT_IMMEDIATE(tb_o_ready == 1'b0);     
     repeat(5) @(negedge tb_clk);
        for (integer k = 0; k < 10; k = k + 1) begin
        tb_rst = 1'b1;

        @(negedge tb_clk);

        tb_rst = 1'b0;

        @(negedge tb_clk);

     `ASSERT_IMMEDIATE(tb_i_data  == '0);     
     `ASSERT_IMMEDIATE(tb_i_valid == 1'b0);     
     `ASSERT_IMMEDIATE(tb_o_ready == 1'b0);     
     @(negedge tb_clk);
    end
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test00_data)

     tb_i_data  = 32'h000A000B;     
     tb_i_valid = 1'b1;     
     tb_o_ready = 1'b0;     
    @(negedge tb_clk);
     tb_o_ready = 1'b1;     
     //repeat(5) @(negedge tb_clk);
        @(negedge tb_clk);
        for (integer k = 0; k < 10; k = k + 1) begin
          tb_i_data = k;
        @(negedge tb_clk);

     `ASSERT_IMMEDIATE(tb_o_data  == k);     
     `ASSERT_IMMEDIATE(tb_o_valid == 1'b1);     
     `ASSERT_IMMEDIATE(tb_o_ready == 1'b1);     
     //@(negedge tb_clk);
    end
    @(negedge tb_clk);
    tb_o_ready = 1'b0;     
    @(negedge tb_clk);
     tb_i_valid = 1'b0;     
    repeat(5) @(negedge tb_clk);
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
