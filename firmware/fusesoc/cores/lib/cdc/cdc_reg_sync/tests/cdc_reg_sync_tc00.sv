// ============================================================================
// File: cdc_reg_sync_tc00.sv
// Description: SVUnit testbench top-level for cdc_reg_sync.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module cdc_reg_sync_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "cdc_reg_sync_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  DW = 4;

    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    logic [DW-1:0] dt_i, dt_o;

    cdc_reg_sync #(.DW(DW)) dut (
        .clk_i (tb_clk),
        .rst_ni(tb_rstn),
        .dt_i  (dt_i),
        .dt_o  (dt_o)
    );

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        dt_i = '0;
        #2;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "cdc_reg_sync_tests.sv"
    `SVUNIT_TESTS_END

endmodule
