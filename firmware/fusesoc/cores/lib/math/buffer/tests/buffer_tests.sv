// ============================================================================
// File: buffer_tests.sv
// Description: Full test suite for the buffer module.
// Included inside SVUNIT_TESTS_BEGIN/END — no task/function declarations here.
// Helper tasks are defined in buffer_tc00.sv (module scope).
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 00: Basic capture — 4 samples written verbatim to consecutive addresses
// ----------------------------------------------------------------------------
`SVTEST(test_capture_basic)
    int timed_out;
    logic [2*B-1:0] samples [4];
    logic [2*B-1:0] captured [4];
    int k;

    samples[0] = {16'h0001, 16'h0064}; // Q=1,   I=100
    samples[1] = {16'h0002, 16'hFFCE}; // Q=2,   I=-50
    samples[2] = {16'hFFFF, 16'h0000}; // Q=-1,  I=0
    samples[3] = {16'h1234, 16'h5678};

    arm_and_trigger(10'd5, 10'd4);

    cb.tb_din_valid_i <= 1'b1;
    for (k = 0; k < 4; k++) begin
        cb.tb_din_i <= samples[k];
        @(cb);
        captured[k] = cb.tb_mem_di_o;
        `FAIL_UNLESS_EQUAL(cb.tb_mem_we_o, 1'b1);
        `FAIL_UNLESS_EQUAL(cb.tb_mem_addr_o, 10'd5 + k);
    end
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    for (k = 0; k < 4; k++)
        `FAIL_UNLESS_EQUAL(captured[k], samples[k]);

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 01: Single-sample capture (len_reg=1)
// ----------------------------------------------------------------------------
`SVTEST(test_capture_single_sample)
    int timed_out;
    arm_and_trigger(10'd1, 10'd1);

    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i       <= {16'hFF9C, 16'h01F4};
    @(cb);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_we_o, 1'b1);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_addr_o, 10'd1);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o, {16'hFF9C, 16'h01F4});
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Capture with din_valid_i bubbles — address only advances on
// valid samples, not idle cycles.
// ----------------------------------------------------------------------------
`SVTEST(test_capture_with_bubbles)
    int timed_out;
    int k;
    arm_and_trigger(10'd0, 10'd3);

    for (k = 0; k < 3; k++) begin
        cb.tb_din_valid_i <= 1'b1;
        cb.tb_din_i       <= 32'(k + 1);
        @(cb);
        `FAIL_UNLESS_EQUAL(cb.tb_mem_we_o, 1'b1);
        `FAIL_UNLESS_EQUAL(cb.tb_mem_addr_o, 10'(k));
        cb.tb_din_valid_i <= 1'b0;
        cb.tb_din_i       <= '0;
        @(cb); // bubble: no write strobe expected
        `FAIL_UNLESS_EQUAL(cb.tb_mem_we_o, 1'b0);
    end

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Two consecutive captures — second capture's addresses/data must
// not be contaminated by the first.
// ----------------------------------------------------------------------------
`SVTEST(test_capture_consecutive_captures)
    int timed_out;

    // --- First capture ---
    arm_and_trigger(10'd0, 10'd2);
    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i <= 32'd10; @(cb);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_addr_o, 10'd0);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o,   32'd10);
    cb.tb_din_i <= 32'd11; @(cb);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_addr_o, 10'd1);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o,   32'd11);
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    // addr_reg/len_reg are only re-latched in START_ST, so a genuine
    // address change between captures needs a full release_fsm() +
    // arm_and_trigger() cycle (not just re-pulsing trigger_i, which would
    // skip START_ST since start_reg never dropped).
    release_fsm();
    arm_and_trigger(10'd100, 10'd2);

    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i <= 32'd20; @(cb);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_addr_o, 10'd100);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o,   32'd20);
    cb.tb_din_i <= 32'd21; @(cb);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_addr_o, 10'd101);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o,   32'd21);
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: FSM abort — start_reg drops in TRIGGER_ST
// mem_we_o must never assert; FSM must recover and complete a normal capture.
// ----------------------------------------------------------------------------
`SVTEST(test_abort_in_trigger_st)
    int timed_out;

    cb.tb_addr_reg  <= 10'd0;
    cb.tb_len_reg   <= 10'd4;
    cb.tb_start_reg <= 1'b1;
    @(cb); // FSM: START_ST -> TRIGGER_ST

    cb.tb_start_reg <= 1'b0;

    repeat(10) begin
        @(cb);
        if (cb.tb_mem_we_o) begin
            $display("[FAIL] mem_we_o asserted after start_reg abort in TRIGGER_ST");
            `FAIL_IF(1);
        end
    end

    // FSM should be back in START_ST — confirm normal capture works
    arm_and_trigger(10'd0, 10'd1);
    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i       <= 32'd1;
    @(cb);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_we_o, 1'b1);
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: Trigger ignored before start_reg asserts
// mem_we_o must never assert; FSM must still work normally after.
// ----------------------------------------------------------------------------
`SVTEST(test_trigger_before_start_reg)
    int timed_out;

    cb.tb_trigger_i <= 1'b1;
    repeat(3) @(cb);
    cb.tb_trigger_i <= 1'b0;

    repeat(5) begin
        @(cb);
        if (cb.tb_mem_we_o) begin
            $display("[FAIL] mem_we_o asserted when trigger came before start_reg");
            `FAIL_IF(1);
        end
    end

    arm_and_trigger(10'd0, 10'd1);
    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i       <= 32'd7;
    @(cb);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o, 32'd7);
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    release_fsm();
`SVTEST_END
