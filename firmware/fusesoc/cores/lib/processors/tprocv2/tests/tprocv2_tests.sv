// ============================================================================
// File: tprocv2_tests.sv
// Description: SVUnit test cases for tprocv2. Included by
//              tprocv2_tc00.sv.
//
// Register map (byte-addressed, matches qproc_axi_reg.sv's header; the
// ADDR_* localparams live in tprocv2_tc00.sv, module scope).
// ============================================================================

`SVTEST(tc_reset_idle)
    logic [31:0] data;
    s_axi.axi_read(ADDR_TPROC_CTRL, data);
    `FAIL_UNLESS(data === 32'd0);
    s_axi.axi_read(ADDR_FIXED_ID, data);
    `FAIL_UNLESS(data === 32'd9); // Fixed core/version id (see qproc_axi_reg.sv)
`SVTEST_END

`SVTEST(tc_axi_register_round_trip)
    logic [31:0] data;

    s_axi.axi_write(ADDR_TPROC_CFG, 32'h0000_0ABC);
    s_axi.axi_read(ADDR_TPROC_CFG, data);
    `FAIL_UNLESS(data === 32'h0000_0ABC);

    s_axi.axi_write(ADDR_MEM_ADDR, 32'h0000_1234);
    s_axi.axi_read(ADDR_MEM_ADDR, data);
    `FAIL_UNLESS(data === 32'h0000_1234);

    s_axi.axi_write(ADDR_MEM_LEN, 32'h0000_0010);
    s_axi.axi_read(ADDR_MEM_LEN, data);
    `FAIL_UNLESS(data === 32'h0000_0010);

    s_axi.axi_write(ADDR_CORE_CFG, 32'h0000_0055);
    s_axi.axi_read(ADDR_CORE_CFG, data);
    `FAIL_UNLESS(data === 32'h0000_0055);
`SVTEST_END

`SVTEST(tc_core_start_reaches_run_via_axi)
    bit reached;

    // TPROC_CTRL bit 2 = START (core_rst_run_p / time_rst_run_p). AUTO_CLEAR_BIT0
    // makes this a one-shot pulse (see qproc_axi_reg.sv); qproc_ctrl's FSM
    // rides the real qproc_dispatcher FIFOs' wr_rst_busy transient through
    // C_RST_RUN -> C_RST_RUN_WAIT -> C_RUN (see qproc_dispatcher's own
    // testbench notes on that XPM_FIFO_ASYNC behavior).
    s_axi.axi_write(ADDR_TPROC_CTRL, 32'h0000_0004);

    wait_for_core_st(C_RUN, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END
