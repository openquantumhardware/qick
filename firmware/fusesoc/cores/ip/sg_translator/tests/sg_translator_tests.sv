// ============================================================================
// File: sg_translator_tests.sv
// Description: SVUnit test cases for sg_translator. Included by
//              sg_translator_tc00.sv.
// ============================================================================

// Port and legacy RTL agree on every output bit, for every OUT_TYPE, over
// random descriptors, tvalid and treadys.
`SVTEST(tc_matches_legacy_all_out_types)
    int errs [NT];
    for (int t = 0; t < NT; t++) errs[t] = 0;
    for (int k = 0; k < 2000; k++) begin
        apply_random();
        for (int t = 0; t < NT; t++) errs[t] += diff_bits(t);
    end
    for (int t = 0; t < NT; t++)
        `FAIL_UNLESS_LOG(errs[t] == 0, $sformatf("OUT_TYPE=%0d: %0d bits differ from the legacy RTL", t, errs[t]));
`SVTEST_END

// Only the output selected by OUT_TYPE is valid, and it carries s_tvalid.
`SVTEST(tc_only_selected_output_valid)
    for (int k = 0; k < 200; k++) begin
        apply_random();
        `FAIL_UNLESS(p_g6v[0] === s_tvalid && p_i4v[0] === 1'b0 && p_m4v[0] === 1'b0 && p_rov[0] === 1'b0);
        `FAIL_UNLESS(p_g6v[1] === 1'b0 && p_i4v[1] === s_tvalid && p_m4v[1] === 1'b0 && p_rov[1] === 1'b0);
        `FAIL_UNLESS(p_g6v[2] === 1'b0 && p_i4v[2] === 1'b0 && p_m4v[2] === s_tvalid && p_rov[2] === 1'b0);
        `FAIL_UNLESS(p_g6v[3] === 1'b0 && p_i4v[3] === 1'b0 && p_m4v[3] === 1'b0 && p_rov[3] === s_tvalid);
    end
`SVTEST_END

// s_tproc_axis_tready is the selected output's tready.
`SVTEST(tc_tready_follows_selected_output)
    for (int k = 0; k < 200; k++) begin
        apply_random();
        for (int t = 0; t < NT; t++)
            `FAIL_UNLESS_LOG(p_tready[t] === m_tready[t],
                $sformatf("OUT_TYPE=%0d: tready %b, selected output's tready %b", t, p_tready[t], m_tready[t]));
    end
`SVTEST_END

// Field layout of each output, against a reference written from the tProc v2
// descriptor layout (not from the legacy RTL).
`SVTEST(tc_field_layout)
    for (int k = 0; k < 500; k++) begin
        apply_random();
        `FAIL_UNLESS(p_g6[0] === ref_gen_v6(s_tdata));
        `FAIL_UNLESS(p_i4[1] === ref_int4(s_tdata));
        `FAIL_UNLESS(p_m4[2] === {s_tdata[159:152], s_tdata[151:120]});
        `FAIL_UNLESS(p_ro[3] === ref_readout(s_tdata));
    end
`SVTEST_END

// One hand-built gen_v6 descriptor, to show the layout with readable numbers:
// freq, phase, env address 0x0123, gain 0x4567, length 100, outsel 1, mode 1,
// stdysel 0, phrst 1.
`SVTEST(tc_gen_v6_example)
    s_tdata = '0;
    s_tdata[31:0]    = 32'h1234_5678;         // freq
    s_tdata[63:32]   = 32'h9abc_def0;         // phase
    s_tdata[87:64]   = 24'h00_0123;           // env address
    s_tdata[119:88]  = 32'h0000_4567;         // gain
    s_tdata[151:120] = 32'd100;               // length
    s_tdata[167:152] = 16'b1_0_1_01;          // phrst=1 stdysel=0 mode=1 outsel=01
    s_tvalid = 1'b1;
    #1;
    `FAIL_UNLESS(p_g6[0][31:0]    === 32'h1234_5678);
    `FAIL_UNLESS(p_g6[0][63:32]   === 32'h9abc_def0);
    `FAIL_UNLESS(p_g6[0][79:64]   === 16'h0123);
    `FAIL_UNLESS(p_g6[0][111:96]  === 16'h4567);
    `FAIL_UNLESS(p_g6[0][143:128] === 16'd100);
    `FAIL_UNLESS(p_g6[0][145:144] === 2'b01);
    `FAIL_UNLESS(p_g6[0][146]     === 1'b1);
    `FAIL_UNLESS(p_g6[0][147]     === 1'b0);
    `FAIL_UNLESS(p_g6[0][148]     === 1'b1);
    `FAIL_UNLESS(p_g6[0][159:149] === 11'd0);
`SVTEST_END
