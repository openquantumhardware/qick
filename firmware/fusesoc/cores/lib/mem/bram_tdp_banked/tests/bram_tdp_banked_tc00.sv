// ============================================================================
// File: bram_tdp_banked_tc00.sv
// Description: SVUnit testbench top-level for bram_tdp_banked.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module bram_tdp_banked_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "bram_tdp_banked_ut";
    svunit_testcase svunit_ut;

    localparam real CLK_A_FREQ = 200e6;
    localparam real CLK_B_FREQ = 150e6;
    localparam int  MEM_AW      = 4;   // 16 words
    localparam int  MEM_DW      = 32;
    localparam time TSU         = 1ns; // setup offset from clock edge (xsim-safe)

    logic clk_a = 1'b0;
    logic clk_b = 1'b0;

    clk_gen #(.FREQ(CLK_A_FREQ)) u_clk_a (.i_enable(1'b1), .o_clk(clk_a));
    clk_gen #(.FREQ(CLK_B_FREQ)) u_clk_b (.i_enable(1'b1), .o_clk(clk_b));

    // DUT signals
    logic                 en_a, we_a;
    logic [MEM_AW-1:0]    addr_a;
    logic [MEM_DW-1:0]    din_a, dout_a;
    logic                 en_b, we_b;
    logic [MEM_AW-1:0]    addr_b;
    logic [MEM_DW-1:0]    din_b, dout_b;

    bram_tdp_banked #(
        .MEM_AW (MEM_AW),
        .MEM_DW (MEM_DW)
    ) dut (
        .clk_a_i  (clk_a),
        .en_a_i   (en_a),
        .we_a_i   (we_a),
        .addr_a_i (addr_a),
        .dt_a_i   (din_a),
        .dt_a_o   (dout_a),

        .clk_b_i  (clk_b),
        .en_b_i   (en_b),
        .we_b_i   (we_b),
        .addr_b_i (addr_b),
        .dt_b_i   (din_b),
        .dt_b_o   (dout_b)
    );

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        {en_a, we_a, addr_a, din_a} = '0;
        {en_b, we_b, addr_b, din_b} = '0;
        #2;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "bram_tdp_banked_tests.sv"
    `SVUNIT_TESTS_END

endmodule
