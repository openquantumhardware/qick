`SVTEST(test00_reset)

//     `ASSERT_IMMEDIATE(tb_i_data  == '0);     
     repeat(5) @(cb);
        for (integer k = 0; k < 10; k = k + 1) begin
        tb_time_rstn <= 1'b0;
        @(cb);
        tb_time_rstn <= 1'b1;
        @(cb);
//     `ASSERT_IMMEDIATE(tb_o_data  == '0);     
     @(cb);
 end

     repeat(5) @(cb_core);
        for (integer k = 0; k < 10; k = k + 1) begin
        tb_core_rstn <= 1'b0;
        @(cb_core);
        tb_core_rstn <= 1'b1;
        @(cb_core);
//     `ASSERT_IMMEDIATE(tb_o_data  == '0);     
     @(cb_core);
    end

     repeat(2) @(cb_ps);
        for (integer k = 0; k < 10; k = k + 1) begin
        tb_ps_rstn   <= 1'b0;
        @(cb_ps);
        tb_ps_rstn   <= 1'b1;
        @(cb_ps);
//     `ASSERT_IMMEDIATE(tb_o_data  == '0);     
     @(cb_ps);
 end
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_core_to_time)

    @(cb_core);
    tb_i_core_op    <= 5'b0_1000;     
    tb_i_core_data1 <= 32'h0000_0002;     
    tb_i_core_data2 <= 32'h0000_0004;     
    tb_i_core_en    <= 1'b1;     
    @(cb_core);
    tb_i_core_en    <= 1'b0;     
    for (integer k = 0; k < 10; k = k + 1) begin
        tb_i_core_data1 <= k;
        tb_i_core_data2 <= k+1;
        @(cb_core);
        
        //if (k > 1) 
        //    `ASSERT_IMMEDIATE(tb_o_data  == k-1);     
    end
    repeat(5) @(cb_core);
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
