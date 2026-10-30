// ============================================================================
// File: delay_line_tc00.sv
// Description: SVUnit testbench top-level for delay_line.
//   Verifies the N-cycle latency for several (N, M) configurations using a
//   software reference (a queue) to model the expected delayed output.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module delay_line_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "delay_line_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N = 5;     // delay stages
    localparam int  M = 16;    // data width

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic [M-1:0] tb_data_i = '0;
    logic [M-1:0] tb_data_o;

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking tb_cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_data_i;
        input  tb_data_o;
    endclocking

    // =========================================================================
    // Dump
    // =========================================================================
    initial begin
        $dumpfile("delay_line.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    delay_line #(
        .N (N),
        .M (M)
    ) dut (
        .i_clk  (tb_clk),
        .i_rstn (tb_rstn),
        .i_data (tb_data_i),
        .o_data (tb_data_o)
    );

    // =========================================================================
    // Helpers
    // =========================================================================
    task automatic reset_dut();
        tb_cb.tb_rstn   <= 1'b0;
        tb_cb.tb_data_i <= '0;
        repeat(N+3) @(tb_cb);
        tb_cb.tb_rstn <= 1'b1;
        repeat(2) @(tb_cb);
    endtask

    // =========================================================================
    // SVUnit
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
        tb_cb.tb_data_i <= '0;
        repeat(2) @(tb_cb);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "delay_line_tests.sv"
    `SVUNIT_TESTS_END

endmodule