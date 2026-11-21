//-------------------------------------------------------------------------------------------------//
// tests.sv
// Included between `SVUNIT_TESTS_BEGIN and `SVUNIT_TESTS_END inside rising_edge_det_unit_test
//
// DUT: delay_r <= i_strobe (posedge);  o_pulse = !delay_r & i_strobe (combinational)
// => o_pulse is high during the whole cycle in which i_strobe is 1 while delay_r is
//    still the previous (0) value. It clears on the next posedge.
//
// Timing model used here:
//   - Drive i_strobe right AFTER a posedge (so it is stable for the whole cycle).
//   - The pulse (if any) is valid for that cycle; sample it on the negedge of the
//     SAME cycle.
//-------------------------------------------------------------------------------------------------//

`SVTEST(test00_reset)
  // Keep strobe low: output pulse must stay low across reset cycles
  tb_strobe = 1'b0;
  @(posedge tb_clk);
  for (integer k = 0; k < 10; k = k + 1) begin
    tb_rstn = 1'b0;
    @(posedge tb_clk);
    tb_rstn = 1'b1;
    @(posedge tb_clk);
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_pulse == 1'b0);
  end
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
// A single 0 -> 1 transition on i_strobe must generate exactly one pulse
`SVTEST(test01_single_rising_edge)
  tb_strobe = 1'b0;
  repeat(3) @(posedge tb_clk);
  @(negedge tb_clk);
  `FAIL_UNLESS(tb_pulse == 1'b0);

  // Drive the rising edge right after the posedge
  @(posedge tb_clk);
  tb_strobe = 1'b1;
  @(negedge tb_clk);
  // This cycle: delay_r still 0, i_strobe 1 -> pulse high
  `FAIL_UNLESS(tb_pulse == 1'b1);

  // Next cycle: delay_r becomes 1 -> pulse low
  @(posedge tb_clk);
  @(negedge tb_clk);
  `FAIL_UNLESS(tb_pulse == 1'b0);

  // Stay high a few cycles: pulse must remain low
  repeat(4) begin
    @(posedge tb_clk);
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_pulse == 1'b0);
  end
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
// A level held high must NOT produce more than one pulse
`SVTEST(test02_no_pulse_on_level_high)
  tb_strobe = 1'b0;
  repeat(2) @(posedge tb_clk);

  @(posedge tb_clk);
  tb_strobe = 1'b1;
  @(negedge tb_clk);
  `FAIL_UNLESS(tb_pulse == 1'b1);   // one pulse on the edge

  // Hold high for many cycles: no further pulses
  for (integer k = 0; k < 10; k = k + 1) begin
    @(posedge tb_clk);
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_pulse == 1'b0);
  end
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
// A falling edge (1 -> 0) must NOT generate a pulse
`SVTEST(test03_no_pulse_on_falling_edge)
  // Produce a rising edge and let it settle
  tb_strobe = 1'b0;
  repeat(2) @(posedge tb_clk);

  @(posedge tb_clk);
  tb_strobe = 1'b1;
  @(negedge tb_clk);
  `FAIL_UNLESS(tb_pulse == 1'b1);

  @(posedge tb_clk);
  @(negedge tb_clk);
  `FAIL_UNLESS(tb_pulse == 1'b0);

  // Now the falling edge
  @(posedge tb_clk);
  tb_strobe = 1'b0;
  @(negedge tb_clk);
  `FAIL_UNLESS(tb_pulse == 1'b0);
  repeat(3) begin
    @(posedge tb_clk);
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_pulse == 1'b0);
  end
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
// Multiple separate rising edges must each generate exactly one pulse
`SVTEST(test04_multiple_edges)
  integer pulse_count;
  pulse_count = 0;

  tb_strobe = 1'b0;
  repeat(2) @(posedge tb_clk);

  for (integer k = 0; k < 5; k = k + 1) begin
    // Rising edge (driven right after posedge)
    @(posedge tb_clk);
    tb_strobe = 1'b1;
    @(negedge tb_clk);
    if (tb_pulse == 1'b1) pulse_count = pulse_count + 1;
    // Hold high one cycle (no extra pulses expected)
    @(posedge tb_clk);
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_pulse == 1'b0);
    // Back to low for a random gap
    @(posedge tb_clk);
    tb_strobe = 1'b0;
    repeat($urandom_range(1,5)) @(posedge tb_clk);
  end

  // Exactly one pulse per rising edge
  `FAIL_UNLESS(pulse_count == 5);
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
// Random toggling: pulse only on the 0 -> 1 transitions (reference model)
`SVTEST(test05_random_toggle)
  logic prev_strobe;
  logic exp_pulse;

  tb_strobe = 1'b0;
  @(posedge tb_clk);
  prev_strobe = 1'b0;

  for (integer k = 0; k < 40; k = k + 1) begin
    logic new_strobe;
    new_strobe = $urandom_range(0,1);
    @(posedge tb_clk);
    tb_strobe = new_strobe;
    @(negedge tb_clk);
    // Pulse is high this cycle iff strobe rose from 0 to 1 relative to
    // the value registered by delay_r (the previous strobe).
    exp_pulse = (~prev_strobe) & new_strobe;
    `FAIL_UNLESS(tb_pulse == exp_pulse);
    prev_strobe = new_strobe;
  end
`SVTEST_END

//-------------------------------------------------------------------------------------------------//