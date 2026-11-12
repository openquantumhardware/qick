// ============================================================================
// File: qproc_core_tests.sv
// Description: SVUnit test cases for qproc_core. Included by
//              qproc_core_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    ps_read(SEL_DMEM, 16'h0000);
    `FAIL_UNLESS(tb_ps_mem_r_dt_o === 168'd0);
`SVTEST_END

`SVTEST(tc_load_pmem_execute_store_to_dmem)
    bit matched;

    // Load a single store-immediate instruction (ai=0 -> dmem addr 0,
    // data = imm11) at PMEM address 0 via the PS port.
    ps_write(SEL_PMEM, 16'h0000, {96'd0, mk_store_imm(1'b0, 11'h055)});

    tb_en_i = 1'b1;

    matched = 1'b0;
    for (int n = 0; n < 40 && !matched; n++) begin
        ps_read(SEL_DMEM, 16'h0000);
        if (tb_ps_mem_r_dt_o === {136'd0, 32'h0000_0055})
            matched = 1'b1;
    end
    `FAIL_UNLESS(matched);
`SVTEST_END

`SVTEST(tc_halted_core_never_executes)
    // Same program as above, but en_i stays low: the CPU must never fetch,
    // so DMEM addr 0 stays whatever it already was (BRAM contents are not
    // cleared by reset, so don't assume it starts at 0 -- capture a
    // baseline first).
    logic [167:0] baseline;
    ps_read(SEL_DMEM, 16'h0000);
    baseline = tb_ps_mem_r_dt_o;

    ps_write(SEL_PMEM, 16'h0000, {96'd0, mk_store_imm(1'b0, 11'h055)});

    tb_en_i = 1'b0;
    repeat(40) @(posedge tb_clk);

    ps_read(SEL_DMEM, 16'h0000);
    `FAIL_UNLESS(tb_ps_mem_r_dt_o === baseline);
`SVTEST_END

// ---------------------------------------------------------------------------
// WPORT_WR command rate.
//
// What is observed: qproc_core's port_we_o / port_o, i.e. the CPU's output
// before the dispatcher, with the real BRAM program memory behind it. The
// number is in c_clk_i cycles, so it does not depend on the clock frequency.
//
// Measured (xsim 2025.2, this testbench), with the wave word held across a
// core pause: two wave-port writes issue 1 cycle apart
// (the same port or different ports, one gap of 2 early in a run on several
// ports), a trigger write every 2 cycles, and every other instruction between
// them costs its own cycles (k instructions of 1 cycle: spacing k + 1).
// The previous stall_id_wp kept any two port writes 3 cycles apart.
// What the stall protected (#37: a FIFO-full pause changing the wave word of
// the instruction waiting in X2) is tested at qick_processor level.
// ---------------------------------------------------------------------------

`SVTEST(tc_wport_wr_encoder_matches_assembler)
    // Words emitted by qick_lib/qick/tprocv2_assembler.py (Assembler.str_asm2bin).
    `FAIL_UNLESS(mk_wport_wr(1'b0, 6'd0, 11'd0, 32'd10)  === 72'hdce000000000000500); // WPORT_WR p0 wmem [&0] @10
    `FAIL_UNLESS(mk_wport_wr(1'b0, 6'd5, 11'd3, 32'd100) === 72'hdce000628000003200); // WPORT_WR p5 wmem [&3] @100
    `FAIL_UNLESS(mk_wport_wr(1'b1, 6'd0, 11'd0, 32'd10)  === 72'hcde000000000000500); // WPORT_WR p0 r_wave @10
`SVTEST_END

`SVTEST(tc_wport_wr_rate_same_port)
    logic [71:0] prog[$];
    build_train(prog, 8, 1'b0, 1'b0, 0);
    run_prog(prog, 80);
    group_writes();
    print_writes("8 x wmem, same port, no gap");
    `FAIL_UNLESS(wr_first.size() == 8);
    `FAIL_UNLESS(spacing_all_eq(1));
    for (int i = 0; i < 8; i++) begin
        `FAIL_UNLESS(wr_time[i] === 32'(10 * (i + 1)));
        `FAIL_UNLESS(wr_port[i] === 6'd0);
    end
`SVTEST_END

`SVTEST(tc_wport_wr_rate_rotating_ports)
    logic [71:0] prog[$];
    build_train(prog, 8, 1'b0, 1'b1, 0);
    run_prog(prog, 80);
    group_writes();
    print_writes("8 x wmem, ports 0..7, no gap");
    `FAIL_UNLESS(wr_first.size() == 8);
    `FAIL_UNLESS(spacing_max() <= 2);
    for (int i = 0; i < 8; i++) begin
        `FAIL_UNLESS(wr_time[i] === 32'(10 * (i + 1)));
        `FAIL_UNLESS(wr_port[i] === 6'(i));
    end
`SVTEST_END

`SVTEST(tc_wport_wr_rate_r_wave)
    logic [71:0] prog[$];
    build_train(prog, 8, 1'b1, 1'b0, 0);
    run_prog(prog, 80);
    group_writes();
    print_writes("8 x r_wave, same port, no gap");
    `FAIL_UNLESS(wr_first.size() == 8);
    `FAIL_UNLESS(spacing_all_eq(1));
    build_train(prog, 8, 1'b1, 1'b1, 0);
    reset_dut();
    run_prog(prog, 80);
    group_writes();
    print_writes("8 x r_wave, ports 0..7, no gap");
    `FAIL_UNLESS(wr_first.size() == 8);
    `FAIL_UNLESS(spacing_max() <= 2);
`SVTEST_END

`SVTEST(tc_wport_wr_spacing_vs_nops_between)
    // Same train, k NOPs after each write: the spacing is the minimum between
    // two port writes while k is small, and 1 + k per write once the NOPs
    // themselves are the limit (a NOP is expected to cost one cycle).
    logic [71:0] prog[$];
    for (int k = 0; k <= 5; k++) begin
        build_train(prog, 5, 1'b0, 1'b0, k);
        reset_dut();
        run_prog(prog, 80);
        group_writes();
        print_writes($sformatf("5 x wmem, same port, %0d NOP between", k));
        `FAIL_UNLESS(wr_first.size() == 5);
        // each filler instruction costs 1 cycle, so the spacing is k + 1
        `FAIL_UNLESS(spacing_all_eq(k + 1));
    end
`SVTEST_END

// The words the software emits (pulse without @time, TRIG, REG_WR). Raw events:
// one line per run, no grouping, so a write per cycle could not hide.

`SVTEST(tc_wport_wr_software_words_encoder)
    `FAIL_UNLESS(mk_pulse(6'd0, 11'd0) === 72'hdcc000000000000000);  // WPORT_WR p0 wmem [&0]
    `FAIL_UNLESS(mk_pulse(6'd3, 11'd7) === 72'hdcc000e18000000000);  // WPORT_WR p3 wmem [&7]
    `FAIL_UNLESS(mk_trig(1'b1, 5'd0)   === 72'hdd8000300000000000);  // TRIG set p0
    `FAIL_UNLESS(mk_trig(1'b0, 5'd0)   === 72'hdd8000100000000000);  // TRIG clr p0
`SVTEST_END

`SVTEST(tc_port_write_rate_software_words)
    logic [71:0] prog[$];

    // 6 pulses on one port
    prog = '{NOP_WORD};
    repeat (6) prog.push_back(mk_pulse(6'd0, 11'd0));
    prog.push_back(mk_branch_imm(11'(prog.size())));
    run_prog(prog, 60);
    print_events("6 x pulse p0");
    `FAIL_UNLESS(we_cyc.size() == 6);
    `FAIL_UNLESS(spacing_all_eq(1));

    // 6 triggers (set) on one port
    prog = '{NOP_WORD};
    repeat (6) prog.push_back(mk_trig(1'b1, 5'd0));
    prog.push_back(mk_branch_imm(11'(prog.size())));
    reset_dut();
    run_prog(prog, 60);
    print_events("6 x TRIG set p0");
    `FAIL_UNLESS(we_cyc.size() == 6);
    `FAIL_UNLESS(spacing_all_eq(2));    // triggers: another hazard, 2 cycles

    // pulse, trigger set, trigger clr, three times (the pulse + readout trigger pattern)
    prog = '{NOP_WORD};
    repeat (3) begin
        prog.push_back(mk_pulse(6'd0, 11'd0));
        prog.push_back(mk_trig(1'b1, 5'd0));
        prog.push_back(mk_trig(1'b0, 5'd0));
    end
    prog.push_back(mk_branch_imm(11'(prog.size())));
    reset_dut();
    run_prog(prog, 60);
    print_events("3 x (pulse, TRIG set, TRIG clr)");
    `FAIL_UNLESS(we_cyc.size() == 9);
    `FAIL_UNLESS(spacing_max() <= 2);

    // pulse, then k register writes, ... : do real instructions fill the gap like NOPs do?
    for (int k = 1; k <= 3; k++) begin
        prog = '{NOP_WORD};
        repeat (5) begin
            prog.push_back(mk_pulse(6'd0, 11'd0));
            repeat (k) prog.push_back(REG_WR_R1_IMM5);
        end
        prog.push_back(mk_branch_imm(11'(prog.size())));
        reset_dut();
        run_prog(prog, 80);
        print_events($sformatf("5 x (pulse, %0d x REG_WR)", k));
        `FAIL_UNLESS(we_cyc.size() == 5);
        `FAIL_UNLESS(spacing_all_eq(k + 1));
    end
`SVTEST_END

// Is the wave word that leaves the core intact when port writes are as close
// as the core lets them be? 8 distinct wave words are preloaded in WMEM and
// read back-to-back (WPORT_WR p0 wmem [&i] @t_i, no gap). Each captured
// p_data must be the word of its address, in order.
`SVTEST(tc_wport_wr_back_to_back_wave_words_intact)
    logic [71:0]  prog[$];
    logic [167:0] exp_w [8];
    logic [167:0] got;
    int           nwords;

    for (int i = 0; i < 8; i++) begin
        exp_w[i] = {{5{32'ha5a50000 + 32'(i)}}, 8'(8'h80 + i)};
        ps_write(SEL_WMEM, 16'(i), exp_w[i]);
    end

    prog = '{NOP_WORD};
    for (int i = 0; i < 8; i++) prog.push_back(mk_wport_wr(1'b0, 6'd0, 11'(i), 32'(10 * (i + 1))));
    prog.push_back(mk_branch_imm(11'(prog.size())));
    run_prog(prog, 80);
    print_events("8 x wmem [&0..7], same port");
    `FAIL_UNLESS(we_cyc.size() == 8);

    nwords = 0;
    for (int i = 0; i < we_cyc.size() && i < 8; i++) begin
        got = we_data[i];   // copy out: xsim compares wide queue elements wrong (TESTBENCH_PATTERNS #28)
        if (got === exp_w[i]) nwords++;
        else $display("WPORT_RATE wave word %0d differs: got %h exp %h", i, got, exp_w[i]);
    end
    $display("WPORT_RATE wave words intact: %0d of 8", nwords);
    `FAIL_UNLESS(nwords == 8);
`SVTEST_END

// Hazard mix: pulses with `TIME inc_ref` (pulse without @time) and r_wave
// (`REG_WR r_wave wmem`, pulse from r_wave) between them, plus triggers. The
// SEQ lines hold what leaves the core (time, type, port, data), without cycle
// numbers, so the same run can be diffed against a build with a different
// stall policy. The time register is not observable at
// this level (the testbench ties it to 0): `p_time` is 0 in every line.
`SVTEST(tc_port_write_hazard_mix_sequences)
    logic [71:0]  prog[$];
    logic [167:0] w;
    localparam logic [71:0] I_TIME_INC10 = 72'h4c0800000000000500;  // TIME inc_ref #10
    localparam logic [71:0] I_TIME_INC3  = 72'h4c0800000000000180;  // TIME inc_ref #3
    localparam logic [71:0] I_RW_W1      = 72'h9c4000200000000000;  // REG_WR r_wave wmem [&1]
    localparam logic [71:0] I_RW_W2      = 72'h9c4000400000000000;  // REG_WR r_wave wmem [&2]
    localparam logic [71:0] I_PW_RW_P0   = 72'hcdc000000000000000;  // WPORT_WR p0 r_wave
    localparam logic [71:0] I_PW_RW_P1   = 72'hcdc000008000000000;  // WPORT_WR p1 r_wave

    for (int i = 0; i < 8; i++)
        ps_write(SEL_WMEM, 16'(i), {{5{32'ha5a50000 + 32'(i)}}, 8'(8'h80 + i)});

    // P1: pulse (s_time) / TIME inc_ref / pulse ...
    prog = '{NOP_WORD, mk_pulse(6'd0, 11'd0), I_TIME_INC10, mk_pulse(6'd0, 11'd1), I_TIME_INC3,
             mk_pulse(6'd0, 11'd2), I_TIME_INC10, mk_pulse(6'd0, 11'd3), I_TIME_INC3, mk_pulse(6'd0, 11'd4)};
    prog.push_back(mk_branch_imm(11'(prog.size())));
    reset_dut();
    run_prog(prog, 80);
    print_events("P1 pulse / TIME inc_ref");
    `FAIL_UNLESS(we_cyc.size() == 5);
    foreach (we_cyc[i]) begin
        w = we_data[i];
        $display("SEQ P1 %0d t=%0d ty=%0d port=%0d d=%08h dh=%08h", i, we_time[i], we_type[i], we_port[i], w[31:0], w[167:136]);
    end

    // P2: r_wave loaded from wmem, then pulsed, alternating ports
    prog = '{NOP_WORD, I_RW_W1, I_PW_RW_P0, I_RW_W2, I_PW_RW_P1, I_RW_W1, I_PW_RW_P1, I_RW_W2, I_PW_RW_P0};
    prog.push_back(mk_branch_imm(11'(prog.size())));
    reset_dut();
    run_prog(prog, 80);
    print_events("P2 REG_WR r_wave / pulse r_wave");
    `FAIL_UNLESS(we_cyc.size() == 4);
    foreach (we_cyc[i]) begin
        w = we_data[i];
        $display("SEQ P2 %0d t=%0d ty=%0d port=%0d d=%08h dh=%08h", i, we_time[i], we_type[i], we_port[i], w[31:0], w[167:136]);
    end

    // P3: dense mix of both sources, TIME and triggers
    prog = '{NOP_WORD, mk_pulse(6'd0, 11'd0), mk_trig(1'b1, 5'd0), I_RW_W2, I_PW_RW_P1, I_TIME_INC10,
             mk_pulse(6'd0, 11'd3), mk_trig(1'b0, 5'd0), I_RW_W1, I_PW_RW_P0, mk_pulse(6'd1, 11'd5),
             I_TIME_INC3, mk_pulse(6'd0, 11'd6)};
    prog.push_back(mk_branch_imm(11'(prog.size())));
    reset_dut();
    run_prog(prog, 100);
    print_events("P3 dense mix");
    `FAIL_UNLESS(we_cyc.size() == 8);
    foreach (we_cyc[i]) begin
        w = we_data[i];
        $display("SEQ P3 %0d t=%0d ty=%0d port=%0d d=%08h dh=%08h", i, we_time[i], we_type[i], we_port[i], w[31:0], w[167:136]);
    end
`SVTEST_END

// ---------------------------------------------------------------------------
// Instruction cost table: core cycles per instruction in
// a straight run, measured between two port writes (markers) with N copies of
// one unit in between, for N = COST_NA and COST_NB. The slope
// (spacing(NB) - spacing(NA)) / (NB - NA) is the cost of one unit; the markers
// themselves are the 3-cycle port-write minimum, so only N large enough to
// exceed it counts. Grep for COST. A unit that is two instructions (a test
// and a jump, a load and its use) costs the sum.
// ---------------------------------------------------------------------------
`SVTEST(tc_instruction_cost_table)
    logic [71:0] prog[$];
    int          sa, sb;
    // cycles per unit, as measured with the RTL as it is (order of cost_name()):
    // nop reg_imm reg_chain test_flag | jump_next cjump_taken cjump_not | time_inc dmem_wr dmem_rd
    // dmem_rd_use lfsr arith div flag rwave_load wmem_wr
    int exp_c [COST_N_UNITS] = '{1, 1, 1, 1, 3, 6, 4, 1, 1, 1, 3, 2, 1, 1, 1, 2, 2};
    for (int u = 0; u < COST_N_UNITS; u++) begin
        cost_prog(u, COST_NA, prog);
        reset_dut();
        run_prog(prog, 600);
        `FAIL_UNLESS(we_cyc.size() == 2);
        sa = (we_cyc.size() == 2) ? we_cyc[1] - we_cyc[0] : -1;
        cost_prog(u, COST_NB, prog);
        reset_dut();
        run_prog(prog, 900);
        `FAIL_UNLESS(we_cyc.size() == 2);
        sb = (we_cyc.size() == 2) ? we_cyc[1] - we_cyc[0] : -1;
        $display("COST %-14s spacing(N=%0d)=%0d spacing(N=%0d)=%0d cycles/unit=%0d.%02d",
                 cost_name(u), COST_NA, sa, COST_NB, sb,
                 (sb - sa) / (COST_NB - COST_NA), (100 * (sb - sa) / (COST_NB - COST_NA)) % 100);
        `FAIL_UNLESS(sb - sa == exp_c[u] * (COST_NB - COST_NA));
    end
`SVTEST_END
