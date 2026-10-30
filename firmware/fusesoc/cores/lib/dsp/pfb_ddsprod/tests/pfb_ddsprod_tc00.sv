// ============================================================================
// File: pfb_ddsprod_tc00.sv
// Description: SVUnit testbench for pfb_ddsprod.
//
//   The port next to the legacy ddsprod chain (tests/ref), both on the same
//   DDS model, on one stimulus. An always-on checker compares m_axis_tvalid
//   on every falling edge and m_axis_tdata whenever it is valid, with !==
//   (mism).
//
//   Inputs are driven with a non-blocking assignment right after a rising
//   edge; outputs are sampled on the falling edge.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module pfb_ddsprod_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "pfb_ddsprod_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 300e6;
    localparam real PI = 3.14159265358979323846;

    logic aclk = 1'b0;
    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(aclk));

    logic        s_tvalid = 1'b0;
    logic [31:0] s_tdata = '0, pinc = '0, poff = '0;
    logic        p_tvalid, l_tvalid;
    logic [31:0] p_tdata, l_tdata;

    pfb_ddsprod dut (
        .aclk(aclk), .s_axis_tvalid(s_tvalid), .s_axis_tdata(s_tdata),
        .m_axis_tvalid(p_tvalid), .m_axis_tdata(p_tdata),
        .pinc_reg(pinc), .poff_reg(poff));

    ddsprod_legacy ref_i (
        .aclk(aclk), .s_axis_tvalid(s_tvalid), .s_axis_tdata(s_tdata),
        .m_axis_tvalid(l_tvalid), .m_axis_tdata(l_tdata),
        .PINC_REG(pinc), .POFF_REG(poff));

    bit cmp_en = 1'b1;
    int mism = 0, n_valid = 0;
    int o_i [$], o_q [$];

    always @(negedge aclk) if (cmp_en) begin
        // tdata only when valid: the legacy leaves the product registers
        // uninitialized (X until the first valid; 0 in hardware, like here).
        if (p_tvalid !== l_tvalid || (l_tvalid && p_tdata !== l_tdata)) mism++;
        if (l_tvalid) n_valid++;
        if (p_tvalid) begin o_i.push_back($signed(p_tdata[15:0])); o_q.push_back($signed(p_tdata[31:16])); end
    end

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        mism = 0; n_valid = 0;
        o_i.delete(); o_q.delete();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "pfb_ddsprod_tests.sv"
    `SVUNIT_TESTS_END
endmodule
