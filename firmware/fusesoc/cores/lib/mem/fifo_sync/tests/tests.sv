// =========================================================
// test00_reset
// =========================================================
`SVTEST(test00_reset)
  `ASSERT_IMMEDIATE(empty == 1);
`SVTEST_END

// =========================================================
// test01_fill_drain
// =========================================================
// =========================================================
// test01_fill_drain (Draining block correction)
// =========================================================
`SVTEST(test01_fill_drain)
  logic [B-1:0] exp;
  int           words_written;

  words_written = 0;
  model_q       = {};
  wr_en         = 0;
  rd_en         = 0;

  // Fill the FIFO until 'full' is asserted
  forever begin
    @(negedge clk); // Sample/drive on negedge to stay clear of the active clock edge
    if (full) begin
      wr_en = 0;
      break;
    end
    wr_en = 1;
    din   = $urandom;
    model_q.push_back(din);
    words_written++;
  end

  @(posedge clk);
  wr_en = 0;

  $display("Effective FIFO depth = %0d words", words_written);
  `ASSERT_IMMEDIATE(full == 1);

  // Drain — FWFT: current data is already waiting at 'dout'
  for (int i = 0; i < words_written; i++) begin
    exp = model_q.pop_front();
    
    @(negedge clk); // Wait for a stable negative edge before sampling dout
    `FAIL_UNLESS_EQUAL(dout, exp); // Check currently exposed data safely
    
    rd_en = 1;      // Tell FIFO to advance to the next word on the upcoming posedge
    @(posedge clk);
    rd_en = 0;      // Lower rd_en immediately after the edge
  end

  repeat(4) @(posedge clk);
  `ASSERT_IMMEDIATE(empty == 1);
  `ASSERT_IMMEDIATE(model_q.size() == 0);
`SVTEST_END

// =========================================================
// test02_random
// =========================================================
`SVTEST(test02_random)
  wr_en   = 0;
  rd_en   = 0;
  model_q = {};

  repeat (200) begin
    @(negedge clk); // Evaluate and drive safely on negedge

    // FWFT Rule: If FIFO is not empty, 'dout' must match the oldest item in the model
    if (!empty && model_q.size() > 0) begin
      `FAIL_UNLESS_EQUAL(dout, model_q[0]);
    end

    // Write Path Randomization
    if (!full && $urandom_range(0,1)) begin
      wr_en = 1;
      din   = $urandom;
      model_q.push_back(din);
    end else begin
      wr_en = 0;
    end

    // Read Path Randomization
    if (!empty && $urandom_range(0,1)) begin
      rd_en = 1;
      void'(model_q.pop_front());
    end else begin
      rd_en = 0;
    end
  end

  @(negedge clk);
  wr_en = 0;
  rd_en = 0;
  @(posedge clk);
`SVTEST_END

// =========================================================
// test03_read_stall (Prolonged Backpressure Simulation)
// =========================================================
// Writes several words, reads a few, stalls reading for 
// many cycles, and verifies that the data in 'dout' remains 
// stable and is not lost upon resuming.
// =========================================================
`SVTEST(test03_read_stall)
  logic [B-1:0] exp;

  wr_en = 0;
  rd_en = 0;
  model_q = {};

  // 1. Write 10 words into the FIFO
  for (int i = 0; i < 10; i++) begin
    @(negedge clk);
    wr_en = 1;
    din = 16'hA000 + i;
    model_q.push_back(din);
  end
  @(negedge clk);
  wr_en = 0;

  // 2. Read 2 words normally
  for (int i = 0; i < 2; i++) begin
    @(negedge clk);
    exp = model_q.pop_front();
    `FAIL_UNLESS_EQUAL(dout, exp);
    rd_en = 1;
    @(posedge clk);
    rd_en = 0;
  end

  // 3. STALL (Backpressure): Stop reading for 50 cycles
  // The FIFO must keep the 3rd data word intact in 'dout'.
  repeat(50) @(posedge clk);

  // 4. Verify the data survived the wait and read the rest
  while(model_q.size() > 0) begin
    @(negedge clk);
    exp = model_q.pop_front();
    // This assertion will fail if FWFT mode discards the data during the stall
    `FAIL_UNLESS_EQUAL(dout, exp); 
    rd_en = 1;
    @(posedge clk);
    rd_en = 0;
  end

  repeat(2) @(posedge clk);
  `ASSERT_IMMEDIATE(empty == 1);
`SVTEST_END

// =========================================================
// test04_concurrent_rw
// =========================================================
// Maintains a constant flow where reading and writing occur
// in the exact same clock cycle.
// =========================================================
`SVTEST(test04_concurrent_rw)
  logic [B-1:0] exp;
  
  wr_en = 0;
  rd_en = 0;
  model_q = {};

  // Partially fill the FIFO to have some margin
  for (int i = 0; i < 3; i++) begin
    @(negedge clk);
    wr_en = 1; 
    din = $urandom; 
    model_q.push_back(din);
  end
  @(negedge clk); 
  wr_en = 0;

  // Simultaneous R/W cycles
  for (int i = 0; i < 20; i++) begin
    @(negedge clk);
    // Verify FWFT before asserting rd_en
    exp = model_q[0];
    `FAIL_UNLESS_EQUAL(dout, exp);

    // Assert both simultaneously
    wr_en = 1; 
    din = $urandom; 
    model_q.push_back(din);
    
    rd_en = 1; 
    void'(model_q.pop_front());
  end

  @(negedge clk);
  wr_en = 0; 
  rd_en = 0;

  // Drain whatever is left
  while(model_q.size() > 0) begin
    @(negedge clk);
    exp = model_q.pop_front();
    `FAIL_UNLESS_EQUAL(dout, exp);
    rd_en = 1;
    @(posedge clk);
    rd_en = 0;
  end
`SVTEST_END
