// ============================================================================
// File: qtt_cmd_tests.sv
// Description: SVUnit test cases for qtt_cmd. Included by qtt_cmd_tc00.sv.
// ============================================================================

`SVTEST(tc_p_arm_disarm)
   bit timed_out;

   send_p_cmd(OP_ARM, 32'd0);
   wait_arm_eq(1'b1, timed_out);
   `FAIL_IF_LOG(timed_out, "qtt_arm_o never asserted for an AXI/Python ARM command");

   send_p_cmd(OP_DISARM, 32'd0);
   wait_arm_eq(1'b0, timed_out);
   `FAIL_IF_LOG(timed_out, "qtt_arm_o never deasserted for an AXI/Python DISARM command");
`SVTEST_END

`SVTEST(tc_c_cmd_arm_via_handshake)
   bit timed_out;

   // Exercises the tProc-side path through qick:cdc:cdc_handshake
   // (c_clk_i -> clk_i), distinct from the AXI/Python path above.
   send_c_cmd(OP_ARM, 32'd0);
   wait_arm_eq(1'b1, timed_out);
   `FAIL_IF_LOG(timed_out, "qtt_arm_o never asserted for a tProc ARM command");
`SVTEST_END

`SVTEST(tc_ext_arm_is_level_sensed)
   bit timed_out;

   // ext_arm_i is a level, armed/disarmed by its own rising/falling edge,
   // unlike the pulse-triggered p_en_i/c_en_i commands.
   cb.tb_ext_arm <= 1'b1;
   @(cb);
   wait_arm_eq(1'b1, timed_out);
   `FAIL_IF_LOG(timed_out, "qtt_arm_o never asserted on ext_arm_i's rising edge");

   cb.tb_ext_arm <= 1'b0;
   @(cb);
   wait_arm_eq(1'b0, timed_out);
   `FAIL_IF_LOG(timed_out, "qtt_arm_o never deasserted on ext_arm_i's falling edge");
`SVTEST_END

`SVTEST(tc_set_threshold_and_inhibit)
   int cyc;

   send_p_cmd(OP_SET_TH, 32'h0000_1234);
   cyc = 0;
   while (cb.tb_cmp_th !== 16'h1234 && cyc < 200) begin
      @(cb);
      cyc++;
   end
   `FAIL_UNLESS_LOG(cb.tb_cmp_th === 16'h1234, $sformatf("qtt_cmp_th_o=0x%04h, expected 0x1234", cb.tb_cmp_th));

   send_p_cmd(OP_SET_INH, 32'h0000_00AB);
   cyc = 0;
   while (cb.tb_cmp_inh !== 8'hAB && cyc < 200) begin
      @(cb);
      cyc++;
   end
   `FAIL_UNLESS_LOG(cb.tb_cmp_inh === 8'hAB, $sformatf("qtt_cmp_inh_o=0x%02h, expected 0xab", cb.tb_cmp_inh));
`SVTEST_END

`SVTEST(tc_reset_handshake)
   int cyc;

   send_p_cmd(OP_RESET, 32'd0);
   cyc = 0;
   while (cb.tb_rst_req !== 1'b1 && cyc < 200) begin
      @(cb);
      cyc++;
   end
   `FAIL_UNLESS_LOG(cb.tb_rst_req === 1'b1, "rst_req_o never asserted for a RESET command");

   cb.tb_rst_ack <= 1'b1;
   @(cb);
   cb.tb_rst_ack <= 1'b0;

   cyc = 0;
   while (cb.tb_rst_req !== 1'b0 && cyc < 200) begin
      @(cb);
      cyc++;
   end
   `FAIL_UNLESS_LOG(cb.tb_rst_req === 1'b0, "rst_req_o never cleared once rst_ack_i was asserted");
`SVTEST_END

`SVTEST(tc_pop_is_a_single_cycle_pulse)
   bit timed_out;

   send_p_cmd(OP_POP, 32'd0);
   wait_pop_req(timed_out);
   `FAIL_IF_LOG(timed_out, "pop_req_o never asserted for a POP command");

   @(cb);
   `FAIL_UNLESS_LOG(cb.tb_pop_req === 1'b0, "pop_req_o should self-clear after one cycle");
`SVTEST_END

`SVTEST(tc_peek_reaches_c_clk_domain)
   bit timed_out;

   send_p_cmd(OP_PEEK, 32'd0);
   wait_peek(timed_out);
   `FAIL_IF_LOG(timed_out, "peek_o never pulsed on the c_clk_i side for a PEEK command");
`SVTEST_END

// ---- qtt_cmd_hold: the AXI command is a one-clock pulse sampled in another clock domain ----

// With routing skew between the strobe and the opcode bits, the legacy path (raw one-clock pulse) loses commands
// and the held path does not. The raw path is the control: if it never lost a command this test would prove
// nothing about the hold.
`SVTEST(tc_hold_survives_skew_where_the_raw_pulse_does_not)
   int          i, lost_raw, lost_hold;
   logic [7:0]  expected;

   lost_raw = 0; lost_hold = 0;
   for (i = 0; i < 40; i++) begin
      expected = (i % 2) ? 8'd30 : 8'd20;
      tb_hold_dt = expected;
      repeat (3) @(posedge tb_ps_clk);
      strobe_cmd(OP_SET_INH);
      repeat (25) @(posedge tb_ps_clk);
      if (hold_inh !== expected) lost_hold++;
      if (raw_inh  !== expected) lost_raw++;
   end
   `FAIL_UNLESS_LOG(lost_hold == 0, $sformatf("qtt_cmd_hold lost %0d of 40 commands under 1.5 ns of skew", lost_hold));
   `FAIL_UNLESS_LOG(lost_raw > 0, "the raw one-clock pulse lost no command: the emulated skew is not exercising the problem");
`SVTEST_END
