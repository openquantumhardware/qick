// ============================================================================
// File: qcore_cpu_tc00.sv
// Description: SVUnit testbench top-level for qcore_cpu.
//
// Drives the CPU with a tiny combinational program-memory model
// (pmem_dt_i = rom[pmem_addr_o], zero latency) so instruction words can be
// hand-encoded per the qcore_cpu header format:
//   op_code[15:13]=header  [12]=ai  [11:10]=df  [9:7]=cond  [6]=so  [5]=to
//   op_data[55:45]=imm_addr/rs_a[0]  [44:39]=rs_a[1]  [37:31]=rs_d[0]
//   [29:23]=rs_d[1]  [6:0]=rd_addr
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qcore_cpu_unit_test;
    import svunit_pkg::svunit_testcase;
    import tpv2_pkg::CFG;
    import tpv2_pkg::BRANCH;
    import tpv2_pkg::MEM_WR;
    import tpv2_pkg::PORT_DT;

    string name = "qcore_cpu_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  PMEM_AW = 8;
    localparam int  DMEM_AW = 8;
    localparam int  WMEM_AW = 8;

    // =========================================================================
    // Clock & reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    // =========================================================================
    // Combinational program-memory model
    // =========================================================================
    logic [71:0] pmem_rom [2**PMEM_AW];

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic        tb_restart_i = 1'b0;
    logic        tb_en_i      = 1'b0;
    logic [1:0]  tb_lfsr_cfg_i = 2'b00;
    logic [31:0] tb_lfsr_o;
    logic [31:0] tb_core_do;
    logic        tb_flag_i = 1'b0;

    logic [7:0]  tb_sreg_cfg_o, tb_sreg_ctrl_o;
    logic [31:0] tb_sreg_arith_i     = '0;
    logic [31:0] tb_sreg_div_i   [2] = '{default:'0};
    logic [31:0] tb_sreg_status_i   = '0;
    logic [31:0] tb_sreg_core_r_dt_i[2] = '{default:'0};
    logic [31:0] tb_sreg_port_dt_i  [2] = '{default:'0};
    logic [31:0] tb_sreg_time_dt_i  = '0;
    logic [31:0] tb_sreg_core_w_dt_o[2];

    logic        tb_usr_en_o;
    logic [7:0]  tb_usr_ctrl_o;
    logic [31:0] tb_usr_dt_a_o, tb_usr_dt_b_o, tb_usr_dt_c_o, tb_usr_dt_d_o;

    logic [PMEM_AW-1:0] tb_pmem_addr_o;
    logic                tb_pmem_en_o;
    logic [71:0]         tb_pmem_dt_i;

    logic                tb_dmem_we_o;
    logic [DMEM_AW-1:0]  tb_dmem_addr_o;
    logic [31:0]         tb_dmem_w_dt_o;
    logic [31:0]         tb_dmem_r_dt_i = '0;

    logic                 tb_wmem_we_o;
    logic [WMEM_AW-1:0]   tb_wmem_addr_o;
    logic [167:0]         tb_wmem_w_dt_o;
    logic [167:0]         tb_wmem_r_dt_i = '0;

    logic     tb_port_we_o, tb_port_re_o;
    PORT_DT   tb_port_o;

    assign tb_pmem_dt_i = pmem_rom[tb_pmem_addr_o];

    initial begin
        $dumpfile("qcore_cpu.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    qcore_cpu #(
        .LFSR    (1),
        .PMEM_AW (PMEM_AW),
        .DMEM_AW (DMEM_AW),
        .WMEM_AW (WMEM_AW),
        .REG_AW  (4)
    ) u_dut (
        .clk_i        (tb_clk),
        .rst_ni       (tb_rstn),
        .restart_i    (tb_restart_i),
        .en_i         (tb_en_i),
        .lfsr_cfg_i   (tb_lfsr_cfg_i),
        .lfsr_o       (tb_lfsr_o),
        .core_do      (tb_core_do),
        .flag_i       (tb_flag_i),
        .sreg_cfg_o        (tb_sreg_cfg_o),
        .sreg_ctrl_o       (tb_sreg_ctrl_o),
        .sreg_arith_i      (tb_sreg_arith_i),
        .sreg_div_i        (tb_sreg_div_i),
        .sreg_status_i     (tb_sreg_status_i),
        .sreg_core_r_dt_i  (tb_sreg_core_r_dt_i),
        .sreg_port_dt_i    (tb_sreg_port_dt_i),
        .sreg_time_dt_i    (tb_sreg_time_dt_i),
        .sreg_core_w_dt_o  (tb_sreg_core_w_dt_o),
        .usr_en_o   (tb_usr_en_o),
        .usr_ctrl_o (tb_usr_ctrl_o),
        .usr_dt_a_o (tb_usr_dt_a_o),
        .usr_dt_b_o (tb_usr_dt_b_o),
        .usr_dt_c_o (tb_usr_dt_c_o),
        .usr_dt_d_o (tb_usr_dt_d_o),
        .pmem_addr_o (tb_pmem_addr_o),
        .pmem_en_o   (tb_pmem_en_o),
        .pmem_dt_i   (tb_pmem_dt_i),
        .dmem_we_o   (tb_dmem_we_o),
        .dmem_addr_o (tb_dmem_addr_o),
        .dmem_w_dt_o (tb_dmem_w_dt_o),
        .dmem_r_dt_i (tb_dmem_r_dt_i),
        .wmem_we_o   (tb_wmem_we_o),
        .wmem_addr_o (tb_wmem_addr_o),
        .wmem_w_dt_o (tb_wmem_w_dt_o),
        .wmem_r_dt_i (tb_wmem_r_dt_i),
        .port_we_o (tb_port_we_o),
        .port_re_o (tb_port_re_o),
        .port_o    (tb_port_o)
    );

    // =========================================================================
    // Instruction encoders
    // =========================================================================
    // MEM_WR, DF=00, SO=0,TO=1 (write-data-memory, data forced to the DF=00
    // immediate = imm11, address = ai ? imm11 : rs_a[0]+rs_a[1] (both 0)).
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

    // All-zero word: header=CFG(000), cond=ALWAYS -> decodes to a harmless,
    // no-hazard "config" instruction (acts as a NOP for these tests).
    localparam logic [71:0] NOP_WORD = 72'd0;

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic reset_dut();
        tb_rstn      = 1'b0;
        tb_restart_i = 1'b0;
        tb_en_i      = 1'b0;
        pmem_rom     = '{default: NOP_WORD};
        repeat(5) @(posedge tb_clk);
        tb_rstn = 1'b1;
        repeat(2) @(posedge tb_clk);
    endtask

    // Polls dmem_we_o for up to max_cycles clocks; returns the addr/data seen
    // on the cycle it first asserts (or 'x/'x on timeout).
    task automatic wait_for_dmem_we(output logic [DMEM_AW-1:0] addr, output logic [31:0] data,
                                     input int max_cycles = 20);
        addr = 'x;
        data = 'x;
        for (int n = 0; n < max_cycles; n++) begin
            @(posedge tb_clk);
            if (tb_dmem_we_o) begin
                addr = tb_dmem_addr_o;
                data = tb_dmem_w_dt_o;
                return;
            end
        end
    endtask

    // Polls pmem_addr_o for up to max_cycles clocks; returns 1 if it reached
    // `target`, 0 on timeout.
    task automatic wait_for_pc(input logic [PMEM_AW-1:0] target, output bit reached,
                               input int max_cycles = 20);
        reached = 1'b0;
        for (int n = 0; n < max_cycles; n++) begin
            @(posedge tb_clk);
            if (tb_pmem_addr_o == target) begin
                reached = 1'b1;
                return;
            end
        end
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
    `include "qcore_cpu_tests.sv"
    `SVUNIT_TESTS_END

endmodule
