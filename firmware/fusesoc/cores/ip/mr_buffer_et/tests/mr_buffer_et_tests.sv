// ============================================================================
// File: mr_buffer_et_tests.sv
// Description: SVUnit test cases for mr_buffer_et.
// Included by mr_buffer_et_tc00.sv inside `SVUNIT_TESTS_BEGIN/END.
//
// Every read burst is consumed with burst_rx(), which holds tready high and
// returns the whole packet up to tlast.  Two invariants are therefore checked
// on every burst and never silently skipped:
//   - beats.size() == TOTAL_WORDS   (tlast landed on the right beat)
//   - beats[0] is ch0 @ addr 0      (word ordering)
// A burst that never produces tlast is caught by the $fatal inside burst_rx.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 00: Register readback — registers initialise to 0 and a write-then-read
// round-trip works for dw_capture_reg and dr_start_reg.
// ----------------------------------------------------------------------------
`SVTEST(tc00_register_readback)
    logic [C_S_AXI_DW-1:0] rdata;

    read_reg(REG_DW_CAPTURE, rdata);
    `FAIL_IF_LOG(rdata !== '0,
        $sformatf("tc00: REG_DW_CAPTURE after reset expected 0, got 0x%0h", rdata));

    read_reg(REG_DR_START, rdata);
    `FAIL_IF_LOG(rdata !== '0,
        $sformatf("tc00: REG_DR_START after reset expected 0, got 0x%0h", rdata));

    set_capture(1'b1);
    read_reg(REG_DW_CAPTURE, rdata);
    `FAIL_IF_LOG(rdata[0] !== 1'b1,
        $sformatf("tc00: REG_DW_CAPTURE[0] after write expected 1, got 0x%0h", rdata));

    set_capture(1'b0);
    read_reg(REG_DW_CAPTURE, rdata);
    `FAIL_IF_LOG(rdata[0] !== 1'b0,
        $sformatf("tc00: REG_DW_CAPTURE[0] after clear expected 0, got 0x%0h", rdata));

    set_start(1'b1);
    read_reg(REG_DR_START, rdata);
    `FAIL_IF_LOG(rdata[0] !== 1'b1,
        $sformatf("tc00: REG_DR_START[0] after write expected 1, got 0x%0h", rdata));
    set_start(1'b0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 01: Basic write/read — one beat captured, every channel of address 0
// verified through the full read burst.
// ----------------------------------------------------------------------------
`SVTEST(tc01_basic_write_read)
    logic [M_DATA_W-1:0] beats [$];

    do_capture(16'hAAAA);

    start_reader();
    drain_burst(beats);
    stop_reader();

    `FAIL_IF_LOG(beats.size() !== TOTAL_WORDS,
        $sformatf("tc01: burst had %0d beats, expected %0d (tlast position)",
                  beats.size(), TOTAL_WORDS));

    // Address 0 holds the captured beat on all NM channels
    for (int ch = 0; ch < NM; ch++) begin
        `FAIL_IF_LOG(beats[ch][B-1:0] !== exp_ch(16'hAAAA, ch),
            $sformatf("tc01: addr=0 ch=%0d expected 0x%0h got 0x%0h",
                      ch, exp_ch(16'hAAAA, ch), beats[ch][B-1:0]));
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Multiple beats — 8 beats with distinct ch0 values land at 8
// consecutive BRAM addresses, and every channel of every address is verified.
// ----------------------------------------------------------------------------
`SVTEST(tc02_multiple_beats)
    localparam int BEATS = 8;
    logic [B-1:0]        expected [BEATS];
    logic [M_DATA_W-1:0] beats [$];
    int                  idx;

    for (int i = 0; i < BEATS; i++)
        expected[i] = 16'hAAAA + B'(i);

    arm_and_trigger();
    for (int i = 0; i < BEATS; i++)
        send_beat(expected[i], (i == BEATS-1) ? 1'b1 : 1'b0);

    // Let the internal FIFO drain into the BRAM before disarming
    repeat (20) @(posedge s_axis_aclk);
    disarm();
    repeat (50) @(posedge m_axis_aclk);   // CDC margin

    start_reader();
    drain_burst(beats);
    stop_reader();

    `FAIL_IF_LOG(beats.size() !== TOTAL_WORDS,
        $sformatf("tc02: burst had %0d beats, expected %0d (tlast position)",
                  beats.size(), TOTAL_WORDS));

    // Word order: ch0@addr0 .. ch(NM-1)@addr0, ch0@addr1, ...
    for (int addr = 0; addr < BEATS; addr++) begin
        for (int ch = 0; ch < NM; ch++) begin
            idx = addr * NM + ch;
            `FAIL_IF_LOG(beats[idx][B-1:0] !== exp_ch(expected[addr], ch),
                $sformatf("tc02: addr=%0d ch=%0d (beat %0d) expected 0x%0h got 0x%0h",
                          addr, ch, idx, exp_ch(expected[addr], ch), beats[idx][B-1:0]));
        end
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Re-arm — a second capture overwrites address 0, and the second read
// burst must not return anything left over from the first one.
// ----------------------------------------------------------------------------
`SVTEST(tc03_rearm_second_capture)
    logic [M_DATA_W-1:0] beats [$];

    do_capture(16'hAAAA);
    start_reader();
    drain_burst(beats);
    stop_reader();

    `FAIL_IF_LOG(beats.size() !== TOTAL_WORDS,
        $sformatf("tc03 first: burst had %0d beats, expected %0d — a short burst leaves stale beats in the reader FIFO",
                  beats.size(), TOTAL_WORDS));
    `FAIL_IF_LOG(beats[0][B-1:0] !== 16'hAAAA,
        $sformatf("tc03 first: expected 0xAAAA, got 0x%0h", beats[0][B-1:0]));

    do_capture(16'hBBBB);
    start_reader();
    drain_burst(beats);
    stop_reader();

    `FAIL_IF_LOG(beats.size() !== TOTAL_WORDS,
        $sformatf("tc03 second: burst had %0d beats, expected %0d",
                  beats.size(), TOTAL_WORDS));
    `FAIL_IF_LOG(beats[0][B-1:0] !== 16'hBBBB,
        $sformatf("tc03 second: expected 0xBBBB, got 0x%0h — stale data from the previous burst", beats[0][B-1:0]));
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: Trigger before arm — a stale trigger must not start a capture.
// ----------------------------------------------------------------------------
`SVTEST(tc04_trigger_before_arm_ignored)
    // Stale trigger while capture_reg is still 0
    @(posedge s_axis_aclk);
    trigger <= 1'b1;
    @(posedge s_axis_aclk);
    trigger <= 1'b0;
    repeat (3) @(posedge s_axis_aclk);

    // Arm: the FSM must sit in TRIGGER_ST waiting for a fresh trigger
    set_capture(1'b1);
    wait_wr_state(WR_TRIGGER_ST);
    repeat (8) @(posedge s_axis_aclk);

    `FAIL_IF_LOG(s_axis_if.tready !== 1'b0,
        "tc04: tready should be low while waiting for a fresh trigger");
    `FAIL_IF_LOG(dut.mr_buffer_i.gen_channel[0].u_axis_to_bram_trig.current_state
                 !== WR_TRIGGER_ST,
        "tc04: capture FSM left TRIGGER_ST without a fresh trigger");

    disarm();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: tready_force via debug_reg[1] — forces s_axis_tready high with no
// capture active, and releases it again.
// ----------------------------------------------------------------------------
`SVTEST(tc05_tready_force_via_axi)
    set_debug(32'h0000_0002);
    repeat (5) @(posedge s_axis_aclk);
    `FAIL_IF_LOG(s_axis_if.tready !== 1'b1,
        "tc05: tready should be forced high by debug_reg[1]");

    set_debug(32'h0000_0000);
    repeat (5) @(posedge s_axis_aclk);
    `FAIL_IF_LOG(s_axis_if.tready !== 1'b0,
        "tc05: tready should return low after clearing debug_reg[1]");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: tlast position — tlast lands exactly on beat TOTAL_WORDS-1 and
// nowhere else.  burst_rx stops at the first tlast, so an exact-length queue
// proves there was no early tlast; a concurrent monitor covers the "extra
// tlast after the burst" case.
// ----------------------------------------------------------------------------
`SVTEST(tc06_tlast_on_last_word)
    logic [M_DATA_W-1:0] beats [$];

    do_capture(16'hCCCC);

    start_reader();
    drain_burst(beats);

    `FAIL_IF_LOG(beats.size() !== TOTAL_WORDS,
        $sformatf("tc06: tlast at beat %0d, expected %0d",
                  beats.size()-1, TOTAL_WORDS-1));

    // After the burst the master must go quiet until the next start
    repeat (20) @(posedge m_axis_aclk);
    `FAIL_IF_LOG(m_axis_if.tvalid !== 1'b0,
        "tc06: tvalid still asserted after the burst completed");

    stop_reader();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: Two back-to-back bursts from a single capture — the same window can
// be re-read without re-arming, and the second burst is identical to the first.
// This is the direct simulation analogue of the DMA re-read on hardware.
// ----------------------------------------------------------------------------
`SVTEST(tc07_two_bursts_same_capture)
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
        $sformatf("tc07: burst sizes %0d and %0d, expected %0d each",
                  first.size(), second.size(), TOTAL_WORDS));

    for (int i = 0; i < TOTAL_WORDS; i++) begin
        `FAIL_IF_LOG(first[i] !== second[i],
            $sformatf("tc07: beat %0d differs between bursts: 0x%0h vs 0x%0h",
                      i, first[i], second[i]));
    end
`SVTEST_END