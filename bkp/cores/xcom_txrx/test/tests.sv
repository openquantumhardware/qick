/////////// XCOM ////////////
//     //Opcodes
//     parameter XCOM_RST         = 4'b1111  ;//LOC command
//     parameter XCOM_WRITE_MEM   = 4'b0011  ;//LOC command
//     parameter XCOM_WRITE_REG   = 4'b0010  ;//LOC command
//     parameter XCOM_WRITE_FLAG  = 4'b0001  ;//LOC command
//     parameter XCOM_SET_ID      = 4'b0000  ;//LOC command
//     parameter XCOM_RFU2        = 4'b1111  ;
//     parameter XCOM_RFU1        = 4'b1101  ;
//     parameter XCOM_QCTRL       = 4'b1011  ;
//     parameter XCOM_UPDATE_DT32 = 4'b1110  ;
//     parameter XCOM_UPDATE_DT16 = 4'b1100  ;
//     parameter XCOM_UPDATE_DT8  = 4'b1010  ;
//     parameter XCOM_AUTO_ID     = 4'b1001  ;
//     parameter XCOM_QRST_SYNC   = 4'b1000  ;
//     parameter XCOM_SEND_32BIT_2= 4'b0111  ;
//     parameter XCOM_SEND_32BIT_1= 4'b0110  ;
//     parameter XCOM_SEND_16BIT_2= 4'b0101  ;
//     parameter XCOM_SEND_16BIT_1= 4'b0100  ;
//     parameter XCOM_SEND_8BIT_2 = 4'b0011  ;
//     parameter XCOM_SEND_8BIT_1 = 4'b0010  ;
//     parameter XCOM_SET_FLAG    = 4'b0001  ;
//     parameter XCOM_CLEAR_FLAG  = 4'b0000  ;

`SVTEST(test00_reset)

for (integer k = 0; k < 10; k = k + 1) begin
    tb_cb.tb_rstn <= 1'b0;
    @(tb_cb);
    tb_cb.tb_rstn <= 1'b1;
    @(tb_cb);
end

`SVTEST_END
//Let's start with LOC commands
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_set_loc_id)
   
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0101};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_header  <= {XCOM_AUTO_ID,4'b0101};//change to AUTO ID but not valid
 
repeat(5) @(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_wflag_loc)
   
   tb_cb.tb_i_header  <= {XCOM_WRITE_FLAG,4'b0101};
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_header  <= {XCOM_AUTO_ID,4'b0101};
   @(tb_cb);
   tb_cb.tb_i_header  <= {XCOM_AUTO_ID,4'b0100};
 
repeat(100) @(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test03_wreg_loc)
   
   tb_cb.tb_i_data    <= 32'h0000_FF0F;     
   tb_cb.tb_i_header  <= {XCOM_WRITE_REG,4'b0101};//select data1
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(5)@(tb_cb);
   tb_cb.tb_i_header  <= {XCOM_AUTO_ID,4'b0101};
   @(tb_cb);
   tb_cb.tb_i_header  <= {XCOM_AUTO_ID,4'b0100};
 
repeat(100) @(tb_cb);
 
   tb_cb.tb_i_data    <= 32'h0000_FF04;     
   tb_cb.tb_i_header  <= {XCOM_WRITE_REG,4'b0100};//select data2
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(5)@(tb_cb);
   tb_cb.tb_i_header  <= {XCOM_AUTO_ID,4'b0101};
   @(tb_cb);
   tb_cb.tb_i_header  <= {XCOM_AUTO_ID,4'b0100};
 
repeat(100) @(tb_cb);
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test04_wmem_loc)
   
   tb_cb.tb_i_data    <= 32'h0000_FF0F;     
   tb_cb.tb_i_header  <= {XCOM_WRITE_MEM,4'b0101};//select data1
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(5)@(tb_cb);
   tb_cb.tb_i_header  <= {XCOM_AUTO_ID,4'b0101};
   @(tb_cb);
   tb_cb.tb_i_header  <= {XCOM_AUTO_ID,4'b0100};
 
repeat(100) @(tb_cb);
 
   tb_cb.tb_i_data    <= 32'h0000_FF04;     
   tb_cb.tb_i_header  <= {XCOM_WRITE_MEM,4'b0100};//select data2
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(5)@(tb_cb);
   tb_cb.tb_i_header  <= {XCOM_AUTO_ID,4'b0101};
   @(tb_cb);
   tb_cb.tb_i_header  <= {XCOM_AUTO_ID,4'b0100};
 
repeat(100) @(tb_cb);
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test05_rst_loc)
   
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0101};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(5)@(tb_cb);
   tb_cb.tb_i_data    <= 32'h0000_FF0F;     
   tb_cb.tb_i_header  <= {XCOM_RST,4'b0101};//select data1
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(100)@(tb_cb);
 
`SVTEST_END
//Let's start with NET commands
//-------------------------------------------------------------------------------------------------//
`SVTEST(test06_set_net_id)
   
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
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0101};//change to set ID locally but not validating
 
repeat(50) @(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test07_8bit_data)

tb_cb.tb_i_data   <= $urandom();
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_req_net    <= 1'b1;
tb_cb.tb_i_header  <= {XCOM_SEND_8BIT_1,4'b1010};
@(tb_cb);
tb_cb.tb_i_req_net <= 1'b0;
repeat(50) @(tb_cb);

`SVTEST_END
//----------------------------------------------------------------------------------------------    ---//

`SVTEST(test08_16bit_data)

tb_cb.tb_i_data   <= $urandom();     
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_req_net    <= 1'b1;
tb_cb.tb_i_header  <= {XCOM_SEND_16BIT_1,4'b1010};
@(tb_cb);
tb_cb.tb_i_req_net <= 1'b0;
repeat(100) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test09_32bit_data)

tb_cb.tb_i_data   <= $urandom();     
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_req_net  <= 1'b1;
tb_cb.tb_i_header  <= {XCOM_SEND_32BIT_1,4'b1010};
@(tb_cb);
tb_cb.tb_i_req_net <= 1'b0;
repeat(100) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test10_cmd_sync)

tb_cb.tb_i_data   <= $urandom();     
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_req_net  <= 1'b1;
tb_cb.tb_i_header  <= {XCOM_QRST_SYNC,4'b1010};
@(tb_cb);
tb_cb.tb_i_req_net <= 1'b0;
repeat(200) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
//OK, now we test the reception of commands
//-------------------------------------------------------------------------------------------------//
`SVTEST(test11_set_net_id)
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
`SVTEST(test12_test_qsync)
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
`SVTEST(test13_test_qctrl)
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0111};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(5)@(tb_cb);

   for (int i=2; i<8; i++) begin
   tb_cb.tb_i_data_tx[0]    <= i;//time rst     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_BEBE;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_QCTRL,4'b0111};//QSYNC 
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(200)@(tb_cb);
end
 
//   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0101};//set ID locally
//   tb_cb.tb_i_req_loc <= 1'b1;
//   @(tb_cb);
//   tb_cb.tb_i_req_loc <= 1'b0;
//   repeat($urandom_range(1,20))@(tb_cb);
//
//   tb_cb.tb_i_data_tx[0]    <= 32'h0000_FF0F;     
//   tb_cb.tb_i_data_tx[1]    <= 32'h0000_BEBE;     
//   tb_cb.tb_i_header_tx[0]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
//   tb_cb.tb_i_header_tx[1]  <= {XCOM_QCTRL,4'b0101};//set ID 
//   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
//   tb_cb.tb_i_valid_tx[1]   <= 1'b1;
//   @(tb_cb);
//   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
//   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
//   repeat(200)@(tb_cb);
// 
//   tb_cb.tb_i_data_tx[0]    <= 32'h0000_FF0F;     
//   tb_cb.tb_i_data_tx[1]    <= 32'h0000_BEBE;     
//   tb_cb.tb_i_header_tx[0]  <= {XCOM_QCTRL,4'b0101};//QSYNC 
//   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
//   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
//   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
//   @(tb_cb);
//   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
//   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
//   repeat(200)@(tb_cb);
// 
//   tb_cb.tb_i_data_tx[0]    <= 32'h0000_FF0F;     
//   tb_cb.tb_i_data_tx[1]    <= 32'h0000_BEBE;     
//   tb_cb.tb_i_header_tx[0]  <= {XCOM_QCTRL,4'b0111};//QSYNC 
//   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
//   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
//   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
//   @(tb_cb);
//   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
//   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
//   repeat(200)@(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test14_test_wflg)
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
`SVTEST(test15_test_wreg)
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
`SVTEST(test16_test_wmem)
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
`SVTEST(test17_test_rst)
   tb_cb.tb_i_data    <= 32'h0000_FF0F;     
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0010};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(5)@(tb_cb);

   tb_cb.tb_i_data_tx[0]    <= 32'h0000_0010;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_0011;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_RST,4'b0010};//WMEM header[3:0]=0 broadcast
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(200)@(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test18_send_8bits)
   tb_cb.tb_i_data    <= 32'h0000_FF0F;     
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0010};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(5)@(tb_cb);

   tb_cb.tb_i_data_tx[0]    <= 32'h0000_0010;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_0011;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_SEND_8BIT_1,4'b0010};//WMEM header[3:0]=0 broadcast
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(300)@(tb_cb);
   tb_cb.tb_i_data_tx[0]    <= 32'h0000_0011;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_0011;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_SEND_8BIT_2,4'b0010};//WMEM header[3:0]=0 broadcast
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(200)@(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test19_send_16bits)
   tb_cb.tb_i_data    <= 32'h0000_FF0F;     
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0010};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(5)@(tb_cb);

   tb_cb.tb_i_data_tx[0]    <= 32'h0000_0011;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_0011;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_SEND_16BIT_1,4'b0010};//WMEM header[3:0]=0 broadcast
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(300)@(tb_cb);
   tb_cb.tb_i_data_tx[0]    <= 32'h0000_0011;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_0011;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_SEND_16BIT_2,4'b0010};//WMEM header[3:0]=0 broadcast
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(200)@(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test20_send_32bits)
   tb_cb.tb_i_data    <= 32'h0000_FF0F;     
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0010};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(5)@(tb_cb);

   tb_cb.tb_i_data_tx[0]    <= 32'h0000_0111;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_0011;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_SEND_32BIT_1,4'b0010};//WMEM header[3:0]=0 broadcast
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(300)@(tb_cb);
   tb_cb.tb_i_data_tx[0]    <= 32'h0000_0011;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_0011;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_SEND_32BIT_2,4'b0010};//WMEM header[3:0]=0 broadcast
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(200)@(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test21_update_dt8)
   tb_cb.tb_i_data    <= 32'h0000_FF0F;     
   tb_cb.tb_i_header  <= {XCOM_SET_ID,4'b0010};//set ID locally
   tb_cb.tb_i_req_loc <= 1'b1;
   @(tb_cb);
   tb_cb.tb_i_req_loc <= 1'b0;
   repeat(50)@(tb_cb);

   tb_cb.tb_i_data_tx[0]    <= 32'h0000_0010;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_0011;     
   tb_cb.tb_i_data          <= 32'h0000_FF0F;     
   tb_cb.tb_i_header        <= {XCOM_SET_ID,4'b1010};//ADDR=10
   tb_cb.tb_i_header_tx[0]  <= {XCOM_UPDATE_DT8,4'b0010};//WMEM header[3:0]=0 broadcast
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(300)@(tb_cb);
   tb_cb.tb_i_data_tx[0]    <= 32'h0000_0011;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_0011;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_UPDATE_DT16,4'b0010};//WMEM header[3:0]=0 broadcast
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(200)@(tb_cb);
   tb_cb.tb_i_data_tx[0]    <= 32'h0000_0111;     
   tb_cb.tb_i_data_tx[1]    <= 32'h0000_0011;     
   tb_cb.tb_i_header_tx[0]  <= {XCOM_UPDATE_DT32,4'b0010};//WMEM header[3:0]=0 broadcast
   tb_cb.tb_i_header_tx[1]  <= {XCOM_AUTO_ID,4'b0111};//set ID 
   tb_cb.tb_i_valid_tx[0]   <= 1'b1;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   @(tb_cb);
   tb_cb.tb_i_valid_tx[0]   <= 1'b0;
   tb_cb.tb_i_valid_tx[1]   <= 1'b0;
   repeat(200)@(tb_cb);
 
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
