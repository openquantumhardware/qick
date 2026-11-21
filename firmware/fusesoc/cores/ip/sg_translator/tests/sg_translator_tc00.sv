// ============================================================================
// File: sg_translator_tc00.sv
// Description: SVUnit testbench for sg_translator.
//
//   For each OUT_TYPE (0..3) the port and the legacy RTL (tests/ref/
//   sg_translator_legacy.v, the original file with only its module renamed)
//   are driven with the same inputs and every output is compared bit for
//   bit. On top of that, an independent reference function checks the field
//   layout of the selected output, so a shared misunderstanding of the legacy
//   code would still be caught.
//
//   The block is combinational: inputs are applied with blocking assignments
//   and outputs are read after #1.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module sg_translator_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sg_translator_ut";
    svunit_testcase svunit_ut;

    localparam int NT = 4;   // OUT_TYPE 0..3

    logic [167:0] s_tdata;
    logic         s_tvalid;
    logic [3:0]   m_tready;  // {readout, mux4, int4, gen_v6}

    // Outputs of the port (p_*) and of the legacy RTL (l_*), per OUT_TYPE.
    logic         p_tready [NT], l_tready [NT];
    logic [159:0] p_g6 [NT],     l_g6 [NT];
    logic         p_g6v [NT],    l_g6v [NT];
    logic [87:0]  p_i4 [NT],     l_i4 [NT];
    logic         p_i4v [NT],    l_i4v [NT];
    logic [39:0]  p_m4 [NT],     l_m4 [NT];
    logic         p_m4v [NT],    l_m4v [NT];
    logic [87:0]  p_ro [NT],     l_ro [NT];
    logic         p_rov [NT],    l_rov [NT];

    for (genvar t = 0; t < NT; t++) begin : g_type
        sg_translator #(.OUT_TYPE(t)) dut (
            .aresetn(1'b1), .aclk(1'b0),
            .s_tproc_axis_tdata(s_tdata), .s_tproc_axis_tvalid(s_tvalid), .s_tproc_axis_tready(p_tready[t]),
            .m_gen_v6_axis_tdata(p_g6[t]), .m_gen_v6_axis_tvalid(p_g6v[t]), .m_gen_v6_axis_tready(m_tready[0]),
            .m_int4_axis_tdata(p_i4[t]),   .m_int4_axis_tvalid(p_i4v[t]),   .m_int4_axis_tready(m_tready[1]),
            .m_mux4_axis_tdata(p_m4[t]),   .m_mux4_axis_tvalid(p_m4v[t]),   .m_mux4_axis_tready(m_tready[2]),
            .m_readout_v3_axis_tdata(p_ro[t]), .m_readout_v3_axis_tvalid(p_rov[t]),
            .m_readout_v3_axis_tready(m_tready[3]));

        sg_translator_legacy #(.OUT_TYPE(t)) ref_i (
            .aresetn(1'b1), .aclk(1'b0),
            .s_axis_tdata(s_tdata), .s_axis_tvalid(s_tvalid), .s_axis_tready(l_tready[t]),
            .m_gen_v6_axis_tdata(l_g6[t]), .m_gen_v6_axis_tvalid(l_g6v[t]), .m_gen_v6_axis_tready(m_tready[0]),
            .m_int4_axis_tdata(l_i4[t]),   .m_int4_axis_tvalid(l_i4v[t]),   .m_int4_axis_tready(m_tready[1]),
            .m_mux4_axis_tdata(l_m4[t]),   .m_mux4_axis_tvalid(l_m4v[t]),   .m_mux4_axis_tready(m_tready[2]),
            .m_readout_axis_tdata(l_ro[t]), .m_readout_axis_tvalid(l_rov[t]),
            .m_readout_axis_tready(m_tready[3]));
    end

    // Number of output bits (valids, readies, data) that differ between port
    // and legacy, for OUT_TYPE t.
    function automatic int diff_bits(int t);
        return $countones(p_g6[t] ^ l_g6[t]) + $countones(p_i4[t] ^ l_i4[t]) +
               $countones(p_m4[t] ^ l_m4[t]) + $countones(p_ro[t] ^ l_ro[t]) +
               (p_g6v[t] !== l_g6v[t]) + (p_i4v[t] !== l_i4v[t]) + (p_m4v[t] !== l_m4v[t]) +
               (p_rov[t] !== l_rov[t]) + (p_tready[t] !== l_tready[t]);
    endfunction

    task automatic apply_random();
        s_tdata  = {$urandom, $urandom, $urandom, $urandom, $urandom, $urandom};
        s_tvalid = $urandom_range(0, 1);
        m_tready = 4'($urandom);
        #1;
    endtask

    // Independent reference: descriptor fields, from the tProc v2 word layout.
    function automatic logic [159:0] ref_gen_v6(logic [167:0] d);
        logic [15:0] conf = d[167:152];
        return {11'd0, conf[4], conf[3], conf[2], conf[1:0], d[135:120],
                16'd0, d[103:88], 16'd0, d[79:64], d[63:32], d[31:0]};
    endfunction

    function automatic logic [87:0] ref_int4(logic [167:0] d);
        logic [15:0] conf = d[167:152];
        return {3'd0, conf[4], conf[3], conf[2], conf[1:0], d[135:120],
                d[103:88], d[79:64], d[47:32], d[15:0]};
    endfunction

    function automatic logic [87:0] ref_readout(logic [167:0] d);
        logic [15:0] conf = d[167:152];
        return {4'd0, conf[4], conf[2], conf[1:0], d[135:120], d[63:32], d[31:0]};
    endfunction

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        s_tdata  = '0;
        s_tvalid = 1'b0;
        m_tready = '0;
        #1;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "sg_translator_tests.sv"
    `SVUNIT_TESTS_END
endmodule
