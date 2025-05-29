`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module xcom_link_rx_unit_test;
import svunit_pkg::svunit_testcase;
import qick_pkg::*;

  string name = "xcom_link_rx_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]

  localparam NB               = 32;

  logic          tb_clk         = 1'b0;
  logic          tb_rstn        = 1'b1;

//tx
  logic [ 4-1:0] tb_i_cfg_tick  = 4'b0000;
  logic          tb_i_valid     = 1'b0;
  logic [ 8-1:0] tb_i_header    = 8'b0000_0000;
  logic [32-1:0] tb_i_data      = 32'h00000000; 
  logic          tb_o_ready     ;

//rx
  logic  [4-1:0] tb_i_id        = 4'b0000;
  logic          tb_o_req       ;
  logic          tb_i_ack       = 1'b0;
  logic  [4-1:0] tb_o_cmd       ;
  logic [32-1:0] tb_o_data      ;
  logic  [5-1:0] tb_o_dbg_state ;

  logic          tb_xcom_data   ; 
  logic          tb_xcom_clk    ; 
  logic  [8-1:0] s_header       ;
  logic [32-1:0] s_data         ;


initial begin
  $dumpfile("xcom_link_rx.vcd");
  $dumpvars();
end

clk_gen
#(
  .FREQ       ( CLOCK_FREQUENCY   )
)
u_clk_gen
(
  .i_enable   ( 1'b1              ),
  .o_clk      ( tb_clk            )
);


clocking tb_cb @(posedge tb_clk);
  default input #1step output #2;
  output  tb_rstn          ;
  output  tb_i_id          ;
//tx
  output  tb_i_cfg_tick    ;
  output  tb_i_valid       ;
  output  tb_i_header      ;
  output  tb_i_data        ;

  input   tb_o_ready       ;

//rx
  output  tb_i_ack         ;

  input   tb_o_req         ;
  input   tb_o_cmd         ;
  input   tb_o_data        ;
  input   tb_o_dbg_state   ;
endclocking

// TX
xcom_link_tx
u_xcom_link_tx
(
  .i_clk      (tb_clk        ),
  .i_rstn     (tb_rstn       ),
  .i_cfg_tick (tb_i_cfg_tick ),
  .i_valid    (tb_i_valid    ),
  .i_header   (tb_i_header   ),
  .i_data     (tb_i_data     ), 
  .o_ready    (tb_o_ready    ),
  .o_data     (tb_xcom_data  ),
  .o_clk      (tb_xcom_clk   )
);

//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================

// RX
xcom_link_rx
u_xcom_link_rx
(
  .i_clk      (tb_clk        ),
  .i_rstn     (tb_rstn       ),
  .i_id       (tb_i_id       ),
  .o_req      (tb_o_req      ),
  .i_ack      (tb_i_ack      ),
  .o_cmd      (tb_o_cmd      ),
  .o_data     (tb_o_data     ),
  .i_xcom_data(tb_xcom_data  ),
  .i_xcom_clk (tb_xcom_clk   ), 
  .o_dbg_state(tb_o_dbg_state)
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
  $display("Starting simulation...");
//tx
    tb_cb.tb_i_cfg_tick <= 4'h0;   
    tb_cb.tb_i_valid    <= 1'b0;   
    tb_cb.tb_i_header   <= 8'h00;   
    tb_cb.tb_i_data     <= '0;

//rx
    tb_cb.tb_i_id        <= 4'b0010; 
    tb_cb.tb_i_ack       <= 1'b0; 

    @(tb_cb);
    tb_cb.tb_rstn    <= 1'b0;
    repeat(2) @(tb_cb);
    tb_cb.tb_rstn    <= 1'b1;
    repeat(5) @(tb_cb);

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
   tb_cb.tb_i_cfg_tick  <= 2;       //one bit every 2 clock cycles
   @(tb_cb);
   tb_cb.tb_i_header <= {XCOM_AUTO_ID,4'b0010}; //no data, should trigger timeout. cmd=AUTO_ID, addr board=2
   tb_cb.tb_i_data   <= 32'd8;
   repeat(100)@(tb_cb);
   TX_DT();
        
   repeat(200)@(tb_cb);
   tb_cb.tb_i_header <= {XCOM_UPDATE_DT8,4'b0010};//8-bit data. cmd=Update DT8, addr board=2
   tb_cb.tb_i_data   <= 32'd16;
   repeat(100)@(tb_cb);
   TX_DT();
        
   repeat(200)@(tb_cb);
   tb_cb.tb_i_header <= {XCOM_UPDATE_DT16,4'b0001};//16-bit data. cmd=Update DT16, addr board=1
   tb_cb.tb_i_data   <= 32'd24;
   repeat(100)@(tb_cb);
   TX_DT();
        
   repeat(200)@(tb_cb);
   tb_cb.tb_i_header <= {XCOM_UPDATE_DT32,4'b0010};//32-bit data. cmd=Update DT32, addr board=10
   tb_cb.tb_i_data   <= 32'd40;
   repeat(100)@(tb_cb);
   TX_DT();
        
   repeat(200)@(tb_cb);
   tb_cb.tb_i_header <= {XCOM_QRST_SYNC,4'b0000};//no data, should trigger timeout. cmd=QRST_SYNC, addr board= broadcast
   tb_cb.tb_i_data   <= 32'd40;
   repeat(100)@(tb_cb);
   TX_DT();
   repeat(500)@(tb_cb);
        
end  
endtask
 
task TX_DT (); begin
   $display("TX_DT");
   tb_cb.tb_i_cfg_tick  <= 2;       //one bit every 2 clock cycles
   wait (tb_cb.tb_o_ready == 1'b1);
   @ (tb_cb);
   tb_cb.tb_i_valid     <= 1;
   wait (tb_cb.tb_o_ready == 1'b0);
   @ (tb_cb);
   tb_cb.tb_i_valid     <= 0;
end
endtask

`SVUNIT_TESTS_BEGIN
`include "tests.sv"
`SVUNIT_TESTS_END 

endmodule
