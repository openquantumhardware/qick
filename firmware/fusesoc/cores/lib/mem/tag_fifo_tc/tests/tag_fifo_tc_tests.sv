// ============================================================================
// File: tag_fifo_tc_tests.sv
// Description: SVUnit test cases for tag_fifo_tc. Included by
//   tag_fifo_tc_tc00.sv.
// ============================================================================

`SVTEST(tc_empty_on_reset)
   `FAIL_UNLESS_LOG(tb_c_empty   === 1'b1, "c_empty_o should be high with nothing pushed");
   `FAIL_UNLESS_LOG(tb_dma_empty === 1'b1, "dma_empty_o should be high with nothing pushed");
   `FAIL_UNLESS_LOG(tb_full      === 1'b0, "full_o should be low with nothing pushed");
`SVTEST_END

`SVTEST(tc_dma_push_pop_sequence)
   int trace[];
   int base;

   base = 32'h1000;
   push_seq(base, 5);
   repeat(20) @(posedge tb_dma_clk);

   capture_dma_trace(80, trace);
   `FAIL_UNLESS_LOG(trace_contains_seq(trace, base, 5),
      $sformatf("expected the run %0d..%0d somewhere in the captured dt_o trace, not found", base, base+4));
`SVTEST_END

`SVTEST(tc_proc_pop_basic)
   bit timed_out;

   push_seq(32'h5000, 1);
   repeat(20) @(posedge tb_dma_clk);
   `FAIL_IF_LOG(tb_c_empty === 1'b1, "c_empty_o should be low once a tag has been pushed");

   proc_pop_and_wait(timed_out);
   `FAIL_IF_LOG(timed_out, "c_pop_o never acknowledged a tag_pop_i request");

   @(posedge tb_dma_clk); // dt_o (mem_dt) settles one cycle after c_pop_o first pulses
   `FAIL_UNLESS_LOG(tb_dt_o === 32'h5000, $sformatf("dt_o=0x%08h expected 0x00005000", tb_dt_o));

   repeat(10) @(posedge tb_dma_clk);
   `FAIL_UNLESS_LOG(tb_c_empty === 1'b1, "c_empty_o should be high again after the tProc drains the only tag");
`SVTEST_END

`SVTEST(tc_proc_has_priority_over_dma)
   bit timed_out;

   // Two tags queued; request both a DMA pop and a tProc pop at the same
   // time - the tProc side must win this cycle (do_dma_pop excludes
   // !do_proc_pop in the legacy design).
   push_seq(32'h6000, 2);
   repeat(20) @(posedge tb_dma_clk);

   tb_pop_dma <= 1'b1; // held for the whole race, unlike proc's one-shot pulse
   proc_pop_and_wait(timed_out);
   `FAIL_IF_LOG(timed_out, "c_pop_o never acknowledged a tag_pop_i request while dma_pop_i was also asserted");

   // dt_o (mem_dt) and c_pop_o are both exactly one cycle behind do_proc_pop,
   // so they become valid together, on the very cycle proc_pop_and_wait's
   // poll loop first sees c_pop_o - sample it right here. Waiting one more
   // cycle (as tc_proc_pop_basic does, harmlessly, since nothing else reads
   // there) would let dma_pop_i - still held for this race - immediately
   // overwrite dt_o with its own read result first.
   `FAIL_UNLESS_LOG(tb_dt_o === 32'h6000,
      $sformatf("dt_o=0x%08h expected 0x00006000 (the proc pop must read the oldest tag, not the DMA one)", tb_dt_o));

   tb_pop_dma <= 1'b0;
   @(posedge tb_dma_clk);
`SVTEST_END

`SVTEST(tc_full_after_filling)
   bit timed_out;
   fill_until_full(200, timed_out);
   `FAIL_IF_LOG(timed_out, "full_o never asserted after filling past FIFO_AW=4 depth");
`SVTEST_END

`SVTEST(tc_flush_recovers)
   bit timed_out;

   push_seq(32'h2000, 3);
   repeat(20) @(posedge tb_dma_clk);

   tb_flush <= 1'b1;
   repeat(10) @(posedge tb_dma_clk);
   tb_flush <= 1'b0;

   wait_dma_empty(timed_out);
   `FAIL_IF_LOG(timed_out, "tag_fifo_tc never reported dma_empty_o again after flush");
   `FAIL_UNLESS_LOG(tb_c_empty === 1'b1, "c_empty_o should also be high after flush");
   `FAIL_UNLESS_LOG(tb_full === 1'b0, "full_o should be low after a flush");

   repeat(40) @(posedge tb_dma_clk); // xpm wr_rst_busy settle (flush pulses the write-side reset)

   begin
      int trace[];
      push_seq(32'h3000, 2);
      repeat(20) @(posedge tb_dma_clk);
      capture_dma_trace(80, trace);
      `FAIL_UNLESS_LOG(trace_contains_seq(trace, 32'h3000, 2),
         "tag_fifo_tc did not behave correctly for a push/pop after flush");
   end
`SVTEST_END
