// ============================================================================
// File: mem_skew_probe.sv  (raw dump of the envelope read mapping)
//
// Question: is out[lane i] = mem[sample r*N_DDS + i]  (natural, no skew)
//           or out[lane i] = mem[sample r*N_DDS + i + 1]  (the +1 skew that
//           tc_envelope_only / tc_gaussian compensate with re[i+1])?
//           ...or is the +1 a TESTBENCH over-compensation?
//
// Method (no model fitting): load a UNIQUE ramp where sample k holds the value
// (k+1)*512, so value/512 = k+1 recovers the sample index exactly (512 spacing
// >> the ~0.05% gain-rounding noise). Play it in MEM mode (outsel=2, gain=MAXV
// so out ~= env), capture beats 0..5 through s_cb, and for each (beat r, lane i)
// print the recovered sample index next to the NATURAL index r*N_DDS + i + 1.
//   idx == natural       -> no skew (the re[i+1] comp is wrong / TB artifact)
//   idx == natural + 1    -> real +1 sample skew (write- or read-side)
//
// Also samples the shared read address dut.sgv6_top_i.mem_addrb at each
// captured beat, to show whether the address sequence itself is 0,1,2,.. or
// already advanced.
//
// Informational; never fails except on no-output. Uses tc00 helpers.
// N in tc00 is 8 (256-deep banks) - a 48-sample ramp (3 rows) fits easily.
// ============================================================================

`SVTEST(tc_dump_mem_mapping)
    logic [15:0]        re [], im [];
    logic signed [15:0] frames [][N_DDS];
    logic [N-1:0]       addrs [];
    logic [159:0]       d;
    localparam int      ROWS = 3;
    localparam int      NS   = N_DDS*ROWS;   // 48 unique samples
    localparam int      CAP  = 6;
    int                 nb, t, idx, nat;
    string              row;

    // Unique ramp: sample k -> (k+1)*512.
    re = new[NS]; im = new[NS];
    for (int k = 0; k < NS; k++) begin
        re[k] = 16'((k+1)*512);
        im[k] = 16'h0000;
    end
    load_envelope(NS, re, im);

    // MEM mode, gain = MAXV (out ~= env), DC (DDS irrelevant in mem mode).
    d = build_descr(32'd0, 32'd0, 16'd0, 16'(MAXV),
                    16'd64, 2'd2 /*mem*/, 1'b0, 1'b0, 1'b0);
    queue_descriptor(d);

    frames = new[CAP];
    addrs  = new[CAP];
    t = 0;
    while (!m_if.s_cb.tvalid && t < 400) begin @(m_if.s_cb); t++; end
    `FAIL_IF_LOG(!m_if.s_cb.tvalid, "tc_dump_mem_mapping: no output");
    nb = 0;
    for (int r = 0; r < CAP; r++) begin
        if (!m_if.s_cb.tvalid) break;
        addrs[r] = dut.sgv6_top_i.mem_addrb;                 // shared read address
        for (int i = 0; i < N_DDS; i++)
            frames[r][i] = m_if.s_cb.tdata[i*16 +: 16];
        nb++;
        @(m_if.s_cb);
    end

    $display("==== [MEM] ramp value(k)=(k+1)*512 ; idx=round(out/512) recovers sample k+1 ====");
    for (int r = 0; r < nb; r++) begin
        row = "";
        for (int i = 0; i < N_DDS; i++) begin
            idx = (int'(frames[r][i]) + 256) / 512;          // recovered sample index (=k+1)
            nat = r*N_DDS + i + 1;                            // natural index if no skew
            row = {row, $sformatf(" %0d/%0d", idx, nat)};     // recovered / natural
        end
        $display("[MEM] beat %0d addrb=%0d  (idx/natural per lane):%s", r, int'(addrs[r]), row);
    end
    $display("[MEM] if idx==natural everywhere -> NO skew (re[i+1] is over-compensating).");
    $display("[MEM] if idx==natural+1 everywhere -> real +1 sample skew.");
    $display("==== [MEM] end ====");
`SVTEST_END
