// ============================================================================
// File: qproc_axi_reg_tc00.sv
// Description: SVUnit testbench top-level for qproc_axi_reg.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qproc_axi_reg_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "qproc_axi_reg_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Register byte-address map (see qproc_axi_reg.sv header)
    // =========================================================================
    localparam logic [31:0] ADDR_TPROC_CTRL   = 32'h00;
    localparam logic [31:0] ADDR_TPROC_CFG    = 32'h04;
    localparam logic [31:0] ADDR_MEM_ADDR     = 32'h08;
    localparam logic [31:0] ADDR_MEM_LEN      = 32'h0C;
    localparam logic [31:0] ADDR_MEM_DT_I     = 32'h10;
    localparam logic [31:0] ADDR_TPROC_W_DT1  = 32'h14;
    localparam logic [31:0] ADDR_TPROC_W_DT2  = 32'h18;
    localparam logic [31:0] ADDR_CORE_CFG     = 32'h1C;
    localparam logic [31:0] ADDR_READ_SEL     = 32'h20;
    localparam logic [31:0] ADDR_VERSION_ID   = 32'h24;
    localparam logic [31:0] ADDR_MEM_DT_O     = 32'h28;
    localparam logic [31:0] ADDR_TPROC_R_DT1  = 32'h2C;
    localparam logic [31:0] ADDR_TPROC_R_DT2  = 32'h30;
    localparam logic [31:0] ADDR_TIME_USR     = 32'h34;
    localparam logic [31:0] ADDR_TPROC_STATUS = 32'h38;
    localparam logic [31:0] ADDR_TPROC_DEBUG  = 32'h3C;

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;

    logic tb_clk   = 1'b0;
    logic tb_rstn  = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    // =========================================================================
    // AXI4-Lite interface
    // =========================================================================
    axi4_lite_if #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (32)
    ) axi_if (
        .aclk    (tb_clk),
        .aresetn (tb_rstn)
    );

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic [15:0] tb_tproc_ctrl_o;
    logic [15:0] tb_tproc_cfg_o;
    logic [15:0] tb_mem_addr_o;
    logic [15:0] tb_mem_len_o;
    logic [31:0] tb_mem_dt_i_o;
    logic [31:0] tb_tproc_w_dt1_o;
    logic [31:0] tb_tproc_w_dt2_o;
    logic [7:0]  tb_core_cfg_o;
    logic [7:0]  tb_read_sel_o;

    logic [31:0] tb_mem_dt_o_i     = '0;
    logic [31:0] tb_tproc_r_dt1_i  = '0;
    logic [31:0] tb_tproc_r_dt2_i  = '0;
    logic [31:0] tb_time_usr_i     = '0;
    logic [31:0] tb_tproc_status_i = '0;
    logic [31:0] tb_tproc_debug_i  = '0;

    initial begin
        $dumpfile("qproc_axi_reg.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    qproc_axi_reg u_dut (
        .ps_aclk        (tb_clk),
        .ps_aresetn     (tb_rstn),
        .s_axi          (axi_if),

        .tproc_ctrl_o   (tb_tproc_ctrl_o),
        .tproc_cfg_o    (tb_tproc_cfg_o),
        .mem_addr_o     (tb_mem_addr_o),
        .mem_len_o      (tb_mem_len_o),
        .mem_dt_i_o     (tb_mem_dt_i_o),
        .tproc_w_dt1_o  (tb_tproc_w_dt1_o),
        .tproc_w_dt2_o  (tb_tproc_w_dt2_o),
        .core_cfg_o     (tb_core_cfg_o),
        .read_sel_o     (tb_read_sel_o),

        .mem_dt_o_i     (tb_mem_dt_o_i),
        .tproc_r_dt1_i  (tb_tproc_r_dt1_i),
        .tproc_r_dt2_i  (tb_tproc_r_dt2_i),
        .time_usr_i     (tb_time_usr_i),
        .tproc_status_i (tb_tproc_status_i),
        .tproc_debug_i  (tb_tproc_debug_i)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic reset_dut();
        tb_rstn = 1'b0;
        repeat(10) @(posedge tb_clk);
        tb_rstn = 1'b1;
        axi_if.reset();
        repeat(5) @(posedge tb_clk);
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
    `include "qproc_axi_reg_tests.sv"
    `SVUNIT_TESTS_END

endmodule
