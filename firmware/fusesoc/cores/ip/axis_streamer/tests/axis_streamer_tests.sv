// ============================================================================
// File: axis_streamer_tests.sv
// Project: QICK
// Description: SVUnit integration tests for axis_streamer.
//
// Sequence used by every streaming test, mirroring the documented software
// flow: configure -> start_block -> send -> consume -> stop -> wait -> check.
// start_block MUST come before any traffic: s_axis_tready is ~fifo_full and is
// not gated by the run state, so beats offered earlier are accepted on the bus
// and thrown away.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 00: register defaults, readback, read-only enforcement and independence
// ----------------------------------------------------------------------------
`SVTEST(tc00_registers)
    logic [31:0] rd;
    logic [31:0] st;

    // --- defaults after reset ---
    reg_read(REG_START, rd);
    `FAIL_IF_LOG(rd[0] !== 1'b0, $sformatf("START default 0x%08h", rd))
    reg_read(REG_NSAMP, rd);
    `FAIL_IF_LOG(rd !== 32'd0, $sformatf("NSAMP default 0x%08h", rd))
    reg_read(REG_LOST, rd);
    `FAIL_IF_LOG(rd !== 32'd0, $sformatf("LOST default 0x%08h", rd))

    // --- writable registers read back ---
    reg_write(REG_NSAMP, 32'h0000_0123);
    reg_read (REG_NSAMP, rd);
    `FAIL_IF_LOG(rd !== 32'h0000_0123, $sformatf("NSAMP readback 0x%08h", rd))

    reg_write(REG_MODE, 32'd1);
    reg_read (REG_MODE, rd);
    `FAIL_IF_LOG(rd[0] !== 1'b1, $sformatf("MODE readback 0x%08h", rd))

    reg_write(REG_FLUSH, 32'd1);
    reg_read (REG_FLUSH, rd);
    `FAIL_IF_LOG(rd[0] !== 1'b1, $sformatf("FLUSH readback 0x%08h", rd))

    // --- independence: NSAMP must not have disturbed its neighbours ---
    reg_read(REG_START, rd);
    `FAIL_IF_LOG(rd[0] !== 1'b0, "writing NSAMP/MODE/FLUSH disturbed START")
    reg_read(REG_NSAMP, rd);
    `FAIL_IF_LOG(rd !== 32'h0000_0123, "writing MODE/FLUSH disturbed NSAMP")

    // --- read-only registers must ignore writes ---
    reg_write(REG_LOST, 32'hDEAD_BEEF);
    reg_read (REG_LOST, rd);
    `FAIL_IF_LOG(rd === 32'hDEAD_BEEF, "LOST accepted a write, it must be read-only")

    reg_write(REG_STATUS, 32'hFFFF_FFFF);
    read_status(st);
    `FAIL_IF_LOG(st === 32'hFFFF_FFFF, "STATUS accepted a write, it must be read-only")

    // --- STATUS reflects an idle block ---
    `FAIL_UNLESS_LOG(st[ST_IDLE]    === 1'b1, $sformatf("STATUS.IDLE not set at rest: 0x%08h", st))
    `FAIL_IF_LOG    (st[ST_RUNNING] === 1'b1, $sformatf("STATUS.RUNNING set at rest: 0x%08h", st))
    `FAIL_IF_LOG    (st[ST_OVF]     === 1'b1, $sformatf("STATUS.OVERFLOW set at rest: 0x%08h", st))
    `FAIL_UNLESS_LOG(st[ST_EMPTY]   === 1'b1, $sformatf("STATUS.FIFO_EMPTY clear at rest: 0x%08h", st))
    `FAIL_IF_LOG    (st[31:6]       !== 26'd0, $sformatf("STATUS has bits set above [5]: 0x%08h", st))
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 01: one-shot, NSAMP = 4, payload and tlast verified
// ----------------------------------------------------------------------------
`SVTEST(tc01_oneshot_4)
    logic [W_IN-1:0]   tx[];
    logic [B_AXIS-1:0] d;
    logic              last;
    bit                ok;
    int                exp_last[];

    configure(4, 1'b0);
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
                     $sformatf("tc01: beat %0d payload 0x%08h", i, d))
        `FAIL_IF_LOG(last !== (i == 3),
                     $sformatf("tc01: beat %0d tlast=%0b", i, last))
    end

    expect_quiet(30, "tc01");
    stop_block();
    wait_idle(ok);
    `FAIL_UNLESS_LOG(ok, "tc01: block never returned to IDLE")

    exp_last = '{3};
    sb_check("tc01");
    check_last_positions("tc01", exp_last);
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 02: one-shot, NSAMP = 1, degenerate packet
// ----------------------------------------------------------------------------
`SVTEST(tc02_oneshot_1)
    logic [W_IN-1:0]   tx[];
    logic [B_AXIS-1:0] d;
    logic              last;
    bit                ok;
    int                exp_last[];

    configure(1, 1'b0);
    set_tready(1'b1);
    make_packet(1, 8'h77, tx);

    start_block();
    fork
        send_words(tx);
    join_none

    recv_beat(d, last, ok);
    `FAIL_UNLESS_LOG(ok, "tc02: timeout on the only beat")
    `FAIL_UNLESS_LOG(last === 1'b1, "tc02: tlast missing on a single-beat packet")

    expect_quiet(30, "tc02");
    stop_block();
    wait_idle(ok);

    exp_last = '{0};
    sb_check("tc02");
    check_last_positions("tc02", exp_last);
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 03: continuous mode, three packets of three
// ----------------------------------------------------------------------------
`SVTEST(tc03_continuous_3x3)
    logic [W_IN-1:0]   tx[];
    logic [B_AXIS-1:0] d;
    logic              last;
    bit                ok;
    int                exp_last[];

    configure(3, 1'b1);
    set_tready(1'b1);
    make_packet(3, 8'hC3, tx);

    start_block();
    fork
        begin
            send_words(tx);
            send_words(tx);
            send_words(tx);
        end
    join_none

    for (int pkt = 0; pkt < 3; pkt++) begin
        for (int i = 0; i < 3; i++) begin
            recv_beat(d, last, ok);
            `FAIL_UNLESS_LOG(ok, $sformatf("tc03: timeout pkt %0d beat %0d", pkt, i))
            `FAIL_IF_LOG(d[B_TDATA-1:0] !== i[B_TDATA-1:0],
                         $sformatf("tc03: pkt %0d beat %0d payload 0x%08h", pkt, i, d))
            `FAIL_IF_LOG(last !== (i == 2),
                         $sformatf("tc03: pkt %0d beat %0d tlast=%0b", pkt, i, last))
        end
    end

    stop_block();
    wait_idle(ok);

    exp_last = '{2, 5, 8};
    sb_check("tc03");
    check_last_positions("tc03", exp_last);
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 04: random backpressure on the DMA side
// ----------------------------------------------------------------------------
`SVTEST(tc04_backpressure)
    logic [W_IN-1:0]   tx[];
    logic [B_AXIS-1:0] d;
    logic              last;
    bit                ok;
    int                exp_last[];

    configure(8, 1'b0);
    set_tready(1'b0);
    make_packet(8, 8'h33, tx);

    start_block();
    fork
        send_words(tx);
        begin
            repeat (600) begin
                @(posedge m_axis_aclk);
                set_tready(($urandom_range(0, 2) != 0));
            end
            set_tready(1'b1);
        end
    join_none

    for (int i = 0; i < 8; i++) begin
        recv_beat(d, last, ok);
        `FAIL_UNLESS_LOG(ok, $sformatf("tc04: timeout on beat %0d", i))
        `FAIL_IF_LOG(d[B_TDATA-1:0] !== i[B_TDATA-1:0],
                     $sformatf("tc04: beat %0d payload 0x%08h", i, d))
        `FAIL_IF_LOG(last !== (i == 7),
                     $sformatf("tc04: beat %0d tlast=%0b", i, last))
    end

    //! Make sure the master retired before killing the tready randomiser: a
    //! `disable fork` while a beat is pending would drop tvalid illegally.
    set_tready(1'b1);
    wait_tx_done(ok);
    `FAIL_UNLESS_LOG(ok, "tc04: the input master never finished")
    disable fork;
    set_tready(1'b1);

    stop_block();
    wait_idle(ok);

    exp_last = '{7};
    sb_check("tc04");
    check_last_positions("tc04", exp_last);
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 05: overflow - LOST must match the monitor exactly, OVERFLOW must stick
//
//   The sink is blocked so the FIFO fills and beats start being dropped. That
//   also stalls the master, since s_axis_tready is ~fifo_full: it ends up
//   holding tvalid high with no handshake in sight. There is no legal way to
//   abort that beat, so the test opens the sink and lets the master retire
//   before stopping the block. Killing the thread instead would drop tvalid
//   without a handshake and trip AXIS_TVALID_STABLE.
// ----------------------------------------------------------------------------
`SVTEST(tc05_lost_and_overflow)
    logic [W_IN-1:0] tx[];
    logic [31:0]     lost_val;
    logic [31:0]     st;
    bit              ok;

    configure(OVF_WORDS, 1'b1);    // continuous, so the run does not self-stop
    set_tready(1'b0);              // sink blocked, the FIFO will fill
    make_packet(OVF_WORDS, 8'h33, tx);

    start_block();
    fork
        send_words(tx);
    join_none

    // Let the FIFO fill up and start dropping.
    repeat (OVF_WAIT) @(posedge s_axis_aclk);

    // OVERFLOW is the flag software can trust DURING a run.
    read_status(st);
    `FAIL_UNLESS_LOG(st[ST_OVF] === 1'b1,
                     $sformatf("tc05: STATUS.OVERFLOW not set while overflowing: 0x%08h", st))
    `FAIL_UNLESS_LOG(st[ST_RUNNING] === 1'b1,
                     $sformatf("tc05: STATUS.RUNNING not set while running: 0x%08h", st))
    `FAIL_IF_LOG(st[ST_IDLE] === 1'b1,
                 $sformatf("tc05: STATUS.IDLE set while running: 0x%08h", st))

    // Open the sink so the stalled master can complete its pending beat.
    set_tready(1'b1);
    wait_tx_done(ok);
    `FAIL_UNLESS_LOG(ok, "tc05: the input master never drained, sink stayed blocked")

    stop_block();
    wait_idle(ok);
    `FAIL_UNLESS_LOG(ok, "tc05: block never returned to IDLE")

    // LOST is only meaningful once the block reports IDLE.
    poll_status_bit(ST_IDLE, 1'b1, ok);
    `FAIL_UNLESS_LOG(ok, "tc05: STATUS.IDLE never asserted after stopping")

    reg_read(REG_LOST, lost_val);
    $display("[TC05] stored=%0d dropped=%0d LOST=%0d", sb_stored, sb_dropped, lost_val);
    `FAIL_IF_LOG(sb_dropped == 0, "tc05: the FIFO never overflowed, test is vacuous")
    `FAIL_IF_LOG(lost_val !== sb_dropped[31:0],
                 $sformatf("tc05: LOST=%0d but %0d beats were dropped",
                           lost_val, sb_dropped))

    // OVERFLOW is sticky and must survive until the next run starts.
    read_status(st);
    `FAIL_UNLESS_LOG(st[ST_OVF] === 1'b1,
                     $sformatf("tc05: STATUS.OVERFLOW did not stick after the run: 0x%08h", st))
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 06: FLUSH = 1, a truncated packet drains and its last beat carries tlast
//
//   The sink is held off during the run so that at stop time the beats are
//   still inside the block. Only then is there a partial packet to drain.
// ----------------------------------------------------------------------------
`SVTEST(tc06_flush_drains_partial)
    logic [W_IN-1:0]   tx[];
    logic [B_AXIS-1:0] d;
    logic              last;
    bit                ok;
    int                n_rx;

    configure(8, 1'b0, 1'b1);      // packet of 8 configured, flush enabled
    set_tready(1'b0);
    make_packet(5, 8'hCC, tx);

    start_block();
    send_words(tx);                // blocking: all 5 beats land inside
    repeat (20) @(posedge m_axis_aclk);
    `FAIL_IF_LOG(sb_rx != 0, "tc06: beats came out although tready was low")

    stop_block();
    set_tready(1'b1);

    n_rx = 0;
    forever begin
        recv_beat(d, last, ok, 8000);
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
// TEST 07: FLUSH = 0, a truncated packet is discarded
//
//   At most the single beat already presented on the bus may complete its
//   handshake: withdrawing tvalid would violate AXI. Nothing else escapes and
//   no tlast is produced.
// ----------------------------------------------------------------------------
`SVTEST(tc07_noflush_discards_partial)
    logic [W_IN-1:0] tx[];
    bit              ok;

    configure(64, 1'b0, 1'b0);     // flush disabled, packet far from complete
    set_tready(1'b0);
    make_packet(5, 8'hEE, tx);

    start_block();
    send_words(tx);
    repeat (20) @(posedge m_axis_aclk);
    `FAIL_IF_LOG(sb_rx != 0, "tc07: beats came out although tready was low")

    stop_block();
    wait_left_run(ok);
    `FAIL_UNLESS_LOG(ok, "tc07: block never left RUN after START was cleared")
    set_tready(1'b1);              // only now, or RUN traffic would escape
    wait_idle(ok);
    `FAIL_UNLESS_LOG(ok, "tc07: block never returned to IDLE")

    $display("[TC07] beats out after stop=%0d, tlast positions: %p", sb_rx, last_pos_q);
    `FAIL_IF_LOG(sb_rx > 1,
                 $sformatf({"tc07: %0d beats escaped after the block left RUN. ",
                            "Only a beat already presented on the bus may complete."}, sb_rx))
    `FAIL_IF_LOG(last_pos_q.size() != 0,
                 "tc07: a tlast was emitted although flushing is disabled")
    expect_quiet(30, "tc07");
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 08: NSAMP = 0 must not start and must not hang
// ----------------------------------------------------------------------------
`SVTEST(tc08_nsamp_zero)
    logic [W_IN-1:0] tx[];
    logic [31:0]     st;
    bit              ok;

    configure(0, 1'b0);
    set_tready(1'b1);
    make_packet(4, 8'h11, tx);

    reg_write(REG_START, 32'd1);
    repeat (200) @(posedge m_axis_aclk);

    read_status(st);
    `FAIL_UNLESS_LOG(st[ST_IDLE] === 1'b1,
                     $sformatf("tc08: block left IDLE with NSAMP=0, STATUS=0x%08h", st))
    `FAIL_IF_LOG(st[ST_RUNNING] === 1'b1,
                 $sformatf("tc08: block reports RUNNING with NSAMP=0, STATUS=0x%08h", st))
    expect_quiet(30, "tc08");

    stop_block();
    wait_idle(ok);
    `FAIL_UNLESS_LOG(ok, "tc08: block did not settle in IDLE")
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 09: two consecutive one-shot runs, reconfigured in between
// ----------------------------------------------------------------------------
`SVTEST(tc09_restart_reconfigure)
    logic [W_IN-1:0]   tx[];
    logic [B_AXIS-1:0] d;
    logic              last;
    bit                ok;
    int                ns;

    for (int run = 0; run < 2; run++) begin
        ns = (run == 0) ? 4 : 6;      // different packet size on the second run
        sb_clear();
        configure(ns, 1'b0);
        set_tready(1'b1);
        make_packet(ns, 8'h5A, tx);

        start_block();
        fork
            send_words(tx);
        join_none

        for (int i = 0; i < ns; i++) begin
            recv_beat(d, last, ok);
            `FAIL_UNLESS_LOG(ok, $sformatf("tc09: run %0d timeout on beat %0d", run, i))
            `FAIL_IF_LOG(d[B_TDATA-1:0] !== i[B_TDATA-1:0],
                         $sformatf("tc09: run %0d beat %0d payload 0x%08h", run, i, d))
            `FAIL_IF_LOG(last !== (i == ns-1),
                         $sformatf("tc09: run %0d beat %0d tlast=%0b", run, i, last))
        end

        stop_block();
        wait_idle(ok);
        `FAIL_UNLESS_LOG(ok, $sformatf("tc09: run %0d never returned to IDLE", run))
        sb_check($sformatf("tc09 run %0d", run));
        `FAIL_IF_LOG(last_pos_q.size() != 1,
                     $sformatf("tc09: run %0d produced %0d tlast, expected 1",
                               run, last_pos_q.size()))
    end
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 10: STATUS follows the FSM through a full one-shot cycle
//
//   This is the register software actually polls, so the transitions matter as
//   much as the values.
// ----------------------------------------------------------------------------
`SVTEST(tc10_status_tracks_fsm)
    logic [W_IN-1:0]   tx[];
    logic [B_AXIS-1:0] d;
    logic              last;
    logic [31:0]       st;
    bit                ok;

    configure(4, 1'b0);
    set_tready(1'b1);
    make_packet(4, 8'hA5, tx);

    // --- idle before starting ---
    read_status(st);
    `FAIL_UNLESS_LOG(st[ST_IDLE] === 1'b1, "tc10: not IDLE before starting")

    // --- running ---
    start_block();
    poll_status_bit(ST_RUNNING, 1'b1, ok);
    `FAIL_UNLESS_LOG(ok, "tc10: STATUS.RUNNING never asserted after START")
    read_status(st);
    `FAIL_IF_LOG(st[ST_IDLE] === 1'b1, "tc10: IDLE and RUNNING set at the same time")

    fork
        send_words(tx);
    join_none

    for (int i = 0; i < 4; i++) begin
        recv_beat(d, last, ok);
        `FAIL_UNLESS_LOG(ok, $sformatf("tc10: timeout on beat %0d", i))
    end

    // --- one-shot finished: DONE, still waiting for START to be cleared ---
    poll_status_bit(ST_DONE, 1'b1, ok);
    `FAIL_UNLESS_LOG(ok, "tc10: STATUS.DONE never asserted after the one-shot packet")
    read_status(st);
    `FAIL_IF_LOG(st[ST_RUNNING] === 1'b1, "tc10: RUNNING still set after DONE")

    // --- back to idle once START is cleared ---
    stop_block();
    poll_status_bit(ST_IDLE, 1'b1, ok);
    `FAIL_UNLESS_LOG(ok, "tc10: STATUS.IDLE never asserted after clearing START")
    read_status(st);
    `FAIL_IF_LOG(st[ST_DONE] === 1'b1, "tc10: DONE still set after returning to IDLE")
    `FAIL_IF_LOG(st[ST_OVF]  === 1'b1, "tc10: OVERFLOW set although nothing was lost")

    sb_check("tc10");
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 11: free-running source - LOST counts genuinely lost samples
//
//   This is the real deployment: an ADC feeding the block, a DMA draining it.
//   The converter cannot be stalled, so every cycle in which the FIFO is full
//   costs one sample, and LOST is then exactly the number of samples that never
//   made it into the buffer.
//
//   THE INVARIANT SOFTWARE CARES ABOUT:
//       samples offered by the ADC == samples stored + LOST
//
//   tc05 measures the same counter with a well-behaved AXI master, where the
//   same beat is held across many stalled cycles. There LOST counts stall
//   cycles rather than distinct samples, which is why the two tests assert
//   different things about the same register.
//
//   Assertions on s_axis_if are switched off here: a free-running converter is
//   not an AXI4-Stream master and does not obey TDATA_STABLE under
//   backpressure. Suppressing them is the honest thing to do, not a workaround.
// ----------------------------------------------------------------------------
`SVTEST(tc11_freerun_source_lost)
    logic [W_IN-1:0] tx[];
    logic [31:0]     lost_val;
    logic [31:0]     st;
    bit              ok;
    int              offered;

    configure(OVF_WORDS*2, 1'b1);  // continuous, packet larger than the buffer
    set_tready(1'b0);              // DMA not draining: the buffer will overrun
    make_packet(OVF_WORDS*2, 8'h5C, tx);

    $assertoff(0, s_axis_if);      // see the note above

    start_block();
    send_words_freerun(tx, offered);

    read_status(st);
    `FAIL_UNLESS_LOG(st[ST_OVF] === 1'b1,
                     $sformatf("tc11: STATUS.OVERFLOW not set after an overrun: 0x%08h", st))

    stop_block();
    set_tready(1'b1);
    wait_idle(ok);
    `FAIL_UNLESS_LOG(ok, "tc11: block never returned to IDLE")

    $asserton(0, s_axis_if);

    reg_read(REG_LOST, lost_val);
    $display("[TC11] offered=%0d stored=%0d LOST=%0d  (stored+LOST=%0d)",
             offered, sb_stored, lost_val, sb_stored + lost_val);

    `FAIL_IF_LOG(lost_val == 0, "tc11: nothing was lost, the buffer never overran")
    `FAIL_IF_LOG(sb_stored == 0, "tc11: nothing was stored at all")
    `FAIL_IF_LOG((sb_stored + int'(lost_val)) != offered,
                 $sformatf({"tc11: %0d samples offered but stored=%0d + LOST=%0d = %0d. ",
                            "For a free-running source these must balance exactly."},
                           offered, sb_stored, lost_val, sb_stored + int'(lost_val)))
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 12: one-shot with a free-running source ends after exactly one packet
//
//   The real source (an ADC) keeps producing after the packet is complete, and
//   the write side only sees the end of the run a few clocks later. Those
//   late words belong to no packet. They must be dropped whatever FLUSH says:
//   FLUSH is about a packet truncated by START = 0, and a completed one-shot
//   packet is not truncated. Emitting them as a second, short packet hangs a
//   DMA that was armed for one transfer (seen on the RFSoC4x2).
//
//   Case 1 and 2 also stall the sink on the last beat, long enough to overrun
//   the FIFO if the late words were left in it: that overrun must not show up
//   as LOST, since nothing that belonged to the packet was lost.
//
//   case  FLUSH  stall on the last beat
//     0     1      no
//     1     0      yes
//     2     1      yes
// ----------------------------------------------------------------------------
`SVTEST(tc12_oneshot_freerun_single_packet)
    localparam int NS = 32;
    logic [W_IN-1:0]   tx[];
    logic [B_AXIS-1:0] d;
    logic              last;
    logic [31:0]       lost_val;
    bit                ok;
    bit                flush;
    bit                stall;
    int                offered;
    int                exp_last[];

    $assertoff(0, s_axis_if);      // free-running source, see send_words_freerun

    for (int c = 0; c < 3; c++) begin
        flush = (c != 1);
        stall = (c != 0);
        sb_clear();
        configure(NS, 1'b0, flush);
        set_tready(1'b1);
        make_packet(NS * 12, 8'h6E, tx);

        start_block();
        fork
            send_words_freerun(tx, offered);
        join_none

        for (int i = 0; i < NS; i++) begin
            if (stall && i == NS - 1) begin
                set_tready(1'b0);
                repeat (4 * N_FIFO + 100) @(posedge m_axis_aclk);
                set_tready(1'b1);
            end
            recv_beat(d, last, ok);
            `FAIL_UNLESS_LOG(ok, $sformatf("tc12 case %0d: timeout on beat %0d", c, i))
            `FAIL_IF_LOG(last !== (i == NS - 1),
                         $sformatf("tc12 case %0d: beat %0d tlast=%0b", c, i, last))
        end

        // Nothing may follow the packet, and the block must reach DONE on its own.
        expect_quiet(100, $sformatf("tc12 case %0d", c));
        poll_status_bit(ST_DONE, 1'b1, ok);
        `FAIL_UNLESS_LOG(ok, $sformatf("tc12 case %0d: STATUS.DONE never set", c))

        wait_tx_done(ok);
        stop_block();
        wait_idle(ok);
        `FAIL_UNLESS_LOG(ok, $sformatf("tc12 case %0d: block never returned to IDLE", c))
        poll_status_bit(ST_IDLE, 1'b1, ok);
        `FAIL_UNLESS_LOG(ok, $sformatf("tc12 case %0d: STATUS.IDLE never asserted", c))

        reg_read(REG_LOST, lost_val);
        $display("[TC12] case %0d flush=%0b stall=%0b offered=%0d stored=%0d rx=%0d LOST=%0d",
                 c, flush, stall, offered, sb_stored, sb_rx, lost_val);
        `FAIL_IF_LOG(sb_rx != NS,
                     $sformatf("tc12 case %0d: %0d beats delivered, expected %0d", c, sb_rx, NS))
        `FAIL_IF_LOG(lost_val != 0,
                     $sformatf("tc12 case %0d: LOST=%0d after a complete packet", c, lost_val))
        exp_last = '{NS - 1};
        sb_check($sformatf("tc12 case %0d", c));
        check_last_positions($sformatf("tc12 case %0d", c), exp_last);
    end

    $asserton(0, s_axis_if);
`SVTEST_END
