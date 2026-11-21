// ============================================================================
// File: streamer_tests.sv
// Project: QICK
// Description: SVUnit test cases for streamer.
//
// Pattern for every streaming test:
//   set_params -> set_tready -> start_block -> send data -> consume ->
//   stop_block -> wait_idle -> sb_check + check_last_positions
//
// start_block MUST come before any traffic: s_axis_tready is ~fifo_full and is
// not gated by the run state, so beats offered before the block is running are
// accepted on the bus and thrown away.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 00: idle - nothing is emitted while the block is disabled
// ----------------------------------------------------------------------------
`SVTEST(tc00_idle)
    set_tready(1'b1);
    expect_quiet(50, "tc00");
    `FAIL_IF_LOG(dbg_state !== ST_IDLE,
                 $sformatf("tc00: expected IDLE, state=0x%0h", dbg_state))
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 01: one-shot, NSAMP = 4
// ----------------------------------------------------------------------------
`SVTEST(tc01_oneshot_4)
    logic [W_IN-1:0]  tx[];
    logic [B_AXIS-1:0] d;
    logic              last;
    bit                ok;
    int                exp_last[];

    set_params(4, 1'b0);
    set_tready(1'b1);
    make_packet(4, 8'h5A, tx);

    start_block();
    fork
        send_words(tx);
    join_none

    for (int i = 0; i < 4; i++) begin
        recv_beat(d, last, ok);
        `FAIL_UNLESS_LOG(ok, $sformatf("tc01: timeout on beat %0d", i))
        `FAIL_IF_LOG(d[B_TDATA-1:0] !== i[B_TDATA-1:0],
                     $sformatf("tc01: beat %0d payload 0x%0h", i, d))
        `FAIL_IF_LOG(last !== (i == 3),
                     $sformatf("tc01: beat %0d tlast=%0b", i, last))
    end

    expect_quiet(20, "tc01");
    stop_block();
    wait_idle(ok);
    `FAIL_UNLESS_LOG(ok, "tc01: block never returned to IDLE")

    exp_last = '{3};
    sb_check("tc01");
    check_last_positions("tc01", exp_last);
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 02: one-shot, NSAMP = 1 (degenerate packet, tlast on the first beat)
// ----------------------------------------------------------------------------
`SVTEST(tc02_oneshot_1)
    logic [W_IN-1:0]  tx[];
    logic [B_AXIS-1:0] d;
    logic              last;
    bit                ok;
    int                exp_last[];

    set_params(1, 1'b0);
    set_tready(1'b1);
    make_packet(1, 8'h77, tx);

    start_block();
    fork
        send_words(tx);
    join_none

    recv_beat(d, last, ok);
    `FAIL_UNLESS_LOG(ok, "tc02: timeout on the only beat")
    `FAIL_IF_LOG(d[B_TDATA-1:0] !== 16'd0, $sformatf("tc02: payload 0x%0h", d))
    `FAIL_UNLESS_LOG(last === 1'b1, "tc02: tlast missing on a single-beat packet")

    expect_quiet(20, "tc02");
    stop_block();
    wait_idle(ok);

    exp_last = '{0};
    sb_check("tc02");
    check_last_positions("tc02", exp_last);
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 03: continuous mode, two packets of 3
// ----------------------------------------------------------------------------
`SVTEST(tc03_continuous_3x2)
    logic [W_IN-1:0]  tx[];
    logic [B_AXIS-1:0] d;
    logic              last;
    bit                ok;
    int                exp_last[];

    set_params(3, 1'b1);
    set_tready(1'b1);
    make_packet(3, 8'hC3, tx);

    start_block();
    fork
        begin
            send_words(tx);
            send_words(tx);
        end
    join_none

    for (int pkt = 0; pkt < 2; pkt++) begin
        for (int i = 0; i < 3; i++) begin
            recv_beat(d, last, ok);
            `FAIL_UNLESS_LOG(ok, $sformatf("tc03: timeout pkt %0d beat %0d", pkt, i))
            `FAIL_IF_LOG(d[B_TDATA-1:0] !== i[B_TDATA-1:0],
                         $sformatf("tc03: pkt %0d beat %0d payload 0x%0h", pkt, i, d))
            `FAIL_IF_LOG(last !== (i == 2),
                         $sformatf("tc03: pkt %0d beat %0d tlast=%0b", pkt, i, last))
        end
    end

    stop_block();
    wait_idle(ok);

    exp_last = '{2, 5};
    sb_check("tc03");
    check_last_positions("tc03", exp_last);
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 04: random backpressure - payload and tlast must survive tready gaps
// ----------------------------------------------------------------------------
`SVTEST(tc04_backpressure)
    logic [W_IN-1:0]  tx[];
    logic [B_AXIS-1:0] d;
    logic              last;
    bit                ok;
    int                exp_last[];

    set_params(8, 1'b0);
    set_tready(1'b0);
    make_packet(8, 8'h33, tx);

    start_block();
    fork
        send_words(tx);
        // Random tready while the packet is in flight.
        begin
            repeat (400) begin
                @(posedge m_clk);
                set_tready(($urandom_range(0, 2) != 0));
            end
            set_tready(1'b1);
        end
    join_none

    for (int i = 0; i < 8; i++) begin
        recv_beat(d, last, ok);
        `FAIL_UNLESS_LOG(ok, $sformatf("tc04: timeout on beat %0d", i))
        `FAIL_IF_LOG(d[B_TDATA-1:0] !== i[B_TDATA-1:0],
                     $sformatf("tc04: beat %0d payload 0x%0h", i, d))
        `FAIL_IF_LOG(last !== (i == 7),
                     $sformatf("tc04: beat %0d tlast=%0b", i, last))
    end

    disable fork;
    set_tready(1'b1);
    stop_block();
    wait_idle(ok);

    exp_last = '{7};
    sb_check("tc04");
    check_last_positions("tc04", exp_last);
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 05: FIFO overflow - lost_reg must match what the monitor saw dropped
// ----------------------------------------------------------------------------
`SVTEST(tc05_lost_samples)
    logic [W_IN-1:0] tx[];
    bit              ok;

    //! Continuous mode and a packet longer than the buffer, so the run cannot
    //! finish on its own before the overrun happens.
    set_params(OVF_WORDS, 1'b1);
    set_tready(1'b0);              // sink blocked, the FIFO will fill up
    make_packet(OVF_WORDS, 8'h33, tx);

    start_block();
    fork
        send_words(tx);
    join_none

    // Let the FIFO overflow.
    repeat (OVF_WAIT) @(posedge s_clk);

    stop_block();
    set_tready(1'b1);
    wait_idle(ok);
    `FAIL_UNLESS_LOG(ok, "tc05: block never returned to IDLE")

    $display("[TC05] stored=%0d dropped=%0d lost_reg=%0d", sb_stored, sb_dropped, lost_reg);
    `FAIL_IF_LOG(sb_dropped == 0, "tc05: the FIFO never overflowed, test is vacuous")
    `FAIL_IF_LOG(lost_reg !== sb_dropped[31:0],
                 $sformatf("tc05: lost_reg=%0d but %0d beats were dropped",
                           lost_reg, sb_dropped))
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 06: flush_reg = 1 - a truncated packet drains, last beat carries tlast
//
//   The sink is held off during the run on purpose, so that when the block is
//   stopped the 5 beats are still inside it (4 in the FIFO, 1 in the output
//   beat register). Only then is there a truncated packet to drain.
// ----------------------------------------------------------------------------
`SVTEST(tc06_flush_drains_partial)
    logic [W_IN-1:0]   tx[];
    logic [B_AXIS-1:0] d;
    logic              last;
    bit                ok;
    int                n_rx;

    set_params(8, 1'b0, 1'b1);     // packet of 8 configured, only 5 sent
    set_tready(1'b0);              // nothing may leave while we fill
    make_packet(5, 8'hCC, tx);

    start_block();
    send_words(tx);                // blocking: all 5 beats land inside
    repeat (10) @(posedge m_clk);
    `FAIL_IF_LOG(sb_rx != 0, "tc06: beats came out although tready was low")

    stop_block();                  // truncated packet: flush must drain it
    set_tready(1'b1);

    n_rx = 0;
    forever begin
        recv_beat(d, last, ok, 5000);
        if (!ok) break;
        n_rx++;
        if (last) break;
    end

    wait_idle(ok);
    `FAIL_UNLESS_LOG(ok, "tc06: block never returned to IDLE")

    $display("[TC06] received %0d beats, tlast positions: %p", n_rx, last_pos_q);
    `FAIL_IF_LOG(n_rx != 5,
                 $sformatf("tc06: expected the 5 stored beats to drain, got %0d", n_rx))
    `FAIL_IF_LOG(last_pos_q.size() != 1,
                 $sformatf("tc06: expected exactly one tlast, saw %0d", last_pos_q.size()))
    `FAIL_IF_LOG(last_pos_q.size() > 0 && last_pos_q[0] != 4,
                 $sformatf("tc06: tlast on beat %0d, expected the last drained beat (4)",
                           last_pos_q[0]))
    sb_check("tc06");
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 07: flush_reg = 0 - a truncated packet is discarded
//
//   Everything still inside the block is dropped. The one beat that was already
//   presented on the bus with tvalid high completes its handshake instead of
//   being withdrawn: dropping it would violate AXI. So 0 or 1 beats may come
//   out, and never a tlast.
//
//   The sink must stay closed until the FSM has left RUN. start_reg crosses two
//   flops, so raising tready straight after stop_block() lets the block stream
//   several perfectly legitimate RUN beats first, which has nothing to do with
//   the discard behaviour under test.
// ----------------------------------------------------------------------------
`SVTEST(tc07_noflush_discards_partial)
    logic [W_IN-1:0] tx[];
    bit              ok;

    set_params(64, 1'b0, 1'b0);    // flush disabled, packet far from complete
    set_tready(1'b0);
    make_packet(5, 8'hEE, tx);

    start_block();
    send_words(tx);
    repeat (10) @(posedge m_clk);
    `FAIL_IF_LOG(sb_rx != 0, "tc07: beats came out although tready was low")

    stop_block();
    wait_left_run(ok);
    `FAIL_UNLESS_LOG(ok, "tc07: block never left RUN after start_reg was dropped")
    set_tready(1'b1);          // only now, or RUN traffic would escape
    wait_idle(ok);
    `FAIL_UNLESS_LOG(ok, "tc07: block never returned to IDLE")

    $display("[TC07] beats out after stop=%0d, tlast positions: %p", sb_rx, last_pos_q);
    `FAIL_IF_LOG(sb_rx > 1,
                 $sformatf({"tc07: %0d beats escaped after the block left RUN. ",
                            "Only a beat already presented on the bus may complete."}, sb_rx))
    `FAIL_IF_LOG(last_pos_q.size() != 0,
                 "tc07: a tlast was emitted although flushing is disabled")
    expect_quiet(20, "tc07");
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 08: NSAMP = 0 must not start and must not hang
// ----------------------------------------------------------------------------
`SVTEST(tc08_nsamp_zero)
    logic [W_IN-1:0] tx[];
    bit              ok;

    set_params(0, 1'b0);
    set_tready(1'b1);
    make_packet(4, 8'h11, tx);

    @(posedge m_clk);
    start_reg <= 1'b1;
    repeat (50) @(posedge m_clk);

    `FAIL_IF_LOG(dbg_state !== ST_IDLE,
                 $sformatf("tc08: block left IDLE with nsamp=0, state=0x%0h", dbg_state))
    expect_quiet(20, "tc08");

    stop_block();
    wait_idle(ok);
    `FAIL_UNLESS_LOG(ok, "tc08: block did not settle in IDLE")
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 09: two consecutive one-shot runs produce identical packets
// ----------------------------------------------------------------------------
`SVTEST(tc09_restart)
    logic [W_IN-1:0]  tx[];
    logic [B_AXIS-1:0] d;
    logic              last;
    bit                ok;

    make_packet(4, 8'h5A, tx);

    for (int run = 0; run < 2; run++) begin
        sb_clear();
        set_params(4, 1'b0);
        set_tready(1'b1);

        start_block();
        fork
            send_words(tx);
        join_none

        for (int i = 0; i < 4; i++) begin
            recv_beat(d, last, ok);
            `FAIL_UNLESS_LOG(ok, $sformatf("tc09: run %0d timeout on beat %0d", run, i))
            `FAIL_IF_LOG(d[B_TDATA-1:0] !== i[B_TDATA-1:0],
                         $sformatf("tc09: run %0d beat %0d payload 0x%0h", run, i, d))
            `FAIL_IF_LOG(last !== (i == 3),
                         $sformatf("tc09: run %0d beat %0d tlast=%0b", run, i, last))
        end

        stop_block();
        wait_idle(ok);
        `FAIL_UNLESS_LOG(ok, $sformatf("tc09: run %0d never returned to IDLE", run))
        sb_check($sformatf("tc09 run %0d", run));
    end
`SVTEST_END
