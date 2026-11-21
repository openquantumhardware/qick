// ============================================================================
// File: tag_gen_tests.sv
// Description: SVUnit test cases for tag_gen. Included by tag_gen_tc00.sv.
// ============================================================================

`SVTEST(tc_independent_channels)
   bit timed_out;
   logic [31:0] expected0, expected1;
   int c;

   cb.tb_th <= 16'd150;
   cb.tb_en <= 1'b1;
   repeat(3) @(cb);

   // ch0: index 1 (200) is the first to cross. ch1: index 0 (200) already
   // crosses, a different crossing index on purpose to catch swapped wiring.
   cb.tb_dt0 <= pack4(50, 200, 300, 400);
   cb.tb_dt1 <= pack4(200, 50, 300, 50);
   @(cb);
   cb.tb_dt0 <= '0;
   cb.tb_dt1 <= '0;

   wait_both_vld(timed_out);
   `FAIL_IF_LOG(timed_out, "both channels should report tag_vld_o for their own crossing");
   @(cb); // tag_dt_o registers latch on the trigger cycle, visible one cycle after tag_vld_o first pulses

   expected0 = {TIME_CK, 3'd1};
   expected1 = {TIME_CK, 3'd0};
   `FAIL_UNLESS_LOG(cb.tb_tagdt0 === expected0,
      $sformatf("channel 0: tag_dt_o=0x%08h expected 0x%08h", cb.tb_tagdt0, expected0));
   `FAIL_UNLESS_LOG(cb.tb_tagdt1 === expected1,
      $sformatf("channel 1: tag_dt_o=0x%08h expected 0x%08h", cb.tb_tagdt1, expected1));
`SVTEST_END

`SVTEST(tc_trig_and_cmp_pulse)
   bit trig_seen, cmp_seen;
   int c;

   cb.tb_th <= 16'd150;
   cb.tb_en <= 1'b1;
   repeat(3) @(cb);

   cb.tb_dt0 <= pack4(50, 200, 300, 400);
   cb.tb_dt1 <= pack4(200, 50, 300, 50);
   @(cb);
   cb.tb_dt0 <= '0;
   cb.tb_dt1 <= '0;

   trig_seen = 1'b0;
   cmp_seen  = 1'b0;
   for (c = 0; c < 30; c++) begin
      @(cb);
      if (cb.tb_trig) trig_seen = 1'b1;
      if (cb.tb_cmp)  cmp_seen  = 1'b1;
   end

   `FAIL_UNLESS_LOG(trig_seen, "trig_o (channel 0 tap) never pulsed for a genuine crossing");
   `FAIL_UNLESS_LOG(cmp_seen,  "cmp_o (channel 0 tap) never pulsed for a genuine crossing");
`SVTEST_END
