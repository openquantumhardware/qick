`include "svunit_defines.svh"

module mult_pipe3_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "mult_pipe3_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQ = 200e6;
    localparam int  B = 16;

    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQ)) u_clk_gen (.i_enable(1'b1), .o_clk(tb_clk));

    logic signed [B-1:0]   tb_a, tb_b;
    logic signed [2*B-1:0] tb_p;

    default clocking cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn, tb_a, tb_b;
        input  tb_p;
    endclocking

    mult_pipe3 #(.B (B)) dut (
        .clk  (tb_clk),
        .rstn (tb_rstn),
        .a    (tb_a),
        .b    (tb_b),
        .p    (tb_p)
    );

    task automatic mult_and_check(input logic signed [B-1:0] a, input logic signed [B-1:0] b);
        logic signed [2*B-1:0] expected;
        expected = a * b;
        cb.tb_a <= a;
        cb.tb_b <= b;
        repeat(4) @(cb);
        `FAIL_UNLESS_EQUAL(cb.tb_p, expected)
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        cb.tb_a <= '0;
        cb.tb_b <= '0;
        cb.tb_rstn <= 1'b0;
        repeat(4) @(cb);
        cb.tb_rstn <= 1'b1;
        repeat(4) @(cb);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "mult_pipe3_tests.sv"
    `SVUNIT_TESTS_END
endmodule
