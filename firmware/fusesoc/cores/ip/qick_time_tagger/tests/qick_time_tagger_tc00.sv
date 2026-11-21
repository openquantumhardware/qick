// ============================================================================
// File: qick_time_tagger_tc00.sv
// Description: SVUnit testbench top-level for axi_qick_time_tagger (the
//   packaged IP, Tier 3). qick:dsp:qtt_core (Tier 2) is
//   already end-to-end tested; this focuses on the AXI-lite register layer
//   itself (axil_slv wiring, CTRL_REG's AUTO_CLEAR_BIT0 self-clear,
//   read-only register protection) plus one real AXI-driven
//   arm->trigger->DMA-readback path to prove the register map actually
//   reaches the datapath correctly.
//
//   Drives the flat AXI-Lite pins through a locally-instantiated
//   axi4_lite_if (its axi_write/axi_read tasks), same convention
//   qick_processor's own testbench uses.
//
//   No clocking blocks for the plain (non-AXI-lite) signals, on purpose -
//   the DUT's dependency chain includes qick:mem:fifo_async
//   (xpm_fifo_async) via qick:dsp:qtt_core. See
//   TESTBENCH_PATTERNS.md #20. (axi4_lite_if's own tasks already follow
//   this convention internally.)
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qick_time_tagger_unit_test;
   import svunit_pkg::svunit_testcase;

   // Register map (byte-addressed, matches qick_time_tagger_regmap.rdl).
   localparam int ADDR_CTRL       = 'h00;
   localparam int ADDR_CFG        = 'h04;
   localparam int ADDR_DMA_CFG    = 'h08;
   localparam int ADDR_AXI_DT1    = 'h0C;
   localparam int ADDR_PROC_DT    = 'h14;
   localparam int ADDR_TAG0_QTY   = 'h1C;
   localparam int ADDR_ARM_QTY    = 'h30;
   localparam int ADDR_QTT_STATUS = 'h38;

   // CTRL_REG op field (bits[4:1]) values, matching qtt_cmd.sv's decode.
   localparam logic [3:0] OP_DISARM  = 4'b0000;
   localparam logic [3:0] OP_ARM     = 4'b0001;
   localparam logic [3:0] OP_SET_TH  = 4'b0100;
   localparam logic [3:0] OP_SET_INH = 4'b0101;
   localparam logic [3:0] OP_RESET   = 4'b0111;

   string name = "qick_time_tagger_ut";
   svunit_testcase svunit_ut;

   localparam real PS_FREQ  = 100e6;
   localparam real C_FREQ   = 150e6;
   localparam real ADC_FREQ = 300e6;
   localparam int  SMP_DW   = 16;
   localparam int  SMP_CK   = 8;

   logic ps_clk   = 1'b0;
   logic ps_rstn  = 1'b1;
   logic c_clk    = 1'b0;
   logic c_rstn   = 1'b1;
   logic adc_clk  = 1'b0;
   logic adc_rstn = 1'b1;

   clk_gen #(.FREQ (PS_FREQ))  u_clk_ps  (.i_enable(1'b1), .o_clk(ps_clk));
   clk_gen #(.FREQ (C_FREQ))   u_clk_c   (.i_enable(1'b1), .o_clk(c_clk));
   clk_gen #(.FREQ (ADC_FREQ)) u_clk_adc (.i_enable(1'b1), .o_clk(adc_clk));

   axi4_lite_if #(
      .DATA_WIDTH (32),
      .ADDR_WIDTH (6)
   ) s_axi (
      .aclk    (ps_clk),
      .aresetn (ps_rstn)
   );

   logic        arm        = 1'b0;
   logic        qtag_en    = 1'b0;
   logic [4:0]  qtag_op    = '0;
   logic [31:0] qtag_dt1_i = '0;
   logic [31:0] qtag_dt2_i = '0;
   logic [31:0] qtag_dt3_i = '0;
   logic [31:0] qtag_dt4_i = '0;

   logic [SMP_CK*SMP_DW-1:0] adc0_dt = '0;

   logic        dma_tready = 1'b1;
   logic        dma_tvalid;
   logic [31:0] dma_tdata;
   logic        dma_tlast;

   initial begin
      $dumpfile("qick_time_tagger.vcd");
      $dumpvars();
   end

   axi_qick_time_tagger #(
      .ADC_QTY      ( 1 ),
      .CMP_INTER    ( 4 ), // real deployed default - see TESTBENCH_PATTERNS.md #21
      .ARM_STORE    ( 1 ),
      .SMP_STORE    ( 0 ),
      .TAG_FIFO_AW  ( 4 ),
      .ARM_FIFO_AW  ( 4 ),
      .SMP_FIFO_AW  ( 4 ),
      .CMP_SLOPE    ( 0 ),
      .SMP_DW       ( SMP_DW ),
      .SMP_CK       ( SMP_CK ),
      .DEBUG        ( 0 )
   ) dut (
      .c_clk                ( c_clk       ),
      .c_aresetn             ( c_rstn      ),
      .s0_axis_aclk               ( adc_clk     ),
      .s0_axis_aresetn            ( adc_rstn    ),
      .s_axi_aclk                ( ps_clk      ),
      .s_axi_aresetn             ( ps_rstn     ),
      .arm_i                  ( arm         ),
      .trig_o                 (             ),
      .cmp_o                  (             ),
      .qtag_en_i              ( qtag_en     ),
      .qtag_op_i              ( qtag_op     ),
      .qtag_dt1_i             ( qtag_dt1_i  ),
      .qtag_dt2_i             ( qtag_dt2_i  ),
      .qtag_dt3_i             ( qtag_dt3_i  ),
      .qtag_dt4_i             ( qtag_dt4_i  ),
      .qtag_rdy_o             (             ),
      .qtag_dt1_o             (             ),
      .qtag_dt2_o             (             ),
      .qtag_vld_o             (             ),
      .qtag_flag_o            (             ),
      .s_axi_awaddr           ( s_axi.awaddr  ),
      .s_axi_awprot           ( s_axi.awprot  ),
      .s_axi_awvalid          ( s_axi.awvalid ),
      .s_axi_awready          ( s_axi.awready ),
      .s_axi_wdata            ( s_axi.wdata   ),
      .s_axi_wstrb            ( s_axi.wstrb   ),
      .s_axi_wvalid           ( s_axi.wvalid  ),
      .s_axi_wready           ( s_axi.wready  ),
      .s_axi_bresp            ( s_axi.bresp   ),
      .s_axi_bvalid           ( s_axi.bvalid  ),
      .s_axi_bready           ( s_axi.bready  ),
      .s_axi_araddr           ( s_axi.araddr  ),
      .s_axi_arprot           ( s_axi.arprot  ),
      .s_axi_arvalid          ( s_axi.arvalid ),
      .s_axi_arready          ( s_axi.arready ),
      .s_axi_rdata            ( s_axi.rdata   ),
      .s_axi_rresp            ( s_axi.rresp   ),
      .s_axi_rvalid           ( s_axi.rvalid  ),
      .s_axi_rready           ( s_axi.rready  ),
      .s0_axis_adc0_tvalid   ( 1'b1        ),
      .s0_axis_adc0_tdata    ( adc0_dt     ),
      .s0_axis_adc0_tready   (             ),
      .s0_axis_adc1_tvalid   ( 1'b0        ),
      .s0_axis_adc1_tdata    ( '0          ),
      .s0_axis_adc1_tready   (             ),
      .s0_axis_adc2_tvalid   ( 1'b0        ),
      .s0_axis_adc2_tdata    ( '0          ),
      .s0_axis_adc2_tready   (             ),
      .s0_axis_adc3_tvalid   ( 1'b0        ),
      .s0_axis_adc3_tdata    ( '0          ),
      .s0_axis_adc3_tready   (             ),
      .m0_axis_dma_tready    ( dma_tready  ),
      .m0_axis_dma_tvalid    ( dma_tvalid  ),
      .m0_axis_dma_tdata     ( dma_tdata   ),
      .m0_axis_dma_tlast     ( dma_tlast   ),
      .qtt_do                 (             )
   );

   function automatic logic [SMP_CK*SMP_DW-1:0] pack_burst(int s0, int s1, int s2, int s3, int s4, int s5, int s6, int s7);
      logic [SMP_CK*SMP_DW-1:0] v;
      v[0*SMP_DW +: SMP_DW] = s0[SMP_DW-1:0];
      v[1*SMP_DW +: SMP_DW] = s1[SMP_DW-1:0];
      v[2*SMP_DW +: SMP_DW] = s2[SMP_DW-1:0];
      v[3*SMP_DW +: SMP_DW] = s3[SMP_DW-1:0];
      v[4*SMP_DW +: SMP_DW] = s4[SMP_DW-1:0];
      v[5*SMP_DW +: SMP_DW] = s5[SMP_DW-1:0];
      v[6*SMP_DW +: SMP_DW] = s6[SMP_DW-1:0];
      v[7*SMP_DW +: SMP_DW] = s7[SMP_DW-1:0];
      return v;
   endfunction

   // Issue a CTRL_REG command: strobe=1, op in bits[4:1].
   task automatic send_ctrl_cmd(logic [3:0] op);
      s_axi.axi_write(ADDR_CTRL, {26'd0, op, 1'b1});
   endtask

   // Threshold 150, dead time 20 clocks.
   task automatic configure_th_inh();
      s_axi.axi_write(ADDR_AXI_DT1, 32'd150);
      send_ctrl_cmd(OP_SET_TH);
      repeat(5) @(posedge ps_clk);
      s_axi.axi_write(ADDR_AXI_DT1, 32'd20);
      send_ctrl_cmd(OP_SET_INH);
      repeat(5) @(posedge ps_clk);
   endtask

   // One 2-clock burst above the threshold, then quiet, then let the tag reach the ring buffer.
   task automatic pulse_and_settle();
      adc0_dt <= pack_burst(300, 300, 300, 300, 300, 300, 300, 300);
      repeat(2) @(posedge adc_clk);
      adc0_dt <= '0;
      repeat(80) @(posedge adc_clk);
      repeat(60) @(posedge ps_clk);
   endtask

   task automatic settle();
      repeat(80) @(posedge adc_clk);
      repeat(60) @(posedge ps_clk);
   endtask

   task automatic read_qtys(output logic [31:0] tag0, output logic [31:0] arm);
      s_axi.axi_read(ADDR_TAG0_QTY, tag0);
      s_axi.axi_read(ADDR_ARM_QTY, arm);
   endtask

   task automatic dma_read_one(logic [23:0] dma_cfg, output logic [31:0] data, output bit ok);
      int cyc;
      s_axi.axi_write(ADDR_DMA_CFG, {8'd0, dma_cfg});
      s_axi.axi_write(ADDR_CTRL, 32'h20); // bit5 = dma_rd, no strobe bit needed
      ok   = 1'b0;
      data = '0;
      for (cyc = 0; cyc < 400; cyc++) begin
         @(posedge ps_clk);
         if (dma_tvalid && dma_tready) begin
            data = dma_tdata;
            ok   = dma_tlast;
            break;
         end
      end
      s_axi.axi_write(ADDR_CTRL, 32'h00); // drop dma_rd
   endtask

   function void build();
      svunit_ut = new(name);
   endfunction

   task setup();
      svunit_ut.setup();
      arm       <= 1'b0;
      adc0_dt   <= '0;
      qtag_en   <= 1'b0;
      qtag_op   <= '0;
      dma_tready <= 1'b1;

      ps_rstn  = 1'b0;
      c_rstn   = 1'b0;
      adc_rstn = 1'b0;
      repeat(8) @(posedge adc_clk);
      ps_rstn  = 1'b1;
      c_rstn   = 1'b1;
      adc_rstn = 1'b1;
      s_axi.reset();
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
   `include "qick_time_tagger_tests.sv"
   `SVUNIT_TESTS_END

endmodule
