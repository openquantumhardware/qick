// ============================================================================
// File: sg_mux8_tests.sv
// Description: SVUnit test cases for sg_mux8. Included by sg_mux8_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_idle)
    `FAIL_UNLESS(tb_m_axis_tvalid_o === 1'b0);
    `FAIL_UNLESS(tb_s_axis_tready_o === 1'b1);
    `FAIL_UNLESS(tb_m_axis_tdata_o === '0);
`SVTEST_END

`SVTEST(tc_descriptor_produces_valid_output)
    bit reached;
    write_channel_regs(0, 32'h1000_0000, 32'h0000_0000, 16'h7FFF);
    push_descriptor(8'h01, 32'd20);
    wait_for_mvalid(1'b1, 40, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END

`SVTEST(tc_all_channels_masked_off_gives_zero_output)
    bit reached;
    write_channel_regs(0, 32'h1000_0000, 32'h0000_0000, 16'h7FFF);
    // mask=0: every channel is muted regardless of PINC/GAIN, so the
    // adder-tree sum (and therefore m_axis_tdata_o) must stay zero even
    // while tvalid is asserted for the descriptor's duration.
    push_descriptor(8'h00, 32'd20);
    wait_for_mvalid(1'b1, 40, reached);
    `FAIL_UNLESS(reached);
    `FAIL_UNLESS(tb_m_axis_tdata_o === '0);
`SVTEST_END

`SVTEST(tc_mvalid_deasserts_after_playback)
    bit reached;
    write_channel_regs(0, 32'h1000_0000, 32'h0000_0000, 16'h7FFF);
    push_descriptor(8'h01, 32'd4);
    wait_for_mvalid(1'b1, 40, reached);
    `FAIL_UNLESS(reached);
    wait_for_mvalid(1'b0, 30, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END

`SVTEST(tc_ready_stays_high_when_fifo_not_full)
    // A single descriptor push never comes close to filling the 16-deep
    // fifo_sync, so tready should never drop during normal operation.
    write_channel_regs(0, 32'h1000_0000, 32'h0000_0000, 16'h7FFF);
    push_descriptor(8'h01, 32'd4);
    `FAIL_UNLESS(tb_s_axis_tready_o === 1'b1);
`SVTEST_END

`SVTEST(tc_qsel1_matches_qsel8_scaling)
    // Regression test for the hardware finding (debug bench board
    // bring-up, 2026-09-23): with ONLY channel 0 active (mask=8'h01, qsel=1)
    // vs all 8 channels unmasked but channels 1-7 at GAIN=0 (mask=8'hFF,
    // qsel=8), the adder-tree sum feeding the output quantization mux is
    // mathematically IDENTICAL in both cases -- channels 1-7 contribute
    // exactly zero regardless of mask, since their gain multiply forces
    // zero output. The only difference is which qsel-selected bit slice of
    // sum6_real_r becomes dout_real: qsel=1 selects [15:0] (no shift),
    // qsel=8 selects [18:3] (>>>3). So val_qsel8 must equal
    // val_qsel1 >>> 3 (a plain arithmetic shift of the same underlying
    // sum), not some unrelated value.
    bit reached;
    logic signed [15:0] val_qsel1, val_qsel8;
    logic signed [15:0] expected_qsel8;

    // PINC=0, nonzero POFF: pins every DDS lane to the same static DC phase
    // (matches dds_top_sgmux8's own tc_zero_pinc_full_gain_dc_output),
    // giving a stable, repeatable sample instead of a moving waveform.
    write_channel_regs(0, 32'h0000_0000, 32'h4000_0000, 16'h7FFF);

    push_descriptor(8'h01, 32'd40);
    wait_for_mvalid(1'b1, 40, reached);
    `FAIL_UNLESS_LOG(reached, "qsel=1: m_axis_tvalid_o never asserted");
    repeat(20) @(posedge tb_clk); // let the DC value settle mid-playback
    val_qsel1 = tb_m_axis_tdata_o[15:0];
    wait_for_mvalid(1'b0, 40, reached);
    `FAIL_UNLESS_LOG(reached, "qsel=1: m_axis_tvalid_o never deasserted after playback");

    push_descriptor(8'hFF, 32'd40);
    wait_for_mvalid(1'b1, 40, reached);
    `FAIL_UNLESS_LOG(reached, "qsel=8: m_axis_tvalid_o never asserted");
    repeat(20) @(posedge tb_clk);
    val_qsel8 = tb_m_axis_tdata_o[15:0];

    expected_qsel8 = val_qsel1 >>> 3;
    `FAIL_UNLESS_LOG(
        (val_qsel8 >= expected_qsel8 - 1) && (val_qsel8 <= expected_qsel8 + 1),
        $sformatf("qsel=8 output (%0d) should be ~qsel=1 output>>>3 (%0d, from val_qsel1=%0d) -- channels 1-7 have gain=0 so should contribute nothing to the sum",
                   val_qsel8, expected_qsel8, val_qsel1));
`SVTEST_END
