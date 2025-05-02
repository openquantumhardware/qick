`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module xcom_link_rx_unit_test;
import svunit_pkg::svunit_testcase;

  string name = "xcom_link_rx_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]

  localparam NB               = 32;

  logic        tb_clk         = 1'b0;
  logic        tb_rstn        = 1'b1;
  logic        tb_i_valid     = 1'b0;
  logic [ 4:0] tb_i_op        = 5'b00000; 
  logic [ 3:0] tb_i_addr      = 4'b0000; 
  logic [31:0] tb_i_data      = 32'h00000000; 
  logic [4-1:0] tb_i_id        = 1'b0;
  logic        tb_o_req_loc   ;
  logic        tb_o_req_net   ;
  logic [ 7:0] tb_o_op        ;
  logic [31:0] tb_o_data      ;
  logic [ 3:0] tb_o_data_cntr ;

  logic [NB-1:0] random_data;

initial begin
  $dumpfile("xcom_link_rx.vcd");
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
  output  tb_i_id          ;
  output  tb_i_valid       ;
  output  tb_i_op          ;
  output  tb_i_addr        ;
  output  tb_i_data        ;

  input   tb_o_req         ;
  input   tb_o_req_net     ;
  input   tb_o_op          ;
  input   tb_o_data        ;
  input   tb_o_data_cntr   ;
endclocking

//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================

xcom_link_rx
u_xcom_link_rx
(
  .i_clk      (tb_clk        ),
  .i_rstn     (tb_rstn       ),
  .i_id       (tb_i_id       ),
  .o_req      (tb_o_req      ),
  .i_ack      (tb_i_ack      ),
  .o_cmd      (tb_o_cmd      ),
  .o_data     (tb_o_data     ),
  .i_xcom_data(tb_i_xcom_data),
  .i_xcom_clk (tb_i_xcom_clk ), 
  .o_dbg_state(tb_o_dbg_state)
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
    random_data = $urandom();
    tb_cb.tb_i_data  <= '0;
    tb_cb.tb_i_valid <= 1'b0;   
    tb_cb.tb_i_op    <= 5'b0000_1;   
    tb_cb.tb_i_addr  <= 4'b0000;   
    tb_cb.tb_i_data  <= 32'h11223344;   
    tb_cb.tb_i_ack   <= 1'b0; 

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

task automatic write_loc(input logic [NB-1:0] in_data);
    for ( int i = 0 ; i < 10 ; i = i + 1 ) begin
        tb_cb.tb_i_valid <= 1'b1;
        tb_cb.tb_i_op    <= 5'b1_1010;
        tb_cb.tb_i_addr  <= 4'b0010;
        tb_cb.tb_i_data  <= in_data + i;
        @(tb_cb);
        tb_cb.tb_i_valid <= 1'b0;
        tb_cb.tb_i_ack   <= 1'b1;
        @(tb_cb);
        tb_cb.tb_i_ack   <= 1'b0;
        repeat($urandom(10))@(tb_cb);
    end
endtask


`SVUNIT_TESTS_BEGIN
`include "tests.sv"
`SVUNIT_TESTS_END 

endmodule
