// ============================================================================
// File: pfb_chsel_tc00.sv
// Description: SVUnit testbench for pfb_chsel.
//
//   The port next to the legacy RTL (tests/ref/pfb_chsel_legacy.sv), B = 32,
//   L = 8 as deployed, on one stimulus. An always-on checker compares
//   m_axis_tvalid/tdata with !== on every falling edge (mism).
//
//   Inputs are driven with a non-blocking assignment right after a rising
//   edge; outputs are sampled on the falling edge.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module pfb_chsel_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "pfb_chsel_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 300e6;
    localparam int  B = 32, L = 8, NFR = 8;

    logic aclk = 1'b0;
    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(aclk));

    logic [L*B-1:0] s_tdata = '0;
    logic           s_tlast = 1'b0;
    logic [15:0]    id = '0;
    logic           p_tvalid, l_tvalid;
    logic [B-1:0]   p_tdata, l_tdata;

    pfb_chsel #(.B(B), .L(L)) dut (
        .aclk(aclk), .s_axis_tdata(s_tdata), .s_axis_tlast(s_tlast),
        .m_axis_tvalid(p_tvalid), .m_axis_tdata(p_tdata), .id_reg(id));

    pfb_chsel_legacy #(.B(B), .L(L)) ref_i (
        .aclk(aclk), .s_axis_tdata(s_tdata), .s_axis_tlast(s_tlast),
        .m_axis_tvalid(l_tvalid), .m_axis_tdata(l_tdata), .ID_REG(id));

    bit cmp_en = 1'b0;
    int mism = 0, n_valid = 0;
    logic [B-1:0] o_data [$];

    always @(negedge aclk) if (cmp_en) begin
        if (p_tvalid !== l_tvalid || p_tdata !== l_tdata) mism++;
        if (l_tvalid) begin n_valid++; o_data.push_back(p_tdata); end
    end

    // One frame of NFR clocks, tlast on the last; word w of clock t carries
    // {frame number, t, w} so every channel is recognisable.
    int frame_no = 0;
    task automatic frame();
        for (int t = 0; t < NFR; t++) begin
            @(posedge aclk);
            s_tlast <= (t == NFR - 1);
            for (int w = 0; w < L; w++) s_tdata[w*B +: B] <= {16'(frame_no), 8'(t), 8'(w)};
        end
        frame_no++;
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        cmp_en = 1'b1;
        mism = 0; n_valid = 0;
        o_data.delete();
    endtask

    task teardown();
        svunit_ut.teardown();
        cmp_en = 1'b0;
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "pfb_chsel_tests.sv"
    `SVUNIT_TESTS_END
endmodule
