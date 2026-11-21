// ============================================================================
// File: pimod_pfb_tc00.sv
// Description: SVUnit testbench for pimod_pfb.
//
//   The port next to the legacy VHDL (tests/ref), NFFT = 64, B = 16, L = 8 as
//   deployed, on one stimulus. An always-on checker compares s_axis_tready and
//   m_axis_tvalid/tlast/tdata with !== on every falling edge (mism).
//
//   Inputs are driven with a non-blocking assignment right after a rising
//   edge; outputs are sampled on the falling edge.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module pimod_pfb_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "pimod_pfb_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 300e6;
    localparam int  NFFT = 64, B = 16, L = 8;
    localparam int  W = 2 * B * L;
    localparam int  T = NFFT / L;

    logic aclk = 1'b0;
    logic aresetn = 1'b1;
    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(aclk));

    logic         s_tvalid = 1'b0, s_tlast = 1'b0, m_tready = 1'b1;
    logic [W-1:0] s_tdata = '0;
    logic         p_sready, l_sready, p_tvalid, l_tvalid, p_tlast, l_tlast;
    logic [W-1:0] p_tdata, l_tdata;

    pimod_pfb #(.NFFT(NFFT), .B(B), .L(L)) dut (
        .aresetn(aresetn), .aclk(aclk),
        .s_axis_tdata(s_tdata), .s_axis_tlast(s_tlast), .s_axis_tvalid(s_tvalid), .s_axis_tready(p_sready),
        .m_axis_tdata(p_tdata), .m_axis_tlast(p_tlast), .m_axis_tvalid(p_tvalid), .m_axis_tready(m_tready));

    pimod_pfb_legacy #(.NFFT(NFFT), .B(B), .L(L)) ref_i (
        .aresetn(aresetn), .aclk(aclk),
        .s_axis_tdata(s_tdata), .s_axis_tlast(s_tlast), .s_axis_tvalid(s_tvalid), .s_axis_tready(l_sready),
        .m_axis_tdata(l_tdata), .m_axis_tlast(l_tlast), .m_axis_tvalid(l_tvalid), .m_axis_tready(m_tready));

    bit cmp_en = 1'b0;
    int mism = 0, n_valid = 0;

    always @(negedge aclk) if (cmp_en) begin
        if (p_sready !== l_sready || p_tvalid !== l_tvalid || p_tlast !== l_tlast || p_tdata !== l_tdata) mism++;
        if (l_tvalid) n_valid++;
    end

    // Output log for the behavioural test.
    logic [W-1:0] o_data [$];
    always @(negedge aclk) if (p_tvalid && m_tready) o_data.push_back(p_tdata);

    task automatic step(input logic valid, input logic last, input logic [W-1:0] data);
        @(posedge aclk);
        s_tvalid <= valid;
        s_tlast  <= last;
        s_tdata  <= data;
    endtask

    function automatic logic [W-1:0] rand_word();
        logic [W-1:0] w;
        for (int i = 0; i < W / 16; i++)
            case ($urandom_range(7))
                0:       w[i*16 +: 16] = 16'h8000;   // -2^15: saturates when negated
                1:       w[i*16 +: 16] = 16'h7fff;
                default: w[i*16 +: 16] = 16'($urandom);
            endcase
        return w;
    endfunction

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
        s_tvalid = 1'b0; s_tlast = 1'b0; m_tready = 1'b1;
        reset_dut();
        mism = 0; n_valid = 0;
        o_data.delete();
    endtask

    task teardown();
        svunit_ut.teardown();
        cmp_en = 1'b0;
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "pimod_pfb_tests.sv"
    `SVUNIT_TESTS_END
endmodule
