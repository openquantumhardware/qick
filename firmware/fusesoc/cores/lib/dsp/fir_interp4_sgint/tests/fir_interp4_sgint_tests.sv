// ============================================================================
// File: fir_interp4_sgint_tests.sv
// Description: SVUnit test cases for fir_interp4_sgint. Included by
//              fir_interp4_sgint_tc00.sv.
// ============================================================================

`SVTEST(tc_zero_input_gives_zero_output)
    drive_real_sample(16'h0000, 16'h0000);
    `FAIL_UNLESS(tb_m_tdata === '0);
`SVTEST_END

`SVTEST(tc_tready_and_tvalid_tied_high)
    `FAIL_UNLESS(tb_s_tready === 1'b1);
    `FAIL_UNLESS(tb_m_tvalid === 1'b1);
`SVTEST_END

`SVTEST(tc_impulse_produces_nonzero_output_within_latency)
    bit found_nonzero;
    int n;
    drive_real_sample(16'sd16384, 16'h0000);
    found_nonzero = 1'b0;
    for (n = 0; n < 20; n++) begin
        drive_real_sample(16'h0000, 16'h0000);
        if (tb_m_tdata !== '0) begin
            found_nonzero = 1'b1;
            break;
        end
    end
    `FAIL_UNLESS(found_nonzero);
`SVTEST_END

`SVTEST(tc_impulse_response_spans_multiple_output_beats)
    // FIR property: a single nonzero input sample must smear across more
    // than one output beat (the filter has more than one nonzero tap), not
    // collapse to a single-cycle pulse.
    int nonzero_count;
    int n;
    drive_real_sample(16'sd16384, 16'h0000);
    nonzero_count = 0;
    for (n = 0; n < 30; n++) begin
        drive_real_sample(16'h0000, 16'h0000);
        if (tb_m_tdata !== '0)
            nonzero_count++;
    end
    `FAIL_UNLESS(nonzero_count > 1);
`SVTEST_END

`SVTEST(tc_imag_channel_independent_of_real)
    // Driving only the imaginary input must leave the real output lanes at
    // zero and produce nonzero imaginary output.
    bit found_nonzero_imag;
    int n;
    drive_real_sample(16'h0000, 16'sd16384);
    found_nonzero_imag = 1'b0;
    for (n = 0; n < 20; n++) begin
        drive_real_sample(16'h0000, 16'h0000);
        for (int lane = 0; lane < 4; lane++) begin
            `FAIL_IF(lane_real(lane) !== 16'h0000);
            if (lane_imag(lane) !== 16'h0000)
                found_nonzero_imag = 1'b1;
        end
    end
    `FAIL_UNLESS(found_nonzero_imag);
`SVTEST_END
