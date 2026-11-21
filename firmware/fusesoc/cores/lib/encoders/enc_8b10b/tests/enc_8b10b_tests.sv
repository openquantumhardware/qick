  //==========================================================================

  //------------------------------------------------------------------
  // Reset drives outputs to their defined idle values.
  `SVTEST(reset_values)
    `FAIL_UNLESS_EQUAL(dout_o,     10'b0)
    `FAIL_UNLESS_EQUAL(code_err_o, 1'b0)
    `FAIL_UNLESS_EQUAL(disp_o,     1'b0)   // rd = 0 => -1
    `FAIL_UNLESS_EQUAL(dout_valid_o, 1'b0)
  `SVTEST_END

  //------------------------------------------------------------------
  // All 256 data bytes, in order, from the reset disparity.
  `SVTEST(data_sweep_pass1)
    for (int b = 0; b < 256; b++) drive_check(1'b0, b[7:0]);
  `SVTEST_END

  //------------------------------------------------------------------
  // Second pass back-to-back: the running disparity entering each byte
  // now differs from pass 1, so many codes get exercised at both RD.
  // (Exhaustive both-RD equivalence is proven offline; this is the
  //  in-sim regression that the synthesizable core matches the table.)
  `SVTEST(data_sweep_two_passes)
    for (int b = 0; b < 256; b++) drive_check(1'b0, b[7:0]);
    for (int b = 0; b < 256; b++) drive_check(1'b0, b[7:0]);
  `SVTEST_END

  //------------------------------------------------------------------
  // The 12 legal control symbols encode with code_err_o = 0.
  `SVTEST(control_codes_legal)
    foreach (k_legal[j]) begin
      drive_check(1'b1, k_legal[j]);
      `FAIL_UNLESS(code_err_o == 1'b0)
    end
  `SVTEST_END

  //------------------------------------------------------------------
  // An illegal control code (e.g. K.00.0 = 8'h00) must raise code_err_o.
  // We check the flag against the golden (which carries libsv's behaviour).
  `SVTEST(control_code_illegal_flags_error)
    logic [9:0]  idx;
    logic [11:0] exp;
    idx = {1'b1, rd_model, 8'h00};
    exp = gold[idx];
    `FAIL_UNLESS(exp[11] == 1'b1)          // sanity: golden marks it illegal
    drive_check(1'b1, 8'h00);
    `FAIL_UNLESS(code_err_o == 1'b1)
  `SVTEST_END

  //------------------------------------------------------------------
  // en_i low holds the symbol and drops valid (no spurious advance).
  `SVTEST(enable_gating_holds_output)
    logic [9:0] held;
    drive_check(1'b0, 8'h55);
    held = dout_o;
    // idle a few cycles with en_i low
    din_i <= 8'hAA; k_i <= 1'b0; en_i <= 1'b0;
    repeat (4) @(posedge clk_i);
    #1;
    `FAIL_UNLESS_EQUAL(dout_o, held)       // unchanged
    `FAIL_UNLESS(dout_valid_o == 1'b0)     // valid dropped
  `SVTEST_END

  //==========================================================================

