// ============================================================================
// File: qtt_cmd_hold_tc00.sv
// Description: SVUnit testbench top-level for qtt_cmd_hold: the source-clock side of the
//   qick_time_tagger AXI command path. The skew-versus-legacy-path test needs qtt_cmd as
//   well and lives in qtt_cmd's bench.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qtt_cmd_hold_unit_test;
   import svunit_pkg::svunit_testcase;

   localparam int HOLD = 6;
   localparam logic [4:0] OP_A = 5'b00100;   // set threshold
   localparam logic [4:0] OP_B = 5'b00101;   // set dead time

   string name = "qtt_cmd_hold_ut";
   svunit_testcase svunit_ut;

   logic        tb_clk    = 1'b0;
   logic        tb_rstn   = 1'b1;
   logic        tb_strobe = 1'b0;
   logic [4:0]  tb_op     = '0;
   wire         h_en;
   wire  [4:0]  h_op;

   clk_gen #(.FREQ (100e6)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

   initial begin
      $dumpfile("qtt_cmd_hold.vcd");
      $dumpvars();
   end

   qtt_cmd_hold #(.HOLD (HOLD)) dut (
      .clk_i (tb_clk), .rst_ni (tb_rstn), .strobe_i (tb_strobe), .op_i (tb_op), .en_o (h_en), .op_o (h_op));

   // One-clock command strobe, as the CTRL register produces it.
   task automatic strobe_cmd(logic [4:0] op);
      @(posedge tb_clk);
      tb_strobe <= 1'b1;
      tb_op     <= op;
      @(posedge tb_clk);
      tb_strobe <= 1'b0;
      tb_op     <= '0;
   endtask

   function void build();
      svunit_ut = new(name);
   endfunction

   task setup();
      svunit_ut.setup();
      tb_strobe = 1'b0;
      tb_op     = '0;
      tb_rstn   = 1'b0;
      repeat (4) @(posedge tb_clk);
      tb_rstn   = 1'b1;
      repeat (4) @(posedge tb_clk);
   endtask

   task teardown();
      svunit_ut.teardown();
   endtask

   `SVUNIT_TESTS_BEGIN
   `include "qtt_cmd_hold_tests.sv"
   `SVUNIT_TESTS_END

endmodule
