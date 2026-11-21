// ============================================================================
// File: axis_tmux_v1_tc00.sv
// Description: SVUnit testbench for axis_tmux_v1.
//
//   Four configurations side by side, each next to the legacy RTL (tests/
//   ref/axis_tmux_v1_legacy.sv, the original files with only the module
//   names changed):
//     c0: N=3, B=168   (216 tpv2_std / tpv2_1ch)
//     c1: N=4, B=168   (216 tpv2_demo / tpv2_std_rfbv2)
//     c2: N=2, B=16    (packaged defaults)
//     c3: N=8, B=32    (all outputs)
//   All share one 168-bit stimulus; narrower instances take its low bits,
//   with the selection byte moved to their own top byte.
//
//   Sampling convention (no clocking block): inputs driven with a
//   non-blocking assignment right after a rising edge, outputs read TSU after
//   a rising edge.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_tmux_v1_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_tmux_v1_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 250e6;
    localparam time TSU = 1ns;
    localparam int  NC = 4;
    localparam int  CN [NC] = '{3, 4, 2, 8};
    localparam int  CB [NC] = '{168, 168, 16, 32};

    logic aclk    = 1'b0;
    logic aresetn = 1'b1;

    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(aclk));

    logic [159:0] s_payload = '0;   // everything below the selection byte
    logic [7:0]   s_sel     = '0;   // selection byte (top byte of each instance's word)
    logic         s_tvalid  = 1'b0;

    // Per configuration: port (p_*) and legacy (l_*) outputs, widest width.
    logic         p_tready [NC], l_tready [NC];
    logic [7:0]   p_valid [NC],  l_valid [NC];
    logic [167:0] p_data [NC][8], l_data [NC][8];

    for (genvar c = 0; c < NC; c++) begin : g_cfg
        localparam int N = CN[c];
        localparam int B = CB[c];
        logic [B-1:0] din;
        logic [B-1:0] pd [8], ld [8];
        assign din = {s_sel, s_payload[B-9:0]};

        axis_tmux_v1 #(.N(N), .B(B)) dut (
            .aresetn(aresetn), .aclk(aclk),
            .s_axis_tready(p_tready[c]), .s_axis_tvalid(s_tvalid), .s_axis_tdata(din),
            .m0_axis_tvalid(p_valid[c][0]), .m0_axis_tdata(pd[0]),
            .m1_axis_tvalid(p_valid[c][1]), .m1_axis_tdata(pd[1]),
            .m2_axis_tvalid(p_valid[c][2]), .m2_axis_tdata(pd[2]),
            .m3_axis_tvalid(p_valid[c][3]), .m3_axis_tdata(pd[3]),
            .m4_axis_tvalid(p_valid[c][4]), .m4_axis_tdata(pd[4]),
            .m5_axis_tvalid(p_valid[c][5]), .m5_axis_tdata(pd[5]),
            .m6_axis_tvalid(p_valid[c][6]), .m6_axis_tdata(pd[6]),
            .m7_axis_tvalid(p_valid[c][7]), .m7_axis_tdata(pd[7]));

        axis_tmux_v1_legacy #(.N(N), .B(B)) ref_i (
            .aresetn(aresetn), .aclk(aclk),
            .s_axis_tready(l_tready[c]), .s_axis_tvalid(s_tvalid), .s_axis_tdata(din),
            .m0_axis_tvalid(l_valid[c][0]), .m0_axis_tdata(ld[0]),
            .m1_axis_tvalid(l_valid[c][1]), .m1_axis_tdata(ld[1]),
            .m2_axis_tvalid(l_valid[c][2]), .m2_axis_tdata(ld[2]),
            .m3_axis_tvalid(l_valid[c][3]), .m3_axis_tdata(ld[3]),
            .m4_axis_tvalid(l_valid[c][4]), .m4_axis_tdata(ld[4]),
            .m5_axis_tvalid(l_valid[c][5]), .m5_axis_tdata(ld[5]),
            .m6_axis_tvalid(l_valid[c][6]), .m6_axis_tdata(ld[6]),
            .m7_axis_tvalid(l_valid[c][7]), .m7_axis_tdata(ld[7]));

        for (genvar i = 0; i < 8; i++) begin : g_out
            assign p_data[c][i] = 168'(pd[i]);
            assign l_data[c][i] = 168'(ld[i]);
        end
    end

    // Stimulus history, for the latency-2 scoreboard.
    localparam int HMAX = 8192;
    logic [7:0]   h_sel [HMAX];
    logic [159:0] h_pay [HMAX];
    logic         h_val [HMAX];
    int           t_now;

    task automatic step(input logic [7:0] sel, input logic valid);
        @(posedge aclk);
        t_now++;
        h_sel[t_now] = sel;
        h_pay[t_now] = {$urandom, $urandom, $urandom, $urandom, $urandom};
        h_val[t_now] = valid;
        s_sel     <= sel;
        s_payload <= h_pay[t_now];
        s_tvalid  <= valid;
        #TSU;
    endtask

    // Bits (valids, and data of the outputs that exist, index < N) that
    // differ between port and legacy, for configuration c.
    function automatic int diff_bits(int c);
        int d = (p_tready[c] !== l_tready[c]);
        for (int i = 0; i < CN[c]; i++)
            d += (p_valid[c][i] !== l_valid[c][i]) + $countones(p_data[c][i] ^ l_data[c][i]);
        return d;
    endfunction

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        s_sel = '0; s_payload = '0; s_tvalid = 1'b0;
        aresetn <= 1'b0;
        repeat (4) @(posedge aclk);
        aresetn <= 1'b1;
        t_now = 0;
        h_sel[0] = '0; h_pay[0] = '0; h_val[0] = 1'b0;
        #TSU;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "axis_tmux_v1_tests.sv"
    `SVUNIT_TESTS_END
endmodule
