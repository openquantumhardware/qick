// ============================================================================
// File: axis_terminator_tc00.sv
// Description: SVUnit testbench for axis_terminator (sink): DATA_WIDTH = 256
//              (as in 111 tpv1_rfbv1_std) and the default 16.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_terminator_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_terminator_ut";
    svunit_testcase svunit_ut;

    logic aclk = 1'b0;
    logic aresetn = 1'b0;
    clk_gen #(.FREQ(100e6)) u_clk (.i_enable(1'b1), .o_clk(aclk));

    logic [255:0] d256 = '0; logic [31:0] s256 = '0;
    logic [15:0]  d16  = '0; logic [1:0]  s16  = '0;
    logic         tlast = 1'b0, tvalid = 1'b0;
    logic         r256, r16;

    axis_terminator #(.DATA_WIDTH(256)) dut256 (
        .s_axis_aclk(aclk), .s_axis_aresetn(aresetn), .s_axis_tready(r256),
        .s_axis_tdata(d256), .s_axis_tstrb(s256), .s_axis_tlast(tlast), .s_axis_tvalid(tvalid));
    axis_terminator #(.DATA_WIDTH(16)) dut16 (
        .s_axis_aclk(aclk), .s_axis_aresetn(aresetn), .s_axis_tready(r16),
        .s_axis_tdata(d16), .s_axis_tstrb(s16), .s_axis_tlast(tlast), .s_axis_tvalid(tvalid));

    function void build(); svunit_ut = new(name); endfunction
    task setup();    svunit_ut.setup();    endtask
    task teardown(); svunit_ut.teardown(); endtask

    `SVUNIT_TESTS_BEGIN
    `include "axis_terminator_tests.sv"
    `SVUNIT_TESTS_END
endmodule
