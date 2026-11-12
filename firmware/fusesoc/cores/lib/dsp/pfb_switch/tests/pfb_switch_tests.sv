// ============================================================================
// File: pfb_switch_tests.sv
// Description: SVUnit test cases for pfb_switch. Included by
//              pfb_switch_tc00.sv.
// ============================================================================

`SVTEST(tc_aligned_frames_match_legacy)
    // The deployed case: tlast on the last clock of every 8-clock frame. The
    // swap reaches its read/write state and stays there.
    int late;
    frames(100);
    late = n_rw1;
    frames(1000);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS(late > 0)
    `FAIL_UNLESS_EQUAL(n_rw1 - late, 1000 * NP)
`SVTEST_END

`SVTEST(tc_tlast_disturbances_match_legacy)
    // Frame phase jumps, missing and extra tlasts (the swap falls back to
    // draining and re-syncs), and resets.
    for (int k = 0; k < 300; k++) begin
        case ($urandom_range(4))
            0: for (int t = 0; t < $urandom_range(1, 3 * NP); t++) step(1'b0);
            1: step(1'b1);
            2: if ($urandom_range(9) == 0) reset_dut();
            default: frames($urandom_range(1, 10));
        endcase
    end
    frames(20);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS(n_rw1 > 1000)
`SVTEST_END
