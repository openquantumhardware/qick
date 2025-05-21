`SVTEST(test00_reset)

//`ASSERT_IMMEDIATE(tb_cb.tb_o_data  == '0);     
//repeat(5) @(tb_cb);
for (integer k = 0; k < 10; k = k + 1) begin
    tb_cb.tb_rstn <= 1'b0;
    @(tb_cb);
    tb_cb.tb_rstn <= 1'b1;
    @(tb_cb);
    //`ASSERT_IMMEDIATE(tb_cb.tb_o_data  == '0);     
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
`SVTEST(test01_8bit_data)

tb_cb.tb_i_data   <= $urandom();
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_req_net    <= 1'b1;
tb_cb.tb_i_header <= 8'b0010_1010;//8-bit data witdth     
@(tb_cb);
tb_cb.tb_i_req_net <= 1'b0;
repeat(50) @(tb_cb);

`SVTEST_END
//----------------------------------------------------------------------------------------------    ---//

`SVTEST(test02_16bit_data)

tb_cb.tb_i_data   <= $urandom();     
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_req_net    <= 1'b1;
tb_cb.tb_i_header <= 8'b0100_1010;//8-bit data witdth     
@(tb_cb);
tb_cb.tb_i_req_net <= 1'b0;
repeat(100) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test03_32bit_data)

tb_cb.tb_i_data   <= $urandom();     
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_req_net  <= 1'b1;
tb_cb.tb_i_header <= 8'b0110_1010;//32-bit data witdth     
@(tb_cb);
tb_cb.tb_i_req_net <= 1'b0;
repeat(100) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test04_cmd_sync)

tb_cb.tb_i_data   <= $urandom();     
//tb_cb.tb_i_data   <= 32'h0000_0003;     
tb_cb.tb_i_req_net  <= 1'b1;
tb_cb.tb_i_header <= 8'b1000_1010;//sync command     
@(tb_cb);
tb_cb.tb_i_req_net <= 1'b0;
repeat(200) @(tb_cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
