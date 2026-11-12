// ============================================================================
// File: x_inter_tests.sv
// Description: SVUnit test cases for x_inter. Included by x_inter_tc00.sv.
// ============================================================================

`SVTEST(tc_ready_when_idle)
   `FAIL_UNLESS_LOG(cb.tb_ready === 1'b1, "ready_o should be high when idle");
`SVTEST_END

`SVTEST(tc_interpolate_various)
   logic [IW-1:0] q;
   bit            timed_out;
   int            curr_v [5];
   int            prev_v [5];
   int            thr_v  [5];
   int            cfg_v  [5];
   int            k;

   curr_v[0] = 116; prev_v[0] = 20;  thr_v[0] = 68;  cfg_v[0] = 4; // (68-20)<<4 / 96  = 8
   curr_v[1] = 50;  prev_v[1] = 10;  thr_v[1] = 25;  cfg_v[1] = 3; // (25-10)<<3 / 40  = 3
   curr_v[2] = 40;  prev_v[2] = 0;   thr_v[2] = 10;  cfg_v[2] = 2; // (10-0)<<2  / 40  = 1
   curr_v[3] = 8;   prev_v[3] = 0;   thr_v[3] = 4;   cfg_v[3] = 1; // (4-0)<<1   / 8   = 1
   curr_v[4] = 1000;prev_v[4] = 0;   thr_v[4] = 333; cfg_v[4] = 4; // 333<<4 / 1000    = 5

   for (k = 0; k < 5; k++) begin
      run_interp(curr_v[k], prev_v[k], thr_v[k], cfg_v[k], q, timed_out);
      `FAIL_IF_LOG(timed_out, $sformatf("case %0d: x_inter never asserted end_o", k));
      `FAIL_UNLESS_LOG(q === expected_q(curr_v[k], prev_v[k], thr_v[k], cfg_v[k]),
         $sformatf("case %0d: x_int_o=%0d expected=%0d (curr=%0d prev=%0d thr=%0d cfg_inter=%0d)",
                    k, q, expected_q(curr_v[k], prev_v[k], thr_v[k], cfg_v[k]),
                    curr_v[k], prev_v[k], thr_v[k], cfg_v[k]));
      // ready_o (~working) follows the FSM back to idle one cycle after
      // end_o first pulses (div_st only re-enters IDLE on the next edge).
      @(cb);
      `FAIL_UNLESS_LOG(cb.tb_ready === 1'b1, $sformatf("case %0d: ready_o should be high again after completion", k));
   end
`SVTEST_END

`SVTEST(tc_no_interpolation_bits)
   logic [IW-1:0] q;
   bit            timed_out;

   // cfg_inter_i = 0: no interpolation bits requested, result must be 0 and
   // the DUT must not hang.
   run_interp(100, 20, 60, 0, q, timed_out);
   `FAIL_IF_LOG(timed_out, "x_inter never asserted end_o for cfg_inter_i=0");
   `FAIL_UNLESS_LOG(q === '0, $sformatf("cfg_inter_i=0 should produce x_int_o=0, got %0d", q));
`SVTEST_END

`SVTEST(tc_not_ready_while_working)
   // Start a multi-cycle interpolation and confirm ready_o drops during it.
   cb.tb_curr      <= 16'd116;
   cb.tb_prev      <= 16'd20;
   cb.tb_thr       <= 16'd68;
   cb.tb_cfg_inter <= 3'd4;
   cb.tb_start     <= 1'b1;
   @(cb);
   cb.tb_start     <= 1'b0;
   @(cb);
   `FAIL_UNLESS_LOG(cb.tb_ready === 1'b0, "ready_o should be low while interpolating");

   // Drain until done so the next test starts from an idle DUT.
   while (cb.tb_end !== 1'b1) @(cb);
`SVTEST_END
