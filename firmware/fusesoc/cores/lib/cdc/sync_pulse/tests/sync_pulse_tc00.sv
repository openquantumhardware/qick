// ============================================================================
// File: sync_pulse_tc00.sv
// Description: SVUnit testbench top-level for sync_pulse. Two DUTs are
//   instantiated side by side (BLOCK=0 and BLOCK=1) sharing the same clocks,
//   with independent stimulus, to exercise both generate branches.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module sync_pulse_unit_test;
   import svunit_pkg::svunit_testcase;

   string name = "sync_pulse_ut";
   svunit_testcase svunit_ut;

   localparam int  QUEUE_AW = 3; // small on purpose: makes the queue easy to fill in a test

   // Domain A is deliberately faster than B, same "fast producer, slow
   // consumer" convention used by the other CDC testbenches in this repo.
   localparam real A_FREQ = 300e6;
   localparam real B_FREQ = 100e6;

   logic tb_a_clk  = 1'b0;
   logic tb_a_rstn = 1'b1;
   logic tb_b_clk  = 1'b0;
   logic tb_b_rstn = 1'b1;

   // No-block DUT stimulus/observation
   logic tb_a_pulse_nb = 1'b0;
   logic tb_b_en_nb    = 1'b0;
   logic tb_b_pulse_nb;
   logic tb_full_nb;

   // Blocking DUT stimulus/observation
   logic tb_a_pulse_bl = 1'b0;
   logic tb_b_en_bl    = 1'b0;
   logic tb_b_pulse_bl;
   logic tb_full_bl;

   clk_gen #(.FREQ (A_FREQ)) u_clk_a (.i_enable(1'b1), .o_clk(tb_a_clk));
   clk_gen #(.FREQ (B_FREQ)) u_clk_b (.i_enable(1'b1), .o_clk(tb_b_clk));

   default clocking a_cb @(posedge tb_a_clk);
      output tb_a_rstn;
      output tb_a_pulse_nb;
      output tb_a_pulse_bl;
      input  tb_full_nb;
      input  tb_full_bl;
   endclocking

   clocking b_cb @(posedge tb_b_clk);
      output tb_b_rstn;
      output tb_b_en_nb;
      output tb_b_en_bl;
      input  tb_b_pulse_nb;
      input  tb_b_pulse_bl;
   endclocking

   initial begin
      $dumpfile("sync_pulse.vcd");
      $dumpvars();
      $dumpvars();
   end

   sync_pulse #(
      .QUEUE_AW ( QUEUE_AW ),
      .BLOCK    ( 0        )
   ) dut_noblock (
      .a_clk_i    ( tb_a_clk      ),
      .a_rst_ni   ( tb_a_rstn     ),
      .a_pulse_i  ( tb_a_pulse_nb ),
      .b_clk_i    ( tb_b_clk      ),
      .b_rst_ni   ( tb_b_rstn     ),
      .b_en_i     ( tb_b_en_nb    ),
      .b_pulse_o  ( tb_b_pulse_nb ),
      .pulse_full ( tb_full_nb    )
   );

   sync_pulse #(
      .QUEUE_AW ( QUEUE_AW ),
      .BLOCK    ( 1        )
   ) dut_block (
      .a_clk_i    ( tb_a_clk      ),
      .a_rst_ni   ( tb_a_rstn     ),
      .a_pulse_i  ( tb_a_pulse_bl ),
      .b_clk_i    ( tb_b_clk      ),
      .b_rst_ni   ( tb_b_rstn     ),
      .b_en_i     ( tb_b_en_bl    ),
      .b_pulse_o  ( tb_b_pulse_bl ),
      .pulse_full ( tb_full_bl    )
   );

   // Wait (with a timeout) for b_pulse to assert on the no-block DUT.
   task automatic wait_pulse_nb(output bit timed_out);
      int cyc;
      timed_out = 1'b0;
      cyc = 0;
      while (b_cb.tb_b_pulse_nb !== 1'b1) begin
         @(b_cb);
         cyc++;
         if (cyc > 200) begin
            timed_out = 1'b1;
            return;
         end
      end
   endtask

   // Drive n back-to-back single-cycle a_pulse_i pulses (one per a_clk cycle).
   task automatic send_pulses_nb(int n);
      repeat(n) begin
         a_cb.tb_a_pulse_nb <= 1'b1;
         @(a_cb);
      end
      a_cb.tb_a_pulse_nb <= 1'b0;
      @(a_cb);
   endtask

   task automatic send_pulses_bl(int n);
      repeat(n) begin
         a_cb.tb_a_pulse_bl <= 1'b1;
         @(a_cb);
      end
      a_cb.tb_a_pulse_bl <= 1'b0;
      @(a_cb);
   endtask

   // Count b_pulse_nb pulses seen over max_cycles b_clk cycles.
   task automatic count_pulses_nb(int max_cycles, output int count);
      int c;
      count = 0;
      for (c = 0; c < max_cycles; c++) begin
         @(b_cb);
         if (b_cb.tb_b_pulse_nb) count++;
      end
   endtask

   task automatic count_pulses_bl(int max_cycles, output int count);
      int c;
      count = 0;
      for (c = 0; c < max_cycles; c++) begin
         @(b_cb);
         if (b_cb.tb_b_pulse_bl) count++;
      end
   endtask

   // Poll pulse_full (block DUT, sampled on the a_cb) until it asserts, with
   // a timeout.
   task automatic wait_full_bl(output bit timed_out);
      int cyc;
      timed_out = 1'b0;
      cyc = 0;
      while (a_cb.tb_full_bl !== 1'b1) begin
         @(a_cb);
         cyc++;
         if (cyc > 200) begin
            timed_out = 1'b1;
            return;
         end
      end
   endtask

   function void build();
      svunit_ut = new(name);
   endfunction

   task setup();
      svunit_ut.setup();
      a_cb.tb_a_pulse_nb <= 1'b0;
      a_cb.tb_a_pulse_bl <= 1'b0;
      b_cb.tb_b_en_nb    <= 1'b0;
      b_cb.tb_b_en_bl    <= 1'b0;

      @(a_cb);
      a_cb.tb_a_rstn <= 1'b0;
      b_cb.tb_b_rstn <= 1'b0;
      repeat(5) @(a_cb);
      a_cb.tb_a_rstn <= 1'b1;
      b_cb.tb_b_rstn <= 1'b1;
      repeat(5) @(a_cb);
   endtask

   task teardown();
      svunit_ut.teardown();
   endtask

   `SVUNIT_TESTS_BEGIN
   `include "sync_pulse_tests.sv"
   `SVUNIT_TESTS_END

endmodule
