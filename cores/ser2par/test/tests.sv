`SVTEST(test01_s2d4p2)
// Test case 1: Serial width = 2, Data width = 4 (PARALLEL_WIDTH = 2)
        $display("------------------ Test Case 1: DW=4, SW=2 ------------------");
        //DATA_WIDTH_TB = 4;
        //SERIAL_WIDTH_TB = 2;
        #10;
        tb_i_load = 1; #5 tb_i_load = 0; // Assert load_en for one clock cycle

        tb_i_data = 2'b01; #10;
        tb_i_data = 2'b10; #10;

        #10;
        $display("Time=%0t: Parallel Out = %b, Data Ready = %b (Expected: %b, %b)",
                 $time, tb_o_data, tb_o_ready, 4'b1001, 1'b1);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//

//`SVTEST(test00_reset)
//
//`ASSERT_IMMEDIATE(tb_cb.tb_o_data  == '0);     
//repeat(5) @(tb_cb);
//for (integer k = 0; k < 10; k = k + 1) begin
//    tb_cb.tb_rstn <= 1'b0;
//    @(tb_cb);
//    tb_cb.tb_rstn <= 1'b1;
//    @(tb_cb);
//    `ASSERT_IMMEDIATE(tb_cb.tb_o_data  == '0);     
//    @(tb_cb);
//end
//
//`SVTEST_END
////-------------------------------------------------------------------------------------------------//
//`SVTEST(test01_32bit_data)
//
//tb_cb.tb_i_data  <= 1'b1;     
//tb_cb.tb_i_valid <= 1'b1;
//@(tb_cb);
//tb_cb.tb_i_valid <= 1'b0;
//repeat(5) @(tb_cb);
//
////tb_cb.tb_i_op <= 5'b1000_0;
//@(tb_cb);
//for (integer k = 0; k < 10; k = k + 1) begin
//    tb_cb.tb_i_data <= k;
//    @(tb_cb);
//
//    //if (k > 1) 
//    //    `ASSERT_IMMEDIATE(tb_o_data  == k-1);     
//end
//repeat(5) @(tb_cb);
//
//`SVTEST_END
////-------------------------------------------------------------------------------------------------//
//`SVTEST(test02_data)
//
//    random_data  = $urandom();     
//    @(tb_cb);
//    write_loc(random_data);
//
//    //`ASSERT_IMMEDIATE(tb_o_data  == k);     
//    repeat(10) @(tb_cb);
//     
//`SVTEST_END
////-------------------------------------------------------------------------------------------------//
