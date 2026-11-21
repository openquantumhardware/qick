// ============================================================================
// File: axis_to_bram_sg_nt_tests.sv
// Description: SVUnit test cases for axis_to_bram_sg_nt.
// Included by axis_to_bram_sg_nt_tc00.sv.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Reset — no writes, tready low, mem_en all zero
// ----------------------------------------------------------------------------
`SVTEST(test_reset_no_write)
    repeat(5) @(tb_cb);
    `FAIL_IF(bram_if_i.we);
    `FAIL_IF(axis_if.tready);
    `FAIL_IF(tb_mem_en !== '0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: capture_reg=0 — tready never asserts
// ----------------------------------------------------------------------------
`SVTEST(test_idle_no_tready)
    tb_cb.tb_capture_reg <= 1'b0;
    repeat(10) @(tb_cb);
    `FAIL_IF(axis_if.tready);
    `FAIL_IF(bram_if_i.we);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Enable writer — tready asserts after WAIT_TVALID_ST
// ----------------------------------------------------------------------------
`SVTEST(test_enable_asserts_tready)
    enable_writer(32'd0);
    repeat(2) @(tb_cb);
    `FAIL_IF(!axis_if.tready);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: mem_en one-hot — exactly one table enabled per write
// Starting at flat_addr=0: writes cycle through tables 0,1,2,3,0,1,...
// ----------------------------------------------------------------------------
`SVTEST(test_mem_en_one_hot)
    int total = NT * 2;

    enable_writer(32'd0);

    fork
        stream_data(total, B'(16'h0001));
        begin
            for (int i = 0; i < total; i++) begin
                @(posedge tb_clk iff bram_if_i.we);
                // Exactly one bit set
                begin
                    int bit_count = 0;
                    for (int b = 0; b < NT; b++)
                        if (tb_mem_en[b]) bit_count++;
                    if (bit_count !== 1) begin
                        $display("[FAIL] test_mem_en_one_hot: write[%0d] en=0b%0b has %0d bits",
                                 i, tb_mem_en, bit_count);
                        `FAIL_IF(1);
                    end
                end
            end
        end
    join
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: Table rotation — consecutive writes cycle 0→NT-1
// Flat addr 0 → table 0, flat addr 1 → table 1, ...
// ----------------------------------------------------------------------------
`SVTEST(test_table_rotation)
    enable_writer(32'd0);

    fork
        stream_data(NT, B'(16'h0001));
        begin
            for (int i = 0; i < NT; i++) begin
                @(posedge tb_clk iff bram_if_i.we);
                begin
                    logic [NT-1:0] expected_en = NT'(1 << i);
                    if (tb_mem_en !== expected_en) begin
                        $display("[FAIL] test_table_rotation: write[%0d] en=0b%0b expected 0b%0b",
                                 i, tb_mem_en, expected_en);
                        `FAIL_IF(1);
                    end
                end
            end
        end
    join
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: bram.addr increments every NT writes
// Writes 0..NT-1 → bram.addr = start_high
// Writes NT..2*NT-1 → bram.addr = start_high + 1
// ----------------------------------------------------------------------------
`SVTEST(test_bram_addr_increment)
    localparam int START_HIGH = 2;  // start flat = START_HIGH * NT
    int total = NT * 3;

    enable_writer(32'(START_HIGH * NT));

    fork
        stream_data(total, B'(16'h0001));
        begin
            for (int i = 0; i < total; i++) begin
                @(posedge tb_clk iff bram_if_i.we);
                begin
                    logic [N-1:0] expected_addr = N'(START_HIGH + i/NT);
                    if (bram_if_i.addr !== expected_addr) begin
                        $display("[FAIL] test_bram_addr_increment: write[%0d] addr=0x%0h expected 0x%0h",
                                 i, bram_if_i.addr, expected_addr);
                        `FAIL_IF(1);
                    end
                end
            end
        end
    join
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: Data integrity — mem data matches sent data in order
// ----------------------------------------------------------------------------
`SVTEST(test_data_integrity)
    localparam int COUNT = NT * 2;

    enable_writer(32'd0);
    stream_data(COUNT, B'(16'h0100));
    wait_pipeline();

    verify_block(0, COUNT, B'(16'h0100), "test_data_integrity");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: Start address alignment — non-zero start_addr offsets
// start_flat = NT+1 → first write: table=1, row=1
// ----------------------------------------------------------------------------
`SVTEST(test_start_addr_alignment)
    localparam int START = NT + 1;

    enable_writer(32'(START));
    stream_data(1, B'(16'hFACE));
    wait_pipeline();

    verify_flat(START, B'(16'hFACE), "test_start_addr_alignment");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 09: Disable stops writes, mem_en deasserts
// ----------------------------------------------------------------------------
`SVTEST(test_disable_stops_writes)
    int writes_after = 0;

    enable_writer(32'd0);
    stream_data(3, B'(16'h0001));
    disable_writer();

    for (int i = 0; i < 10; i++) begin
        @(tb_cb);
        if (bram_if_i.we) writes_after++;
    end

    `FAIL_IF(writes_after > 0);
    `FAIL_IF(tb_mem_en !== '0);
    `FAIL_IF(axis_if.tready);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 10: Reset during operation — writes stop
// ----------------------------------------------------------------------------
`SVTEST(test_reset_during_operation)
    int writes_after_reset = 0;

    enable_writer(32'd0);

    axis_if.m_cb.tvalid <= 1'b1;
    axis_if.m_cb.tdata  <= B'(16'h1234);
    repeat(3) @(tb_cb);

    tb_cb.tb_capture_reg <= 1'b0;
    tb_cb.tb_rstn        <= 1'b0;
    axis_if.m_cb.tvalid  <= 1'b0;
    repeat(5) @(tb_cb);
    tb_cb.tb_rstn <= 1'b1;
    repeat(10) @(tb_cb);

    for (int i = 0; i < 5; i++) begin
        @(tb_cb);
        if (bram_if_i.we) writes_after_reset++;
    end

    `FAIL_IF(writes_after_reset > 0);
    `FAIL_IF(axis_if.tready);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 11: bram.en always asserted
// ----------------------------------------------------------------------------
`SVTEST(test_bram_en_always_asserted)
    `FAIL_IF(!bram_if_i.en);
    enable_writer(32'd0);
    `FAIL_IF(!bram_if_i.en);
    stream_data(2, B'(1));
    `FAIL_IF(!bram_if_i.en);
    disable_writer();
    `FAIL_IF(!bram_if_i.en);
`SVTEST_END
