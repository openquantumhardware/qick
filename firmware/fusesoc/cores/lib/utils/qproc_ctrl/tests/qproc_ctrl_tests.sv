// ============================================================================
// File: qproc_ctrl_tests.sv
// Description: SVUnit test cases for qproc_ctrl. Included by
//              qproc_ctrl_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_holds_core_and_time_in_reset)
    // The core FSM parks in C_RST_STOP (asserting core_rst_o) until
    // all_fifo_full_i pulses -- it does not self-advance.
    `FAIL_UNLESS(tb_core_st_do === C_RST_STOP);
    `FAIL_UNLESS(tb_core_rst_o);

    // The time FSM's RST_STOP has no such external gate: it pulses
    // time_rst_o for exactly one cycle and then self-advances to T_STOP, so
    // by the time setup() settles it has already parked in T_STOP.
    `FAIL_UNLESS(tb_time_st_do === T_STOP);
    `FAIL_IF(tb_time_rst_o);
`SVTEST_END

`SVTEST(tc_core_start_reaches_run_via_fifo_handshake)
    bit reached;

    // START (ps_tproc_ctrl_i[2]) drives core_rst_run_p; the FSM parks in
    // C_RST_RUN asserting core_rst_o until all_fifo_full_i is seen high,
    // then waits for it to drop before declaring C_RUN.
    tb_all_fifo_full_i = 1'b1;
    tb_ps_tproc_ctrl_i[2] = 1'b1;
    wait_for_core_st(C_RST_RUN_WAIT, reached);
    `FAIL_UNLESS(reached);

    tb_all_fifo_full_i = 1'b0;
    wait_for_core_st(C_RUN, reached);
    `FAIL_UNLESS(reached);
    `FAIL_UNLESS(tb_core_en_o);
`SVTEST_END

`SVTEST(tc_core_stop_returns_to_stop)
    bit reached;

    tb_all_fifo_full_i = 1'b1;
    tb_ps_tproc_ctrl_i[2] = 1'b1; // START
    wait_for_core_st(C_RST_RUN_WAIT, reached);
    `FAIL_UNLESS(reached);
    tb_all_fifo_full_i = 1'b0;
    wait_for_core_st(C_RUN, reached);
    `FAIL_UNLESS(reached);

    tb_ps_tproc_ctrl_i[3] = 1'b1; // STOP (bit-wise edge-detected, bit2 stays steady)
    wait_for_core_st(C_STOP, reached);
    `FAIL_UNLESS(reached);
    `FAIL_IF(tb_core_en_o);
`SVTEST_END

`SVTEST(tc_time_free_runs_after_start)
    bit reached;
    logic [47:0] prev;

    tb_ps_tproc_ctrl_i[2] = 1'b1; // START -> time_rst_run_p (T_RST_RUN auto-advances to T_RUN)
    wait_for_time_st(T_RUN, reached);
    `FAIL_UNLESS(reached);

    repeat(2) @(posedge tb_clk);
    prev = tb_time_abs_o;
    repeat(5) begin
        @(posedge tb_clk);
        `FAIL_UNLESS(tb_time_abs_o === prev + 48'd1);
        prev = tb_time_abs_o;
    end
`SVTEST_END

// ---- reference time (TIME set_ref / inc_ref) and user time ----------------------------------------------------------------------
// c_time_ref_o is 48 bits wide and is loaded from a 32-bit operand (int_time_dt), so its upper bits can only be reached by an
// increment that carries out of bit 31. The dispatcher adds it to every event time and TIME_USR is time_abs minus it. The old
// qick_testbench (test_tproc_basic) forced it to 2**M, M = 15..47, to look at that; nothing here did.

`SVTEST(tc_time_ref_set_and_inc_carry_into_the_upper_bits)
    bit reached;
    run_core(reached);
    `FAIL_UNLESS(reached);

    time_cmd(4'b0100, 32'hFFFF_FFF0);              // set_ref: zero-extended, not sign-extended
    `FAIL_UNLESS(tb_c_time_ref_o === 48'h0000_FFFF_FFF0);

    time_cmd(4'b1000, 32'h0000_0020);              // inc_ref carries out of bit 31
    `FAIL_UNLESS(tb_c_time_ref_o === 48'h0001_0000_0010);

    time_cmd(4'b1000, 32'hFFFF_FFFF);              // and again: 2**32 + 0x10 + (2**32 - 1)
    `FAIL_UNLESS(tb_c_time_ref_o === 48'h0002_0000_000F);
`SVTEST_END

`SVTEST(tc_time_ref_is_cleared_by_a_core_reset)
    bit reached;
    run_core(reached);
    `FAIL_UNLESS(reached);

    time_cmd(4'b0100, 32'h1234_5678);
    `FAIL_UNLESS(tb_c_time_ref_o === 48'h0000_1234_5678);

    tb_ps_tproc_ctrl_i[6] = 1'b1;                      // P_RST: core reset, parked in C_RST_STOP
    wait_for_core_st(C_RST_STOP, reached);
    `FAIL_UNLESS(reached);
    repeat (2) @(posedge tb_clk);
    `FAIL_UNLESS(tb_c_time_ref_o === 48'd0);
`SVTEST_END

// TIME_USR = time_abs - ref, 32 bits, also with a reference above 2**32. Time is stopped first so that the value read across the
// two clock domains is the one to compare with.
`SVTEST(tc_time_usr_is_abs_minus_ref_with_an_upper_reference)
    bit reached;
    logic [47:0] abs_s;
    run_core(reached);
    `FAIL_UNLESS(reached);
    repeat (60) @(posedge tb_clk);                     // let time_abs get away from 0

    tb_ps_tproc_ctrl_i[3] = 1'b1;                      // STOP
    wait_for_time_st(T_STOP, reached);
    `FAIL_UNLESS(reached);

    time_cmd(4'b0100, 32'hFFFF_FFF0);
    time_cmd(4'b1000, 32'h0000_0020);             // ref = 2**32 + 0x10
    repeat (40) @(posedge tb_clk);                     // the read path crosses clock domains: settle
    abs_s = tb_time_abs_o;
    `FAIL_IF(abs_s === 48'd0);
    `FAIL_UNLESS(tb_c_time_usr_o === 32'(abs_s - tb_c_time_ref_o));
`SVTEST_END
