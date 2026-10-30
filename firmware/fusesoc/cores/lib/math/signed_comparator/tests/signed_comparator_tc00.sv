// ============================================================================
// File: signed_comparator_tc00.sv
// Description: SVUnit testbench top-level for the signed_comparator module.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module signed_comparator_unit_test;

    import svunit_pkg::svunit_testcase;

    string name = "signed_comparator_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  B = 16;

    // -------------------------------------------------------------------------
    // Clock & Reset
    // -------------------------------------------------------------------------
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    // -------------------------------------------------------------------------
    // UUT interfaces
    // -------------------------------------------------------------------------
    logic [B-1:0] tb_din_a = '0;
    logic [B-1:0] tb_din_b = '0;
    logic [3:0]   tb_op    = '0;
    logic         tb_flag;

    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("signed_comparator.vcd");
        $dumpvars();
    end

    // -------------------------------------------------------------------------
    // Clock generator
    // -------------------------------------------------------------------------
    clk_gen #(
        .FREQ (CLOCK_FREQUENCY)
    ) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    // -------------------------------------------------------------------------
    // Clocking block
    // -------------------------------------------------------------------------
    default clocking cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_din_a;
        output tb_din_b;
        output tb_op;
        input  tb_flag;
    endclocking

    // -------------------------------------------------------------------------
    // Unit Under Test
    // -------------------------------------------------------------------------
    signed_comparator #(
        .B (B)
    ) u_signed_comparator (
        .clk   (tb_clk),
        .rstn  (tb_rstn),
        .din_a (tb_din_a),
        .din_b (tb_din_b),
        .op    (tb_op),
        .flag  (tb_flag)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================

    // check_cond: Drives inputs, waits for the 1-cycle latency, and verifies the flag.
    task automatic check_cond(
        input int a,
        input int b,
        input logic [3:0] op,
        input logic exp_flag
    );
        cb.tb_din_a <= a[B-1:0];
        cb.tb_din_b <= b[B-1:0];
        cb.tb_op    <= op;
        
        // Cycle 1: Inputs are driven and sampled by UUT at the end of this cycle
        @(cb); 
        
        // Cycle 2: UUT registers update, combinational logic evaluates. 
        // Clocking block samples the output at the end of this cycle.
        @(cb); 
        
        `FAIL_UNLESS_EQUAL(cb.tb_flag, exp_flag);
    endtask

    // =========================================================================
    // SVUnit build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        cb.tb_din_a <= '0;
        cb.tb_din_b <= '0;
        cb.tb_op    <= '0;
        @(cb);
        
        // Assert reset
        cb.tb_rstn <= 1'b0;
        repeat(2) @(cb);
        
        // Release reset
        cb.tb_rstn <= 1'b1;
        repeat(2) @(cb);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "tests.sv"
    `SVUNIT_TESTS_END

endmodule
