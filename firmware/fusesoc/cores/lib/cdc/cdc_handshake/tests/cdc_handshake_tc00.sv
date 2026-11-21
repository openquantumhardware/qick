`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module cdc_handshake_unit_test;
import svunit_pkg::svunit_testcase;

  string name = "cdc_handshake_ut";
  svunit_testcase svunit_ut;

  localparam int DW = 8;
  localparam int NS = 2;

  // Source domain is deliberately faster than destination, to exercise the
  // "fast producer, slow consumer" case the handshake is meant to protect.
  localparam real SRC_FREQ = 300e6; //[Hz]
  localparam real DST_FREQ = 100e6; //[Hz]

  logic          tb_i_clk   = 1'b0;
  logic          tb_i_rstn  = 1'b1;
  logic [DW-1:0] tb_i_data  = '0;
  logic          tb_i_valid = 1'b0;
  logic          tb_o_busy;

  logic          tb_o_clk   = 1'b0;
  logic          tb_o_rstn  = 1'b1;
  logic [DW-1:0] tb_o_data;
  logic          tb_o_valid;

initial begin
  $dumpfile("cdc_handshake.vcd");
  $dumpvars();
end

clk_gen #( .FREQ ( SRC_FREQ ) ) u_clk_gen_src (
  .i_enable ( 1'b1     ),
  .o_clk    ( tb_i_clk )
);

clk_gen #( .FREQ ( DST_FREQ ) ) u_clk_gen_dst (
  .i_enable ( 1'b1     ),
  .o_clk    ( tb_o_clk )
);

default clocking src_cb @(posedge tb_i_clk);
  output tb_i_rstn ;
  output tb_i_data ;
  output tb_i_valid;
  input  tb_o_busy ;
endclocking

clocking dst_cb @(posedge tb_o_clk);
  output tb_o_rstn ;
  input  tb_o_data ;
  input  tb_o_valid;
endclocking

//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================
cdc_handshake #(
  .DW ( DW ),
  .NS ( NS )
) u_cdc_handshake (
  .i_clk   ( tb_i_clk   ),
  .i_rstn  ( tb_i_rstn  ),
  .i_data  ( tb_i_data  ),
  .i_valid ( tb_i_valid ),
  .o_busy  ( tb_o_busy  ),

  .o_clk   ( tb_o_clk   ),
  .o_rstn  ( tb_o_rstn  ),
  .o_data  ( tb_o_data  ),
  .o_valid ( tb_o_valid )
);

//===================================
// Helper: send one word and block until the destination domain reports
// o_valid for it (with a generous cycle-count timeout).
//===================================
task automatic send_and_wait(input logic [DW-1:0] data);
  int timeout;

  @(src_cb);
  src_cb.tb_i_data  <= data;
  src_cb.tb_i_valid <= 1'b1;
  @(src_cb);
  src_cb.tb_i_valid <= 1'b0;

  timeout = 0;
  do begin
    @(dst_cb);
    timeout++;
    if (timeout > 200) begin
      `FAIL_IF_LOG(1, "cdc_handshake: timed out waiting for o_valid");
      return;
    end
  end while (!dst_cb.tb_o_valid);
endtask

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
  src_cb.tb_i_valid <= 1'b0;
  src_cb.tb_i_data  <= '0;

  @(src_cb);
  src_cb.tb_i_rstn <= 1'b0;
  dst_cb.tb_o_rstn <= 1'b0;
  repeat(5) @(src_cb);
  src_cb.tb_i_rstn <= 1'b1;
  dst_cb.tb_o_rstn <= 1'b1;
  repeat(5) @(src_cb);
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
