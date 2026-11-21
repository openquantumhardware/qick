// ============================================================================
// File: axis_pfb_readout_v4_tests.sv
// Description: SVUnit test cases for axis_pfb_readout_v4. Included by
//              axis_pfb_readout_v4_tc00.sv.
// ============================================================================

`SVTEST(tc_registers_match_the_legacy_slave)
    // 3000 random operations over all 64 registers: writes with random data
    // and byte strobes, reads; the IP and the legacy slave must agree on
    // every AXI output and every value handed to the datapath, and reads
    // must return what a byte-lane model of the registers expects.
    logic [31:0] shadow [64];
    logic [31:0] rd;
    foreach (shadow[r]) shadow[r] = '0;
    for (int n = 0; n < 3000; n++) begin
        int r = $urandom_range(63);
        if ($urandom_range(1)) begin
            logic [31:0] d = $urandom;
            logic [3:0]  s = 4'($urandom);
            axi_wr(8'(4 * r), d, s);
            for (int b = 0; b < 4; b++) if (s[b]) shadow[r][8*b +: 8] = d[8*b +: 8];
        end else begin
            axi_rd(8'(4 * r), rd);
            `FAIL_UNLESS_EQUAL(rd, shadow[r])
        end
    end
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS(n_reads > 1000)
`SVTEST_END

`SVTEST(tc_register_map_reaches_the_datapath)
    // IDi at 0x00 + 4i (16 bits), PINCi at 0x20 + 8i, POFFi at 0x24 + 8i.
    for (int i = 0; i < 8; i++) begin
        axi_wr(8'(4 * i), 32'hABCD_0000 | 32'(16'h0100 * i + i), 4'hf);
        axi_wr(8'(8'h20 + 8 * i), 32'h1000_0000 + 32'(i), 4'hf);
        axi_wr(8'(8'h24 + 8 * i), 32'h2000_0000 + 32'(i), 4'hf);
    end
    repeat (4) @(posedge aclk);
    for (int i = 0; i < 8; i++) begin
        `FAIL_UNLESS_EQUAL(dut.pfb_readout_i.id_reg[i],   16'(16'h0100 * i + i))
        `FAIL_UNLESS_EQUAL(dut.pfb_readout_i.pinc_reg[i], 32'h1000_0000 + 32'(i))
        `FAIL_UNLESS_EQUAL(dut.pfb_readout_i.poff_reg[i], 32'h2000_0000 + 32'(i))
    end
    `FAIL_UNLESS_EQUAL(mism, 0)
`SVTEST_END

`SVTEST(tc_tone_configured_over_axi_comes_out_as_dc)
    // Output 5 on channel 37, its DDS on the tone's offset (0.3 of the channel
    // spacing = 0.15 cycles per output sample): a constant of magnitude ~A on
    // m5_axis. Every m<i>_axis_tvalid is the same strobe.
    int  k = 37;
    real d = 0.3, mi = 0.0, mq = 0.0, dev = 0.0;
    axi_wr(8'h14, 32'({8'(k % 8), 8'(k / 8)}), 4'hf);
    axi_wr(8'(8'h20 + 8 * 5), 32'($rtoi(d / 2.0 * 4294967296.0)), 4'hf);
    o_idx = 5;
    tone((k + d) / 64.0, 3000.0, 1000);     // settle
    o_i.delete(); o_q.delete();
    tone((k + d) / 64.0, 3000.0, 3000);
    for (int n = 0; n < o_i.size(); n++) begin mi += o_i[n]; mq += o_q[n]; end
    mi /= o_i.size(); mq /= o_q.size();
    for (int n = 0; n < o_i.size(); n++) dev += $sqrt((o_i[n] - mi) ** 2 + (o_q[n] - mq) ** 2);
    dev /= o_i.size();
    `FAIL_UNLESS(o_i.size() > 350)
    `FAIL_UNLESS($sqrt(mi * mi + mq * mq) > 0.98 * 3000.0 && $sqrt(mi * mi + mq * mq) < 1.02 * 3000.0)
    `FAIL_UNLESS(dev < 2.0)
    `FAIL_UNLESS(m_tvalid == 8'h00 || m_tvalid == 8'hFF)
    `FAIL_UNLESS_EQUAL(mism, 0)
`SVTEST_END
