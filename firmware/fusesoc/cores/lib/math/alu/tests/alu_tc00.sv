`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

//------------------------------------------------------------------------------
// Component: alu_unit_test
// Description: Unit testbench for the top-level ALU module.
//              Verifies arithmetic unit routing (op[3]=1), bitwise unit routing
//              (op[3]=0), zero detection, pipeline alignment (op_rrr selector
//              matches 2-cycle sub-module latency), reset state, and
//              back-to-back cross-unit operations.
//
// Pipeline architecture (from RTL):
//   Cycle 0 : din_a/din_b/op presented at inputs
//   Cycle 1 : sub-modules register din_a_r, din_b_r, op_r  |  op_r   latched
//   Cycle 2 : sub-modules compute dout_r                    |  op_rr  latched
//   Cycle 3 : sub-modules output dout_rr = dout             |  op_rrr latched -> sel valid
//   => apply_op waits 3 @(cb) after driving inputs.
//------------------------------------------------------------------------------
module alu_unit_test;
    import svunit_pkg::svunit_testcase;
    import alu_pkg::*;

    string name = "alu_ut";
    svunit_testcase svunit_ut;

    //--------------------------------------------------------------------------
    // Testbench Parameters
    //--------------------------------------------------------------------------
    localparam real        CLOCK_FREQUENCY = 100e6; // 100 MHz
    localparam int unsigned B              = alu_pkg::B;

    // op[3] encoding
    localparam logic UNIT_BITW  = 1'b0;
    localparam logic UNIT_ARITH = 1'b1;

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
        $dumpfile("alu.vcd");
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
    alu #(
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

    // Zero-A detection: combinational in alu_arithmetic_unit, disable during reset
    property zero_a_detect;
        @(posedge tb_clk) disable iff (!tb_rstn)
        (tb_din_a == '0) |-> (tb_zero_a == 1'b1);
    endproperty
    `ASSERT_CONCURRENT(zero_a_detect);

    // Zero-B detection: combinational in alu_arithmetic_unit, disable during reset
    property zero_b_detect;
        @(posedge tb_clk) disable iff (!tb_rstn)
        (tb_din_b == '0) |-> (tb_zero_b == 1'b1);
    endproperty
    `ASSERT_CONCURRENT(zero_b_detect);

    // Selector alignment: op_rrr[3] must match op delayed by 3 cycles
    property sel_pipeline;
        @(posedge tb_clk) disable iff (!tb_rstn)
        ##3 (u_dut.sel == $past(tb_op[3], 3));
    endproperty
    `ASSERT_CONCURRENT(sel_pipeline);

    //--------------------------------------------------------------------------
    // SVUnit Infrastructure (Build, Setup, Teardown)
    //--------------------------------------------------------------------------
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        cb.tb_rstn  <= 1'b0;
        cb.tb_din_a <= '0;
        cb.tb_din_b <= '0;
        cb.tb_op    <= '0;
        repeat(3) @(cb);
        cb.tb_rstn  <= 1'b1;
        repeat(3) @(cb); // Extra cycles to flush op_rrr pipeline after reset
    endtask

    task teardown();
        svunit_ut.teardown();
        cb.tb_rstn  <= 1'b0;
        cb.tb_din_a <= '0;
        cb.tb_din_b <= '0;
        cb.tb_op    <= '0;
        repeat(2) @(cb);
    endtask

    //--------------------------------------------------------------------------
    // Helper Tasks
    //--------------------------------------------------------------------------

    // apply_arith: op[3]=1 routes to arithmetic unit.
    // Waits 3 @(cb) for sub-module pipeline + op_rrr alignment.
    task apply_arith(
        input logic [B-1:0]          a,
        input logic [B-1:0]          b,
        input alu_pkg::arith_op_e    arith_op
    );
        cb.tb_din_a <= a;
        cb.tb_din_b <= b;
        cb.tb_op    <= {UNIT_ARITH, arith_op[2:0]};
        @(cb); // Stage 1: sub-module input registers
        @(cb); // Stage 2: dout_r in sub-modules
        @(cb); // Stage 3: dout_rr available; op_rrr selector valid
    endtask

    // apply_bitw: op[3]=0 routes to bitwise unit.
    // op[2:0] carries the full bitwise opcode (LSHIFT=3'b100, RSHIFT=3'b101
    // need bit[2], so pass bitw_op[2:0] not just [1:0]).
    task apply_bitw(
        input logic [B-1:0]         a,
        input logic [B-1:0]         b,
        input alu_pkg::bitw_op_e    bitw_op
    );
        cb.tb_din_a <= a;
        cb.tb_din_b <= b;
        cb.tb_op    <= {UNIT_BITW, bitw_op[2:0]};
        @(cb);
        @(cb);
        @(cb);
    endtask

    //--------------------------------------------------------------------------
    // Test Cases Block Insertion
    //--------------------------------------------------------------------------
    `SVUNIT_TESTS_BEGIN
        `include "alu_tests.sv"
    `SVUNIT_TESTS_END

endmodule
