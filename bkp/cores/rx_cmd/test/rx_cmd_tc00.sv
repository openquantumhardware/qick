`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module rx_cmd_unit_test;
import svunit_pkg::svunit_testcase;

  string name = "rx_cmd_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]
  localparam SYNC_PULSE_FREQ = 5e6; //[Hz]

  localparam NB                 = 32;

  logic          tb_clk         = 1'b0;
  logic          tb_rstn        = 1'b1;
  logic          tb_i_sync      = 1'b0;
  logic [ 4-1:0] tb_i_cfg_tick  = 4'b0000;
  logic          tb_i_req       = 1'b0;
  logic          tb_i_valid     = 1'b0;
  logic [ 8-1:0] tb_i_header    = 8'b0000_0000;
  logic [NB-1:0] tb_i_data      = 32'h00000000; 
  logic          tb_o_ready     ;
  logic          tb_o_data      ;
  logic          tb_o_clk       ;
  logic [2-1:0]  tb_o_dbg_state ; 

initial begin
  $dumpfile("rx_cmd.vcd");
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
  output  tb_i_cfg_tick    ;
  output  tb_i_req         ;
  output  tb_i_valid       ;
  output  tb_i_header      ;
  output  tb_i_data        ;

  input   tb_o_ready       ;
  input   tb_o_data        ;
  input   tb_o_clk         ;
  input   tb_o_dbg_state   ;
endclocking

initial begin
  tb_i_sync <= 1'b0;
  forever # (200) tb_i_sync <= ~tb_i_sync;  
end 



//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================

rx_cmd
u_rx_cmd
(
  .i_clk      ( tb_clk         ),
  .i_rstn     ( tb_rstn        ),
  .i_sync     ( tb_i_sync      ),
  .i_cfg_tick ( tb_i_cfg_tick  ),
  .i_req      ( tb_i_req       ),
  .i_header   ( tb_i_header    ),
  .i_data     ( tb_i_data      ), 
  .o_ready    ( tb_o_ready     ),
  .o_data     ( tb_o_data      ),
  .o_clk      ( tb_o_clk       ),
  .o_dbg_state( tb_o_dbg_state )
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
    tb_cb.tb_i_cfg_tick <= 4'h2;//N clock cycles in 1/0. Invalid values here 0 and 1. Bit LSB is always 0
    tb_cb.tb_i_req      <= 1'b0;   
    tb_cb.tb_i_valid    <= 1'b0;   
    tb_cb.tb_i_header   <= 8'h00;   
    tb_cb.tb_i_data     <= '0;

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

`SVUNIT_TESTS_BEGIN
`include "tests.sv"
`SVUNIT_TESTS_END 

endmodule
