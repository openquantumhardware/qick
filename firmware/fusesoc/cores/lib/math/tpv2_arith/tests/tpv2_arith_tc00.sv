//------------------------------------------------------------------------------
// Testbench: tpv2_arith_tc00
// Description:
//   Unit tests for tpv2_arith (ported from `arith` in
//   firmware/ip/qick_processor/src/_qproc_ips.sv) — the DSP48-backed
//   multiply-accumulate "user peripheral" of tprocv2.
//------------------------------------------------------------------------------

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module tpv2_arith_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "tpv2_arith_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;

    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    logic signed [31:0] tb_a, tb_b, tb_c, tb_d;
    logic        [4:0]  tb_alu_op;
    logic                tb_start;
    logic                tb_ready;
    logic signed [63:0]  tb_result;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    tpv2_arith dut (
        .clk_i          (tb_clk),
        .rst_ni         (tb_rstn),
        .start_i        (tb_start),
        .a_i            (tb_a),
        .b_i            (tb_b),
        .c_i            (tb_c),
        .d_i            (tb_d),
        .alu_op_i       (tb_alu_op),
        .ready_o        (tb_ready),
        .arith_result_o (tb_result)
    );

    initial begin
        $dumpfile("tpv2_arith.vcd");
        $dumpvars();
    end

    // Pulses start_i for one cycle with the given operands/opcode, waits for
    // ready_o to fall then rise again, leaving arith_result_o stable.
    task automatic run_arith(
        input signed [31:0] a, b, c, d,
        input        [4:0]  op
    );
        tb_a      = a;
        tb_b      = b;
        tb_c      = c;
        tb_d      = d;
        tb_alu_op = op;
        tb_start  = 1'b1;
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
        tb_rstn   = 1'b0;
        tb_a      = '0;
        tb_b      = '0;
        tb_c      = '0;
        tb_d      = '0;
        tb_alu_op = '0;
        tb_start  = 1'b0;
        repeat(4) @(posedge tb_clk);
        tb_rstn = 1'b1;
        repeat(4) @(posedge tb_clk);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "tpv2_arith_tests.sv"
    `SVUNIT_TESTS_END

endmodule
