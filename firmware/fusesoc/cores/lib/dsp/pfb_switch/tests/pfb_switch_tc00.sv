// ============================================================================
// File: pfb_switch_tc00.sv
// Description: SVUnit testbench for pfb_switch.
//
//   The port next to the legacy pfb_switch + pfb_reorder + pfb_swap and its
//   VHDL FIFOs (tests/ref), B = 32, L = 4, N = 64 as deployed, on one
//   stimulus. An always-on checker compares m_axis_tvalid/tlast/tdata with
//   !== on every falling edge (mism).
//
//   Inputs are driven with a non-blocking assignment right after a rising
//   edge; outputs are sampled on the falling edge.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module pfb_switch_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "pfb_switch_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 300e6;
    localparam int  B = 32, L = 4, N = 64;
    localparam int  NP = N / (2 * L);
    localparam int  W = 2 * L * B;

    logic aclk = 1'b0;
    logic aresetn = 1'b1;
    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(aclk));

    logic         s_tlast = 1'b0;
    logic [W-1:0] s_tdata = '0;
    logic         p_tvalid, l_tvalid, p_tlast, l_tlast;
    logic [W-1:0] p_tdata, l_tdata;

    pfb_switch #(.B(B), .L(L), .N(N)) dut (
        .aresetn(aresetn), .aclk(aclk),
        .s_axis_tvalid(1'b1), .s_axis_tlast(s_tlast), .s_axis_tdata(s_tdata),
        .m_axis_tvalid(p_tvalid), .m_axis_tlast(p_tlast), .m_axis_tdata(p_tdata));

    pfb_switch_legacy #(.B(B), .L(L), .N(N)) ref_i (
        .aresetn(aresetn), .aclk(aclk),
        .s_axis_tvalid(1'b1), .s_axis_tlast(s_tlast), .s_axis_tdata(s_tdata),
        .m_axis_tvalid(l_tvalid), .m_axis_tlast(l_tlast), .m_axis_tdata(l_tdata));

    bit cmp_en = 1'b0;
    int mism = 0, n_rw1 = 0;

    always @(negedge aclk) if (cmp_en) begin
        if (p_tvalid !== l_tvalid || p_tlast !== l_tlast || p_tdata !== l_tdata) mism++;
        if (dut.rw1_state) n_rw1++;
    end

    task automatic step(input logic last);
        @(posedge aclk);
        s_tlast <= last;
        for (int i = 0; i < W / 32; i++) s_tdata[i*32 +: 32] <= $urandom;
    endtask

    // n frames of NP clocks, tlast on the last clock of each.
    task automatic frames(input int n);
        for (int f = 0; f < n; f++)
            for (int t = 0; t < NP; t++) step(t == NP - 1);
    endtask

    task automatic reset_dut();
        @(posedge aclk);
        aresetn <= 1'b0;
        repeat (3) @(posedge aclk);
        aresetn <= 1'b1;
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        cmp_en = 1'b1;
        reset_dut();
        mism = 0; n_rw1 = 0;
    endtask

    task teardown();
        svunit_ut.teardown();
        cmp_en = 1'b0;
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "pfb_switch_tests.sv"
    `SVUNIT_TESTS_END
endmodule
