// ============================================================================
// File: dmem_single_rw_tests.sv
// Description: SVUnit test cases for dmem_single_rw.
// Included by dmem_single_rw_tc00.sv.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 01: Reset — idle outputs, no ack, FSM in INIT_ST
// ----------------------------------------------------------------------------
`SVTEST(test_reset_idle)
    repeat(5) @(tb_cb);
    `FAIL_IF(tb_exec_ack_o);
    `FAIL_IF(bram_if_i.en);
    `FAIL_IF(bram_if_i.we);
    `FAIL_IF(u_dut.state !== INIT_ST);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: No exec — FSM stays in INIT_ST, no BRAM activity
// ----------------------------------------------------------------------------
`SVTEST(test_idle_no_exec)
    tb_cb.tb_addr_i <= N'(10'h055);
    tb_cb.tb_din_i  <= B'(16'hCAFE);
    repeat(10) @(tb_cb);
    `FAIL_IF(u_dut.state !== INIT_ST);
    `FAIL_IF(tb_exec_ack_o);
    `FAIL_IF(bram_if_i.en);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Single write — data written to BRAM, ack asserted
// ----------------------------------------------------------------------------
`SVTEST(test_single_write)
    do_write(N'(10'h010), B'(16'hA5A5));
    // BRAM model should hold the written value
    verify_word(B'(16'hA5A5), mem[10'h010], "test_single_write");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: Single read — data read back matches BRAM content
// ----------------------------------------------------------------------------
`SVTEST(test_single_read)
    logic [B-1:0] rdata;
    // Preload BRAM model
    mem[10'h020] = B'(16'h1234);
    do_read(N'(10'h020), rdata);
    verify_word(B'(16'h1234), rdata, "test_single_read");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: Write then read back same address — data integrity round trip
// ----------------------------------------------------------------------------
`SVTEST(test_write_then_read)
    logic [B-1:0] rdata;
    do_write(N'(10'h0FF), B'(16'hBEEF));
    do_read (N'(10'h0FF), rdata);
    verify_word(B'(16'hBEEF), rdata, "test_write_then_read");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: Back-to-back transactions — handshake returns to idle each time
// ----------------------------------------------------------------------------
`SVTEST(test_back_to_back)
    logic [B-1:0] rdata;
    do_write(N'(10'h001), B'(16'hDEAD));
    do_write(N'(10'h002), B'(16'h0BAD));
    do_read (N'(10'h001), rdata);
    verify_word(B'(16'hDEAD), rdata, "test_back_to_back addr 0x001");
    do_read (N'(10'h002), rdata);
    verify_word(B'(16'h0BAD), rdata, "test_back_to_back addr 0x002");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: exec_ack handshake — ack asserts then clears after exec deasserted
// ----------------------------------------------------------------------------
`SVTEST(test_ack_handshake)
    @(tb_cb);
    tb_cb.tb_rw_i   <= 1'b1;
    tb_cb.tb_addr_i <= N'(10'h003);
    tb_cb.tb_din_i  <= B'(16'h5555);
    tb_cb.tb_exec_i <= 1'b1;
    wait_ack();
    `FAIL_IF(!tb_exec_ack_o);          // ack must be high in ACK_ST
    // Deassert exec → DUT must return to INIT and drop ack
    @(tb_cb);
    tb_cb.tb_exec_i <= 1'b0;
    repeat(2) @(tb_cb);
    `FAIL_IF(tb_exec_ack_o);           // ack cleared
    `FAIL_IF(u_dut.state !== INIT_ST); // back to idle
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: ACK held while exec stays asserted — no premature return to idle
// ----------------------------------------------------------------------------
`SVTEST(test_ack_held_while_exec_high)
    @(tb_cb);
    tb_cb.tb_rw_i   <= 1'b1;
    tb_cb.tb_addr_i <= N'(10'h004);
    tb_cb.tb_din_i  <= B'(16'h9999);
    tb_cb.tb_exec_i <= 1'b1;
    wait_ack();
    // Keep exec high — DUT must stay in ACK_ST and hold ack
    repeat(8) @(tb_cb) begin
        `FAIL_IF(!tb_exec_ack_o);
        `FAIL_IF(u_dut.state !== ACK_ST);
    end
    @(tb_cb);
    tb_cb.tb_exec_i <= 1'b0;
    repeat(2) @(tb_cb);
    `FAIL_IF(u_dut.state !== INIT_ST);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 09: Write asserts bram.we / byte-enables; read keeps we low
// ----------------------------------------------------------------------------
`SVTEST(test_write_drives_we)
    int we_seen = 0;
    @(tb_cb);
    tb_cb.tb_rw_i   <= 1'b1;     // write
    tb_cb.tb_addr_i <= N'(10'h008);
    tb_cb.tb_din_i  <= B'(16'h0F0F);
    tb_cb.tb_exec_i <= 1'b1;
    // During WRITE_ST, en & we & we_be should be asserted at least once
    fork
        begin
            repeat(8) @(posedge tb_clk) begin
                if (bram_if_i.en && bram_if_i.we) begin
                    we_seen++;
                    `FAIL_IF(bram_if_i.we_be !== '1); // all byte-enables high
                end
            end
        end
        wait_ack();
    join_any
    disable fork;
    @(tb_cb);
    tb_cb.tb_exec_i <= 1'b0;
    repeat(2) @(tb_cb);
    `FAIL_IF(we_seen == 0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 10: Read never asserts we — and drives byte-enables low
// ----------------------------------------------------------------------------
`SVTEST(test_read_never_writes)
    int we_during_read = 0;
    mem[10'h00A] = B'(16'h7777);
    @(tb_cb);
    tb_cb.tb_rw_i   <= 1'b0;     // read
    tb_cb.tb_addr_i <= N'(10'h00A);
    tb_cb.tb_exec_i <= 1'b1;
    fork
        begin
            repeat(8) @(posedge tb_clk) begin
                if (bram_if_i.we) we_during_read++;
            end
        end
        wait_ack();
    join_any
    disable fork;
    @(tb_cb);
    tb_cb.tb_exec_i <= 1'b0;
    repeat(2) @(tb_cb);
    `FAIL_IF(we_during_read > 0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 11: Read pipeline — FSM walks INIT→READ0→READ1→ACK
// ----------------------------------------------------------------------------
`SVTEST(test_read_fsm_sequence)
    mem[10'h00C] = B'(16'hABCD);
    @(tb_cb);
    tb_cb.tb_rw_i   <= 1'b0;     // read
    tb_cb.tb_addr_i <= N'(10'h00C);
    tb_cb.tb_exec_i <= 1'b1;
    // Next cycles: READ0 → READ1 → ACK
    @(posedge tb_clk); #1;
    `FAIL_IF(u_dut.state !== READ0_ST);
    @(posedge tb_clk); #1;
    `FAIL_IF(u_dut.state !== READ1_ST);
    @(posedge tb_clk); #1;
    `FAIL_IF(u_dut.state !== ACK_ST);
    `FAIL_IF(!tb_exec_ack_o);
    verify_word(B'(16'hABCD), tb_do_o, "test_read_fsm_sequence");
    @(tb_cb);
    tb_cb.tb_exec_i <= 1'b0;
    repeat(2) @(tb_cb);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 12: Write pipeline — FSM walks INIT→WRITE→ACK (single write cycle)
// ----------------------------------------------------------------------------
`SVTEST(test_write_fsm_sequence)
    @(tb_cb);
    tb_cb.tb_rw_i   <= 1'b1;     // write
    tb_cb.tb_addr_i <= N'(10'h00D);
    tb_cb.tb_din_i  <= B'(16'hF00D);
    tb_cb.tb_exec_i <= 1'b1;
    @(posedge tb_clk); #1;
    `FAIL_IF(u_dut.state !== WRITE_ST);
    @(posedge tb_clk); #1;
    `FAIL_IF(u_dut.state !== ACK_ST);
    `FAIL_IF(!tb_exec_ack_o);
    @(tb_cb);
    tb_cb.tb_exec_i <= 1'b0;
    repeat(2) @(tb_cb);
    verify_word(B'(16'hF00D), mem[10'h00D], "test_write_fsm_sequence");
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 13: Boundary addresses — first (0x000) and last (DEPTH-1)
// ----------------------------------------------------------------------------
`SVTEST(test_boundary_addresses)
    logic [B-1:0] rdata;
    do_write(N'(0),         B'(16'h0001));
    do_write(N'(DEPTH-1),   B'(16'hFFFE));
    do_read (N'(0),         rdata);
    verify_word(B'(16'h0001), rdata, "test_boundary addr 0");
    do_read (N'(DEPTH-1),   rdata);
    verify_word(B'(16'hFFFE), rdata, "test_boundary addr DEPTH-1");
`SVTEST_END