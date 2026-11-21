// ============================================================================
// File: dds_phase_probe.sv  (rev 4 - phrst=0 vs phrst=1 comparison)
//
// The phase pipeline is fixed (cnt_n_reg no longer frozen); the raw dump
// confirmed lane0 sweeps a full cosine at N_DDS*pinc/beat. The only residual
// question is the startup offset: with phrst=0 the dump showed phase=0 landing
// at beat 2, not beat 0.
//
// Hypothesis: that is NOT a defect. cnt_n is a free-running "non-stop time
// counter" reset ONLY when phrst is asserted at descriptor load, so with
// phrst=0 the pulse phase is referenced to absolute time (QICK phase-coherent
// behaviour), and the beat-2 crossing is just wherever the free-running count
// happened to be at capture. With phrst=1 the counter resets at load, so the
// phase-0 crossing should move to ~beat 0 (plus whatever fixed pipeline
// latency remains).
//
// This test dumps lane0 over the burst for phrst=0 and phrst=1 back to back.
// Read the two rows:
//   * phrst=1 crossing at (or near) beat 0  -> offset was the free-running
//     time reference; nothing to fix, working as designed.
//   * phrst=1 crossing still at beat 2       -> a genuine fixed pipeline skew
//     of 2 beats that software (or the phase field) must compensate.
//
// Informational; never fails except on no-output. Uses tc00 helpers.
// ============================================================================

`SVTEST(tc_dump_phrst_compare)
    logic [15:0]        re [], im [];
    logic signed [15:0] l0 [];
    logic [159:0]       d;
    localparam int      CAP = 20;
    logic [31:0]        pinc = 32'h0100_0000;   // 2^24
    int                 nb, t;
    string              row;

    const_envelope(N_DDS, 16'h0000, re, im);
    load_envelope(N_DDS, re, im);

     m_if.s_cb.tready <= 1'b1; // force the sink always ready
    // ---- phrst = 0 (free-running time reference) ----
    l0 = new[CAP];
    d = build_descr(pinc, 32'd0, 16'd0, 16'(MAXV),
                    16'd128, 2'd1 /*DDS*/, 1'b0, 1'b0, 1'b0 /*phrst=0*/);
    queue_descriptor(d);
    
    t = 0; while (!m_if.s_cb.tvalid && t < 400) begin @(m_if.s_cb); t++; end
    `FAIL_IF_LOG(!m_if.s_cb.tvalid, "tc_dump_phrst_compare: no output (phrst=0)");
    nb = 0;
    for (int r = 0; r < CAP; r++) begin
        if (!m_if.s_cb.tvalid) break;
        l0[r] = m_if.s_cb.tdata[0 +: 16];
        nb++; @(m_if.s_cb);
    end
    row = "";
    for (int r = 0; r < nb; r++) row = {row, $sformatf("%7d", int'(l0[r]))};
    $display("==== [PHRST] pinc=0x%08h ====", pinc);
    $display("[PHRST=0] lane0 over beats 0..%0d:%s", nb-1, row);

    // let the pipeline drain fully between descriptors
    repeat (60) @(posedge aclk);

    // ---- phrst = 1 (counter reset at load) ----
    l0 = new[CAP];
    d = build_descr(pinc, 32'd0, 16'd0, 16'(MAXV),
                    16'd128, 2'd1, 1'b0, 1'b0, 1'b1 /*phrst=1*/);
    queue_descriptor(d);
    t = 0; while (!m_if.s_cb.tvalid && t < 400) begin @(m_if.s_cb); t++; end
    `FAIL_IF_LOG(!m_if.s_cb.tvalid, "tc_dump_phrst_compare: no output (phrst=1)");
    nb = 0;
    for (int r = 0; r < CAP; r++) begin
        if (!m_if.s_cb.tvalid) break;
        l0[r] = m_if.s_cb.tdata[0 +: 16];
        nb++; @(m_if.s_cb);
    end
    row = "";
    for (int r = 0; r < nb; r++) row = {row, $sformatf("%7d", int'(l0[r]))};
    $display("[PHRST=1] lane0 over beats 0..%0d:%s", nb-1, row);
    $display("[PHRST] ref: cos(0)=+32766 is the phase-0 crossing (peak). Beat index of the peak = startup latency in beats.");
    $display("==== [PHRST] end ====");
`SVTEST_END