// ============================================================================
// File: qtt_core_tests.sv
// Description: SVUnit test cases for qtt_core. Included by
//   qtt_core_tc00.sv.
// ============================================================================

`SVTEST(tc_arm_and_trigger)
   bit ok;

   arm <= 1'b1;
   repeat(3) @(posedge adc_clk);

   // Monotonically increasing samples: index 1 (200) is the first to cross
   // th=150 (same pattern already proven at the qtt_tag_calc level). Held
   // for many cycles so it survives the whole filter/compare/encoder
   // pipeline, same reasoning as qtt_tag_calc's own testbench.
   adc_dt[0] <= pack_burst(50, 200, 300, 400);

   wait_trig(60, ok);
   `FAIL_UNLESS_LOG(ok, "trig_o never pulsed for a genuine threshold crossing while armed");

   adc_dt[0] <= '0;
   arm <= 1'b0;
`SVTEST_END

`SVTEST(tc_disarmed_never_triggers)
   bit ok;
   int c;

   arm <= 1'b0;
   adc_dt[0] <= pack_burst(50, 200, 300, 400);
   for (c = 0; c < 30; c++) begin
      @(posedge adc_clk);
      `FAIL_IF_LOG(trig === 1'b1, $sformatf("trig_o fired at cycle %0d while never armed", c));
   end
   adc_dt[0] <= '0;
`SVTEST_END

`SVTEST(tc_dma_tag_readback)
   bit ok;
   logic [31:0] data;

   arm <= 1'b1;
   repeat(3) @(posedge adc_clk);
   adc_dt[0] <= pack_burst(50, 200, 300, 400);

   wait_trig(60, ok);
   `FAIL_IF_LOG(!ok, "trig_o never pulsed");
   adc_dt[0] <= '0;

   // Let the tag propagate: qtt_tag_calc -> tag_gen -> tag_mem's async FIFO
   // -> its dma_clk-only ring buffer.
   repeat(60) @(posedge ps_clk);

   // dma_mem_sel_i = 3'b000 selects tag channel 0 (the only channel here).
   dma_read_one(3'b000, data, ok);
   `FAIL_UNLESS_LOG(ok, "DMA readback of the tag channel never completed (tlast not seen)");
   `FAIL_UNLESS_LOG(data[2:0] === 3'd1,
      $sformatf("tag_dt_o[2:0]=%0d, expected 1 (sample index 200 was the first to cross th=150)", data[2:0]));

   arm <= 1'b0;
`SVTEST_END

`SVTEST(tc_qtt_rst_flush)
   bit ok;
   int cyc;

   arm <= 1'b1;
   repeat(3) @(posedge adc_clk);
   adc_dt[0] <= pack_burst(50, 200, 300, 400);
   wait_trig(60, ok);
   `FAIL_IF_LOG(!ok, "trig_o never pulsed");
   adc_dt[0] <= '0;
   arm <= 1'b0;
   repeat(30) @(posedge ps_clk);

   qtt_rst_req <= 1'b1;
   cyc = 0;
   while (qtt_rst_ack !== 1'b1 && cyc < 300) begin
      @(posedge adc_clk);
      cyc++;
   end
   `FAIL_UNLESS_LOG(qtt_rst_ack === 1'b1, "qtt_rst_ack_o never asserted for a qtt_rst_req_i");

   qtt_rst_req <= 1'b0;
   cyc = 0;
   while (qtt_rst_ack !== 1'b0 && cyc < 300) begin
      @(posedge adc_clk);
      cyc++;
   end
   `FAIL_UNLESS_LOG(qtt_rst_ack === 1'b0, "qtt_rst_ack_o never cleared once qtt_rst_req_i dropped");
`SVTEST_END

`SVTEST(tc_smp_and_arm_readback)
   bit ok;
   logic [31:0] data;

   arm <= 1'b1;
   repeat(3) @(posedge adc_clk);
   adc_dt[0] <= pack_burst(50, 200, 300, 400);
   wait_trig(60, ok);
   `FAIL_IF_LOG(!ok, "trig_o never pulsed");
   adc_dt[0] <= '0;

   // Disarm: arm_t10 (the falling edge of the synced arm signal) is what
   // pushes a trig-count entry into the ARM_STORE ring buffer.
   arm <= 1'b0;
   repeat(30) @(posedge ps_clk);

   // dma_mem_sel_i = 3'b101 selects the sample-store channel.
   dma_read_one(3'b101, data, ok);
   `FAIL_UNLESS_LOG(ok, "DMA readback of the sample-store channel never completed");

   // dma_mem_sel_i = 3'b100 selects the ARM_STORE (trigger count) channel.
   dma_read_one(3'b100, data, ok);
   `FAIL_UNLESS_LOG(ok, "DMA readback of the arm-store channel never completed");
`SVTEST_END
