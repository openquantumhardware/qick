`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module xcom_qctrl_unit_test;
import svunit_pkg::svunit_testcase;

  string name = "xcom_qctrl_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]
  localparam SYNC_PULSE_FREQ = 5e6; //[Hz]

  localparam NB                   = 32;

  logic          tb_clk           = 1'b0;
  logic          tb_rstn          = 1'b1;
  logic          tb_i_sync        = 1'b0;
  logic          tb_i_ctrl_req    = 4'b0000;
  logic [3-1:0]  tb_i_ctrl_data   = 1'b0;
  logic          tb_i_sync_req    = 1'b0;
  logic          tb_o_proc_start  ;
  logic          tb_o_proc_stop   ; 
  logic          tb_o_time_rst    ;
  logic          tb_o_time_update ;
  logic          tb_o_core_start  ;
  logic [2-1:0]  tb_o_core_stop   ; 

initial begin
  $dumpfile("xcom_qctrl.vcd");
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

//clk_gen
//#(
//  .FREQ       ( SYNC_PULSE_FREQ   )
//)
//u_sync_pulse
//(
//  .i_enable   ( 1'b1              ),
//  .o_clk      ( tb_i_sync         )
//);

clocking tb_cb @(posedge tb_clk);
  default input #1step output #2;
  output  tb_rstn          ;
  output  tb_i_sync        ;
  output  tb_i_ctrl_req    ;
  output  tb_i_ctrl_data   ;
  output  tb_i_sync_req    ;

  input   tb_o_proc_start  ;
  input   tb_o_proc_stop   ;
  input   tb_o_time_rst    ;
  input   tb_o_time_update ;
  input   tb_o_core_start  ;
  input   tb_o_core_stop   ;
endclocking

initial begin
  tb_i_sync <= 1'b0;
  forever # (200) tb_i_sync <= ~tb_i_sync;  
end 



//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================

xcom_qctrl
u_xcom_qctrl
(
  .i_clk        ( tb_clk           ),
  .i_rstn       ( tb_rstn          ),
  .i_sync       ( tb_i_sync        ),
  .i_ctrl_req   ( tb_i_ctrl_req    ),
  .i_ctrl_data  ( tb_i_ctrl_data   ),
  .i_sync_req   ( tb_i_sync_req    ),
  .o_proc_start ( tb_o_proc_start  ), 
  .o_proc_stop  ( tb_o_proc_stop   ),
  .o_time_rst   ( tb_o_time_rst    ),
  .o_time_update( tb_o_time_update ),
  .o_core_start ( tb_o_core_start  ),
  .o_core_stop  ( tb_o_core_stop   ) 
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
    tb_cb.tb_i_ctrl_req  <= 1'b0;//N clock cycles in 1/0. Invalid values here 0 and 1. Bit LSB is always 0
    tb_cb.tb_i_ctrl_data <= 3'b110;   
    tb_cb.tb_i_sync_req  <= 1'b0;   

    @(tb_cb);
    tb_cb.tb_rstn    <= 1'b0;
    repeat(2) @(tb_cb);
    tb_cb.tb_rstn    <= 1'b1;
    repeat(20) @(tb_cb);

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

`SVUNIT_TESTS_BEGIN
`include "tests.sv"
`SVUNIT_TESTS_END 

endmodule
