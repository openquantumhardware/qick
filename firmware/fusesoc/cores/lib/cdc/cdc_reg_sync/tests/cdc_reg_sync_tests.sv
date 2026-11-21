// ============================================================================
// File: cdc_reg_sync_tests.sv
// Description: SVUnit test cases for cdc_reg_sync.
// ============================================================================

`SVTEST(tc_propagation_2cycles)
    dt_i = 4'hA;
    repeat (3) @(posedge tb_clk);
    `FAIL_IF(dt_o !== 4'hA);
`SVTEST_END

`SVTEST(tc_update_after_change)
    dt_i = 4'h5;
    repeat (3) @(posedge tb_clk);
    `FAIL_IF(dt_o !== 4'h5);

    dt_i = 4'hF;
    repeat (3) @(posedge tb_clk);
    `FAIL_IF(dt_o !== 4'hF);
`SVTEST_END

`SVTEST(tc_reset_clears)
    dt_i = 4'h0;
    tb_rstn = 1'b0;
    repeat (1) @(posedge tb_clk);
    tb_rstn = 1'b1;
    repeat (3) @(posedge tb_clk);

    `FAIL_IF(dt_o !== 4'h0);
`SVTEST_END
