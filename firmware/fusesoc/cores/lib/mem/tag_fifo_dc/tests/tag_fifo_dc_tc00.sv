// ============================================================================
// File: tag_fifo_dc_tc00.sv
// Description: SVUnit testbench top-level for tag_fifo_dc.
//
// SAMPLING CONVENTION (no clocking blocks, on purpose - matches
// qick:mem:fifo_async's own testbench convention, required because this DUT
// wraps that same xpm_fifo_async primitive across two clock domains):
//   - Every drive uses non-blocking assignment right before @(posedge clk),
//     landing in the NBA region, stable before the next edge.
//   - Every read of a DUT output happens right after @(posedge clk) (the
//     active region), returning the value the DUT itself just sampled.
//   - Never sample a dma_clk-domain signal from the adc_clk process or vice
//     versa.
//
// Same latency-agnostic verification approach as fifo_dc's own testbench:
// push a known sequence, then search for it as a contiguous in-order run
// inside a generously long dma_clk-side capture trace, rather than
// hand-deriving the async-FIFO-plus-ring-buffer pipeline depth.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module tag_fifo_dc_unit_test;
   import svunit_pkg::svunit_testcase;

   localparam int FIFO_AW = 4; // 16-entry ring buffer

   string name = "tag_fifo_dc_ut";
   svunit_testcase svunit_ut;

   localparam real ADC_FREQ = 300e6;
   localparam real DMA_FREQ = 100e6;

   logic         tb_adc_clk  = 1'b0;
   logic         tb_adc_rstn = 1'b1;
   logic         tb_push     = 1'b0;
   logic [31:0]  tb_data_i   = '0;

   logic         tb_dma_clk  = 1'b0;
   logic         tb_dma_rstn = 1'b1;
   logic         tb_flush    = 1'b0;
   logic         tb_pop      = 1'b0;
   logic [31:0]  tb_data_o;
   logic         tb_empty;
   logic         tb_full;

   clk_gen #(.FREQ (ADC_FREQ)) u_clk_adc (.i_enable(1'b1), .o_clk(tb_adc_clk));
   clk_gen #(.FREQ (DMA_FREQ)) u_clk_dma (.i_enable(1'b1), .o_clk(tb_dma_clk));

   initial begin
      $dumpfile("tag_fifo_dc.vcd");
      $dumpvars();
   end

   tag_fifo_dc #(
      .FIFO_AW ( FIFO_AW )
   ) dut (
      .adc_clk_i  ( tb_adc_clk  ),
      .adc_rst_ni ( tb_adc_rstn ),
      .dma_clk_i  ( tb_dma_clk  ),
      .dma_rst_ni ( tb_dma_rstn ),
      .flush_i    ( tb_flush    ),
      .flush_o    (             ),
      .adc_push_i ( tb_push     ),
      .adc_data_i ( tb_data_i   ),
      .dma_pop_i  ( tb_pop      ),
      .dma_pop_o  (             ),
      .dma_qty_o  (             ),
      .dma_dt_o   ( tb_data_o   ),
      .empty_o    ( tb_empty    ),
      .full_o     ( tb_full     ),
      .debug_do   (             )
   );

   task automatic push_seq(int base, int n);
      int k;
      for (k = 0; k < n; k++) begin
         tb_push   <= 1'b1;
         tb_data_i <= (base + k);
         @(posedge tb_adc_clk);
      end
      tb_push <= 1'b0;
      @(posedge tb_adc_clk);
   endtask

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

   task automatic wait_full(output bit timed_out);
      int cyc;
      timed_out = 1'b0;
      cyc = 0;
      while (tb_full !== 1'b1) begin
         @(posedge tb_dma_clk);
         cyc++;
         if (cyc > 300) begin
            timed_out = 1'b1;
            return;
         end
      end
   endtask

   task automatic wait_empty(output bit timed_out);
      int cyc;
      timed_out = 1'b0;
      cyc = 0;
      while (tb_empty !== 1'b1) begin
         @(posedge tb_dma_clk);
         cyc++;
         if (cyc > 300) begin
            timed_out = 1'b1;
            return;
         end
      end
   endtask

   // Push continuously (incrementing data) until full_o asserts or
   // max_cycles is exceeded.
   task automatic fill_until_full(int max_cycles, output bit timed_out);
      int k;
      timed_out = 1'b1;
      tb_push <= 1'b1;
      for (k = 0; k < max_cycles; k++) begin
         tb_data_i <= k;
         @(posedge tb_adc_clk);
         if (tb_full === 1'b1) begin
            timed_out = 1'b0;
            break;
         end
      end
      tb_push <= 1'b0;
      @(posedge tb_adc_clk);
   endtask

   function void build();
      svunit_ut = new(name);
   endfunction

   task setup();
      svunit_ut.setup();
      tb_push   <= 1'b0;
      tb_data_i <= '0;
      tb_flush  <= 1'b0;
      tb_pop    <= 1'b0;

      tb_adc_rstn <= 1'b0;
      tb_dma_rstn <= 1'b0;
      repeat(8) @(posedge tb_adc_clk);
      tb_adc_rstn <= 1'b1;
      tb_dma_rstn <= 1'b1;
      // xpm_fifo_async holds wr_rst_busy/rd_rst_busy high for many cycles
      // after reset releases and silently drops writes during that window -
      // same settle margin fifo_async's own testbench uses (CDC_WAIT=32).
      repeat(40) @(posedge tb_adc_clk);
      repeat(40) @(posedge tb_dma_clk);
   endtask

   task teardown();
      svunit_ut.teardown();
   endtask

   `SVUNIT_TESTS_BEGIN
   `include "tag_fifo_dc_tests.sv"
   `SVUNIT_TESTS_END

endmodule
