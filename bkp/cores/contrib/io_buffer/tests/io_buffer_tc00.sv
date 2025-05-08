`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module io_buffer_unit_test;
import svunit_pkg::svunit_testcase;

  string name = "io_buffer_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]

  localparam DWIDTH             = 32;

  logic              tb_clk     = 1'b0;
  logic              tb_rst     = 1'b0;

  logic [DWIDTH-1:0] tb_i_data  = '0;
  logic              tb_i_valid = 1'b0;
  logic              tb_i_ready = 1'b0;

  logic [DWIDTH-1:0] tb_o_data  = '0;
  logic              tb_o_valid = 1'b0;
  logic              tb_o_ready = 1'b0;

initial begin
  $dumpfile("io_buffer.vcd");
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
endclocking

//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================

io_buffer
#(
  .DWIDTH (DWIDTH)
)
u_io_buffer
(
  .i_clk      ( tb_clk ),
  .i_rst      ( tb_rst ),

  .i_data     ( tb_i_data  ),
  .i_valid    ( tb_i_valid ),
  .i_ready    ( tb_i_ready ),
                           
  .o_data     ( tb_o_data  ),
  .o_valid    ( tb_o_valid ),
  .o_ready    ( tb_o_ready )
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
  tb_i_data  = '0;
  tb_i_valid = 1'b0;
  tb_o_ready = 1'b0;
  
  @(negedge tb_clk);
  tb_rst              <= 1'b1;
  repeat(2) @(negedge tb_clk);
  tb_rst              <= 1'b0;
  repeat(5) @(negedge tb_clk);

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
