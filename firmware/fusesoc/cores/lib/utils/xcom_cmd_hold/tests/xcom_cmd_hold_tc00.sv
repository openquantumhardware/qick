// ============================================================================
// File: xcom_cmd_hold_tc00.sv
// Description: SVUnit testbench top-level for xcom_cmd_hold: the source-clock side of
//   xcom's AXI command path (CTRL_REG bit 0 / bits [5:1]).
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module xcom_cmd_hold_unit_test;
   import svunit_pkg::svunit_testcase;

   localparam int HOLD = 6;
   localparam logic [4:0] OP_A = 5'b10000;   // XCOM_SET_ID
   localparam logic [4:0] OP_B = 5'b00001;   // XCOM_SET_FLAG

   string name = "xcom_cmd_hold_ut";
   svunit_testcase svunit_ut;

   logic        tb_clk    = 1'b0;
   logic        tb_rstn   = 1'b1;
   logic        tb_strobe = 1'b0;
   logic [4:0]  tb_op     = '0;
   wire         h_en;
   wire  [4:0]  h_op;

   clk_gen #(.FREQ (100e6)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

   initial begin
      $dumpfile("xcom_cmd_hold.vcd");
      $dumpvars();
   end

   xcom_cmd_hold #(.HOLD (HOLD)) dut (
      .clk_i (tb_clk), .rst_ni (tb_rstn), .strobe_i (tb_strobe), .op_i (tb_op), .en_o (h_en), .op_o (h_op));

   // One-clock command strobe, as CTRL_REG[0] produces it when read straight from o_slv_regs.
   task automatic strobe_cmd(logic [4:0] op);
      @(posedge tb_clk);
      tb_strobe <= 1'b1;
      tb_op     <= op;
      @(posedge tb_clk);
      tb_strobe <= 1'b0;
      tb_op     <= '0;
   endtask

   // A CTRL_REG that is never cleared: the strobe (and the opcode) stay asserted at a fixed
   // value for `cycles` clocks, the way xcom's software leaves CTRL_REG after a write.
   task automatic hold_level(logic [4:0] op, int cycles);
      @(posedge tb_clk);
      tb_strobe <= 1'b1;
      tb_op     <= op;
      repeat (cycles) @(posedge tb_clk);
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
   `include "xcom_cmd_hold_tests.sv"
   `SVUNIT_TESTS_END

endmodule
