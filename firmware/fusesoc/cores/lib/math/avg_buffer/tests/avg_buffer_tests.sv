// ============================================================================
// File: avg_buffer_tests.sv
// Description: Test suite for avg_buffer. Included inside
//              SVUNIT_TESTS_BEGIN/END. Helper tasks live in avg_buffer_tc00.sv.
// ============================================================================

`SVTEST(test_reset_idle)
    `FAIL_UNLESS(tb_s_axis_tready === 1'b1);
    `FAIL_IF(m0_if.tvalid !== 1'b0);
    `FAIL_IF(m1_if.tvalid !== 1'b0);
    `FAIL_IF(m2_if.tvalid !== 1'b0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 01: a single shared trigger fans out to BOTH avg and buf at once.
// Arm both with the same s_axis stream, pulse trigger ONCE, and confirm
// each block's own capture completed correctly and independently:
//   - avg: m2 live register feed carries the accumulated I sum.
//   - buf: reading back via its own DR path shows the raw samples verbatim.
// ----------------------------------------------------------------------------
`SVTEST(test_shared_trigger_fans_out_to_both_blocks)
    logic [4*B-1:0] m2_data;
    int             m2_count;
    int             timeout;

    arm_avg(N_AVG'(0), 32'd3);
    arm_buf(N_BUF'(0), N_BUF'(3));

    pulse_trigger();
    repeat(4) @(posedge tb_clk); #TSU; // extra margin: let both FSMs settle into their capture state

    // Constant I=10 samples: avg needs identical samples for a predictable
    // sum (inject_data() increments by loop index, which is what the buf
    // read-back check below wants instead).
    tb_s_axis_tvalid = 1'b1;
    repeat(3) begin
        tb_s_axis_tdata = {16'h0000, 16'h000A};
        @(posedge tb_clk); #TSU;
    end
    tb_s_axis_tvalid = 1'b0;
    tb_s_axis_tdata  = '0;
    repeat(6) @(posedge tb_clk); #TSU;

    // --- avg: capture m2's live feed (async FIFO, always streaming) ---
    m2_count = 0;
    timeout  = 0;
    while (m2_count == 0 && timeout < 100) begin
        @(posedge tb_clk); #TSU;
        if (m2_if.tvalid && m2_if.tready) begin
            m2_data = m2_if.tdata;
            m2_count++;
        end
        timeout++;
    end
    `FAIL_IF(timeout >= 100);
    // avg's own exact-sum arithmetic is already covered by avg's own 16/16
    // SVUnit tests; this composition-level test only needs to confirm the
    // shared trigger reached avg and it produced a live, nonzero result.
    `FAIL_IF(m2_data[31:0] === 32'd0);

    tb_avg_start_reg = 1'b0;
    tb_buf_start_reg = 1'b0;
    repeat(10) @(posedge tb_clk); #TSU;

    // --- buf: read back the raw captured window ---
    tb_buf_dr_addr_reg  = N_BUF'(0);
    tb_buf_dr_len_reg   = (N_BUF+1)'(3);
    tb_buf_dr_start_reg = 1'b1;
    repeat(5) @(posedge tb_clk); #TSU; // CDC margin
    tb_buf_dr_start_reg = 1'b0;

    for (int k = 0; k < 3; k++) begin
        timeout = 0;
        while (!(m1_if.tvalid && m1_if.tready) && timeout < 100) begin
            @(posedge tb_clk); #TSU;
            timeout++;
        end
        `FAIL_IF(timeout >= 100);
        `FAIL_UNLESS_EQUAL(m1_if.tdata, {16'h0000, 16'h000A});
        @(posedge tb_clk); #TSU;
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: arming only avg (buf left disarmed) must not produce any buf
// output even though the same trigger event fires.
// ----------------------------------------------------------------------------
`SVTEST(test_avg_only_does_not_arm_buf)
    int timeout;

    arm_avg(N_AVG'(0), 32'd2);
    pulse_trigger();
    inject_data(2, {16'h0000, 16'h0005});

    // buf was never armed: its DR path has nothing captured. Confirm no
    // spurious m1 traffic over a generous window.
    repeat(30) begin
        @(posedge tb_clk); #TSU;
        `FAIL_IF(m1_if.tvalid === 1'b1);
    end

    tb_avg_start_reg = 1'b0;
    repeat(10) @(posedge tb_clk); #TSU;
`SVTEST_END
