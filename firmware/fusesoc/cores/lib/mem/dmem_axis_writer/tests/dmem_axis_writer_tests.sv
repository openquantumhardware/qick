// ============================================================================
// File: dmem_axis_writer_tests.sv
// Description: SVUnit test cases for dmem_axis_writer.
// Included by dmem_axis_writer_tc00.sv.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Reset — FSM in INIT, tready low, no BRAM writes
// ----------------------------------------------------------------------------
`SVTEST(test_reset_idle)
    repeat(5) @(tb_cb);
    `FAIL_IF(u_dut.state !== INIT_ST);
    `FAIL_IF(axis_if.tready);
    `FAIL_IF(bram_if_i.we);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: No exec — tready stays low, FSM stays in INIT
// ----------------------------------------------------------------------------
`SVTEST(test_idle_no_exec)
    repeat(10) @(tb_cb);
    `FAIL_IF(u_dut.state !== INIT_ST);
    `FAIL_IF(axis_if.tready);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: tready asserted only during WRITE_ST
// ----------------------------------------------------------------------------
`SVTEST(test_tready_only_in_write)
    `FAIL_IF(axis_if.tready);          // idle
    start_write(N'(0));
    wait_state(WRITE_ST);
    @(tb_cb);
    `FAIL_IF(!axis_if.tready);          // asserted in WRITE
    // Send a single-beat burst to finish
    stream_burst(1, B'(16'h1111));
    wait_state(END_ST);
    @(tb_cb);
    `FAIL_IF(axis_if.tready);           // deasserted after WRITE
    finish_write();
    wait_state(INIT_ST);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: Single-beat write — one word written to BRAM at addr
// ----------------------------------------------------------------------------
`SVTEST(test_single_beat_write)
    start_write(N'(10'h010));
    wait_state(WRITE_ST);
    stream_burst(1, B'(16'hABCD));
    wait_state(END_ST);
    finish_write();
    wait_state(INIT_ST);
    verify_mem(10'h010, 1, B'(16'hABCD), "test_single_beat_write");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: Multi-beat write — sequential words written from addr
// ----------------------------------------------------------------------------
`SVTEST(test_multi_beat_write)
    localparam int LEN = 8;
    start_write(N'(0));
    wait_state(WRITE_ST);
    stream_burst(LEN, B'(16'h2000));
    wait_state(END_ST);
    finish_write();
    wait_state(INIT_ST);
    verify_mem(0, LEN, B'(16'h2000), "test_multi_beat_write");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: Write at non-zero start address
// ----------------------------------------------------------------------------
`SVTEST(test_write_offset_address)
    localparam int LEN  = 4;
    localparam int ADDR = 10'h080;
    start_write(N'(ADDR));
    wait_state(WRITE_ST);
    stream_burst(LEN, B'(16'h5500));
    wait_state(END_ST);
    finish_write();
    wait_state(INIT_ST);
    verify_mem(ADDR, LEN, B'(16'h5500), "test_write_offset_address");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: Gapped stream — idle cycles between beats (tvalid toggling)
// ----------------------------------------------------------------------------
`SVTEST(test_gapped_stream)
    localparam int LEN = 6;
    start_write(N'(10'h020));
    wait_state(WRITE_ST);
    stream_burst_gapped(LEN, B'(16'h3000), 2);  // 2 idle cycles per beat
    wait_state(END_ST);
    finish_write();
    wait_state(INIT_ST);
    verify_mem(10'h020, LEN, B'(16'h3000), "test_gapped_stream");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: tlast terminates the burst — FSM moves to ACK then END,
//          and exec_ack_o pulses high (captured concurrently to avoid the
//          single-cycle ACK_ST sampling race).
// ----------------------------------------------------------------------------
`SVTEST(test_tlast_terminates)
    localparam int LEN = 3;
    logic ack_seen = 1'b0;
    start_write(N'(0));
    wait_state(WRITE_ST);
    fork
        // Monitor: latch any assertion of exec_ack_o
        begin
            while (u_dut.state !== END_ST) begin
                @(tb_cb);
                if (tb_exec_ack_o) ack_seen = 1'b1;
            end
        end
        // Stimulus: send the burst (tlast on last beat)
        stream_burst(LEN, B'(16'h4000));
    join
    wait_state(END_ST);
    `FAIL_IF(!ack_seen);               // exec_ack_o pulsed during ACK_ST
    finish_write();
    wait_state(INIT_ST);
    verify_mem(0, LEN, B'(16'h4000), "test_tlast_terminates");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 09: exec_ack handshake — END holds until exec deasserted
// ----------------------------------------------------------------------------
`SVTEST(test_exec_ack_handshake)
    localparam int LEN = 2;
    start_write(N'(0));
    wait_state(WRITE_ST);
    stream_burst(LEN, B'(16'h6000));
    wait_state(END_ST);
    // exec still high -> stays in END_ST
    repeat(5) @(tb_cb) `FAIL_IF(u_dut.state !== END_ST);
    finish_write();
    wait_state(INIT_ST);
    `FAIL_IF(u_dut.state !== INIT_ST);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 10: Back-to-back writes — second burst after first completes
// ----------------------------------------------------------------------------
`SVTEST(test_back_to_back_writes)
    localparam int LEN = 4;
    // First burst
    start_write(N'(0));
    wait_state(WRITE_ST);
    stream_burst(LEN, B'(16'h7000));
    wait_state(END_ST);
    finish_write();
    wait_state(INIT_ST);
    verify_mem(0, LEN, B'(16'h7000), "test_back_to_back_writes (1st)");
    // Second burst at different address
    start_write(N'(10'h100));
    wait_state(WRITE_ST);
    stream_burst(LEN, B'(16'h8000));
    wait_state(END_ST);
    finish_write();
    wait_state(INIT_ST);
    verify_mem(10'h100, LEN, B'(16'h8000), "test_back_to_back_writes (2nd)");
`SVTEST_END