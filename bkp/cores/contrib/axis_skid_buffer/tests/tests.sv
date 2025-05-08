`SVTEST(test00_reset_test)
    axis_output_if.tready <= 1'b1;

    for (integer k = 0; k < 10; k = k + 1) begin
        wait_time <= $urandom_range(1,10);
        repeat(wait_time) @(negedge tb_clk);
        tb_rst = 1'b1;
        wait_time <= $urandom_range(1,10);
        repeat(wait_time) @(negedge tb_clk);
        tb_rst <= 1'b0;
    end
`SVTEST_END

`SVTEST(test01_throttle_test)
    axis_output_if.tready = 1'b0;

    for (integer k = 0; k < 1000; k = k + 1) begin
        axis_output_if.tready <= $urandom();
        @(negedge tb_clk);
    end
`SVTEST_END

`SVTEST(test02_full_throughout_test)
    for (integer k = 0; k < 20; k = k + 1) begin
        axis_output_if.tready <= 1'b1;
        repeat(1000) @(negedge tb_clk);
        axis_output_if.tready <= 1'b0;
        repeat(10) @(negedge tb_clk);
    end
`SVTEST_END

// Testing case where a producer sent a random number of packets
`SVTEST(test03_random_packets_test)
    repeat(3) @(negedge tb_clk);
    axis_input_if.tvalid <= 1'b1;

    @(negedge tb_clk);   // Delay for take the right value of last_chn

    fork
        begin // Process that writes data
            axis_write_frame();
        end
        begin  // Process that handle the TREADY signal
            axis_read();
        end
        begin // Process that drives TREADY signal
            while(axis_output_if.tvalid) begin
                repeat($urandom_range(1,150)) @(negedge tb_clk);
                axis_output_if.tready <= 1'b0;
                repeat($urandom_range(1,150)) @(negedge tb_clk);
                axis_output_if.tready <= 1'b1;
            end
        end
    join
`SVTEST_END
