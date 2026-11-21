// ============================================================================
// File: tag_fifo_dc_tests.sv
// Description: SVUnit test cases for tag_fifo_dc. Included by
//   tag_fifo_dc_tc00.sv.
// ============================================================================

`SVTEST(tc_empty_on_reset)
   `FAIL_UNLESS_LOG(tb_empty === 1'b1, "empty_o should be high with nothing pushed");
   `FAIL_UNLESS_LOG(tb_full  === 1'b0, "full_o should be low with nothing pushed");
`SVTEST_END

`SVTEST(tc_push_pop_sequence)
   int trace[];
   int base;

   base = 32'h1000;
   push_seq(base, 5);
   repeat(20) @(posedge tb_dma_clk);

   capture_trace(80, trace);
   `FAIL_UNLESS_LOG(trace_contains_seq(trace, base, 5),
      $sformatf("expected the run %0d..%0d somewhere in the captured dma_dt_o trace, not found", base, base+4));
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

   wait_empty(timed_out);
   `FAIL_IF_LOG(timed_out, "tag_fifo_dc never reported empty again after flush");
   `FAIL_UNLESS_LOG(tb_full === 1'b0, "full_o should be low after a flush");

   // flush pulses fifo_async's write-side reset, which re-triggers the same
   // xpm wr_rst_busy settle window as a fresh reset.
   repeat(40) @(posedge tb_dma_clk);

   // Sanity: the buffer must still work normally after a flush.
   begin
      int trace[];
      push_seq(32'h3000, 2);
      repeat(20) @(posedge tb_dma_clk);
      capture_trace(80, trace);
      `FAIL_UNLESS_LOG(trace_contains_seq(trace, 32'h3000, 2),
         "tag_fifo_dc did not behave correctly for a push/pop after flush");
   end
`SVTEST_END
