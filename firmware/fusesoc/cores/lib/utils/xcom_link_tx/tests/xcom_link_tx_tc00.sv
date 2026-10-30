`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

`include "qick_pkg.sv"
module xcom_link_tx_unit_test;
  import svunit_pkg::svunit_testcase;
  import qick_pkg::*;

  string name = "xcom_link_tx_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]

  localparam NB                 = 32;

  logic          tb_clk         = 1'b0;
  logic          tb_rstn        = 1'b1;
  logic [ 4-1:0] tb_i_cfg_tick  = 4'b0000;
  logic          tb_i_valid     = 1'b0;
  logic [ 8-1:0] tb_i_header    = 8'b0000_0000;
  logic [32-1:0] tb_i_data      = 32'h00000000; 
  logic          tb_o_ready     ;
  logic          tb_o_data      ;
  logic          tb_o_clk       ;

  initial begin
    $dumpfile("xcom_link_tx.vcd");
    $dumpvars();
  end

  clk_gen#(
    .FREQ       ( CLOCK_FREQUENCY   )
  )u_clk_gen(
    .i_enable   ( 1'b1              ),
    .o_clk      ( tb_clk            )
  );


  clocking cb @(posedge tb_clk);
    default input #1step output #2;
    output  tb_rstn          ;
    output  tb_i_cfg_tick    ;
    output  tb_i_valid       ;
    output  tb_i_header      ;
    output  tb_i_data        ;

    input   tb_o_ready       ;
    input   tb_o_data        ;
    input   tb_o_clk         ;
  endclocking

  //===================================
  // This is the UUT that we're
  // running the Unit Tests on
  //===================================

  xcom_link_tx u_xcom_link_tx(
    .i_clk      (tb_clk        ),
    .i_rstn     (tb_rstn       ),
    .i_cfg_tick (tb_i_cfg_tick ),
    .i_valid    (tb_i_valid    ),
    .i_header   (tb_i_header   ),
    .i_data     (tb_i_data     ), 
    .o_ready    (tb_o_ready    ),
    .o_data     (tb_o_data     ),
    .o_clk      (tb_o_clk      )
  );

  //===================================
  // Build
  //===================================

  function void build();
    svunit_ut = new(name);
  endfunction

  //===================================
  // Setup for running the Unit Tests
  //===================================
  task setup();
    svunit_ut.setup();
    cb.tb_i_cfg_tick <= 4'h2;   
    cb.tb_i_valid    <= 1'b0;   
    cb.tb_i_header   <= 8'h00;   
    cb.tb_i_data     <= '0;

    @(cb);
    cb.tb_rstn    <= 1'b0;
    repeat(2) @(cb);
    cb.tb_rstn    <= 1'b1;
    repeat(5) @(cb);

  endtask

  //===================================
  // Here we deconstruct anything we 
  // need after running the Unit Tests
  //===================================
  task teardown();
    svunit_ut.teardown();
  endtask

  //===================================
  // All tests are defined between the
  // SVUNIT_TESTS_BEGIN/END macros
  //
  // Each individual test must be
  // defined between `SVTEST(_NAME_)
  // `SVTEST_END
  //
  // i.e.
  //   `SVTEST(mytest)
  //     <test code>
  //   `SVTEST_END
  //===================================

  task SIM_TX (); begin
    $display("SIM TX");

    cb.tb_i_header <= {XCOM_CLEAR_FLAG,4'b0010}; //no data, should trigger timeout. cmd=AUTO_ID, addr board=2
    cb.tb_i_data   <= 32'd8;
    repeat(10)@(cb);
    TX_DT();

    repeat(200)@(cb);
    cb.tb_i_header <= {XCOM_SET_FLAG,4'b0010}; //no data, should trigger timeout. cmd=AUTO_ID, addr board=2
    //cb.tb_i_data   <= 32'd8;
    cb.tb_i_data   <= $urandom(); 
    repeat(10)@(cb);
    TX_DT();

    repeat(200)@(cb);
    cb.tb_i_header <= {XCOM_SEND_8BIT_1,4'b0010};//8-bit data. cmd=Update DT8, addr board=2
    //cb.tb_i_data   <= 32'd16;
    cb.tb_i_data   <= $urandom(); 
    repeat(10)@(cb);
    TX_DT();

    repeat(200)@(cb);
    cb.tb_i_header <= {XCOM_SEND_8BIT_2,4'b0010};//8-bit data. cmd=Update DT8, addr board=2
    //cb.tb_i_data   <= 32'd16;
    cb.tb_i_data   <= $urandom(); 
    repeat(10)@(cb);
    TX_DT();

    repeat(200)@(cb);
    cb.tb_i_header <= {XCOM_SEND_16BIT_1,4'b0001};//16-bit data. cmd=Update DT16, addr board=1
    //cb.tb_i_data   <= 32'd24;
    cb.tb_i_data   <= $urandom(); 
    repeat(10)@(cb);
    TX_DT();

    repeat(200)@(cb);
    cb.tb_i_header <= {XCOM_SEND_16BIT_2,4'b0001};//16-bit data. cmd=Update DT16, addr board=1
    //cb.tb_i_data   <= 32'd24;
    cb.tb_i_data   <= $urandom(); 
    repeat(10)@(cb);
    TX_DT();

    repeat(200)@(cb);
    cb.tb_i_header <= {XCOM_SEND_32BIT_1,4'b0010};//32-bit data. cmd=Update DT32, addr board=10
    //cb.tb_i_data   <= 32'd40;
    cb.tb_i_data   <= $urandom(); 
    repeat(10)@(cb);
    TX_DT();

    repeat(200)@(cb);
    cb.tb_i_header <= {XCOM_SEND_32BIT_2,4'b0010};//32-bit data. cmd=Update DT32, addr board=10
    //cb.tb_i_data   <= 32'd40;
    cb.tb_i_data   <= $urandom(); 
    repeat(10)@(cb);
    TX_DT();

    repeat(200)@(cb);
    cb.tb_i_header <= {XCOM_QRST_SYNC,4'b0010};//32-bit data. cmd=Update DT32, addr board=10
    //cb.tb_i_data   <= 32'd40;
    cb.tb_i_data   <= $urandom(); 
    repeat(10)@(cb);
    TX_DT();

    repeat(200)@(cb);
    cb.tb_i_header <= {XCOM_AUTO_ID,4'b0010};//32-bit data. cmd=Update DT32, addr board=10
    //cb.tb_i_data   <= 32'd40;
    cb.tb_i_data   <= $urandom(); 
    repeat(10)@(cb);
    TX_DT();

    repeat(200)@(cb);
    cb.tb_i_header <= {XCOM_QCTRL,4'b0010};//32-bit data. cmd=Update DT32, addr board=10
    //cb.tb_i_data   <= 32'd40;
    cb.tb_i_data   <= $urandom(); 
    repeat(10)@(cb);
    TX_DT();

    repeat(200)@(cb);
    cb.tb_i_header <= {XCOM_QRST_SYNC,4'b0000};//no data, should trigger timeout. cmd=QRST_SYNC, addr board= broadcast
    //cb.tb_i_data   <= 32'd40;
    cb.tb_i_data   <= $urandom(); 
    repeat(10)@(cb);
    TX_DT();
    repeat(50)@(cb);

  end  
  endtask

  task TX_DT (); begin
    $display("TX_DT");
    wait (cb.tb_o_ready == 1'b1);
    @ (cb);
    cb.tb_i_valid     <= 1;
    wait (cb.tb_o_ready == 1'b0);
    @ (cb);
    cb.tb_i_valid     <= 0;
  end
  endtask

  `SVUNIT_TESTS_BEGIN
  `include "tests.sv"
  `SVUNIT_TESTS_END 

endmodule
