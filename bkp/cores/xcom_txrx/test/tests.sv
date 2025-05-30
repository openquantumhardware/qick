`SVTEST(test00_reset)

for (integer k = 0; k < 10; k = k + 1) begin
    tb_cb.tb_rstn <= 1'b0;
    @(tb_cb);
    tb_cb.tb_rstn <= 1'b1;
    @(tb_cb);
end

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_set_loc_id)
   
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0101};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   @(tb_cb);
   SIM_TX();
   tb_cb.tb_i_header  <= {XCOM_AUTO_ID,4'b0101};//change to AUTO ID but not valid
   SIM_TX();
   SIM_TX();
 
repeat(5) @(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_set_net_id)
   
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0101};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(20)@(tb_cb);
   tb_cb.tb_i_header  <= {XCOM_AUTO_ID,4'b0101};//set auto ID
   tb_cb.tb_i_req_net <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_net <= 1'b0;
   @(tb_cb);
   SIM_TX();
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0101};//change to set ID locally but not validating
   SIM_TX();
   //tb_cb.tb_i_id <= 4'b1010;
   SIM_TX();
 
repeat(5) @(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test03_set_loc_id)
   
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0101};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   @(tb_cb);
   SIM_TX();
   //tb_cb.tb_i_id <= 4'b0010;
   SIM_TX();
   //tb_cb.tb_i_id <= 4'b1010;
   SIM_TX();
 
repeat(5) @(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test04_8bit_data)

tb_cb.tb_i_data   <= $urandom();
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_req_net    <= 1'b1;
tb_cb.tb_i_header <= 8'b0010_1010;//8-bit data witdth     
@(tb_cb);
tb_cb.tb_i_req_net <= 1'b0;
repeat(50) @(tb_cb);

`SVTEST_END
//----------------------------------------------------------------------------------------------    ---//

`SVTEST(test05_16bit_data)

tb_cb.tb_i_data   <= $urandom();     
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_req_net    <= 1'b1;
tb_cb.tb_i_header <= 8'b0100_1010;//8-bit data witdth     
@(tb_cb);
tb_cb.tb_i_req_net <= 1'b0;
repeat(100) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test06_32bit_data)

tb_cb.tb_i_data   <= $urandom();     
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_req_net  <= 1'b1;
tb_cb.tb_i_header <= 8'b0110_1010;//32-bit data witdth     
@(tb_cb);
tb_cb.tb_i_req_net <= 1'b0;
repeat(100) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test07_cmd_sync)

tb_cb.tb_i_data   <= $urandom();     
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_req_net  <= 1'b1;
tb_cb.tb_i_header <= 8'b1000_1010;//sync command     
@(tb_cb);
tb_cb.tb_i_req_net <= 1'b0;
repeat(200) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
//OK, now we test the reception of commands
`SVTEST(test08_set_net_id)
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0111};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(5)@(tb_cb);

   tb_cb.tb_i_data_tx[0]    <= 32'h0000_FF0F;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_BEBE;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_AUTO_ID,4'b0101};//set ID 
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(200)@(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test09_test_qsync)
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0111};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(5)@(tb_cb);

   tb_cb.tb_i_data_tx[0]    <= 32'h0000_FF0F;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_BEBE;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_QRST_SYNC,4'b0111};//QSYNC 
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(200)@(tb_cb);
 
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0101};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat($urandom_range(1,20))@(tb_cb);

   tb_cb.tb_i_data_tx[0]    <= 32'h0000_FF0F;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_BEBE;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_header_tx[1]  <= {XCOM_QRST_SYNC,4'b0101};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(200)@(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test10_test_qctrl)
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0111};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(5)@(tb_cb);

   tb_cb.tb_i_data_tx[0]    <= 32'h0000_FF0F;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_BEBE;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_QCTRL,4'b0111};//QSYNC 
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(200)@(tb_cb);
 
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0101};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat($urandom_range(1,20))@(tb_cb);

   tb_cb.tb_i_data_tx[0]    <= 32'h0000_FF0F;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_BEBE;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_header_tx[1]  <= {XCOM_QCTRL,4'b0101};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(200)@(tb_cb);
 
   tb_cb.tb_i_data_tx[0]    <= 32'h0000_FF0F;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_BEBE;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_QCTRL,4'b0101};//QSYNC 
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(200)@(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test11_test_wflg)
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0001};//set ID locally
   //tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(5)@(tb_cb);

   tb_cb.tb_i_data_tx[0]    <= 32'h0000_0000;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_BEBE;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_WRITE_FLAG,4'b0000};//WFLG 
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(200)@(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test12_test_wreg)
   tb_cb.tb_i_data    <= 32'h0000_FF0F;     
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0010};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(5)@(tb_cb);

   tb_cb.tb_i_data_tx[0]    <= 32'h0000_0010;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_0011;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_WRITE_REG,4'b0010};//WREG header[3:0]=0 broadcast
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(200)@(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test13_test_wmem)
   tb_cb.tb_i_data    <= 32'h0000_FF0F;     
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0010};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(5)@(tb_cb);

   tb_cb.tb_i_data_tx[0]    <= 32'h0000_0010;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_0011;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_WRITE_MEM,4'b1000};//WMEM header[3:0]=0 broadcast
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(200)@(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
