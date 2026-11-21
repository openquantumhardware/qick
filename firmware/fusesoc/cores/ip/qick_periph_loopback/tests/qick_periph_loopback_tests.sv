// ============================================================================
// File: qick_periph_loopback_tests.sv
// Description: SVUnit test cases for qick_periph_loopback. Included by qick_periph_loopback_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_ready)
    `FAIL_UNLESS(rdy3 === 1'b1 && vld3 === 1'b0 && flag3 === 1'b0);
    `FAIL_UNLESS(cmd3 === 32'd0 && drop3 === 32'd0);
`SVTEST_END

// The result is on vld exactly DELAY clocks after the clock that took the command, and rdy is low in between.
`SVTEST(tc_result_after_the_delay)
    cmd(5'd7, 32'd100, 32'd23, 32'hF0F0, 32'h0F00);        // taken at this edge
    `FAIL_UNLESS(rdy3 === 1'b0 && rdy1 === 1'b0);
    `FAIL_UNLESS(vld1 === 1'b0);
    idle(1);                                               // 1 clock after the command
    `FAIL_UNLESS(vld1 === 1'b1);                           // DELAY = 1
    `FAIL_UNLESS(dt1_1 === 32'd123);
    `FAIL_UNLESS(dt2_1 === (32'hF0F0 ^ 32'h0F00 ^ 32'd7));
    `FAIL_UNLESS(rdy1 === 1'b1);
    `FAIL_UNLESS(vld3 === 1'b0 && rdy3 === 1'b0);          // DELAY = 3 not yet
    idle(1);
    `FAIL_UNLESS(vld1 === 1'b0);                           // a pulse of one clock
    `FAIL_UNLESS(vld3 === 1'b0);
    idle(1);                                               // 3 clocks after the command
    `FAIL_UNLESS(vld3 === 1'b1 && rdy3 === 1'b1);
    `FAIL_UNLESS(dt1_3 === 32'd123);
    `FAIL_UNLESS(dt2_3 === (32'hF0F0 ^ 32'h0F00 ^ 32'd7));
    idle(1);
    `FAIL_UNLESS(vld3 === 1'b0);
    `FAIL_UNLESS(dt1_3 === 32'd123);                       // the result is held after the pulse
`SVTEST_END

`SVTEST(tc_flag_follows_bit_0_of_a)
    cmd(5'd0, 32'd2, 32'd0, 32'd0, 32'd0);
    `FAIL_UNLESS(flag3 === 1'b0);
    idle(4);
    cmd(5'd0, 32'd3, 32'd0, 32'd0, 32'd0);
    `FAIL_UNLESS(flag3 === 1'b1);
    idle(4);
    cmd(5'd0, 32'd4, 32'd0, 32'd0, 32'd0);
    `FAIL_UNLESS(flag3 === 1'b0);
`SVTEST_END

`SVTEST(tc_sum_wraps)
    cmd(5'd0, 32'hFFFF_FFFF, 32'd2, 32'd0, 32'd0);
    idle(4);
    `FAIL_UNLESS(dt1_3 === 32'd1);
`SVTEST_END

// A command while busy is dropped and counted, and does not disturb the one in progress.
`SVTEST(tc_command_while_busy_is_dropped)
    cmd(5'd1, 32'd10, 32'd20, 32'd0, 32'd0);               // taken
    cmd(5'd2, 32'd1000, 32'd2000, 32'd0, 32'd0);           // delay 3: still busy -> dropped
    `FAIL_UNLESS(drop3 === 32'd1);
    idle(2);                                               // after E1 (the dropped one): vld rises at E3 = E0 + DELAY
    `FAIL_UNLESS(vld3 === 1'b1);
    `FAIL_UNLESS(dt1_3 === 32'd30);
    `FAIL_UNLESS(cmd3 === 32'd1);
    // and the DELAY = 1 instance dropped its second one too (it was busy for one clock)
    `FAIL_UNLESS(cmd1 === 32'd1 && drop1 === 32'd1);
`SVTEST_END

`SVTEST(tc_back_to_back_after_ready)
    cmd(5'd1, 32'd1, 32'd1, 32'd0, 32'd0);
    idle(2);                                               // vld at the third edge: now ready again next clock
    `FAIL_UNLESS(rdy3 === 1'b0);
    idle(1);
    `FAIL_UNLESS(rdy3 === 1'b1 && dt1_3 === 32'd2);
    cmd(5'd1, 32'd5, 32'd6, 32'd0, 32'd0);                 // taken
    idle(3);
    `FAIL_UNLESS(dt1_3 === 32'd11 && cmd3 === 32'd2 && drop3 === 32'd0);
`SVTEST_END
