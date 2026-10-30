//------------------------------------------------------------------------------
// Test cases for regfile_8p
//------------------------------------------------------------------------------

// test00: Reset state – all outputs must be zero
`SVTEST(test00_reset_state)
    `FAIL_IF_LOG($isunknown(tb_dout0), "dout0 X/Z after reset");
    `FAIL_IF_LOG($isunknown(tb_dout1), "dout1 X/Z after reset");
    `FAIL_IF_LOG($isunknown(tb_dout2), "dout2 X/Z after reset");
    `FAIL_IF_LOG($isunknown(tb_dout3), "dout3 X/Z after reset");
    `FAIL_IF_LOG($isunknown(tb_dout4), "dout4 X/Z after reset");
    `FAIL_IF_LOG($isunknown(tb_dout5), "dout5 X/Z after reset");
    `FAIL_IF_LOG($isunknown(tb_dout6), "dout6 X/Z after reset");

    `FAIL_UNLESS_LOG(tb_dout0 == 0, "dout0 should be 0 after reset");
    `FAIL_UNLESS_LOG(tb_dout1 == 0, "dout1 should be 0 after reset");
    `FAIL_UNLESS_LOG(tb_dout2 == 0, "dout2 should be 0 after reset");
    `FAIL_UNLESS_LOG(tb_dout3 == 0, "dout3 should be 0 after reset");
    `FAIL_UNLESS_LOG(tb_dout4 == 0, "dout4 should be 0 after reset");
    `FAIL_UNLESS_LOG(tb_dout5 == 0, "dout5 should be 0 after reset");
    `FAIL_UNLESS_LOG(tb_dout6 == 0, "dout6 should be 0 after reset");
`SVTEST_END

//------------------------------------------------------------------------------
// test01: Write and read back (single page, addr != 0)
//------------------------------------------------------------------------------
`SVTEST(test01_write_read)
    logic [B-1:0] read_data;
    logic [B-1:0] test_data = 16'hA5A5;

    write_reg(0, 5, test_data);
    read_reg0(0, 5, read_data);
    `FAIL_UNLESS_LOG(read_data == test_data,
        $sformatf("Write/read mismatch: expected 0x%h, got 0x%h", test_data, read_data));
`SVTEST_END

// test02: Register 0 always reads zero (even after write)
`SVTEST(test02_reg0_zero)
    logic [B-1:0] read_data;

    // Write to register 0 of page 0
    write_reg(0, 0, 16'hDEAD);
    // Read back register 0
    read_reg0(0, 0, read_data);
    `FAIL_UNLESS_LOG(read_data == 0,
        $sformatf("Register 0 should always read 0, got 0x%h", read_data));
`SVTEST_END

//------------------------------------------------------------------------------
// test03: Page selection – write to one page, read from another
//------------------------------------------------------------------------------
`SVTEST(test03_page_selection)
    logic [B-1:0] data_a = 16'h1234;
    logic [B-1:0] data_b = 16'h5678;
    logic [B-1:0] read_a, read_b;

    // Write to page 0, register 1
    write_reg(0, 1, data_a);
    // Write to page 1, register 1
    write_reg(1, 1, data_b);

    // Read from page 0
    read_reg0(0, 1, read_a);
    `FAIL_UNLESS_LOG(read_a == data_a,
        $sformatf("Page 0 read mismatch: expected 0x%h, got 0x%h", data_a, read_a));

    // Read from page 1
    read_reg0(1, 1, read_b);
    `FAIL_UNLESS_LOG(read_b == data_b,
        $sformatf("Page 1 read mismatch: expected 0x%h, got 0x%h", data_b, read_b));
`SVTEST_END

// test04: Write enable gating – only selected page gets written
`SVTEST(test04_write_gating)
    logic [B-1:0] data = 16'hCAFE;
    logic [B-1:0] read_0, read_1;

    // Pre-initialize reg 2 of page 1 to a known value (0) explicitly,
    // since regfile has no reset and mem[] starts as X in simulation.
    write_reg(1, 2, 16'h0000);

    // Write to page 0, register 2
    write_reg(0, 2, data);

    // Read from page 1, same register – should still be 0
    read_reg0(1, 2, read_1);
    `FAIL_UNLESS_LOG(read_1 == 0,
        $sformatf("Page 1 should not receive write, got 0x%h", read_1));
`SVTEST_END

// test05: Read latency – data appears one cycle after address
`SVTEST(test05_read_latency)
    logic [B-1:0] data = 16'hBEEF;
    logic [B-1:0] read_data;

    // Initialize reg 10 page 0 to 0 first (no HW reset on regfile mem[])
    write_reg(0, 10, 16'h0000);

    // Verify reg 10 reads 0 before writing the real value
    cb.tb_pnum  <= 0;
    cb.tb_addr0 <= 10;
    @(cb);
    @(cb);  // 2-cycle latency
    `FAIL_UNLESS_LOG(tb_dout0 == 0,
        "Before write, dout0 should be 0 (initialized value)");

    // Now write the real value and verify read-back
    write_reg(0, 10, data);
    read_reg0(0, 10, read_data);
    `FAIL_UNLESS_LOG(read_data == data,
        $sformatf("Read latency test: expected 0x%h, got 0x%h", data, read_data));
`SVTEST_END

//------------------------------------------------------------------------------
// test06: Concurrent read ports (all 7 ports read from different registers)
//------------------------------------------------------------------------------
`SVTEST(test06_concurrent_reads)
    logic [B-1:0] data0 = 16'h1111, data1 = 16'h2222;
    logic [B-1:0] data2 = 16'h3333, data3 = 16'h4444;
    logic [B-1:0] data4 = 16'h5555, data5 = 16'h6666;
    logic [B-1:0] data6 = 16'h7777;
    logic [B-1:0] r0, r1, r2, r3, r4, r5, r6;

    // Write to registers 1..7 in page 0
    write_reg(0, 1, data0);
    write_reg(0, 2, data1);
    write_reg(0, 3, data2);
    write_reg(0, 4, data3);
    write_reg(0, 5, data4);
    write_reg(0, 6, data5);
    write_reg(0, 7, data6);

    // Read all 7 ports in one go
    read_all_ports(0, 1, 2, 3, 4, 5, 6, 7, r0, r1, r2, r3, r4, r5, r6);

    `FAIL_UNLESS_LOG(r0 == data0, "dout0 mismatch");
    `FAIL_UNLESS_LOG(r1 == data1, "dout1 mismatch");
    `FAIL_UNLESS_LOG(r2 == data2, "dout2 mismatch");
    `FAIL_UNLESS_LOG(r3 == data3, "dout3 mismatch");
    `FAIL_UNLESS_LOG(r4 == data4, "dout4 mismatch");
    `FAIL_UNLESS_LOG(r5 == data5, "dout5 mismatch");
    `FAIL_UNLESS_LOG(r6 == data6, "dout6 mismatch");
`SVTEST_END
