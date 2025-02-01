`SVTEST(test00_reset_test)
    tb_enable_i <= 1'b1;
    tb_rf_max_count_i <= 'hA;

    tb_start_count_i <= 1'b1;
    @(negedge tb_clk);
    tb_start_count_i <= 1'b0;


    for (int i = 0; i < 10 ; i++) begin : single_pulse
        tb_rst <= 1'b1;

        @(negedge tb_clk);

        `ASSERT_IMMEDIATE(tb_counter_o == 1'b0);
        tb_rst <= 1'b0;

        repeat($urandom_range(1,10))@(negedge tb_clk);
    end

    tb_enable_i <= 1'b1;
    tb_rf_max_count_i <= 'hA;

    tb_start_count_i <= 1'b1;
    @(negedge tb_clk);
    tb_start_count_i <= 1'b0;

    for (int i = 0; i < 10 ; i++) begin : toggle_pulse
        tb_rst <= 1'b1;

        repeat($urandom_range(1,10))@(negedge tb_clk);

        `ASSERT_IMMEDIATE(tb_counter_o == 1'b0);
        tb_rst <= 1'b0;

        repeat($urandom_range(1,10))@(negedge tb_clk);
    end

`SVTEST_END


`SVTEST(test01_sanity_counter)
    value = $urandom_range(1, (1<<NB_MAX_COUNT));
    tb_enable_i <= 1'b1;
    tb_rf_max_count_i <= value;
    tb_start_count_i <= 1'b1;

    @(negedge tb_clk);

    tb_start_count_i <= 1'b0;

    for (int i = 1; i < value - 1 ; i++) begin
        `ASSERT_IMMEDIATE(tb_count_in_process_o == 1'b1);
        `ASSERT_IMMEDIATE(tb_count_done_o == 1'b0);
        `ASSERT_IMMEDIATE(tb_counter_o == i);
        @(negedge tb_clk);
    end

    `ASSERT_IMMEDIATE(tb_count_in_process_o == 1'b1);
    `ASSERT_IMMEDIATE(tb_count_done_o == 1'b1);
    `ASSERT_IMMEDIATE(tb_counter_o == value - 1);

    @(negedge tb_clk);

    `ASSERT_IMMEDIATE(tb_count_in_process_o == 1'b0);
    `ASSERT_IMMEDIATE(tb_count_done_o == 1'b0);
    `ASSERT_IMMEDIATE(tb_counter_o == '0);

`SVTEST_END

`SVTEST(test02_enable_test)
    value = $urandom_range(15, (1<<NB_MAX_COUNT));
    tb_enable_i <= 1'b1;
    tb_rf_max_count_i <= value;
    tb_start_count_i <= 1'b1;

    @(negedge tb_clk);

    tb_start_count_i <= 1'b0;

    for (int i = 1; i < value - 11 ; i++) begin
        `ASSERT_IMMEDIATE(tb_count_in_process_o == 1'b1);
        `ASSERT_IMMEDIATE(tb_count_done_o == 1'b0);
        `ASSERT_IMMEDIATE(tb_counter_o == i);
        @(negedge tb_clk);
    end

    `ASSERT_IMMEDIATE(tb_count_in_process_o == 1'b1);
    `ASSERT_IMMEDIATE(tb_count_done_o == 1'b0);
    `ASSERT_IMMEDIATE(tb_counter_o == value - 11);

    tb_enable_i <= 1'b0;

    repeat($urandom_range(1,10))@(negedge tb_clk);

    tb_enable_i <= 1'b1;

    @(negedge tb_clk);

    for (int i = value - 10; i < value - 1 ; i++) begin
        `ASSERT_IMMEDIATE(tb_count_in_process_o == 1'b1);
        `ASSERT_IMMEDIATE(tb_count_done_o == 1'b0);
        `ASSERT_IMMEDIATE(tb_counter_o == i);
        @(negedge tb_clk);
    end

    `ASSERT_IMMEDIATE(tb_count_in_process_o == 1'b1);
    `ASSERT_IMMEDIATE(tb_count_done_o == 1'b1);
    `ASSERT_IMMEDIATE(tb_counter_o == value - 1);

    @(negedge tb_clk);

    `ASSERT_IMMEDIATE(tb_count_in_process_o == 1'b0);
    `ASSERT_IMMEDIATE(tb_count_done_o == 1'b0);
    `ASSERT_IMMEDIATE(tb_counter_o == '0);

`SVTEST_END


`SVTEST(test03_count_done)
    value               = 2;
    tb_enable_i         <= 1'b0;
    tb_rf_max_count_i   <= value;
    tb_start_count_i    <= 1'b1;

    repeat(4) @(negedge tb_clk);
    tb_enable_i         <= 1'b1;
    @(negedge tb_clk);
    `ASSERT_IMMEDIATE(tb_count_done_o == 1'b1);
    `ASSERT_IMMEDIATE(tb_count_in_process_o == 1'b1);
    tb_start_count_i    <= 1'b0;
    tb_enable_i         <= 1'b0;

    @(negedge tb_clk);
    `ASSERT_IMMEDIATE(tb_count_done_o == 1'b0);
    `ASSERT_IMMEDIATE(tb_counter_o == 1);

    @(negedge tb_clk);
    tb_enable_i         <= 1'b1;
    `ASSERT_IMMEDIATE(tb_count_done_o == 1'b0);
    `ASSERT_IMMEDIATE(tb_counter_o == 1);

`SVTEST_END
