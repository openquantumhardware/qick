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
`SVTEST(test02_core_to_ps)

    @(cb);
    tb_i_core_data1 <= 32'h0000_0002;     
    tb_i_core_data2 <= 32'h0000_0004;     
    tb_i_core_valid <= 1'b1;     
    repeat(2)@(cb);
    tb_i_core_valid <= 1'b0;     
    repeat(8)@(cb);
    for (integer k = 0; k < 10; k = k + 1) begin
        tb_i_core_valid <= 1'b1;     
        tb_i_core_data1 <= k;
        tb_i_core_data2 <= k+1;
        @(cb);
        tb_i_core_valid <= 1'b0;     
        repeat(10)@(cb);
        
        //if (k > 1) 
        //    `ASSERT_IMMEDIATE(tb_o_data  == k-1);     
    end
    repeat(50) @(cb_core);
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test03_ps_to_time)

    @(cb_ps);
    tb_i_xcom_cfg  <= 32'h0000_00FF;     
    tb_i_xcom_ctrl <= 32'h0000_00AA;     
    tb_i_axi_data1 <= 32'hBEBE_0000;     
    tb_i_axi_data2 <= 32'hFEFE_0000;     
    repeat(2)@(cb_ps);
    tb_i_xcom_cfg  <= 32'h0000_00DD;     
    tb_i_xcom_ctrl <= 32'h0000_00BB;     
    tb_i_axi_data1 <= 32'hA0A0_0000;     
    tb_i_axi_data2 <= 32'hFFFF_0000;     
    repeat(8)@(cb_ps);
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test04_time_to_core)

    @(cb);
    tb_i_core_ready <= 1'b1;     
    tb_i_core_flag  <= 1'b1;     
    tb_i_core_valid <= 1'b1;     
    @(cb);
    tb_i_core_ready <= 1'b0;     
    tb_i_core_flag  <= 1'b0;     
    tb_i_core_valid <= 1'b0;     
    repeat(50)@(cb);
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
//-------------------------------------------------------------------------------------------------//
`SVTEST(test05_time_to_ps)

    @(cb);
    tb_i_core_flag <= 1'b1;     
    tb_i_xcom_id   <= 4'b1010;     
    tb_i_xcom_rx_data <= 32'hDDDD_AAAA;     
    tb_i_xcom_tx_data <= 32'hCCCC_AAAA;     
    tb_i_xcom_status <= 32'hBEBE_AAAA;     
    tb_i_xcom_debug  <= 32'hFFFF_EEEE;     
    repeat(4)@(cb);
    tb_i_core_flag <= 1'b0;     
    tb_i_xcom_id   <= 4'b0010;     
    tb_i_xcom_rx_data <= 32'hAAAA_AAAA;     
    tb_i_xcom_tx_data <= 32'hBBBB_CCCC;     
    tb_i_xcom_status <= 32'hEEEE_AAAA;     
    tb_i_xcom_debug  <= 32'hEEEE_BBBB;     
    repeat(4)@(cb);
    tb_i_core_flag <= 1'b1;     
    tb_i_xcom_id   <= 4'b0110;     
    tb_i_xcom_rx_data <= 32'hBBBD_AAAA;     
    tb_i_xcom_tx_data <= 32'hAACC_AAAA;     
    tb_i_xcom_status <= 32'hBBBB_AAAA;     
    tb_i_xcom_debug  <= 32'hCCCC_EEEE;     
    repeat(50)@(cb);
     
`SVTEST_END
