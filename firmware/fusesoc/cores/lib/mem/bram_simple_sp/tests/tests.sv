// Tests of bram_simple_sp_unit_test. The reference model in the testcase does
// the checking; each test only chooses the operations.

`SVTEST(test00_file_image)
    // Every word reads back as loaded from the image file
    for (int a = 0; a < WORDS; a++) cycle(1'b1, 1'b0, a, '0);
    idle();
    `FAIL_UNLESS(n_checked >= WORDS)
`SVTEST_END

`SVTEST(test01_write_all_read_all)
    for (int a = 0; a < WORDS; a++) cycle(1'b1, 1'b1, a, $urandom());
    for (int a = WORDS - 1; a >= 0; a--) cycle(1'b1, 1'b0, a, '0);
    idle();
`SVTEST_END

`SVTEST(test02_write_first)
    // A write shows the new word on o_doa at once, then a read of the same
    // address returns it; back to back on one address
    for (int k = 0; k < 8; k++) begin
        cycle(1'b1, 1'b1, 4'd9, $urandom());
        cycle(1'b1, 1'b0, 4'd9, $urandom());  // data ignored on a read
    end
    idle();
`SVTEST_END

`SVTEST(test03_enable_low)
    // With i_ena low a write does nothing and o_doa holds its last value
    cycle(1'b1, 1'b0, 4'd2, '0);
    repeat (5) cycle(1'b0, 1'b1, 4'd2, $urandom());
    repeat (3) cycle(1'b0, 1'b0, $urandom(), $urandom());
    cycle(1'b1, 1'b0, 4'd2, '0);
    idle();
`SVTEST_END

`SVTEST(test04_random)
    for (int k = 0; k < 1000; k++)
        cycle(1'($urandom()), 1'($urandom()), NB_ADDR'($urandom()), $urandom());
    idle();
    `FAIL_UNLESS(n_checked > 400)
`SVTEST_END
