// ============================================================================
// File: xcom_cmd_hold_tests.sv
// Description: SVUnit test cases for xcom_cmd_hold. Included by xcom_cmd_hold_tc00.sv.
// ============================================================================

// op is latched before en rises, en is high for exactly HOLD clocks, and op stays until en has fallen.
`SVTEST(tc_op_before_en_and_en_width)
   int         c, en_high, first_en, op_bad, op_first_ok;

   en_high = 0; first_en = -1; op_bad = 0; op_first_ok = -1;
   strobe_cmd(OP_A);
   for (c = 0; c < 25; c++) begin
      @(posedge tb_clk);
      if (op_first_ok < 0 && h_op === OP_A) op_first_ok = c;
      if (h_en) begin
         en_high++;
         if (first_en < 0) first_en = c;
         if (h_op !== OP_A) op_bad++;
      end
   end
   `FAIL_UNLESS_LOG(en_high == HOLD, $sformatf("en was high for %0d clocks, expected HOLD = %0d", en_high, HOLD));
   `FAIL_UNLESS_LOG(op_bad == 0, "op changed while en was high");
   `FAIL_UNLESS_LOG(first_en - op_first_ok >= 2,
      $sformatf("op valid at clock %0d but en rose at %0d: op must be stable at least 2 clocks before en", op_first_ok, first_en));
`SVTEST_END

// Nothing happens without a strobe.
`SVTEST(tc_idle_without_strobe)
   int c;
   for (c = 0; c < 30; c++) begin
      @(posedge tb_clk);
      `FAIL_IF_LOG(h_en !== 1'b0, "en rose without a strobe");
   end
`SVTEST_END

// Two strobes closer together than the hold: both commands are delivered, in order, each with its own
// rising edge of en.
`SVTEST(tc_back_to_back_strobes_are_both_delivered)
   int          c, rises;
   logic        en_prev;
   logic [4:0]  ops [2];

   rises = 0; en_prev = 1'b0;
   strobe_cmd(OP_A);
   strobe_cmd(OP_B);
   for (c = 0; c < 40; c++) begin
      @(posedge tb_clk);
      if (h_en && !en_prev) begin
         if (rises < 2) ops[rises] = h_op;
         rises++;
      end
      en_prev = h_en;
   end
   `FAIL_UNLESS_LOG(rises == 2, $sformatf("saw %0d command enables for 2 strobes", rises));
   `FAIL_UNLESS_LOG(ops[0] === OP_A && ops[1] === OP_B,
      $sformatf("commands out of order or corrupted: %0d then %0d", ops[0], ops[1]));
`SVTEST_END

// A burst of strobes: only one pending strobe is remembered (a later one replaces it), but the hold must never
// produce a command that was not issued.
`SVTEST(tc_a_burst_never_produces_an_unknown_command)
   int   c;
   logic en_prev;
   int   bad;

   bad = 0; en_prev = 1'b0;
   strobe_cmd(OP_A);
   strobe_cmd(OP_B);
   strobe_cmd(OP_A);
   for (c = 0; c < 60; c++) begin
      @(posedge tb_clk);
      if (h_en && !en_prev && h_op !== OP_A && h_op !== OP_B) bad++;
      en_prev = h_en;
   end
   `FAIL_UNLESS_LOG(bad == 0, "the hold produced a command that was never issued");
`SVTEST_END

// Documents the limit this core does NOT cover on its own: it assumes strobe_i is itself a bounded pulse
// (see the header). A source that never clears the strobe (the bug xcom's CTRL_REG had before
// AUTO_CLEAR_BIT0 was enabled) still repeats the command, once every HOLD+1 clocks, instead of once.
`SVTEST(tc_uncleared_strobe_still_repeats_this_is_expected)
   int c, rises;
   logic en_prev;

   rises = 0; en_prev = 1'b0;
   fork
      hold_level(OP_A, 200);
      begin
         for (c = 0; c < 200; c++) begin
            @(posedge tb_clk);
            if (h_en && !en_prev) rises++;
            en_prev = h_en;
         end
      end
   join
   `FAIL_UNLESS_LOG(rises > 1,
      "an indefinitely-held strobe produced only one command: this contradicts the documented limit " +
      "(if this now fails, the module's behaviour changed and the header comment needs updating)");
`SVTEST_END
