// ============================================================================
// File: qick_processor_prog_tests.sv
// Description: SVUnit test cases of qick_processor that RUN PROGRAMS. Included by
//   qick_processor_tc00.sv after qick_processor_tests.sv, in its own file so that the two files can be edited by different branches.
//   The binaries come from tests/data/gen_prog.py, i.e. from the repo's assembler; they are loaded with load_program() -> dma_load().
// ============================================================================
// ============================================================================
// Program-running tests. The binaries come from tests/data/gen_prog.py, i.e. from the real assembler.
// ============================================================================

// A constant written to a data port: load, start, run.
`SVTEST(tc_prog_dport_write)
    run_program("prog_dport.hex", 300);
    `FAIL_UNLESS(tb_port_0_dt_o === 4'd9);
`SVTEST_END

// A counted loop with a flag-conditioned jump: the loop body ran 5 times.
`SVTEST(tc_prog_counted_loop)
    run_program("prog_loop.hex", 600);
    `FAIL_UNLESS(tb_port_0_dt_o === 4'd5);
`SVTEST_END

// PA and PB: one command each, op code and the four operands reach the pins of qick_processor in the order the
// assembler gets them (PA <op> r1 r2 r3 r4 -> a b c d). This also checks the assembler's encoding of PA (CTRL_ADDR _10) and
// PB (_11) against the RTL decode (usr_ctrl_s[7:5] 110 / 111).
`SVTEST(tc_prog_pa_pb_reach_the_pins)
    int n1, n2;
    n1 = qp1_n; n2 = qp2_n;
    run_program("prog_pa_pb.hex", 300);
    `FAIL_UNLESS(qp1_n - n1 == 1);
    `FAIL_UNLESS(qp2_n - n2 == 1);
    `FAIL_UNLESS(qp1_op_q === 5'd3);
    `FAIL_UNLESS({qp1_a_q, qp1_b_q, qp1_c_q, qp1_d_q} === {32'd5, 32'd7, 32'd9, 32'd11});
    `FAIL_UNLESS(qp2_op_q === 5'd4);
    `FAIL_UNLESS({qp2_a_q, qp2_b_q, qp2_c_q, qp2_d_q} === {32'd11, 32'd9, 32'd7, 32'd5});
`SVTEST_END

// ---- the new-data flags of the two peripherals are independent -------------------------------------------
// TPROC_STATUS bit 24 = QPA_DT_NEW, bit 25 = QPB_DT_NEW (tprocv2.sv axi_status_ds[25:20]).

`SVTEST(tc_qp_new_data_flags_set_independently)
    logic [31:0] st;
    one_clock_pulse_vld(1'b1, 1'b0);
    s_axi.axi_read(ADDR_STATUS, st);
    `FAIL_UNLESS(st[25:24] === 2'b01);
    one_clock_pulse_vld(1'b0, 1'b1);
    s_axi.axi_read(ADDR_STATUS, st);
    `FAIL_UNLESS(st[25:24] === 2'b11);
`SVTEST_END

// CLEAR qpb clears QPB_DT_NEW and leaves QPA_DT_NEW alone.
`SVTEST(tc_prog_clear_qpb_clears_only_qpb)
    logic [31:0] st;
    int n;
    load_program("prog_clear_qpb.hex", n);
    s_axi.axi_write(ADDR_TPROC_CTRL, 32'h0000_0004);   // START resets the core, so the new-data pulses come after it
    repeat (50) @(posedge tb_clk);
    one_clock_pulse_vld(1'b1, 1'b1);
    repeat (400) @(posedge tb_clk);
    `FAIL_UNLESS(tb_port_0_dt_o === 4'd1);              // the program got to the CLEAR and past it
    s_axi.axi_read(ADDR_STATUS, st);
    `FAIL_UNLESS(st[25] === 1'b0);                      // QPB cleared
    `FAIL_UNLESS(st[24] === 1'b1);                      // QPA kept
`SVTEST_END

// CLEAR qpa clears QPA_DT_NEW and leaves QPB_DT_NEW alone.
`SVTEST(tc_prog_clear_qpa_clears_only_qpa)
    logic [31:0] st;
    int n;
    load_program("prog_clear_qpa.hex", n);
    s_axi.axi_write(ADDR_TPROC_CTRL, 32'h0000_0004);   // START resets the core, so the new-data pulses come after it
    repeat (50) @(posedge tb_clk);
    one_clock_pulse_vld(1'b1, 1'b1);
    repeat (400) @(posedge tb_clk);
    `FAIL_UNLESS(tb_port_0_dt_o === 4'd1);
    s_axi.axi_read(ADDR_STATUS, st);
    `FAIL_UNLESS(st[24] === 1'b0);                      // QPA cleared
    `FAIL_UNLESS(st[25] === 1'b1);                      // QPB kept
`SVTEST_END

// ---- single-word AXI access to the memories. The core stores the word that MEM_DT_I holds when MEM_START is set, so
// the data register has to be written before the start bit: MEM_ADDR, MEM_DT_I, TPROC_CFG = 0x13 + (type << 2) (type 1 pmem,
// 2 dmem, 3 wmem), TPROC_CFG &= ~63; a read is MEM_ADDR, TPROC_CFG = 0x11 + (type << 2), MEM_DT_O, TPROC_CFG &= ~63.
`SVTEST(tc_single_word_dmem_round_trip)
    localparam int ADDR_MEM_DT_I = 'h10;
    localparam int ADDR_MEM_DT_O = 'h28;
    logic [31:0] cfg, v;
    s_axi.axi_read(ADDR_TPROC_CFG, cfg);
    for (int a = 3; a <= 5; a++) begin
        s_axi.axi_write(ADDR_MEM_ADDR, a);
        s_axi.axi_write(ADDR_MEM_DT_I, 32'hC0DE_0000 + a);
        s_axi.axi_write(ADDR_TPROC_CFG, (cfg & ~32'h3f) | (32'h13 | (32'd2 << 2)));
        repeat (4) @(posedge tb_clk);
        s_axi.axi_write(ADDR_TPROC_CFG, cfg & ~32'h3f);
    end
    for (int a = 2; a <= 6; a++) begin
        s_axi.axi_write(ADDR_MEM_ADDR, a);
        s_axi.axi_write(ADDR_TPROC_CFG, (cfg & ~32'h3f) | (32'h11 | (32'd2 << 2)));
        repeat (6) @(posedge tb_clk);
        s_axi.axi_read(ADDR_MEM_DT_O, v);
        s_axi.axi_write(ADDR_TPROC_CFG, cfg & ~32'h3f);
        if (a >= 3 && a <= 5) begin
            `FAIL_UNLESS(v === 32'hC0DE_0000 + a);
        end else begin
            `FAIL_UNLESS(v === 32'h0);                               // untouched words
        end
    end
`SVTEST_END

// The word written is the one MEM_DT_I holds at the start edge: setting the data after the start (the order the driver
// used before the fix) stores the previous value of the register.
`SVTEST(tc_single_word_write_latches_the_data_register_at_start)
    localparam int ADDR_MEM_DT_I = 'h10;
    localparam int ADDR_MEM_DT_O = 'h28;
    logic [31:0] cfg, v;
    s_axi.axi_read(ADDR_TPROC_CFG, cfg);
    s_axi.axi_write(ADDR_MEM_DT_I, 32'hAAAA_0001);               // the register holds this when the start comes
    s_axi.axi_write(ADDR_MEM_ADDR, 7);
    s_axi.axi_write(ADDR_TPROC_CFG, (cfg & ~32'h3f) | 32'h1B);   // start
    s_axi.axi_write(ADDR_MEM_DT_I, 32'hBBBB_0002);               // too late
    repeat (4) @(posedge tb_clk);
    s_axi.axi_write(ADDR_TPROC_CFG, cfg & ~32'h3f);
    s_axi.axi_write(ADDR_MEM_ADDR, 7);
    s_axi.axi_write(ADDR_TPROC_CFG, (cfg & ~32'h3f) | 32'h19);
    repeat (6) @(posedge tb_clk);
    s_axi.axi_read(ADDR_MEM_DT_O, v);
    s_axi.axi_write(ADDR_TPROC_CFG, cfg & ~32'h3f);
    `FAIL_UNLESS(v === 32'hAAAA_0001);
`SVTEST_END

// ============================================================================
// Issue 04, in simulation: a PA program written with the QickProgramV2 macros (periph_write / periph_config / periph_wait /
// periph_read / periph_clear, lowered and assembled by tests/data/gen_prog.py) against two qick_periph_loopback peripherals.
// Results go to data memory and are read back through the single-word AXI access.
// ============================================================================


// PA to the peripheral, wait for new data, read both words, branch on the QP1 flag (a even: flag clear).
`SVTEST(tc_loopback_pa_wait_read_flag0)
    logic [31:0] v0, v1, v2, v3, st;
    tb_use_loopback = 1'b1;
    run_program("prog_lb_flag0.hex", 800);
    dmem_read(0, v0); dmem_read(1, v1); dmem_read(2, v2); dmem_read(3, v3);
    `FAIL_UNLESS(v3 === 32'd1);                                   // the program got to its end
    `FAIL_UNLESS(v0 === 32'd123);                                 // a + b
    `FAIL_UNLESS(v1 === (32'hF0F0 ^ 32'h0F00 ^ 32'd5));           // c ^ d ^ op
    `FAIL_UNLESS(v2 === 32'd1);                                   // flag clear
    s_axi.axi_read(ADDR_STATUS, st);
    `FAIL_UNLESS(st[24] === 1'b0);                                // periph_clear('a') cleared QPA_DT_NEW
    `FAIL_UNLESS(lb1_cmd === 32'd1 && lb1_drop === 32'd0);
`SVTEST_END

// Same with an odd operand a: the flag is set and the conditional jump on it is taken.
`SVTEST(tc_loopback_pa_wait_read_flag1)
    logic [31:0] v0, v2, v3;
    tb_use_loopback = 1'b1;
    run_program("prog_lb_flag1.hex", 800);
    dmem_read(0, v0); dmem_read(2, v2); dmem_read(3, v3);
    `FAIL_UNLESS(v3 === 32'd1);
    `FAIL_UNLESS(v0 === 32'd124);
    `FAIL_UNLESS(v2 === 32'd2);                                   // flag set: the jump was taken
`SVTEST_END

// Three PA back to back: the core does not stall on rdy; the peripheral takes the first and drops the other two.
`SVTEST(tc_loopback_pa_issued_while_not_ready_is_dropped)
    logic [31:0] v0, v3;
    tb_use_loopback = 1'b1;
    run_program("prog_lb_busy.hex", 800);
    dmem_read(0, v0); dmem_read(3, v3);
    `FAIL_UNLESS(v3 === 32'd1);
    `FAIL_UNLESS(v0 === 32'd123);
    `FAIL_UNLESS(lb1_cmd === 32'd1);
    `FAIL_UNLESS(lb1_drop === 32'd2);
`SVTEST_END

// ============================================================================
// Programs carried over from the old qick_testbench (test_issue359, test_tproc_basic), which loaded them from exported .mem files
// and had no checks: here they are assembled by tests/data/gen_prog.py and their results are asserted.
// ============================================================================

// openquantumhardware/qick#359: PA/PB with s6/s7 as source operands hung the core: the hazard unit counted the instruction's own
// peripheral use as an earlier peripheral write whose result it had to wait for. The program goes through the whole processor against
// the two loopback peripherals (the reads of s6/s7 after the commands wait for their answer, so one is needed): it has to reach its
// end marker, with both commands taken. Two programs: s6/s7 in the data-section operands (R1, R2) and in the address-section ones
// (R3, R4); the unit tests of qcore_ctrl_hazard had only the "peripheral instruction ahead" case and passed while the core hung.
`SVTEST(tc_prog_pa_pb_with_s6_s7_in_the_data_section_does_not_hang)
    logic [31:0] m0, m1, m2, m3, m4;
    tb_use_loopback = 1'b1;
    run_program("prog_pa_s6_s7.hex", 800);
    dmem_read(0, m0); dmem_read(1, m1); dmem_read(2, m2); dmem_read(3, m3); dmem_read(4, m4);
    `FAIL_UNLESS(m1 === 32'h5A5A);                                // past the PA
    `FAIL_UNLESS(m2 === 32'h5A5A);                                // past the PB
    `FAIL_UNLESS(m3 === 32'h5A5A);                                // past the read of s6
    `FAIL_UNLESS(m4 === 32'h5A5A);                                // past the read of s7
    `FAIL_UNLESS(m0 === 32'h5A5A);                                // end
    `FAIL_UNLESS(lb1_cmd === 32'd1 && lb1_drop === 32'd0);       // PA taken
    `FAIL_UNLESS(lb2_cmd === 32'd1 && lb2_drop === 32'd0);       // PB taken
`SVTEST_END

`SVTEST(tc_prog_pa_pb_with_s6_s7_in_the_address_section_does_not_hang)
    logic [31:0] m0, m1, m2, m3, m4;
    tb_use_loopback = 1'b1;
    run_program("prog_pa_s6_s7_cd.hex", 800);
    dmem_read(0, m0); dmem_read(1, m1); dmem_read(2, m2); dmem_read(3, m3); dmem_read(4, m4);
    `FAIL_UNLESS(m1 === 32'h5A5A);                                // past the PA
    `FAIL_UNLESS(m2 === 32'h5A5A);                                // past the PB
    `FAIL_UNLESS(m3 === 32'h5A5A);                                // past the read of s6
    `FAIL_UNLESS(m4 === 32'h5A5A);                                // past the read of s7
    `FAIL_UNLESS(m0 === 32'h5A5A);                                // end
    `FAIL_UNLESS(lb1_cmd === 32'd1 && lb1_drop === 32'd0);       // PA taken
    `FAIL_UNLESS(lb2_cmd === 32'd1 && lb2_drop === 32'd0);       // PB taken
`SVTEST_END

// The 16 data registers: each one takes its own value and keeps it (dmem[0..15] read back), then each takes s_zero (dmem[16..31]).
`SVTEST(tc_prog_all_data_registers_take_a_value_and_zero)
    logic [31:0] v;
    run_program("prog_regs.hex", 1500);
    dmem_read(32, v);
    `FAIL_UNLESS(v === 32'd1);                                    // the program got to its end
    for (int n = 0; n < 16; n++) begin
        dmem_read(n, v);
        `FAIL_UNLESS(v === 32'h1000 + n);
        dmem_read(16 + n, v);
        `FAIL_UNLESS(v === 32'd0);
    end
`SVTEST_END

// ============================================================================
// The programs of the hardware validation notebook, tests/data/periph_programs.py,
// lowered with the 4096-word program memory of the board (jumps through s15) and run on the real core against the two
// loopbacks. dmem[DONE = 15] is cleared before each run: data memory is not reset between tests.
// s_status bits (TRM 4.6): 8 QPA_RDY, 9 QPA_DT_NEW, 10 QPB_RDY, 11 QPB_DT_NEW. The registered ext flag is TPROC_STATUS[15] (AXI only).
// ============================================================================

// One PA, wait, read: the words, the new-data bit in the status snapshot, one command taken, nothing on the other port.
`SVTEST(tc_nb_pa_one)
    logic [31:0] v0, v1, v2, done;
    dmem_write(15, 32'd0);
    tb_use_loopback = 1'b1;
    run_program("prog_nb_one_a.hex", 1200);
    dmem_read(0, v0); dmem_read(1, v1); dmem_read(2, v2); dmem_read(15, done);
    `FAIL_UNLESS(done === 32'd1);
    `FAIL_UNLESS(v0 === ((32'hFFFFFFF0 + 32'h20) & 32'hFFFFFFFF));                    // wraps: 0x10
    `FAIL_UNLESS(v1 === (32'hAAAA5555 ^ 32'h0F0F0F0F ^ 32'd5));
    `FAIL_UNLESS(v2[9] === 1'b1);                                                     // QPA_DT_NEW
    `FAIL_UNLESS(lb1_cmd === 32'd1 && lb1_drop === 32'd0);
    `FAIL_UNLESS(lb2_cmd === 32'd0 && lb2_drop === 32'd0);
`SVTEST_END

// One PB, op code 31 (all five op bits).
`SVTEST(tc_nb_pb_one)
    logic [31:0] v0, v1, v2, done;
    dmem_write(15, 32'd0);
    tb_use_loopback = 1'b1;
    run_program("prog_nb_one_b.hex", 1200);
    dmem_read(0, v0); dmem_read(1, v1); dmem_read(2, v2); dmem_read(15, done);
    `FAIL_UNLESS(done === 32'd1);
    `FAIL_UNLESS(v0 === (32'h12345678 + 32'h0000FFFF));
    `FAIL_UNLESS(v1 === (32'hDEADBEEF ^ 32'h01234567 ^ 32'd31));
    `FAIL_UNLESS(v2[11] === 1'b1);                                                    // QPB_DT_NEW
    `FAIL_UNLESS(lb2_cmd === 32'd1 && lb2_drop === 32'd0);
    `FAIL_UNLESS(lb1_cmd === 32'd0 && lb1_drop === 32'd0);
`SVTEST_END

// PA and PB back to back with different op codes and operands: each answer is its own.
`SVTEST(tc_nb_pa_and_pb_back_to_back)
    logic [31:0] v0, v1, v2, v3, done;
    dmem_write(15, 32'd0);
    tb_use_loopback = 1'b1;
    run_program("prog_nb_both.hex", 1500);
    dmem_read(0, v0); dmem_read(1, v1); dmem_read(2, v2); dmem_read(3, v3); dmem_read(15, done);
    `FAIL_UNLESS(done === 32'd1);
    `FAIL_UNLESS(v0 === ((32'h80000000 + 32'h80000000) & 32'hFFFFFFFF));              // 0
    `FAIL_UNLESS(v1 === (32'hFFFF0000 ^ 32'h0000FFFF ^ 32'd3));
    `FAIL_UNLESS(v2 === (32'd1000 + 32'd2000));
    `FAIL_UNLESS(v3 === (32'h13579BDF ^ 32'h2468ACE0 ^ 32'd30));
    `FAIL_UNLESS(lb1_cmd === 32'd1 && lb1_drop === 32'd0);
    `FAIL_UNLESS(lb2_cmd === 32'd1 && lb2_drop === 32'd0);
`SVTEST_END

// Independent CLEAR, in both orders (on the real notebook program): both answers in -> s_status has both
// new-data bits; the first CLEAR drops only its own; the second drops the other.
`SVTEST(tc_nb_clear_a_first)
    logic [31:0] s_both, s_read, s_c1, s_c2, done;
    dmem_write(15, 32'd0);
    tb_use_loopback = 1'b1;
    run_program("prog_nb_clear_a.hex", 2500);
    dmem_read(4, s_both); dmem_read(5, s_read); dmem_read(6, s_c1); dmem_read(7, s_c2); dmem_read(15, done);
    $display("nb_clear_a: s_status both-in %08h, after reads %08h, after CLEAR qpa %08h, after CLEAR qpb %08h", s_both, s_read, s_c1, s_c2);
    `FAIL_UNLESS(done === 32'd1);
    `FAIL_UNLESS(s_both[9] === 1'b1 && s_both[11] === 1'b1);
    `FAIL_UNLESS(s_c1[9] === 1'b0 && s_c1[11] === 1'b1);
    `FAIL_UNLESS(s_c2[9] === 1'b0 && s_c2[11] === 1'b0);
`SVTEST_END

`SVTEST(tc_nb_clear_b_first)
    logic [31:0] s_both, s_read, s_c1, s_c2, done;
    dmem_write(15, 32'd0);
    tb_use_loopback = 1'b1;
    run_program("prog_nb_clear_b.hex", 2500);
    dmem_read(4, s_both); dmem_read(5, s_read); dmem_read(6, s_c1); dmem_read(7, s_c2); dmem_read(15, done);
    $display("nb_clear_b: s_status both-in %08h, after reads %08h, after CLEAR qpb %08h, after CLEAR qpa %08h", s_both, s_read, s_c1, s_c2);
    `FAIL_UNLESS(done === 32'd1);
    `FAIL_UNLESS(s_both[9] === 1'b1 && s_both[11] === 1'b1);
    `FAIL_UNLESS(s_c1[9] === 1'b1 && s_c1[11] === 1'b0);
    `FAIL_UNLESS(s_c2[9] === 1'b0 && s_c2[11] === 1'b0);
`SVTEST_END

// -if(F) on flg_qpa: the branch follows bit 0 of operand a.
`SVTEST(tc_nb_flag_qpa_odd_taken)
    logic [31:0] v0, v2, done;
    dmem_write(15, 32'd0);
    tb_use_loopback = 1'b1;
    run_program("prog_nb_flag_odd.hex", 1500);
    dmem_read(0, v0); dmem_read(2, v2); dmem_read(15, done);
    `FAIL_UNLESS(done === 32'd1);
    `FAIL_UNLESS(v0 === ((32'hFFFFFFFF + 32'd23) & 32'hFFFFFFFF));
    `FAIL_UNLESS(v2 === 32'd2);
`SVTEST_END

`SVTEST(tc_nb_flag_qpa_even_not_taken)
    logic [31:0] v0, v2, done;
    dmem_write(15, 32'd0);
    tb_use_loopback = 1'b1;
    run_program("prog_nb_flag_even.hex", 1500);
    dmem_read(0, v0); dmem_read(2, v2); dmem_read(15, done);
    `FAIL_UNLESS(done === 32'd1);
    `FAIL_UNLESS(v0 === ((32'hFFFFFFFE + 32'd23) & 32'hFFFFFFFF));
    `FAIL_UNLESS(v2 === 32'd1);
`SVTEST_END

// -if(F) on flg_qpb (revision 29, FLAG_SRC 0x8): the branch follows bit 0 of the operand a of the PB command.
`SVTEST(tc_nb_flag_qpb_odd_taken)
    logic [31:0] v0, v2, done;
    dmem_write(15, 32'd0);
    tb_use_loopback = 1'b1;
    run_program("prog_nb_flagb_odd.hex", 1500);
    dmem_read(0, v0); dmem_read(2, v2); dmem_read(15, done);
    `FAIL_UNLESS(done === 32'd1);
    `FAIL_UNLESS(v0 === ((32'hFFFFFFFF + 32'd23) & 32'hFFFFFFFF));
    `FAIL_UNLESS(v2 === 32'd2);
`SVTEST_END

`SVTEST(tc_nb_flag_qpb_even_not_taken)
    logic [31:0] v0, v2, done;
    dmem_write(15, 32'd0);
    tb_use_loopback = 1'b1;
    run_program("prog_nb_flagb_even.hex", 1500);
    dmem_read(0, v0); dmem_read(2, v2); dmem_read(15, done);
    `FAIL_UNLESS(done === 32'd1);
    `FAIL_UNLESS(v0 === ((32'hFFFFFFFE + 32'd23) & 32'hFFFFFFFF));
    `FAIL_UNLESS(v2 === 32'd1);
`SVTEST_END

// The two flags differ (QP1 set, QP2 clear, and the other way round): each source sees its own port, not the other one.
`SVTEST(tc_nb_flag_sources_do_not_cross_qpa_set_qpb_clear)
    logic [31:0] v2, v3, done;
    dmem_write(15, 32'd0);
    tb_use_loopback = 1'b1;
    run_program("prog_nb_cross_a1_b0.hex", 2000);
    dmem_read(2, v2); dmem_read(3, v3); dmem_read(15, done);
    `FAIL_UNLESS(done === 32'd1);
    `FAIL_UNLESS(v2 === 32'd1);                                   // flg_qpb: clear
    `FAIL_UNLESS(v3 === 32'd2);                                   // flg_qpa: set
`SVTEST_END

`SVTEST(tc_nb_flag_sources_do_not_cross_qpa_clear_qpb_set)
    logic [31:0] v2, v3, done;
    dmem_write(15, 32'd0);
    tb_use_loopback = 1'b1;
    run_program("prog_nb_cross_a0_b1.hex", 2000);
    dmem_read(2, v2); dmem_read(3, v3); dmem_read(15, done);
    `FAIL_UNLESS(done === 32'd1);
    `FAIL_UNLESS(v2 === 32'd2);                                   // flg_qpb: set
    `FAIL_UNLESS(v3 === 32'd1);                                   // flg_qpa: clear
`SVTEST_END

// Six PA (and six PB) back to back: every command reaches the peripheral; it takes what it can and drops the rest.
// (The notebook's step 6 asserts the same: taken + dropped == n, taken >= 1, the data of the operands.)
`SVTEST(tc_nb_busy_pa_x6)
    logic [31:0] v0, v1, done;
    dmem_write(15, 32'd0);
    tb_use_loopback = 1'b1;
    run_program("prog_nb_busy_a.hex", 1500);
    dmem_read(0, v0); dmem_read(1, v1); dmem_read(15, done);
    $display("nb_busy_a: taken %0d dropped %0d", lb1_cmd, lb1_drop);
    `FAIL_UNLESS(done === 32'd1);
    `FAIL_UNLESS(lb1_cmd + lb1_drop === 32'd6);
    `FAIL_UNLESS(lb1_cmd >= 32'd1);
    `FAIL_UNLESS(v0 === 32'd3000);
    `FAIL_UNLESS(v1 === (32'd3 ^ 32'd4 ^ 32'd9));
`SVTEST_END

`SVTEST(tc_nb_busy_pb_x6)
    logic [31:0] v0, v1, done;
    dmem_write(15, 32'd0);
    tb_use_loopback = 1'b1;
    run_program("prog_nb_busy_b.hex", 1500);
    dmem_read(0, v0); dmem_read(1, v1); dmem_read(15, done);
    $display("nb_busy_b: taken %0d dropped %0d", lb2_cmd, lb2_drop);
    `FAIL_UNLESS(done === 32'd1);
    `FAIL_UNLESS(lb2_cmd + lb2_drop === 32'd6);
    `FAIL_UNLESS(lb2_cmd >= 32'd1);
    `FAIL_UNLESS(v0 === 32'd3000);
    `FAIL_UNLESS(v1 === (32'd3 ^ 32'd4 ^ 32'd9));
`SVTEST_END

// ext_flag_i with flg_ext: the level, set before the start (also visible to the PS in TPROC_STATUS[15]).
`SVTEST(tc_nb_ext_flag_level_0)
    logic [31:0] v2, st, done;
    dmem_write(15, 32'd0);
    tb_ext_flag_i = 1'b0;
    run_program("prog_nb_ext_flag.hex", 600);
    dmem_read(2, v2); dmem_read(15, done);
    s_axi.axi_read(ADDR_STATUS, st);
    `FAIL_UNLESS(done === 32'd1);
    `FAIL_UNLESS(v2 === 32'd1);
    `FAIL_UNLESS(st[15] === 1'b0);
`SVTEST_END

`SVTEST(tc_nb_ext_flag_level_1)
    logic [31:0] v2, st, done;
    dmem_write(15, 32'd0);
    tb_ext_flag_i = 1'b1;
    run_program("prog_nb_ext_flag.hex", 600);
    dmem_read(2, v2); dmem_read(15, done);
    s_axi.axi_read(ADDR_STATUS, st);
    `FAIL_UNLESS(done === 32'd1);
    `FAIL_UNLESS(v2 === 32'd2);
    `FAIL_UNLESS(st[15] === 1'b1);
`SVTEST_END

// The program polls flg_ext in a loop; the testbench raises ext_flag_i after the start (through the core's synchronizer): the
// loop is still running before, and ends after, with a pass count > 0.
`SVTEST(tc_nb_ext_flag_edge_ends_the_poll_loop)
    logic [31:0] v0, done_before, done_after;
    int n;
    dmem_write(15, 32'd0);
    tb_ext_flag_i = 1'b0;
    load_program("prog_nb_ext_poll.hex", n);
    s_axi.axi_write(ADDR_TPROC_CTRL, 32'h0000_0004);
    repeat (400) @(posedge tb_clk);
    dmem_read(15, done_before);
    `FAIL_UNLESS(done_before === 32'd0);                          // still polling
    @(negedge tb_clk);
    tb_ext_flag_i = 1'b1;
    repeat (200) @(posedge tb_clk);
    dmem_read(15, done_after);
    dmem_read(0, v0);
    `FAIL_UNLESS(done_after === 32'd1);
    `FAIL_UNLESS(v0 > 32'd0);
`SVTEST_END

