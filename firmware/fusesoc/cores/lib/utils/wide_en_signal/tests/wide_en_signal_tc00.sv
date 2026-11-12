`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module wide_en_signal_unit_test;
import svunit_pkg::svunit_testcase;

  string name = "wide_en_signal_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]

  localparam NB             = 8; //[Hz]

  logic          tb_clk     = 1'b0;
  logic          tb_rstn    = 1'b1;

  logic [NB-1:0] tb_i_data  = 1'b0;
  logic [NB-1:0] tb_o_data  = 1'b0;

initial begin
  $dumpfile("wide_en_signal.vcd");
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


default clocking cb @(posedge tb_clk);
output tb_rstn   ;
output tb_i_data ;
input  tb_o_data ;
endclocking

//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================

wide_en_signal u_wide_en_signal (
  .i_clk  ( tb_clk     ),
  .i_rstn ( tb_rstn    ),
  .i_en   ( tb_i_data  ), 
  .o_en   ( tb_o_data  )
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
  cb.tb_i_data  <= '0;
  
  @(cb);
  cb.tb_rstn             <= 1'b0;
  repeat(2) @(cb);
  cb.tb_rstn             <= 1'b1;
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


`SVUNIT_TESTS_BEGIN
`include "tests.sv"
`SVUNIT_TESTS_END 

endmodule
