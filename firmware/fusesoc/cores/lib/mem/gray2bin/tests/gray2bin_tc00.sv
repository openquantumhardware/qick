`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module gray2bin_unit_test;
import svunit_pkg::svunit_testcase;

  string name = "gray2bin_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]

  localparam B = 8;

  logic          tb_clk     = 1'b0;

  logic [B-1:0] tb_i_data  = '0;
  logic [B-1:0] tb_o_data  = '0;

initial begin
  $dumpfile("gray2bin.vcd");
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

//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================

gray2bin
#(
    .B(B)
    ) u_gray2bin (
  .din    ( tb_i_data  ),
  .dout   ( tb_o_data  )
);

//===================================
// Reference function (same algorithm,
// used only for self-checking)
//===================================

function automatic logic [B-1:0] gray2bin_ref (input logic [B-1:0] gray);
    gray2bin_ref[B-1] = gray[B-1];
    for (int i = B-2; i >= 0; i--) begin
        gray2bin_ref[i] = gray2bin_ref[i+1] ^ gray[i];
    end
endfunction

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
  tb_i_data  <= '0;
  #1;
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
