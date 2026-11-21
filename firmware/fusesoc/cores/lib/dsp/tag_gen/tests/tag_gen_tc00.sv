// ============================================================================
// File: tag_gen_tc00.sv
// Description: SVUnit testbench top-level for tag_gen (ADC_QTY=2). Each
//   qtt_tag_calc channel is already unit-tested on its own; this focuses on
//   the integration risk - per-channel array wiring (adc_dt_i[ind] ->
//   tag_vld_o[ind]/tag_dt_o[ind]) - by giving each channel a different
//   crossing pattern and checking they resolve independently and correctly.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module tag_gen_unit_test;
   import svunit_pkg::svunit_testcase;

   string name = "tag_gen_ut";
   svunit_testcase svunit_ut;

   localparam real CLOCK_FREQUENCY = 200e6;
   localparam int  ADC_QTY = 2;
   localparam int  SMP_DW  = 16;
   localparam int  SMP_CK  = 4;
   localparam logic [28:0] TIME_CK = 29'd5;

   logic                     tb_clk    = 1'b0;
   logic                     tb_rstn   = 1'b1;
   logic                     tb_en     = 1'b0;
   logic                     tb_invert = 1'b0;
   logic                     tb_filter = 1'b0;
   logic [2:0]               tb_inter  = 3'd0;
   logic                     tb_slope  = 1'b0;
   logic [SMP_DW-1:0]        tb_th     = '0;
   logic [7:0]               tb_inh    = 8'd2;
   logic [SMP_CK*SMP_DW-1:0] tb_dt0    = '0;
   logic [SMP_CK*SMP_DW-1:0] tb_dt1    = '0;

   logic                     tb_trig, tb_cmp;
   logic [ADC_QTY-1:0]       tb_vld;
   logic [31:0]              tb_tagdt0, tb_tagdt1;

   wire [SMP_CK*SMP_DW-1:0]  adc_dt [ADC_QTY];
   wire [31:0]               tag_dt [ADC_QTY];
   assign adc_dt[0] = tb_dt0;
   assign adc_dt[1] = tb_dt1;
   assign tb_tagdt0 = tag_dt[0];
   assign tb_tagdt1 = tag_dt[1];

   clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

   default clocking cb @(posedge tb_clk);
      output tb_rstn, tb_en, tb_invert, tb_filter, tb_inter, tb_slope, tb_th, tb_inh, tb_dt0, tb_dt1;
      input  tb_trig, tb_cmp, tb_vld, tb_tagdt0, tb_tagdt1;
   endclocking

   initial begin
      $dumpfile("tag_gen.vcd");
      $dumpvars();
   end

   tag_gen #(
      .ADC_QTY   ( ADC_QTY ),
      .CMP_SLOPE ( 0       ),
      .CMP_INTER ( 0       ),
      .SMP_DW    ( SMP_DW  ),
      .SMP_CK    ( SMP_CK  )
   ) dut (
      .clk_i         ( tb_clk    ),
      .rst_ni        ( tb_rstn   ),
      .cfg_invert_i  ( tb_invert ),
      .cfg_filter_i  ( tb_filter ),
      .cfg_inter_i   ( tb_inter  ),
      .cfg_slope_i   ( tb_slope  ),
      .time_ck_i     ( TIME_CK   ),
      .cmp_th_i      ( tb_th     ),
      .cmp_inh_i     ( tb_inh    ),
      .en_i          ( tb_en     ),
      .adc_dt_i      ( adc_dt    ),
      .trig_o        ( tb_trig   ),
      .cmp_o         ( tb_cmp    ),
      .tag_vld_o     ( tb_vld    ),
      .tag_dt_o      ( tag_dt    )
   );

   function automatic logic [SMP_CK*SMP_DW-1:0] pack4(int s0, int s1, int s2, int s3);
      logic [SMP_CK*SMP_DW-1:0] v;
      v[1*SMP_DW-1:0*SMP_DW] = s0[SMP_DW-1:0];
      v[2*SMP_DW-1:1*SMP_DW] = s1[SMP_DW-1:0];
      v[3*SMP_DW-1:2*SMP_DW] = s2[SMP_DW-1:0];
      v[4*SMP_DW-1:3*SMP_DW] = s3[SMP_DW-1:0];
      return v;
   endfunction

   task automatic wait_both_vld(output bit timed_out);
      int cyc;
      timed_out = 1'b0;
      cyc = 0;
      while (cb.tb_vld !== 2'b11) begin
         @(cb);
         cyc++;
         if (cyc > 50) begin
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
      cb.tb_en     <= 1'b0;
      cb.tb_th     <= '0;
      cb.tb_inh    <= 8'd2;
      cb.tb_dt0    <= '0;
      cb.tb_dt1    <= '0;
      cb.tb_filter <= 1'b0;
      cb.tb_slope  <= 1'b0;
      cb.tb_invert <= 1'b0;
      cb.tb_inter  <= 3'd0;

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
   `include "tag_gen_tests.sv"
   `SVUNIT_TESTS_END

endmodule
