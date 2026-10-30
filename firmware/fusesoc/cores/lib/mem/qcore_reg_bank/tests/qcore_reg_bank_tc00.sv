// ============================================================================
// File: qcore_reg_bank_tc00.sv
// Description: SVUnit testbench top-level for qcore_reg_bank.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qcore_reg_bank_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "qcore_reg_bank_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  PMEM_AW = 8;
    localparam int  REG_AW  = 4;

    // Address-bank selectors used to build w_addr_i / rs_*_addr_i (see the
    // qcore_reg_bank header comment for the [6:5] bank encoding).
    localparam logic [6:0] ADDR_LFSR_STEP = 7'b000_0000;
    localparam logic [6:0] ADDR_LFSR_LOAD = 7'b000_0001;
    localparam logic [6:0] ADDR_SREG_CFG  = 7'b000_0010;

    function automatic logic [6:0] addr_sreg_special(input int idx); // idx 0..3 -> addr 12..15
        addr_sreg_special = 7'b000_1100 | idx[1:0];
    endfunction

    function automatic logic [6:0] addr_dreg(input int idx); // general data register bank (01_xxxxx)
        addr_dreg = {2'b01, 1'b0, idx[REG_AW-1:0]};
    endfunction

    function automatic logic [6:0] addr_wreg(input int idx); // wave param register bank (10_xxxxx)
        addr_wreg = {2'b10, 2'b00, idx[2:0]};
    endfunction

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
    logic         tb_halt_i    = 1'b0;
    logic         tb_clear_i   = 1'b0;
    logic [1:0]   tb_lfsr_cfg_i = 2'b00;
    logic [31:0]  tb_reg_arith_i = '0;
    logic [31:0]  tb_reg_div_i   [2] = '{default:'0};
    logic [31:0]  tb_reg_port_i  [2] = '{default:'0};
    logic [31:0]  tb_tproc_ext_i [2] = '{default:'0};
    logic [31:0]  tb_time_dt_i   = '0;
    logic [167:0] tb_wave_dt_i   = '0;
    logic [31:0]  tb_status_i    = '0;
    logic [7:0]   tb_reg_cfg_o;
    logic [7:0]   tb_reg_ctrl_o;
    logic         tb_wave_we_i = 1'b0;
    logic         tb_we_i      = 1'b0;
    logic [6:0]   tb_w_addr_i  = '0;
    logic [31:0]  tb_w_dt_i    = '0;
    logic [5:0]   tb_rs_A_addr_i[2] = '{default:'0};
    logic [6:0]   tb_rs_D_addr_i[2] = '{default:'0};
    logic [31:0]  tb_rs_D_dt_o[2];
    logic [31:0]  tb_rs_A_dt_o[2];
    logic [31:0]  tb_sreg_dt_o[2];
    logic [PMEM_AW-1:0] tb_out_addr_o;
    logic [31:0]  tb_out_time_o;
    logic [167:0] tb_out_wreg_o;
    logic [31:0]  tb_lfsr_o;

    initial begin
        $dumpfile("qcore_reg_bank.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    qcore_reg_bank #(
        .LFSR    (1),
        .PMEM_AW (PMEM_AW),
        .REG_AW  (REG_AW)
    ) u_dut (
        .clk_i       (tb_clk),
        .halt_i      (tb_halt_i),
        .rst_ni      (tb_rstn),
        .clear_i     (tb_clear_i),
        .lfsr_cfg_i  (tb_lfsr_cfg_i),
        .reg_arith_i (tb_reg_arith_i),
        .reg_div_i   (tb_reg_div_i),
        .reg_port_i  (tb_reg_port_i),
        .tproc_ext_i (tb_tproc_ext_i),
        .time_dt_i   (tb_time_dt_i),
        .wave_dt_i   (tb_wave_dt_i),
        .status_i    (tb_status_i),
        .reg_cfg_o   (tb_reg_cfg_o),
        .reg_ctrl_o  (tb_reg_ctrl_o),
        .wave_we_i   (tb_wave_we_i),
        .we_i        (tb_we_i),
        .w_addr_i    (tb_w_addr_i),
        .w_dt_i      (tb_w_dt_i),
        .rs_a_addr_i (tb_rs_A_addr_i),
        .rs_d_addr_i (tb_rs_D_addr_i),
        .rs_d_dt_o   (tb_rs_D_dt_o),
        .rs_a_dt_o   (tb_rs_A_dt_o),
        .sreg_dt_o   (tb_sreg_dt_o),
        .out_addr_o  (tb_out_addr_o),
        .out_time_o  (tb_out_time_o),
        .out_wreg_o  (tb_out_wreg_o),
        .lfsr_o      (tb_lfsr_o)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic reset_dut();
        tb_rstn      = 1'b0;
        tb_halt_i    = 1'b0;
        tb_clear_i   = 1'b0;
        tb_we_i      = 1'b0;
        tb_wave_we_i = 1'b0;
        tb_w_addr_i  = '0;
        tb_w_dt_i    = '0;
        tb_rs_A_addr_i = '{default:'0};
        tb_rs_D_addr_i = '{default:'0};
        repeat(5) @(posedge tb_clk);
        tb_rstn = 1'b1;
        repeat(2) @(posedge tb_clk);
    endtask

    // Single-cycle write on the w_addr_i/w_dt_i port.
    task automatic reg_write(input logic [6:0] addr, input logic [31:0] data);
        @(negedge tb_clk);
        tb_we_i     = 1'b1;
        tb_w_addr_i = addr;
        tb_w_dt_i   = data;
        @(negedge tb_clk);
        tb_we_i     = 1'b0;
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
    `include "qcore_reg_bank_tests.sv"
    `SVUNIT_TESTS_END

endmodule
