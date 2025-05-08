    `SVTEST(test00_fixed_packet_length_test)
        tb_packet_size = $urandom_range(0,5000);
        ##10;
        tb_rst = 1'b1;
        ##1;
        tb_rst = 1'b0;
        ##10;

        axis_out_if.tready = 1'b1;
        axis_in_if.tvalid = 1'b0;
        axis_in_if.tdata = $urandom();

        for (integer i = 0; i < 20; i = i + 1) begin
            word_counter = '0;
            axis_in_if.tvalid = 1'b1;
            ##1;

            while (axis_out_if.tvalid && axis_out_if.tready && !axis_out_if.tlast) begin
                word_counter = word_counter + 1'b1;
                ##1;
            end

            `ASSERT_IMMEDIATE(word_counter == tb_packet_size - 1)
            axis_in_if.tvalid = 1'b0;
        end
    `SVTEST_END

    `SVTEST(test01_reset_and_variable_packet_length_test)
        ##10;
        tb_rst = 1'b1;
        ##1;
        tb_rst = 1'b0;
        ##10;

        axis_out_if.tready = 1'b1;
        axis_in_if.tvalid = 1'b0;
        axis_in_if.tdata = $urandom();

        for (integer i = 0; i < 20; i = i + 1) begin
            tb_packet_size = $urandom_range(0,5000);
            word_counter = '0;
            tb_rst = 1'b1;
            ##1;
            tb_rst = 1'b0;
            ##10; //tdata, tvalid & tready bypassed inside RTL, we need to wait >1 cycles
            axis_in_if.tvalid = 1'b1;
            ##1;

            while (axis_out_if.tvalid && axis_out_if.tready && !axis_out_if.tlast) begin
                word_counter = word_counter + 1'b1;
                ##1;
            end

            `ASSERT_IMMEDIATE(word_counter == tb_packet_size - 1)
            axis_in_if.tvalid = 1'b0;
        end
    `SVTEST_END

    `SVTEST(test02_throttle_test)
        tb_packet_size = $urandom_range(0,5000);
        ##10;
        tb_rst = 1'b1;
        ##1;
        tb_rst = 1'b0;
        ##10;

        axis_out_if.tready = 1'b1;
        axis_in_if.tvalid = 1'b0;
        axis_in_if.tdata = $urandom();

        for (integer i = 0; i < 20; i = i + 1) begin
            word_counter = '0;
            axis_in_if.tvalid = 1'b1;
            ##1;

            while (!(axis_out_if.tvalid && axis_out_if.tready && axis_out_if.tlast)) begin
                axis_out_if.tready = $urandom();
                if (axis_out_if.tvalid && axis_out_if.tready) begin
                    word_counter = word_counter + 1'b1;
                end
                ##1;
            end

            `ASSERT_IMMEDIATE(word_counter == tb_packet_size - 1)
            axis_in_if.tvalid = 1'b0;
        end
    `SVTEST_END
