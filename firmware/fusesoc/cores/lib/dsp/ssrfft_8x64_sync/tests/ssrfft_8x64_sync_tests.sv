// ============================================================================
// File: ssrfft_8x64_sync_tests.sv
// Description: SVUnit test cases for ssrfft_8x64_sync. Included by
//              ssrfft_8x64_sync_tc00.sv.
// ============================================================================

`SVTEST(tc_aligned_stream_matches_legacy)
    // tlast on the last clock of every frame; every QOUT 0..15 (12..15 select
    // bit 0) and a random SCALE per QOUT.
    for (int q = 0; q < 16; q++) begin
        @(posedge aclk);
        qout  <= q;
        scale <= $urandom_range(63);
        aligned(40);
    end
    repeat (100) step(1'b0);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS(n_valid > 16 * 30 * 8)
    `FAIL_UNLESS(n_last > 16 * 30)
`SVTEST_END

`SVTEST(tc_misaligned_tlast_matches_legacy)
    // The frame phase jumps: tlast one to seven clocks early or late, extra
    // tlasts inside a frame, and stretches with no tlast at all.
    @(posedge aclk);
    qout  <= 3;
    scale <= 6'b000111;
    aligned(40);
    for (int k = 0; k < 60; k++) begin
        int gap = $urandom_range(1, 3 * NFFT / SSR);
        for (int t = 0; t < gap; t++) step(1'b0);
        step(1'b1);
        if ($urandom_range(3) == 0) aligned($urandom_range(1, 5));
    end
    repeat (40) step(1'b0);
    aligned(20);
    repeat (100) step(1'b0);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS(n_valid > 1000)
`SVTEST_END

`SVTEST(tc_reset_restarts_the_framing)
    // After reset no new frame enters the FFT for the 256-clock wait; then
    // the frames follow tlast again. The FFT itself has no reset, so the
    // frames already inside it still come out: count from 80 clocks after
    // reset. Reset in the middle of a frame, twice.
    int early = 0;
    @(posedge aclk);
    qout <= 0;
    aligned(30);
    for (int r = 0; r < 2; r++) begin
        for (int t = 0; t < 3; t++) step(1'b0);
        reset_dut();
        repeat (80) step(1'b0);
        n_valid = 0;
        repeat (150) step(1'b0);
        early += n_valid;
        aligned(40);
    end
    repeat (100) step(1'b0);
    `FAIL_UNLESS_EQUAL(early, 0)
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS(n_valid > 30 * 8)
`SVTEST_END
