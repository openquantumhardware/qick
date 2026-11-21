// ============================================================================
// File: smp_mem_tc00.sv
// Description: SVUnit testbench top-level for smp_mem (SMP_CK=4,
//   SMP_DW=16). smp_fifo_dc (the composed sub-core) is already thoroughly
//   unit-tested; this focuses on the integration risk: the trigger
//   (tag_wr_i) -> capture-window FSM -> smp_fifo_dc push wiring, and the
//   dma_dt_o sign extension. Because the capture pipeline is a fixed,
//   value-preserving delay (smp_wr_dt -> _r -> _2r -> _3r), holding
//   adc_dt_i constant across the whole trigger window makes the exact
//   pipeline depth irrelevant to the test - whatever gets captured is
//   still that same constant value.
//
// No clocking blocks, on purpose - wraps qick:mem:fifo_async via
// smp_fifo_dc (see TESTBENCH_PATTERNS.md #20).
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module smp_mem_unit_test;
   import svunit_pkg::svunit_testcase;

   localparam int SMP_CK      = 4;
   localparam int SMP_DW      = 16;
   localparam int SMP_FIFO_AW = 6;

   string name = "smp_mem_ut";
   svunit_testcase svunit_ut;

   localparam real ADC_FREQ = 300e6;
   localparam real DMA_FREQ = 100e6;

   logic                      tb_adc_clk  = 1'b0;
   logic                      tb_adc_rstn = 1'b1;
   logic [4:0]                tb_wr_qty   = 5'd2;
   logic                      tb_tag_wr   = 1'b0;
   logic [SMP_CK*SMP_DW-1:0]  tb_adc_dt   = '0;

   logic                      tb_dma_clk  = 1'b0;
   logic                      tb_dma_rstn = 1'b1;
   logic                      tb_flush    = 1'b0;
   logic                      tb_pop      = 1'b0;
   logic [31:0]               tb_data_o;
   logic                      tb_empty;
   logic                      tb_full;

   clk_gen #(.FREQ (ADC_FREQ)) u_clk_adc (.i_enable(1'b1), .o_clk(tb_adc_clk));
   clk_gen #(.FREQ (DMA_FREQ)) u_clk_dma (.i_enable(1'b1), .o_clk(tb_dma_clk));

   initial begin
      $dumpfile("smp_mem.vcd");
      $dumpvars();
   end

   smp_mem #(
      .SMP_DW      ( SMP_DW      ),
      .SMP_CK      ( SMP_CK      ),
      .SMP_FIFO_AW ( SMP_FIFO_AW )
   ) dut (
      .dma_clk_i        ( tb_dma_clk  ),
      .dma_rst_ni       ( tb_dma_rstn ),
      .adc_clk_i        ( tb_adc_clk  ),
      .adc_rst_ni       ( tb_adc_rstn ),
      .qtt_rst_req_i    ( tb_flush    ),
      .qtt_rst_ack_o    (             ),
      .cfg_smp_wr_qty_i ( tb_wr_qty   ),
      .tag_wr_i         ( tb_tag_wr   ),
      .adc_dt_i         ( tb_adc_dt   ),
      .dma_pop_i        ( tb_pop      ),
      .dma_pop_o        (             ),
      .dma_dt_o         ( tb_data_o   ),
      .dma_qty_o        (             ),
      .smp_empty_o      ( tb_empty    ),
      .smp_full_o       ( tb_full     ),
      .debug_do         (             )
   );

   function automatic logic [SMP_CK*SMP_DW-1:0] pack_burst(logic [SMP_DW-1:0] base);
      logic [SMP_CK*SMP_DW-1:0] v;
      for (int k = 0; k < SMP_CK; k++)
         v[k*SMP_DW +: SMP_DW] = (base + k);
      return v;
   endfunction

   task automatic capture_trace(int cycles, output int trace[]);
      int k;
      trace = new[cycles];
      tb_pop <= 1'b1;
      for (k = 0; k < cycles; k++) begin
         @(posedge tb_dma_clk);
         trace[k] = tb_data_o;
      end
      tb_pop <= 1'b0;
      @(posedge tb_dma_clk);
   endtask

   function automatic bit trace_contains_seq(int trace[], int base, int n);
      int start, k;
      for (start = 0; start <= trace.size() - n; start++) begin
         bit match_ok = 1'b1;
         for (k = 0; k < n; k++)
            if (trace[start+k] != base + k) match_ok = 1'b0;
         if (match_ok) return 1'b1;
      end
      return 1'b0;
   endfunction

   function void build();
      svunit_ut = new(name);
   endfunction

   task setup();
      svunit_ut.setup();
      tb_tag_wr <= 1'b0;
      tb_adc_dt <= '0;
      tb_flush  <= 1'b0;
      tb_pop    <= 1'b0;
      tb_wr_qty <= 5'd2;

      tb_adc_rstn <= 1'b0;
      tb_dma_rstn <= 1'b0;
      repeat(8) @(posedge tb_adc_clk);
      tb_adc_rstn <= 1'b1;
      tb_dma_rstn <= 1'b1;
      // xpm_fifo_async settle window (see tag_fifo_dc's testbench).
      repeat(40) @(posedge tb_adc_clk);
      repeat(40) @(posedge tb_dma_clk);
   endtask

   task teardown();
      svunit_ut.teardown();
   endtask

   `SVUNIT_TESTS_BEGIN
   `include "smp_mem_tests.sv"
   `SVUNIT_TESTS_END

endmodule
