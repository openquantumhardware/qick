// ============================================================================
// File: mult_32x32_tc00.sv
// Description: SVUnit testbench top-level for mult_32x32.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module mult_32x32_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "mult_32x32_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;

    logic tb_clk = 1'b0;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    logic [31:0] tb_din_a;
    logic [31:0] tb_din_b;
    logic [63:0] tb_dout;

    initial begin
        $dumpfile("mult_32x32.vcd");
        $dumpvars();
    end

    mult_32x32 dut (
        .clk   (tb_clk),
        .din_a (tb_din_a),
        .din_b (tb_din_b),
        .dout  (tb_dout)
    );

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_din_a = '0;
        tb_din_b = '0;
        repeat(8) @(posedge tb_clk);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // Drives a/b for one cycle then waits the fixed 6-cycle pipeline latency.
    task automatic mult_and_wait(input logic [31:0] a, input logic [31:0] b);
        @(negedge tb_clk);
        tb_din_a = a;
        tb_din_b = b;
        repeat(6) @(posedge tb_clk);
        @(negedge tb_clk);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "mult_32x32_tests.sv"
    `SVUNIT_TESTS_END

endmodule
