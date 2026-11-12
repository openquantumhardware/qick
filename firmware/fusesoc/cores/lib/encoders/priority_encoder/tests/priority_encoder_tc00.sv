// ============================================================================
// File: priority_encoder_tc00.sv
// Description: SVUnit testbench top-level for priority_encoder.
//   Instantiates both output modes (combinational "NO_REG" and the
//   registered mode used in practice by qtt_tag_calc, "TNO_REG") side by
//   side, fed the same stimulus, to exercise both generate branches.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module priority_encoder_unit_test;
   import svunit_pkg::svunit_testcase;

   string name = "priority_encoder_ut";
   svunit_testcase svunit_ut;

   localparam real CLOCK_FREQUENCY = 200e6;
   localparam int  DW = 3; // 2**DW = 8-bit one-hot input

   logic               tb_clk       = 1'b0;
   logic               tb_rstn      = 1'b1;
   logic [7:0]         tb_one_hot   = '0;

   logic [DW-1:0]      tb_bin_comb;
   logic               tb_vld_comb;
   logic [DW-1:0]      tb_bin_reg;
   logic               tb_vld_reg;

   clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

   default clocking cb @(posedge tb_clk);
      output tb_rstn;
      output tb_one_hot;
      input  tb_bin_comb;
      input  tb_vld_comb;
      input  tb_bin_reg;
      input  tb_vld_reg;
   endclocking

   initial begin
      $dumpfile("priority_encoder.vcd");
      $dumpvars();
      $dumpvars();
   end

   priority_encoder #(
      .DW  ( DW       ),
      .OUT ( "NO_REG"  )
   ) dut_comb (
      .clk_i        ( tb_clk      ),
      .rst_ni       ( tb_rstn     ),
      .one_hot_dt_i ( tb_one_hot  ),
      .bin_dt_o     ( tb_bin_comb ),
      .vld_o        ( tb_vld_comb )
   );

   // Matches the exact OUT string used by qtt_tag_calc.sv ("TNO_REG", which
   // is NOT "NO_REG" and therefore selects the registered branch).
   priority_encoder #(
      .DW  ( DW        ),
      .OUT ( "TNO_REG"  )
   ) dut_reg (
      .clk_i        ( tb_clk      ),
      .rst_ni       ( tb_rstn     ),
      .one_hot_dt_i ( tb_one_hot  ),
      .bin_dt_o     ( tb_bin_reg  ),
      .vld_o        ( tb_vld_reg  )
   );

   // Reference model: index of the lowest set bit, and whether any bit is set.
   function automatic void expected(logic [7:0] oh, output logic [DW-1:0] bin, output logic vld);
      int j;
      vld = 1'b0;
      bin = '0;
      for (j = 0; j < 8; j++)
         if (!vld && oh[j]) begin
            vld = 1'b1;
            bin = j[DW-1:0];
         end
   endfunction

   function void build();
      svunit_ut = new(name);
   endfunction

   task setup();
      svunit_ut.setup();
      cb.tb_one_hot <= '0;
      @(cb);
      cb.tb_rstn <= 1'b0;
      repeat(2) @(cb);
      cb.tb_rstn <= 1'b1;
      repeat(3) @(cb);
   endtask

   task teardown();
      svunit_ut.teardown();
   endtask

   `SVUNIT_TESTS_BEGIN
   `include "priority_encoder_tests.sv"
   `SVUNIT_TESTS_END

endmodule
