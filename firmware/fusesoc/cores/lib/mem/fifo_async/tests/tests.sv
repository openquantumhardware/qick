// ============================================================================
// File: tests.sv
// Project: QICK
// Description: SVUnit test cases for fifo_async.
//
// Included inside fifo_async_unit_test between SVUNIT_TESTS_BEGIN/END, so:
//   - every constant lives in the MODULE, never here (a localparam real inside
//     an SVTEST silently reads back as 0 under xsim);
//   - only variables are declared inside a test;
//   - data checking is done by the monitors, not by the tests. A test drives
//     traffic and then calls sb_check(). If a test needs to prove a specific
//     timing relationship, it does that explicitly (see test05/test06).
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 00: reset state
// ----------------------------------------------------------------------------
`SVTEST(test00_reset_state)
    repeat (CDC_WAIT) @(posedge rd_clk);
    `FAIL_UNLESS_LOG(empty === 1'b1, "empty should be 1 after reset")
    `FAIL_UNLESS_LOG(full  === 1'b0, "full should be 0 once reset has settled")
    `FAIL_UNLESS_LOG(data_valid === 1'b0, "data_valid should be 0 on an empty FIFO")
    `FAIL_IF_LOG($isunknown({empty, full, data_valid}), "flags are X after reset")
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 01: basic flow — write a burst, read it back one word at a time
// ----------------------------------------------------------------------------
`SVTEST(test01_basic_flow)
    int           n;
    bit           ok;
    logic [B-1:0] d;

    // Stay well below the depth so nothing is dropped.
    n = (N < 64) ? (N / 2) : 50;

    for (int i = 0; i < n; i++) begin
        write_word($urandom, ok);
        `FAIL_UNLESS_LOG(ok, $sformatf("write %0d rejected, full asserted early", i))
    end

    for (int i = 0; i < n; i++) begin
        read_word(d, ok);
        `FAIL_UNLESS_LOG(ok, $sformatf("timeout reading word %0d", i))
    end

    repeat (CDC_WAIT) @(posedge rd_clk);
    `FAIL_UNLESS_LOG(empty === 1'b1, "FIFO should be empty after reading everything")
    sb_check("test01");
    `FAIL_UNLESS_LOG(sb_words == n,
                     $sformatf("test01: wrote %0d words, read back %0d", n, sb_words))
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 02: random stress — independent producer / consumer, ~50% duty cycle
//          At small N this deliberately overflows and underflows; the FIFO
//          must drop the excess without ever corrupting the order.
// ----------------------------------------------------------------------------
`SVTEST(test02_random_stress)
    fork
        begin : producer
            repeat (2000) begin
                wr_en <= (($urandom_range(0, 1)) != 0);
                din   <= $urandom;
                @(posedge wr_clk);
            end
            wr_en <= 1'b0;
            @(posedge wr_clk);
        end

        begin : consumer
            repeat (2000) begin
                rd_en <= (($urandom_range(0, 1)) != 0);
                @(posedge rd_clk);
            end
            rd_en <= 1'b0;
            @(posedge rd_clk);
        end
    join

    drain_all();
    sb_check("test02");
    $display("[TEST02] compared %0d words (%0d accepted on the write side)",
             sb_words, sb_wr);
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 03: full condition — fill the FIFO and measure the usable depth
//          XPM doc: usable depth is N-1 in std mode and N+1 in fwft mode.
//          If this fails, it is NOT necessarily a bug: it is the real number,
//          write it down, it is what sizes the buffer in streamer.
// ----------------------------------------------------------------------------
`SVTEST(test03_full_condition)
    int accepted;

    write_burst(N + 32, accepted);

    `FAIL_UNLESS_LOG(full === 1'b1, "full never asserted while overfilling")
    $display("[TEST03] usable depth measured = %0d (expected %0d for %0s)",
             accepted, EFF_DEPTH, RD_MODE);
    `FAIL_UNLESS_LOG(accepted == EFF_DEPTH,
                     $sformatf("usable depth is %0d, XPM doc says %0d for READ_MODE=%0s",
                               accepted, EFF_DEPTH, RD_MODE))

    drain_all();
    `FAIL_UNLESS_LOG(empty === 1'b1, "FIFO not empty after draining")
    `FAIL_UNLESS_LOG(full  === 1'b0, "full still asserted after draining")
    sb_check("test03");
    `FAIL_UNLESS_LOG(sb_words == accepted,
                     $sformatf("accepted %0d words, %0d came out", accepted, sb_words))
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 04: interleaved single-word transactions
//          Exercises the empty -> not-empty CDC path on every transaction.
// ----------------------------------------------------------------------------
`SVTEST(test04_interleaved)
    bit           ok;
    logic [B-1:0] d;

    for (int i = 0; i < 20; i++) begin
        write_word($urandom, ok);
        `FAIL_UNLESS_LOG(ok, $sformatf("write %0d rejected", i))
        read_word(d, ok);
        `FAIL_UNLESS_LOG(ok, $sformatf("timeout reading word %0d", i))
    end

    repeat (CDC_WAIT) @(posedge rd_clk);
    `FAIL_UNLESS_LOG(empty === 1'b1, "FIFO should be empty")
    sb_check("test04");
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 05: read contract — the exact timing streamer.sv depends on
//
//   fwft : dout holds the head word WITHOUT any rd_en, and stays stable until
//          a pop. This is what makes `last_dout <= fifo_dout` legal on the same
//          cycle as fifo_rd_en.
//   std  : dout is meaningless on the pop cycle and becomes valid exactly one
//          cycle later, together with data_valid.
// ----------------------------------------------------------------------------
`SVTEST(test05_read_contract)
    bit           ok;
    logic [B-1:0] golden;
    logic [B-1:0] d;
    logic [B-1:0] first_seen;

    golden = 32'hA5A5_1234;

    write_word(golden[B-1:0], ok);
    `FAIL_UNLESS_LOG(ok, "seed write rejected")

    wait_not_empty(ok);
    `FAIL_UNLESS_LOG(ok, "empty never deasserted after a single write")

    if (FWFT_MODE) begin
        // (a) the word must already be on dout, with rd_en still low
        `FAIL_UNLESS_LOG(rd_en === 1'b0, "TB error: rd_en should be idle here")
        first_seen = dout;
        `FAIL_UNLESS_LOG(first_seen === golden[B-1:0],
            $sformatf("fwft: dout should show 0x%0h before any rd_en, got 0x%0h",
                      golden[B-1:0], first_seen))

        // (b) data_valid must track ~empty in fwft
        `FAIL_UNLESS_LOG(data_valid === 1'b1,
                         "fwft: data_valid should be 1 whenever the FIFO is not empty")

        // (c) dout must stay stable while no pop is issued
        repeat (8) begin
            @(posedge rd_clk);
            `FAIL_UNLESS_LOG(dout === first_seen, "fwft: dout moved without a pop")
            `FAIL_UNLESS_LOG(empty === 1'b0, "fwft: empty rose without a pop")
        end

        // (d) the pop empties the FIFO
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        repeat (CDC_WAIT) @(posedge rd_clk);
        `FAIL_UNLESS_LOG(empty === 1'b1, "fwft: FIFO not empty after popping the only word")
    end
    else begin
        // (a) nothing valid before the pop
        `FAIL_UNLESS_LOG(data_valid === 1'b0,
                         "std: data_valid should be 0 before any rd_en")

        // (b) pop, then data_valid exactly one cycle later
        rd_en <= 1'b1;
        @(posedge rd_clk);              // DUT consumes here
        rd_en <= 1'b0;
        `FAIL_UNLESS_LOG(data_valid === 1'b0,
                         "std: data_valid must not be high on the pop cycle itself")

        @(posedge rd_clk);              // latency = 1
        `FAIL_UNLESS_LOG(data_valid === 1'b1,
                         "std: data_valid did not arrive exactly 1 cycle after the pop")
        d = dout;
        `FAIL_UNLESS_LOG(d === golden[B-1:0],
            $sformatf("std: expected 0x%0h got 0x%0h", golden[B-1:0], d))

        repeat (CDC_WAIT) @(posedge rd_clk);
        `FAIL_UNLESS_LOG(empty === 1'b1, "std: FIFO not empty after popping the only word")
    end

    sb_check("test05");
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 06: overflow — writing while full must set wr_err and must NOT corrupt
//          or reorder what is already stored.
// ----------------------------------------------------------------------------
`SVTEST(test06_overflow_wr_err)
    int accepted;
    int extra;
    bit ok;
    bit saw_wr_err;

    write_burst(N + 8, accepted);
    `FAIL_UNLESS_LOG(full === 1'b1, "full never asserted")

    // Keep hammering while full and watch wr_err.
    saw_wr_err = 1'b0;
    extra      = 0;
    for (int i = 0; i < 8; i++) begin
        write_attempt($urandom, ok);
        if (wr_err === 1'b1) saw_wr_err = 1'b1;
        if (ok) extra++;
    end
    `FAIL_UNLESS_LOG(extra == 0, $sformatf("%0d writes were accepted while full", extra))
    `FAIL_UNLESS_LOG(saw_wr_err, "wr_err never asserted on an overflow")

    drain_all();
    sb_check("test06");
    `FAIL_UNLESS_LOG(sb_words == accepted,
        $sformatf("overflow corrupted the stream: accepted %0d, read %0d",
                  accepted, sb_words))
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 07: asymmetric reset — pulsing ONLY rd_rstn
//
//   fifo_async builds the XPM reset as (~wr_rstn | ~rd_rstn), so a read-domain
//   reset flushes the WHOLE FIFO, write side included. That is different from
//   the old fifo_dc_axi, which ignored rd_rstn entirely. This test pins the new
//   semantics down so the change is deliberate and documented.
// ----------------------------------------------------------------------------
`SVTEST(test07_reset_rd_domain_only)
    int accepted;
    bit ok;

    write_burst(8, accepted);
    `FAIL_UNLESS_LOG(accepted == 8, "seed burst was not accepted")

    // Reset only the read domain.
    mon_en  = 1'b0;
    rd_rstn = 1'b0;
    repeat (8) @(posedge rd_clk);
    rd_rstn = 1'b1;
    repeat (CDC_WAIT) @(posedge rd_clk);
    repeat (CDC_WAIT) @(posedge wr_clk);
    sb_clear();
    mon_en = 1'b1;

    `FAIL_UNLESS_LOG(empty === 1'b1,
        "a read-domain reset must flush the FIFO (documented new behaviour)")
    `FAIL_UNLESS_LOG(full === 1'b0, "full still asserted after a read-domain reset")

    // And the FIFO must be usable again straight away.
    for (int i = 0; i < 8; i++) begin
        write_word($urandom, ok);
        `FAIL_UNLESS_LOG(ok, $sformatf("post-reset write %0d rejected", i))
    end
    drain_all();
    sb_check("test07");
    `FAIL_UNLESS_LOG(sb_words == 8,
                     $sformatf("expected 8 words after reset, got %0d", sb_words))
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 08: reset in the middle of live traffic
// ----------------------------------------------------------------------------
`SVTEST(test08_reset_during_traffic)
    bit ok;

    fork
        begin : traffic
            repeat (200) begin
                wr_en <= 1'b1;
                din   <= $urandom;
                @(posedge wr_clk);
            end
            wr_en <= 1'b0;
        end
        begin : reader
            repeat (100) begin
                rd_en <= (empty !== 1'b1);
                @(posedge rd_clk);
            end
            rd_en <= 1'b0;
        end
    join_any
    disable fork;                  // stop the surviving driver BEFORE resetting

    // Yank both resets mid-flight.
    apply_reset();

    `FAIL_UNLESS_LOG(empty === 1'b1, "FIFO not empty after a mid-traffic reset")
    `FAIL_IF_LOG($isunknown({empty, full, data_valid}), "flags are X after reset")

    // Prove the FIFO still works afterwards.
    for (int i = 0; i < 16; i++) begin
        write_word($urandom, ok);
        `FAIL_UNLESS_LOG(ok, $sformatf("post-reset write %0d rejected", i))
    end
    drain_all();
    sb_check("test08");
    `FAIL_UNLESS_LOG(sb_words == 16,
                     $sformatf("expected 16 words after reset, got %0d", sb_words))
`SVTEST_END


// ----------------------------------------------------------------------------
// TEST 09: writes issued immediately after reset release
//
//   THE CONTRACT UNDER TEST: if full is low and I write, the word must come out.
//   Nothing else is visible to an AXI master, and streamer.sv drives
//   s_axis_tready = ~fifo_full straight from this flag.
//
//   XPM holds wr_rst_busy high for several cycles AFTER rst deasserts and drops
//   every write in that window, while full still reads 0. This test therefore
//   FAILS until fifo_async ORs wr_rst_busy into full. That failure is the point:
//   it documents the hole instead of hiding it behind a dut.wr_rst_busy peek.
// ----------------------------------------------------------------------------
`SVTEST(test09_write_right_after_reset)
    int accepted;

    apply_reset_fast();          // no settling time on purpose

    // Long enough that some beats necessarily land after wr_rst_busy clears:
    // the busy window spans a full reset CDC round trip, which at 100 MHz on
    // the read side is tens of write-clock cycles.
    write_burst(128, accepted);
    drain_all();

    $display("[TEST09] %0d of 128 beats saw full=0, %0d came out, %0d lost",
             accepted, sb_words, exp_q.size());

    `FAIL_IF_LOG(sb_errors != 0,
                 $sformatf("test09: %0d data mismatches", sb_errors))
    `FAIL_IF_LOG(accepted == 0,
                 "test09: full never released, cannot tell anything")
    `FAIL_UNLESS_LOG(sb_words == accepted,
        $sformatf({"test09: %0d beats were accepted with full=0 but only %0d came out. ",
                   "Writes are dropped while wr_rst_busy is high and full reads 0: ",
                   "OR wr_rst_busy into full inside fifo_async."},
                  accepted, sb_words))
`SVTEST_END