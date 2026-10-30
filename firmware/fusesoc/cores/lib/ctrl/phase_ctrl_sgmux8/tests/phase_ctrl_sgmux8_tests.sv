// ============================================================================
// File: phase_ctrl_sgmux8_tests.sv
// Description: SVUnit test cases for phase_ctrl_sgmux8. Included by
//              phase_ctrl_sgmux8_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_clears_output)
    // The opcode byte (8'h01) is a hardcoded constant in the output
    // concatenation, not a register -- it is present even at reset. Only
    // the data fields (phase, pinc_N) are expected to be zero.
    for (int i = 0; i < N_DDS; i++) begin
        `FAIL_UNLESS(lane_opcode(i) === 8'h01);
        `FAIL_UNLESS(lane_phase(i) === 32'd0);
        `FAIL_UNLESS(lane_pinc_n(i) === 32'd0);
    end
`SVTEST_END

`SVTEST(tc_no_write_without_we_keeps_pinc_n_zero)
    // Drive PINC nonzero but never assert we_reg: pinc_reg_r/poff_reg_r must
    // stay at their reset value, so the pinc_N field (PINC*N_DDS) stays 0.
    @(negedge tb_clk);
    tb_pinc_reg = 32'h0000_1000;
    tb_we_reg   = 1'b0;
    repeat(20) @(posedge tb_clk);
    @(negedge tb_clk);
    `FAIL_UNLESS(lane_pinc_n(0) === 32'd0);
`SVTEST_END

`SVTEST(tc_opcode_is_correct_in_all_lanes)
    write_regs(32'h0000_1000, 32'h0000_0000);
    for (int i = 0; i < N_DDS; i++) begin
        `FAIL_UNLESS(lane_opcode(i) === 8'h01);
    end
`SVTEST_END

`SVTEST(tc_pinc_n_field_matches_pinc_times_ndds)
    // pinc_N = (PINC * N_DDS) mod 2^32 -- independent of the free-running
    // cnt_n counter, so it is exactly predictable once the write has
    // propagated through mult0_i's 6-cycle pipeline.
    logic [63:0] expected;
    write_regs(32'h0000_1000, 32'h0000_0000);
    expected = 64'h0000_1000 * N_DDS;
    for (int i = 0; i < N_DDS; i++) begin
        `FAIL_UNLESS(lane_pinc_n(i) === expected[31:0]);
    end
`SVTEST_END

`SVTEST(tc_lane_phase_offset_is_pinc_coherent)
    // Phase-coherence invariant: at any given output cycle, lane i's phase
    // field equals lane 0's phase field plus i*PINC (mod 2^32) -- the
    // pinc_Nm/POFF terms are common to every lane and cancel in the
    // difference, so this holds regardless of the free-running cnt_n phase.
    logic [31:0] phase0, phase1, diff;
    write_regs(32'h0000_1000, 32'h0000_0000);
    phase0 = lane_phase(0);
    phase1 = lane_phase(1);
    diff   = phase1 - phase0;
    `FAIL_UNLESS(diff === 32'h0000_1000);
`SVTEST_END

`SVTEST(tc_poff_shifts_phase_uniformly)
    // Changing POFF (with PINC=0) shifts every lane's phase by the same
    // amount, since it is added after the per-lane offset.
    logic [31:0] phase0_before;
    logic [31:0] phase0_after;
    write_regs(32'h0000_0000, 32'h0000_0000);
    phase0_before = lane_phase(0);
    write_regs(32'h0000_0000, 32'h0000_0100);
    phase0_after = lane_phase(0);
    `FAIL_UNLESS((phase0_after - phase0_before) === 32'h0000_0100);
`SVTEST_END
