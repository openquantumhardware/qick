// ============================================================================
// File: pfb_firs_tc00.sv
// Description: SVUnit testbench for pfb_firs.
//
//   The port next to the legacy firs (tests/ref/firs_legacy.sv), N = 64,
//   L = 4 as deployed, on one stimulus. An always-on checker compares
//   m_axis_tvalid/tlast/tdata on every falling edge (mism); `!==`, so the
//   unknowns both start with (no reset in the FIRs or the delay line) must
//   match too.
//
//   Inputs are driven with a non-blocking assignment right after a rising
//   edge; outputs are sampled on the falling edge.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module pfb_firs_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "pfb_firs_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 300e6;
    localparam int  N = 64, L = 4;

    logic aclk = 1'b0;
    logic aresetn = 1'b1;
    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(aclk));

    logic              s_tvalid = 1'b0;
    logic [L*32-1:0]   s_tdata  = '0;
    logic              p_tvalid, l_tvalid, p_tlast, l_tlast;
    logic [2*L*32-1:0] p_tdata, l_tdata;

    pfb_firs #(.N(N), .L(L)) dut (
        .aresetn(aresetn), .aclk(aclk),
        .s_axis_tvalid(s_tvalid), .s_axis_tdata(s_tdata),
        .m_axis_tvalid(p_tvalid), .m_axis_tlast(p_tlast), .m_axis_tdata(p_tdata));

    firs_legacy #(.N(N), .L(L)) ref_i (
        .aresetn(aresetn), .aclk(aclk),
        .s_axis_tvalid(s_tvalid), .s_axis_tdata(s_tdata),
        .m_axis_tvalid(l_tvalid), .m_axis_tlast(l_tlast), .m_axis_tdata(l_tdata));

    bit cmp_en = 1'b0;
    int mism = 0, n_valid = 0, n_sync = 0;

    always @(negedge aclk) if (cmp_en) begin
        if (p_tvalid !== l_tvalid || p_tlast !== l_tlast || p_tdata !== l_tdata) mism++;
        if (l_tvalid) n_valid++;
        if (dut.fr_sync) n_sync++;
    end

    // One input clock: random I/Q on every lane (amplitude 2^13).
    task automatic step(input logic valid);
        @(posedge aclk);
        s_tvalid <= valid;
        for (int i = 0; i < 2 * L; i++) s_tdata[i*16 +: 16] <= 16'($signed(14'($urandom)));
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
        mism = 0; n_valid = 0; n_sync = 0;
    endtask

    task teardown();
        svunit_ut.teardown();
        cmp_en = 1'b0;
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "pfb_firs_tests.sv"
    `SVUNIT_TESTS_END
endmodule
