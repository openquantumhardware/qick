    `SVTEST(test00_reset_test)
        for (integer i = 0; i < 10; i = i + 1) begin
            repeat(10)@(o_axis.m_cb) tb_rst <= 1'b1;
            repeat(10)@(o_axis.m_cb) tb_rst <= 1'b0;
        end
    `SVTEST_END

    `SVTEST(full_throughput_test)
        fork
            begin
                for(int i = 0; i < 10; i++) begin
                    for (int j = 0; j < N_CHANNELS; j++) begin
                        data_payload[j] = (i+1)*j;
                    end
                    i_axis.s_cb.tdata <= data_payload;
                    i_axis.s_cb.tvalid <= 1'b1;
                    data_queue.push_back(data_payload);
                    @(i_axis.s_cb)
                    while(!i_axis.s_cb.tready) @(i_axis.s_cb);
                end
            end
            begin
                o_axis.m_cb.tready <= 1'b1;
                @(o_axis.m_cb);
                while(!o_axis.tvalid) @(o_axis.m_cb);
                for(int i = 0; i < 10; i++) begin
                    for (int j = 0; j < N_CHANNELS; j++) begin
                        `ASSERT_IMMEDIATE(o_axis.m_cb.tdata == data_queue[0][j]);
                        `ASSERT_IMMEDIATE(o_axis.tlast == (j == N_CHANNELS-1));
                        @(o_axis.m_cb);
                    end
                    data_queue.pop_front();
                end
            end
        join
    `SVTEST_END

    `SVTEST(random_transaction_test)
        fork
            begin
                for(int i = 0; i < 10; i++) begin
                    for (int j = 0; j < N_CHANNELS; j++) begin
                        data_payload[j] = (i+1)*j;
                    end
                    repeat($urandom_range(10))@(i_axis.s_cb);
                    i_axis.s_cb.tdata <= data_payload;
                    i_axis.s_cb.tvalid <= 1'b1;
                    data_queue.push_back(data_payload);
                    @(i_axis.s_cb)
                    while(!i_axis.s_cb.tready) @(i_axis.s_cb);
                    i_axis.s_cb.tvalid <= 1'b0;
                end
            end
            begin
                for(int i = 0; i < 10; i++) begin
                    for (int j = 0; j < N_CHANNELS; j++) begin
                        repeat($urandom_range(10))@(o_axis.m_cb);
                        o_axis.m_cb.tready <= 1'b1;
                        @(o_axis.m_cb);
                        while(!o_axis.tvalid) @(o_axis.m_cb);
                        `ASSERT_IMMEDIATE(o_axis.m_cb.tdata == data_queue[0][j]);
                        `ASSERT_IMMEDIATE(o_axis.tlast == (j == N_CHANNELS-1));
                        o_axis.m_cb.tready <= 1'b0;
                    end
                    data_queue.pop_front();
                end
            end
        join
    `SVTEST_END

    `SVTEST(tvalid_after_tready)
        fork
            begin
                for (int j = 0; j < N_CHANNELS; j++) begin
                    data_payload[j] = j;
                end
                repeat($urandom_range(2,10)) @(i_axis.s_cb);
                i_axis.s_cb.tdata <= data_payload;
                i_axis.s_cb.tvalid <= 1'b1;
                data_queue.push_back(data_payload);
                while(!i_axis.s_cb.tready) @(i_axis.s_cb);
                @(i_axis.s_cb)
                i_axis.s_cb.tvalid <= 1'b0;
            end
            begin
                o_axis.m_cb.tready <= 1'b1;
                @(o_axis.m_cb);
                for (int j = 0; j < N_CHANNELS; j++) begin
                    while(!o_axis.tvalid) @(o_axis.m_cb);
                    `ASSERT_IMMEDIATE(o_axis.m_cb.tdata == data_queue[0][j]);
                    `ASSERT_IMMEDIATE(o_axis.tlast == (j == N_CHANNELS-1));
                    @(o_axis.m_cb);
                end
                data_queue.pop_front();
            end
        join
    `SVTEST_END

    `SVTEST(tlast_prop_in_tuser)
        fork
            begin
                for (int i = 0; i < 10; i++) begin
                    // using data_payload first bit as tlast flag
                    data_payload[0][0] = $urandom();
                    repeat($urandom_range(2,20)) @(i_axis.s_cb);
                    i_axis.s_cb.tvalid <= 1'b1;
                    i_axis.s_cb.tlast <= data_payload[0][0];
                    data_queue.push_back(data_payload);
                    @(i_axis.s_cb)
                    while(!i_axis.s_cb.tready) @(i_axis.s_cb);
                    i_axis.s_cb.tvalid <= 1'b0;
                end
            end
            begin
                for (int i = 0; i < 10; i++) begin
                    repeat($urandom_range(2,10)) @(o_axis.m_cb);
                    o_axis.m_cb.tready <= 1'b1;
                    for (int j = 0; j < N_CHANNELS; j++) begin
                        @(o_axis.m_cb);
                        while(!o_axis.tvalid) @(o_axis.m_cb);
                        if (dut.TLAST_IS_EOF) begin
                            `ASSERT_IMMEDIATE_LOG(
                                o_axis.tlast == ((j == N_CHANNELS-1) & data_queue[0][0][0]),
                                $sformatf(
                                    "Unexpected tlast value %0h for channel %0d",
                                    o_axis.tlast,
                                    j
                                )
                            );
                        end
                        else begin
                            `ASSERT_IMMEDIATE(&o_axis.m_cb.tuser == data_queue[0][0][0]);
                            `ASSERT_IMMEDIATE_LOG(
                                o_axis.tlast == (j == N_CHANNELS-1),
                                $sformatf(
                                    "Unexpected tlast value %0h for channel %0d",
                                    o_axis.tlast,
                                    j
                                )
                            );
                        end
                    end
                    data_queue.pop_front();
                    o_axis.m_cb.tready <= 1'b0;
                end
            end
        join
    `SVTEST_END
