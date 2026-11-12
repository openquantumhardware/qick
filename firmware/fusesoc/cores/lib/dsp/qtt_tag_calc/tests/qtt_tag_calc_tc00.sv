// ============================================================================
// File: qtt_tag_calc_tc00.sv
// Description: SVUnit testbench top-level for qtt_tag_calc. Two DUTs:
//   dut_plain (CMP_INTER=0, no sub-sample interpolation) and dut_inter
//   (CMP_INTER=4, exercises the x_inter datapath end to end). time_ck_i is
//   held constant throughout so the upper (time-counter) bits of tag_dt_o
//   are trivially predictable regardless of exact pipeline latency; only
//   tag_vld_o (polled, with timeout) gates when a result is sampled.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qtt_tag_calc_unit_test;
   import svunit_pkg::svunit_testcase;

   string name = "qtt_tag_calc_ut";
   svunit_testcase svunit_ut;

   localparam real CLOCK_FREQUENCY = 200e6;
   localparam int  SMP_DW = 16;
   localparam int  SMP_CK = 4;
   localparam logic [28:0] TIME_CK = 29'd5;

   logic                       tb_clk    = 1'b0;
   logic                       tb_rstn   = 1'b1;

   // dut_plain stimulus/observation
   logic                       tb_arm_p     = 1'b0;
   logic                       tb_invert_p  = 1'b0;
   logic                       tb_filter_p  = 1'b0;
   logic [2:0]                 tb_inter_p   = 3'd0;
   logic                       tb_slope_p   = 1'b0;
   logic [SMP_DW-1:0]          tb_th_p      = '0;
   logic [7:0]                 tb_inh_p     = 8'd2;
   logic [SMP_CK*SMP_DW-1:0]   tb_dt_p      = '0;
   logic                       tb_trig_p;
   logic                       tb_vld_p;
   logic [31:0]                tb_tagdt_p;

   // dut_inter stimulus/observation
   logic                       tb_arm_i     = 1'b0;
   logic                       tb_invert_i  = 1'b0;
   logic                       tb_filter_i  = 1'b0;
   logic [2:0]                 tb_inter_i   = 3'd0;
   logic                       tb_slope_i   = 1'b0;
   logic [SMP_DW-1:0]          tb_th_i      = '0;
   logic [7:0]                 tb_inh_i     = 8'd2;
   logic [SMP_CK*SMP_DW-1:0]   tb_dt_i      = '0;
   logic [28:0]                tb_time_i    = TIME_CK;
   logic                       tb_time_cnt  = 1'b0;   // 1: dut_inter's time_ck_i counts up instead of staying at TIME_CK
   logic                       tb_trig_i;
   logic                       tb_vld_i;
   logic [31:0]                tb_tagdt_i;

   clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

   default clocking cb @(posedge tb_clk);
      output tb_rstn;
      output tb_arm_p, tb_invert_p, tb_filter_p, tb_inter_p, tb_slope_p, tb_th_p, tb_inh_p, tb_dt_p;
      output tb_arm_i, tb_invert_i, tb_filter_i, tb_inter_i, tb_slope_i, tb_th_i, tb_inh_i, tb_dt_i;
      output tb_time_cnt;
      input  tb_trig_p, tb_vld_p, tb_tagdt_p;
      input  tb_trig_i, tb_vld_i, tb_tagdt_i;
   endclocking

   always_ff @(posedge tb_clk) tb_time_i <= tb_time_cnt ? tb_time_i + 1'b1 : TIME_CK;

   initial begin
      $dumpfile("qtt_tag_calc.vcd");
      $dumpvars();
      $dumpvars();
   end

   qtt_tag_calc #(
      .CMP_SLOPE ( 0 ),
      .CMP_INTER ( 0 ),
      .SMP_DW    ( SMP_DW ),
      .SMP_CK    ( SMP_CK )
   ) dut_plain (
      .clk_i         ( tb_clk       ),
      .rst_ni        ( tb_rstn      ),
      .arm_i         ( tb_arm_p     ),
      .cfg_invert_i  ( tb_invert_p  ),
      .cfg_filter_i  ( tb_filter_p  ),
      .cfg_inter_i   ( tb_inter_p   ),
      .cfg_slope_i   ( tb_slope_p   ),
      .time_ck_i     ( TIME_CK      ),
      .cmp_th_i      ( tb_th_p      ),
      .cmp_inh_i     ( tb_inh_p     ),
      .dt_i          ( tb_dt_p      ),
      .trig_o        ( tb_trig_p    ),
      .cmp_o         (              ),
      .tag_vld_o     ( tb_vld_p     ),
      .tag_dt_o      ( tb_tagdt_p   ),
      .debug_do      (              )
   );

   qtt_tag_calc #(
      .CMP_SLOPE ( 0 ),
      .CMP_INTER ( 4 ),
      .SMP_DW    ( SMP_DW ),
      .SMP_CK    ( SMP_CK )
   ) dut_inter (
      .clk_i         ( tb_clk       ),
      .rst_ni        ( tb_rstn      ),
      .arm_i         ( tb_arm_i     ),
      .cfg_invert_i  ( tb_invert_i  ),
      .cfg_filter_i  ( tb_filter_i  ),
      .cfg_inter_i   ( tb_inter_i   ),
      .cfg_slope_i   ( tb_slope_i   ),
      .time_ck_i     ( tb_time_i    ),
      .cmp_th_i      ( tb_th_i      ),
      .cmp_inh_i     ( tb_inh_i     ),
      .dt_i          ( tb_dt_i      ),
      .trig_o        ( tb_trig_i    ),
      .cmp_o         (              ),
      .tag_vld_o     ( tb_vld_i     ),
      .tag_dt_o      ( tb_tagdt_i   ),
      .debug_do      (              )
   );

   // Pack SMP_CK signed 16-bit samples (LSB-first, matching dt_i[SMP_DW*i+:SMP_DW]).
   function automatic logic [SMP_CK*SMP_DW-1:0] pack4(int s0, int s1, int s2, int s3);
      logic [SMP_CK*SMP_DW-1:0] v;
      v[1*SMP_DW-1:0*SMP_DW] = s0[SMP_DW-1:0];
      v[2*SMP_DW-1:1*SMP_DW] = s1[SMP_DW-1:0];
      v[3*SMP_DW-1:2*SMP_DW] = s2[SMP_DW-1:0];
      v[4*SMP_DW-1:3*SMP_DW] = s3[SMP_DW-1:0];
      return v;
   endfunction

   // Wait (with timeout) for tag_vld_o (plain DUT) to assert.
   task automatic wait_vld_p(output bit timed_out);
      int cyc;
      timed_out = 1'b0;
      cyc = 0;
      while (cb.tb_vld_p !== 1'b1) begin
         @(cb);
         cyc++;
         if (cyc > 50) begin
            timed_out = 1'b1;
            return;
         end
      end
   endtask

   task automatic wait_vld_i(output bit timed_out);
      int cyc;
      timed_out = 1'b0;
      cyc = 0;
      while (cb.tb_vld_i !== 1'b1) begin
         @(cb);
         cyc++;
         if (cyc > 50) begin
            timed_out = 1'b1;
            return;
         end
      end
   endtask

   // Reset dut_inter, then capture one tag for a single-clock crossing at lane
   // cross_idx (0 or 2) with cfg_inter = k, filter off, threshold 100. time_ck_i
   // counts from a fixed value after the reset, so every call sees the same
   // counter phase and the coarse fields of different calls can be compared.
   task automatic capture_cross(input int k, input int cross_idx, output logic [31:0] tag, output bit timed_out);
      cb.tb_arm_i     <= 1'b0;
      cb.tb_time_cnt  <= 1'b0;
      cb.tb_dt_i      <= '0;
      cb.tb_filter_i  <= 1'b0;
      cb.tb_th_i      <= 16'd100;
      cb.tb_inh_i     <= 8'd20;
      cb.tb_inter_i   <= k[2:0];
      cb.tb_rstn      <= 1'b0;
      repeat(3) @(cb);
      cb.tb_rstn      <= 1'b1;
      repeat(5) @(cb);
      cb.tb_time_cnt  <= 1'b1;
      cb.tb_arm_i     <= 1'b1;
      repeat(3) @(cb);
      if (cross_idx == 0) cb.tb_dt_i <= pack4(500, 500, 500, 500);
      else                cb.tb_dt_i <= pack4(0, 0, 500, 500);
      wait_vld_i(timed_out);
      @(cb);
      tag = cb.tb_tagdt_i;
      cb.tb_dt_i <= '0;
   endtask

   // Reset dut_inter, optionally present pre_high (every lane 500) for a few clocks before arming, then drive
   // b0 for one clock, b1 for one clock if has_b1, then zeros, and capture the first tag. cfg_inter = k,
   // threshold th, filter on or off. The batches are NOT held: the interpolator must use the samples of the
   // batch that crossed, not whatever follows.
   task automatic capture_seq(input int k, input int th, input bit filt,
                              input logic [SMP_CK*SMP_DW-1:0] b0, input logic [SMP_CK*SMP_DW-1:0] b1, input bit has_b1,
                              input bit pre_high, output logic [31:0] tag, output bit timed_out);
      cb.tb_arm_i     <= 1'b0;
      cb.tb_time_cnt  <= 1'b0;
      cb.tb_dt_i      <= '0;
      cb.tb_filter_i  <= filt;
      cb.tb_th_i      <= th[SMP_DW-1:0];
      cb.tb_inh_i     <= 8'd20;
      cb.tb_inter_i   <= k[2:0];
      cb.tb_rstn      <= 1'b0;
      repeat(3) @(cb);
      cb.tb_rstn      <= 1'b1;
      repeat(5) @(cb);
      if (pre_high) begin
         cb.tb_dt_i <= pack4(500, 500, 500, 500);
         repeat(4) @(cb);
      end
      cb.tb_arm_i     <= 1'b1;
      repeat(3) @(cb);
      cb.tb_dt_i <= b0;
      @(cb);
      if (has_b1) begin
         cb.tb_dt_i <= b1;
         @(cb);
      end
      cb.tb_dt_i <= '0;
      wait_vld_i(timed_out);
      @(cb);
      tag = cb.tb_tagdt_i;
   endtask

   // Two tags in a row, each read in the very cycle tag_vld_o asserts (the cycle in which the tag FIFO samples
   // tag_dt_o), with no reset between them. Filter off, threshold 100, cfg_inter = 4.
   task automatic capture_two_at_vld(input logic [SMP_CK*SMP_DW-1:0] b0, input logic [SMP_CK*SMP_DW-1:0] b1,
                                     output logic [31:0] tag0, output logic [31:0] tag1, output bit timed_out);
      bit to1, to2;
      cb.tb_arm_i     <= 1'b0;
      cb.tb_time_cnt  <= 1'b0;
      cb.tb_dt_i      <= '0;
      cb.tb_filter_i  <= 1'b0;
      cb.tb_th_i      <= 16'd100;
      cb.tb_inh_i     <= 8'd20;
      cb.tb_inter_i   <= 3'd4;
      cb.tb_rstn      <= 1'b0;
      repeat(3) @(cb);
      cb.tb_rstn      <= 1'b1;
      repeat(5) @(cb);
      cb.tb_time_cnt  <= 1'b1;
      cb.tb_arm_i     <= 1'b1;
      repeat(3) @(cb);
      cb.tb_dt_i <= b0;
      @(cb);
      cb.tb_dt_i <= '0;
      wait_vld_i(to1);
      tag0 = cb.tb_tagdt_i;                    // no extra clock: this is what the FIFO captures
      repeat(40) @(cb);                         // longer than the dead time
      cb.tb_dt_i <= b1;
      @(cb);
      cb.tb_dt_i <= '0;
      @(cb);                                    // leave the first tag's vld behind
      wait_vld_i(to2);
      tag1 = cb.tb_tagdt_i;
      timed_out = to1 | to2;
   endtask

   function void build();
      svunit_ut = new(name);
   endfunction

   task setup();
      svunit_ut.setup();
      cb.tb_arm_p    <= 1'b0;
      cb.tb_filter_p <= 1'b0;
      cb.tb_slope_p  <= 1'b0;
      cb.tb_invert_p <= 1'b0;
      cb.tb_inter_p  <= 3'd0;
      cb.tb_th_p     <= '0;
      cb.tb_inh_p    <= 8'd2;
      cb.tb_dt_p     <= '0;

      cb.tb_arm_i    <= 1'b0;
      cb.tb_filter_i <= 1'b1; // realistic config: filter on, so ftr_smp/threshold share the same "sum of samples" scale
      cb.tb_slope_i  <= 1'b0;
      cb.tb_invert_i <= 1'b0;
      cb.tb_inter_i  <= 3'd0;
      cb.tb_th_i     <= '0;
      cb.tb_inh_i    <= 8'd2;
      cb.tb_dt_i     <= '0;

      @(cb);
      cb.tb_rstn <= 1'b0;
      repeat(3) @(cb);
      cb.tb_rstn <= 1'b1;
      repeat(5) @(cb);
   endtask

   task teardown();
      svunit_ut.teardown();
   endtask

   `SVUNIT_TESTS_BEGIN
   `include "qtt_tag_calc_tests.sv"
   `SVUNIT_TESTS_END

endmodule
