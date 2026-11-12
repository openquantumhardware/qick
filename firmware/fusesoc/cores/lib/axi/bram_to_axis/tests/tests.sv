// ============================================================================
// tests.sv - Test suite for bram_to_axis module (FINAL CORRECTED VERSION)
// ============================================================================

`SVTEST(test_single_word)
    logic [B-1:0] expected[1];
    logic [B-1:0] actual[];
    expected[0] = B'(5);
    
    do_transfer(N'(5), N'(1), actual);
    verify_data(expected, actual, "test_single_word");
`SVTEST_END

`SVTEST(test_multiple_words)
    logic [B-1:0] expected[5];
    logic [B-1:0] actual[];
    for (int i = 0; i < 5; i++) expected[i] = B'(10 + i);
    
    do_transfer(N'(10), N'(5), actual);
    verify_data(expected, actual, "test_multiple_words");
`SVTEST_END

`SVTEST(test_dlast_assertion)
    logic [B-1:0] expected[3];
    logic [B-1:0] actual[];
    expected[0] = B'(20); expected[1] = B'(21); expected[2] = B'(22);
    
    do_transfer(N'(20), N'(3), actual);
    verify_data(expected, actual, "test_dlast_assertion");
`SVTEST_END

`SVTEST(test_consecutive_reads)
    logic [B-1:0] expected1[3];
    logic [B-1:0] expected2[4];
    logic [B-1:0] actual[];
    for (int i = 0; i < 3; i++) expected1[i] = B'(40 + i);
    for (int i = 0; i < 4; i++) expected2[i] = B'(50 + i);
    
    do_transfer(N'(40), N'(3), actual);
    verify_data(expected1, actual, "consecutive first");
    
    do_transfer(N'(50), N'(4), actual);
    verify_data(expected2, actual, "consecutive second");
`SVTEST_END

`SVTEST(test_backpressure)
    logic [B-1:0] expected[6];
    logic [B-1:0] actual[];
    logic last;
    
    for (int i = 0; i < 6; i++) expected[i] = B'(30 + i);
    actual = new[6];
    
    start_reader(N'(30), N'(6));
    
    for (int i = 0; i < 6; i++) begin
        if (i < 5) begin
            read_with_backpressure(actual[i], last, 3);
        end else begin
            set_tready(1'b1);
            @(posedge tb_clk);
            while (!(axis_if.tvalid && axis_if.tready)) @(posedge tb_clk);
            actual[i] = axis_if.tdata;
            last = axis_if.tlast;
            set_tready(1'b0);
        end
        $display("[BKPR] data[%0d] = 0x%0h, last=%b", i, actual[i], last);
    end
    
    stop_reader();
    verify_data(expected, actual, "test_backpressure");
`SVTEST_END

`SVTEST(test_reset_during_operation)
    logic [B-1:0] expected[5];
    logic [B-1:0] actual[];
    for (int i = 0; i < 5; i++) expected[i] = B'(60 + i);
    
    // Start first transfer
    start_reader(N'(60), N'(5));
    repeat(3) @(posedge tb_clk);
    
    // Reset during operation - this will abort the current transfer
    reset_dut();
    
    // Start a new transfer after reset
    start_reader(N'(60), N'(5));
    read_all_data(5, actual);
    stop_reader();
    verify_data(expected, actual, "after_reset");
`SVTEST_END

`SVTEST(test_address_relatch)
    logic [B-1:0] expected_a[2];
    logic [B-1:0] expected_b[2];
    logic [B-1:0] actual[];
    expected_a[0] = B'(100); expected_a[1] = B'(101);
    expected_b[0] = B'(200); expected_b[1] = B'(201);
    
    do_transfer(N'(100), N'(2), actual);
    verify_data(expected_a, actual, "addr_relatch A");
    
    do_transfer(N'(200), N'(2), actual);
    verify_data(expected_b, actual, "addr_relatch B");
`SVTEST_END

`SVTEST(test_zero_length)
    start_reader(N'(10), N'(0));
    repeat(10) @(posedge tb_clk);
    stop_reader();
    `FAIL_UNLESS(axis_if.tvalid == 1'b0);
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
            read_with_backpressure(actual[i], last, 50);
        end else begin
            set_tready(1'b1);
            @(posedge tb_clk);
            while (!(axis_if.tvalid && axis_if.tready)) @(posedge tb_clk);
            actual[i] = axis_if.tdata;
            last = axis_if.tlast;
            set_tready(1'b0);
        end
        $display("[READ] data[%0d] = 0x%0h, last=%b", i, actual[i], last);
    end
    
    stop_reader();
    verify_data(expected, actual, "test_fifo_full_stall");
`SVTEST_END

`SVTEST(test_concurrent_start_ignored)
    logic [B-1:0] expected[5];
    logic [B-1:0] actual[];
    for (int i = 0; i < 5; i++) expected[i] = B'(120 + i);
    
    start_reader(N'(120), N'(5));
    
    // Try to start another transfer while active
    repeat(2) @(posedge tb_clk);
    tb_start_reg <= 1'b1;  // This should be ignored because already active
    @(posedge tb_clk);
    tb_start_reg <= 1'b0;  // Deassert start_reg (but module still has start_reg=1 internally)
    
    read_all_data(5, actual);
    stop_reader();
    verify_data(expected, actual, "test_concurrent_start_ignored");
`SVTEST_END

`SVTEST(test_memory_wrap)
    logic [B-1:0] expected[2];
    logic [B-1:0] actual[];
    expected[0] = B'(255);
    expected[1] = B'(0);
    
    do_transfer(N'(255), N'(2), actual);
    verify_data(expected, actual, "test_memory_wrap");
`SVTEST_END

`SVTEST(tc_bram_to_axis_consecutive_reads)
    logic [B-1:0] actual[];
    
    // Write directly to the mock memory array
    // The memory is initialized as mem[i] = B'(i) in the initial block
    // So we need to override that with our test values
    mem[0] = 16'hAAAA;
    mem[1] = 16'hBBBB;
    
    $display("[TEST] mem[0]=0x%0h, mem[1]=0x%0h", mem[0], mem[1]);
    
    do_transfer(0, 2, actual);
    
    $display("[TEST] actual[0]=0x%0h, actual[1]=0x%0h", actual[0], actual[1]);
    
    `FAIL_IF_LOG(actual.size() != 2, "Expected 2 words, got %0d");
    `FAIL_IF_LOG(actual[0] !== 16'hAAAA, "First data: expected 0xAAAA");
    `FAIL_IF_LOG(actual[1] !== 16'hBBBB, "Second data: expected 0xBBBB");
`SVTEST_END
