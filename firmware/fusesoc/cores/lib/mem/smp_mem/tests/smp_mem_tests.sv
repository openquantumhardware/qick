// ============================================================================
// File: smp_mem_tests.sv
// Description: SVUnit test cases for smp_mem. Included by smp_mem_tc00.sv.
// ============================================================================

`SVTEST(tc_no_capture_without_trigger)
   int c;

   tb_adc_dt <= pack_burst(16'h1000);
   for (c = 0; c < 30; c++) begin
      @(posedge tb_adc_clk);
      `FAIL_IF_LOG(tb_empty === 1'b0, $sformatf("smp_empty_o dropped at cycle %0d without any tag_wr_i", c));
   end
`SVTEST_END

`SVTEST(tc_capture_on_trigger)
   int trace[];

   // Hold a constant burst across the whole trigger window - the capture
   // pipeline (smp_wr_dt -> _r -> _2r -> _3r) only delays values, it never
   // changes them, so whatever gets captured is still this same burst
   // regardless of the exact pipeline depth.
   tb_adc_dt <= pack_burst(16'h0400);
   repeat(3) @(posedge tb_adc_clk);

   tb_tag_wr <= 1'b1;
   @(posedge tb_adc_clk);
   tb_tag_wr <= 1'b0;

   repeat(20) @(posedge tb_adc_clk);
   tb_adc_dt <= '0;
   repeat(20) @(posedge tb_dma_clk);

   capture_trace(120, trace);
   `FAIL_UNLESS_LOG(trace_contains_seq(trace, 32'h0400, SMP_CK),
      "expected the captured burst 0x0400..0x0403, in order, somewhere in the captured dma_dt_o trace, not found");
`SVTEST_END

`SVTEST(tc_sign_extension)
   int trace[];

   // 0xfffc..0xffff are negative 16-bit samples; dma_dt_o must sign-extend
   // them to 32 bits (0xfffffffc..0xffffffff), not zero-extend.
   tb_adc_dt <= pack_burst(16'hfffc);
   repeat(3) @(posedge tb_adc_clk);

   tb_tag_wr <= 1'b1;
   @(posedge tb_adc_clk);
   tb_tag_wr <= 1'b0;

   repeat(20) @(posedge tb_adc_clk);
   tb_adc_dt <= '0;
   repeat(20) @(posedge tb_dma_clk);

   capture_trace(120, trace);
   `FAIL_UNLESS_LOG(trace_contains_seq(trace, 32'hfffffffc, SMP_CK),
      "expected the sign-extended run 0xfffffffc..0xffffffff, in order, not found (dma_dt_o may be zero-extending instead)");
`SVTEST_END
