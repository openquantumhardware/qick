// ============================================================================
// File: qcore_ctrl_hazard_tc00.sv
// Description: SVUnit testbench top-level for qcore_ctrl_hazard.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qcore_ctrl_hazard_unit_test;
    import svunit_pkg::svunit_testcase;
    import tpv2_pkg::CTRL_REG;

    string name = "qcore_ctrl_hazard_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;

    localparam CTRL_REG NO_REG = '{we: 1'b0, r_wave_we: 1'b0, addr: 7'd0, src: 2'b00, port_re: 1'b0};

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic        tb_halt_i = 1'b0;
    logic [5:0]  tb_rs_a_addr_i [2] = '{default:'0};
    logic [31:0] tb_rs_a_dt_i   [2] = '{default:'0};
    logic [6:0]  tb_rs_d_addr_i [2] = '{default:'0};
    logic [31:0] tb_rs_d_dt_i   [2] = '{default:'0};

    CTRL_REG tb_id_reg_i = NO_REG;
    CTRL_REG tb_rd_reg_i = NO_REG;
    CTRL_REG tb_x1_reg_i = NO_REG;
    CTRL_REG tb_x2_reg_i = NO_REG;
    CTRL_REG tb_wr_reg_i = NO_REG;

    logic tb_rd_periph_use = 1'b0;
    logic tb_x1_periph_use = 1'b0;
    logic tb_x2_periph_use = 1'b0;

    logic tb_id_wmem_we   = 1'b0;
    logic tb_id_flag_used = 1'b0;
    logic tb_flag_we      = 1'b0;
    logic tb_id_jmp_i     = 1'b0;

    logic [31:0] tb_x1_alu_dt_i  = '0;
    logic [31:0] tb_x2_alu_dt_i  = '0;
    logic [31:0] tb_x2_dmem_dt_i = '0;
    logic [31:0] tb_rd_imm_dt_i  = '0;
    logic [31:0] tb_x1_imm_dt_i  = '0;
    logic [31:0] tb_x2_imm_dt_i  = '0;

    logic [31:0] tb_reg_a_dt_o [2];
    logic [31:0] tb_reg_d_dt_o [2];
    logic        tb_bubble_id_o;
    logic        tb_bubble_rd_o;

    initial begin
        $dumpfile("qcore_ctrl_hazard.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    qcore_ctrl_hazard u_dut (
        .clk_i          (tb_clk),
        .rst_ni         (tb_rstn),
        .halt_i         (tb_halt_i),
        .rs_a_addr_i    (tb_rs_a_addr_i),
        .rs_a_dt_i      (tb_rs_a_dt_i),
        .rs_d_addr_i    (tb_rs_d_addr_i),
        .rs_d_dt_i      (tb_rs_d_dt_i),
        .id_reg_i       (tb_id_reg_i),
        .rd_reg_i       (tb_rd_reg_i),
        .x1_reg_i       (tb_x1_reg_i),
        .x2_reg_i       (tb_x2_reg_i),
        .wr_reg_i       (tb_wr_reg_i),
        .rd_periph_use  (tb_rd_periph_use),
        .x1_periph_use  (tb_x1_periph_use),
        .x2_periph_use  (tb_x2_periph_use),
        .id_wmem_we     (tb_id_wmem_we),
        .id_flag_used   (tb_id_flag_used),
        .flag_we        (tb_flag_we),
        .id_jmp_i       (tb_id_jmp_i),
        .x1_alu_dt_i    (tb_x1_alu_dt_i),
        .x2_alu_dt_i    (tb_x2_alu_dt_i),
        .x2_dmem_dt_i   (tb_x2_dmem_dt_i),
        .rd_imm_dt_i    (tb_rd_imm_dt_i),
        .x1_imm_dt_i    (tb_x1_imm_dt_i),
        .x2_imm_dt_i    (tb_x2_imm_dt_i),
        .reg_a_dt_o     (tb_reg_a_dt_o),
        .reg_d_dt_o     (tb_reg_d_dt_o),
        .bubble_id_o    (tb_bubble_id_o),
        .bubble_rd_o    (tb_bubble_rd_o)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic reset_dut();
        tb_halt_i        = 1'b0;
        tb_rs_a_addr_i   = '{default:'0};
        tb_rs_a_dt_i     = '{default:'0};
        tb_rs_d_addr_i   = '{default:'0};
        tb_rs_d_dt_i     = '{default:'0};
        tb_id_reg_i      = NO_REG;
        tb_rd_reg_i      = NO_REG;
        tb_x1_reg_i      = NO_REG;
        tb_x2_reg_i      = NO_REG;
        tb_wr_reg_i      = NO_REG;
        tb_rd_periph_use = 1'b0;
        tb_x1_periph_use = 1'b0;
        tb_x2_periph_use = 1'b0;
        tb_id_wmem_we    = 1'b0;
        tb_id_flag_used  = 1'b0;
        tb_flag_we       = 1'b0;
        tb_id_jmp_i      = 1'b0;
        tb_rstn = 1'b0;
        repeat(5) @(posedge tb_clk);
        tb_rstn = 1'b1;
        repeat(2) @(posedge tb_clk);
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
    `include "qcore_ctrl_hazard_tests.sv"
    `SVUNIT_TESTS_END

endmodule
