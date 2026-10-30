// ============================================================================
// File: pfb_readout_tc00.sv
// Description: SVUnit testbench for pfb_readout.
//
//   - Wiring: the port at NOUT = 8 next to the legacy v4 pfb_readout +
//     pfb_top + ddsprod_v, and at NOUT = 4 next to the legacy v3 ones
//     (tests/ref, on the same ported children), N = 64, L = 4; an always-on
//     checker compares tvalid on every falling edge and every output's tdata
//     whenever valid, with !== (mism).
//   - Function: a tone inside a PFB channel, that channel selected and its
//     DDS set to the tone's offset, comes out as a constant.
//
//   Inputs are driven with a non-blocking assignment right after a rising
//   edge; outputs are sampled on the falling edge.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module pfb_readout_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "pfb_readout_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 300e6;
    localparam real PI = 3.14159265358979323846;
    localparam int  N = 64, L = 4;

    logic aclk = 1'b0;
    logic aresetn = 1'b1;
    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(aclk));

    logic            s_tvalid = 1'b0;
    logic [L*32-1:0] s_tdata  = '0;
    logic [15:0]     id   [8] = '{default: '0};
    logic [31:0]     pinc [8] = '{default: '0};
    logic [31:0]     poff [8] = '{default: '0};

    // NOUT = 8 (v4)
    logic        p8_v, l8_v;
    logic [31:0] p8_d [8], l8_d [8];
    pfb_readout #(.N(N), .L(L), .NOUT(8)) dut8 (
        .aresetn(aresetn), .aclk(aclk), .s_axis_tvalid(s_tvalid), .s_axis_tdata(s_tdata),
        .m_axis_tvalid(p8_v), .m_axis_tdata(p8_d), .id_reg(id), .pinc_reg(pinc), .poff_reg(poff));
    pfb_readout_v4_legacy #(.N(N), .L(L)) ref8 (
        .aresetn(aresetn), .aclk(aclk), .s_axis_tvalid(s_tvalid), .s_axis_tdata(s_tdata),
        .m_axis_tvalid(l8_v),
        .m0_axis_tdata(l8_d[0]), .m1_axis_tdata(l8_d[1]), .m2_axis_tdata(l8_d[2]), .m3_axis_tdata(l8_d[3]),
        .m4_axis_tdata(l8_d[4]), .m5_axis_tdata(l8_d[5]), .m6_axis_tdata(l8_d[6]), .m7_axis_tdata(l8_d[7]),
        .ID0_REG(id[0]), .ID1_REG(id[1]), .ID2_REG(id[2]), .ID3_REG(id[3]),
        .ID4_REG(id[4]), .ID5_REG(id[5]), .ID6_REG(id[6]), .ID7_REG(id[7]),
        .PINC0_REG(pinc[0]), .POFF0_REG(poff[0]), .PINC1_REG(pinc[1]), .POFF1_REG(poff[1]),
        .PINC2_REG(pinc[2]), .POFF2_REG(poff[2]), .PINC3_REG(pinc[3]), .POFF3_REG(poff[3]),
        .PINC4_REG(pinc[4]), .POFF4_REG(poff[4]), .PINC5_REG(pinc[5]), .POFF5_REG(poff[5]),
        .PINC6_REG(pinc[6]), .POFF6_REG(poff[6]), .PINC7_REG(pinc[7]), .POFF7_REG(poff[7]));

    // NOUT = 4 (v3)
    logic        p4_v, l4_v;
    logic [31:0] p4_d [4], l4_d [4];
    logic [15:0] id4 [4];
    logic [31:0] pinc4 [4], poff4 [4];
    for (genvar i = 0; i < 4; i++) begin : g4
        assign id4[i] = id[i]; assign pinc4[i] = pinc[i]; assign poff4[i] = poff[i];
    end
    pfb_readout #(.N(N), .L(L), .NOUT(4)) dut4 (
        .aresetn(aresetn), .aclk(aclk), .s_axis_tvalid(s_tvalid), .s_axis_tdata(s_tdata),
        .m_axis_tvalid(p4_v), .m_axis_tdata(p4_d), .id_reg(id4), .pinc_reg(pinc4), .poff_reg(poff4));
    pfb_readout_v3_legacy #(.N(N), .L(L)) ref4 (
        .aresetn(aresetn), .aclk(aclk), .s_axis_tvalid(s_tvalid), .s_axis_tdata(s_tdata),
        .m_axis_tvalid(l4_v),
        .m0_axis_tdata(l4_d[0]), .m1_axis_tdata(l4_d[1]), .m2_axis_tdata(l4_d[2]), .m3_axis_tdata(l4_d[3]),
        .ID0_REG(id[0]), .ID1_REG(id[1]), .ID2_REG(id[2]), .ID3_REG(id[3]),
        .PINC0_REG(pinc[0]), .POFF0_REG(poff[0]), .PINC1_REG(pinc[1]), .POFF1_REG(poff[1]),
        .PINC2_REG(pinc[2]), .POFF2_REG(poff[2]), .PINC3_REG(pinc[3]), .POFF3_REG(poff[3]));

    bit cmp_en = 1'b0;
    int mism = 0, n_valid = 0;
    int o_i [$], o_q [$];       // output 0 of dut8

    always @(negedge aclk) if (cmp_en) begin
        if (p8_v !== l8_v || p4_v !== l4_v) mism++;
        if (l8_v) for (int i = 0; i < 8; i++) if (p8_d[i] !== l8_d[i]) mism++;
        if (l4_v) for (int i = 0; i < 4; i++) if (p4_d[i] !== l4_d[i]) mism++;
        if (l8_v) begin
            n_valid++;
            o_i.push_back($signed(p8_d[0][15:0]));
            o_q.push_back($signed(p8_d[0][31:16]));
        end
    end

    real ph = 0.0;
    task automatic tone(input real f, input real amp, input int nclk);
        for (int t = 0; t < nclk; t++) begin
            @(posedge aclk);
            s_tvalid <= 1'b1;
            for (int i = 0; i < L; i++) begin
                s_tdata[i*32      +: 16] <= 16'($rtoi(amp * $cos(ph)));
                s_tdata[i*32 + 16 +: 16] <= 16'($rtoi(amp * $sin(ph)));
                ph += 2.0 * PI * f;
            end
        end
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
        mism = 0; n_valid = 0;
        o_i.delete(); o_q.delete();
    endtask

    task teardown();
        svunit_ut.teardown();
        cmp_en = 1'b0;
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "pfb_readout_tests.sv"
    `SVUNIT_TESTS_END
endmodule
