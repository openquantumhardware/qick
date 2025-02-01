`SVTEST(test00_reset_test)

    s_axis_if.tdata <= 'h55;
    axis_transaction();

    repeat(2)@(negedge tb_clk);

    for (int i = 0; i < 10 ; i++) begin
        tb_rst <= 1'b1;

        @(negedge tb_clk);

        tb_rst <= 1'b0;

        @(negedge tb_clk);

        `ASSERT_IMMEDIATE(m_datas_if.valid == 1'b0);
        `ASSERT_IMMEDIATE(m_datas_if.last == 1'b0);

        repeat($urandom_range(1,10))@(negedge tb_clk);
    end

`SVTEST_END

`SVTEST(test01_last_check)

    s_axis_if.tdata <= $urandom();
    axis_transaction();

    @(negedge tb_clk);

    while (!m_datas_if.last) begin
        tb_count ++;
        @(negedge tb_clk);
    end
    tb_count ++;
    
    `ASSERT_IMMEDIATE(tb_count == u_memory_data_dispatcher.len_d);

`SVTEST_END

`SVTEST(test02_full_throughput_data_select)

    for (int j = 0; j<10 ; j++) begin
        s_axis_if.tdata <= tb_data[j];
        axis_transaction();

        for (int i = 0; i < tb_data[j].tb_len - 1; i++) begin
            @(negedge tb_clk);

            `ASSERT_IMMEDIATE(m_datas_if.valid == 1'b1);
            `ASSERT_IMMEDIATE(m_datas_if.last == 1'b0);
            data_out_concat = {tb_bram_data_full_msb[(MEM_NB_DATA * (tb_data[j].tb_base_address + i))  +: MEM_NB_DATA],tb_bram_data_full_lsb[(MEM_NB_DATA * (tb_data[j].tb_base_address + i))  +: MEM_NB_DATA]};
            `ASSERT_IMMEDIATE(m_datas_if.data == data_out_concat);
        end

        @(negedge tb_clk);

        `ASSERT_IMMEDIATE(m_datas_if.valid == 1'b1);
        `ASSERT_IMMEDIATE(m_datas_if.last == 1'b1);
        data_out_concat = {tb_bram_data_full_msb[(MEM_NB_DATA * (tb_data[j].tb_base_address + tb_data[j].tb_len - 1)) +: MEM_NB_DATA] , tb_bram_data_full_lsb[(MEM_NB_DATA * (tb_data[j].tb_base_address + tb_data[j].tb_len - 1)) +: MEM_NB_DATA]};
        `ASSERT_IMMEDIATE(m_datas_if.data == data_out_concat);

        @(negedge tb_clk);

        `ASSERT_IMMEDIATE(m_datas_if.valid == 1'b0);
        `ASSERT_IMMEDIATE(m_datas_if.last == 1'b0);
    end

`SVTEST_END

`SVTEST(test03_len_equals_one_test)

    tb_data_1.tb_len = 'h1;
    tb_data_1.tb_base_address = '0;
    s_axis_if.tdata <= tb_data_1;
    axis_transaction();

    @(negedge tb_clk);

    `ASSERT_IMMEDIATE(m_datas_if.valid == 1'b1);
    `ASSERT_IMMEDIATE(m_datas_if.last == 1'b1);

    for (int i = 0; i<10; i++) begin
        @(negedge tb_clk);
        `ASSERT_IMMEDIATE(m_datas_if.valid == 1'b0);
    end

`SVTEST_END

`SVTEST(test04_enable_test)

    s_axis_if.tdata <= tb_data[0];
    axis_transaction();

    @(negedge tb_clk);

    tb_enable_i <= 1'b0;
    s_axis_if.tvalid <= 1'b1;
    s_axis_if.tdata <= tb_data[2];
    `ASSERT_IMMEDIATE(m_datas_if.valid == 1'b1);
    `ASSERT_IMMEDIATE(m_datas_if.last == 1'b0);

    @(negedge tb_clk);

    for (int i = 0; i<10; i++) begin
        `ASSERT_IMMEDIATE(m_datas_if.valid == 1'b0);
        `ASSERT_IMMEDIATE(m_datas_if.last == 1'b0);
        `ASSERT_IMMEDIATE(s_axis_if.tready == 1'b0);
        @(negedge tb_clk);
    end

    `ASSERT_IMMEDIATE(s_axis_if.tready == 1'b0);
    tb_enable_i <= 1'b1;

    for (int i = 1; i < tb_data[0].tb_len - 1; i++) begin
        @(negedge tb_clk);
        `ASSERT_IMMEDIATE(s_axis_if.tready == 1'b0);
        `ASSERT_IMMEDIATE(m_datas_if.valid == 1'b1);
        `ASSERT_IMMEDIATE(m_datas_if.last == 1'b0);
        data_out_concat = {tb_bram_data_full_msb[(MEM_NB_DATA * (tb_data[0].tb_base_address + i))  +: MEM_NB_DATA], tb_bram_data_full_lsb[(MEM_NB_DATA * (tb_data[0].tb_base_address + i))  +: MEM_NB_DATA]};
        `ASSERT_IMMEDIATE(m_datas_if.data == data_out_concat);
    end

    @(negedge tb_clk);

    `ASSERT_IMMEDIATE(s_axis_if.tready == 1'b0);
    `ASSERT_IMMEDIATE(m_datas_if.valid == 1'b1);
    `ASSERT_IMMEDIATE(m_datas_if.last == 1'b1);
    data_out_concat = {tb_bram_data_full_msb[(MEM_NB_DATA * (tb_data[0].tb_base_address + tb_data[0].tb_len - 1)) +: MEM_NB_DATA],tb_bram_data_full_lsb[(MEM_NB_DATA * (tb_data[0].tb_base_address + tb_data[0].tb_len - 1)) +: MEM_NB_DATA]};
    `ASSERT_IMMEDIATE(m_datas_if.data == data_out_concat);

    @(negedge tb_clk);

    `ASSERT_IMMEDIATE(s_axis_if.tready == 1'b1);

`SVTEST_END

`SVTEST(test05_rd_first_position_bram)
    s_axis_if.tdata <= tb_data[1];

    for (int j = 0; j<10 ; j++) begin
        axis_transaction();

        for (int i = 0; i < tb_data[1].tb_len - 1; i++) begin
            @(negedge tb_clk);

            `ASSERT_IMMEDIATE(m_datas_if.valid == 1'b1);
            `ASSERT_IMMEDIATE(m_datas_if.last == 1'b0);
            data_out_concat = {tb_bram_data_full_msb[(MEM_NB_DATA * (tb_data[1].tb_base_address + i))  +: MEM_NB_DATA],tb_bram_data_full_lsb[(MEM_NB_DATA * (tb_data[1].tb_base_address + i))  +: MEM_NB_DATA]};
            `ASSERT_IMMEDIATE(m_datas_if.data == data_out_concat);
        end

        @(negedge tb_clk);

        `ASSERT_IMMEDIATE(m_datas_if.valid == 1'b1);
        `ASSERT_IMMEDIATE(m_datas_if.last == 1'b1);
        data_out_concat = {tb_bram_data_full_msb[(MEM_NB_DATA * (tb_data[1].tb_base_address + tb_data[1].tb_len - 1)) +: MEM_NB_DATA], tb_bram_data_full_lsb[(MEM_NB_DATA * (tb_data[1].tb_base_address + tb_data[1].tb_len - 1)) +: MEM_NB_DATA]};
        `ASSERT_IMMEDIATE(m_datas_if.data == data_out_concat);

        @(negedge tb_clk);

        `ASSERT_IMMEDIATE(m_datas_if.valid == 1'b0);
        `ASSERT_IMMEDIATE(m_datas_if.last == 1'b0);
    end

`SVTEST_END

`SVTEST(test06_rd_software_enable)
    value = 'h0;

    tb_axil_rd_en_i <= 1'b1;
    @(negedge tb_clk);

    for (int i = 0 ; i < (1 << NB_DEPTH) ; i++) begin

        axi4_lite_in_if.read(i*4,data_out);

        @(negedge tb_clk);

        `ASSERT_IMMEDIATE(data_out == {8{value}});

        value ++;

    end

`SVTEST_END