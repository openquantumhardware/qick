//------------------------------------------------------------------------------
// Testbench: sync_ab_en_tc00
// Description:
//   Unit tests for sync_ab_en, the free-running two-phase CDC handshake
//   ported from firmware/ip/qick_processor/src/_qproc_ips.sv (used by
//   qproc_ctrl to pulse a "latch time counter" enable in two clock domains).
//------------------------------------------------------------------------------

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module sync_ab_en_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sync_ab_en_ut";
    svunit_testcase svunit_ut;

    // Deliberately different, non-integer-ratio periods so the two domains
    // are genuinely asynchronous to each other.
    localparam real PERIOD_A = 5.0;    // 200 MHz
    localparam real PERIOD_B = 3.333;  // ~300 MHz

    logic tb_clk_a  = 1'b0;
    logic tb_rst_a_n = 1'b0;
    logic tb_clk_b  = 1'b0;
    logic tb_rst_b_n = 1'b0;

    logic tb_a_en;
    logic tb_b_en;

    clk_gen #(.FREQ (1.0e9 / PERIOD_A)) u_clk_a (.i_enable(1'b1), .o_clk(tb_clk_a));
    clk_gen #(.FREQ (1.0e9 / PERIOD_B)) u_clk_b (.i_enable(1'b1), .o_clk(tb_clk_b));

    sync_ab_en dut (
        .clk_a_i  (tb_clk_a),
        .rst_a_ni (tb_rst_a_n),
        .clk_b_i  (tb_clk_b),
        .rst_b_ni (tb_rst_b_n),
        .a_en_o   (tb_a_en),
        .b_en_o   (tb_b_en)
    );

    // Pulse counters / pulse-width checkers, one per domain.
    int cnt_a_en;
    int cnt_b_en;
    int a_en_high_cycles;
    int b_en_high_cycles;

    always_ff @(posedge tb_clk_a) begin
        if (!tb_rst_a_n) cnt_a_en <= 0;
        else if (tb_a_en) cnt_a_en <= cnt_a_en + 1;
    end

    always_ff @(posedge tb_clk_b) begin
        if (!tb_rst_b_n) cnt_b_en <= 0;
        else if (tb_b_en) cnt_b_en <= cnt_b_en + 1;
    end

    initial begin
        $dumpfile("sync_ab_en.vcd");
        $dumpvars();
    end

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_rst_a_n = 1'b0;
        tb_rst_b_n = 1'b0;
        cnt_a_en   = 0;
        cnt_b_en   = 0;
        repeat(10) @(posedge tb_clk_a);
        tb_rst_a_n = 1'b1;
        tb_rst_b_n = 1'b1;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "sync_ab_en_tests.sv"
    `SVUNIT_TESTS_END

endmodule
