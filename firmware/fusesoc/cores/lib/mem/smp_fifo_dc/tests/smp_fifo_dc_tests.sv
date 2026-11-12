// ============================================================================
// File: smp_fifo_dc_tests.sv
// Description: SVUnit test cases for smp_fifo_dc. Included by
//   smp_fifo_dc_tc00.sv.
// ============================================================================

`SVTEST(tc_empty_on_reset)
   `FAIL_UNLESS_LOG(tb_empty === 1'b1, "dma_empty_o should be high with nothing pushed");
   `FAIL_UNLESS_LOG(tb_full  === 1'b0, "full_o should be low with nothing pushed");
`SVTEST_END

`SVTEST(tc_single_burst_unpack)
   int trace[];

   push_burst(pack_burst(32'h1000));
   repeat(20) @(posedge tb_dma_clk);

   capture_trace(80, trace);
   `FAIL_UNLESS_LOG(trace_contains_seq(trace, 32'h1000, SMP_CK),
      "expected the unpacked burst 0x1000..0x1003, in order, somewhere in the captured dt_o trace, not found");
`SVTEST_END

`SVTEST(tc_multi_burst_stays_in_order)
   int trace[];

   push_burst(pack_burst(32'h2000));
   push_burst(pack_burst(32'h2000 + SMP_CK));
   repeat(20) @(posedge tb_dma_clk);

   capture_trace(80, trace);
   `FAIL_UNLESS_LOG(trace_contains_seq(trace, 32'h2000, 2*SMP_CK),
      "expected both unpacked bursts back to back (0x2000..0x2007), in order, not found");
`SVTEST_END

`SVTEST(tc_full_after_filling)
   bit timed_out;
   fill_until_full(80, timed_out);
   `FAIL_IF_LOG(timed_out, "full_o never asserted after filling past FIFO_AW=4 depth");
`SVTEST_END

`SVTEST(tc_flush_recovers)
   bit timed_out;

   push_burst(pack_burst(32'h3000));
   repeat(20) @(posedge tb_dma_clk);

   tb_flush <= 1'b1;
   repeat(10) @(posedge tb_dma_clk);
   tb_flush <= 1'b0;

   wait_empty(timed_out);
   `FAIL_IF_LOG(timed_out, "smp_fifo_dc never reported empty again after flush");
   `FAIL_UNLESS_LOG(tb_full === 1'b0, "full_o should be low after a flush");

   repeat(40) @(posedge tb_dma_clk); // xpm wr_rst_busy settle

   begin
      int trace[];
      push_burst(pack_burst(32'h4000));
      repeat(20) @(posedge tb_dma_clk);
      capture_trace(80, trace);
      `FAIL_UNLESS_LOG(trace_contains_seq(trace, 32'h4000, SMP_CK),
         "smp_fifo_dc did not behave correctly for a push/pop after flush");
   end
`SVTEST_END
