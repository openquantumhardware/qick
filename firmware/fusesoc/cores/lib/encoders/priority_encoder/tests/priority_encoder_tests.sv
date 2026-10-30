// ============================================================================
// File: priority_encoder_tests.sv
// Description: SVUnit test cases for priority_encoder. Included by
//   priority_encoder_tc00.sv.
// ============================================================================

`SVTEST(tc_valid_low_on_idle)
   `FAIL_UNLESS_LOG(cb.tb_vld_comb === 1'b0, "vld_o (NO_REG) should be low with no bits set");
   `FAIL_UNLESS_LOG(cb.tb_vld_reg  === 1'b0, "vld_o (registered) should be low with no bits set");
`SVTEST_END

`SVTEST(tc_single_bit_various)
   logic [7:0]    pattern;
   logic [DW-1:0] exp_bin;
   logic          exp_vld;
   int            idx;
   int            patterns[3];

   patterns[0] = 0;
   patterns[1] = 3;
   patterns[2] = 7;

   for (int k = 0; k < 3; k++) begin
      idx     = patterns[k];
      pattern = (8'h1 << idx);

      cb.tb_one_hot <= pattern;
      @(cb); // NO_REG output settles combinationally onto the bus this edge
      @(cb); // sample point: comb output now visible through the CB, reg output visible next edge

      expected(pattern, exp_bin, exp_vld);
      `FAIL_UNLESS_LOG(cb.tb_bin_comb === exp_bin, $sformatf("idx %0d: bin_comb=%0d expected=%0d", idx, cb.tb_bin_comb, exp_bin));
      `FAIL_UNLESS_LOG(cb.tb_vld_comb === exp_vld, $sformatf("idx %0d: vld_comb=%0b expected=%0b", idx, cb.tb_vld_comb, exp_vld));

      @(cb); // registered output catches up one cycle later
      `FAIL_UNLESS_LOG(cb.tb_bin_reg === exp_bin, $sformatf("idx %0d: bin_reg=%0d expected=%0d", idx, cb.tb_bin_reg, exp_bin));
      `FAIL_UNLESS_LOG(cb.tb_vld_reg === exp_vld, $sformatf("idx %0d: vld_reg=%0b expected=%0b", idx, cb.tb_vld_reg, exp_vld));
   end
`SVTEST_END

`SVTEST(tc_priority_multiple_bits)
   logic [7:0]    pattern;
   logic [DW-1:0] exp_bin;
   logic          exp_vld;

   // Bits 2 and 5 set: the lowest index (2) must win.
   pattern = 8'b0010_0100;

   cb.tb_one_hot <= pattern;
   repeat(2) @(cb);

   expected(pattern, exp_bin, exp_vld);
   `FAIL_UNLESS_LOG(exp_bin == 3'd2, "reference model sanity: expected index 2");
   `FAIL_UNLESS_LOG(cb.tb_bin_comb === 3'd2, $sformatf("bin_comb=%0d, expected lowest set bit index 2", cb.tb_bin_comb));
   `FAIL_UNLESS_LOG(cb.tb_vld_comb === 1'b1, "vld_comb should be high");

   @(cb);
   `FAIL_UNLESS_LOG(cb.tb_bin_reg === 3'd2, $sformatf("bin_reg=%0d, expected lowest set bit index 2", cb.tb_bin_reg));
   `FAIL_UNLESS_LOG(cb.tb_vld_reg === 1'b1, "vld_reg should be high");
`SVTEST_END

`SVTEST(tc_deassert_returns_to_invalid)
   cb.tb_one_hot <= 8'h04;
   repeat(3) @(cb);
   `FAIL_UNLESS_LOG(cb.tb_vld_comb === 1'b1, "vld_comb should be high while a bit is set");

   cb.tb_one_hot <= 8'h00;
   repeat(2) @(cb);
   `FAIL_UNLESS_LOG(cb.tb_vld_comb === 1'b0, "vld_comb should drop once no bits are set");

   @(cb);
   `FAIL_UNLESS_LOG(cb.tb_vld_reg === 1'b0, "vld_reg should drop once no bits are set");
`SVTEST_END
