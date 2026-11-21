// ============================================================================
// File: dmem_ctrl_tests.sv
// Description: SVUnit test cases for dmem_ctrl.
// Included by dmem_ctrl_tc00.sv.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Reset — FSM in INIT, idle outputs, single-access available
// ----------------------------------------------------------------------------
`SVTEST(test_reset_idle)
    repeat(5) @(tb_cb);
    `FAIL_IF(u_dut.state !== INIT_ST);
    `FAIL_IF(tb_busy_o);
    `FAIL_IF(tb_ar_exec_o);
    `FAIL_IF(tb_aw_exec_o);
    `FAIL_IF(tb_sel_o !== SEL_SINGLE);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Idle — without start_reg, FSM stays in INIT (single access)
// ----------------------------------------------------------------------------
`SVTEST(test_idle_no_start)
    tb_cb.tb_mode_reg <= 1'b0;
    repeat(10) @(tb_cb);
    `FAIL_IF(u_dut.state !== INIT_ST);
    `FAIL_IF(tb_busy_o);
    `FAIL_IF(tb_sel_o !== SEL_SINGLE);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: AXIS read flow — full FSM walk INIT→READ→READ_ACK→END→INIT
// ----------------------------------------------------------------------------
`SVTEST(test_axis_read_flow)
    start_axis(1'b0);                 // MODE=0 -> read
    // INIT -> AXIS_READ_ST (transient, single cycle)
    wait_state(AXIS_READ_ST);
    `FAIL_IF(tb_ar_exec_o);           // ar_exec NOT asserted yet in READ_ST
    // AXIS_READ_ST -> AXIS_READ_ACK_ST (stable: waits for ack)
    wait_state(AXIS_READ_ACK_ST);
    @(tb_cb);                         // settle combinational outputs
    `FAIL_IF(!tb_busy_o);
    `FAIL_IF(!tb_ar_exec_o);          // ar_exec asserted in ACK state
    `FAIL_IF(tb_sel_o !== SEL_READ);
    // Provide reader ack -> END_ST
    ack_reader();
    wait_state(END_ST);
    @(tb_cb);                         // settle
    `FAIL_IF(tb_busy_o);              // busy deasserted in END
    `FAIL_IF(tb_ar_exec_o);
    `FAIL_IF(tb_sel_o !== SEL_SINGLE);
    // Deassert START -> back to INIT
    stop_axis();
    wait_state(INIT_ST);
    `FAIL_IF(u_dut.state !== INIT_ST);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: AXIS write flow — full FSM walk INIT→WRITE→WRITE_ACK→END→INIT
// ----------------------------------------------------------------------------
`SVTEST(test_axis_write_flow)
    start_axis(1'b1);                 // MODE=1 -> write
    wait_state(AXIS_WRITE_ST);
    `FAIL_IF(tb_aw_exec_o);           // aw_exec NOT asserted yet
    wait_state(AXIS_WRITE_ACK_ST);
    @(tb_cb);                         // settle
    `FAIL_IF(!tb_busy_o);
    `FAIL_IF(!tb_aw_exec_o);          // aw_exec asserted in ACK state
    `FAIL_IF(tb_sel_o !== SEL_WRITE);
    ack_writer();
    wait_state(END_ST);
    @(tb_cb);                         // settle
    `FAIL_IF(tb_busy_o);
    `FAIL_IF(tb_aw_exec_o);
    `FAIL_IF(tb_sel_o !== SEL_SINGLE);
    stop_axis();
    wait_state(INIT_ST);
    `FAIL_IF(u_dut.state !== INIT_ST);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: busy_o asserted throughout AXIS read until END_ST
// ----------------------------------------------------------------------------
`SVTEST(test_busy_high_during_read)
    start_axis(1'b0);
    // busy must stay high through READ_ACK (stable state)
    wait_state(AXIS_READ_ACK_ST);
    @(tb_cb);                         // settle
    `FAIL_IF(!tb_busy_o);
    repeat(5) @(tb_cb) `FAIL_IF(!tb_busy_o); // still waiting on ack
    ack_reader();
    wait_state(END_ST);
    @(tb_cb);                         // settle
    `FAIL_IF(tb_busy_o);                      // released in END
    stop_axis();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: ACK_READ waits for ar_exec_ack (no premature exit)
// ----------------------------------------------------------------------------
`SVTEST(test_read_ack_waits)
    start_axis(1'b0);
    wait_state(AXIS_READ_ACK_ST);
    // Hold without ack: FSM must remain in ACK state, ar_exec held high
    repeat(10) @(tb_cb) begin
        `FAIL_IF(u_dut.state !== AXIS_READ_ACK_ST);
        `FAIL_IF(!tb_ar_exec_o);
    end
    ack_reader();
    wait_state(END_ST);
    stop_axis();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: ACK_WRITE waits for aw_exec_ack (no premature exit)
// ----------------------------------------------------------------------------
`SVTEST(test_write_ack_waits)
    start_axis(1'b1);
    wait_state(AXIS_WRITE_ACK_ST);
    repeat(10) @(tb_cb) begin
        `FAIL_IF(u_dut.state !== AXIS_WRITE_ACK_ST);
        `FAIL_IF(!tb_aw_exec_o);
    end
    ack_writer();
    wait_state(END_ST);
    stop_axis();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: END_ST holds until start_reg deasserted
// ----------------------------------------------------------------------------
`SVTEST(test_end_holds_until_start_low)
    start_axis(1'b0);
    wait_state(AXIS_READ_ACK_ST);
    ack_reader();
    wait_state(END_ST);
    // Keep START high: FSM must stay in END_ST
    repeat(10) @(tb_cb) `FAIL_IF(u_dut.state !== END_ST);
    `FAIL_IF(tb_busy_o);              // busy stays low in END
    stop_axis();
    wait_state(INIT_ST);
    `FAIL_IF(u_dut.state !== INIT_ST);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 09: mode_reg selects path — read vs write mutually exclusive
// ----------------------------------------------------------------------------
`SVTEST(test_mode_selects_path)
    // Read path: aw_exec must never assert
    start_axis(1'b0);
    wait_state(AXIS_READ_ACK_ST);
    `FAIL_IF(tb_aw_exec_o);
    `FAIL_IF(tb_sel_o !== SEL_READ);
    ack_reader();
    wait_state(END_ST);
    stop_axis();
    wait_state(INIT_ST);
    // Write path: ar_exec must never assert
    start_axis(1'b1);
    wait_state(AXIS_WRITE_ACK_ST);
    `FAIL_IF(tb_ar_exec_o);
    `FAIL_IF(tb_sel_o !== SEL_WRITE);
    ack_writer();
    wait_state(END_ST);
    stop_axis();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 10: Back-to-back AXIS transactions (read then write)
// ----------------------------------------------------------------------------
`SVTEST(test_back_to_back_transactions)
    // First: read
    start_axis(1'b0);
    wait_state(AXIS_READ_ACK_ST);
    ack_reader();
    wait_state(END_ST);
    stop_axis();
    wait_state(INIT_ST);
    `FAIL_IF(tb_busy_o);
    // Second: write
    start_axis(1'b1);
    wait_state(AXIS_WRITE_ACK_ST);
    ack_writer();
    wait_state(END_ST);
    stop_axis();
    wait_state(INIT_ST);
    `FAIL_IF(u_dut.state !== INIT_ST);
    `FAIL_IF(tb_busy_o);
    `FAIL_IF(tb_sel_o !== SEL_SINGLE);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 11: sel_o = single (0) whenever idle (INIT and END)
// ----------------------------------------------------------------------------
`SVTEST(test_sel_single_when_idle)
    // INIT
    `FAIL_IF(tb_sel_o !== SEL_SINGLE);
    start_axis(1'b1);
    wait_state(AXIS_WRITE_ACK_ST);
    ack_writer();
    wait_state(END_ST);
    @(tb_cb);                         // settle: outputs reflect END_ST
    // END_ST also exposes single access (sel=0)
    `FAIL_IF(tb_sel_o !== SEL_SINGLE);
    stop_axis();
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 12: Reset during AXIS read returns FSM to INIT
// ----------------------------------------------------------------------------
`SVTEST(test_reset_during_transaction)
    start_axis(1'b0);
    wait_state(AXIS_READ_ACK_ST);
    // Assert reset mid-transaction
    tb_cb.tb_rstn      <= 1'b0;
    tb_cb.tb_start_reg <= 1'b0;
    repeat(5) @(tb_cb);
    `FAIL_IF(u_dut.state !== INIT_ST);
    `FAIL_IF(tb_busy_o);
    `FAIL_IF(tb_ar_exec_o);
    tb_cb.tb_rstn <= 1'b1;
    repeat(5) @(tb_cb);
    `FAIL_IF(u_dut.state !== INIT_ST);
`SVTEST_END