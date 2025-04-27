    `SVTEST(test00_reset_test)
        ##10;
        tb_rst = 1'b1;
        ##1;
        tb_rst = 1'b0;
        ##10;

        for (integer i = 0; i < 100; i = i + 1) begin
            axis_in_if.tvalid = 1'b1;
            for (integer j = 0; j < 10; j = j + 1) begin
                axis_in_if.tdata = $urandom();
                ##1;
            end
            axis_in_if.tvalid = 1'b0;
            ##990;
        end
    `SVTEST_END

