// ============================================================================
// File: mem_write_probe.sv  (raw dump of the ENVELOPE WRITE mapping)
//
// The read side is shared-row (one o_mem_addr for all 16 banks), so it cannot
// produce a frame that straddles two rows. tc_dump_mem_mapping showed exactly
// such a straddle (beat 0 = samples [1..16]), so the +1 skew is BAKED IN BY
// THE WRITE: row 0 of bank i holds sample (i+1), not sample i.
//
// This probe watches the ACTUAL BRAM write port during load_envelope and logs,
// for each write, the data, the one-hot bank it lands in, the row address, and
// the writer's internal addr_full. Load a unique ramp re[k]=(k+1)*100 so the
// data value names the sample: din=100 -> sample 0, din=200 -> sample 1, ...
//
// Read the first rows:
//   din=100 (sample 0) -> bank 0, row 0   => write CORRECT (skew is elsewhere)
//   din=100 (sample 0) -> bank 15 / not row0/bank0, or first logged write is
//                         din=200 at bank 0  => write is +1 (addr_full lags data)
//
// Informational; never fails except on no-output. Uses tc00 helpers.
// Paths taken from sgv6_top.sv: bram_wr.{we,addr,din}, mem_en, writer_i.addr_full.
// ============================================================================

`SVTEST(tc_dump_write_mapping)
    logic [15:0]  re [], im [];
    localparam int NS  = 20;
    localparam int CAP = 40;

    logic [15:0]  log_din  [];
    logic [N_DDS-1:0] log_men [];
    logic [N-1:0] log_row  [];
    int           log_af   [];
    int           wr_cnt;
    int           bank;
    string        line;

    log_din = new[CAP];
    log_men = new[CAP];
    log_row = new[CAP];
    log_af  = new[CAP];
    wr_cnt  = 0;

    // Monitor the real BRAM write port in the s0 domain.
    fork
        begin : monitor
            forever begin
                @(posedge s0_axis_aclk);
                if (dut.sgv6_top_i.bram_wr.we && wr_cnt < CAP) begin
                    log_din[wr_cnt] = dut.sgv6_top_i.bram_wr.din[15:0];
                    log_men[wr_cnt] = dut.sgv6_top_i.mem_en;
                    log_row[wr_cnt] = dut.sgv6_top_i.bram_wr.addr;
                    log_af [wr_cnt] = int'(dut.sgv6_top_i.writer_i.addr_full);
                    wr_cnt++;
                end
            end
        end
    join_none

    // Unique ramp: sample k -> value (k+1)*100.
    re = new[NS]; im = new[NS];
    for (int k = 0; k < NS; k++) begin
        re[k] = 16'((k+1)*100);
        im[k] = 16'h0000;
    end
    load_envelope(NS, re, im);
    repeat (40) @(posedge s0_axis_aclk);   // let the 3-stage write pipeline flush
    disable monitor;

    $display("==== [WR] envelope write mapping (din value = (sample+1)*100) ====");
    for (int j = 0; j < wr_cnt; j++) begin
        bank = -1;
        for (int t = 0; t < N_DDS; t++) if (log_men[j][t]) bank = t;
        $display("[WR] write #%0d: din=%0d (sample %0d)  -> bank=%0d row=%0d  addr_full=%0d",
                 j, int'(log_din[j]), (int'(log_din[j])/100)-1, bank,
                 int'(log_row[j]), log_af[j]);
    end
    $display("[WR] expected if correct: sample s -> bank s%%16, row s/16, addr_full=s");
    $display("==== [WR] end ====");
`SVTEST_END
