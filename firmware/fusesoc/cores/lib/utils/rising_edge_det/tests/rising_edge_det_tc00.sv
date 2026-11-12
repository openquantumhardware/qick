`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module rising_edge_det_unit_test;
import svunit_pkg::svunit_testcase;

  string name = "rising_edge_det_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]
  localparam NB              = 8;

  logic          tb_clk    = 1'b0;
  logic          tb_rstn   = 1'b1;
  logic          tb_strobe = 1'b0;   // i_strobe stimulus (1-bit level input)
  logic          tb_pulse  = 1'b0;   // o_pulse observed output

initial begin
  $dumpfile("rising_edge_det.vcd");
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
  output tb_strobe ;
  input  tb_pulse  ;
endclocking

//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================
rising_edge_det u_rising_edge_det (
  .i_clk    ( tb_clk    ),
  .i_rstn   ( tb_rstn   ),
  .i_strobe ( tb_strobe ),
  .o_pulse  ( tb_pulse  )
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
  cb.tb_strobe <= 1'b0;

  @(cb);
  cb.tb_rstn   <= 1'b0;
  repeat(2) @(cb);
  cb.tb_rstn   <= 1'b1;
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
//===================================
`SVUNIT_TESTS_BEGIN
`include "tests.sv"
`SVUNIT_TESTS_END

endmodule