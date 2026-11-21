// ============================================================================
// File: axis_reorder_iq_v1_tc00.sv
// Description: SVUnit testbench for axis_reorder_iq_v1 at the defaults
//              (B = 16, L = 4) and at B = 16, L = 8, each next to the legacy
//              RTL (tests/ref/axis_reorder_iq_v1_legacy.sv, the original file
//              with only the module renamed). Combinational: outputs read #1.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_reorder_iq_v1_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_reorder_iq_v1_ut";
    svunit_testcase svunit_ut;

    logic [255:0] din = '0;
    logic         vin = 1'b0;
    logic [127:0] p4, l4;  logic pv4, lv4, pr4, lr4;
    logic [255:0] p8, l8;  logic pv8, lv8, pr8, lr8;

    axis_reorder_iq_v1 #(.B(16), .L(4)) dut4 (.aresetn(1'b1), .aclk(1'b0),
        .s_axis_tdata(din[127:0]), .s_axis_tvalid(vin), .s_axis_tready(pr4),
        .m_axis_tdata(p4), .m_axis_tvalid(pv4), .m_axis_tready(1'b1));
    axis_reorder_iq_v1_legacy #(.B(16), .L(4)) ref4 (.aresetn(1'b1), .aclk(1'b0),
        .s_axis_tdata(din[127:0]), .s_axis_tvalid(vin), .s_axis_tready(lr4),
        .m_axis_tdata(l4), .m_axis_tvalid(lv4), .m_axis_tready(1'b1));
    axis_reorder_iq_v1 #(.B(16), .L(8)) dut8 (.aresetn(1'b1), .aclk(1'b0),
        .s_axis_tdata(din), .s_axis_tvalid(vin), .s_axis_tready(pr8),
        .m_axis_tdata(p8), .m_axis_tvalid(pv8), .m_axis_tready(1'b1));
    axis_reorder_iq_v1_legacy #(.B(16), .L(8)) ref8 (.aresetn(1'b1), .aclk(1'b0),
        .s_axis_tdata(din), .s_axis_tvalid(vin), .s_axis_tready(lr8),
        .m_axis_tdata(l8), .m_axis_tvalid(lv8), .m_axis_tready(1'b1));

    function void build(); svunit_ut = new(name); endfunction
    task setup();    svunit_ut.setup();    endtask
    task teardown(); svunit_ut.teardown(); endtask

    `SVUNIT_TESTS_BEGIN
    `include "axis_reorder_iq_v1_tests.sv"
    `SVUNIT_TESTS_END
endmodule
