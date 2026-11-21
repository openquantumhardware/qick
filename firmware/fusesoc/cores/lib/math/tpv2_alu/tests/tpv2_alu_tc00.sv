// ============================================================================
// File: tpv2_alu_tc00.sv
// Description: SVUnit testbench top-level for tpv2_alu (combinational 2-input ALU).
//   tpv2_alu has no clock/reset; clk_gen is used only to sequence assertions.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module tpv2_alu_unit_test;
    import svunit_pkg::svunit_testcase;
    import alu_pkg::*;

    string name = "tpv2_alu_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;

    // =========================================================================
    // Clock (only to sequence the combinational checks)
    // =========================================================================
    logic tb_clk = 1'b0;
    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic signed [31:0] a_i;
    logic signed [31:0] b_i;
    logic        [3:0]  alu_op_i;
    logic               z_o, c_o, s_o;
    logic signed [31:0] alu_result_o;

    // =========================================================================
    // DUT
    // =========================================================================
    tpv2_alu dut (
        .a_i          (a_i),
        .b_i          (b_i),
        .alu_op_i     (alu_op_i),
        .z_o          (z_o),
        .c_o          (c_o),
        .s_o          (s_o),
        .alu_result_o (alu_result_o)
    );

    // =========================================================================
    // Helper: apply inputs, let combinational logic settle.
    // =========================================================================
    task automatic apply(
        input logic signed [31:0] a,
        input logic signed [31:0] b,
        input logic        [3:0]  op
    );
        a_i      = a;
        b_i      = b;
        alu_op_i = op;
        #1;  // settle combinational logic
    endtask

    task automatic check(
        input logic signed [31:0] exp_res,
        input logic               exp_z,
        input logic               exp_c,
        input logic               exp_s,
        input string              msg
    );
        if (alu_result_o !== exp_res) begin
            $display("RESULT MISMATCH %s: exp 0x%08h got 0x%08h", msg, exp_res, alu_result_o);
            `FAIL_IF(1);
        end
        if (z_o !== exp_z) begin
            $display("Z MISMATCH %s: exp %b got %b", msg, exp_z, z_o); `FAIL_IF(1);
        end
        if (c_o !== exp_c) begin
            $display("C MISMATCH %s: exp %b got %b", msg, exp_c, c_o); `FAIL_IF(1);
        end
        if (s_o !== exp_s) begin
            $display("S MISMATCH %s: exp %b got %b", msg, exp_s, s_o); `FAIL_IF(1);
        end
    endtask

    // Check result only (flags don't-care)
    task automatic check_res(
        input logic signed [31:0] exp_res,
        input string              msg
    );
        if (alu_result_o !== exp_res) begin
            $display("RESULT MISMATCH %s: exp 0x%08h got 0x%08h", msg, exp_res, alu_result_o);
            `FAIL_IF(1);
        end
    endtask

    // =========================================================================
    // SVUnit
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        a_i = '0; b_i = '0; alu_op_i = '0;
        #1;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "tpv2_alu_tests.sv"
    `SVUNIT_TESTS_END

endmodule
