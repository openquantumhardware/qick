// ============================================================================
// File: fir_decim8_dynro_tests.sv
// Description: SVUnit test cases for fir_decim8_dynro. Included by
//              fir_decim8_dynro_tc00.sv.
// ============================================================================

`SVTEST(tc_zero_input_gives_zero_output)
    drive_zero_block();
    `FAIL_UNLESS(tb_m_tdata === 32'h0000_0000);
`SVTEST_END

`SVTEST(tc_tready_and_tvalid_tied_high)
    `FAIL_UNLESS(tb_s_tready === 1'b1);
    `FAIL_UNLESS(tb_m_tvalid === 1'b1);
`SVTEST_END

`SVTEST(tc_impulse_block_produces_nonzero_output_within_latency)
    bit found_nonzero;
    int n;
    drive_const_block(16'sd16384, 16'h0000);
    found_nonzero = 1'b0;
    for (n = 0; n < 20; n++) begin
        drive_zero_block();
        if (tb_m_tdata !== 32'h0000_0000) begin
            found_nonzero = 1'b1;
            break;
        end
    end
    `FAIL_UNLESS(found_nonzero);
`SVTEST_END

`SVTEST(tc_impulse_response_spans_multiple_output_cycles)
    // FIR property: a single nonzero input block must smear across more
    // than one output cycle (many nonzero taps), not collapse to one.
    int nonzero_count;
    int n;
    drive_const_block(16'sd16384, 16'h0000);
    nonzero_count = 0;
    for (n = 0; n < 30; n++) begin
        drive_zero_block();
        if (tb_m_tdata !== 32'h0000_0000)
            nonzero_count++;
    end
    `FAIL_UNLESS(nonzero_count > 1);
`SVTEST_END

`SVTEST(tc_constant_block_reaches_steady_nonzero_output)
    // Drive a constant nonzero real input for long enough to fully
    // populate the 120-tap (15-block) history, then confirm the output has
    // settled to a nonzero value.
    int n;
    for (n = 0; n < 25; n++)
        drive_const_block(16'sd8000, 16'h0000);
    `FAIL_UNLESS(tb_m_tdata[15:0] !== 16'h0000);
`SVTEST_END

`SVTEST(tc_imag_channel_independent_of_real)
    bit found_nonzero_imag;
    int n;
    drive_const_block(16'h0000, 16'sd16384);
    found_nonzero_imag = 1'b0;
    for (n = 0; n < 20; n++) begin
        drive_zero_block();
        `FAIL_IF(tb_m_tdata[15:0] !== 16'h0000);
        if (tb_m_tdata[31:16] !== 16'h0000)
            found_nonzero_imag = 1'b1;
    end
    `FAIL_UNLESS(found_nonzero_imag);
`SVTEST_END
