// ============================================================================
// File: qproc_mem_ctrl_tc00.sv
// Description: SVUnit testbench top-level for qproc_mem_ctrl.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qproc_mem_ctrl_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "qproc_mem_ctrl_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;

    // mem_sel encodings
    localparam logic [1:0] SEL_PMEM = 2'b01;
    localparam logic [1:0] SEL_DMEM = 2'b10;
    localparam logic [1:0] SEL_WMEM = 2'b11;

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
    logic [1:0]   tb_ext_core_sel_o;
    logic [1:0]   tb_ext_mem_sel_o;
    logic         tb_ext_mem_we_o;
    logic [15:0]  tb_ext_mem_addr_o;
    logic [167:0] tb_ext_mem_w_dt_o;
    logic [167:0] tb_ext_mem_r_dt_i = '0;

    logic [255:0] tb_s_axis_tdata_i  = '0;
    logic         tb_s_axis_tlast_i  = 1'b0;
    logic         tb_s_axis_tvalid_i = 1'b0;
    logic         tb_s_axis_tready_o;

    logic [255:0] tb_m_axis_tdata_o;
    logic         tb_m_axis_tlast_o;
    logic         tb_m_axis_tvalid_o;
    logic         tb_m_axis_tready_i = 1'b1;

    logic [6:0]   tb_mem_ctrl = '0;
    logic [15:0]  tb_mem_addr = '0;
    logic [15:0]  tb_mem_len  = '0;
    logic [31:0]  tb_mem_dt_i = '0;
    logic [31:0]  tb_mem_dt_o;
    logic [31:0]  tb_debug_o;

    logic         tb_busy_o;
    logic         tb_end_single_o;

    initial begin
        $dumpfile("qproc_mem_ctrl.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    qproc_mem_ctrl u_dut (
        .clk             (tb_clk),
        .rstn            (tb_rstn),
        .ext_core_sel_o  (tb_ext_core_sel_o),
        .ext_mem_sel_o   (tb_ext_mem_sel_o),
        .ext_mem_we_o    (tb_ext_mem_we_o),
        .ext_mem_addr_o  (tb_ext_mem_addr_o),
        .ext_mem_w_dt_o  (tb_ext_mem_w_dt_o),
        .ext_mem_r_dt_i  (tb_ext_mem_r_dt_i),
        .s_axis_tdata_i  (tb_s_axis_tdata_i),
        .s_axis_tlast_i  (tb_s_axis_tlast_i),
        .s_axis_tvalid_i (tb_s_axis_tvalid_i),
        .s_axis_tready_o (tb_s_axis_tready_o),
        .m_axis_tdata_o  (tb_m_axis_tdata_o),
        .m_axis_tlast_o  (tb_m_axis_tlast_o),
        .m_axis_tvalid_o (tb_m_axis_tvalid_o),
        .m_axis_tready_i (tb_m_axis_tready_i),
        .mem_ctrl        (tb_mem_ctrl),
        .mem_addr        (tb_mem_addr),
        .mem_len         (tb_mem_len),
        .mem_dt_i        (tb_mem_dt_i),
        .mem_dt_o        (tb_mem_dt_o),
        .debug_o         (tb_debug_o),
        .busy_o          (tb_busy_o),
        .end_single_o    (tb_end_single_o)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic reset_dut();
        tb_rstn       = 1'b0;
        tb_mem_ctrl   = '0;
        tb_mem_addr   = '0;
        tb_mem_len    = '0;
        tb_mem_dt_i   = '0;
        tb_ext_mem_r_dt_i  = '0;
        tb_s_axis_tvalid_i = 1'b0;
        tb_s_axis_tlast_i  = 1'b0;
        tb_m_axis_tready_i = 1'b1;
        repeat(10) @(posedge tb_clk);
        tb_rstn = 1'b1;
        repeat(5) @(posedge tb_clk);
    endtask

    // Drive mem_ctrl fields and pulse start (mem_ctrl[0]) high; caller is
    // responsible for eventually clearing start via stop_mem().
    task automatic start_mem(input logic op, input logic [1:0] sel, input logic source, input logic [1:0] core = 2'b00);
        tb_mem_ctrl = {core, source, sel, op, 1'b1};
    endtask

    task automatic stop_mem();
        tb_mem_ctrl[0] = 1'b0;
        repeat(2) @(posedge tb_clk);
    endtask

    task automatic wait_cycles(input int n);
        repeat(n) @(posedge tb_clk);
    endtask

    // Poll `sig` until it equals 1, with a cycle timeout.
    task automatic wait_until_high(ref logic sig, input int timeout = 50);
        int t = 0;
        while (sig !== 1'b1 && t < timeout) begin
            @(posedge tb_clk);
            t++;
        end
        if (t >= timeout)
            $display("[WARN] wait_until_high: timeout waiting for signal");
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
        stop_mem();
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "qproc_mem_ctrl_tests.sv"
    `SVUNIT_TESTS_END

endmodule
