//------------------------------------------------------------------------------
// Testbench: restoring_divider_tc00
// Description:
//   Unit tests for restoring_divider (ported from div_r in
//   firmware/ip/qick_processor/src/_qproc_ips.sv).
//------------------------------------------------------------------------------

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module restoring_divider_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "restoring_divider_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  DW = 32;

    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    logic [DW-1:0] tb_a;
    logic [DW-1:0] tb_b;
    logic          tb_start;
    logic          tb_ready;
    logic [DW-1:0] tb_quotient;
    logic [DW-1:0] tb_remainder;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    restoring_divider #(
        .DW (DW)
    ) dut (
        .clk_i           (tb_clk),
        .rst_ni          (tb_rstn),
        .start_i         (tb_start),
        .a_i             (tb_a),
        .b_i             (tb_b),
        .ready_o         (tb_ready),
        .div_quotient_o  (tb_quotient),
        .div_remainder_o (tb_remainder)
    );

    initial begin
        $dumpfile("restoring_divider.vcd");
        $dumpvars();
    end

    // Drives A_i/B_i, pulses start_i for one cycle, waits for ready_o to
    // fall then rise again (one full division), leaving quotient/remainder
    // stable for the caller to check.
    task automatic run_division(input logic [DW-1:0] a, input logic [DW-1:0] b);
        tb_a     = a;
        tb_b     = b;
        tb_start = 1'b1;
        @(posedge tb_clk);
        tb_start = 1'b0;
        @(posedge tb_clk);
        wait (tb_ready == 1'b1);
        @(posedge tb_clk);
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_rstn  = 1'b0;
        tb_a     = '0;
        tb_b     = '0;
        tb_start = 1'b0;
        repeat(4) @(posedge tb_clk);
        tb_rstn = 1'b1;
        repeat(4) @(posedge tb_clk);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "restoring_divider_tests.sv"
    `SVUNIT_TESTS_END

endmodule
