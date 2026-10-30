`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module diff_in_nb_unit_test;
import svunit_pkg::svunit_testcase;

  string name = "diff_in_nb_ut";
  svunit_testcase svunit_ut;

  localparam int NB = 4;

  logic [NB-1:0] tb_i_diff_p = '0;
  logic [NB-1:0] tb_i_diff_n = '1;
  logic [NB-1:0] tb_o_se;

initial begin
  $dumpfile("diff_in_nb.vcd");
  $dumpvars();
end

//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================
diff_in_nb #(
  .NB ( NB )
) u_diff_in_nb (
  .i_diff_p ( tb_i_diff_p ),
  .i_diff_n ( tb_i_diff_n ),
  .o_se     ( tb_o_se     )
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
  tb_i_diff_p = '0;
  tb_i_diff_n = '1;
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
