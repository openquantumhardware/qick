`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module req_ack_cmd_unit_test;
import svunit_pkg::svunit_testcase;

  string name = "req_ack_cmd_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]

  localparam N                 = 4;

  logic        tb_clk     = 1'b0;
  logic        tb_rstn    = 1'b1;
  logic        tb_i_valid     ;
  logic [ 4:0] tb_i_op        ; 
  logic [ 3:0] tb_i_addr      ; 
  logic [31:0] tb_i_data      ; 
  logic        tb_i_ack       ;
  logic        tb_o_req_loc   ;
  logic        tb_o_req_net   ;
  logic [ 7:0] tb_o_op        ;
  logic [31:0] tb_o_data      ;
  logic [ 3:0] tb_o_data_cntr ;


initial begin
  $dumpfile("req_ack_cmd.vcd");
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

req_ack_cmd
#(
  .N (N)
)
u_req_ack_cmd
(
  .i_clk      ( tb_clk       ),
  .i_rstn     ( tb_rstn      ),
  .i_valid    (tb_i_valid    ),
  .i_op       (tb_i_op       ),
  .i_addr     (tb_i_addr     ), 
  .i_data     (tb_i_data     ), 
  .i_ack      (tb_i_ack      ) ,
  .o_req_loc  (tb_o_req_loc  ) ,
  .o_req_net  (tb_o_req_net  ) ,
  .o_op       (tb_o_op       ) ,
  .o_data     (tb_o_data     ) ,
  .o_data_cntr(tb_o_data_cntr)

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
  tb_i_valid =1'b0;   
  tb_i_op    =5'b0000_1;   
  tb_i_addr  =4'b0000;   
  tb_i_data  =32'h1234;   
  tb_i_ack   =1'b0   
  
  @(negedge tb_clk);
  tb_rstn             <= 1'b0;
  repeat(2) @(negedge tb_clk);
  tb_rstn             <= 1'b1;
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
