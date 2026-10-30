//-------------------------------------------------------------------------------------------------//
`SVTEST(test00_reset)
  // Out of reset, nothing in flight: not busy, no spurious valid.
  repeat (10) @(src_cb);
  `FAIL_IF(tb_o_busy != 1'b0);
  `FAIL_IF(tb_o_valid != 1'b0);
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_single_transfer)
  send_and_wait(8'hA5);
  `FAIL_IF(tb_o_data != 8'hA5);
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_busy_asserts_while_in_flight)
  @(src_cb);
  src_cb.tb_i_data  <= 8'h3C;
  src_cb.tb_i_valid <= 1'b1;
  @(src_cb);
  src_cb.tb_i_valid <= 1'b0;

  // o_busy must be observable asserted immediately after the request
  `FAIL_IF(tb_o_busy != 1'b1);

  // ... and must clear again once the transfer completes.
  fork
    begin : wait_dst
      int timeout;
      timeout = 0;
      do begin
        @(dst_cb);
        timeout++;
        if (timeout > 200) `FAIL_IF_LOG(1, "timed out waiting for o_valid");
      end while (!dst_cb.tb_o_valid);
    end
  join

  repeat(20) @(src_cb);
  `FAIL_IF(tb_o_busy != 1'b0);
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
`SVTEST(test03_sequential_transfers)
  logic [DW-1:0] words [4] = '{8'h11, 8'h22, 8'h33, 8'h44};

  for (int i = 0; i < 4; i++) begin
    send_and_wait(words[i]);
    `FAIL_IF(tb_o_data != words[i]);
  end
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
//-------------------------------------------------------------------------------------------------//
// ASYMMETRIC RESET (TESTBENCH_PATTERNS.md, "Both sides of a CDC need the same reset"). The two domains can be reset independently --
// in xcom_async the destination-side reset pulses on every RX link re-lock. Because a transfer is a
// toggle, a side that resets alone used to leave the two toggle bits disagreeing, which the other side
// read as a genuine request: one phantom o_valid, carrying all-zero data, per reset.
//
// Destination resets alone: the source is idle, so nothing at all should come out.
`SVTEST(test04_dst_reset_alone_produces_no_phantom_valid)
  int valids;
  // Settle, and get the toggles into the '1' state so a reset to 0 is a real change.
  send_and_wait(8'h5A);
  repeat(20) @(src_cb);

  valids = 0;
  fork
    begin : count_valids
      repeat(200) begin
        @(dst_cb);
        if (dst_cb.tb_o_valid) valids++;
      end
    end
    begin : pulse_dst_reset
      repeat(10) @(dst_cb);
      dst_cb.tb_o_rstn <= 1'b0;
      repeat(10) @(dst_cb);
      dst_cb.tb_o_rstn <= 1'b1;
    end
  join

  `FAIL_UNLESS_LOG(valids == 0,
      $sformatf("destination reset alone produced %0d phantom o_valid pulse(s)", valids));
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
// Source resets alone: again nothing should be delivered, and ack must not be left stale (if it were,
// the next transfer would complete instantly in the source's eyes).
`SVTEST(test05_src_reset_alone_produces_no_phantom_valid)
  int valids;
  send_and_wait(8'h5A);
  repeat(20) @(src_cb);

  valids = 0;
  fork
    begin : count_valids
      repeat(200) begin
        @(dst_cb);
        if (dst_cb.tb_o_valid) valids++;
      end
    end
    begin : pulse_src_reset
      repeat(10) @(src_cb);
      src_cb.tb_i_rstn <= 1'b0;
      repeat(10) @(src_cb);
      src_cb.tb_i_rstn <= 1'b1;
    end
  join

  `FAIL_UNLESS_LOG(valids == 0,
      $sformatf("source reset alone produced %0d phantom o_valid pulse(s)", valids));
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
// The link must still work after an independent reset of either side: this is what would break if the
// fix resynchronized the two sides by simply freezing one of them.
`SVTEST(test06_transfers_resume_after_an_asymmetric_reset)
  send_and_wait(8'h11);
  `FAIL_IF(tb_o_data != 8'h11);

  // Destination alone.
  repeat(5) @(dst_cb);
  dst_cb.tb_o_rstn <= 1'b0;
  repeat(10) @(dst_cb);
  dst_cb.tb_o_rstn <= 1'b1;
  repeat(20) @(dst_cb);

  send_and_wait(8'h22);
  `FAIL_UNLESS_LOG(tb_o_data == 8'h22,
      $sformatf("after a destination-only reset, got %h, expected 22", tb_o_data));

  // Source alone.
  repeat(5) @(src_cb);
  src_cb.tb_i_rstn <= 1'b0;
  repeat(10) @(src_cb);
  src_cb.tb_i_rstn <= 1'b1;
  repeat(20) @(src_cb);

  send_and_wait(8'h33);
  `FAIL_UNLESS_LOG(tb_o_data == 8'h33,
      $sformatf("after a source-only reset, got %h, expected 33", tb_o_data));

  // And o_busy is genuinely clear, not just reported clear by a stale ack.
  repeat(20) @(src_cb);
  `FAIL_IF(tb_o_busy != 1'b0);
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
// Bound of the protection above: the peer's reset is observed through a synchronizer, so a reset
// pulse too short to be sampled in the other domain cannot be seen at all. Here the DESTINATION is
// 3x slower than the source, so a 1-source-cycle reset is the pathological case. This test documents
// the behaviour rather than demanding a particular outcome -- what matters is that the module does
// not lock up, and that a normal (multi-cycle) reset, which is what real designs issue, is handled
// by test04/test05.
`SVTEST(test07_survives_a_reset_pulse_too_short_to_be_synchronized)
  send_and_wait(8'h5A);
  repeat(20) @(src_cb);

  // One source cycle of reset: far below the destination's sampling ability.
  @(src_cb);
  src_cb.tb_i_rstn <= 1'b0;
  @(src_cb);
  src_cb.tb_i_rstn <= 1'b1;
  repeat(40) @(src_cb);

  // Whatever happened on the wire, the link must still be usable afterwards.
  send_and_wait(8'h77);
  `FAIL_UNLESS_LOG(tb_o_data == 8'h77,
      $sformatf("after a sub-synchronizer reset pulse, got %h, expected 77", tb_o_data));
  repeat(20) @(src_cb);
  `FAIL_IF(tb_o_busy != 1'b0);
`SVTEST_END
