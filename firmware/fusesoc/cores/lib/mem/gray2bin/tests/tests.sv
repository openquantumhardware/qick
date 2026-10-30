`SVTEST(test00_specific_values)
    tb_i_data = 8'h00;
    #1;
    `ASSERT_IMMEDIATE(tb_o_data == 8'h00);
    tb_i_data = 8'h01;
    #1;
    `ASSERT_IMMEDIATE(tb_o_data == 8'h01);
    tb_i_data = 8'h03;
    #1;
    `ASSERT_IMMEDIATE(tb_o_data == 8'h02);
    tb_i_data = 8'h02;
    #1;
    `ASSERT_IMMEDIATE(tb_o_data == 8'h03);
    tb_i_data = 8'h08;
    #1;
    `ASSERT_IMMEDIATE(tb_o_data == 8'h0F);
    tb_i_data = 8'hC0;
    #1;
    `ASSERT_IMMEDIATE(tb_o_data == 8'h80);
    tb_i_data = 8'hFE;
    #1;
    `ASSERT_IMMEDIATE(tb_o_data == 8'hAB);
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_range)

    for (integer k = 0; k < 256; k = k + 1) begin
        tb_i_data = k;
        #1;
        `ASSERT_IMMEDIATE(tb_o_data == gray2bin_ref(k));     
    end
      
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_msb_passthrough)

    tb_i_data = 8'hFF;     
    #1;
    `ASSERT_IMMEDIATE(tb_o_data[7] == 1'b1);
    tb_i_data = 8'h7F;     
    #1;
    `ASSERT_IMMEDIATE(tb_o_data[7] == 1'b0);
    tb_i_data = 8'h80;     
    #1;
    `ASSERT_IMMEDIATE(tb_o_data[7] == 1'b1);
      
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
