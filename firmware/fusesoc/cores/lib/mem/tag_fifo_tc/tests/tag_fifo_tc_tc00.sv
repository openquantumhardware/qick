// ============================================================================
// File: tag_fifo_tc_tc00.sv
// Description: SVUnit testbench top-level for tag_fifo_tc.
//
// No clocking blocks, on purpose - this DUT wraps qick:mem:fifo_async
// (xpm_fifo_async); see TESTBENCH_PATTERNS.md #20 and tag_fifo_dc's own
// testbench for why. Every drive is `sig <= val` right before
// @(posedge clk); every read of a DUT output happens right after it.
//
// c_clk_i/c_rst_ni are present on the DUT's port list but never actually
// used inside tag_fifo_tc (matches the legacy TAG_FIFO_TC exactly - its
// tProc-pop CDC is keyed off tag_clk_i, not c_clk_i; a dead-port quirk in
// the original source, preserved faithfully). c_clk is still driven here
// for port-list completeness, but no test depends on its timing.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module tag_fifo_tc_unit_test;
   import svunit_pkg::svunit_testcase;

   localparam int FIFO_AW = 4; // 16-entry ring buffer

   string name = "tag_fifo_tc_ut";
   svunit_testcase svunit_ut;

   localparam real TAG_FREQ = 300e6;
   localparam real C_FREQ   = 150e6;
   localparam real DMA_FREQ = 100e6;

   logic         tb_tag_clk  = 1'b0;
   logic         tb_tag_rstn = 1'b1;
   logic         tb_push     = 1'b0;
   logic [31:0]  tb_data_i   = '0;
   logic         tb_pop_c    = 1'b0; // tag_pop_i (tProc side), sampled on tag_clk per the DUT

   logic         tb_c_clk    = 1'b0;
   logic         tb_c_rstn   = 1'b1;

   logic         tb_dma_clk  = 1'b0;
   logic         tb_dma_rstn = 1'b1;
   logic         tb_flush    = 1'b0;
   logic         tb_pop_dma  = 1'b0;
   logic [31:0]  tb_dt_o;
   logic         tb_c_empty;
   logic         tb_c_pop_o;
   logic [FIFO_AW-1:0] tb_c_qty;
   logic         tb_dma_empty;
   logic         tb_full;

   clk_gen #(.FREQ (TAG_FREQ)) u_clk_tag (.i_enable(1'b1), .o_clk(tb_tag_clk));
   clk_gen #(.FREQ (C_FREQ))   u_clk_c   (.i_enable(1'b1), .o_clk(tb_c_clk));
   clk_gen #(.FREQ (DMA_FREQ)) u_clk_dma (.i_enable(1'b1), .o_clk(tb_dma_clk));

   initial begin
      $dumpfile("tag_fifo_tc.vcd");
      $dumpvars();
   end

   tag_fifo_tc #(
      .TAG_DW  ( 32      ),
      .FIFO_AW ( FIFO_AW )
   ) dut (
      .tag_clk_i   ( tb_tag_clk   ),
      .tag_rst_ni  ( tb_tag_rstn  ),
      .c_clk_i     ( tb_c_clk     ),
      .c_rst_ni    ( tb_c_rstn    ),
      .dma_clk_i   ( tb_dma_clk   ),
      .dma_rst_ni  ( tb_dma_rstn  ),
      .flush_i     ( tb_flush     ),
      .flush_o     (              ),
      .tag_push_i  ( tb_push      ),
      .tag_data_i  ( tb_data_i    ),
      .tag_pop_i   ( tb_pop_c     ),
      .c_pop_o     ( tb_c_pop_o   ),
      .c_qty_o     ( tb_c_qty     ),
      .c_empty_o   ( tb_c_empty   ),
      .dma_pop_i   ( tb_pop_dma   ),
      .dma_pop_o   (              ),
      .dma_qty_o   (              ),
      .dma_empty_o ( tb_dma_empty ),
      .dt_o        ( tb_dt_o      ),
      .full_o      ( tb_full      ),
      .debug_do    (              )
   );

   task automatic push_seq(int base, int n);
      int k;
      for (k = 0; k < n; k++) begin
         tb_push   <= 1'b1;
         tb_data_i <= (base + k);
         @(posedge tb_tag_clk);
      end
      tb_push <= 1'b0;
      @(posedge tb_tag_clk);
   endtask

   task automatic capture_dma_trace(int cycles, output int trace[]);
      int k;
      trace = new[cycles];
      tb_pop_dma <= 1'b1;
      for (k = 0; k < cycles; k++) begin
         @(posedge tb_dma_clk);
         trace[k] = tb_dt_o;
      end
      tb_pop_dma <= 1'b0;
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

   task automatic wait_c_empty(output bit timed_out);
      int cyc;
      timed_out = 1'b0;
      cyc = 0;
      while (tb_c_empty !== 1'b1) begin
         @(posedge tb_dma_clk);
         cyc++;
         if (cyc > 300) begin
            timed_out = 1'b1;
            return;
         end
      end
   endtask

   task automatic wait_dma_empty(output bit timed_out);
      int cyc;
      timed_out = 1'b0;
      cyc = 0;
      while (tb_dma_empty !== 1'b1) begin
         @(posedge tb_dma_clk);
         cyc++;
         if (cyc > 300) begin
            timed_out = 1'b1;
            return;
         end
      end
   endtask

   // Pulse the tProc-side pop request for exactly one tag_clk cycle, then
   // wait (on dma_clk) for c_pop_o to acknowledge it.
   task automatic proc_pop_and_wait(output bit timed_out);
      int cyc;
      tb_pop_c <= 1'b1;
      @(posedge tb_tag_clk);
      tb_pop_c <= 1'b0;

      timed_out = 1'b0;
      cyc = 0;
      while (tb_c_pop_o !== 1'b1) begin
         @(posedge tb_dma_clk);
         cyc++;
         if (cyc > 300) begin
            timed_out = 1'b1;
            return;
         end
      end
   endtask

   task automatic fill_until_full(int max_cycles, output bit timed_out);
      int k;
      timed_out = 1'b1;
      tb_push <= 1'b1;
      for (k = 0; k < max_cycles; k++) begin
         tb_data_i <= k;
         @(posedge tb_tag_clk);
         if (tb_full === 1'b1) begin
            timed_out = 1'b0;
            break;
         end
      end
      tb_push <= 1'b0;
      @(posedge tb_tag_clk);
   endtask

   function void build();
      svunit_ut = new(name);
   endfunction

   task setup();
      svunit_ut.setup();
      tb_push    <= 1'b0;
      tb_data_i  <= '0;
      tb_pop_c   <= 1'b0;
      tb_flush   <= 1'b0;
      tb_pop_dma <= 1'b0;

      tb_tag_rstn <= 1'b0;
      tb_c_rstn   <= 1'b0;
      tb_dma_rstn <= 1'b0;
      repeat(8) @(posedge tb_tag_clk);
      tb_tag_rstn <= 1'b1;
      tb_c_rstn   <= 1'b1;
      tb_dma_rstn <= 1'b1;
      // xpm_fifo_async settle window (see tag_fifo_dc's testbench).
      repeat(40) @(posedge tb_tag_clk);
      repeat(40) @(posedge tb_dma_clk);
   endtask

   task teardown();
      svunit_ut.teardown();
   endtask

   `SVUNIT_TESTS_BEGIN
   `include "tag_fifo_tc_tests.sv"
   `SVUNIT_TESTS_END

endmodule
