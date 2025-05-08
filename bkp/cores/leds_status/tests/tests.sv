`SVTEST(test00_reset_test)

    i_axil_csr.write_field(`LED_REGISTERS_BLINK_TIME, 50e6, `BLINK_TIME_REG_BTIME_MASK, `BLINK_TIME_REG_BTIME_OFFSET);
    i_axil_csr.write_field(`LED_REGISTERS_LED_ID, 'h01, `LED_ID_REG_MODE_MASK, `LED_ID_REG_MODE_OFFSET);
    i_axil_csr.write_field(`LED_REGISTERS_LED_ID, 'h00, `LED_ID_REG_STATUS_MASK, `LED_ID_REG_STATUS_OFFSET);
    i_axil_csr.write_field(`LED_REGISTERS_LED_ID, 'h00, `LED_ID_REG_GNSS_MASK, `LED_ID_REG_GNSS_OFFSET);
    i_axil_csr.write_field(`LED_REGISTERS_LED_ID, 'h00, `LED_ID_REG_TRACK_MASK, `LED_ID_REG_TRACK_OFFSET);

    fork
        begin
            for (int i = 0; i < 20 ; i++) begin
                tb_rst = 1'b1;
                @(negedge tb_clk);
                tb_rst <= 1'b0;
                repeat(3)@(negedge tb_clk);
                i_axil_csr.write_field(`LEDS_STATUS_REGMAP_RST, 'h1, `RST_REG_TOGGLE_RST_MASK ,`RST_REG_TOGGLE_RST_OFFSET);
                @(negedge tb_clk);
                i_axil_csr.write_field(`LEDS_STATUS_REGMAP_RST, 'h0, `RST_REG_TOGGLE_RST_MASK ,`RST_REG_TOGGLE_RST_OFFSET);
                tb_rst = 1'b1;
                @(negedge tb_clk);
                tb_rst <= 1'b0;
        
                `ASSERT_IMMEDIATE(tb_o_led_mode   == 3'b111);
                `ASSERT_IMMEDIATE(tb_o_led_status == 3'b000);
                `ASSERT_IMMEDIATE(tb_o_led_gnss   == 3'b000);
                `ASSERT_IMMEDIATE(tb_o_led_track  == 3'b000);
                //`ASSERT_IMMEDIATE(tb_msg_o == '0);
        
            end
        end
    join
    repeat(10)@(negedge tb_clk);

`SVTEST_END

`SVTEST(test00_green_blink_test)

    tb_rst = 1'b1;
    @(negedge tb_clk);
    tb_rst <= 1'b0;
    //Let's test the GREEN LED blinking
    i_axil_csr.write_field(`LED_REGISTERS_BLINK_TIME, 20, `BLINK_TIME_REG_BTIME_MASK, `BLINK_TIME_REG_BTIME_OFFSET);
    i_axil_csr.write_field(`LED_REGISTERS_LED_ID, 8'b0001_0011, `LED_ID_REG_MODE_MASK, `LED_ID_REG_MODE_OFFSET);
    i_axil_csr.write_field(`LED_REGISTERS_LED_ID, 'h00, `LED_ID_REG_STATUS_MASK, `LED_ID_REG_STATUS_OFFSET);
    i_axil_csr.write_field(`LED_REGISTERS_LED_ID, 'h00, `LED_ID_REG_GNSS_MASK, `LED_ID_REG_GNSS_OFFSET);
    i_axil_csr.write_field(`LED_REGISTERS_LED_ID, 'h00, `LED_ID_REG_TRACK_MASK, `LED_ID_REG_TRACK_OFFSET);

    repeat(100)@(negedge tb_clk);

`SVTEST_END

`SVTEST(test00_three_blink_test)

    tb_rst = 1'b1;
    @(negedge tb_clk);
    tb_rst <= 1'b0;
    i_axil_csr.write_field(`LED_REGISTERS_BLINK_TIME, 10, `BLINK_TIME_REG_BTIME_MASK, `BLINK_TIME_REG_BTIME_OFFSET);
    i_axil_csr.write_field(`LED_REGISTERS_LED_ID, 8'b0011_1011, `LED_ID_REG_MODE_MASK, `LED_ID_REG_MODE_OFFSET);
    i_axil_csr.write_field(`LED_REGISTERS_LED_ID, 'h00, `LED_ID_REG_STATUS_MASK, `LED_ID_REG_STATUS_OFFSET);
    i_axil_csr.write_field(`LED_REGISTERS_LED_ID, 'h00, `LED_ID_REG_GNSS_MASK, `LED_ID_REG_GNSS_OFFSET);
    i_axil_csr.write_field(`LED_REGISTERS_LED_ID, 'h00, `LED_ID_REG_TRACK_MASK, `LED_ID_REG_TRACK_OFFSET);

    repeat(100)@(negedge tb_clk);

`SVTEST_END

`SVTEST(test00_all_on_test)

    tb_rst = 1'b1;
    @(negedge tb_clk);
    tb_rst <= 1'b0;
    i_axil_csr.write_field(`LED_REGISTERS_BLINK_TIME, 10, `BLINK_TIME_REG_BTIME_MASK, `BLINK_TIME_REG_BTIME_OFFSET);
    i_axil_csr.write_field(`LED_REGISTERS_LED_ID, 'h01, `LED_ID_REG_MODE_MASK, `LED_ID_REG_MODE_OFFSET);
    i_axil_csr.write_field(`LED_REGISTERS_LED_ID, 'h01, `LED_ID_REG_STATUS_MASK, `LED_ID_REG_STATUS_OFFSET);
    i_axil_csr.write_field(`LED_REGISTERS_LED_ID, 'h01, `LED_ID_REG_GNSS_MASK, `LED_ID_REG_GNSS_OFFSET);
    i_axil_csr.write_field(`LED_REGISTERS_LED_ID, 'h01, `LED_ID_REG_TRACK_MASK, `LED_ID_REG_TRACK_OFFSET);

    repeat(100)@(negedge tb_clk);

`SVTEST_END
