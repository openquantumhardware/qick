// ============================================================================
// File: axis_avg_buffer_tests.sv
// Description: SVUnit test cases for the axis_avg_buffer packaged IP.
// ============================================================================

`SVTEST(test_reset_idle)
    logic [31:0] rdata;
    reg_read(ADDR_AVG_START, rdata);
    `FAIL_UNLESS_EQUAL(rdata[0], 1'b0)
    reg_read(ADDR_BUF_START, rdata);
    `FAIL_UNLESS_EQUAL(rdata[0], 1'b0)
    `FAIL_UNLESS_EQUAL(m0_if.tvalid, 1'b0)
    `FAIL_UNLESS_EQUAL(m1_if.tvalid, 1'b0)
    `FAIL_UNLESS_EQUAL(m2_if.tvalid, 1'b0)
`SVTEST_END

`SVTEST(test_register_readback)
    logic [31:0] rdata;

    reg_write(ADDR_AVG_ADDR, 32'd3);
    reg_read(ADDR_AVG_ADDR, rdata);
    `FAIL_UNLESS_EQUAL(rdata, 32'd3)

    reg_write(ADDR_AVG_LEN, 32'd5);
    reg_read(ADDR_AVG_LEN, rdata);
    `FAIL_UNLESS_EQUAL(rdata, 32'd5)

    reg_write(ADDR_BUF_ADDR, 32'd7);
    reg_read(ADDR_BUF_ADDR, rdata);
    `FAIL_UNLESS_EQUAL(rdata, 32'd7)

    reg_write(ADDR_BUF_LEN, 32'd4);
    reg_read(ADDR_BUF_LEN, rdata);
    `FAIL_UNLESS_EQUAL(rdata, 32'd4)

    reg_write(ADDR_AVG_PHOTON_MODE, 32'd1);
    reg_read(ADDR_AVG_PHOTON_MODE, rdata);
    `FAIL_UNLESS_EQUAL(rdata[0], 1'b1)

    reg_write(ADDR_AVG_H_THRSH, 32'h0000_1234);
    reg_read(ADDR_AVG_H_THRSH, rdata);
    `FAIL_UNLESS_EQUAL(rdata, 32'h0000_1234)

    reg_write(ADDR_AVG_L_THRSH, 32'h0000_0056);
    reg_read(ADDR_AVG_L_THRSH, rdata);
    `FAIL_UNLESS_EQUAL(rdata, 32'h0000_0056)
`SVTEST_END

// Arm buf via the AXI-Lite register map, pulse the shared hardware trigger,
// feed a few constant samples, then drain the raw-capture BRAM back out
// m1_axis and confirm it round-trips exactly. This is the one thing that's
// genuinely new at THIS layer (the AXI-Lite decode driving the datapath) --
// buffer/buffer_top's own testbenches already exhaustively cover the FSM.
`SVTEST(test_buf_capture_and_readback)
    logic [2*B-1:0] expected;
    int i, timeout;
    int timed_out = 0;

    expected = {16'h0000, 16'h002A}; // 42

    arm_buf(32'd0, 32'd3);
    pulse_trigger();
    drive_const_samples(3, expected);

    reg_write(ADDR_BUF_DR_ADDR, 32'd0);
    reg_write(ADDR_BUF_DR_LEN, 32'd3);
    reg_write(ADDR_BUF_DR_START, 32'h1);

    m1_if.tready = 1'b1;
    for (i = 0; i < 3 && !timed_out; i++) begin
        timeout = 0;
        while (!m1_if.tvalid && !timed_out) begin
            @(posedge axis_clk);
            timeout++;
            if (timeout > 500) timed_out = 1;
        end
        if (!timed_out) begin
            `FAIL_UNLESS_EQUAL(m1_if.tdata, expected)
            @(posedge axis_clk);
        end
    end
    `FAIL_IF_LOG(timed_out, "test_buf_capture_and_readback: timed out waiting for m1_axis data")

    reg_write(ADDR_BUF_DR_START, 32'h0);
    repeat(5) @(posedge axis_clk);
`SVTEST_END

// Confirm the shared trigger port reaches the avg datapath too (arming avg
// only, not buf) -- proves the register map correctly gates AVG_START
// independently of BUF_START. Exact accumulator arithmetic is already
// covered by avg's own 16/16 SVUnit suite; here we only need liveness.
`SVTEST(test_avg_only_arms_avg_not_buf)
    int timeout = 0;
    int timed_out = 0;

    arm_avg(32'd0, 32'd3);
    pulse_trigger();
    drive_const_samples(3, {16'h0000, 16'h000A});

    reg_write(ADDR_AVG_DR_ADDR, 32'd0);
    reg_write(ADDR_AVG_DR_LEN, 32'd1);
    reg_write(ADDR_AVG_DR_START, 32'h1);

    m0_if.tready = 1'b1;
    while (!m0_if.tvalid && !timed_out) begin
        @(posedge axis_clk);
        timeout++;
        if (timeout > 500) timed_out = 1;
    end
    `FAIL_IF_LOG(timed_out, "test_avg_only_arms_avg_not_buf: timed out waiting for m0_axis data")
    if (!timed_out) `FAIL_IF(m0_if.tdata === '0)

    reg_write(ADDR_AVG_DR_START, 32'h0);
    repeat(5) @(posedge axis_clk);

    // buf was never armed, so its m1 stream must stay idle.
    `FAIL_UNLESS_EQUAL(m1_if.tvalid, 1'b0)
`SVTEST_END

// ============================================================================
// Reading an ODD number of samples.
//
// The legacy data_reader raised tlast on the 8th beat of a 9-sample read and
// left tvalid high; the driver works around it by always reading an even
// length (readout.py, transfer_avg/transfer_buf). The reader of this IP is
// bram_to_axis, which packs tlast with the data in its FIFO, and the lower
// layers already read 1, 3 and 5 words. These tests ask the question of the
// issue at the layer the driver sees: register map in, m0/m1 stream out, for
// 9, 7 and 1 samples, with
//   - tlast on the last beat and on no other,
//   - exactly N beats and then nothing (valid must not stay high),
//   - the data of the capture, beat by beat,
//   - the reader usable again afterwards.
// ============================================================================

// Raw buffer. The source keeps running 12 samples past the end of the capture.
`SVTEST(test_buf_readout_odd_lengths)
    logic [4*B-1:0] data[];
    int k, len, early_last, extra, bad;
    bit last_ok, timed_out;

    for (k = 0; k < 3; k++) begin
        len = odd_len(k);
        reg_write(ADDR_BUF_START, 32'h0);
        repeat(4) @(posedge axis_clk);
        arm_buf(32'd0, len);
        pulse_trigger();
        drive_ramp_samples(len + 12, 16 * k);

        start_readout(1, 0, len);
        drain_beats(1, len, 0, 0, data, early_last, last_ok, extra, timed_out);
        stop_readout(1);
        bad = count_ramp_mismatches(data, 16 * k, 0, len);
        if (bad != 0) show_beats(data, 16 * k, 0, 0);

        $display("[#55] buf len=%0d: timed_out=%0d early_last=%0d last_ok=%0d extra_beats=%0d bad=%0d",
                 len, timed_out, early_last, last_ok, extra, bad);
        `FAIL_IF_LOG(timed_out, "buf odd length: timed out waiting for the beats")
        `FAIL_UNLESS_EQUAL(early_last, 0)
        `FAIL_UNLESS_EQUAL(last_ok, 1'b1)
        `FAIL_UNLESS_EQUAL(extra, 0)
        `FAIL_UNLESS_EQUAL(bad, 0)
    end
`SVTEST_END

// Averaged data: one trigger per averaged address, so a 9-sample readout needs
// 9 triggers of 2 samples each. Q is negative (sign extension of the sum).
`SVTEST(test_avg_readout_odd_lengths)
    logic [4*B-1:0] data[];
    int k, i, len, early_last, extra, bad;
    bit last_ok, timed_out;

    for (k = 0; k < 3; k++) begin
        len = odd_len(k);
        reg_write(ADDR_AVG_START, 32'h0);
        repeat(4) @(posedge axis_clk);
        arm_avg(32'd0, 32'd2);
        for (i = 0; i < len; i++) begin
            pulse_trigger();
            drive_const_samples(2, avg_in_word(16 * k, i));
            repeat(10) @(posedge axis_clk);
        end
        reg_write(ADDR_AVG_START, 32'h0);
        repeat(10) @(posedge axis_clk);

        start_readout(0, 0, len);
        drain_beats(0, len, 0, 0, data, early_last, last_ok, extra, timed_out);
        stop_readout(0);
        bad = count_avg_mismatches(data, 16 * k, len);
        if (bad != 0) show_beats(data, 16 * k, 0, 1);

        $display("[#55] avg len=%0d: timed_out=%0d early_last=%0d last_ok=%0d extra_beats=%0d bad=%0d",
                 len, timed_out, early_last, last_ok, extra, bad);
        `FAIL_IF_LOG(timed_out, "avg odd length: timed out waiting for the beats")
        `FAIL_UNLESS_EQUAL(early_last, 0)
        `FAIL_UNLESS_EQUAL(last_ok, 1'b1)
        `FAIL_UNLESS_EQUAL(extra, 0)
        `FAIL_UNLESS_EQUAL(bad, 0)
    end
`SVTEST_END

// An odd read must leave the reader ready for the next transfer, odd or even,
// from the same capture and with a start address other than 0 (the driver
// issues many transfers per capture).
`SVTEST(test_buf_odd_then_even_reads_same_capture)
    logic [4*B-1:0] data[];
    int early_last, extra, bad;
    bit last_ok, timed_out;

    arm_buf(32'd0, 32'd12);
    pulse_trigger();
    drive_ramp_samples(24, 40);

    // 9, then 8, then 3 from address 5, then 1 from address 11 (the last one
    // captured)
    start_readout(1, 0, 9);
    drain_beats(1, 9, 0, 0, data, early_last, last_ok, extra, timed_out);
    stop_readout(1);
    bad = count_ramp_mismatches(data, 40, 0, 9);
    `FAIL_IF_LOG(timed_out, "read of 9: timed out")
    `FAIL_UNLESS_EQUAL(early_last, 0)
    `FAIL_UNLESS_EQUAL(last_ok, 1'b1)
    `FAIL_UNLESS_EQUAL(extra, 0)
    `FAIL_UNLESS_EQUAL(bad, 0)

    start_readout(1, 0, 8);
    drain_beats(1, 8, 0, 0, data, early_last, last_ok, extra, timed_out);
    stop_readout(1);
    bad = count_ramp_mismatches(data, 40, 0, 8);
    `FAIL_IF_LOG(timed_out, "read of 8 after 9: timed out")
    `FAIL_UNLESS_EQUAL(early_last, 0)
    `FAIL_UNLESS_EQUAL(last_ok, 1'b1)
    `FAIL_UNLESS_EQUAL(extra, 0)
    `FAIL_UNLESS_EQUAL(bad, 0)

    start_readout(1, 5, 3);
    drain_beats(1, 3, 0, 0, data, early_last, last_ok, extra, timed_out);
    stop_readout(1);
    bad = count_ramp_mismatches(data, 40, 5, 3);
    `FAIL_IF_LOG(timed_out, "read of 3 from address 5: timed out")
    `FAIL_UNLESS_EQUAL(early_last, 0)
    `FAIL_UNLESS_EQUAL(last_ok, 1'b1)
    `FAIL_UNLESS_EQUAL(extra, 0)
    `FAIL_UNLESS_EQUAL(bad, 0)

    start_readout(1, 11, 1);
    drain_beats(1, 1, 0, 0, data, early_last, last_ok, extra, timed_out);
    stop_readout(1);
    bad = count_ramp_mismatches(data, 40, 11, 1);
    `FAIL_IF_LOG(timed_out, "read of 1 from address 11: timed out")
    `FAIL_UNLESS_EQUAL(early_last, 0)
    `FAIL_UNLESS_EQUAL(last_ok, 1'b1)
    `FAIL_UNLESS_EQUAL(extra, 0)
    `FAIL_UNLESS_EQUAL(bad, 0)
`SVTEST_END

// The DMA does not take every beat the cycle it is offered: a stall on one
// cycle in three, and a 25-cycle stall in front of the last beat with tlast on
// the bus (the case that stranded words in axis_streamer, section 26).
`SVTEST(test_buf_odd_read_with_backpressure)
    logic [4*B-1:0] data[];
    int early_last, extra, bad;
    bit last_ok, timed_out;

    arm_buf(32'd0, 32'd9);
    pulse_trigger();
    drive_ramp_samples(21, 80);

    start_readout(1, 0, 9);
    drain_beats(1, 9, 3, 25, data, early_last, last_ok, extra, timed_out);
    stop_readout(1);
    bad = count_ramp_mismatches(data, 80, 0, 9);

    `FAIL_IF_LOG(timed_out, "buf odd read with back-pressure: timed out")
    `FAIL_UNLESS_EQUAL(early_last, 0)
    `FAIL_UNLESS_EQUAL(last_ok, 1'b1)
    `FAIL_UNLESS_EQUAL(extra, 0)
    `FAIL_UNLESS_EQUAL(bad, 0)
`SVTEST_END

// openquantumhardware/qick#361: the VHDL data reader lost the sample that was on the bus when its FIFO filled (tready low for a
// while) and repeated the one after it, in both buffers. The reader is a different module now (bram_to_axis), and the existing
// back-pressure test stalls one cycle in three: it never fills the FIFO (16 words) mid-stream. Here tready is 40 cycles low and
// 24 high over a long, even read (the old qick_testbench test_issue361 used 16/16). Checked against a mutated reader whose address
// advances while the FIFO is full: both tests fail.
`SVTEST(test_buf_read_with_long_backpressure_keeps_every_sample)
    logic [4*B-1:0] data[];
    int early_last, extra, bad;
    bit last_ok, timed_out;

    arm_buf(32'd0, 32'd64);
    pulse_trigger();
    drive_ramp_samples(128, 7);

    start_readout(1, 0, 64);
    burst_low = 40; burst_high = 24;
    drain_beats(1, 64, 0, 0, data, early_last, last_ok, extra, timed_out);
    burst_low = 0; burst_high = 0;
    stop_readout(1);
    bad = count_ramp_mismatches(data, 7, 0, 64);
    if (bad != 0) show_beats(data, 7, 0, 0);

    `FAIL_IF_LOG(timed_out, "buf read with long back-pressure: timed out")
    `FAIL_UNLESS_EQUAL(early_last, 0)
    `FAIL_UNLESS_EQUAL(last_ok, 1'b1)
    `FAIL_UNLESS_EQUAL(extra, 0)
    `FAIL_UNLESS_EQUAL(bad, 0)
`SVTEST_END

`SVTEST(test_avg_read_with_long_backpressure_keeps_every_sample)
    logic [4*B-1:0] data[];
    int i, len, early_last, extra, bad;
    bit last_ok, timed_out;

    len = 48;
    arm_avg(32'd0, 32'd2);
    for (i = 0; i < len; i++) begin
        pulse_trigger();
        drive_const_samples(2, avg_in_word(0, i));
        repeat(10) @(posedge axis_clk);
    end
    reg_write(ADDR_AVG_START, 32'h0);
    repeat(10) @(posedge axis_clk);

    start_readout(0, 0, len);
    burst_low = 40; burst_high = 24;
    drain_beats(0, len, 0, 0, data, early_last, last_ok, extra, timed_out);
    burst_low = 0; burst_high = 0;
    stop_readout(0);
    bad = count_avg_mismatches(data, 0, len);
    if (bad != 0) show_beats(data, 0, 0, 1);

    `FAIL_IF_LOG(timed_out, "avg read with long back-pressure: timed out")
    `FAIL_UNLESS_EQUAL(early_last, 0)
    `FAIL_UNLESS_EQUAL(last_ok, 1'b1)
    `FAIL_UNLESS_EQUAL(extra, 0)
    `FAIL_UNLESS_EQUAL(bad, 0)
`SVTEST_END
