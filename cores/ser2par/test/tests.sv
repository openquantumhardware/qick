`SVTEST(test02_s8d4p2)
 // Test case 1: Send 8 bits (0 to 7)
        $display("--- Test Case 1: Sending 8 bits  ---");
        tb_cb.tb_i_data <= 1; tb_cb.tb_i_load <= 1; @(tb_cb); tb_cb.tb_i_load <= 0;
        tb_cb.tb_i_data <= 1; tb_cb.tb_i_load <= 1; @(tb_cb); tb_cb.tb_i_load <= 0;
        tb_cb.tb_i_data <= 1; tb_cb.tb_i_load <= 1; @(tb_cb); tb_cb.tb_i_load <= 0;
        tb_cb.tb_i_data <= 0; tb_cb.tb_i_load <= 1; @(tb_cb); tb_cb.tb_i_load <= 0;
        tb_cb.tb_i_data <= 0; tb_cb.tb_i_load <= 1; @(tb_cb); tb_cb.tb_i_load <= 0;
        tb_cb.tb_i_data <= 0; tb_cb.tb_i_load <= 1; @(tb_cb); tb_cb.tb_i_load <= 0;
        tb_cb.tb_i_data <= 0; tb_cb.tb_i_load <= 1; @(tb_cb); tb_cb.tb_i_load <= 0;
        tb_cb.tb_i_data <= 0; tb_cb.tb_i_load <= 1; @(tb_cb); tb_cb.tb_i_load <= 0;

        // Wait for parallel_ready
        wait(tb_o_ready);
        repeat(10) @(tb_cb);
        $display("Received parallel data: %b (expected: 00000111)", tb_o_data);
        if (tb_o_data == 8'b00000111) $display("Test Case 1 PASSED");
        else $display("Test Case 1 FAILED");
        repeat(20) @(tb_cb);
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
