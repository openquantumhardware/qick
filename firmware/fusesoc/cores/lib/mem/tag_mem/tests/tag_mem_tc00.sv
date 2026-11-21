// ============================================================================
// File: tag_mem_tc00.sv
// Description: SVUnit testbench top-level for tag_mem (MEM_QTY=3: channel 0
//   is qick:mem:tag_fifo_tc, channels 1-2 are qick:mem:tag_fifo_dc, channel
//   3 is tied off). Both sub-cores are already thoroughly unit-tested on
//   their own; this focuses on the integration risk - per-channel array
//   wiring, the dma_sel_i mux, the tie-off of unused channels, and the
//   qtt_pop_req_i/qtt_rst_req_i routing to channel 0 only.
//
// No clocking blocks, on purpose (both sub-cores wrap qick:mem:fifo_async /
// xpm_fifo_async) - see TESTBENCH_PATTERNS.md #20.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module tag_mem_unit_test;
   import svunit_pkg::svunit_testcase;

   localparam int MEM_QTY     = 3;
   localparam int TAG_FIFO_AW = 4; // small ring buffers, easy to fill in a test

   string name = "tag_mem_ut";
   svunit_testcase svunit_ut;

   localparam real ADC_FREQ = 300e6;
   localparam real C_FREQ   = 150e6;
   localparam real DMA_FREQ = 100e6;

   logic         tb_dma_clk  = 1'b0;
   logic         tb_dma_rstn = 1'b1;
   logic         tb_c_clk    = 1'b0;
   logic         tb_c_rstn   = 1'b1;
   logic         tb_adc_clk  = 1'b0;
   logic         tb_adc_rstn = 1'b1;

   logic         tb_pop_req  = 1'b0;
   logic         tb_pop_ack;
   logic         tb_rst_req  = 1'b0;
   logic         tb_rst_ack;

   logic [MEM_QTY-1:0] tb_wr     = '0;
   logic [31:0]        tb_dt [MEM_QTY];

   logic [TAG_FIFO_AW-1:0] tb_dma_qty [4];
   logic [TAG_FIFO_AW-1:0] tb_proc_qty;
   logic                   tb_empty;
   logic                   tb_full;

   logic [1:0]   tb_dma_sel  = '0;
   logic         tb_dma_pop  = 1'b0;
   logic         tb_dma_pop_o;
   logic [31:0]  tb_dma_dt;

   clk_gen #(.FREQ (ADC_FREQ)) u_clk_adc (.i_enable(1'b1), .o_clk(tb_adc_clk));
   clk_gen #(.FREQ (C_FREQ))   u_clk_c   (.i_enable(1'b1), .o_clk(tb_c_clk));
   clk_gen #(.FREQ (DMA_FREQ)) u_clk_dma (.i_enable(1'b1), .o_clk(tb_dma_clk));

   initial begin
      tb_dt[0] = '0;
      tb_dt[1] = '0;
      tb_dt[2] = '0;
   end

   initial begin
      $dumpfile("tag_mem.vcd");
      $dumpvars();
   end

   tag_mem #(
      .MEM_QTY     ( MEM_QTY     ),
      .TAG_FIFO_AW ( TAG_FIFO_AW ),
      .DEBUG       ( 0           )
   ) dut (
      .dma_clk_i     ( tb_dma_clk  ),
      .dma_rst_ni    ( tb_dma_rstn ),
      .c_clk_i       ( tb_c_clk    ),
      .c_rst_ni      ( tb_c_rstn   ),
      .adc_clk_i     ( tb_adc_clk  ),
      .adc_rst_ni    ( tb_adc_rstn ),
      .qtt_pop_req_i ( tb_pop_req  ),
      .qtt_pop_ack_o ( tb_pop_ack  ),
      .qtt_rst_req_i ( tb_rst_req  ),
      .qtt_rst_ack_o ( tb_rst_ack  ),
      .tag_wr_i      ( tb_wr       ),
      .tag_dt_i      ( tb_dt       ),
      .dma_qty_o     ( tb_dma_qty  ),
      .proc_qty_o    ( tb_proc_qty ),
      .empty_o       ( tb_empty    ),
      .full_o        ( tb_full     ),
      .dma_sel_i     ( tb_dma_sel  ),
      .dma_pop_i     ( tb_dma_pop  ),
      .dma_pop_o     ( tb_dma_pop_o),
      .dma_dt_o      ( tb_dma_dt   ),
      .debug_do      (             )
   );

   // Push one word to channel `ch` for one adc_clk cycle.
   task automatic push_one(int ch, logic [31:0] data);
      tb_wr[ch] <= 1'b1;
      tb_dt[ch] <= data;
      @(posedge tb_adc_clk);
      tb_wr[ch] <= 1'b0;
      @(posedge tb_adc_clk);
   endtask

   task automatic wait_pop_ack(output bit timed_out);
      int cyc;
      timed_out = 1'b0;
      cyc = 0;
      while (tb_pop_ack !== 1'b1) begin
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

   // Read one word from channel `ch` via the DMA mux (dma_sel_i), returning
   // the first non-zero dma_dt_o sample seen while popping (channels here
   // never legitimately hold data 0, so this is an adequate capture rule
   // for a single expected word).
   task automatic dma_read_one(int ch, int max_cycles, output logic [31:0] data, output bit timed_out);
      int k;
      timed_out = 1'b1;
      data = '0;
      tb_dma_sel <= ch[1:0];
      tb_dma_pop <= 1'b1;
      for (k = 0; k < max_cycles; k++) begin
         @(posedge tb_dma_clk);
         if (tb_dma_dt !== 32'h0) begin
            data = tb_dma_dt;
            timed_out = 1'b0;
            break;
         end
      end
      tb_dma_pop <= 1'b0;
      @(posedge tb_dma_clk);
   endtask

   function void build();
      svunit_ut = new(name);
   endfunction

   task setup();
      svunit_ut.setup();
      tb_wr      <= '0;
      tb_pop_req <= 1'b0;
      tb_rst_req <= 1'b0;
      tb_dma_sel <= '0;
      tb_dma_pop <= 1'b0;

      tb_adc_rstn <= 1'b0;
      tb_c_rstn   <= 1'b0;
      tb_dma_rstn <= 1'b0;
      repeat(8) @(posedge tb_adc_clk);
      tb_adc_rstn <= 1'b1;
      tb_c_rstn   <= 1'b1;
      tb_dma_rstn <= 1'b1;
      // xpm_fifo_async settle window, x3 channels sharing the reset.
      repeat(40) @(posedge tb_adc_clk);
      repeat(40) @(posedge tb_dma_clk);
   endtask

   task teardown();
      svunit_ut.teardown();
   endtask

   `SVUNIT_TESTS_BEGIN
   `include "tag_mem_tests.sv"
   `SVUNIT_TESTS_END

endmodule
