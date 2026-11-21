`SVTEST(test_reset)
    `FAIL_UNLESS_EQUAL(cb.tb_p, 0)
`SVTEST_END

`SVTEST(test_positive_positive)
    mult_and_check(16'sd100, 16'sd200);
`SVTEST_END

`SVTEST(test_negative_positive)
    mult_and_check(-16'sd100, 16'sd200);
`SVTEST_END

`SVTEST(test_negative_negative)
    mult_and_check(-16'sd100, -16'sd200);
`SVTEST_END

`SVTEST(test_full_scale)
    mult_and_check(16'sh4000, 16'sh4000);
`SVTEST_END

`SVTEST(test_consecutive_pipelined)
    cb.tb_a <= 16'sd10;
    cb.tb_b <= 16'sd10;
    @(cb);
    cb.tb_a <= 16'sd20;
    cb.tb_b <= 16'sd20;
    @(cb);
    cb.tb_a <= 16'sd30;
    cb.tb_b <= 16'sd30;
    @(cb);
    @(cb);
    `FAIL_UNLESS_EQUAL(cb.tb_p, 100)
    @(cb);
    `FAIL_UNLESS_EQUAL(cb.tb_p, 400)
    @(cb);
    `FAIL_UNLESS_EQUAL(cb.tb_p, 900)
`SVTEST_END
