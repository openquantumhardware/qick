// ============================================================================
// tests.sv - Test suite for bram_to_axis module
// Version with clocking block
// ============================================================================

`SVTEST(test_single_word)
    logic [B-1:0] expected[1];
    logic [B-1:0] actual[];
    expected[0] = B'(5);
    start_reader(N'(5), N'(1));
    read_all_data(1, actual);
    verify_data(expected, actual, "test_single_word");
`SVTEST_END

`SVTEST(test_multiple_words)
    logic [B-1:0] expected[5];
    logic [B-1:0] actual[];
    for (int i = 0; i < 5; i++) expected[i] = B'(10 + i);
    start_reader(N'(10), N'(5));
    read_all_data(5, actual);
    verify_data(expected, actual, "test_multiple_words");
`SVTEST_END

`SVTEST(test_tlast_assertion)
    logic [B-1:0] expected[3];
    logic [B-1:0] actual[];
    expected[0] = B'(20); expected[1] = B'(21); expected[2] = B'(22);
    start_reader(N'(20), N'(3));
    read_all_data(3, actual);
    verify_data(expected, actual, "test_tlast_assertion");
`SVTEST_END

`SVTEST(test_consecutive_reads)
    logic [B-1:0] expected1[3];
    logic [B-1:0] expected2[4];
    logic [B-1:0] actual[];
    for (int i = 0; i < 3; i++) expected1[i] = B'(40 + i);
    for (int i = 0; i < 4; i++) expected2[i] = B'(50 + i);
    start_reader(N'(40), N'(3));
    read_all_data(3, actual);
    verify_data(expected1, actual, "consecutive first");
    start_reader(N'(50), N'(4));
    read_all_data(4, actual);
    verify_data(expected2, actual, "consecutive second");
`SVTEST_END

`SVTEST(test_backpressure)
    logic [B-1:0] expected[6];
    logic [B-1:0] actual[$]; // Use only a dynamic queue
    logic last = 0;
    
    for (int i = 0; i < 6; i++) expected[i] = B'(30 + i);
    
    start_reader(N'(30), N'(6));
    
    // Leer hasta recibir el tlast
    for (int i = 0; i < 6; i++) begin
        // Ensure tready = 1 to receive
        axis_if_i.s_cb.tready <= 1'b1;
        
        // Wait for handshake
        // Use the clocking block to avoid race conditions
        do @(axis_if_i.s_cb); while (!axis_if_i.s_cb.tvalid); 
        
        // Capture data in the same clock cycle that the handshake occurs
        actual[i] = axis_if_i.s_cb.tdata;
        last      = axis_if_i.s_cb.tlast;
        
        $display("[BKPR] Recibido i=%0d, data=0x%0h, last=%b", i, actual[i], last);

        // If it's the beat 0, 1, 2, 3 or 4, apply backpressure (stall for 3 cycles)
        if (i < 5) begin
            axis_if_i.s_cb.tready <= 1'b0; // Stall
            repeat(3) @(axis_if_i.s_cb);
        end
    end 

    repeat(3) @(axis_if_i.s_cb);
    
    // Convert the queue to an array for your verify_data function
    `FAIL_UNLESS(actual.size() == 6)
    verify_data(expected, actual, "test_backpressure");
`SVTEST_END

`SVTEST(test_reset_during_operation)
    logic [B-1:0] expected[5];
    logic [B-1:0] actual[];
    for (int i = 0; i < 5; i++) expected[i] = B'(60 + i);
    start_reader(N'(60), N'(5));
    repeat(3) @(tb_cb);
    reset_dut();
    start_reader(N'(60), N'(5));
    read_all_data(5, actual);
    verify_data(expected, actual, "after_reset");
`SVTEST_END

`SVTEST(test_address_relatch)
    logic [B-1:0] expected_a[2];
    logic [B-1:0] expected_b[2];
    logic [B-1:0] actual[];
    expected_a[0] = B'(100); expected_a[1] = B'(101);
    expected_b[0] = B'(200); expected_b[1] = B'(201);
    start_reader(N'(100), N'(2));
    read_all_data(2, actual);
    verify_data(expected_a, actual, "addr_relatch A");
    start_reader(N'(200), N'(2));
    read_all_data(2, actual);
    verify_data(expected_b, actual, "addr_relatch B");
`SVTEST_END

`SVTEST(test_zero_length)
    start_reader(N'(10), N'(0));
    repeat(10) @(tb_cb);
    `FAIL_UNLESS(axis_if_i.tvalid == 1'b0);
`SVTEST_END

`SVTEST(test_fifo_full_stall)
    logic [B-1:0] expected[20];
    logic [B-1:0] actual[];
    logic last;

    for (int i = 0; i < 20; i++) expected[i] = B'(80 + i);
    actual = new[20];

    start_reader(N'(80), N'(20));

    for (int i = 0; i < 20; i++) begin
        if (i == 5) begin
            // Backpressure: keep tready=0 for 50 cycles
            axis_if_i.s_cb.tready <= 1'b0;
            repeat(50) @(axis_if_i.s_cb);
        end

        // Activate tready and wait for handshake via s_cb
        axis_if_i.s_cb.tready <= 1'b1;
        do @(axis_if_i.s_cb); while (!(axis_if_i.tvalid && axis_if_i.tready));

        actual[i] = axis_if_i.tdata;
        last       = axis_if_i.tlast;
        $display("[READ] data[%0d] = 0x%0h, last=%b", i, actual[i], last);

        // Put tready = 0 between beats for explicit control
        axis_if_i.s_cb.tready <= 1'b0;
        @(axis_if_i.s_cb);
    end

    repeat(5) @(axis_if_i.s_cb);
    
    verify_data(expected, actual, "test_fifo_full_stall");
`SVTEST_END

`SVTEST(test_concurrent_start_ignored)
    logic [B-1:0] expected[5];
    logic [B-1:0] actual[];
    for (int i = 0; i < 5; i++) expected[i] = B'(120 + i);
    start_reader(N'(120), N'(5));
    repeat(2) @(tb_cb);
    tb_cb.tb_start_reg <= 1'b1;
    @(tb_cb);
    tb_cb.tb_start_reg <= 1'b0;
    read_all_data(5, actual);
    verify_data(expected, actual, "test_concurrent_start_ignored");
`SVTEST_END

`SVTEST(test_memory_wrap)
    logic [B-1:0] expected[2];
    logic [B-1:0] actual[];
    expected[0] = B'(255);
    expected[1] = B'(0);
    start_reader(N'(255), N'(2));
    read_all_data(2, actual);
    verify_data(expected, actual, "test_memory_wrap");
`SVTEST_END
