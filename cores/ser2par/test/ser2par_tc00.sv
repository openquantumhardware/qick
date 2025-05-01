`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module ser2par_unit_test;
import svunit_pkg::svunit_testcase;

  string name = "ser2par_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]

  // Parameters for the DUT
  parameter DATA_WIDTH_TB = 4;
  parameter SERIAL_WIDTH_TB = 2;

  // Calculate PARALLEL_WIDTH for the testbench
  localparam PARALLEL_WIDTH_TB = DATA_WIDTH_TB / SERIAL_WIDTH_TB;

  localparam NB                 = 32;

  logic                         tb_clk         = 1'b0;
  logic                         tb_rstn        = 1'b1;
  logic                         tb_i_valid     = 1'b0;
  logic                         tb_i_load      = 1'b0;
  logic [SERIAL_WIDTH_TB-1:0]   tb_i_data      = '0; 
  logic                         tb_o_ready     ;
  logic [PARALLEL_WIDTH_TB-1:0] tb_o_data      ;
  logic                         tb_o_clk       ;

  logic [NB-1:0] random_data;

initial begin
  $dumpfile("ser2par.vcd");
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
  output  tb_i_valid       ;
  output  tb_i_load        ;
  output  tb_i_data        ;

  input   tb_o_ready       ;
  input   tb_o_data        ;
  input   tb_o_clk         ;
endclocking

//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================

ser2par #(
  .DATA_WIDTH(DATA_WIDTH_TB),
  .SERIAL_WIDTH(SERIAL_WIDTH_TB)
  ) u_ser2par (
  .i_clk    (tb_clk        ),
  .i_rstn   (tb_rstn       ),
  .i_data   (tb_i_data     ), 
  .i_load   (tb_i_load     ),
  .o_data   (tb_o_data     ),
  .o_ready  (tb_o_ready    )
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
    tb_cb.tb_i_valid  <= 1'b0;   
    tb_cb.tb_i_load   <= 1'b0;   
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
