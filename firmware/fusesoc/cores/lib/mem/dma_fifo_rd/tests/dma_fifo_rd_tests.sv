// ============================================================================
// File: dma_fifo_rd_tests.sv
// Description: SVUnit test cases for dma_fifo_rd. Included by
//   dma_fifo_rd_tc00.sv.
// ============================================================================

`SVTEST(tc_basic_transfer)
   int beats[];
   bit ok;
   int i;

   run_transfer(5, beats, ok);
   `FAIL_IF_LOG(!ok, "transfer of 5 words never completed (tlast not seen)");
   `FAIL_UNLESS_LOG(beats.size() == 5, $sformatf("collected %0d beats, expected 5", beats.size()));
   for (i = 0; i < 5; i++)
      `FAIL_UNLESS_LOG(beats[i] === (32'hA000_0000 + i),
         $sformatf("beat %0d = 0x%08h, expected 0x%08h", i, beats[i], 32'hA000_0000 + i));
`SVTEST_END

`SVTEST(tc_single_word_transfer)
   int beats[];
   bit ok;

   // dma_len_i == 1 takes the ST_IDLE -> ST_LAST shortcut (skips ST_TXING
   // entirely) - a distinct path worth exercising on its own.
   run_transfer(1, beats, ok);
   `FAIL_IF_LOG(!ok, "single-word transfer never completed (tlast not seen)");
   `FAIL_UNLESS_LOG(beats.size() == 1, $sformatf("collected %0d beats, expected 1", beats.size()));
   `FAIL_UNLESS_LOG(beats[0] === 32'hA000_0000,
      $sformatf("beat 0 = 0x%08h, expected 0x%08h", beats[0], 32'hA000_0000));
`SVTEST_END

`SVTEST(tc_two_back_to_back_transfers)
   int beats[];
   bit ok;
   int i;

   // The source's word counter keeps advancing across transfers (it is
   // never reset between them, matching real hardware where the caller
   // decides dma_len_i per transfer independently); the second transfer
   // must pick up exactly where the first left off.
   run_transfer(3, beats, ok);
   `FAIL_IF_LOG(!ok, "first transfer never completed");
   `FAIL_UNLESS_LOG(beats.size() == 3, $sformatf("first transfer: collected %0d beats, expected 3", beats.size()));

   run_transfer(2, beats, ok);
   `FAIL_IF_LOG(!ok, "second transfer never completed");
   `FAIL_UNLESS_LOG(beats.size() == 2, $sformatf("second transfer: collected %0d beats, expected 2", beats.size()));
   for (i = 0; i < 2; i++)
      `FAIL_UNLESS_LOG(beats[i] === (32'hA000_0000 + 3 + i),
         $sformatf("second transfer beat %0d = 0x%08h, expected 0x%08h", i, beats[i], 32'hA000_0000 + 3 + i));
`SVTEST_END

`SVTEST(tc_backpressure_no_loss)
   int beats[];
   bit ok;
   int i;

   fork
      run_transfer(8, beats, ok);
      begin
         repeat(15) begin
            cb.tb_tready <= 1'b0;
            @(cb);
            cb.tb_tready <= 1'b1;
            @(cb);
         end
      end
   join

   `FAIL_IF_LOG(!ok, "transfer under intermittent backpressure never completed");
   `FAIL_UNLESS_LOG(beats.size() == 8, $sformatf("collected %0d beats under backpressure, expected 8", beats.size()));
   for (i = 0; i < 8; i++)
      `FAIL_UNLESS_LOG(beats[i] === (32'hA000_0000 + i),
         $sformatf("beat %0d = 0x%08h, expected 0x%08h (order/value must survive backpressure)", i, beats[i], 32'hA000_0000 + i));
`SVTEST_END
