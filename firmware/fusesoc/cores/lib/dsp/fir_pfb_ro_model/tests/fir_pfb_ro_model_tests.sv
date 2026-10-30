// ============================================================================
// File: fir_pfb_ro_model_tests.sv
// Description: SVUnit test cases for fir_pfb_ro_model. Included by
//              fir_pfb_ro_model_tc00.sv.
//
//   The model has no reset (neither has the real core), so the tests run in
//   this order and share its state: each one pushes whole vectors, so every
//   test starts on channel 0; the first runs before any config (set 0).
//
//   Offsets, in the testbench's edge count (see tc00): 18 for data (LAT), 4
//   for data events (EVLAT), 6 for config events (CFG_EVLAT).
// ============================================================================

`SVTEST(tc_starts_on_set0_with_latency_and_tlast)
    int e0, e;
    clear_logs();
    for (int c = 0; c < NCH; c++) begin
        push(200 * (c + 1), -100 * (c + 1), c == NCH - 1, e);
        if (c == 0) e0 = e;
    end
    idle(30);
    `FAIL_UNLESS_EQUAL(o_edge.size(), NCH)
    `FAIL_UNLESS_EQUAL(o_edge[0] - e0, 18)
    for (int c = 0; c < NCH; c++) begin
        `FAIL_UNLESS_EQUAL(o_edge[c], o_edge[0] + c)
        `FAIL_UNLESS_EQUAL(o_i[c], 100 * (c + 1))
        `FAIL_UNLESS_EQUAL(o_q[c], -50 * (c + 1))
        `FAIL_UNLESS_EQUAL(o_last[c], c == NCH - 1)
    end
`SVTEST_END

`SVTEST(tc_rounding_is_to_nearest_ties_toward_zero)
    // Set 0 halves: x/2 lands on .5 for every odd x.
    int x [NCH] = '{1, -1, 3, -3, 5, -5, 32767, -32768};
    int y [NCH] = '{0,  0, 1, -1, 2, -2, 16383, -16384};
    int e;
    clear_logs();
    idle(20);   // let the previous test's history age out of tap 0 only
    for (int c = 0; c < NCH; c++) push(x[c], x[c], c == NCH - 1, e);
    idle(30);
    `FAIL_UNLESS_EQUAL(o_edge.size(), NCH)
    for (int c = 0; c < NCH; c++) begin
        `FAIL_UNLESS_EQUAL(o_i[c], y[c])
        `FAIL_UNLESS_EQUAL(o_q[c], y[c])
    end
`SVTEST_END

`SVTEST(tc_config_applies_from_the_next_vector_start)
    // Constant input 1000 on every channel while a config (every channel ->
    // set 2, gain ~1) completes in the middle of a vector: the outputs switch
    // from 500 to 1000 at the first vector start after the packet completes.
    int sets [NCH] = '{default: 2};
    int acc [$];
    int cfg_done, e, sw;
    clear_logs();
    fork
        for (int n = 0; n < 6 * NCH; n++) begin push(1000, 1000, n % NCH == NCH - 1, e); acc.push_back(e); end
        begin
            repeat (NCH + 3) @(posedge aclk);
            send_config(sets);
            cfg_done = edge_n - 1;   // edge that accepted the last config word
        end
    join
    idle(30);
    `FAIL_UNLESS_EQUAL(o_i.size(), 6 * NCH)
    sw = -1;
    foreach (o_i[n]) if (sw < 0 && o_i[n] == 1000) sw = n;
    `FAIL_UNLESS(sw > 0 && sw % NCH == 0)
    foreach (o_i[n]) begin
        `FAIL_UNLESS_EQUAL(o_i[n], (n < sw) ? 500 : 1000)
    end
    // The switch vector is the first one that starts after the packet.
    `FAIL_UNLESS(acc[sw] > cfg_done)
    `FAIL_UNLESS(acc[sw - NCH] <= cfg_done)
`SVTEST_END

`SVTEST(tc_taps_are_zero_packed)
    // Every channel on set 1 (tap 1 only, 8192): an impulse of 4000 on
    // channel 5 comes out as 1000 on channel 5 two vectors later, and nowhere
    // else.
    int sets [NCH] = '{default: 1};
    int e, hit = 0;
    send_config(sets);
    for (int v = 0; v < 14; v++) vector(0, 0);   // flush the 13-sample history
    idle(30);
    clear_logs();
    for (int v = 0; v < 6; v++)
        for (int c = 0; c < NCH; c++) push((v == 1 && c == 5) ? 4000 : 0, 0, c == NCH - 1, e);
    idle(30);
    `FAIL_UNLESS_EQUAL(o_i.size(), 6 * NCH)
    foreach (o_i[n]) begin
        if (n == 3 * NCH + 5) begin
            `FAIL_UNLESS_EQUAL(o_i[n], 1000)
            hit++;
        end else begin
            `FAIL_UNLESS_EQUAL(o_i[n], 0)
        end
    end
    `FAIL_UNLESS_EQUAL(hit, 1)
`SVTEST_END

`SVTEST(tc_data_events_and_their_hold_through_a_gap)
    // tlast on channel 3: one-clock "unexpected" EVLAT edges later. No tlast on
    // channel 7 followed by a gap: "missing" holds through the gap (2 clocks).
    int e3, e7, e;
    clear_logs();
    for (int c = 0; c < NCH; c++) begin
        push(0, 0, c == 3, e);
        if (c == 3) e3 = e;
        if (c == 7) e7 = e;
    end
    idle(1);
    vector(0, 0);
    idle(20);
    `FAIL_UNLESS_EQUAL(e_unexp.size(), 1)
    `FAIL_UNLESS_EQUAL(e_unexp[0] - e3, 4)
    `FAIL_UNLESS_EQUAL(e_miss.size(), 2)
    `FAIL_UNLESS_EQUAL(e_miss[0] - e7, 4)
    `FAIL_UNLESS_EQUAL(e_miss[1], e_miss[0] + 1)
`SVTEST_END

`SVTEST(tc_config_events_follow_consumption)
    // A packet with tlast on word 5 (unexpected) and none on word 7
    // (missing). Words are consumed one per input from the next vector
    // start; each event comes CFG_EVLAT edges after its word is consumed.
    int sets [NCH] = '{default: 0};
    int acc [$];
    int e;
    clear_logs();
    send_config(sets, 5);
    for (int n = 0; n < 3 * NCH; n++) begin push(0, 0, n % NCH == NCH - 1, e); acc.push_back(e); end
    idle(20);
    `FAIL_UNLESS_EQUAL(e_cunexp.size(), 1)
    `FAIL_UNLESS_EQUAL(e_cmiss.size(), 1)
    `FAIL_UNLESS_EQUAL(e_cunexp[0] - acc[5], 6)
    `FAIL_UNLESS_EQUAL(e_cmiss[0] - acc[7], 6)
`SVTEST_END
