// ============================================================================
// File: lfsr_tests.sv
// Description: SVUnit test cases for the generic lfsr.
// Included by lfsr_tc00.sv.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Reset clears the register to 0.
// ----------------------------------------------------------------------------
`SVTEST(tc_reset_zero)
    `FAIL_IF(tb_lfsr_dt !== '0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Load seeds the register; value is reflected on the output.
// ----------------------------------------------------------------------------
`SVTEST(tc_load_seed)
    do_load(32'hACE1_1234);
    `FAIL_IF(tb_lfsr_dt !== 32'hACE1_1234);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Hold — with en=0 and load=0 the register keeps its value.
// ----------------------------------------------------------------------------
`SVTEST(tc_hold_value)
    do_load(32'hDEAD_BEEF);
    tb_cb.tb_en <= 1'b0;
    repeat(5) @(tb_cb);
    `FAIL_IF(tb_lfsr_dt !== 32'hDEAD_BEEF);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: Load has priority over enable.
// ----------------------------------------------------------------------------
`SVTEST(tc_load_priority)
    @(tb_cb);
    tb_cb.tb_en      <= 1'b1;     // enable asserted
    tb_cb.tb_load_we <= 1'b1;     // load also asserted -> load wins
    tb_cb.tb_load_dt <= 32'h1234_5678;
    @(tb_cb);
    tb_cb.tb_load_we <= 1'b0;
    tb_cb.tb_en      <= 1'b0;
    @(tb_cb);
    `FAIL_IF(tb_lfsr_dt !== 32'h1234_5678);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: Sequence from reset (seed 0) matches the reference model.
//   XNOR feedback self-starts from 0; verify N steps step-by-step.
// ----------------------------------------------------------------------------
`SVTEST(tc_sequence_from_zero)
    logic [DW-1:0] model;
    model = '0;                         // matches reset state
    // Run N enabled steps, comparing each step to the reference model.
    tb_cb.tb_en <= 1'b1;
    for (int i = 0; i < 64; i++) begin
        model = lfsr_step(model);       // expected next state
        @(tb_cb);                       // DUT advances one step
        if (tb_lfsr_dt !== model) begin
            $display("SEQ MISMATCH step %0d: exp 0x%08h got 0x%08h",
                     i, model, tb_lfsr_dt);
            `FAIL_IF(1);
        end
    end
    tb_cb.tb_en <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: Sequence from a loaded seed matches the reference model.
// ----------------------------------------------------------------------------
`SVTEST(tc_sequence_from_seed)
    logic [DW-1:0] model;
    do_load(32'hA5A5_5A5A);
    model = 32'hA5A5_5A5A;
    tb_cb.tb_en <= 1'b1;
    for (int i = 0; i < 64; i++) begin
        model = lfsr_step(model);
        @(tb_cb);
        if (tb_lfsr_dt !== model) begin
            $display("SEQ MISMATCH step %0d: exp 0x%08h got 0x%08h",
                     i, model, tb_lfsr_dt);
            `FAIL_IF(1);
        end
    end
    tb_cb.tb_en <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: Enable gating — paused steps don't advance the sequence.
// ----------------------------------------------------------------------------
`SVTEST(tc_enable_gating)
    logic [DW-1:0] model, snapshot;
    do_load(32'h0000_0001);
    model = 32'h0000_0001;
    // one enabled step
    tb_cb.tb_en <= 1'b1;
    model = lfsr_step(model);
    @(tb_cb);
    `FAIL_IF(tb_lfsr_dt !== model);
    // pause: hold for several cycles, value must not change
    tb_cb.tb_en <= 1'b0;
    snapshot = model;
    repeat(4) @(tb_cb);
    `FAIL_IF(tb_lfsr_dt !== snapshot);
    // resume: one more enabled step
    tb_cb.tb_en <= 1'b1;
    model = lfsr_step(model);
    @(tb_cb);
    `FAIL_IF(tb_lfsr_dt !== model);
    tb_cb.tb_en <= 1'b0;
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: Re-load mid-sequence resets the state cleanly.
// ----------------------------------------------------------------------------
`SVTEST(tc_reload_midsequence)
    logic [DW-1:0] model;
    // run a few steps
    tb_cb.tb_en <= 1'b1;
    repeat(10) @(tb_cb);
    tb_cb.tb_en <= 1'b0;
    @(tb_cb);
    // reload a new seed
    do_load(32'hCAFE_0000);
    model = 32'hCAFE_0000;
    // continue and verify against model
    tb_cb.tb_en <= 1'b1;
    for (int i = 0; i < 16; i++) begin
        model = lfsr_step(model);
        @(tb_cb);
        if (tb_lfsr_dt !== model) begin
            $display("RELOAD SEQ MISMATCH step %0d: exp 0x%08h got 0x%08h",
                     i, model, tb_lfsr_dt);
            `FAIL_IF(1);
        end
    end
    tb_cb.tb_en <= 1'b0;
`SVTEST_END
