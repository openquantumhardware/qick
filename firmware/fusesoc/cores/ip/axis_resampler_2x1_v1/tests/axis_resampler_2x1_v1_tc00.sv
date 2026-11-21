// ============================================================================
// File: axis_resampler_2x1_v1_tc00.sv
// Description: SVUnit testbench for axis_resampler_2x1_v1 at the deployed
//              B = 16, N = 8 (216/tpv2_demo), next to the legacy RTL
//              (tests/ref/axis_resampler_2x1_v1_legacy.sv, the original file
//              with only the module renamed).
//
//   Sampling convention (no clocking block): inputs driven with a
//   non-blocking assignment right after a rising edge, outputs read TSU after
//   a rising edge. The input is valid at most every other clock, as the IP
//   requires.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_resampler_2x1_v1_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_resampler_2x1_v1_ut";
    svunit_testcase svunit_ut;

    localparam int  B = 16, N = 8;
    localparam time TSU = 1ns;
    localparam int  HMAX = 8192;

    logic aclk = 1'b0;
    logic aresetn = 1'b1;
    clk_gen #(.FREQ(250e6)) u_clk (.i_enable(1'b1), .o_clk(aclk));

    logic [N*B-1:0]   s_tdata  = '0;
    logic             s_tvalid = 1'b0;
    logic [N/2*B-1:0] p_tdata, l_tdata;
    logic             p_tvalid, l_tvalid, p_tready, l_tready;

    axis_resampler_2x1_v1 #(.B(B), .N(N)) dut (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tready(p_tready), .s_axis_tvalid(s_tvalid), .s_axis_tdata(s_tdata),
        .m_axis_tready(1'b1), .m_axis_tvalid(p_tvalid), .m_axis_tdata(p_tdata));
    axis_resampler_2x1_v1_legacy #(.B(B), .N(N)) ref_i (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tready(l_tready), .s_axis_tvalid(s_tvalid), .s_axis_tdata(s_tdata),
        .m_axis_tready(1'b1), .m_axis_tvalid(l_tvalid), .m_axis_tdata(l_tdata));

    logic [N*B-1:0] h_data [HMAX];
    logic           h_val  [HMAX];
    int             t_now;

    // Drive one input clock; 'valid' must not be 1 on two consecutive calls.
    task automatic step(input logic valid);
        @(posedge aclk);
        t_now++;
        h_data[t_now] = {$urandom, $urandom, $urandom, $urandom};
        h_val[t_now]  = valid;
        s_tdata  <= h_data[t_now];
        s_tvalid <= valid;
        #TSU;
    endtask

    function void build(); svunit_ut = new(name); endfunction

    task setup();
        svunit_ut.setup();
        s_tdata = '0; s_tvalid = 1'b0;
        aresetn <= 1'b0;
        repeat (4) @(posedge aclk);
        aresetn <= 1'b1;
        t_now = 0; h_val[0] = 1'b0; h_data[0] = '0;
        #TSU;
    endtask

    task teardown(); svunit_ut.teardown(); endtask

    `SVUNIT_TESTS_BEGIN
    `include "axis_resampler_2x1_v1_tests.sv"
    `SVUNIT_TESTS_END
endmodule
