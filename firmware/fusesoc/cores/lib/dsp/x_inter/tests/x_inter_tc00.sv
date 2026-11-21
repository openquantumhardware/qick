// ============================================================================
// File: x_inter_tc00.sv
// Description: SVUnit testbench top-level for x_inter (timestamp bit
//   interpolator: a cfg_inter_i-cycle bit-serial restoring divider computing
//   floor( ((thr-prev) << cfg_inter_i) / (curr-prev) )).
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module x_inter_unit_test;
   import svunit_pkg::svunit_testcase;

   string name = "x_inter_ut";
   svunit_testcase svunit_ut;

   localparam real CLOCK_FREQUENCY = 200e6;
   localparam int  DW = 16;
   localparam int  IW = 4;

   logic               tb_clk     = 1'b0;
   logic               tb_rstn    = 1'b1;
   logic               tb_start   = 1'b0;
   logic [2:0]         tb_cfg_inter = '0;
   logic [DW-1:0]      tb_curr    = '0;
   logic [DW-1:0]      tb_prev    = '0;
   logic [DW-1:0]      tb_thr     = '0;
   logic               tb_end;
   logic               tb_ready;
   logic [IW-1:0]      tb_x_int;

   clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

   default clocking cb @(posedge tb_clk);
      output tb_rstn;
      output tb_start;
      output tb_cfg_inter;
      output tb_curr;
      output tb_prev;
      output tb_thr;
      input  tb_end;
      input  tb_ready;
      input  tb_x_int;
   endclocking

   initial begin
      $dumpfile("x_inter.vcd");
      $dumpvars();
   end

   x_inter #(
      .DW ( DW ),
      .IW ( IW )
   ) dut (
      .clk_i       ( tb_clk       ),
      .rst_ni      ( tb_rstn      ),
      .start_i     ( tb_start     ),
      .cfg_inter_i ( tb_cfg_inter ),
      .curr_i      ( tb_curr      ),
      .prev_i      ( tb_prev      ),
      .thr_i       ( tb_thr       ),
      .end_o       ( tb_end       ),
      .ready_o     ( tb_ready     ),
      .x_int_o     ( tb_x_int     )
   );

   // Reference model: same non-negative restoring division the RTL performs,
   // valid whenever prev <= thr <= curr (guaranteed by how the caller uses
   // this module - interpolating between two filtered samples that bracket
   // the compare threshold).
   function automatic logic [IW-1:0] expected_q(int curr, int prev, int thr, int cfg_inter);
      longint numerator, denom;
      numerator = (thr - prev) <<< cfg_inter;
      denom     = curr - prev;
      if (denom == 0) return '0;
      return (numerator / denom) & ((1 << IW) - 1);
   endfunction

   // Drive one interpolation and wait for end_o, with a timeout so a stuck
   // DUT fails the test instead of hanging the simulation.
   task automatic run_interp(int curr, int prev, int thr, int cfg_inter, output logic [IW-1:0] q, output bit timed_out);
      int cyc;
      `FAIL_UNLESS_LOG(cb.tb_ready === 1'b1, "DUT must be ready before starting a new interpolation");

      cb.tb_curr       <= curr[DW-1:0];
      cb.tb_prev       <= prev[DW-1:0];
      cb.tb_thr        <= thr[DW-1:0];
      cb.tb_cfg_inter  <= cfg_inter[2:0];
      cb.tb_start      <= 1'b1;
      @(cb);
      cb.tb_start      <= 1'b0;

      timed_out = 1'b0;
      cyc = 0;
      while (cb.tb_end !== 1'b1) begin
         @(cb);
         cyc++;
         if (cyc > 20) begin
            timed_out = 1'b1;
            break;
         end
      end
      q = cb.tb_x_int;
   endtask

   function void build();
      svunit_ut = new(name);
   endfunction

   task setup();
      svunit_ut.setup();
      cb.tb_start     <= 1'b0;
      cb.tb_cfg_inter <= '0;
      cb.tb_curr      <= '0;
      cb.tb_prev      <= '0;
      cb.tb_thr       <= '0;
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
   `include "x_inter_tests.sv"
   `SVUNIT_TESTS_END

endmodule
