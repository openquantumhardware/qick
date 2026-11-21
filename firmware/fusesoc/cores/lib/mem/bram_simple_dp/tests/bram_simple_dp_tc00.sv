// ============================================================================
// File: bram_simple_dp_tc00.sv
// Description: SVUnit testbench top-level for bram_simple_dp.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module bram_simple_dp_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "bram_simple_dp_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N = 4; // 16 locations
    localparam int  B = 8; // 8-bit data

    // =========================================================================
    // Clock
    // =========================================================================
    logic tb_clk = 1'b0;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic       tb_ena   = 1'b0;
    logic       tb_enb   = 1'b0;
    logic       tb_wea   = 1'b0;
    logic [N-1:0] tb_addra = '0;
    logic [N-1:0] tb_addrb = '0;
    logic [B-1:0] tb_dia   = '0;
    logic [B-1:0] tb_dob;

    initial begin
        $dumpfile("bram_simple_dp.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    bram_simple_dp #(
        .N (N),
        .B (B)
    ) u_dut (
        .clk   (tb_clk),
        .ena   (tb_ena),
        .enb   (tb_enb),
        .wea   (tb_wea),
        .addra (tb_addra),
        .addrb (tb_addrb),
        .dia   (tb_dia),
        .dob   (tb_dob)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic init_signals();
        tb_ena   = 1'b0;
        tb_enb   = 1'b0;
        tb_wea   = 1'b0;
        tb_addra = '0;
        tb_addrb = '0;
        tb_dia   = '0;
        repeat(5) @(posedge tb_clk);
    endtask

    // Write `data` to `addr` on port A.
    task automatic write(input logic [N-1:0] addr, input logic [B-1:0] data);
        @(negedge tb_clk);
        tb_ena   = 1'b1;
        tb_wea   = 1'b1;
        tb_addra = addr;
        tb_dia   = data;
        @(negedge tb_clk);
        tb_ena   = 1'b0;
        tb_wea   = 1'b0;
    endtask

    // Read from `addr` on port B; result lands in tb_dob one cycle later
    // (bram_simple_dp registers the read data on the enabled clock edge).
    task automatic read(input logic [N-1:0] addr);
        @(negedge tb_clk);
        tb_enb   = 1'b1;
        tb_addrb = addr;
        @(negedge tb_clk);
        tb_enb   = 1'b0;
    endtask

    // =========================================================================
    // SVUnit build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        init_signals();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "bram_simple_dp_tests.sv"
    `SVUNIT_TESTS_END

endmodule
