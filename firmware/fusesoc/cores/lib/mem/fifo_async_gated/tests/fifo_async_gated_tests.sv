// ============================================================================
// File: fifo_async_gated_tests.sv
// Description: SVUnit test cases for fifo_async_gated.
// ============================================================================

`SVTEST(tc_empty_after_reset)
    repeat (2000) @(posedge rd_clk);
    `FAIL_IF(async_empty_o !== 1'b1);
    `FAIL_IF(async_full_o  !== 1'b0);
`SVTEST_END

`SVTEST(tc_write_read_cross_domain)
    wr_en_i = 1'b1; push_i = 1'b1;
    data_i  = 16'hA5A5;
    repeat (1) @(posedge wr_clk);
    wr_en_i = 1'b0; push_i = 1'b0;

    repeat (20) @(posedge rd_clk);
    rd_en_i = 1'b1; pop_i = 1'b1;
    repeat (1) @(posedge rd_clk);
    rd_en_i = 1'b0; pop_i = 1'b0;

    `FAIL_IF(data_o !== 16'hA5A5);
`SVTEST_END

`SVTEST(tc_flush_clears)
    wr_en_i = 1'b1; push_i = 1'b1;
    data_i  = 16'h1234;
    repeat (1) @(posedge wr_clk);
    wr_en_i = 1'b0; push_i = 1'b0;

    flush_i = 1'b1;
    repeat (20) @(posedge wr_clk);
    flush_i = 1'b0;

    repeat (50) @(posedge rd_clk);
    `FAIL_IF(async_empty_o !== 1'b1);
`SVTEST_END

`SVTEST(tc_full_flag)
    wr_en_i = 1'b1; push_i = 1'b1;
    repeat (17) begin
        data_i = data_i + 1;
        repeat (1) @(posedge wr_clk);
    end
    wr_en_i = 1'b0; push_i = 1'b0;

    repeat (2000) @(posedge wr_clk);
    `FAIL_IF(async_full_o !== 1'b1);
`SVTEST_END
