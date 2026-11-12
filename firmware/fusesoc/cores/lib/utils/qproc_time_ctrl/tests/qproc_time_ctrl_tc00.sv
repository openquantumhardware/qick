// ============================================================================
// File: qproc_time_ctrl_tc00.sv
// Description: SVUnit testbench top-level for qproc_time_ctrl.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qproc_time_ctrl_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "qproc_time_ctrl_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;

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
    // DUT signals
    // =========================================================================
    logic        tb_time_en_i   = 1'b0;
    logic        tb_time_rst_i  = 1'b0;
    logic        tb_time_init_i = 1'b0;
    logic        tb_time_updt_i = 1'b0;
    logic [31:0] tb_updt_dt_i   = '0;
    logic [47:0] tb_time_abs_o;

    initial begin
        $dumpfile("qproc_time_ctrl.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    qproc_time_ctrl u_dut (
        .t_clk_i     (tb_clk),
        .t_rst_ni    (tb_rstn),
        .time_en_i   (tb_time_en_i),
        .time_rst_i  (tb_time_rst_i),
        .time_init_i (tb_time_init_i),
        .time_updt_i (tb_time_updt_i),
        .updt_dt_i   (tb_updt_dt_i),
        .time_abs_o  (tb_time_abs_o)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================
    // time_abs itself has no tie to t_rst_ni (only the FSM state does, like
    // the real ADDSUB_MACRO-backed hardware) -- it stays 'x until the first
    // time_rst_i/time_init_i pulse. Pulse time_rst_i here so every test
    // starts from a known, zeroed counter.
    task automatic reset_dut();
        tb_time_en_i   = 1'b0;
        tb_time_rst_i  = 1'b0;
        tb_time_init_i = 1'b0;
        tb_time_updt_i = 1'b0;
        tb_updt_dt_i   = '0;
        tb_rstn = 1'b0;
        repeat(5) @(posedge tb_clk);
        tb_rstn = 1'b1;
        repeat(2) @(posedge tb_clk);
        pulse(tb_time_rst_i);
    endtask

    // One-cycle pulse on `sig`, synchronized to negedge like the rest of the
    // repo's testbenches (see NEW_CORE.md verification guidelines).
    task automatic pulse(ref logic sig);
        @(negedge tb_clk);
        sig = 1'b1;
        @(negedge tb_clk);
        sig = 1'b0;
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
    `include "qproc_time_ctrl_tests.sv"
    `SVUNIT_TESTS_END

endmodule
