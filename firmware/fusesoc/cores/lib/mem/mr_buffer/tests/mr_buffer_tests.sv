// ============================================================================
// File: mr_buffer_tests.sv
// Description: SVUnit test cases for the mr_buffer core.
// Included by mr_buffer_tc00.sv inside `SVUNIT_TESTS_BEGIN/END.
//
// Every read burst is consumed with burst_rx(), which holds tready high for the
// whole packet and returns everything up to tlast.  Two invariants are checked
// on every burst and never silently skipped:
//   - beats.size() == TOTAL_WORDS   (tlast landed on the right beat)
//   - beats[0] is ch0 @ addr 0      (word ordering)
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 00: Basic write/read — one beat captured, every channel of address 0
// verified through the full read burst.
// ----------------------------------------------------------------------------
`SVTEST(tc00_basic_write_read)
    logic [M_DATA_W-1:0] beats [$];

    do_capture(16'hAAAA);

    start_reader();
    drain_burst(beats);
    stop_reader();

    `FAIL_IF_LOG(beats.size() !== TOTAL_WORDS,
        $sformatf("tc00: burst had %0d beats, expected %0d (tlast position)",
                  beats.size(), TOTAL_WORDS));

    for (int ch = 0; ch < NM; ch++) begin
        `FAIL_IF_LOG(beats[ch][B-1:0] !== exp_ch(16'hAAAA, ch),
            $sformatf("tc00: addr=0 ch=%0d expected 0x%0h got 0x%0h",
                      ch, exp_ch(16'hAAAA, ch), beats[ch][B-1:0]));
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 01: Multiple beats — 8 beats with distinct ch0 values land at 8
// consecutive BRAM addresses; every channel of every address is verified.
// ----------------------------------------------------------------------------
`SVTEST(tc01_multiple_beats)
    localparam int BEATS = 8;
    logic [B-1:0]        expected [BEATS];
    logic [M_DATA_W-1:0] beats [$];
    int                  idx;

    for (int i = 0; i < BEATS; i++)
        expected[i] = 16'hAAAA + B'(i);

    arm_and_trigger();
    for (int i = 0; i < BEATS; i++)
        send_beat(expected[i], (i == BEATS-1) ? 1'b1 : 1'b0);

    repeat (20) @(posedge s_axis_aclk);   // let the FIFO drain into the BRAM
    disarm();
    repeat (50) @(posedge m_axis_aclk);   // CDC margin

    start_reader();
    drain_burst(beats);
    stop_reader();

    `FAIL_IF_LOG(beats.size() !== TOTAL_WORDS,
        $sformatf("tc01: burst had %0d beats, expected %0d (tlast position)",
                  beats.size(), TOTAL_WORDS));

    for (int addr = 0; addr < BEATS; addr++) begin
        for (int ch = 0; ch < NM; ch++) begin
            idx = addr * NM + ch;
            `FAIL_IF_LOG(beats[idx][B-1:0] !== exp_ch(expected[addr], ch),
                $sformatf("tc01: addr=%0d ch=%0d (beat %0d) expected 0x%0h got 0x%0h",
                          addr, ch, idx, exp_ch(expected[addr], ch), beats[idx][B-1:0]));
        end
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Re-arm — a second capture overwrites address 0, and the second
// burst must not return anything left over from the first.
// ----------------------------------------------------------------------------
`SVTEST(tc02_rearm_second_capture)
    logic [M_DATA_W-1:0] beats [$];

    do_capture(16'hAAAA);
    start_reader();
    drain_burst(beats);
    stop_reader();

    `FAIL_IF_LOG(beats.size() !== TOTAL_WORDS,
        $sformatf("tc02 first: burst had %0d beats, expected %0d — a short burst leaves stale beats in the reader FIFO", beats.size(), TOTAL_WORDS));
    `FAIL_IF_LOG(beats[0][B-1:0] !== 16'hAAAA,
        $sformatf("tc02 first: expected 0xAAAA, got 0x%0h", beats[0][B-1:0]));

    do_capture(16'hBBBB);
    start_reader();
    drain_burst(beats);
    stop_reader();

    `FAIL_IF_LOG(beats.size() !== TOTAL_WORDS,
        $sformatf("tc02 second: burst had %0d beats, expected %0d",
                  beats.size(), TOTAL_WORDS));
    `FAIL_IF_LOG(beats[0][B-1:0] !== 16'hBBBB,
        $sformatf("tc02 second: expected 0xBBBB, got 0x%0h — stale data from the previous burst", beats[0][B-1:0]));
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Trigger before arm — a stale trigger must not start a capture.
// ----------------------------------------------------------------------------
`SVTEST(tc03_trigger_before_arm_ignored)
    // Stale trigger while capture_reg is still 0
    @(posedge s_axis_aclk);
    trigger <= 1'b1;
    @(posedge s_axis_aclk);
    trigger <= 1'b0;
    repeat (3) @(posedge s_axis_aclk);

    // Arm: the FSM must sit in TRIGGER_ST waiting for a fresh trigger
    @(posedge s_axis_aclk);
    dw_capture_reg <= 1'b1;
    wait_wr_state(WR_TRIGGER_ST);
    repeat (8) @(posedge s_axis_aclk);

    `FAIL_IF_LOG(s_axis_if.tready !== 1'b0,
        "tc03: tready should be low while waiting for a fresh trigger");
    `FAIL_IF_LOG(dut.gen_channel[0].u_axis_to_bram_trig.current_state !== WR_TRIGGER_ST,
        "tc03: capture FSM left TRIGGER_ST without a fresh trigger");

    disarm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: capture disabled, no force — tready stays low.
// ----------------------------------------------------------------------------
`SVTEST(tc04_no_capture_no_tready)
    `FAIL_IF(debug_reg[1] !== 1'b0);

    repeat (10) @(posedge s_axis_aclk);
    `FAIL_IF_LOG(s_axis_if.tready !== 1'b0,
        "tc04: tready should be low when capture is disabled");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: tready_force override (debug_reg[1]).
// ----------------------------------------------------------------------------
`SVTEST(tc05_tready_force_override)
    @(posedge s_axis_aclk);
    debug_reg[1] <= 1'b1;
    repeat (5) @(posedge s_axis_aclk);
    `FAIL_IF_LOG(s_axis_if.tready !== 1'b1,
        "tc05: tready should be forced high by debug_reg[1]");

    @(posedge s_axis_aclk);
    debug_reg[1] <= 1'b0;
    repeat (5) @(posedge s_axis_aclk);
    `FAIL_IF_LOG(s_axis_if.tready !== 1'b0,
        "tc05: tready should return low after clearing debug_reg[1]");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: tlast position — tlast lands exactly on beat TOTAL_WORDS-1, and the
// master goes quiet afterwards instead of emitting extra beats.
// ----------------------------------------------------------------------------
`SVTEST(tc06_tlast_on_last_word)
    logic [M_DATA_W-1:0] beats [$];

    do_capture(16'hCCCC);

    start_reader();
    drain_burst(beats);

    `FAIL_IF_LOG(beats.size() !== TOTAL_WORDS,
        $sformatf("tc06: tlast at beat %0d, expected %0d",
                  beats.size()-1, TOTAL_WORDS-1));

    repeat (20) @(posedge m_axis_aclk);
    `FAIL_IF_LOG(m_axis_if.tvalid !== 1'b0,
        "tc06: tvalid still asserted after the burst completed");

    stop_reader();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: o_capture_done — the writer must report completion on its way back
// to INIT_ST.  The flag is a level that is only high in END_ST, so it is
// observed with the sticky monitor in the top level.
// ----------------------------------------------------------------------------
`SVTEST(tc07_capture_done_asserts)
    `FAIL_IF_LOG(saw_capture_done !== 1'b0,
        "tc07: capture_done was already set before any capture ran");

    do_capture(16'hEEEE);

    `FAIL_IF_LOG(saw_capture_done !== 1'b1,
        "tc07: capture_done never asserted during a completed capture");
    `FAIL_IF_LOG(o_capture_done !== 1'b0,
        "tc07: capture_done still high after the FSM returned to INIT_ST");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: Two back-to-back bursts from a single capture — the same window can
// be re-read without re-arming, and both bursts are identical.
// ----------------------------------------------------------------------------
`SVTEST(tc08_two_bursts_same_capture)
    logic [M_DATA_W-1:0] first  [$];
    logic [M_DATA_W-1:0] second [$];

    do_capture(16'hDDDD);

    start_reader();
    drain_burst(first);
    stop_reader();

    start_reader();
    drain_burst(second);
    stop_reader();

    `FAIL_IF_LOG(first.size() !== TOTAL_WORDS || second.size() !== TOTAL_WORDS,
        $sformatf("tc08: burst sizes %0d and %0d, expected %0d each",
                  first.size(), second.size(), TOTAL_WORDS));

    for (int i = 0; i < TOTAL_WORDS; i++) begin
        `FAIL_IF_LOG(first[i] !== second[i],
            $sformatf("tc08: beat %0d differs between bursts: 0x%0h vs 0x%0h",
                      i, first[i], second[i]));
    end
`SVTEST_END

// ============================================================================
// Additional test cases
//
// These two target the axis_to_bram_trig v1.1 fixes specifically.  They are
// written against the mr_buffer TB helpers (arm_and_trigger / send_beat /
// disarm / start_reader / drain_burst / exp_ch), and drop into
// mr_buffer_et_tests.sv unchanged since those helpers share their names.
//
// Both are negative-regression tests: revert axis_to_bram_trig to v1.0 and
// they must fail.  If they pass against v1.0 too, they are not testing what
// they claim to and the stimulus needs tightening.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 09: Tail not lost on disarm.
//
// v1.0 lost the end of a capture in two ways when capture_reg dropped:
//   - END_ST popped the FIFO with write_en=0, discarding whatever was in it
//   - entering END_ST cleared mem_we_r, cancelling the write that had already
//     been popped and was sitting in the BRAM write pipeline
//
// The other tests never see this because they insert a 20-cycle settling
// margin before disarm(), by which point the FIFO and the pipeline are empty.
// This test deliberately removes that margin: capture_reg drops with the last
// beat still in flight.  Every beat the DUT accepted (tx() only returns on a
// completed handshake) must be readable from the BRAM afterwards.
// ----------------------------------------------------------------------------
`SVTEST(tc09_tail_not_lost_on_disarm)
    localparam int BEATS = 32;
    logic [B-1:0]        expected [BEATS];
    logic [M_DATA_W-1:0] beats [$];
    int                  idx;
 
    for (int i = 0; i < BEATS; i++)
        expected[i] = 16'h1000 + B'(i);
 
    arm_and_trigger();
 
    for (int i = 0; i < BEATS; i++)
        send_beat(expected[i], (i == BEATS-1) ? 1'b1 : 1'b0);
 
    // NO settling margin here — that is the whole point of this test.
    disarm();
    repeat (50) @(posedge m_axis_aclk);   // CDC margin only
 
    start_reader();
    drain_burst(beats);
    stop_reader();
 
    `FAIL_IF_LOG(beats.size() !== TOTAL_WORDS,
        $sformatf("tc09: burst had %0d beats, expected %0d",
                  beats.size(), TOTAL_WORDS));
 
    for (int addr = 0; addr < BEATS; addr++) begin
        for (int ch = 0; ch < NM; ch++) begin
            idx = addr * NM + ch;
            `FAIL_IF_LOG(beats[idx][B-1:0] !== exp_ch(expected[addr], ch),
                $sformatf("tc09: addr=%0d ch=%0d expected 0x%0h got 0x%0h%s",
                          addr, ch, exp_ch(expected[addr], ch), beats[idx][B-1:0],
                          (addr == BEATS-1) ? "  <-- LAST beat of the capture"
                                            : ""));
        end
    end
`SVTEST_END
 
// ----------------------------------------------------------------------------
// TEST 10: Full window — the capture retires on its own and does not wrap.
//
// This is the hardware case in miniature: on the bench the window is 2**16
// samples per channel and the FSM leaves CAPTURE_ST because window_full sets,
// not because software dropped capture_reg.  Checks three things:
//   - the FSM reaches END_ST by itself after exactly DEPTH beats, with
//     capture_reg still high (o_capture_done is the same flag software polls)
//   - address 0 still holds the FIRST beat, i.e. the counter did not wrap and
//     overwrite the start of the window
//   - the last address holds the last beat
//
// Exactly DEPTH beats are sent: once window_full sets, tready drops, and a
// further send_beat() would sit in tx()'s timeout and $fatal.
// ----------------------------------------------------------------------------
`SVTEST(tc10_full_window_retires_without_wrap)
    logic [M_DATA_W-1:0] beats [$];
    logic [B-1:0]        val;
    int                  idx;
    int                  guard;
 
    arm_and_trigger();
 
    // Fill the whole window.  Values are unique modulo 2**B so a wrap-around
    // would be visible as the wrong value at address 0.
    for (int i = 0; i < DEPTH; i++)
        send_beat(16'h4000 + B'(i), (i == DEPTH-1) ? 1'b1 : 1'b0);
 
    // The FSM must retire on its own — capture_reg is still asserted
    guard = 0;
    while (o_capture_done !== 1'b1) begin
        @(posedge s_axis_aclk);
        `FAIL_IF_LOG(++guard > 1000,
            "tc10: capture never reported done after a full window with capture_reg still high — window_full did not retire the FSM");
    end
    `FAIL_IF_LOG(dw_capture_reg !== 1'b1,
        "tc10: test bug — capture_reg should still be high at this point");
 
    disarm();
    repeat (50) @(posedge m_axis_aclk);
 
    start_reader();
    drain_burst(beats);
    stop_reader();
 
    `FAIL_IF_LOG(beats.size() !== TOTAL_WORDS,
        $sformatf("tc10: burst had %0d beats, expected %0d",
                  beats.size(), TOTAL_WORDS));
 
    // Address 0 must still be the first sample, not a wrapped later one
    for (int ch = 0; ch < NM; ch++) begin
        `FAIL_IF_LOG(beats[ch][B-1:0] !== exp_ch(16'h4000, ch),
            $sformatf("tc10: addr=0 ch=%0d expected 0x%0h got 0x%0h — the address counter wrapped and overwrote the window start",
                      ch, exp_ch(16'h4000, ch), beats[ch][B-1:0]));
    end
 
    // And the last address must hold the last sample
    val = 16'h4000 + B'(DEPTH-1);
    for (int ch = 0; ch < NM; ch++) begin
        idx = (DEPTH-1) * NM + ch;
        `FAIL_IF_LOG(beats[idx][B-1:0] !== exp_ch(val, ch),
            $sformatf("tc10: addr=%0d ch=%0d expected 0x%0h got 0x%0h",
                      DEPTH-1, ch, exp_ch(val, ch), beats[idx][B-1:0]));
    end
 
    // Spot-check the middle so a systematic offset cannot hide
    val = 16'h4000 + B'(DEPTH/2);
    `FAIL_IF_LOG(beats[(DEPTH/2) * NM][B-1:0] !== val,
        $sformatf("tc10: addr=%0d ch=0 expected 0x%0h got 0x%0h",
                  DEPTH/2, val, beats[(DEPTH/2) * NM][B-1:0]));
`SVTEST_END
