// ============================================================================
// File: gcc_tests.sv
// Description: SVUnit test cases for gcc. Included by gcc_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_values)
   `FAIL_UNLESS_LOG(cb.tb_bin_o    === '0, "count_bin_o should be 0 after reset");
   `FAIL_UNLESS_LOG(cb.tb_gray_o   === '0, "count_gray_o should be 0 after reset");
   `FAIL_UNLESS_LOG(cb.tb_bin_p1_o === 4'h1, "count_bin_p1_o should be 1 after reset");
   `FAIL_UNLESS_LOG(cb.tb_gray_p1_o === 4'h1, "count_gray_p1_o should be 1 after reset");
`SVTEST_END

`SVTEST(tc_hold_when_disabled)
   logic [3:0] bin_before, gray_before, bin_p1_before, gray_p1_before;

   bin_before     = cb.tb_bin_o;
   gray_before    = cb.tb_gray_o;
   bin_p1_before  = cb.tb_bin_p1_o;
   gray_p1_before = cb.tb_gray_p1_o;

   repeat(10) @(cb);

   `FAIL_UNLESS_LOG(cb.tb_bin_o    === bin_before,     "count_bin_o must not move while cnt_en_i is low");
   `FAIL_UNLESS_LOG(cb.tb_gray_o   === gray_before,    "count_gray_o must not move while cnt_en_i is low");
   `FAIL_UNLESS_LOG(cb.tb_bin_p1_o === bin_p1_before,  "count_bin_p1_o must not move while cnt_en_i is low");
   `FAIL_UNLESS_LOG(cb.tb_gray_p1_o === gray_p1_before,"count_gray_p1_o must not move while cnt_en_i is low");
`SVTEST_END

// count_bin_p1_o/count_gray_p1_o track the counter itself: each enable event
// increments them by 1. count_bin_o/count_gray_o are a one-enable-event-deep
// shadow of the same registers (they capture the *previous* value of
// count_bin_p1_o/count_gray_p1_o on every enable event) - see gcc.sv: both
// pairs update inside the same `if (cnt_en_i)` branch, so count_bin_o only
// ever "catches up" to where count_bin_p1_o was after the previous pulse.
`SVTEST(tc_increment_sequence)
   logic [3:0] expect_p1;
   logic [3:0] prev_p1;
   int         i;

   expect_p1 = cb.tb_bin_p1_o; // 1, from reset
   for (i = 0; i < 20; i++) begin
      prev_p1 = cb.tb_bin_p1_o;

      pulse_cnt_en();
      // one more cycle for the registered update to become visible
      @(cb);

      expect_p1 = expect_p1 + 4'h1;

      `FAIL_UNLESS_LOG(cb.tb_bin_p1_o === expect_p1,
         $sformatf("iter %0d: count_bin_p1_o = %0d, expected %0d", i, cb.tb_bin_p1_o, expect_p1));
      `FAIL_UNLESS_LOG(cb.tb_gray_p1_o === bin2gray(expect_p1),
         $sformatf("iter %0d: count_gray_p1_o = %0d, expected gray(%0d) = %0d", i, cb.tb_gray_p1_o, expect_p1, bin2gray(expect_p1)));
      `FAIL_UNLESS_LOG(cb.tb_bin_o === prev_p1,
         $sformatf("iter %0d: count_bin_o = %0d, expected previous count_bin_p1_o = %0d", i, cb.tb_bin_o, prev_p1));
      `FAIL_UNLESS_LOG(cb.tb_gray_o === bin2gray(prev_p1),
         $sformatf("iter %0d: count_gray_o = %0d, expected gray(%0d) = %0d", i, cb.tb_gray_o, prev_p1, bin2gray(prev_p1)));
   end
`SVTEST_END

// Classic gray-code property, including across the wraparound (15 -> 0):
// consecutive codes must differ by exactly one bit.
`SVTEST(tc_gray_single_bit_change)
   logic [3:0] prev_gray, curr_gray;
   int         i;

   prev_gray = cb.tb_gray_p1_o;
   for (i = 0; i < 20; i++) begin
      pulse_cnt_en();
      @(cb);
      curr_gray = cb.tb_gray_p1_o;
      `FAIL_UNLESS_LOG($countones(curr_gray ^ prev_gray) == 1,
         $sformatf("iter %0d: gray %0h -> %0h changed %0d bits, expected 1", i, prev_gray, curr_gray, $countones(curr_gray ^ prev_gray)));
      prev_gray = curr_gray;
   end
`SVTEST_END

`SVTEST(tc_async_clear)
   // Advance the counter a few steps first so clear has something to undo.
   pulse_cnt_en(); @(cb);
   pulse_cnt_en(); @(cb);
   `FAIL_IF_LOG(cb.tb_bin_p1_o === 4'h1, "counter should have moved before testing clear");

   // async_clear_i is registered through a 2-stage pipe (clear_rcd -> clear_r)
   // before it becomes clear_r/clear_o; hold it for one cycle only.
   cb.tb_async_clear <= 1'b1;
   @(cb);
   cb.tb_async_clear <= 1'b0;
   @(cb); // clear_rcd sees it
   @(cb); // clear_r / clear_o pulse this cycle, counters reload to reset values

   `FAIL_UNLESS_LOG(cb.tb_clear_o === 1'b1, "clear_o should pulse 2 cycles after async_clear_i");

   // The reset values are the registered *effect* of clear_r being high this
   // cycle - they land one cycle later, together with clear_o's deassertion
   // (clear_r is a single-cycle pulse, not sticky).
   @(cb);
   `FAIL_UNLESS_LOG(cb.tb_clear_o === 1'b0, "clear_o should be a single-cycle pulse");
   `FAIL_UNLESS_LOG(cb.tb_bin_o    === '0,   "count_bin_o should reload to 0 on clear");
   `FAIL_UNLESS_LOG(cb.tb_gray_o   === '0,   "count_gray_o should reload to 0 on clear");
   `FAIL_UNLESS_LOG(cb.tb_bin_p1_o === 4'h1, "count_bin_p1_o should reload to 1 on clear");
   `FAIL_UNLESS_LOG(cb.tb_gray_p1_o === 4'h1,"count_gray_p1_o should reload to 1 on clear");
`SVTEST_END
