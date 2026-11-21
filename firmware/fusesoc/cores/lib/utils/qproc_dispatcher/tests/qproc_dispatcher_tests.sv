// ============================================================================
// File: qproc_dispatcher_tests.sv
// Description: SVUnit test cases for qproc_dispatcher. Included by
//              qproc_dispatcher_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    `FAIL_IF(tb_all_fifo_full);
    `FAIL_IF(tb_some_fifo_full);
    `FAIL_IF(tb_port_trig_o[0]);
    `FAIL_IF(tb_port_tvalid_o[0]);
    `FAIL_IF(tb_m_axis_tvalid[0]);
`SVTEST_END

`SVTEST(tc_trigger_dispatch_fires_when_due)
    PORT_DT ev;
    ev = '{p_time: 32'd0, p_type: 1'b1, p_addr: 6'b10_0000, p_data: 168'd1}; // trigger ch0, value=1

    tb_core_en = 1'b1;
    tb_time_en = 1'b1;
    tb_time_abs_i = 48'd100; // already past any p_time=0 event

    push_event(ev);
    wait_until(tb_port_trig_o[0]);
    `FAIL_UNLESS(tb_port_trig_o[0]);
`SVTEST_END

`SVTEST(tc_data_dispatch_fires)
    PORT_DT ev;
    ev = '{p_time: 32'd0, p_type: 1'b1, p_addr: 6'b00_0000, p_data: 168'hA}; // data ch0, low nibble = 0xA

    tb_core_en = 1'b1;
    tb_time_en = 1'b1;
    tb_time_abs_i = 48'd100;

    push_event(ev);
    wait_until(tb_port_tvalid_o[0]);
    `FAIL_UNLESS(tb_port_tvalid_o[0]);
    `FAIL_UNLESS(tb_port_tdata_o[0] === 4'hA);
`SVTEST_END

`SVTEST(tc_wave_dispatch_waits_for_tready)
    PORT_DT ev;
    ev = '{p_time: 32'd0, p_type: 1'b0, p_addr: 6'd0, p_data: 168'h1122_3344_5566_7788_99AA_BBCC_DDEE_FF00_11};

    tb_core_en = 1'b1;
    tb_time_en = 1'b1;
    tb_time_abs_i = 48'd100;
    tb_m_axis_tready[0] = 1'b0;

    push_event(ev);
    // Give it plenty of time to (incorrectly) fire while tready is low.
    repeat(30) @(posedge tb_clk);
    `FAIL_IF(tb_m_axis_tvalid[0]);

    tb_m_axis_tready[0] = 1'b1;
    wait_until(tb_m_axis_tvalid[0]);
    `FAIL_UNLESS(tb_m_axis_tvalid[0]);
    `FAIL_UNLESS(tb_m_axis_tdata[0] === 168'h1122_3344_5566_7788_99AA_BBCC_DDEE_FF00_11);
`SVTEST_END

`SVTEST(tc_trigger_fifo_reports_full_when_filled)
    PORT_DT ev;
    // Never enable time_en, so nothing ever pops -- fill the 16-entry FIFO
    // (FIFO_DEPTH=4) with core_en held high.
    ev = '{p_time: 32'd0, p_type: 1'b1, p_addr: 6'b10_0000, p_data: 168'd1};

    tb_core_en = 1'b1;
    tb_time_en = 1'b0;

    for (int i = 0; i < 24; i++) begin
        push_event(ev);
    end
    wait_until(tb_some_fifo_full);
    `FAIL_UNLESS(tb_some_fifo_full);
`SVTEST_END

`SVTEST(tc_core_rst_flushes_trigger_fifo)
    PORT_DT ev;
    bit reached;
    ev = '{p_time: 32'd0, p_type: 1'b1, p_addr: 6'b10_0000, p_data: 168'd1};

    tb_core_en = 1'b1;
    tb_time_en = 1'b0; // don't drain, so the FIFO stays full after filling

    for (int i = 0; i < 24; i++) begin
        push_event(ev);
    end
    wait_until(tb_some_fifo_full);
    `FAIL_UNLESS(tb_some_fifo_full);

    // core_rst folds into the FIFO's wr_rstn (see the module header) and
    // should clear it back to not-full. XPM_FIFO_ASYNC's wr_rst_busy stays
    // high for a while after rst deasserts (see reset_dut()), so give the
    // same generous margin here.
    @(negedge tb_clk);
    tb_core_rst = 1'b1;
    repeat(4) @(posedge tb_clk);
    tb_core_rst = 1'b0;
    repeat(100) @(posedge tb_clk);
    `FAIL_IF(tb_some_fifo_full);
`SVTEST_END

`SVTEST(tc_out_of_range_addr_is_dropped)
    // A port address past the configured channel count (here 2 per kind) must
    // not dispatch anywhere: not to a real channel by aliasing, and not stuck
    // in a FIFO. Only the in-range event pushed afterwards may fire.
    PORT_DT ev;

    tb_core_en = 1'b1;
    tb_time_en = 1'b1;
    tb_time_abs_i = 48'd100;

    ev = '{p_time: 32'd0, p_type: 1'b1, p_addr: 6'b10_0010, p_data: 168'd1}; // trigger ch2
    push_event(ev);
    ev = '{p_time: 32'd0, p_type: 1'b1, p_addr: 6'b00_0011, p_data: 168'hF}; // data ch3
    push_event(ev);
    ev = '{p_time: 32'd0, p_type: 1'b0, p_addr: 6'd5,       p_data: 168'h5}; // wave ch5
    push_event(ev);

    repeat(40) @(posedge tb_clk);
    `FAIL_IF(tb_port_trig_o[0] || tb_port_trig_o[1]);
    `FAIL_IF(tb_port_tvalid_o[0] || tb_port_tvalid_o[1]);
    `FAIL_IF(tb_m_axis_tvalid[0] || tb_m_axis_tvalid[1]);
    `FAIL_IF(tb_some_fifo_full);

    ev = '{p_time: 32'd0, p_type: 1'b1, p_addr: 6'b10_0001, p_data: 168'd1}; // trigger ch1
    push_event(ev);
    wait_until(tb_port_trig_o[1]);
    `FAIL_UNLESS(tb_port_trig_o[1]);
    `FAIL_IF(tb_port_trig_o[0]);
`SVTEST_END

// ---- the due time is compared on all 48 bits ----------------------------------------------------------------------------------
// The time of an event is p_time (32 bit, sign-extended) + c_time_ref_dt (48 bit), and the event is due when time_abs is greater
// than it. The tests above keep both the reference and time_abs below 2**8, so they do not tell a comparator or an adder that stops
// at 32 bits from a correct one. The old qick_testbench (test_tproc_basic) forced the reference to 2**M, M = 15..47, and watched
// trig_0_o. Here the reference sits just under 2**M and the event just over it, so that the sum carries into bit M and the
// low 32 bits of time_abs are ABOVE those of the event while the full value is below it: a comparator that looks at 32 bits
// fires early, one that drops the carry never fires.

// Not due 1 below the event, due 1 above: event = 2**M + 10 for M = 15, 31, 32, 40, 47.
`SVTEST(tc_trigger_waits_for_time_across_an_upper_bit)
    PORT_DT ev, ev_clear;
    int     ms[5] = '{15, 31, 32, 40, 47};
    bit     fired;

    // The trigger pin is a level that keeps the value of the last trigger event: each round ends by clearing it, so that the
    // next round starts from 0 and a 1 can only come from its own event.
    ev       = '{p_time: 32'd20, p_type: 1'b1, p_addr: 6'b10_0000, p_data: 168'd1};   // trigger ch0 = 1, 20 after the reference
    ev_clear = '{p_time: 32'd0,  p_type: 1'b1, p_addr: 6'b10_0000, p_data: 168'd0};   // trigger ch0 = 0, at the reference
    tb_core_en = 1'b1;
    tb_time_en = 1'b1;

    foreach (ms[i]) begin
        tb_c_time_ref_dt = (48'd1 << ms[i]) - 48'd10;        // event at 2**M + 10
        tb_time_abs_i    = (48'd1 << ms[i]) - 48'd1;         // 11 before it, all low bits set
        push_event(ev);
        fired = 1'b0;
        repeat (40) begin
            @(posedge tb_clk);
            fired |= tb_port_trig_o[0];
        end
        `FAIL_IF(fired);                                     // not early, at M = ms[i]
        tb_time_abs_i    = (48'd1 << ms[i]) + 48'd11;        // 1 after
        wait_until(tb_port_trig_o[0]);
        `FAIL_UNLESS(tb_port_trig_o[0]);                     // and not lost
        push_event(ev_clear);                                // due already: time_abs is past the reference
        for (int n = 0; n < 60 && tb_port_trig_o[0]; n++) @(posedge tb_clk);
        `FAIL_IF(tb_port_trig_o[0]);
    end
`SVTEST_END

// A negative p_time is before the reference: the sign extension is added to all 48 bits of it (reference = 2**32 + 5, event
// = 2**32 - 5: the sum borrows from bit 32).
`SVTEST(tc_negative_p_time_borrows_from_an_upper_bit)
    PORT_DT ev;
    bit     fired;

    ev = '{p_time: -32'sd10, p_type: 1'b1, p_addr: 6'b10_0000, p_data: 168'd1}; // 10 before the reference
    tb_core_en = 1'b1;
    tb_time_en = 1'b1;
    tb_c_time_ref_dt = (48'd1 << 32) + 48'd5;
    tb_time_abs_i    = (48'd1 << 32) - 48'd6;                // 1 before the event (low 32 bits 0xFFFFFFFA)

    push_event(ev);
    fired = 1'b0;
    repeat (40) begin
        @(posedge tb_clk);
        fired |= tb_port_trig_o[0];
    end
    `FAIL_IF(fired);
    tb_time_abs_i    = (48'd1 << 32) - 48'd4;                // 1 after
    wait_until(tb_port_trig_o[0]);
    `FAIL_UNLESS(tb_port_trig_o[0]);
`SVTEST_END

// Same for a wave word (its own FIFO and comparator), across the top bit of the counter: event = 2**47 + 2.
`SVTEST(tc_wave_waits_for_time_across_the_top_bit)
    PORT_DT ev;
    bit     fired;

    ev = '{p_time: 32'd5, p_type: 1'b0, p_addr: 6'd0, p_data: 168'h1122_3344_5566_7788_99AA_BBCC_DDEE_FF00_11};
    tb_core_en = 1'b1;
    tb_time_en = 1'b1;
    tb_m_axis_tready[0] = 1'b1;
    tb_c_time_ref_dt = (48'd1 << 47) - 48'd3;
    tb_time_abs_i    = (48'd1 << 47) - 48'd1;                // 3 before the event, all low bits set

    push_event(ev);
    fired = 1'b0;
    repeat (40) begin
        @(posedge tb_clk);
        fired |= tb_m_axis_tvalid[0];
    end
    `FAIL_IF(fired);
    tb_time_abs_i    = (48'd1 << 47) + 48'd3;                // 1 after
    wait_until(tb_m_axis_tvalid[0]);
    `FAIL_UNLESS(tb_m_axis_tvalid[0]);
    `FAIL_UNLESS(tb_m_axis_tdata[0] === 168'h1122_3344_5566_7788_99AA_BBCC_DDEE_FF00_11);
`SVTEST_END
