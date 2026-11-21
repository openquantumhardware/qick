// ============================================================================
// File: tag_mem_tests.sv
// Description: SVUnit test cases for tag_mem. Included by tag_mem_tc00.sv.
// ============================================================================

`SVTEST(tc_empty_on_reset)
   `FAIL_UNLESS_LOG(tb_empty === 1'b1, "empty_o should be high with nothing pushed on any channel");
   `FAIL_UNLESS_LOG(tb_full  === 1'b0, "full_o should be low with nothing pushed");
`SVTEST_END

`SVTEST(tc_dma_mux_across_channels)
   logic [31:0] data;
   bit          timed_out;

   push_one(0, 32'hA000);
   push_one(1, 32'hB000);
   push_one(2, 32'hC000);
   repeat(20) @(posedge tb_dma_clk);

   dma_read_one(0, 100, data, timed_out);
   `FAIL_IF_LOG(timed_out, "never read back channel 0's tag over the DMA mux");
   `FAIL_UNLESS_LOG(data === 32'hA000, $sformatf("channel 0: dma_dt_o=0x%08h expected 0xa000", data));

   dma_read_one(1, 100, data, timed_out);
   `FAIL_IF_LOG(timed_out, "never read back channel 1's tag over the DMA mux");
   `FAIL_UNLESS_LOG(data === 32'hB000, $sformatf("channel 1: dma_dt_o=0x%08h expected 0xb000", data));

   dma_read_one(2, 100, data, timed_out);
   `FAIL_IF_LOG(timed_out, "never read back channel 2's tag over the DMA mux");
   `FAIL_UNLESS_LOG(data === 32'hC000, $sformatf("channel 2: dma_dt_o=0x%08h expected 0xc000", data));
`SVTEST_END

`SVTEST(tc_channel0_proc_pop)
   bit timed_out;

   push_one(0, 32'hD000);
   repeat(20) @(posedge tb_dma_clk);
   `FAIL_IF_LOG(tb_proc_qty === '0, "proc_qty_o should be nonzero once channel 0 has a tag pending");

   tb_pop_req <= 1'b1;
   @(posedge tb_adc_clk);
   tb_pop_req <= 1'b0;

   wait_pop_ack(timed_out);
   `FAIL_IF_LOG(timed_out, "qtt_pop_ack_o never acknowledged qtt_pop_req_i for channel 0");

   repeat(10) @(posedge tb_dma_clk);
   `FAIL_UNLESS_LOG(tb_proc_qty === '0, "proc_qty_o should return to 0 after the tProc drains channel 0's only tag");
`SVTEST_END

`SVTEST(tc_channel3_tied_off)
   int c;

   // MEM_QTY=3: channel 3 does not exist (tag_wr_i is only 3 bits wide), so
   // its dma_qty_o slot must stay tied to 0 regardless of activity on the
   // real channels.
   push_one(0, 32'hE000);
   push_one(1, 32'hE001);
   push_one(2, 32'hE002);
   for (c = 0; c < 20; c++) begin
      @(posedge tb_dma_clk);
      `FAIL_IF_LOG(tb_dma_qty[3] !== '0, $sformatf("dma_qty_o[3] should stay 0 (tied off), read %0d", tb_dma_qty[3]));
   end
`SVTEST_END

`SVTEST(tc_flush_via_qtt_rst)
   bit timed_out;

   // empty_o is `|empty` across all MEM_QTY channels (matches the legacy
   // source exactly) - i.e. "at least one channel is empty", not "all
   // channels are empty". With MEM_QTY=3, all three must have a pending
   // tag before empty_o reads 0.
   push_one(0, 32'hF000);
   push_one(1, 32'hF001);
   push_one(2, 32'hF002);
   repeat(20) @(posedge tb_dma_clk);
   `FAIL_IF_LOG(tb_empty === 1'b1, "empty_o should be low once every channel has a tag pending");

   tb_rst_req <= 1'b1;
   repeat(10) @(posedge tb_dma_clk);
   tb_rst_req <= 1'b0;

   wait_empty(timed_out);
   `FAIL_IF_LOG(timed_out, "empty_o never returned high after qtt_rst_req_i");
   `FAIL_UNLESS_LOG(tb_full === 1'b0, "full_o should be low after a reset/flush");
`SVTEST_END
