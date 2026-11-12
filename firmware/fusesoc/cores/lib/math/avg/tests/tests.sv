// ============================================================================
// File: tests.sv
// Description: Full test suite for the avg module.
// Included inside SVUNIT_TESTS_BEGIN/END — no task/function declarations here.
// Helper tasks are defined in avg_tc00.sv (module scope).
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 00: Basic accumulation — 4 samples, I=100, Q=-50
// Expected: mem_di_o[31:0]=400 (0x190), mem_di_o[63:32]=-200 (0xFFFFFF38)
// ----------------------------------------------------------------------------
`SVTEST(test_accumulation_basic)
    int timed_out;
    arm_and_trigger(10'd5, 32'd4, 1'b0, 16'd0, 16'd0);

    cb.tb_din_valid_i <= 1'b1;
    repeat(4) begin
        cb.tb_din_i <= {16'hFFCE, 16'h0064}; // Q=-50, I=100
        @(cb);
    end
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_accumulation_basic: FSM never reached WRITE_MEM_ST");
        `FAIL_IF(1);
    end

    `FAIL_UNLESS_EQUAL(cb.tb_mem_addr_o,      10'd5);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[31:0],  32'h0000_0190);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[63:32], 32'hFFFF_FF38);

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 01: Accumulation — single sample (len_reg=1)
// Expected: result equals the sample itself, sign-extended to 32b.
// ----------------------------------------------------------------------------
`SVTEST(test_accumulation_single_sample)
    int timed_out;
    arm_and_trigger(10'd1, 32'd1, 1'b0, 16'd0, 16'd0);

    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i       <= {16'hFF9C, 16'h01F4}; // Q=-100, I=500
    @(cb);
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_accumulation_single_sample");
        `FAIL_IF(1);
    end

    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[31:0],  32'h0000_01F4); // I=500
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[63:32], 32'hFFFF_FF9C); // Q=-100

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Accumulation — din_valid_i with bubbles
// 4 samples with one idle cycle between each.
// FSM must count only valid cycles; result must match TEST 00.
// ----------------------------------------------------------------------------
`SVTEST(test_accumulation_with_bubbles)
    int timed_out;
    arm_and_trigger(10'd2, 32'd4, 1'b0, 16'd0, 16'd0);

    repeat(4) begin
        cb.tb_din_valid_i <= 1'b1;
        cb.tb_din_i       <= {16'hFFCE, 16'h0064}; // Q=-50, I=100
        @(cb);
        cb.tb_din_valid_i <= 1'b0;
        cb.tb_din_i       <= '0;
        @(cb); // bubble
    end

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_accumulation_with_bubbles");
        `FAIL_IF(1);
    end

    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[31:0],  32'h0000_0190); // 100*4=400
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[63:32], 32'hFFFF_FF38); // -50*4=-200

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Accumulation — all-negative values
// 3 samples: I=-1 (0xFFFF), Q=-1 (0xFFFF)
// Expected: I_acc=-3 (0xFFFFFFFD), Q_acc=-3 (0xFFFFFFFD)
// ----------------------------------------------------------------------------
`SVTEST(test_accumulation_negative_values)
    int timed_out;
    arm_and_trigger(10'd0, 32'd3, 1'b0, 16'd0, 16'd0);

    cb.tb_din_valid_i <= 1'b1;
    repeat(3) begin
        cb.tb_din_i <= {16'hFFFF, 16'hFFFF}; // Q=-1, I=-1
        @(cb);
    end
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_accumulation_negative_values");
        `FAIL_IF(1);
    end

    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[31:0],  32'hFFFF_FFFD); // -3
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[63:32], 32'hFFFF_FFFD); // -3

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: Accumulation — large positive values
// 8 samples of I=0x7FFF (32767). Expected I_acc = 262136 = 0x0003FFF8
// Verifies the 32-bit accumulator does not overflow for reasonable counts.
// ----------------------------------------------------------------------------
`SVTEST(test_accumulation_large_values)
    int timed_out;
    arm_and_trigger(10'd0, 32'd8, 1'b0, 16'd0, 16'd0);

    cb.tb_din_valid_i <= 1'b1;
    repeat(8) begin
        cb.tb_din_i <= {16'h0000, 16'h7FFF}; // Q=0, I=32767
        @(cb);
    end
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_accumulation_large_values");
        `FAIL_IF(1);
    end

    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[31:0],  32'h0003_FFF8); // 32767*8=262136
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[63:32], 32'h0000_0000);

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: Accumulation — mem_addr_o reflects addr_reg exactly
// ----------------------------------------------------------------------------
`SVTEST(test_accumulation_address)
    int timed_out;
    arm_and_trigger(10'd1023, 32'd1, 1'b0, 16'd0, 16'd0);

    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i       <= {16'h0001, 16'h0001};
    @(cb);
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_accumulation_address");
        `FAIL_IF(1);
    end

    `FAIL_UNLESS_EQUAL(cb.tb_mem_addr_o, 10'd1023);

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: Two consecutive captures — accumulators must reset between runs
// First: 2x I=10 → acc=20. Second: 2x I=20 → acc=40 (not 60).
// ----------------------------------------------------------------------------
`SVTEST(test_accumulation_consecutive_captures)
    int timed_out;

    // --- First capture ---
    arm_and_trigger(10'd0, 32'd2, 1'b0, 16'd0, 16'd0);
    cb.tb_din_valid_i <= 1'b1;
    repeat(2) begin
        cb.tb_din_i <= {16'h0000, 16'h000A}; // I=10
        @(cb);
    end
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_consecutive_captures (first)");
        `FAIL_IF(1);
    end
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[31:0], 32'd20);

    // trigger_i is already 0, start_reg=1 → FSM exits WAIT_TRIGGER_ST
    // and returns to TRIGGER_ST automatically after one cycle.
    @(cb);

    // --- Second capture ---
    cb.tb_addr_reg <= 10'd1;
    cb.tb_len_reg  <= 32'd2;
    @(cb);
    cb.tb_trigger_i <= 1'b1;
    @(cb);
    cb.tb_trigger_i <= 1'b0;

    cb.tb_din_valid_i <= 1'b1;
    repeat(2) begin
        cb.tb_din_i <= {16'h0000, 16'h0014}; // I=20
        @(cb);
    end
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_consecutive_captures (second)");
        `FAIL_IF(1);
    end
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[31:0], 32'd40); // must be 40, NOT 60

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: FSM abort — start_reg drops in TRIGGER_ST
// mem_we_o must never assert; FSM must recover and complete a normal capture.
// ----------------------------------------------------------------------------
`SVTEST(test_abort_in_trigger_st)
    int timed_out;

    // Reach TRIGGER_ST without pulsing trigger
    cb.tb_addr_reg        <= 10'd0;
    cb.tb_len_reg         <= 32'd4;
    cb.tb_photon_mode_reg <= 1'b0;
    cb.tb_start_reg       <= 1'b1;
    @(cb); // FSM: START_ST -> TRIGGER_ST

    // Abort: drop start_reg without ever asserting trigger_i
    cb.tb_start_reg <= 1'b0;

    // Verify no write strobe over next 10 cycles
    repeat(10) begin
        @(cb);
        if (cb.tb_mem_we_o) begin
            $display("[FAIL] mem_we_o asserted after start_reg abort in TRIGGER_ST");
            `FAIL_IF(1);
        end
    end

    // FSM should be back in START_ST — confirm normal capture works
    arm_and_trigger(10'd0, 32'd1, 1'b0, 16'd0, 16'd0);
    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i       <= {16'h0000, 16'h0001};
    @(cb);
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_abort_in_trigger_st: FSM did not recover");
        `FAIL_IF(1);
    end

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: FSM abort — start_reg drops in WAIT_TRIGGER_ST
// FSM must return to START_ST and accept a new capture.
// ----------------------------------------------------------------------------
`SVTEST(test_abort_in_wait_trigger_st)
    int timed_out;
    arm_and_trigger(10'd0, 32'd1, 1'b0, 16'd0, 16'd0);

    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i       <= {16'h0000, 16'h0001};
    @(cb);
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_abort_in_wait_trigger_st: first capture");
        `FAIL_IF(1);
    end

    // Drop start_reg while in WAIT_TRIGGER_ST
    cb.tb_start_reg <= 1'b0;
    repeat(3) @(cb);

    // Confirm FSM recovers with a second capture
    arm_and_trigger(10'd5, 32'd1, 1'b0, 16'd0, 16'd0);
    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i       <= {16'h0000, 16'h0002};
    @(cb);
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_abort_in_wait_trigger_st: FSM did not recover");
        `FAIL_IF(1);
    end
    `FAIL_UNLESS_EQUAL(cb.tb_mem_addr_o,     10'd5);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[31:0], 32'd2);

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 09: Trigger ignored before start_reg asserts
// mem_we_o must never assert; FSM must still work normally after.
// ----------------------------------------------------------------------------
`SVTEST(test_trigger_before_start_reg)
    int timed_out;

    // Fire trigger while FSM is in START_ST (start_reg=0)
    cb.tb_trigger_i <= 1'b1;
    repeat(3) @(cb);
    cb.tb_trigger_i <= 1'b0;

    // Verify no spurious write
    repeat(5) begin
        @(cb);
        if (cb.tb_mem_we_o) begin
            $display("[FAIL] mem_we_o asserted when trigger came before start_reg");
            `FAIL_IF(1);
        end
    end

    // Confirm FSM still works
    arm_and_trigger(10'd0, 32'd1, 1'b0, 16'd0, 16'd0);
    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i       <= {16'h0000, 16'h0007};
    @(cb);
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_trigger_before_start_reg: FSM did not recover");
        `FAIL_IF(1);
    end
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[31:0], 32'd7);

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 10: Photon mode — basic edge counter (2 edges)
// Signal: 0, 60, 55, 5, 70, 70 — H=50, L=10 → 2 edges
// ----------------------------------------------------------------------------
`SVTEST(test_photon_edge_counter)
    int timed_out;
    arm_and_trigger(10'd0, 32'd6, 1'b1, 16'd50, 16'd10);

    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i <= {16'd0, 16'd0};  @(cb); // below L, high_state stays 0
    cb.tb_din_i <= {16'd0, 16'd60}; @(cb); // above H → high_state=1
    cb.tb_din_i <= {16'd0, 16'd55}; @(cb); // still high, edge counted this cycle
    cb.tb_din_i <= {16'd0, 16'd5};  @(cb); // below L → high_state=0
    cb.tb_din_i <= {16'd0, 16'd70}; @(cb); // above H → high_state=1
    cb.tb_din_i <= {16'd0, 16'd70}; @(cb); // still high, 2nd edge counted
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_photon_edge_counter");
        `FAIL_IF(1);
    end
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o, 64'd2);

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 11: Photon mode — signal never crosses H threshold → count = 0
// ----------------------------------------------------------------------------
`SVTEST(test_photon_no_edges)
    int timed_out;
    arm_and_trigger(10'd0, 32'd4, 1'b1, 16'd50, 16'd10);

    cb.tb_din_valid_i <= 1'b1;
    repeat(4) begin
        cb.tb_din_i <= {16'd0, 16'd30}; // below H=50
        @(cb);
    end
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_photon_no_edges");
        `FAIL_IF(1);
    end
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o, 64'd0);

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 12: Photon mode — signal exactly equal to H_THRSH
// RTL uses strict '>' so equal value must NOT count as an edge.
// ----------------------------------------------------------------------------
`SVTEST(test_photon_equal_to_threshold)
    int timed_out;
    arm_and_trigger(10'd0, 32'd4, 1'b1, 16'd50, 16'd10);

    cb.tb_din_valid_i <= 1'b1;
    repeat(4) begin
        cb.tb_din_i <= {16'd0, 16'd50}; // exactly H_THRSH, not strictly greater
        @(cb);
    end
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_photon_equal_to_threshold");
        `FAIL_IF(1);
    end
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o, 64'd0);

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 13: Photon mode — first sample already above H_THRSH
// The signal may have been high before the window opened, so a crossing on
// the first sample is not an edge (legacy edge-counting fix, ecf27cdc).
// Signal: 70, 70, 5, 70, 70 (5 samples) → 1 edge (the one at sample 3)
// ----------------------------------------------------------------------------
`SVTEST(test_photon_starts_above_threshold)
    int timed_out;
    arm_and_trigger(10'd0, 32'd5, 1'b1, 16'd50, 16'd10);

    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i <= {16'd0, 16'd70}; @(cb); // above H on sample 0: not counted
    cb.tb_din_i <= {16'd0, 16'd70}; @(cb);
    cb.tb_din_i <= {16'd0, 16'd5};  @(cb); // below L → high_state=0
    cb.tb_din_i <= {16'd0, 16'd70}; @(cb); // above H → edge
    cb.tb_din_i <= {16'd0, 16'd70}; @(cb);
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_photon_starts_above_threshold");
        `FAIL_IF(1);
    end
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o, 64'd1);

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 13b: Photon mode — edge on the last sample of the window
// Only QOUT_ST can count it (legacy edge-counting fix, ecf27cdc).
// Signal: 0, 0, 0, 70 (4 samples) → 1 edge
// ----------------------------------------------------------------------------
`SVTEST(test_photon_edge_on_last_sample)
    int timed_out;
    arm_and_trigger(10'd0, 32'd4, 1'b1, 16'd50, 16'd10);

    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i <= {16'd0, 16'd0};  @(cb);
    cb.tb_din_i <= {16'd0, 16'd0};  @(cb);
    cb.tb_din_i <= {16'd0, 16'd0};  @(cb);
    cb.tb_din_i <= {16'd0, 16'd70}; @(cb); // above H on the last sample
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_photon_edge_on_last_sample");
        `FAIL_IF(1);
    end
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o, 64'd1);

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 14: Photon mode — with din_valid_i bubbles
// Same stimulus as TEST 10 but one idle cycle between each sample.
// Edge count must be identical.
// ----------------------------------------------------------------------------
`SVTEST(test_photon_with_bubbles)
    int timed_out;
    logic [15:0] samples [0:5];
    samples[0] = 16'd0;
    samples[1] = 16'd60;
    samples[2] = 16'd55;
    samples[3] = 16'd5;
    samples[4] = 16'd70;
    samples[5] = 16'd70;

    arm_and_trigger(10'd0, 32'd6, 1'b1, 16'd50, 16'd10);

    for (int s = 0; s < 6; s++) begin
        cb.tb_din_valid_i <= 1'b1;
        cb.tb_din_i       <= {16'd0, samples[s]};
        @(cb);

        if (s < 5) begin
            cb.tb_din_valid_i <= 1'b0;
            cb.tb_din_i       <= '0;  // Don't hold data - set to 0
            @(cb); // bubble
        end
    end

    // Clean de-assertion
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;
    @(cb);

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_photon_with_bubbles");
        `FAIL_IF(1);
    end

    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o, 64'd2);

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 15: Mode switch between captures
// Capture 1: accumulation mode → I_acc=20
// Capture 2: photon mode, 0, 60, 5, 70 → 2 edges (the one on the last
//            sample is counted in QOUT_ST)
// Verifies photon_mode_reg is re-latched correctly on each new START_ST.
// ----------------------------------------------------------------------------
`SVTEST(test_mode_switch_between_captures)
    int timed_out;

    // --- Capture 1: accumulation ---
    arm_and_trigger(10'd0, 32'd2, 1'b0, 16'd0, 16'd0);
    cb.tb_din_valid_i <= 1'b1;
    repeat(2) begin
        cb.tb_din_i <= {16'h0000, 16'h000A}; // I=10
        @(cb);
    end
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_mode_switch: first capture");
        `FAIL_IF(1);
    end
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[31:0], 32'd20);

    release_fsm();
    repeat(2) @(cb);

    // --- Capture 2: photon mode ---
    arm_and_trigger(10'd1, 32'd4, 1'b1, 16'd50, 16'd10);
    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i <= {16'd0, 16'd0};  @(cb);
    cb.tb_din_i <= {16'd0, 16'd60}; @(cb);
    cb.tb_din_i <= {16'd0, 16'd5};  @(cb);
    cb.tb_din_i <= {16'd0, 16'd70}; @(cb);
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_mode_switch: second capture");
        `FAIL_IF(1);
    end
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o, 64'd2);

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 17: the window starts at the sample after the trigger cycle and holds
// len samples (input stage of avg 1.0.1: trigger_i is delayed with the data)
// A valid sample 1000 sits in the trigger cycle and 7000 right after the
// window: neither is accumulated. mem_we_o is a one-clock strobe.
// ----------------------------------------------------------------------------
`SVTEST(test_window_alignment_and_single_clock_write)
    int timed_out;

    cb.tb_addr_reg        <= 10'd3;
    cb.tb_len_reg         <= 32'd4;
    cb.tb_photon_mode_reg <= 1'b0;
    cb.tb_start_reg       <= 1'b1;
    @(cb);
    cb.tb_trigger_i   <= 1'b1;
    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i       <= {16'd0, 16'd1000};
    @(cb);
    cb.tb_trigger_i <= 1'b0;
    for (int k = 1; k <= 4; k++) begin
        cb.tb_din_i <= {-16'(k), 16'(k)};   // I = k, Q = -k
        @(cb);
    end
    cb.tb_din_i <= {16'd0, 16'd7000};
    @(cb);
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    if (timed_out) begin
        $display("[TIMEOUT] test_window_alignment: no write");
        `FAIL_IF(1);
    end
    `FAIL_UNLESS_EQUAL(cb.tb_mem_addr_o,      10'd3);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[31:0],  32'd10);
    `FAIL_UNLESS_EQUAL(cb.tb_mem_di_o[63:32], 32'hFFFF_FFF6);  // -10

    repeat(6) begin
        @(cb);
        `FAIL_UNLESS_EQUAL(cb.tb_mem_we_o, 1'b0);
    end

    release_fsm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 18: start_reg drops in the cycle of WRITE_MEM_ST: the registered write
// strobe is still qualified with start_reg, so nothing is written.
// ----------------------------------------------------------------------------
`SVTEST(test_no_write_when_start_reg_drops_in_write_mem_st)
    int guard;

    arm_and_trigger(10'd9, 32'd2, 1'b0, 16'd0, 16'd0);
    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i       <= {16'd0, 16'd5};
    repeat(2) @(cb);
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    // qout_state is seen at the edge that leaves QOUT_ST: start_reg driven
    // now is low in WRITE_MEM_ST.
    guard = 0;
    while (!u_avg.qout_state && guard < 30) begin
        @(cb);
        guard++;
    end
    `FAIL_IF(guard >= 30);
    cb.tb_start_reg <= 1'b0;

    repeat(10) begin
        @(cb);
        `FAIL_UNLESS_EQUAL(cb.tb_mem_we_o, 1'b0);
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 19: a trigger held high through the capture re-arms only after it falls
// and the samples that follow without a new trigger are not captured (the
// delayed copy of the trigger is already low when the FSM is back in
// TRIGGER_ST, so WAIT_TRIGGER_ST leaving on trigger_i or on trigger_r is the
// same behaviour).
// ----------------------------------------------------------------------------
`SVTEST(test_held_trigger_does_not_retrigger_when_it_falls)
    int timed_out;

    cb.tb_addr_reg        <= 10'd4;
    cb.tb_len_reg         <= 32'd2;
    cb.tb_photon_mode_reg <= 1'b0;
    cb.tb_start_reg       <= 1'b1;
    @(cb);
    cb.tb_trigger_i <= 1'b1;
    @(cb);
    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i       <= {16'd0, 16'd5};
    repeat(2) @(cb);
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;

    wait_for_write(timed_out);
    `FAIL_IF(timed_out);
    repeat(5) @(cb);
    cb.tb_trigger_i <= 1'b0;

    // samples without a new trigger: nothing may be written
    cb.tb_din_valid_i <= 1'b1;
    cb.tb_din_i       <= {16'd0, 16'd9};
    repeat(6) @(cb);
    cb.tb_din_valid_i <= 1'b0;
    cb.tb_din_i       <= '0;
    repeat(20) begin
        @(cb);
        `FAIL_UNLESS_EQUAL(cb.tb_mem_we_o, 1'b0);
    end

    release_fsm();
`SVTEST_END
