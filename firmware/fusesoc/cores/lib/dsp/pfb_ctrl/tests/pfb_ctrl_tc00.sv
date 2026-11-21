// ============================================================================
// File: pfb_ctrl_tc00.sv
// Description: SVUnit testbench for pfb_ctrl.
//
//   Two configurations, each next to the legacy VHDL (tests/ref/*_legacy.vhd,
//   the original files with only the design-unit names changed):
//     c0: N = 8   (the PFB readouts: 64 channels / 8 lanes)
//     c1: N = 16
//   Both share one stimulus. An always-on checker compares every output on
//   every falling edge (mism).
//
//   Inputs are driven with a non-blocking assignment right after a rising
//   edge; outputs are sampled on the falling edge.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module pfb_ctrl_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "pfb_ctrl_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 300e6;
    localparam int  NC = 2;
    localparam int  CN [NC] = '{8, 16};

    logic aclk = 1'b0;
    logic aresetn = 1'b1;
    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(aclk));

    logic cfg_tready = 1'b1, cfg_en = 1'b1, tready = 1'b1, tvalid = 1'b1, fr_sync = 1'b0;

    logic       p_cv [NC], l_cv [NC], p_cl [NC], l_cl [NC], p_fr [NC], l_fr [NC];
    logic [7:0] p_cd [NC], l_cd [NC];

    for (genvar c = 0; c < NC; c++) begin : g_cfg
        pfb_ctrl #(.N(CN[c])) dut (
            .aresetn(aresetn), .aclk(aclk),
            .m_axis_config_tvalid(p_cv[c]), .m_axis_config_tready(cfg_tready),
            .m_axis_config_tlast(p_cl[c]), .m_axis_config_tdata(p_cd[c]),
            .cfg_en(cfg_en), .tready(tready), .tvalid(tvalid),
            .fr_sync(fr_sync), .fr_out(p_fr[c]));

        pfb_ctrl_legacy #(.N(CN[c])) ref_i (
            .aresetn(aresetn), .aclk(aclk),
            .m_axis_config_tvalid(l_cv[c]), .m_axis_config_tready(cfg_tready),
            .m_axis_config_tlast(l_cl[c]), .m_axis_config_tdata(l_cd[c]),
            .cfg_en(cfg_en), .tready(tready), .tvalid(tvalid),
            .fr_sync(fr_sync), .fr_out(l_fr[c]));
    end

    bit cmp_en = 1'b0;
    int mism = 0;
    int n_cfg [NC], n_fr [NC];

    always @(negedge aclk) if (cmp_en)
        for (int c = 0; c < NC; c++) begin
            if (p_cv[c] !== l_cv[c] || p_cl[c] !== l_cl[c] || p_fr[c] !== l_fr[c]) mism++;
            if (p_cd[c] !== l_cd[c]) mism++;
            if (l_cv[c]) n_cfg[c]++;
            if (l_fr[c]) n_fr[c]++;
        end

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
        cmp_en = 1'b0;
        cfg_tready = 1'b1; cfg_en = 1'b1; tready = 1'b1; tvalid = 1'b1; fr_sync = 1'b0;
        reset_dut();
        mism = 0;
        for (int c = 0; c < NC; c++) begin n_cfg[c] = 0; n_fr[c] = 0; end
        cmp_en = 1'b1;
    endtask

    task teardown();
        svunit_ut.teardown();
        cmp_en = 1'b0;
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "pfb_ctrl_tests.sv"
    `SVUNIT_TESTS_END
endmodule
