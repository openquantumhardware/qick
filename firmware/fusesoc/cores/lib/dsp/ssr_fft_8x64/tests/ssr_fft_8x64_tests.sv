// ============================================================================
// File: ssr_fft_8x64_tests.sv
// Description: SVUnit test cases for ssr_fft_8x64. Included by
//              ssr_fft_8x64_tc00.sv.
// ============================================================================

`SVTEST(tc_tone_lands_in_one_bin)
    // For a spread of bins: exactly one output of the (steady-state) frame
    // carries the tone, with gain 64 at i_scale = 0; every other output is
    // near zero. Bins come out in natural order: bin k on clock k/8, lane k%8.
    int tone_bins [] = '{0, 1, 2, 7, 8, 9, 31, 32, 33, 55, 63};
    int amp = 1000;
    foreach (tone_bins[b]) begin
        int k0 = tone_bins[b];
        int best_t = -1, best_l = -1, n_big = 0;
        real best = 0.0;
        fork
            drive_tone(k0, amp, 4);
            capture_frame(8);   // the second frame
        join
        for (int t = 0; t < 8; t++)
            for (int l = 0; l < 8; l++) begin
                real m = $sqrt(real'(f_re[t][l]) ** 2 + real'(f_im[t][l]) ** 2);
                if (m > 0.05 * 64 * amp) n_big++;
                if (m > best) begin best = m; best_t = t; best_l = l; end
            end
        $display("ssr_fft_8x64: bin %0d -> clock %0d lane %0d, |X| = %0.1f (expected %0d)",
                 k0, best_t, best_l, best, 64 * amp);
        `FAIL_UNLESS_EQUAL(n_big, 1)
        `FAIL_UNLESS_EQUAL(best_t, k0 / 8)
        `FAIL_UNLESS_EQUAL(best_l, k0 % 8)
        `FAIL_UNLESS(best > 0.99 * 64 * amp && best < 1.01 * 64 * amp)
        repeat (100) @(posedge clk);
    end
`SVTEST_END

`SVTEST(tc_scale_halves_per_bit)
    // i_scale: one bit per radix-2 stage (6 stages); each bit set halves the
    // result. Bin 5, amplitude 1000.
    logic [5:0] scales [] = '{6'b000000, 6'b000001, 6'b100000, 6'b000111, 6'b111111};
    foreach (scales[i]) begin
        real m, expect_m;
        i_scale = scales[i];
        fork
            drive_tone(5, 1000, 4);
            capture_frame(8);
        join
        m = $sqrt(real'(f_re[0][5]) ** 2 + real'(f_im[0][5]) ** 2);
        expect_m = 64000.0 / (2.0 ** $countones(scales[i]));
        $display("ssr_fft_8x64: i_scale %b -> |X| = %0.1f (expected %0.1f)", scales[i], m, expect_m);
        `FAIL_UNLESS(m > 0.98 * expect_m && m < 1.02 * expect_m)
        repeat (100) @(posedge clk);
    end
`SVTEST_END
