// ============================================================================
// File: qcore_mem_tc00.sv
// Description: SVUnit testbench top-level for qcore_mem.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qcore_mem_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "qcore_mem_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  PMEM_AW = 8;
    localparam int  DMEM_AW = 8;
    localparam int  WMEM_AW = 8;

    localparam logic [1:0] SEL_NONE = 2'b00;
    localparam logic [1:0] SEL_PMEM = 2'b01;
    localparam logic [1:0] SEL_DMEM = 2'b10;
    localparam logic [1:0] SEL_WMEM = 2'b11;

    // =========================================================================
    // Clock & Reset (single clock drives both domains for the testbench)
    // =========================================================================
    logic tb_clk   = 1'b0;
    logic tb_c_rstn  = 1'b1;
    logic tb_ps_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic [1:0]   tb_ps_sel_i  = SEL_NONE;
    logic         tb_ps_we_i   = 1'b0;
    logic [15:0]  tb_ps_addr_i = '0;
    logic [167:0] tb_ps_w_dt_i = '0;
    logic [167:0] tb_ps_r_dt_o;

    logic                tb_c_pmem_en_i   = 1'b0;
    logic [PMEM_AW-1:0]  tb_c_pmem_addr_i = '0;
    logic [71:0]         tb_c_pmem_r_dt_o;

    logic                tb_c_dmem_we_i   = 1'b0;
    logic [DMEM_AW-1:0]  tb_c_dmem_addr_i = '0;
    logic [31:0]         tb_c_dmem_w_dt_i = '0;
    logic [31:0]         tb_c_dmem_r_dt_o;

    logic                tb_c_wmem_we_i   = 1'b0;
    logic [WMEM_AW-1:0]  tb_c_wmem_addr_i = '0;
    logic [167:0]        tb_c_wmem_w_dt_i = '0;
    logic [167:0]        tb_c_wmem_r_dt_o;

    initial begin
        $dumpfile("qcore_mem.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    qcore_mem #(
        .PMEM_AW (PMEM_AW),
        .DMEM_AW (DMEM_AW),
        .WMEM_AW (WMEM_AW)
    ) u_dut (
        .c_clk_i       (tb_clk),
        .c_rst_ni      (tb_c_rstn),
        .ps_clk_i      (tb_clk),
        .ps_rst_ni     (tb_ps_rstn),
        .ps_sel_i      (tb_ps_sel_i),
        .ps_we_i       (tb_ps_we_i),
        .ps_addr_i     (tb_ps_addr_i),
        .ps_w_dt_i     (tb_ps_w_dt_i),
        .ps_r_dt_o     (tb_ps_r_dt_o),

        .c_pmem_en_i   (tb_c_pmem_en_i),
        .c_pmem_addr_i (tb_c_pmem_addr_i),
        .c_pmem_r_dt_o (tb_c_pmem_r_dt_o),

        .c_dmem_we_i   (tb_c_dmem_we_i),
        .c_dmem_addr_i (tb_c_dmem_addr_i),
        .c_dmem_w_dt_i (tb_c_dmem_w_dt_i),
        .c_dmem_r_dt_o (tb_c_dmem_r_dt_o),

        .c_wmem_we_i   (tb_c_wmem_we_i),
        .c_wmem_addr_i (tb_c_wmem_addr_i),
        .c_wmem_w_dt_i (tb_c_wmem_w_dt_i),
        .c_wmem_r_dt_o (tb_c_wmem_r_dt_o)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic reset_dut();
        tb_c_rstn    = 1'b0;
        tb_ps_rstn   = 1'b0;
        tb_ps_sel_i  = SEL_NONE;
        tb_ps_we_i   = 1'b0;
        tb_c_pmem_en_i = 1'b0;
        tb_c_dmem_we_i = 1'b0;
        tb_c_wmem_we_i = 1'b0;
        repeat(10) @(posedge tb_clk);
        tb_c_rstn  = 1'b1;
        tb_ps_rstn = 1'b1;
        repeat(5) @(posedge tb_clk);
    endtask

    // Single-cycle write via the PS (port B) side.
    task automatic ps_write(input logic [1:0] sel, input logic [15:0] addr, input logic [167:0] data);
        @(negedge tb_clk);
        tb_ps_sel_i  = sel;
        tb_ps_we_i   = 1'b1;
        tb_ps_addr_i = addr;
        tb_ps_w_dt_i = data;
        @(negedge tb_clk);
        tb_ps_we_i   = 1'b0;
        tb_ps_sel_i  = SEL_NONE;
    endtask

    // Present a PS-side read address for `sel`/`addr` and wait for the 1-cycle
    // BRAM read latency; leaves ps_sel_i asserted so ps_r_dt_o stays valid.
    task automatic ps_read(input logic [1:0] sel, input logic [15:0] addr);
        @(negedge tb_clk);
        tb_ps_sel_i  = sel;
        tb_ps_we_i   = 1'b0;
        tb_ps_addr_i = addr;
        @(negedge tb_clk); // BRAM read latency.
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
    `include "qcore_mem_tests.sv"
    `SVUNIT_TESTS_END

endmodule
