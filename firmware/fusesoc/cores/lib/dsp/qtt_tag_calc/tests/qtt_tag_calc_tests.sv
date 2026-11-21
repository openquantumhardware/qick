// ============================================================================
// File: qtt_tag_calc_tests.sv
// Description: SVUnit test cases for qtt_tag_calc. Included by
//   qtt_tag_calc_tc00.sv.
// ============================================================================

`SVTEST(tc_no_trigger_below_threshold)
   bit timed_out;

   cb.tb_th_p <= 16'd150;
   cb.tb_arm_p <= 1'b1;
   repeat(3) @(cb);

   cb.tb_dt_p <= pack4(50, 50, 50, 50); // all below threshold
   @(cb);
   cb.tb_dt_p <= '0;

   wait_vld_p(timed_out);
   `FAIL_UNLESS_LOG(timed_out, "tag_vld_o should never assert when no sample crosses the threshold");
`SVTEST_END

`SVTEST(tc_lowest_index_wins)
   bit timed_out;
   logic [31:0] expected;

   cb.tb_th_p <= 16'd150;
   cb.tb_arm_p <= 1'b1;
   repeat(3) @(cb);

   // Index 0 and 2 both cross; the lowest index (0) must be reported.
   cb.tb_dt_p <= pack4(200, 50, 300, 50);
   @(cb);
   cb.tb_dt_p <= '0;

   wait_vld_p(timed_out);
   `FAIL_IF_LOG(timed_out, "tag_vld_o never asserted for a genuine crossing");
   @(cb); // tag_dt_o's registers latch on the same cycle tag_vld_o first pulses; visible one cycle later

   expected = {TIME_CK, 3'd0}; // enc_s = 0
   `FAIL_UNLESS_LOG(cb.tb_tagdt_p === expected,
      $sformatf("tag_dt_o=0x%08h expected 0x%08h (time_ck=%0d, adc_idx=0)", cb.tb_tagdt_p, expected, TIME_CK));
`SVTEST_END

`SVTEST(tc_trigger_basic)
   bit timed_out;
   logic [31:0] expected;

   cb.tb_th_p <= 16'd150;
   cb.tb_arm_p <= 1'b1;
   repeat(3) @(cb);

   // Monotonically increasing samples: index 1 (200) is the first to cross.
   cb.tb_dt_p <= pack4(50, 200, 300, 400);
   @(cb);
   cb.tb_dt_p <= '0;

   wait_vld_p(timed_out);
   `FAIL_IF_LOG(timed_out, "tag_vld_o never asserted for a genuine crossing");
   @(cb); // see note above

   expected = {TIME_CK, 3'd1}; // enc_s = 1
   `FAIL_UNLESS_LOG(cb.tb_tagdt_p === expected,
      $sformatf("tag_dt_o=0x%08h expected 0x%08h (time_ck=%0d, adc_idx=1)", cb.tb_tagdt_p, expected, TIME_CK));
`SVTEST_END

`SVTEST(tc_arm_gating)
   bit timed_out;
   int c;

   cb.tb_th_p  <= 16'd150;
   cb.tb_arm_p <= 1'b0; // never armed

   cb.tb_dt_p <= pack4(200, 50, 300, 50); // would cross if armed
   @(cb);
   cb.tb_dt_p <= '0;

   for (c = 0; c < 30; c++) begin
      @(cb);
      `FAIL_IF_LOG(cb.tb_trig_p === 1'b1, $sformatf("trig_o fired at cycle %0d while never armed", c));
      `FAIL_IF_LOG(cb.tb_vld_p === 1'b1, $sformatf("tag_vld_o fired at cycle %0d while never armed", c));
   end
`SVTEST_END

// End-to-end through the x_inter datapath (CMP_INTER=4, filter on: the interpolation runs on the filtered
// signal, the sum of two consecutive samples, with the threshold doubled to the same scale).
`SVTEST(tc_interpolation_end_to_end)
   bit timed_out;
   logic [31:0] expected;

   // dt = [0, 0, 500, 500]; with filter on and a quiet preceding cycle:
   //   ftr_smp    = [0, 0, 500, 1000]
   //   cmp_thr_s  = 2*100 = 200 -> cmp_flg = [F,F,T,T] -> enc_s = 2
   //   ftr_prev_smp[2] = 0, ftr_smp[2] = 500 -> floor(((200-0)<<4)/(500-0)) = floor(3200/500) = 6
   //   trig_time_adc_r = enc_m1 = enc_s-1 = 1 (cfg_inter_i != 0 selects enc_m1)
   cb.tb_th_i    <= 16'd100;
   cb.tb_inter_i <= 3'd4;
   cb.tb_arm_i   <= 1'b1;
   repeat(3) @(cb);

   // x_inter reads ftr_smp[enc_s]/ftr_prev_smp[enc_s] "live" (not a snapshot
   // taken when the crossing was first seen) at the time div_start actually
   // fires, several pipeline cycles after the crossing sample arrived
   // (1 filter + 1 compare-register + 2 encoder-output-register stages).
   // Real ADC pulses are slowly varying relative to that, so the samples
   // are still in place by then; hold this synthetic pulse the same way
   // instead of a single-cycle glitch. The outer FSM only lets trigger_cmp
   // (and so x_inter's div_start) pulse once per arm/inhibit cycle even
   // though the underlying crossing condition stays true the whole time,
   // so it's safe to leave dt_i asserted and just catch the first result.
   cb.tb_dt_i <= pack4(0, 0, 500, 500);

   wait_vld_i(timed_out);
   `FAIL_IF_LOG(timed_out, "tag_vld_o (interpolating DUT) never asserted for a genuine crossing");
   @(cb); // see note above
   cb.tb_dt_i <= '0;

   expected = {TIME_CK[24:0], 3'd1, 4'd6}; // time_ck=5, adc_idx=enc_m1=1, x_int=6 (only the low 25 bits of the ck counter survive when 4 interpolation bits are appended)
   `FAIL_UNLESS_LOG(cb.tb_tagdt_i === expected,
      $sformatf("tag_dt_o=0x%08h expected 0x%08h (time_ck=%0d, adc_idx=1, x_int=6)", cb.tb_tagdt_i, expected, TIME_CK));
`SVTEST_END

// A crossing at lane 0 is timed against the previous clock's last sample, so
// its coarse count must be exactly one clock earlier than the coarse count of
// the same crossing seen at lane 2, for every interpolation depth (odd and
// even).
`SVTEST(tc_interp_enc_zero_uses_previous_clock)
   bit          timed_out;
   logic [31:0] tag0, tag2, t0, t2;
   int          k;
   int          c0, c2;

   for (k = 1; k <= 4; k++) begin
      capture_cross(k, 0, tag0, timed_out);
      `FAIL_IF_LOG(timed_out, $sformatf("interp=%0d: no tag for the lane-0 crossing", k));
      capture_cross(k, 2, tag2, timed_out);
      `FAIL_IF_LOG(timed_out, $sformatf("interp=%0d: no tag for the lane-2 crossing", k));

      t0 = tag0 >> k;
      t2 = tag2 >> k;
      c0 = int'(tag0 >> (3 + k));
      c2 = int'(tag2 >> (3 + k));
      `FAIL_UNLESS_LOG(t0[2:0] === 3'd7,
         $sformatf("interp=%0d: lane-0 crossing should be timed at sample 7 of the previous clock, got idx=%0d", k, t0[2:0]));
      `FAIL_UNLESS_LOG(t2[2:0] === 3'd1,
         $sformatf("interp=%0d: lane-2 crossing should be timed at sample 1, got idx=%0d", k, t2[2:0]));
      `FAIL_UNLESS_LOG(c0 === c2 - 1,
         $sformatf("interp=%0d: coarse count for lane 0 is %0d, lane 2 is %0d; lane 0 must be exactly one clock earlier", k, c0, c2));
   end
`SVTEST_END

// The fraction is the linear interpolation of the crossing between the sample before it and the first sample
// above the threshold, both taken from the batch that crossed (the batches are single-clock, not held), with the
// real previous sample and the threshold at the same scale. k = 4 (16 steps), SMP_CK = 4 in this bench.
// A tag is {coarse, idx[2:0], frac[3:0]}.

// Step 0 -> 500 with threshold 100: the crossing is at 100/500 = 0.2 of the interval (3.2/16, so 3).
`SVTEST(tc_interp_step_from_zero)
   bit timed_out; logic [31:0] tag;
   capture_seq(4, 100, 1'b0, pack4(0, 0, 500, 500), '0, 1'b0, 1'b0, tag, timed_out);
   `FAIL_IF_LOG(timed_out, "no tag");
   `FAIL_UNLESS_LOG(tag[6:4] === 3'd1, $sformatf("idx=%0d, expected 1 (the sample before the crossing)", tag[6:4]));
   `FAIL_UNLESS_LOG(tag[3:0] === 4'd3, $sformatf("fraction=%0d, expected 3 = floor(16*100/500)", tag[3:0]));
`SVTEST_END

// A signal that does not start from zero: -300 -100 100 300 crossing 0 exactly midway between -100 and 100.
`SVTEST(tc_interp_nonzero_baseline)
   bit timed_out; logic [31:0] tag;
   capture_seq(4, 0, 1'b0, pack4(-300, -100, 100, 300), '0, 1'b0, 1'b0, tag, timed_out);
   `FAIL_IF_LOG(timed_out, "no tag");
   `FAIL_UNLESS_LOG(tag[6:4] === 3'd1, $sformatf("idx=%0d, expected 1", tag[6:4]));
   `FAIL_UNLESS_LOG(tag[3:0] === 4'd8, $sformatf("fraction=%0d, expected 8 (half way)", tag[3:0]));
`SVTEST_END

// The crossing is between the last sample of one clock and the first of the next: the previous sample comes
// from the previous batch. -100 -> 100 is half way again.
`SVTEST(tc_interp_crossing_across_clocks)
   bit timed_out; logic [31:0] tag;
   capture_seq(4, 0, 1'b0, pack4(-500, -400, -300, -100), pack4(100, 300, 500, 700), 1'b1, 1'b0, tag, timed_out);
   `FAIL_IF_LOG(timed_out, "no tag");
   `FAIL_UNLESS_LOG(tag[6:4] === 3'd7, $sformatf("idx=%0d, expected 7 (last sample of the previous clock)", tag[6:4]));
   `FAIL_UNLESS_LOG(tag[3:0] === 4'd8, $sformatf("fraction=%0d, expected 8 (half way)", tag[3:0]));
`SVTEST_END

// Armed while the signal is already above the threshold: there is no crossing, the previous sample is already
// above it, and the fraction must be 0 (not garbage).
`SVTEST(tc_interp_already_high_gives_zero_fraction)
   bit timed_out; logic [31:0] tag;
   capture_seq(4, 100, 1'b0, pack4(500, 500, 500, 500), '0, 1'b0, 1'b1, tag, timed_out);
   `FAIL_IF_LOG(timed_out, "no tag");
   `FAIL_UNLESS_LOG(tag[3:0] === 4'd0, $sformatf("fraction=%0d, expected 0 when the previous sample is already above the threshold", tag[3:0]));
`SVTEST_END

// With the 2-sample filter the interpolation runs on the filtered signal (sum of two samples, threshold doubled
// too): a step 0 -> 500 gives filtered lanes 0 0 500 1000; threshold 100 -> 200 is 0.4 of the way, so 6.
`SVTEST(tc_interp_filtered_signal)
   bit timed_out; logic [31:0] tag;
   capture_seq(4, 100, 1'b1, pack4(0, 0, 500, 500), '0, 1'b0, 1'b0, tag, timed_out);
   `FAIL_IF_LOG(timed_out, "no tag");
   `FAIL_UNLESS_LOG(tag[3:0] === 4'd6, $sformatf("fraction=%0d, expected 6 = floor(16*200/500)", tag[3:0]));
`SVTEST_END

// The tag FIFO samples tag_dt_o in the cycle tag_vld_o pulses. The fraction must already be in the word then:
// (legacy: the fraction register was loaded at the END of that cycle, so each tag carried the fraction of the
// previous one.) Tag 1: step 0 -> 500 on lane 2, threshold 100: fraction 3. Tag 2: 0 -> 600 on lane 3 (a different
// lane and fraction): 16*200/600 = 5.
`SVTEST(tc_tag_word_is_final_when_tag_vld_pulses)
   bit          timed_out;
   logic [31:0] tag0, tag1;

   capture_two_at_vld(pack4(0, 0, 500, 500), pack4(0, 0, 0, 300), tag0, tag1, timed_out);
   `FAIL_IF_LOG(timed_out, "no tag");
   `FAIL_UNLESS_LOG(tag0[6:4] === 3'd1 && tag0[3:0] === 4'd3,
      $sformatf("tag 1 at vld: idx=%0d frac=%0d, expected idx 1 frac 3", tag0[6:4], tag0[3:0]));
   `FAIL_UNLESS_LOG(tag1[6:4] === 3'd2 && tag1[3:0] === 4'd5,
      $sformatf("tag 2 at vld: idx=%0d frac=%0d, expected idx 2 frac 5 (frac 3 would be the previous tag's)", tag1[6:4], tag1[3:0]));
`SVTEST_END

// A dead time shorter than the interpolation (2 against about 7 clocks) must not make the re-arm wait for the 8-bit
// inhibit counter to wrap (about 256 clocks): the second tag arrives within the 50-clock timeout of wait_vld_i.
`SVTEST(tc_dead_time_shorter_than_interpolation_rearms)
   bit to1, to2;
   cb.tb_arm_i     <= 1'b0;
   cb.tb_time_cnt  <= 1'b0;
   cb.tb_dt_i      <= '0;
   cb.tb_filter_i  <= 1'b0;
   cb.tb_th_i      <= 16'd100;
   cb.tb_inh_i     <= 8'd2;
   cb.tb_inter_i   <= 3'd4;
   cb.tb_rstn      <= 1'b0;
   repeat(3) @(cb);
   cb.tb_rstn      <= 1'b1;
   repeat(5) @(cb);
   cb.tb_arm_i     <= 1'b1;
   repeat(3) @(cb);
   cb.tb_dt_i <= pack4(0, 0, 500, 500);
   @(cb);
   cb.tb_dt_i <= '0;
   wait_vld_i(to1);
   `FAIL_IF_LOG(to1, "no first tag");
   repeat(12) @(cb);                         // the interpolation (about 7 clocks) is over, the dead time (2) too
   cb.tb_dt_i <= pack4(0, 0, 0, 300);
   @(cb);
   cb.tb_dt_i <= '0;
   @(cb);
   wait_vld_i(to2);
   `FAIL_IF_LOG(to2, "no second tag within 50 clocks: the re-arm waited for the inhibit counter to wrap");
`SVTEST_END
