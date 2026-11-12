
// ---------------------------------------------------------------------------
// FIFO-full pause stimuli beyond the single-port test of qick_processor_tests.sv.
// Each one fills a dispatcher FIFO (16 entries) so
// that the core is paused and resumed while port writes are in flight, with
// the three clocks different. The expected words come from 8 isolated pulses.
// Checked against two controls (scratch copies, not kept):
//   RTL with the stall (before the fix): the four tests pass;
//   no stall and no hold: tc_two_ports_one_port_blocked (19 of 20 words on
//   port 0) and tc_time_inc_ref_between_pulses_under_fifo_full (28 of 40) fail,
//   as does the single-port test of qick_processor_tests.sv. The r_wave test
//   (the word comes from the r_wave register, not from the memory output) and
//   the trigger test do not depend on the held word and pass either way: they
//   keep those paths covered.
// ---------------------------------------------------------------------------

`SVTEST(tc_two_ports_one_port_blocked)
    logic [255:0] prog [$];
    logic [167:0] got;
    int ok0, ok1, a;
    make_golden();
    `FAIL_UNLESS(m0_words.size() == 8);

    reset_dut();
    tb_m0_axis_tready = 1'b1;
    tb_m1_axis_tready = 1'b0;       // port 1 cannot send: its FIFO fills, port 0's does not
    prog = '{256'd0};
    for (int i = 0; i < 40; i++) begin
        a = (i % 2 == 0) ? (i / 2) % 8 : (i / 2 + 3) % 8;
        prog.push_back(mk_pwp(i % 2, a, 2000 + 20 * i));
    end
    prog.push_back(mk_jump(11'(prog.size())));
    load_and_start(prog);
    repeat (2500) @(posedge tb_c_clk);
    `FAIL_UNLESS(fifo_full_cycles > 0);       // the core was paused on port 1's FIFO
    tb_m1_axis_tready = 1'b1;
    repeat (4000) @(posedge tb_c_clk);

    ok0 = 0; ok1 = 0;
    for (int k = 0; k < m0_words.size() && k < 20; k++) begin
        got = m0_words[k]; a = (2 * k) / 2 % 8;
        if (got === golden[a]) ok0++;
    end
    for (int k = 0; k < m1_words.size() && k < 20; k++) begin
        got = m1_words[k]; a = ((2 * k + 1) / 2 + 3) % 8;
        if (got === golden[a]) ok1++;
    end
    $display("PAUSE port0 %0d/%0d words ok, port1 %0d/%0d ok, FIFO full %0d cycles",
             ok0, m0_words.size(), ok1, m1_words.size(), fifo_full_cycles);
    `FAIL_UNLESS(m0_words.size() == 20);
    `FAIL_UNLESS(m1_words.size() == 20);
    `FAIL_UNLESS(ok0 == 20);
    `FAIL_UNLESS(ok1 == 20);
`SVTEST_END

`SVTEST(tc_r_wave_source_under_fifo_full)
    logic [255:0] prog [$];
    logic [167:0] got;
    int ok;
    make_golden();
    `FAIL_UNLESS(m0_words.size() == 8);

    reset_dut();
    tb_m0_axis_tready = 1'b1;
    tb_m1_axis_tready = 1'b1;
    prog = '{256'd0};
    for (int i = 0; i < 40; i++) begin
        prog.push_back(mk_rw_load(i % 8));          // REG_WR r_wave wmem [&a]
        prog.push_back(mk_pwr(0, 2000 + 20 * i));   // WPORT_WR p0 r_wave @t
    end
    prog.push_back(mk_jump(11'(prog.size())));
    load_and_start(prog);
    repeat (4500) @(posedge tb_c_clk);
    ok = 0;
    for (int k = 0; k < m0_words.size() && k < 40; k++) begin
        got = m0_words[k];
        if (got === golden[k % 8]) ok++;
    end
    $display("PAUSE r_wave %0d/%0d words ok, FIFO full %0d cycles", ok, m0_words.size(), fifo_full_cycles);
    `FAIL_UNLESS(fifo_full_cycles > 0);
    `FAIL_UNLESS(m0_words.size() == 40);
    `FAIL_UNLESS(ok == 40);
`SVTEST_END

`SVTEST(tc_time_inc_ref_between_pulses_under_fifo_full)
    // the shape asm_v2 emits: TIME inc_ref advances the reference, each pulse has an
    // immediate @t relative to it. Words and release times must both be right.
    logic [255:0] prog [$];
    logic [167:0] got;
    int ok, bad_dt;
    make_golden();
    `FAIL_UNLESS(m0_words.size() == 8);

    reset_dut();
    tb_m0_axis_tready = 1'b1;
    tb_m1_axis_tready = 1'b1;
    prog = '{256'd0, mk_time_inc(2000)};
    for (int i = 0; i < 40; i++) begin
        prog.push_back(mk_pwp(0, i % 8, 0));     // WPORT_WR p0 wmem [&a] @0
        prog.push_back(mk_time_inc(20));         // TIME inc_ref #20
    end
    prog.push_back(mk_jump(11'(prog.size())));
    load_and_start(prog);
    repeat (4500) @(posedge tb_c_clk);
    ok = 0; bad_dt = 0;
    for (int k = 0; k < m0_words.size() && k < 40; k++) begin
        got = m0_words[k];
        if (got === golden[k % 8]) ok++;
        if (k > 0 && (m0_time[k] - m0_time[k-1] < 19 || m0_time[k] - m0_time[k-1] > 21)) bad_dt++;
    end
    $display("PAUSE time_inc %0d/%0d words ok, %0d release intervals off 20 ticks, FIFO full %0d cycles",
             ok, m0_words.size(), bad_dt, fifo_full_cycles);
    `FAIL_UNLESS(fifo_full_cycles > 0);
    `FAIL_UNLESS(m0_words.size() == 40);
    `FAIL_UNLESS(ok == 40);
    `FAIL_UNLESS(bad_dt == 0);
`SVTEST_END

`SVTEST(tc_trigger_pairs_under_fifo_full)
    logic [255:0] prog [$];
    int bad_gap, bad_w;
    reset_dut();
    tb_m0_axis_tready = 1'b1;
    tb_m1_axis_tready = 1'b1;
    prog = '{256'd0};
    for (int i = 0; i < 24; i++) begin
        prog.push_back(mk_trig_t(1'b1, 2000 + 40 * i));
        prog.push_back(mk_trig_t(1'b0, 2000 + 40 * i + 10));
    end
    prog.push_back(mk_jump(11'(prog.size())));
    load_and_start(prog);
    repeat (3500) @(posedge tb_c_clk);
    bad_gap = 0; bad_w = 0;
    for (int k = 1; k < trig_rise.size(); k++)
        if (trig_rise[k] - trig_rise[k-1] < 39 || trig_rise[k] - trig_rise[k-1] > 41) bad_gap++;
    for (int k = 0; k < trig_rise.size() && k < trig_fall.size(); k++)
        if (trig_fall[k] - trig_rise[k] < 9 || trig_fall[k] - trig_rise[k] > 11) bad_w++;
    $display("PAUSE trig %0d rises, %0d falls, %0d gaps off 40 ticks, %0d widths off 10 ticks, FIFO full %0d cycles",
             trig_rise.size(), trig_fall.size(), bad_gap, bad_w, fifo_full_cycles);
    `FAIL_UNLESS(fifo_full_cycles > 0);
    `FAIL_UNLESS(trig_rise.size() == 24);
    `FAIL_UNLESS(trig_fall.size() == 24);
    `FAIL_UNLESS(bad_gap == 0);
    `FAIL_UNLESS(bad_w == 0);
`SVTEST_END
