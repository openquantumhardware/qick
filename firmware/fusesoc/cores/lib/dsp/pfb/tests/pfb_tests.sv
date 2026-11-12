// ============================================================================
// File: pfb_tests.sv
// Description: SVUnit test cases for pfb. Included by pfb_tc00.sv.
// ============================================================================

`SVTEST(tc_tone_lands_in_its_channel)
    // A complex tone at the centre of channel k (k/64 cycles per sample)
    // comes out at frame position clock k/8, lane k%8 (channels in natural
    // order), at least 50 dB above every other position, with |X| = A/2 at
    // qout 6 (FIR gain ~1/2, FFT gain 64 = 2^6) within 3 %.
    int ks [] = '{0, 1, 5, 17, 32, 47, 63};
    qout <= 8'd6;
    foreach (ks[j]) begin
        real best = 0.0, second = 0.0, mag;
        int  bt = -1, bl = -1, nfr = 3000 / NFR;
        tone(real'(ks[j]) / real'(N), 4000.0, 1500);   // settle
        clear_pw(); acc_en = 1'b1;
        tone(real'(ks[j]) / real'(N), 4000.0, 3000);
        acc_en = 1'b0;
        for (int t = 0; t < NFR; t++) for (int l = 0; l < 2 * L; l++) begin
            if (pw[t][l] > best) begin second = best; best = pw[t][l]; bt = t; bl = l; end
            else if (pw[t][l] > second) second = pw[t][l];
        end
        mag = $sqrt(best / nfr);
        `FAIL_UNLESS_EQUAL(bt, ks[j] / 8)
        `FAIL_UNLESS_EQUAL(bl, ks[j] % 8)
        `FAIL_UNLESS(10.0 * $log10(best / second) > 50.0)
        `FAIL_UNLESS(mag > 0.97 * 2000.0 && mag < 1.03 * 2000.0)
    end
    `FAIL_UNLESS_EQUAL(mism, 0)
`SVTEST_END

`SVTEST(tc_qout_halves_per_step)
    // One more qout bit: half the magnitude in the tone's channel.
    real m6, m7;
    qout <= 8'd6;
    tone(9.0 / N, 4000.0, 1500);
    clear_pw(); acc_en = 1'b1; tone(9.0 / N, 4000.0, 2000); acc_en = 1'b0;
    m6 = $sqrt(pw[1][1]);
    qout <= 8'd7;
    tone(9.0 / N, 4000.0, 1500);
    clear_pw(); acc_en = 1'b1; tone(9.0 / N, 4000.0, 2000); acc_en = 1'b0;
    m7 = $sqrt(pw[1][1]);
    `FAIL_UNLESS(m7 > 0.49 * m6 && m7 < 0.51 * m6)
    `FAIL_UNLESS_EQUAL(mism, 0)
`SVTEST_END

`SVTEST(tc_random_matches_legacy_wiring)
    // Random input, every qout 0..15 (12..15 read as 0), gaps and resets.
    for (int n = 0; n < 16000; n++) begin
        @(posedge aclk);
        s_tvalid <= ($urandom_range(19) != 0);
        for (int i = 0; i < 2 * L; i++) s_tdata[i*16 +: 16] <= 16'($signed(14'($urandom)));
        if (n % 1000 == 0) qout <= 8'(n / 1000);
        if ($urandom_range(3999) == 0) reset_dut();
    end
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS(n_valid > 12000)
`SVTEST_END
