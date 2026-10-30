// ============================================================================
// File: write_startup_probe.sv  (cycle-by-cycle dump of the writer start-up)
//
// tc_dump_write_mapping proved sample 0 is dropped: the first BRAM write is
// already sample 1, with addr_full=3. This probe logs the writer's start-up
// cycle by cycle so we can SEE the exact cycle where sample 0 fails to produce
// a v1/write while addr_full is already counting.
//
// Logs, each s0_axis_aclk once capture_sync is high, for ~24 cycles:
//   state       : FSM (0=INIT 1=READ_START 2=WAIT_TVALID 3=RW_TDATA)
//   tvalid      : axis_wr.tvalid  (data presented by the master)
//   tready_r    : registered tready the master actually sees
//   hs          : handshake = tvalid & tready_r
//   addr_full   : write pointer (should be 0 at the first accepted sample)
//   v1 / d1     : stage-1 write-enable / data captured this cycle
//   v3 a3 e3bank: the actual BRAM write (we / row / one-hot bank -> index)
//
// Watch for the cycle where the master advances / addr_full increments but v1
// does NOT latch the first sample. Uses tc00 helpers. Paths from
// axis_to_bram_sg_nt.sv (instance writer_i) and sgv6_top.sv (axis_wr).
// ============================================================================

`SVTEST(tc_dump_write_startup)
    logic [15:0]  re [], im [];
    localparam int W        = 26;   // cycles to log from capture_sync
    localparam int NS_LOCAL = 20;   // ramp samples streamed

    int  s_state [], s_af [], s_d1 [], s_a3 [], s_bank [];
    bit  s_tv [], s_trr [], s_hs [], s_v1 [], s_v3 [];
    int  n, b;

    s_state=new[W]; s_af=new[W]; s_d1=new[W]; s_a3=new[W]; s_bank=new[W];
    s_tv=new[W]; s_trr=new[W]; s_hs=new[W]; s_v1=new[W]; s_v3=new[W];
    n = 0;

    fork
        begin : mon
            // arm: wait until capture is synchronised into the s0 domain
            while (dut.sgv6_top_i.writer_i.capture_sync !== 1'b1)
                @(posedge s0_axis_aclk);
            for (int c = 0; c < W; c++) begin
                @(posedge s0_axis_aclk); #1;
                s_state[c] = int'(dut.sgv6_top_i.writer_i.state);
                s_tv   [c] = dut.sgv6_top_i.axis_wr.tvalid;
                s_trr  [c] = dut.sgv6_top_i.writer_i.tready_r;
                s_hs   [c] = dut.sgv6_top_i.writer_i.handshake;
                s_af   [c] = int'(dut.sgv6_top_i.writer_i.addr_full);
                s_v1   [c] = dut.sgv6_top_i.writer_i.v1;
                s_d1   [c] = int'(dut.sgv6_top_i.writer_i.d1);
                s_v3   [c] = dut.sgv6_top_i.writer_i.v3;
                s_a3   [c] = int'(dut.sgv6_top_i.writer_i.a3);
                b = -1;
                for (int t = 0; t < N_DDS; t++)
                    if (dut.sgv6_top_i.writer_i.e3[t]) b = t;
                s_bank[c] = b;
                n = c + 1;
            end
        end
    join_none

    // Unique ramp so d1 names the sample: value=(sample+1)*100.
    re = new[NS_LOCAL]; im = new[NS_LOCAL];
    for (int k = 0; k < NS_LOCAL; k++) begin re[k]=16'((k+1)*100); im[k]=16'h0000; end
    load_envelope(NS_LOCAL, re, im);
    repeat (30) @(posedge s0_axis_aclk);
    disable mon;

    $display("==== [WRSTART] cyc | state tvalid treadyR hs | addr_full | v1 d1 | v3 row bank ====");
    for (int c = 0; c < n; c++)
        $display("[WRSTART] %2d | st=%0d tv=%0b trr=%0b hs=%0b | af=%0d | v1=%0b d1=%0d | v3=%0b a3=%0d bank=%0d",
                 c, s_state[c], s_tv[c], s_trr[c], s_hs[c], s_af[c],
                 s_v1[c], s_d1[c], s_v3[c], s_a3[c], s_bank[c]);
    $display("==== [WRSTART] end ====");
`SVTEST_END
