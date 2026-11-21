// ============================================================================
// File: qtt_core_tc00.sv
// Description: SVUnit testbench top-level for qtt_core (Tier 2, the
//   non-AXI top composition). Every sub-core (tag_gen, tag_mem,
//   dma_fifo_rd, smp_mem, tag_fifo_dc, cdc_reg_sync, cdc_handshake) is
//   already thoroughly unit-tested on its own; this is an end-to-end
//   integration exercise - arm -> a real threshold crossing -> tag capture
//   -> DMA readback, plus the sample-store/arm-store DMA mux paths and the
//   qtt_rst_req_i flush.
//
//   No clocking blocks, on purpose - the DUT's dependency chain includes
//   qick:mem:fifo_async (xpm_fifo_async) via tag_mem/smp_mem/tag_fifo_dc.
//   See TESTBENCH_PATTERNS.md #20.
//
//   ADC_QTY=1 and CMP_INTER=0 here (both already covered in depth by
//   tag_gen's and qtt_tag_calc's own testbenches) to keep this bench's
//   stimulus and expected values tractable.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qtt_core_unit_test;
   import svunit_pkg::svunit_testcase;

   localparam int ADC_QTY     = 1;
   localparam int CMP_SLOPE   = 0;
   // CMP_INTER=0 (the compile-time parameter, selects qtt_tag_calc's
   // gen_no_inter branch) makes tag_vld_o pulse the SAME cycle
   // trig_time_adc_r's non-blocking update is scheduled, one cycle before
   // that update is actually visible - so tag_mem would latch the tag word
   // one crossing stale. CMP_INTER=1 forces the real x_inter instantiation
   // instead, which - even fed cfg_inter_i=0 at runtime, so it contributes
   // no interpolation bits and stays cheap to reason about - still takes
   // one extra cycle before x_inter_end/tag_vld_o pulse, by which time
   // trig_time_adc_r has already settled. This mirrors the real deployed
   // configuration (qtt_core.sv's own default is CMP_INTER=4).
   localparam int CMP_INTER   = 1;
   localparam int ARM_STORE   = 1;
   localparam int SMP_STORE   = 1;
   localparam int TAG_FIFO_AW = 4;
   localparam int ARM_FIFO_AW = 4;
   localparam int SMP_FIFO_AW = 4;
   localparam int SMP_DW      = 16;
   localparam int SMP_CK      = 4;

   string name = "qtt_core_ut";
   svunit_testcase svunit_ut;

   localparam real PS_FREQ  = 100e6;
   localparam real C_FREQ   = 150e6;
   localparam real ADC_FREQ = 300e6;

   logic ps_clk   = 1'b0;
   logic ps_rstn  = 1'b1;
   logic c_clk    = 1'b0;
   logic c_rstn   = 1'b1;
   logic adc_clk  = 1'b0;
   logic adc_rstn = 1'b1;

   logic        qtt_pop_req = 1'b0;
   logic        qtt_rst_req = 1'b0;
   logic        qtt_rst_ack;

   logic        cfg_invert = 1'b0;
   logic        cfg_filter = 1'b0;
   logic        cfg_slope  = 1'b0;
   logic [2:0]  cfg_inter  = '0;
   logic [4:0]  cfg_smp_wr_qty = 5'd2;
   logic        arm        = 1'b0;
   logic [SMP_DW-1:0] cmp_th  = '0;
   logic [7:0]        cmp_inh = 8'd2;

   logic [SMP_CK*SMP_DW-1:0] adc_dt [ADC_QTY];

   logic        dma_req    = 1'b0;
   logic [2:0]  dma_mem_sel= '0;
   logic [19:0] dma_len    = 20'd1;
   logic        dma_ack;
   logic        dma_tready = 1'b1;
   logic        dma_tvalid;
   logic [31:0] dma_tdata;
   logic        dma_tlast;

   logic [31:0] tag_dt;
   logic        tag_vld;
   logic        trig;
   logic        cmp;

   logic [TAG_FIFO_AW-1:0] proc_qty;
   logic [TAG_FIFO_AW-1:0] dma_qty [4];
   logic [SMP_FIFO_AW-1:0] smp_qty;
   logic [ARM_FIFO_AW-1:0] arm_qty;
   logic [31:0] qtt_debug;
   logic [23:0] qtt_reg_status;
   logic [31:0] qtt_reg_debug;

   clk_gen #(.FREQ (PS_FREQ))  u_clk_ps  (.i_enable(1'b1), .o_clk(ps_clk));
   clk_gen #(.FREQ (C_FREQ))   u_clk_c   (.i_enable(1'b1), .o_clk(c_clk));
   clk_gen #(.FREQ (ADC_FREQ)) u_clk_adc (.i_enable(1'b1), .o_clk(adc_clk));

   initial begin
      $dumpfile("qtt_core.vcd");
      $dumpvars();
   end

   qtt_core #(
      .ADC_QTY      ( ADC_QTY     ),
      .CMP_SLOPE    ( CMP_SLOPE   ),
      .CMP_INTER    ( CMP_INTER   ),
      .ARM_STORE    ( ARM_STORE   ),
      .SMP_STORE    ( SMP_STORE   ),
      .TAG_FIFO_AW  ( TAG_FIFO_AW ),
      .ARM_FIFO_AW  ( ARM_FIFO_AW ),
      .SMP_FIFO_AW  ( SMP_FIFO_AW ),
      .SMP_DW       ( SMP_DW      ),
      .SMP_CK       ( SMP_CK      ),
      .DEBUG        ( 0           )
   ) dut (
      .ps_clk_i             ( ps_clk      ),
      .ps_rst_ni            ( ps_rstn     ),
      .c_clk_i              ( c_clk       ),
      .c_rst_ni             ( c_rstn      ),
      .adc_clk_i            ( adc_clk     ),
      .adc_rst_ni           ( adc_rstn    ),
      .qtt_pop_req_i        ( qtt_pop_req ),
      .qtt_rst_req_i        ( qtt_rst_req ),
      .qtt_rst_ack_o        ( qtt_rst_ack ),
      .cfg_invert_i         ( cfg_invert  ),
      .cfg_filter_i         ( cfg_filter  ),
      .cfg_slope_i          ( cfg_slope   ),
      .cfg_inter_i          ( cfg_inter   ),
      .cfg_smp_wr_qty_i     ( cfg_smp_wr_qty ),
      .arm_i                ( arm         ),
      .cmp_th_i             ( cmp_th      ),
      .cmp_inh_i            ( cmp_inh     ),
      .adc_dt_i             ( adc_dt      ),
      .dma_req_i            ( dma_req     ),
      .dma_mem_sel_i        ( dma_mem_sel ),
      .dma_len_i            ( dma_len     ),
      .dma_ack_o            ( dma_ack     ),
      .dma_m_axis_tready_i  ( dma_tready  ),
      .dma_m_axis_tvalid_o  ( dma_tvalid  ),
      .dma_m_axis_tdata_o   ( dma_tdata   ),
      .dma_m_axis_tlast_o   ( dma_tlast   ),
      .tag_dt_o             ( tag_dt      ),
      .tag_vld_o            ( tag_vld     ),
      .trig_o               ( trig        ),
      .cmp_o                ( cmp         ),
      .proc_qty_o           ( proc_qty    ),
      .dma_qty_o            ( dma_qty     ),
      .smp_qty_o            ( smp_qty     ),
      .arm_qty_o            ( arm_qty     ),
      .qtt_debug_o          ( qtt_debug   ),
      .qtt_reg_status_o     ( qtt_reg_status ),
      .qtt_reg_debug_o      ( qtt_reg_debug  )
   );

   function automatic logic [SMP_CK*SMP_DW-1:0] pack_burst(int s0, int s1, int s2, int s3);
      logic [SMP_CK*SMP_DW-1:0] v;
      v[0*SMP_DW +: SMP_DW] = s0[SMP_DW-1:0];
      v[1*SMP_DW +: SMP_DW] = s1[SMP_DW-1:0];
      v[2*SMP_DW +: SMP_DW] = s2[SMP_DW-1:0];
      v[3*SMP_DW +: SMP_DW] = s3[SMP_DW-1:0];
      return v;
   endfunction

   task automatic wait_trig(int max_cycles, output bit ok);
      int k;
      ok = 1'b0;
      for (k = 0; k < max_cycles; k++) begin
         @(posedge adc_clk);
         if (trig) begin
            ok = 1'b1;
            return;
         end
      end
   endtask

   // Request len=1 word via the DMA mux from mem_sel, collect the one beat.
   task automatic dma_read_one(logic [2:0] mem_sel, output logic [31:0] data, output bit ok);
      int cyc;
      dma_mem_sel <= mem_sel;
      dma_len     <= 20'd1;
      dma_req     <= 1'b1;
      ok   = 1'b0;
      data = '0;
      for (cyc = 0; cyc < 300; cyc++) begin
         @(posedge ps_clk);
         if (dma_tvalid && dma_tready) begin
            data = dma_tdata;
            ok   = dma_tlast;
            break;
         end
      end
      dma_req <= 1'b0;
      cyc = 0;
      while (dma_ack !== 1'b0 && cyc < 300) begin
         @(posedge ps_clk);
         cyc++;
      end
      @(posedge ps_clk);
   endtask

   function void build();
      svunit_ut = new(name);
   endfunction

   task setup();
      svunit_ut.setup();
      qtt_pop_req    = 1'b0;
      qtt_rst_req    = 1'b0;
      cfg_invert     = 1'b0;
      cfg_filter     = 1'b0;
      cfg_slope      = 1'b0;
      cfg_inter      = '0;
      cfg_smp_wr_qty = 5'd2;
      arm            = 1'b0;
      cmp_th         = 16'd150;
      cmp_inh        = 8'd2;
      adc_dt[0]      = '0;
      dma_req        = 1'b0;
      dma_mem_sel    = '0;
      dma_len        = 20'd1;
      dma_tready     = 1'b1;

      ps_rstn  = 1'b0;
      c_rstn   = 1'b0;
      adc_rstn = 1'b0;
      repeat(8) @(posedge adc_clk);
      ps_rstn  = 1'b1;
      c_rstn   = 1'b1;
      adc_rstn = 1'b1;
      // xpm_fifo_async settle window, expressed on each domain's own clock
      // (see TESTBENCH_PATTERNS.md #20 / tag_fifo_dc's testbench).
      repeat(60) @(posedge adc_clk);
      repeat(60) @(posedge c_clk);
      repeat(60) @(posedge ps_clk);
   endtask

   task teardown();
      svunit_ut.teardown();
   endtask

   `SVUNIT_TESTS_BEGIN
   `include "qtt_core_tests.sv"
   `SVUNIT_TESTS_END

endmodule
