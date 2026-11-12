// ============================================================================
// File: lfsr_tc00.sv
// Description: SVUnit testbench top-level for the generic lfsr.
//   Uses default parameters (DW=32, TAPS=0x8020_0003, XNOR feedback) which
//   reproduce the original tProcessor v2 LFSR. A software reference model
//   computes the expected sequence to validate the feedback polynomial.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module lfsr_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "lfsr_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters (match the DUT defaults)
    // =========================================================================
    localparam real          CLOCK_FREQUENCY = 200e6;
    localparam int           DW   = 32;
    localparam logic [31:0]  TAPS = 32'h8020_0003;
    localparam bit           XNOR = 1'b1;

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic          tb_en        = 1'b0;
    logic          tb_load_we   = 1'b0;
    logic [DW-1:0] tb_load_dt   = '0;
    logic [DW-1:0] tb_lfsr_dt;

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking tb_cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_en;
        output tb_load_we;
        output tb_load_dt;
        input  tb_lfsr_dt;
    endclocking

    // =========================================================================
    // Dump
    // =========================================================================
    initial begin
        $dumpfile("lfsr.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    lfsr #(
        .DW   (DW),
        .TAPS (TAPS),
        .XNOR (XNOR)
    ) dut (
        .clk_i     (tb_clk),
        .rst_ni    (tb_rstn),
        .en_i      (tb_en),
        .load_we_i (tb_load_we),
        .load_dt_i (tb_load_dt),
        .lfsr_dt_o (tb_lfsr_dt)
    );

    // =========================================================================
    // Reference model: one LFSR step (same feedback as the DUT)
    // =========================================================================
    function automatic logic [DW-1:0] lfsr_step(input logic [DW-1:0] state);
        logic fb;
        fb = XNOR ? ~(^(state & TAPS[DW-1:0])) : (^(state & TAPS[DW-1:0]));
        return {state[DW-2:0], fb};
    endfunction

    // =========================================================================
    // Helpers
    // =========================================================================
    task automatic reset_dut();
        tb_cb.tb_rstn      <= 1'b0;
        tb_cb.tb_en        <= 1'b0;
        tb_cb.tb_load_we   <= 1'b0;
        tb_cb.tb_load_dt   <= '0;
        repeat(5) @(tb_cb);
        tb_cb.tb_rstn <= 1'b1;
        repeat(2) @(tb_cb);
    endtask

    task automatic do_load(input logic [DW-1:0] seed);
        @(tb_cb);
        tb_cb.tb_load_we <= 1'b1;
        tb_cb.tb_load_dt <= seed;
        @(tb_cb);
        tb_cb.tb_load_we <= 1'b0;
        @(tb_cb);   // value now visible
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
        tb_cb.tb_en      <= 1'b0;
        tb_cb.tb_load_we <= 1'b0;
        repeat(2) @(tb_cb);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "lfsr_tests.sv"
    `SVUNIT_TESTS_END

endmodule
