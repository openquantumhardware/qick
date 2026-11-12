// ============================================================================
// File: sync_pulse_tests.sv
// Description: SVUnit test cases for sync_pulse. Included by
//   sync_pulse_tc00.sv.
// ============================================================================

`SVTEST(tc_single_pulse_crossing)
   bit timed_out;

   b_cb.tb_b_en_nb <= 1'b1;
   @(a_cb);
   a_cb.tb_a_pulse_nb <= 1'b1;
   @(a_cb);
   a_cb.tb_a_pulse_nb <= 1'b0;

   wait_pulse_nb(timed_out);
   `FAIL_IF_LOG(timed_out, "b_pulse_o never asserted for a single a_pulse_i");

   @(b_cb);
   `FAIL_UNLESS_LOG(b_cb.tb_b_pulse_nb === 1'b0, "b_pulse_o must be a single-cycle pulse");
`SVTEST_END

`SVTEST(tc_multiple_pulses_no_block)
   int count;

   b_cb.tb_b_en_nb <= 1'b1;
   send_pulses_nb(5);
   count_pulses_nb(100, count);

   `FAIL_UNLESS_LOG(count == 5, $sformatf("expected 5 pulses to cross, got %0d", count));
`SVTEST_END

`SVTEST(tc_b_en_gating)
   int c;

   b_cb.tb_b_en_nb <= 1'b0;
   @(a_cb);
   a_cb.tb_a_pulse_nb <= 1'b1;
   @(a_cb);
   a_cb.tb_a_pulse_nb <= 1'b0;

   // Give the pulse plenty of time to cross the CDC and sit in the queue;
   // with b_en_i low it must not be dispensed.
   for (c = 0; c < 30; c++) begin
      @(b_cb);
      `FAIL_IF_LOG(b_cb.tb_b_pulse_nb === 1'b1, $sformatf("b_pulse_o fired at cycle %0d while b_en_i was low", c));
   end

   b_cb.tb_b_en_nb <= 1'b1;
   begin
      bit timed_out;
      wait_pulse_nb(timed_out);
      `FAIL_IF_LOG(timed_out, "queued pulse never came out once b_en_i was raised");
   end
`SVTEST_END

`SVTEST(tc_no_block_never_asserts_full)
   int c;

   b_cb.tb_b_en_nb <= 1'b0; // never drain, so the queue would overflow if unguarded
   for (c = 0; c < 40; c++) begin
      a_cb.tb_a_pulse_nb <= 1'b1;
      @(a_cb);
      `FAIL_IF_LOG(a_cb.tb_full_nb === 1'b1, "pulse_full must stay low when BLOCK=0");
   end
   a_cb.tb_a_pulse_nb <= 1'b0;
`SVTEST_END

`SVTEST(tc_block_backpressure)
   bit timed_out;
   int drained;

   // Overload the queue (QUEUE_AW=3 => at most 7 outstanding pulses) with
   // the consumer disabled; BLOCK=1 must assert pulse_full instead of
   // silently overrunning the pointer.
   b_cb.tb_b_en_bl <= 1'b0;
   fork
      send_pulses_bl(40);
      begin
         wait_full_bl(timed_out);
         `FAIL_IF_LOG(timed_out, "pulse_full never asserted while overloading a BLOCK=1 queue");
      end
   join

   `FAIL_UNLESS_LOG(a_cb.tb_full_bl === 1'b1, "pulse_full should still be asserted right after overload");

   // Drain: no more than the queue capacity should ever come out, and
   // pulse_full must clear again once it does.
   b_cb.tb_b_en_bl <= 1'b1;
   count_pulses_bl(200, drained);

   `FAIL_UNLESS_LOG(drained > 0 && drained <= 7,
      $sformatf("drained %0d pulses from a BLOCK=1, QUEUE_AW=3 queue, expected 1-7", drained));
   `FAIL_UNLESS_LOG(a_cb.tb_full_bl === 1'b0, "pulse_full should clear once the queue is drained");
`SVTEST_END
