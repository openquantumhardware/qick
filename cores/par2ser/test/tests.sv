if(test_8bit) begin
`SVTEST(test00_8bit)
 // Test case 1: Send 8 bits (0 to 7)
        $display("--- Test Case 1: Sending 8 bits  ---");
        tb_cb.tb_i_data <= 8'b1110_0011; tb_cb.tb_i_load <= 1; @(tb_cb); tb_cb.tb_i_load <= 0;

        // Wait for serial_ready
        wait(tb_o_valid);
        repeat(10) @(tb_cb);
        $display("Received serial data: %b (expected: 00000111)", tb_o_data);
        if (tb_o_data == 8'b00000111) $display("Test Case 1 PASSED");
        else $display("Test Case 1 FAILED");
        repeat(20) @(tb_cb);
`SVTEST_END
end
//-------------------------------------------------------------------------------------------------//
if(test_16bit) begin
`SVTEST(test01_16bit)
 // Test case 2: Send 16 bits 
        $display("--- Test Case 2: Sending 16 bits  ---");
        tb_cb.tb_i_data <= 16'b1111_0000_1010_1100; tb_cb.tb_i_load <= 1; @(tb_cb); tb_cb.tb_i_load <= 0;

        // Wait for serial_ready
        wait(tb_o_valid);
        repeat(10) @(tb_cb);
        $display("Received serial data: %b (expected: 0000011100000111)", tb_o_data);
        if (tb_o_data == 16'b0000011100000111) $display("Test Case 2 PASSED");
        else $display("Test Case 2 FAILED");
        repeat(20) @(tb_cb);
`SVTEST_END
end
//-------------------------------------------------------------------------------------------------//
