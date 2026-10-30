// ============================================================================
// File: axis_constant_tc00.sv
// Description: SVUnit testbench for axis_constant (tie-off master): two
//              instances, DATA_WIDTH = 64 and 160 (as in the 111 tpv1 BDs).
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_constant_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_constant_ut";
    svunit_testcase svunit_ut;

    logic aclk = 1'b0;
    logic aresetn = 1'b0;
    logic tready = 1'b0;
    clk_gen #(.FREQ(100e6)) u_clk (.i_enable(1'b1), .o_clk(aclk));

    logic [63:0]  d64;  logic [7:0]  s64;  logic l64, v64;
    logic [159:0] d160; logic [19:0] s160; logic l160, v160;

    axis_constant #(.DATA_WIDTH(64)) dut64 (
        .m_axis_aclk(aclk), .m_axis_aresetn(aresetn), .m_axis_tready(tready),
        .m_axis_tdata(d64), .m_axis_tstrb(s64), .m_axis_tlast(l64), .m_axis_tvalid(v64));
    axis_constant #(.DATA_WIDTH(160)) dut160 (
        .m_axis_aclk(aclk), .m_axis_aresetn(aresetn), .m_axis_tready(tready),
        .m_axis_tdata(d160), .m_axis_tstrb(s160), .m_axis_tlast(l160), .m_axis_tvalid(v160));

    function automatic bit all_zero();
        return (d64 === '0) && (s64 === '0) && (l64 === 1'b0) && (v64 === 1'b0) &&
               (d160 === '0) && (s160 === '0) && (l160 === 1'b0) && (v160 === 1'b0);
    endfunction

    function void build(); svunit_ut = new(name); endfunction
    task setup();    svunit_ut.setup();    endtask
    task teardown(); svunit_ut.teardown(); endtask

    `SVUNIT_TESTS_BEGIN
    `include "axis_constant_tests.sv"
    `SVUNIT_TESTS_END
endmodule
