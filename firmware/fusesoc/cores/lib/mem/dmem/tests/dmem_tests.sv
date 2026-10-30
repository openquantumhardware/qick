// ============================================================================
// File: dmem_tests.sv
// Description: SVUnit integration test cases for dmem.
// Included by dmem_tc00.sv.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Reset — idle, not busy, no exec_ack
// ----------------------------------------------------------------------------
`SVTEST(test_reset_idle)
    repeat(5) @(tb_cb);
    `FAIL_IF(tb_busy_o);
    `FAIL_IF(tb_exec_ack_o);
    `FAIL_IF(tb_mem_we);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Single write then single read (processor path, sel=0)
// ----------------------------------------------------------------------------
`SVTEST(test_single_write_read)
    logic [B-1:0] rdata;
    single_write(N'(10'h010), B'(32'hDEADBEEF));
    `FAIL_IF(mem[10'h010] !== 32'hDEADBEEF);   // landed in BRAM
    single_read(N'(10'h010), rdata);
    if (rdata !== 32'hDEADBEEF) begin
        $display("MISMATCH single rw: exp 0x%0h got 0x%0h", 32'hDEADBEEF, rdata);
        `FAIL_IF(1);
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: busy_o low during single access (not locked out)
// ----------------------------------------------------------------------------
`SVTEST(test_busy_low_single_access)
    logic [B-1:0] rdata;
    `FAIL_IF(tb_busy_o);
    single_write(N'(0), B'(32'h12345678));
    `FAIL_IF(tb_busy_o);                        // single access never sets busy
    single_read(N'(0), rdata);
    `FAIL_IF(tb_busy_o);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: AXIS write — burst lands in BRAM at addr_reg
// ----------------------------------------------------------------------------
`SVTEST(test_axis_write)
    localparam int LEN = 8;
    axis_write(N'(10'h020), LEN, B'(32'h1000));
    verify_mem(10'h020, LEN, B'(32'h1000), "test_axis_write");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: AXIS read — burst streamed out matches preloaded BRAM
// ----------------------------------------------------------------------------
`SVTEST(test_axis_read)
    localparam int LEN = 8;
    logic [B-1:0] expected [];
    logic [B-1:0] actual [];
    logic         saw_tlast;
    // Preload via BRAM model directly
    for (int i = 0; i < LEN; i++) mem[10'h040 + i] = 32'h2000 + B'(i);
    expected = new[LEN];
    for (int i = 0; i < LEN; i++) expected[i] = 32'h2000 + B'(i);
    axis_read(N'(10'h040), LEN, actual, saw_tlast);
    verify_data(expected, actual, "test_axis_read");
    `FAIL_IF(!saw_tlast);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: End-to-end — AXIS write then AXIS read back same region
// ----------------------------------------------------------------------------
`SVTEST(test_axis_write_then_read)
    localparam int LEN = 8;
    logic [B-1:0] expected [];
    logic [B-1:0] actual [];
    logic         saw_tlast;
    expected = new[LEN];
    for (int i = 0; i < LEN; i++) expected[i] = 32'hCAFE0000 + B'(i);
    // Write via AXIS
    axis_write(N'(10'h060), LEN, B'(32'hCAFE0000));
    // Read back via AXIS
    axis_read(N'(10'h060), LEN, actual, saw_tlast);
    verify_data(expected, actual, "test_axis_write_then_read");
    `FAIL_IF(!saw_tlast);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: busy_o asserted throughout AXIS write, released afterward
// ----------------------------------------------------------------------------
`SVTEST(test_busy_during_axis_write)
    localparam int LEN = 4;
    logic busy_during = 1'b0;
    tb_cb.tb_mode_reg  <= 1'b1;
    tb_cb.tb_addr_reg  <= N'(0);
    tb_cb.tb_start_reg <= 1'b1;
    do @(tb_cb); while (!tb_busy_o);
    fork
        begin
            while (tb_busy_o) begin
                busy_during = 1'b1;
                @(tb_cb);
            end
        end
        begin
            for (int i = 0; i < LEN; i++) begin
                s_axis_if.m_cb.tdata  <= B'(32'h9000) + B'(i);
                s_axis_if.m_cb.tlast  <= (i == LEN-1);
                s_axis_if.m_cb.tvalid <= 1'b1;
                do @(s_axis_if.m_cb); while (!s_axis_if.m_cb.tready);
            end
            s_axis_if.m_cb.tvalid <= 1'b0;
            s_axis_if.m_cb.tlast  <= 1'b0;
        end
    join
    `FAIL_IF(!busy_during);
    tb_cb.tb_start_reg <= 1'b0;
    repeat(3) @(tb_cb);
    `FAIL_IF(tb_busy_o);                        // released after transaction
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: Single access interleaved with AXIS transactions
// ----------------------------------------------------------------------------
`SVTEST(test_single_and_axis_interleaved)
    localparam int LEN = 4;
    logic [B-1:0] rdata;
    logic [B-1:0] expected [];
    logic [B-1:0] actual [];
    logic         saw_tlast;
    // 1. Single write
    single_write(N'(10'h008), B'(32'hAAAA5555));
    // 2. AXIS write at a different region
    axis_write(N'(10'h080), LEN, B'(32'hB000));
    verify_mem(10'h080, LEN, B'(32'hB000), "interleaved axis_write");
    // 3. Single read back the first location (must be intact)
    single_read(N'(10'h008), rdata);
    if (rdata !== 32'hAAAA5555) begin
        $display("MISMATCH interleaved single read: exp 0x%0h got 0x%0h",
                 32'hAAAA5555, rdata);
        `FAIL_IF(1);
    end
    // 4. AXIS read back the AXIS-written region
    expected = new[LEN];
    for (int i = 0; i < LEN; i++) expected[i] = 32'hB000 + B'(i);
    axis_read(N'(10'h080), LEN, actual, saw_tlast);
    verify_data(expected, actual, "interleaved axis_read");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 09: mode_reg selects path — write vs read mutually exclusive
// ----------------------------------------------------------------------------
`SVTEST(test_mode_reg_selects_path)
    localparam int LEN = 4;
    logic [B-1:0] expected [];
    logic [B-1:0] actual [];
    logic         saw_tlast;
    // MODE=1 -> write path
    axis_write(N'(10'h0A0), LEN, B'(32'hC000));
    verify_mem(10'h0A0, LEN, B'(32'hC000), "mode write");
    // MODE=0 -> read path
    expected = new[LEN];
    for (int i = 0; i < LEN; i++) expected[i] = 32'hC000 + B'(i);
    axis_read(N'(10'h0A0), LEN, actual, saw_tlast);
    verify_data(expected, actual, "mode read");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 10: Back-to-back AXIS transactions (re-arm via start_reg toggle)
// ----------------------------------------------------------------------------
`SVTEST(test_back_to_back_axis)
    localparam int LEN = 4;
    logic [B-1:0] expected [];
    logic [B-1:0] actual [];
    logic         saw_tlast;
    // First write
    axis_write(N'(0), LEN, B'(32'h1111));
    verify_mem(0, LEN, B'(32'h1111), "b2b write 1");
    // Second write at different address
    axis_write(N'(10'h0C0), LEN, B'(32'h2222));
    verify_mem(10'h0C0, LEN, B'(32'h2222), "b2b write 2");
    // Read back both
    expected = new[LEN];
    for (int i = 0; i < LEN; i++) expected[i] = 32'h1111 + B'(i);
    axis_read(N'(0), LEN, actual, saw_tlast);
    verify_data(expected, actual, "b2b read 1");
    expected = new[LEN];
    for (int i = 0; i < LEN; i++) expected[i] = 32'h2222 + B'(i);
    axis_read(N'(10'h0C0), LEN, actual, saw_tlast);
    verify_data(expected, actual, "b2b read 2");
`SVTEST_END