// ============================================================================
// File: qick_processor_tests.sv
// Description: SVUnit test cases for qick_processor. Included by
//              qick_processor_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    logic [31:0] data;
    s_axi.axi_read(ADDR_TPROC_CTRL, data);
    `FAIL_UNLESS(data === 32'd0);
    s_axi.axi_read(ADDR_FIXED_ID, data);
    `FAIL_UNLESS(data === 32'd9);
    `FAIL_UNLESS(tb_s0_axis_tready); // unused-input tready is always driven high
`SVTEST_END

`SVTEST(tc_unused_input_ports_tie_ready_high)
    // Only s0 is wired into qick_processor (IN_PORT_QTY=1); every s*_axis
    // tready is still hard-tied to 1, including the unused ones.
    `FAIL_UNLESS(tb_s1_axis_tready);
`SVTEST_END

`SVTEST(tc_unused_wave_port_tied_off)
    // OUT_WPORT_QTY=1: channel 1's AXIS master output must be tied to
    // not-valid (gen_wave_port_not_present).
    `FAIL_IF(tb_m1_axis_tvalid);
`SVTEST_END

`SVTEST(tc_unused_trigger_pins_tied_off)
    // OUT_TRIG_QTY=2: only trig_0/trig_1 are wired; trig_2 and above must
    // be tied to 0 (gen_trigger_port_not_present).
    `FAIL_IF(tb_trig_2_o);
    `FAIL_IF(tb_trig_5_o);
    `FAIL_IF(tb_trig_31_o);
`SVTEST_END

`SVTEST(tc_axi_register_round_trip)
    logic [31:0] data;
    s_axi.axi_write(ADDR_TPROC_CFG, 32'h0000_0ABC);
    s_axi.axi_read(ADDR_TPROC_CFG, data);
    `FAIL_UNLESS(data === 32'h0000_0ABC);

    s_axi.axi_write(ADDR_CORE_CFG, 32'h0000_0055);
    s_axi.axi_read(ADDR_CORE_CFG, data);
    `FAIL_UNLESS(data === 32'h0000_0055);
`SVTEST_END

`SVTEST(tc_axi_start_reaches_run)
    bit reached;
    // TPROC_CTRL bit 2 = START; same integration path as qick_processor's
    // own testbench, exercised here through qick_processor's flat
    // AXI-Lite pins.
    s_axi.axi_write(ADDR_TPROC_CTRL, 32'h0000_0004);
    wait_for_core_st(C_RUN, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END

`SVTEST(tc_external_proc_start_pin_reaches_run)
    bit reached;
    // Exercises qick_processor's OWN addition: the external
    // proc_start_i level pin, synchronized (cdc_reg_sync) and edge-detected
    // into a one-shot pulse before reaching qick_processor. The pin only
    // takes effect once TPROC_CFG[10] selects the external start source
    // (qproc_ctrl.sv's proc_start_io gate) -- mirrors the real driver's
    // start_src('external') (qick_lib/qick/drivers/tproc.py).
    s_axi.axi_write(ADDR_TPROC_CFG, 32'h0000_0400);

    @(negedge tb_clk);
    tb_proc_start_i = 1'b1;
    repeat(5) @(posedge tb_clk);
    tb_proc_start_i = 1'b0;

    wait_for_core_st(C_RUN, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END

// ---------------------------------------------------------------------------
// A pulse train that fills the dispatcher FIFOs pauses the
// core; the wave words that come out after the resume must be the ones the
// program asked for, in order. The instructions in flight at the pause are
// what the stall_id_wp hazard protects.
//
// Golden words: 8 pulses (one per WMEM row) run alone, far from any FIFO
// pressure. Then the same words are requested 40 times (FIFO_DEPTH = 4, so 16
// entries per FIFO: the core pauses on full) with times far enough in the
// future that nothing drains before the FIFO is full.
// ---------------------------------------------------------------------------
`SVTEST(tc_pulse_train_fifo_full_pause_resume_keeps_wave_words)
    logic [255:0] prog [$];
    logic [255:0] rows [$];
    logic [167:0] golden [8];
    logic [167:0] got;
    bit           reached;
    int           ok, n_out;

    for (int i = 0; i < 8; i++) begin
        logic [255:0] r;
        r = '0;
        for (int k = 0; k < 6; k++) r[32*k +: 32] = {8'(i + 1), 8'(k + 1), 16'h5aa5};
        rows.push_back(r);
    end

    // --- golden: 8 pulses alone ---
    tb_m0_axis_tready = 1'b1;
    prog = '{256'd0};
    for (int i = 0; i < 8; i++) prog.push_back(mk_pw(i, 2000 + 20 * i));
    prog.push_back(mk_jump(11'(prog.size())));   // park: jump to its own address
    dma_load(3, rows);
    dma_load(1, prog);
    m0_words.delete();
    s_axi.axi_write(ADDR_TPROC_CTRL, 32'h0000_0004);
    wait_for_core_st(C_RUN, reached);
    `FAIL_UNLESS(reached);
    repeat (3000) @(posedge tb_clk);
    n_out = m0_words.size();
    $display("FIFO37 golden: %0d words out", n_out);
    `FAIL_UNLESS(n_out == 8);
    for (int i = 0; i < 8 && i < n_out; i++) golden[i] = m0_words[i];
    for (int i = 0; i < 8; i++)
        for (int j = i + 1; j < 8; j++)
            `FAIL_UNLESS(golden[i] !== golden[j]);   // rows are distinguishable at the output

    // --- stressed: 40 pulses, 5 passes over the 8 words ---
    reset_dut();
    fifo_full_cycles = 0;
    prog = '{256'd0};
    for (int i = 0; i < 40; i++) prog.push_back(mk_pw(i % 8, 2000 + 20 * i));
    prog.push_back(mk_jump(11'(prog.size())));
    dma_load(3, rows);
    dma_load(1, prog);
    m0_words.delete();
    s_axi.axi_write(ADDR_TPROC_CTRL, 32'h0000_0004);
    wait_for_core_st(C_RUN, reached);
    `FAIL_UNLESS(reached);
    repeat (6000) @(posedge tb_clk);
    n_out = m0_words.size();
    ok = 0;
    for (int i = 0; i < 40 && i < n_out; i++) begin
        got = m0_words[i];   // copy out (TESTBENCH_PATTERNS #28)
        if (got === golden[i % 8]) ok++;
    end
    $display("FIFO37 stressed: %0d words out, %0d of 40 equal to the golden word; some_fifo_full high for %0d cycles",
             n_out, ok, fifo_full_cycles);
    `FAIL_UNLESS(fifo_full_cycles > 0);   // the stimulus did fill a FIFO and pause the core
    `FAIL_UNLESS(n_out == 40);
    `FAIL_UNLESS(ok == 40);
`SVTEST_END
