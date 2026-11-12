// =========================================================================
// test00_reset
// After reset: empty must be asserted, full must be deasserted.
// Pointers are zero so wptr == rptr -> empty=1, full=0.
// =========================================================================
`SVTEST(test00_reset)

  `ASSERT_IMMEDIATE(tb_empty == 1'b1);
  `ASSERT_IMMEDIATE(tb_full  == 1'b0);

  // Assert reset mid-test and re-check
  cb.tb_rstn <= 1'b0;
  repeat(2) @(cb);
  `ASSERT_IMMEDIATE(tb_empty == 1'b1);
  `ASSERT_IMMEDIATE(tb_full  == 1'b0);

  cb.tb_rstn <= 1'b1;
  repeat(3) @(cb);

`SVTEST_END

// =========================================================================
// test01_empty_flag
// Verify empty is asserted after reset and deasserted after one write.
// =========================================================================
`SVTEST(test01_empty_flag)

  `ASSERT_IMMEDIATE(tb_empty == 1'b1);

  write_word(16'hABCD);

  `ASSERT_IMMEDIATE(tb_empty == 1'b0);

`SVTEST_END

// =========================================================================
// test02_full_flag
// Fill the FIFO to capacity and verify full is asserted.
// Then verify that writing when full is ignored (wptr does not advance).
// =========================================================================
`SVTEST(test02_full_flag)

  fill_fifo(16'h1000);

  `ASSERT_IMMEDIATE(tb_full == 1'b1);

  // Attempt to write when full — should be ignored
  cb.tb_din   <= 16'hDEAD;
  cb.tb_wr_en <= 1'b1;
  @(cb);
  cb.tb_wr_en <= 1'b0;
  @(cb);

  // Still full, no overflow
  `ASSERT_IMMEDIATE(tb_full == 1'b1);

`SVTEST_END

// =========================================================================
// test03_single_write_read
// Write one word, read it back and verify data integrity.
// Account for 1-cycle BRAM read latency.
// =========================================================================
`SVTEST(test03_single_write_read)

  logic [B-1:0] rdata;

  write_word(16'hCAFE);
  read_word(rdata);

  `FAIL_UNLESS_EQUAL(rdata, 16'hCAFE);
  `ASSERT_IMMEDIATE(tb_empty == 1'b1);

`SVTEST_END

// =========================================================================
// test04_fifo_order
// Fill to capacity (N-1 words) and read them back in order.
// =========================================================================
`SVTEST(test04_fifo_order)
  logic [B-1:0] out_data[$];

  fill_fifo(16'hB000);
  `ASSERT_IMMEDIATE(tb_full == 1'b1);

  read_n_words(CAP, out_data);

  `FAIL_UNLESS_EQUAL(out_data.size(), CAP);
  for (int k = 0; k < CAP; k++)
    `FAIL_UNLESS_EQUAL(out_data[k], 16'hB000 + B'(k));

  `ASSERT_IMMEDIATE(tb_empty == 1'b1);
`SVTEST_END

// =========================================================================
// test05_write_ignored_when_full
// Verify the FIFO content is not corrupted when a write is attempted
// while full — the extra word must not appear on readout.
// =========================================================================
`SVTEST(test05_write_ignored_when_full)
  logic [B-1:0] out_data[$];

  fill_fifo(16'hC000);
  `ASSERT_IMMEDIATE(tb_full == 1'b1);

  write_word(16'hDEAD); // ignored

  read_n_words(CAP, out_data);

  `FAIL_UNLESS_EQUAL(out_data.size(), CAP);
  for (int k = 0; k < CAP; k++)
    `FAIL_UNLESS_EQUAL(out_data[k], 16'hC000 + B'(k));

  `ASSERT_IMMEDIATE(tb_empty == 1'b1);
`SVTEST_END

// =========================================================================
// test06_read_ignored_when_empty
// Verify rptr does not advance when rd_en is asserted on an empty FIFO.
// After one write, the data must still be readable.
// =========================================================================
`SVTEST(test06_read_ignored_when_empty)

  logic [B-1:0] rdata;

  `ASSERT_IMMEDIATE(tb_empty == 1'b1);

  // Attempt read on empty FIFO — should be ignored
  cb.tb_rd_en <= 1'b1;
  @(cb);
  cb.tb_rd_en <= 1'b0;
  repeat(2) @(cb);

  // Still empty
  `ASSERT_IMMEDIATE(tb_empty == 1'b1);

  // Write and read — data must be correct (rptr not corrupted)
  write_word(16'hF00D);
  read_word(rdata);
  `FAIL_UNLESS_EQUAL(rdata, 16'hF00D);

`SVTEST_END

// =========================================================================
// test07_simultaneous_write_read
// With a non-empty, non-full FIFO: assert both wr_en and rd_en
// simultaneously. Verify that count stays the same and data is correct.
// =========================================================================
`SVTEST(test07_simultaneous_write_read)

  logic [B-1:0] rdata;

  // Pre-load two words
  write_word(16'h0001);
  write_word(16'h0002);

  // Simultaneous write and read
  cb.tb_din   <= 16'h0003;
  cb.tb_wr_en <= 1'b1;
  cb.tb_rd_en <= 1'b1;
  @(cb);
  cb.tb_wr_en <= 1'b0;
  cb.tb_rd_en <= 1'b0;
  @(cb); // BRAM read latency
  rdata = tb_dout;

  // First word out must be 0x0001
  `FAIL_UNLESS_EQUAL(rdata, 16'h0001);

  // Read remaining words: 0x0002, 0x0003
  read_word(rdata);
  `FAIL_UNLESS_EQUAL(rdata, 16'h0002);

  read_word(rdata);
  `FAIL_UNLESS_EQUAL(rdata, 16'h0003);

  `ASSERT_IMMEDIATE(tb_empty == 1'b1);

`SVTEST_END

// =========================================================================
// test08_fill_drain_fill
// Fill, drain, and fill again — verify the FIFO resets its pointers
// correctly and behaves identically on the second fill.
// =========================================================================
`SVTEST(test08_fill_drain_fill)
  logic [B-1:0] out_data[$];

  // First fill and drain
  fill_fifo(16'hA000);
  read_n_words(N, out_data);
  `ASSERT_IMMEDIATE(tb_empty == 1'b1);

  // Second fill with different data
  fill_fifo(16'hE000);
  `ASSERT_IMMEDIATE(tb_full == 1'b1);

  read_n_words(CAP, out_data);
  `FAIL_UNLESS_EQUAL(out_data.size(), CAP);
  for (int k = 0; k < CAP; k++)
    `FAIL_UNLESS_EQUAL(out_data[k], 16'hE000 + B'(k));

  `ASSERT_IMMEDIATE(tb_empty == 1'b1);
`SVTEST_END

// =========================================================================
// test09_pointer_wraparound
// Write and read more than N words to exercise pointer wraparound.
// Verify data integrity across the wrap boundary.
// =========================================================================
`SVTEST(test09_pointer_wraparound)

  logic [B-1:0] rdata;
  int           total = N * 3; // 3x the FIFO depth

  for (int k = 0; k < total; k++) begin
    write_word(B'(16'hD000 + k));
    read_word(rdata);
    `FAIL_UNLESS_EQUAL(rdata, B'(16'hD000 + k));
  end

  `ASSERT_IMMEDIATE(tb_empty == 1'b1);

`SVTEST_END
