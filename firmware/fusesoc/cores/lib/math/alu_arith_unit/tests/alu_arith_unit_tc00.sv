`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

//------------------------------------------------------------------------------
// Component: alu_arith_unit_unit_test
// Description: Unit testbench for ALU Arithmetic Unit.
//              Verifies reset state, ADD/SUB/MUL operations, zero detection,
//              pipeline latency (2-cycle dout_rr), signed arithmetic, and
//              default opcode behavior.
//------------------------------------------------------------------------------
module alu_arith_unit_unit_test;
    import svunit_pkg::svunit_testcase;
    import alu_pkg::*;

    string name = "alu_arith_unit_ut";
    svunit_testcase svunit_ut;

    //--------------------------------------------------------------------------
    // Testbench Parameters
    //--------------------------------------------------------------------------
    localparam real        CLOCK_FREQUENCY = 100e6; // 100 MHz
    localparam int unsigned B              = alu_pkg::B;

    //--------------------------------------------------------------------------
    // Interface & Testbench Signals
    //--------------------------------------------------------------------------
    logic          tb_clk    = 1'b0;
    logic          tb_rstn   = 1'b0;
    logic [B-1:0]  tb_din_a  = '0;
    logic [B-1:0]  tb_din_b  = '0;
    logic [3:0]    tb_op     = '0;
    logic          tb_zero_a;
    logic          tb_zero_b;
    logic [B-1:0]  tb_dout;

    //--------------------------------------------------------------------------
    // VCD Waveform Generation
    //--------------------------------------------------------------------------
    initial begin
        $dumpfile("alu_arith_unit.vcd");
        $dumpvars();
    end

    //--------------------------------------------------------------------------
    // Clock Generator Instance
    //--------------------------------------------------------------------------
    clk_gen #(
        .FREQ (CLOCK_FREQUENCY)
    ) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    //--------------------------------------------------------------------------
    // Default Clocking Block (Synchronous Stimulus Driving & Sampling)
    //--------------------------------------------------------------------------
    default clocking cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_din_a;
        output tb_din_b;
        output tb_op;
        input  tb_zero_a;
        input  tb_zero_b;
        input  tb_dout;
    endclocking

    //--------------------------------------------------------------------------
    // Unit Under Test (UUT)
    //--------------------------------------------------------------------------
    alu_arith_unit #(
        .B (B)
    ) u_dut (
        .clk    (tb_clk),
        .rstn   (tb_rstn),
        .din_a  (tb_din_a),
        .din_b  (tb_din_b),
        .op     (tb_op),
        .zero_a (tb_zero_a),
        .zero_b (tb_zero_b),
        .dout   (tb_dout)
    );

    //--------------------------------------------------------------------------
    // Concurrent Assertions
    //--------------------------------------------------------------------------

    // Zero-A detection: combinational, must match immediately.
    // Guard with rstn to avoid false failures at time zero when signals are X.
    property zero_a_detect;
        @(posedge tb_clk) disable iff (!tb_rstn)
        (tb_din_a == '0) |-> (tb_zero_a == 1'b1);
    endproperty
    `ASSERT_CONCURRENT(zero_a_detect);

    // Zero-B detection: combinational, must match immediately.
    // Guard with rstn to avoid false failures at time zero when signals are X.
    property zero_b_detect;
        @(posedge tb_clk) disable iff (!tb_rstn)
        (tb_din_b == '0) |-> (tb_zero_b == 1'b1);
    endproperty
    `ASSERT_CONCURRENT(zero_b_detect);

    // Reset guarantee: dout must be zero one cycle after rstn deasserted
    property reset_clears_output;
        @(posedge tb_clk)
        (!tb_rstn) |=> (u_dut.dout_r == '0);
    endproperty
    `ASSERT_CONCURRENT(reset_clears_output);

    //--------------------------------------------------------------------------
    // SVUnit Infrastructure (Build, Setup, Teardown)
    //--------------------------------------------------------------------------
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        // Assert reset and clear all inputs
        cb.tb_rstn  <= 1'b0;
        cb.tb_din_a <= '0;
        cb.tb_din_b <= '0;
        cb.tb_op    <= '0;
        repeat(3) @(cb);
        // Deassert reset
        cb.tb_rstn  <= 1'b1;
        repeat(2) @(cb);
    endtask

    task teardown();
        svunit_ut.teardown();
        // Return to idle/reset state between tests
        cb.tb_rstn  <= 1'b0;
        cb.tb_din_a <= '0;
        cb.tb_din_b <= '0;
        cb.tb_op    <= '0;
        repeat(2) @(cb);
    endtask

    //--------------------------------------------------------------------------
    // Helper Tasks
    //--------------------------------------------------------------------------

    // apply_op: Drive inputs for one clock cycle, then wait 2 cycles for
    // the 2-stage pipeline (dout_r -> dout_rr) to propagate the result.
    task apply_op(
        input logic [B-1:0] a,
        input logic [B-1:0] b,
        input logic [3:0]   op_code
    );
        cb.tb_din_a <= a;
        cb.tb_din_b <= b;
        cb.tb_op    <= op_code;
        @(cb); // Stage 1: inputs registered into din_a_r, din_b_r, op_r
        @(cb); // Stage 2: dout_mux -> dout_r
        @(cb); // Stage 3: dout_r  -> dout_rr (output)
    endtask

    //--------------------------------------------------------------------------
    // Test Cases Block Insertion
    //--------------------------------------------------------------------------
    `SVUNIT_TESTS_BEGIN
        `include "alu_arith_unit_tests.sv"
    `SVUNIT_TESTS_END

endmodule
