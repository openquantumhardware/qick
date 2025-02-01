    `SVTEST(test00_reset_test)
        repeat(10)@(axis_output_if.m_cb);
        tb_rst <= 1'b1;
        repeat(1)@(axis_output_if.m_cb);
        tb_rst <= 1'b0;
        repeat(10)@(axis_output_if.m_cb);

        for (integer i = 0; i < 10; i = i + 1) begin
            `ASSERT_IMMEDIATE(tb_fifo_empty == 1'b1);
            `ASSERT_IMMEDIATE(tb_fifo_full == 1'b0);
            `ASSERT_IMMEDIATE(axis_output_if.m_cb.tvalid == 1'b0);

            data_input_if.s_cb.data <= $urandom();

            repeat(1)@(axis_output_if.m_cb) data_input_if.s_cb.valid <= 1'b1;
            repeat(1)@(axis_output_if.m_cb) data_input_if.s_cb.valid <= 1'b0;
            repeat(5)@(axis_output_if.m_cb);

            `ASSERT_IMMEDIATE(tb_fifo_empty == 1'b0);
            `ASSERT_IMMEDIATE(tb_fifo_full == 1'b0);
            `ASSERT_IMMEDIATE(axis_output_if.m_cb.tvalid == 1'b1);

            tb_rst <= 1'b1;
            repeat(1)@(axis_output_if.m_cb);
            tb_rst <= 1'b0;
            repeat(10)@(axis_output_if.m_cb);
        end
    `SVTEST_END

    `SVTEST(test01_data_sanity_check)
        //check for data sanity between input and output streams
        axis_output_if.m_cb.tready <= 1'b1;

        for (integer k = 0; k < 100; k = k + 1) begin
            data_payload = $urandom();

            data_input_if.s_cb.data <= data_payload;

            data_input_if.s_cb.valid <= 1'b1;
            repeat(1)@(axis_output_if.m_cb)
            data_input_if.s_cb.valid <= 1'b0;

            while (axis_output_if.m_cb.tvalid != 1'b1) @(axis_output_if.m_cb);

            repeat(1)@(axis_output_if.m_cb);
            `ASSERT_IMMEDIATE(axis_output_if.m_cb.tdata == data_payload)
        end
    `SVTEST_END

    `SVTEST(test02_full_throughput_data_sanity_check)
        //concurrently write and read at full throughput
        axis_output_if.m_cb.tready <= 1'b1;
        data_input_if.s_cb.valid <= 1'b1;
        fork
            begin
                for (integer k = 0; k < 100; k = k + 1) begin
                    data_payload = $urandom();

                    data_input_if.s_cb.data <= data_payload;
                    data_payload_queue.push_front(data_payload);

                    repeat(1)@(axis_output_if.m_cb);
                end
            end
            begin
                for (integer l = 0; l < 100; l = l + 1) begin
                    if (axis_output_if.m_cb.tvalid) begin
                        `ASSERT_IMMEDIATE(axis_output_if.m_cb.tdata == data_payload_queue.pop_back())
                    end

                    repeat(1)@(axis_output_if.m_cb);
                end
            end
        join
    `SVTEST_END

    `SVTEST(test03_throttle_test)
        fork
            begin
                for (integer k = 0; k < 100; k = k + 1) begin
                    data_payload = $urandom();

                    data_input_if.s_cb.data <= data_payload;
                    data_input_if.s_cb.valid <= $urandom();

                    repeat(1)@(axis_output_if.m_cb);
                    if (!tb_fifo_full && data_input_if.valid) begin
                        data_payload_queue.push_front(data_payload);
                    end
                end
            end
            begin
                for (integer l = 0; l < 100; l = l + 1) begin
                    axis_output_if.m_cb.tready <= $urandom();
                    @(axis_output_if.m_cb);
                    if (axis_output_if.m_cb.tvalid && axis_output_if.tready) begin
                        rcv_data_payload = data_payload_queue.pop_back();
                        `ASSERT_IMMEDIATE_LOG(
                            axis_output_if.m_cb.tdata == rcv_data_payload,
                            $sformatf(
                                "Obtained data %0h does not match expected data %0h",
                                axis_output_if.m_cb.tdata,
                                rcv_data_payload
                            )
                        );
                    end
                end
            end
        join
    `SVTEST_END

    `SVTEST(test04_recovery)
        //overflow fifo
        axis_output_if.m_cb.tready <= 1'b0;
        data_input_if.s_cb.valid <= 1'b1;
        data_payload = $urandom();

        while (tb_fifo_full != 1'b1) @(axis_output_if.m_cb);

        data_input_if.s_cb.valid <= 1'b0;
        axis_output_if.m_cb.tready <= 1'b1;

        while (tb_fifo_empty != 1'b1) @(axis_output_if.m_cb);

        repeat(20)@(axis_output_if.m_cb);

        //retest sanity
        for (integer k = 0; k < 100; k = k + 1) begin
            data_payload = $urandom();

            data_input_if.s_cb.data <= data_payload;

            data_input_if.s_cb.valid <= 1'b1;
            repeat(1)@(axis_output_if.m_cb)
            data_input_if.s_cb.valid <= 1'b0;

            while (axis_output_if.m_cb.tvalid != 1'b1) @(axis_output_if.m_cb);

            repeat(1)@(axis_output_if.m_cb);
            `ASSERT_IMMEDIATE(axis_output_if.m_cb.tdata == data_payload)
        end
    `SVTEST_END
