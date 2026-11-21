// ============================================================================
// File: qproc_core_tc00.sv
// Description: SVUnit testbench top-level for qproc_core.
//
// Loads/reads PMEM and DMEM through the PS-side memory port (ps_mem_*,
// same encoding as qcore_mem: SEL_NONE=00, SEL_PMEM=01, SEL_DMEM=10,
// SEL_WMEM=11) to exercise the full loop: PS loads a program -> qcore_cpu
// fetches/executes it -> qcore_mem's DMEM write is readable back via the
// PS port. Instruction words use the same hand-encoding as qcore_cpu's own
// testbench (see its header for the exact bit layout).
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qproc_core_unit_test;
    import svunit_pkg::svunit_testcase;
    import tpv2_pkg::BRANCH;
    import tpv2_pkg::MEM_WR;
    import tpv2_pkg::PORT_WR;
    import tpv2_pkg::PORT_DT;

    string name = "qproc_core_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  IN_PORT_QTY = 1;
    localparam int  PMEM_AW = 8;
    localparam int  DMEM_AW = 8;
    localparam int  WMEM_AW = 8;

    localparam logic [1:0] SEL_NONE = 2'b00;
    localparam logic [1:0] SEL_PMEM = 2'b01;
    localparam logic [1:0] SEL_DMEM = 2'b10;
    localparam logic [1:0] SEL_WMEM = 2'b11;

    // =========================================================================
    // Clock & reset (single clock drives c_clk_i/ps_clk_i, like qcore_mem's TB)
    // =========================================================================
    logic tb_clk    = 1'b0;
    logic tb_c_rstn  = 1'b1;
    logic tb_ps_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic tb_en_i      = 1'b0;
    logic tb_restart_i = 1'b0;
    logic [1:0]  tb_lfsr_cfg_i = 2'b00;
    logic [31:0] tb_core_status_o, tb_core_debug_o, tb_lfsr_o;

    logic [63:0] tb_port_dt_i [IN_PORT_QTY] = '{default: '0};
    logic        tb_flag_i = 1'b0;

    logic [7:0]  tb_sreg_cfg_o, tb_sreg_ctrl_o;
    logic [31:0] tb_sreg_arith_i        = '0;
    logic [31:0] tb_sreg_div_i      [2] = '{default: '0};
    logic [31:0] tb_sreg_status_i       = '0;
    logic [31:0] tb_sreg_core_r_dt_i[2] = '{default: '0};
    logic [31:0] tb_sreg_time_dt_i      = '0;
    logic [31:0] tb_sreg_core_w_dt_o[2];

    logic        tb_usr_en_o;
    logic [7:0]  tb_usr_ctrl_o;
    logic [31:0] tb_usr_dt_a_o, tb_usr_dt_b_o, tb_usr_dt_c_o, tb_usr_dt_d_o;

    logic [1:0]   tb_ps_mem_sel_i  = SEL_NONE;
    logic         tb_ps_mem_we_i   = 1'b0;
    logic [15:0]  tb_ps_mem_addr_i = '0;
    logic [167:0] tb_ps_mem_w_dt_i = '0;
    logic [167:0] tb_ps_mem_r_dt_o;

    logic   tb_port_we_o;
    PORT_DT tb_port_o;
    logic [31:0] tb_core_do;

    initial begin
        $dumpfile("qproc_core.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    qproc_core #(
        .LFSR        (1),
        .IN_PORT_QTY (IN_PORT_QTY),
        .PMEM_AW     (PMEM_AW),
        .DMEM_AW     (DMEM_AW),
        .WMEM_AW     (WMEM_AW),
        .REG_AW      (4)
    ) u_dut (
        .c_clk_i   (tb_clk),
        .c_rst_ni  (tb_c_rstn),
        .ps_clk_i  (tb_clk),
        .ps_rst_ni (tb_ps_rstn),
        .en_i      (tb_en_i),
        .restart_i (tb_restart_i),
        .lfsr_cfg_i (tb_lfsr_cfg_i),
        .core_status_o (tb_core_status_o),
        .core_debug_o  (tb_core_debug_o),
        .lfsr_o        (tb_lfsr_o),
        .port_dt_i (tb_port_dt_i),
        .flag_i    (tb_flag_i),
        .sreg_cfg_o       (tb_sreg_cfg_o),
        .sreg_ctrl_o      (tb_sreg_ctrl_o),
        .sreg_arith_i     (tb_sreg_arith_i),
        .sreg_div_i       (tb_sreg_div_i),
        .sreg_status_i    (tb_sreg_status_i),
        .sreg_core_r_dt_i (tb_sreg_core_r_dt_i),
        .sreg_time_dt_i   (tb_sreg_time_dt_i),
        .sreg_core_w_dt_o (tb_sreg_core_w_dt_o),
        .usr_en_o   (tb_usr_en_o),
        .usr_ctrl_o (tb_usr_ctrl_o),
        .usr_dt_a_o (tb_usr_dt_a_o),
        .usr_dt_b_o (tb_usr_dt_b_o),
        .usr_dt_c_o (tb_usr_dt_c_o),
        .usr_dt_d_o (tb_usr_dt_d_o),
        .ps_mem_sel_i  (tb_ps_mem_sel_i),
        .ps_mem_we_i   (tb_ps_mem_we_i),
        .ps_mem_addr_i (tb_ps_mem_addr_i),
        .ps_mem_w_dt_i (tb_ps_mem_w_dt_i),
        .ps_mem_r_dt_o (tb_ps_mem_r_dt_o),
        .port_we_o (tb_port_we_o),
        .port_o    (tb_port_o),
        .core_do   (tb_core_do)
    );

    // =========================================================================
    // Instruction encoder (mirrors qcore_cpu's testbench)
    // =========================================================================
    // MEM_WR, DF=00, SO=0,TO=1: data forced to the DF=00 immediate = imm11,
    // address = ai ? imm11 : rs_a[0]+rs_a[1] (both 0 here).
    function automatic logic [71:0] mk_store_imm(input logic ai_bit, input logic [10:0] imm11);
        logic [15:0] op_code;
        logic [55:0] op_data;
        op_code = {MEM_WR, ai_bit, 2'b00, 3'b000, 1'b0, 1'b1, 5'b0};
        op_data = {imm11, 45'b0};
        mk_store_imm = {op_code, op_data};
    endfunction

    // BRANCH, AI=1 (jump to immediate), COND=ALWAYS, SO=0,TO=0 (not RET).
    function automatic logic [71:0] mk_branch_imm(input logic [10:0] target);
        logic [15:0] op_code;
        logic [55:0] op_data;
        op_code = {BRANCH, 1'b1, 2'b00, 3'b000, 1'b0, 1'b0, 5'b0};
        op_data = {target, 45'b0};
        mk_branch_imm = {op_code, op_data};
    endfunction

    // WPORT_WR with an immediate time (TO=1), as the Python assembler emits
    // it (`WPORT_WR p<port> wmem [&<wmem_addr>] @<time_v>` for use_r_wave=0,
    // `WPORT_WR p<port> r_wave @<time_v>` for use_r_wave=1):
    //   [71:56] op_code = PORT_WR, AI, DF=11, COND={Ww,Sp,Wp}, SO=1, TO=1, 5'b0
    //   [55:45] rsA0 = wmem address (0 for r_wave), [44:39] rsA1 = port,
    //   [38:7]  time, [6:0] RD = 0
    // tc_wport_wr_encoder_matches_assembler pins it to the assembler's words.
    function automatic logic [71:0] mk_wport_wr(input logic use_r_wave, input logic [5:0] port,
                                                input logic [10:0] wmem_addr, input logic [31:0] time_v);
        logic [15:0] op_code;
        logic [55:0] op_data;
        if (use_r_wave) op_code = {PORT_WR, 1'b0, 2'b11, 3'b011, 1'b1, 1'b1, 5'b0};
        else            op_code = {PORT_WR, 1'b1, 2'b11, 3'b001, 1'b1, 1'b1, 5'b0};
        op_data = {use_r_wave ? 11'd0 : wmem_addr, port, time_v, 7'd0};
        mk_wport_wr = {op_code, op_data};
    endfunction

    // The words the QICK software actually emits (asm_v2.py -> the assembler):
    //   pulse            WPORT_WR p<port> wmem [&<addr>]   (no @time: uses s_time)
    //   trigger set/clr  TRIG set|clr p<port>
    //   register write   REG_WR r1 imm #5
    function automatic logic [71:0] mk_pulse(input logic [5:0] port, input logic [10:0] wmem_addr);
        mk_pulse = {16'hdcc0, wmem_addr, port, 39'd0};
    endfunction
    function automatic logic [71:0] mk_trig(input logic set_not_clr, input logic [4:0] port);
        mk_trig = {16'hdd80, 10'd0, set_not_clr, 1'b1, port, 39'd0};
    endfunction
    localparam logic [71:0] REG_WR_R1_IMM5 = 72'h8c60000000000002a1;

    // All-zero word: header=CFG, cond=ALWAYS -> NOP (also what the assembler
    // puts at address 0 of every program).
    localparam logic [71:0] NOP_WORD = 72'd0;

    // =========================================================================
    // Port-write monitor: every cycle in which the core asserts port_we_o,
    // with the cycle number (relative to en_i going high), the port and the
    // time operand. Sampled at the falling edge (the DUT's outputs are stable
    // there, and the stimulus is driven there too: ps_* tasks and en_i).
    // =========================================================================
    int unsigned cyc = 0;
    always @(posedge tb_clk) cyc <= cyc + 1;

    bit          mon_en = 1'b0;
    int unsigned mon_t0 = 0;
    int          we_cyc  [$];
    logic [5:0]  we_port [$];
    logic [31:0] we_time [$];
    bit          we_type [$];   // PORT_DT.p_type: 0 = WAVE, 1 = DATA/TRIG
    logic [167:0] we_data [$];  // PORT_DT.p_data (the wave word for a WPORT_WR)

    always @(negedge tb_clk) begin
        if (mon_en && tb_port_we_o) begin
            we_cyc.push_back(int'(cyc - mon_t0));
            we_port.push_back(tb_port_o.p_addr);
            we_time.push_back(tb_port_o.p_time);
            we_type.push_back(tb_port_o.p_type);
            we_data.push_back(tb_port_o.p_data);
        end
    end

    // Programs of the instruction-cost table (generated, see the header of the file)
    `include "qproc_core_cost_progs.svh"

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic reset_dut();
        tb_en_i      = 1'b0;
        tb_restart_i = 1'b0;
        tb_ps_mem_sel_i  = SEL_NONE;
        tb_ps_mem_we_i   = 1'b0;
        tb_ps_mem_addr_i = '0;
        tb_ps_mem_w_dt_i = '0;
        tb_c_rstn  = 1'b0;
        tb_ps_rstn = 1'b0;
        repeat(10) @(posedge tb_clk);
        tb_c_rstn  = 1'b1;
        tb_ps_rstn = 1'b1;
        repeat(5) @(posedge tb_clk);
    endtask

    task automatic ps_write(input logic [1:0] sel, input logic [15:0] addr, input logic [167:0] data);
        @(negedge tb_clk);
        tb_ps_mem_sel_i  = sel;
        tb_ps_mem_we_i   = 1'b1;
        tb_ps_mem_addr_i = addr;
        tb_ps_mem_w_dt_i = data;
        @(negedge tb_clk);
        tb_ps_mem_we_i  = 1'b0;
        tb_ps_mem_sel_i = SEL_NONE;
    endtask

    // Loads `prog` at PMEM address 0, starts the core and watches port_we_o
    // for run_cycles clocks. Results are in we_cyc/we_port/we_time.
    task automatic run_prog(input logic [71:0] prog[$], input int run_cycles);
        mon_en = 1'b0;
        we_cyc.delete();
        we_port.delete();
        we_time.delete();
        we_type.delete();
        we_data.delete();
        foreach (prog[i]) ps_write(SEL_PMEM, 16'(i), {96'd0, prog[i]});
        @(negedge tb_clk);
        mon_t0 = cyc;
        mon_en = 1'b1;
        tb_en_i = 1'b1;
        repeat (run_cycles) @(negedge tb_clk);
        tb_en_i = 1'b0;
        mon_en  = 1'b0;
    endtask

    // Builds NOP, then n WPORT_WR (time operand 10, 20, ...; port = 0, or
    // the write index when rotate_ports; wmem [&0] or r_wave), each followed by
    // nops_between NOPs, then a jump-to-self so the core parks.
    function automatic void build_train(ref logic [71:0] prog[$], input int n, input bit use_r_wave,
                                        input bit rotate_ports, input int nops_between);
        prog.delete();
        prog.push_back(NOP_WORD);
        for (int i = 0; i < n; i++) begin
            prog.push_back(mk_wport_wr(use_r_wave, rotate_ports ? 6'(i) : 6'd0, 11'd0, 32'(10 * (i + 1))));
            for (int k = 0; k < nops_between; k++) prog.push_back(NOP_WORD);
        end
        prog.push_back(mk_branch_imm(11'(prog.size())));
    endfunction

    // Collapses the per-cycle events into one entry per distinct write (the
    // time operand is unique per write): first cycle, cycles port_we_o stayed
    // high, port and time.
    int          wr_first [$];
    int          wr_len   [$];
    logic [5:0]  wr_port  [$];
    logic [31:0] wr_time  [$];

    function automatic void group_writes();
        wr_first.delete(); wr_len.delete(); wr_port.delete(); wr_time.delete();
        foreach (we_cyc[i]) begin
            if (wr_time.size() > 0 && we_time[i] === wr_time[$] && we_port[i] === wr_port[$]
                && we_cyc[i] == wr_first[$] + wr_len[$]) begin
                wr_len[$] = wr_len[$] + 1;
            end else begin
                wr_first.push_back(we_cyc[i]);
                wr_len.push_back(1);
                wr_port.push_back(we_port[i]);
                wr_time.push_back(we_time[i]);
            end
        end
    endfunction

    // One line per run: label, then cycle-of-first-assertion per write and the
    // spacing between consecutive writes. Grep for WPORT_RATE.
    function automatic void print_writes(input string label);
        string line, sp;
        line = $sformatf("WPORT_RATE %-34s n=%0d first@", label, wr_first.size());
        foreach (wr_first[i]) line = {line, $sformatf(" %0d", wr_first[i])};
        sp = "";
        for (int i = 1; i < wr_first.size(); i++) sp = {sp, $sformatf(" %0d", wr_first[i] - wr_first[i-1])};
        line = {line, " | spacing:", sp};
        $display("%s", line);
    endfunction

    // Raw view: every cycle port_we_o was high, as cycle:{W|D}port, and the
    // spacing between consecutive events. W = wave port write, D = data/trigger.
    function automatic void print_events(input string label);
        string line, sp;
        line = $sformatf("WPORT_RATE %-34s n=%0d ev@", label, we_cyc.size());
        foreach (we_cyc[i]) line = {line, $sformatf(" %0d:%s%0d", we_cyc[i], we_type[i] ? "D" : "W", we_port[i])};
        sp = "";
        for (int i = 1; i < we_cyc.size(); i++) sp = {sp, $sformatf(" %0d", we_cyc[i] - we_cyc[i-1])};
        line = {line, " | spacing:", sp};
        $display("%s", line);
    endfunction

    // True when every spacing between consecutive port-write events is v.
    function automatic bit spacing_all_eq(input int v);
        spacing_all_eq = (we_cyc.size() > 1);
        for (int i = 1; i < we_cyc.size(); i++)
            if (we_cyc[i] - we_cyc[i-1] != v) spacing_all_eq = 1'b0;
    endfunction

    // Largest spacing between consecutive port-write events (0 with fewer than 2).
    function automatic int spacing_max();
        spacing_max = 0;
        for (int i = 1; i < we_cyc.size(); i++)
            if (we_cyc[i] - we_cyc[i-1] > spacing_max) spacing_max = we_cyc[i] - we_cyc[i-1];
    endfunction

    task automatic ps_read(input logic [1:0] sel, input logic [15:0] addr);
        @(negedge tb_clk);
        tb_ps_mem_sel_i  = sel;
        tb_ps_mem_we_i   = 1'b0;
        tb_ps_mem_addr_i = addr;
        @(negedge tb_clk); // BRAM read latency
    endtask

    // =========================================================================
    // SVUnit build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "qproc_core_tests.sv"
    `SVUNIT_TESTS_END

endmodule
