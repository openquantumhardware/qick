`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module diff_out_nb_unit_test;
import svunit_pkg::svunit_testcase;

  string name = "diff_out_nb_ut";
  svunit_testcase svunit_ut;

  localparam int NB = 4;

  logic [NB-1:0] tb_i_se = '0;
  logic [NB-1:0] tb_o_diff_p;
  logic [NB-1:0] tb_o_diff_n;

initial begin
  $dumpfile("diff_out_nb.vcd");
  $dumpvars();
end

//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================
diff_out_nb #(
  .NB ( NB )
) u_diff_out_nb (
  .i_se     ( tb_i_se     ),
  .o_diff_p ( tb_o_diff_p ),
  .o_diff_n ( tb_o_diff_n )
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
  tb_i_se = '0;
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
//===================================
`SVUNIT_TESTS_BEGIN
`include "tests.sv"
`SVUNIT_TESTS_END

endmodule
