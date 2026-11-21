// ============================================================================
// File: smp_fifo_dc_tc00.sv
// Description: SVUnit testbench top-level for smp_fifo_dc (SMP_CK=4,
//   SMP_DW=16). No clocking blocks, on purpose - wraps qick:mem:fifo_async
//   (see TESTBENCH_PATTERNS.md #20). Same latency-agnostic verification
//   approach as tag_fifo_dc: push known bursts, then search for the
//   expected sample sequence as a contiguous in-order run inside a
//   generously long dma_clk-side capture trace.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module smp_fifo_dc_unit_test;
   import svunit_pkg::svunit_testcase;

   localparam int SMP_CK   = 4;
   localparam int SMP_DW   = 16;
   localparam int FIFO_AW  = 4; // 16-entry ring buffer

   string name = "smp_fifo_dc_ut";
   svunit_testcase svunit_ut;

   localparam real ADC_FREQ = 300e6;
   localparam real DMA_FREQ = 100e6;

   logic                      tb_adc_clk  = 1'b0;
   logic                      tb_adc_rstn = 1'b1;
   logic                      tb_push     = 1'b0;
   logic [SMP_CK*SMP_DW-1:0]  tb_data_i   = '0;

   logic                      tb_dma_clk  = 1'b0;
   logic                      tb_dma_rstn = 1'b1;
   logic                      tb_flush    = 1'b0;
   logic                      tb_pop      = 1'b0;
   logic [SMP_DW-1:0]         tb_data_o;
   logic                      tb_empty;
   logic                      tb_full;

   clk_gen #(.FREQ (ADC_FREQ)) u_clk_adc (.i_enable(1'b1), .o_clk(tb_adc_clk));
   clk_gen #(.FREQ (DMA_FREQ)) u_clk_dma (.i_enable(1'b1), .o_clk(tb_dma_clk));

   initial begin
      $dumpfile("smp_fifo_dc.vcd");
      $dumpvars();
   end

   smp_fifo_dc #(
      .SMP_CK  ( SMP_CK  ),
      .SMP_DW  ( SMP_DW  ),
      .FIFO_AW ( FIFO_AW )
   ) dut (
      .adc_clk_i   ( tb_adc_clk  ),
      .adc_rst_ni  ( tb_adc_rstn ),
      .dma_clk_i   ( tb_dma_clk  ),
      .dma_rst_ni  ( tb_dma_rstn ),
      .flush_i     ( tb_flush    ),
      .flush_o     (             ),
      .adc_push_i  ( tb_push     ),
      .adc_data_i  ( tb_data_i   ),
      .dma_pop_i   ( tb_pop      ),
      .dma_pop_o   (             ),
      .dma_qty_o   (             ),
      .dma_empty_o ( tb_empty    ),
      .dt_o        ( tb_data_o   ),
      .full_o      ( tb_full     ),
      .debug_do    (             )
   );

   // Pack SMP_CK samples LSB-first (sample k at bit offset SMP_DW*k),
   // matching wr_dt = wr_dt_r[SMP_DW*wr_cnt +: SMP_DW] (wr_cnt counts 0..).
   function automatic logic [SMP_CK*SMP_DW-1:0] pack_burst(int base);
      logic [SMP_CK*SMP_DW-1:0] v;
      for (int k = 0; k < SMP_CK; k++)
         v[k*SMP_DW +: SMP_DW] = (base + k);
      return v;
   endfunction

   task automatic push_burst(logic [SMP_CK*SMP_DW-1:0] data);
      tb_push   <= 1'b1;
      tb_data_i <= data;
      @(posedge tb_adc_clk);
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

   task automatic fill_until_full(int max_bursts, output bit timed_out);
      int k;
      timed_out = 1'b1;
      for (k = 0; k < max_bursts; k++) begin
         push_burst(pack_burst(k*SMP_CK));
         if (tb_full === 1'b1) begin
            timed_out = 1'b0;
            break;
         end
      end
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
      // xpm_fifo_async settle window (see tag_fifo_dc's testbench).
      repeat(40) @(posedge tb_adc_clk);
      repeat(40) @(posedge tb_dma_clk);
   endtask

   task teardown();
      svunit_ut.teardown();
   endtask

   `SVUNIT_TESTS_BEGIN
   `include "smp_fifo_dc_tests.sv"
   `SVUNIT_TESTS_END

endmodule
