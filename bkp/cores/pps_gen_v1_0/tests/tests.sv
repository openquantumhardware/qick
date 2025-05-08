`SVTEST(test00_reset_test)

    fork
        begin
            for (int i = 0; i < 20 ; i++) begin
                tb_rst = 1'b1;
                @(negedge tb_clk);
                tb_rst <= 1'b0;
                repeat(3)@(negedge tb_clk);
                tb_rst = 1'b1;
                @(negedge tb_clk);
                tb_rst <= 1'b0;
            end
        end
    join

`SVTEST_END

