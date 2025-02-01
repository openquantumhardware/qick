`SVTEST(test00_reset_test)

    i_axil_csr.write_field(`CTRL_LOGIC_REGISTERS_MAX_COUNT, 'h16, `MAX_COUNT_REG_MAX_COUNT_MASK, `MAX_COUNT_REG_MAX_COUNT_OFFSET    );

    fork
        begin
            for (int i = 0; i < 20 ; i++) begin
                tb_rst = 1'b1;
                @(negedge tb_clk);
                tb_rst <= 1'b0;
                repeat(3)@(negedge tb_clk);
                i_axil_csr.write_field(`UTC_TIME_REGMAP_RST, 'h1, `RST_REG_TOGGLE_RST_MASK ,`RST_REG_TOGGLE_RST_OFFSET);
                @(negedge tb_clk);
                i_axil_csr.write_field(`UTC_TIME_REGMAP_RST, 'h0, `RST_REG_TOGGLE_RST_MASK ,`RST_REG_TOGGLE_RST_OFFSET);
tb_rst = 1'b1;
                @(negedge tb_clk);
                //tb_rst <= 1'b0;
        
                //`ASSERT_IMMEDIATE(s_axis_if.tvalid == 1'b1);
                //`ASSERT_IMMEDIATE(tb_msg_o == '0);
        
            end
        end
    join

`SVTEST_END

`SVTEST(test01_constant_data_test)
    i_axil_csr.write_field(`CTRL_LOGIC_REGISTERS_MAX_COUNT, 'h16, `MAX_COUNT_REG_MAX_COUNT_MASK, `MAX_COUNT_REG_MAX_COUNT_OFFSET        );

    nmea_gen.input_data.utctime_hh     = "18";
    nmea_gen.input_data.utctime_mm     = "30";
    nmea_gen.input_data.utctime_ss     = "10";
    nmea_gen.input_data.utctime_cc     = "00";
    nmea_gen.input_data.current_day    = "27";
    nmea_gen.input_data.current_month  = "02";
    nmea_gen.input_data.current_year   = "2023";
    nmea_gen.input_data.lzone_hh       = "15";
    nmea_gen.input_data.lzone_mm       = "30";
    corrupt_checksum = 1'b0;
    nmea_gen.generate_nmea_zda(corrupt_checksum);
    nmea_msg_byte_array = nmea_gen.zda_msg;

    fork
        begin
            for (int i = 0; i < 20; i = i + 1) begin
                data_index = 0;
                axis_if.tvalid = 1'b1;

                foreach (nmea_msg_byte_array[data_index]) begin
                    axis_if.tdata = nmea_msg_byte_array[data_index];
                    @(negedge tb_clk);
                    while (! (axis_if.tvalid && axis_if.tready)) begin
                      @(negedge tb_clk);
                    end
                end

                axis_if.tvalid = 1'b0;
                @(negedge tb_clk);
            end
        end
        begin
            wait (tb_time_data_valid == 1'b1);
            @(negedge tb_clk);
            `ASSERT_IMMEDIATE(tb_time_data.year         == nmea_gen.input_data.current_year);
            `ASSERT_IMMEDIATE(tb_time_data.month        == nmea_gen.input_data.current_month);
            `ASSERT_IMMEDIATE(tb_time_data.day          == nmea_gen.input_data.current_day);
            `ASSERT_IMMEDIATE(tb_time_data.localHour    == nmea_gen.input_data.lzone_hh);
            `ASSERT_IMMEDIATE(tb_time_data.localMinutes == nmea_gen.input_data.lzone_mm);
            `ASSERT_IMMEDIATE(tb_time_data.timeOfDay    == {nmea_gen.input_data.utctime_hh, nmea_gen.input_data.utctime_mm, nmea_gen.input_data.utctime_ss, 8'h2e, nmea_gen.input_data.utctime_cc});
        end
    join
`SVTEST_END

`SVTEST(test02_random_data_and_checksum)
    fork
        begin
            for (int i = 0; i < 100; i = i + 1) begin
                corrupt_checksum = $urandom();
                nmea_gen.randomize();
                nmea_gen.generate_nmea_zda(corrupt_checksum);
                nmea_msg_byte_array = nmea_gen.zda_msg;
                data_index = 0;
                axis_if.tvalid = 1'b1;

                foreach (nmea_msg_byte_array[data_index]) begin
                    axis_if.tdata = nmea_msg_byte_array[data_index];
                    @(negedge tb_clk);
                    while (! (axis_if.tvalid && axis_if.tready)) begin
                      @(negedge tb_clk);
                    end
                end

                axis_if.tvalid = 1'b0;
                @(negedge tb_clk);
            end
        end
        begin
            if (corrupt_checksum) begin
                wait (tb_rf_checksum_error == 1'b1);
                `ASSERT_IMMEDIATE(tb_rf_checksum_error == 1'b1);
            end else begin
                wait (tb_time_data_valid == 1'b1);
                @(negedge tb_clk);
                `ASSERT_IMMEDIATE(tb_time_data.year         == nmea_gen.input_data.current_year);
                `ASSERT_IMMEDIATE(tb_time_data.month        == nmea_gen.input_data.current_month);
                `ASSERT_IMMEDIATE(tb_time_data.day          == nmea_gen.input_data.current_day);
                `ASSERT_IMMEDIATE(tb_time_data.localHour    == nmea_gen.input_data.lzone_hh);
                `ASSERT_IMMEDIATE(tb_time_data.localMinutes == nmea_gen.input_data.lzone_mm);
                `ASSERT_IMMEDIATE(tb_time_data.timeOfDay    == {nmea_gen.input_data.utctime_hh, nmea_gen.input_data.utctime_mm, nmea_gen.input_data.utctime_ss, 8'h2e, nmea_gen.input_data.utctime_cc});
            end
        end
    join
`SVTEST_END

`SVTEST(test03_bad_frame)
    fork
        begin
            for (int i = 0; i < 100; i = i + 1) begin
                corrupt_checksum = 1'b0;
                corrupt_frame = $urandom();
                nmea_gen.randomize();
                nmea_gen.generate_nmea_zda(corrupt_checksum);

                if (corrupt_frame) begin
                    corrupt_frame_options = $urandom();
                    case (corrupt_frame_options)
                    2'd0:
                    begin
                        nmea_gen.zda_msg.insert(2,"X");
                    end
                    2'd1:
                    begin
                        nmea_gen.zda_msg[4] = "Z";
                    end
                    2'd2:
                    begin
                        for (int j = 0; j < 10; j = j + 1) begin
                            nmea_gen.zda_msg.insert(10, "1");
                        end
                    end
                    2'd3:
                    begin
                        for (int j = 0; j < 20; j = j + 1) begin
                            nmea_gen.zda_msg.insert(20, ",");
                        end
                    end
                    endcase
                end

                nmea_msg_byte_array = nmea_gen.zda_msg;
                data_index = 0;
                axis_if.tvalid = 1'b1;

                foreach (nmea_msg_byte_array[data_index]) begin
                    axis_if.tdata = nmea_msg_byte_array[data_index];
                    @(negedge tb_clk);
                    while (! (axis_if.tvalid && axis_if.tready)) begin
                      @(negedge tb_clk);
                    end
                end

                axis_if.tvalid = 1'b0;
                @(negedge tb_clk);
            end
        end
        begin
            if (corrupt_frame) begin
                wait (tb_rf_badframe == 1'b1);
                `ASSERT_IMMEDIATE(tb_rf_badframe == 1'b1);
            end else begin
                wait (tb_time_data_valid == 1'b1);
                @(negedge tb_clk);
                `ASSERT_IMMEDIATE(tb_time_data.year         == nmea_gen.input_data.current_year);
                `ASSERT_IMMEDIATE(tb_time_data.month        == nmea_gen.input_data.current_month);
                `ASSERT_IMMEDIATE(tb_time_data.day          == nmea_gen.input_data.current_day);
                `ASSERT_IMMEDIATE(tb_time_data.localHour    == nmea_gen.input_data.lzone_hh);
                `ASSERT_IMMEDIATE(tb_time_data.localMinutes == nmea_gen.input_data.lzone_mm);
                `ASSERT_IMMEDIATE(tb_time_data.timeOfDay    == {nmea_gen.input_data.utctime_hh, nmea_gen.input_data.utctime_mm, nmea_gen.input_data.utctime_ss, 8'h2e, nmea_gen.input_data.utctime_cc});
            end
        end
    join
`SVTEST_END

`SVTEST(test04_timeout)
    fork
        begin
            for (int i = 0; i < 100; i = i + 1) begin
                corrupt_checksum = 1'b0;
                nmea_gen.randomize();
                nmea_gen.generate_nmea_zda(corrupt_checksum);
                elements_deleted = 10;
                nmea_gen.zda_msg = nmea_gen.zda_msg[0:$-elements_deleted];
                nmea_msg_byte_array = nmea_gen.zda_msg;
                data_index = 0;
                axis_if.tvalid = 1'b1;

                foreach (nmea_msg_byte_array[data_index]) begin
                    axis_if.tdata = nmea_msg_byte_array[data_index];
                    @(negedge tb_clk);
                    while (! (axis_if.tvalid && axis_if.tready)) begin
                      @(negedge tb_clk);
                    end
                end

                axis_if.tvalid = 1'b0;
                @(negedge tb_clk);
            end
        end
        begin
            wait (tb_rf_timeout == 1'b1);
            `ASSERT_IMMEDIATE(tb_rf_timeout == 1'b1);
        end
    join
`SVTEST_END

`SVTEST(test05_random_valid)
    fork
        begin
            for (int i = 0; i < 100; i = i + 1) begin
                corrupt_checksum = 1'b0;
                nmea_gen.randomize();
                nmea_gen.generate_nmea_zda(corrupt_checksum);
                nmea_msg_byte_array = nmea_gen.zda_msg;
                data_index = 0;

                while (data_index < nmea_msg_byte_array.size())  begin
                    axis_if.tvalid = $urandom();
                    axis_if.tdata = nmea_msg_byte_array[data_index];
                    @(negedge tb_clk);
                    if (axis_if.tvalid == 1'b1) begin
                        wait (axis_if.tready);
                        data_index += 1;
                    end else begin
                      @(negedge tb_clk);
                    end
                end

                axis_if.tvalid = 1'b0;
                @(negedge tb_clk);
            end
        end
        begin
            wait (tb_time_data_valid == 1'b1);
            @(negedge tb_clk);
            `ASSERT_IMMEDIATE(tb_time_data.year         == nmea_gen.input_data.current_year);
            `ASSERT_IMMEDIATE(tb_time_data.month        == nmea_gen.input_data.current_month);
            `ASSERT_IMMEDIATE(tb_time_data.day          == nmea_gen.input_data.current_day);
            `ASSERT_IMMEDIATE(tb_time_data.localHour    == nmea_gen.input_data.lzone_hh);
            `ASSERT_IMMEDIATE(tb_time_data.localMinutes == nmea_gen.input_data.lzone_mm);
            `ASSERT_IMMEDIATE(tb_time_data.timeOfDay    == {nmea_gen.input_data.utctime_hh, nmea_gen.input_data.utctime_mm, nmea_gen.input_data.utctime_ss, 8'h2e, nmea_gen.input_data.utctime_cc});
        end
    join
`SVTEST_END

`SVTEST(test06_maxcount_test)

    i_axil_csr.write_field(`CTRL_LOGIC_REGISTERS_SW_MAXCNTR_ENABLE, 'h1, `SW_MAXCNTR_ENABLE_REG_MAXCNTR_ENABLE_MASK, `SW_MAXCNTR_ENABLE_REG_MAXCNTR_ENABLE_OFFSET );
    i_axil_csr.write_field(`CTRL_LOGIC_REGISTERS_MAX_COUNT, 'h16, `MAX_COUNT_REG_MAX_COUNT_MASK, `MAX_COUNT_REG_MAX_COUNT_OFFSET    );
    i_axil_csr.read(`STATUS_REGISTERS_CLK_BTW_PPS, tb_error_reg);
    $display("Clocks entre PPS: %d", tb_error_reg);



    fork
        begin
            for (int i = 0; i < 20 ; i++) begin
                tb_rst = 1'b1;
                @(negedge tb_clk);
                tb_rst <= 1'b0;
                repeat(20)@(negedge tb_clk);
                tb_pps = 1'b1;
                @(negedge tb_clk);
                tb_pps <= 1'b0;
                repeat(200)@(negedge tb_clk);
            end
        end
    join
    i_axil_csr.write_field(`CTRL_LOGIC_REGISTERS_SW_MAXCNTR_ENABLE, 'h0, `SW_MAXCNTR_ENABLE_REG_MAXCNTR_ENABLE_MASK, `SW_MAXCNTR_ENABLE_REG_MAXCNTR_ENABLE_OFFSET );
    fork
        begin
            for (int i = 0; i < 20 ; i++) begin
                tb_rst = 1'b1;
                @(negedge tb_clk);
                tb_rst <= 1'b0;
                repeat(20)@(negedge tb_clk);
                tb_pps = 1'b1;
                @(negedge tb_clk);
                tb_pps <= 1'b0;
                repeat(200)@(negedge tb_clk);
            end
        end
    join
    i_axil_csr.read(`STATUS_REGISTERS_CLK_BTW_PPS, tb_error_reg);
    $display("Clocks entre PPS: %d", tb_error_reg);

`SVTEST_END
