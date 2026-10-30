// ============================================================================
// File: bram_to_axis_nt_tests.sv
// Description: SVUnit test cases for bram_to_axis_nt module.
// ============================================================================

// -----------------------------------------------------------------------------
// TEST 00: Basic read - verify all channels from all addresses
// -----------------------------------------------------------------------------
`SVTEST(tc00_basic_read)
    localparam int TOTAL_WORDS = 2**N * NT;
    logic [B-1:0] actual[];
    logic [B-1:0] expected[];
    
    // Read all data (do_transfer already waits for completion)
    do_transfer(TOTAL_WORDS, actual, 100000);
    
    // Build expected data
    expected = new[TOTAL_WORDS];
    for (int i = 0; i < TOTAL_WORDS; i++) begin
        expected[i] = get_expected_data(i);
    end
    
    verify_data(expected, actual, "tc00_basic_read");
`SVTEST_END

// -----------------------------------------------------------------------------
// TEST 01: Verify tlast on last word only
// -----------------------------------------------------------------------------
`SVTEST(tc01_tlast_assertion)
    localparam int TOTAL_WORDS = 2**N * NT;
    logic [B-1:0] data[];
    logic last_found;
    
    start_reader();
    set_tready(1'b1);
    
    last_found = 1'b0;
    for (int i = 0; i < TOTAL_WORDS; i++) begin
        @(posedge tb_clk);
        while (!(tb_m_axis_tvalid && tb_m_axis_tready)) begin
            @(posedge tb_clk);
        end
        
        if (i == TOTAL_WORDS - 1) begin
            `FAIL_IF_LOG(tb_m_axis_tlast !== 1'b1, 
                $sformatf("tlast should be 1 on word %0d", i));
            last_found = 1'b1;
        end else begin
            `FAIL_IF_LOG(tb_m_axis_tlast !== 1'b0, 
                $sformatf("tlast should be 0 on word %0d (got %b)", i, tb_m_axis_tlast));
        end
    end
    
    `FAIL_IF_LOG(last_found !== 1'b1, "tlast never asserted");
    
    // Don't call wait_for_read_complete again - we already consumed all data
    stop_reader();
`SVTEST_END

// -----------------------------------------------------------------------------
// TEST 02: Backpressure - stall during read
// -----------------------------------------------------------------------------
`SVTEST(tc02_backpressure)
    localparam int TOTAL_WORDS = 2**N * NT;
    logic [B-1:0] actual[];
    logic [B-1:0] expected[];
    
    expected = new[TOTAL_WORDS];
    for (int i = 0; i < TOTAL_WORDS; i++) begin
        expected[i] = get_expected_data(i);
    end
    
    start_reader();
    set_tready(1'b0);
    
    actual = new[TOTAL_WORDS];
    for (int i = 0; i < TOTAL_WORDS; i++) begin
        // Occasionally apply backpressure
        if (i > 0 && (i % 5 == 0)) begin
            set_tready(1'b0);
            repeat(3) @(posedge tb_clk);
            $display("[BACKPRESSURE] stall at word %0d", i);
        end
        
        set_tready(1'b1);
        @(posedge tb_clk);
        while (!(tb_m_axis_tvalid && tb_m_axis_tready)) begin
            @(posedge tb_clk);
        end
        
        actual[i] = tb_m_axis_tdata;
        $display("[READ] word[%0d] = 0x%0h, tlast=%b", i, actual[i], tb_m_axis_tlast);
        
        // Verify tlast only on last word
        if (i == TOTAL_WORDS - 1) begin
            `FAIL_IF_LOG(tb_m_axis_tlast !== 1'b1, "tlast not asserted on last word");
        end
    end
    
    stop_reader();
    verify_data(expected, actual, "tc02_backpressure");
`SVTEST_END

// -----------------------------------------------------------------------------
// TEST 03: Reset during operation - verifies that reset aborts current transfer
//          and allows a new transfer to start from beginning
// -----------------------------------------------------------------------------
`SVTEST(tc03_reset_during_operation)
    localparam int TOTAL_WORDS = 2**N * NT;
    logic [B-1:0] actual[];
    logic [B-1:0] expected[];
    
    // Reinitialize BRAM with clean pattern
    for (int i = 0; i < 2**N; i++) begin
        for (int ch = 0; ch < NT; ch++) begin
            mem[i][(ch+1)*B-1 -: B] = (i * NT + ch) & 16'hFFFF;
        end
    end
    
    expected = new[TOTAL_WORDS];
    for (int i = 0; i < TOTAL_WORDS; i++) begin
        expected[i] = get_expected_data(i);
    end
    
    // Start first transfer and read first few words
    start_reader();
    set_tready(1'b1);
    
    // Read exactly 4 words before reset
    for (int i = 0; i < 4; i++) begin
        @(posedge tb_clk);
        while (!(tb_m_axis_tvalid && tb_m_axis_tready)) @(posedge tb_clk);
        $display("[PRE-RESET] read word[%0d] = 0x%0h", i, tb_m_axis_tdata);
    end
    
    // Reset during operation
    $display("[RESET] Applying reset...");
    reset_dut();
    $display("[RESET] Reset complete");
    
    // Start new transfer after reset
    start_reader();
    read_all_data(TOTAL_WORDS, actual);
    stop_reader();
    
    // Verify all data (should match expected pattern from beginning)
    verify_data(expected, actual, "tc03_reset_during_operation");
`SVTEST_END

// -----------------------------------------------------------------------------
// TEST 04: Multiple back-to-back transfers
// -----------------------------------------------------------------------------
`SVTEST(tc04_consecutive_transfers)
    localparam int TOTAL_WORDS = 2**N * NT;
    logic [B-1:0] transfer1[];
    logic [B-1:0] transfer2[];
    logic [B-1:0] expected[];
    
    expected = new[TOTAL_WORDS];
    for (int i = 0; i < TOTAL_WORDS; i++) begin
        expected[i] = get_expected_data(i);
    end
    
    // First transfer
    do_transfer(TOTAL_WORDS, transfer1, 100000);
    verify_data(expected, transfer1, "tc04_consecutive first");
    
    // Small pause
    repeat(10) @(posedge tb_clk);
    
    // Second transfer
    do_transfer(TOTAL_WORDS, transfer2, 100000);
    verify_data(expected, transfer2, "tc04_consecutive second");
`SVTEST_END

// -----------------------------------------------------------------------------
// TEST 05: Start_reg held behavior (level-sensitive)
// -----------------------------------------------------------------------------
`SVTEST(tc05_start_reg_level_sensitive)
    localparam int TOTAL_WORDS = 2**N * NT;
    logic [B-1:0] actual[];
    logic [B-1:0] expected[];
    
    expected = new[TOTAL_WORDS];
    for (int i = 0; i < TOTAL_WORDS; i++) begin
        expected[i] = get_expected_data(i);
    end
    
    // Assert start_reg and keep it high
    start_reader();
    
    // Read all data while start_reg is still high
    read_all_data(TOTAL_WORDS, actual);
    
    // Stop the reader after completion
    stop_reader();
    
    verify_data(expected, actual, "tc05_start_reg_level_sensitive");
`SVTEST_END

// -----------------------------------------------------------------------------
// TEST 06: Start_reg ignored when already active
// -----------------------------------------------------------------------------
`SVTEST(tc06_concurrent_start_ignored)
    localparam int TOTAL_WORDS = 2**N * NT;
    logic [B-1:0] actual[];
    logic [B-1:0] expected[];
    
    expected = new[TOTAL_WORDS];
    for (int i = 0; i < TOTAL_WORDS; i++) begin
        expected[i] = get_expected_data(i);
    end
    
    start_reader();
    
    // Try to start another transfer while active
    repeat(2) @(posedge tb_clk);
    tb_start_reg <= 1'b1;  // This should be ignored
    @(posedge tb_clk);
    
    // Read all data (should be first transfer, not a new one)
    read_all_data(TOTAL_WORDS, actual);
    stop_reader();
    
    verify_data(expected, actual, "tc06_concurrent_start_ignored");
`SVTEST_END

// -----------------------------------------------------------------------------
// TEST 07: Custom BRAM data write and read
// -----------------------------------------------------------------------------
`SVTEST(tc07_custom_bram_data)
    localparam int TOTAL_WORDS = 2**N * NT;
    logic [B-1:0] actual[];
    logic [B-1:0] expected[];
    
    // Write custom pattern to BRAM
    for (int addr = 0; addr < 2**N; addr++) begin
        for (int ch = 0; ch < NT; ch++) begin
            write_bram(addr, ch, (addr * NT + ch) * 2 + 1);
        end
    end
    
    // Build expected data
    expected = new[TOTAL_WORDS];
    for (int i = 0; i < TOTAL_WORDS; i++) begin
        expected[i] = get_expected_data(i);
    end
    
    // Read and verify
    do_transfer(TOTAL_WORDS, actual, 100000);
    verify_data(expected, actual, "tc07_custom_bram_data");
`SVTEST_END

// -----------------------------------------------------------------------------
// TEST 08: Start without reading (just test FSM)
// -----------------------------------------------------------------------------
`SVTEST(tc08_start_without_reading)
    // Just start and stop without reading
    start_reader();
    repeat(10) @(posedge tb_clk);
    stop_reader();
    
    // Should be back in INIT_ST (no easy way to check, but no error is good)
`SVTEST_END

// -----------------------------------------------------------------------------
// TEST 09: Slow read - tready low most of the time
// -----------------------------------------------------------------------------
`SVTEST(tc09_slow_read)
    localparam int TOTAL_WORDS = 2**N * NT;
    logic [B-1:0] actual[];
    logic [B-1:0] expected[];
    
    expected = new[TOTAL_WORDS];
    for (int i = 0; i < TOTAL_WORDS; i++) begin
        expected[i] = get_expected_data(i);
    end
    
    start_reader();
    actual = new[TOTAL_WORDS];
    
    for (int i = 0; i < TOTAL_WORDS; i++) begin
        // tready low most of the time
        set_tready(1'b0);
        repeat(5) @(posedge tb_clk);
        
        set_tready(1'b1);
        @(posedge tb_clk);
        while (!(tb_m_axis_tvalid && tb_m_axis_tready)) begin
            @(posedge tb_clk);
        end
        
        actual[i] = tb_m_axis_tdata;
        $display("[SLOW] word[%0d] = 0x%0h", i, actual[i]);
    end
    
    stop_reader();
    verify_data(expected, actual, "tc09_slow_read");
`SVTEST_END

// -----------------------------------------------------------------------------
// TEST 10: Verify channel order (channel 0 first, then channel 1, etc.)
// -----------------------------------------------------------------------------
`SVTEST(tc10_channel_order)
    localparam int DEPTH = 2**N;
    localparam int TOTAL_WORDS = DEPTH * NT;
    logic [B-1:0] actual[];
    logic [B-1:0] expected[];
    
    // Write unique pattern per channel: channel number in upper byte
    for (int ch = 0; ch < NT; ch++) begin
        for (int addr = 0; addr < DEPTH; addr++) begin
            write_bram(addr, ch, (ch << 8) | (addr & 8'hFF));
        end
    end
    
    // Build expected: all channels for addr 0, then addr 1, etc.
    expected = new[TOTAL_WORDS];
    for (int addr = 0; addr < DEPTH; addr++) begin
        for (int ch = 0; ch < NT; ch++) begin
            int idx = addr * NT + ch;
            expected[idx] = (ch << 8) | (addr & 8'hFF);
        end
    end
    
    do_transfer(TOTAL_WORDS, actual, 100000);
    
    // Verify channel order - channel 0 should come first for each address
    for (int addr = 0; addr < DEPTH; addr++) begin
        int base_idx = addr * NT;
        `FAIL_IF_LOG((actual[base_idx] & 16'hFF00) !== (0 << 8),
            $sformatf("Addr %0d: Expected channel 0 first, got channel %0d", 
            addr, (actual[base_idx] >> 8) & 16'hFF));
    end
    
    verify_data(expected, actual, "tc10_channel_order");
`SVTEST_END

// -----------------------------------------------------------------------------
// TEST 11: Full depth read with all channels
// -----------------------------------------------------------------------------
`SVTEST(tc11_full_depth_read)
    localparam int DEPTH = 2**N;
    localparam int TOTAL_WORDS = DEPTH * NT;
    logic [B-1:0] actual[];
    logic [B-1:0] expected[];
    
    // Write incrementing pattern
    for (int addr = 0; addr < DEPTH; addr++) begin
        for (int ch = 0; ch < NT; ch++) begin
            write_bram(addr, ch, addr * NT + ch);
        end
    end
    
    expected = new[TOTAL_WORDS];
    for (int i = 0; i < TOTAL_WORDS; i++) begin
        expected[i] = i;
    end
    
    do_transfer(TOTAL_WORDS, actual, 100000);
    verify_data(expected, actual, "tc11_full_depth_read");
`SVTEST_END