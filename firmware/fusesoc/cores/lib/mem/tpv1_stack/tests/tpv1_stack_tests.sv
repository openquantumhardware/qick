//------------------------------------------------------------------------------
// Tests
//------------------------------------------------------------------------------

//--------------------------------------------------------------------------
// test00: Reset state
//   After reset, stack should be empty, not full.
//--------------------------------------------------------------------------
`SVTEST(test00_reset_state)
   `FAIL_UNLESS_LOG(tb_empty == 1'b1, "Stack should be empty after reset");
   `FAIL_IF_LOG(tb_full == 1'b1, "Stack should not be full after reset");
`SVTEST_END

//--------------------------------------------------------------------------
// test01: Single push
//   Push one value, verify it can be popped back.
//--------------------------------------------------------------------------
`SVTEST(test01_single_push_pop)
    logic [B-1:0] data_in;
    logic [B-1:0] data_out;

    data_in = 16'hABCD;

    // Push
    cb.tb_en  <= 1'b1;
    cb.tb_op  <= 1'b1;
    cb.tb_din <= data_in;
    @(cb);

    // Pop
    cb.tb_op  <= 1'b0;
    @(cb);   // rd_enb=1, rd_addr=sp (1 latency cycle)

    data_out = cb.tb_dout;
    cb.tb_en <= 1'b0;

    `FAIL_UNLESS_LOG(data_out == data_in,
        $sformatf("Push/pop mismatch: wrote 0x%04h, read 0x%04h", data_in, data_out));
    repeat(5)@(cb);
`SVTEST_END

//--------------------------------------------------------------------------
// test02: Push until full
//   Push 256 values, verify full flag and pointer behavior.
//--------------------------------------------------------------------------
`SVTEST(test02_push_until_full)
    int i;

    cb.tb_en <= 1'b1;
    cb.tb_op <= 1'b1;  // push

    // Push 255 values (sp goes from 255 down to 0)
    for (i = 0; i < 254; i++) begin
        cb.tb_din <= i[B-1:0];
        @(cb);
        `FAIL_IF_LOG(tb_full == 1'b1,
            $sformatf("Stack should not be full at push %0d", i));
    end

    // Push 255th value (sp goes from 0 to 0 with tb_full=1)
    cb.tb_din <= 254;
    @(cb);
    `FAIL_UNLESS_LOG(tb_full == 1'b1, "Stack should be full after 255 pushes");
    
    cb.tb_en <= 1'b0;
`SVTEST_END

//--------------------------------------------------------------------------
// test03: Pop until empty
//   Fill stack, then pop all values, verify empty flag.
//--------------------------------------------------------------------------
`SVTEST(test03_pop_until_empty)
    int push_count, pop_count;

    // ------------------------------------
    // 1. PUSH (Fill the stack)
    // ------------------------------------
    cb.tb_en <= 1'b1;
    cb.tb_op <= 1'b1;
    @(cb); // CRITICAL: Wait 1 cycle for tb_en and tb_op to take effect in DUT

    push_count = 0;
    while (!cb.tb_full) begin  // Use synchronized signal cb.tb_full
        cb.tb_din <= push_count[B-1:0];
        @(cb);
        push_count++;
    end
    $display("Full after %0d pushes", push_count);

    // ------------------------------------
    // 2. CLEAN TRANSITION
    // ------------------------------------
    cb.tb_en <= 1'b0; 
    @(cb); // Flush: clear the control pipeline to avoid collisions

    // ------------------------------------
    // 3. POP (Empty the stack)
    // ------------------------------------
    cb.tb_en <= 1'b1;
    cb.tb_op <= 1'b0;
    @(cb); // Wait 1 cycle for DUT to register read mode stably

    pop_count = 0;
    while (!cb.tb_empty) begin // Use synchronized signal cb.tb_empty
        @(cb);
        pop_count++;
    end
    $display("Empty after %0d pops", pop_count);

    // Disable stimuli
    cb.tb_en <= 1'b0;

    `FAIL_UNLESS_LOG(push_count == pop_count, 
        $sformatf("Push/pop mismatch: %0d pushes, %0d pops", push_count, pop_count));
`SVTEST_END

//--------------------------------------------------------------------------
// test04: Overflow protection
//   Attempt to push when full, verify pointer does not change.
//--------------------------------------------------------------------------
`SVTEST(test04_overflow_protection)
   int i;

   // Fill the stack
   cb.tb_en <= 1'b1;
   cb.tb_op <= 1'b1;  // push
   for (i = 0; i < 256; i++) begin
       cb.tb_din <= i[B-1:0];
       @(cb);
   end

   `FAIL_UNLESS_LOG(tb_full == 1'b1, "Stack should be full");

   // Try to push when full
   cb.tb_din <= 16'hDEAD;
   @(cb);

   // Should still be full (push ignored)
   `FAIL_UNLESS_LOG(tb_full == 1'b1, "Stack should remain full on overflow attempt");

   cb.tb_en <= 1'b0;
`SVTEST_END

//--------------------------------------------------------------------------
// test05: Underflow protection
//   Attempt to pop when empty, verify pointer does not change.
//--------------------------------------------------------------------------
`SVTEST(test05_underflow_protection)
   `FAIL_UNLESS_LOG(tb_empty == 1'b1, "Stack should be empty after reset");

   // Try to pop when empty
   cb.tb_en <= 1'b1;
   cb.tb_op <= 1'b0;  // pop
   @(cb);

   // Should still be empty (pop ignored)
   `FAIL_UNLESS_LOG(tb_empty == 1'b1, "Stack should remain empty on underflow attempt");

cb.tb_en <= 1'b0;
`SVTEST_END

//--------------------------------------------------------------------------
// test06: LIFO order
//   Push 4 values, pop them back, verify reverse order.
//--------------------------------------------------------------------------
`SVTEST(test06_lifo_order)
    logic [B-1:0] test_data [0:3];
    logic [B-1:0] read_data;
    int i;

    test_data[0] = 16'h1111;
    test_data[1] = 16'h2222;
    test_data[2] = 16'h3333;
    test_data[3] = 16'h4444;

    // ------------------------------------
    // 1. PUSH (Burst write)
    // ------------------------------------
    cb.tb_en <= 1'b1;
    cb.tb_op <= 1'b1;
    @(cb); // Synchronize control signals to DUT

    for (i = 0; i < 4; i++) begin
        cb.tb_din <= test_data[i];
        @(cb);
    end

    // ------------------------------------
    // 2. CLEAN TRANSITION
    // ------------------------------------
    cb.tb_en <= 1'b0; 
    @(cb); // Flush: 1-cycle pause to let DUT settle pointers

    // ------------------------------------
    // 3. POP (Burst read with latency)
    // ------------------------------------
    cb.tb_en <= 1'b1;
    cb.tb_op <= 1'b0;
    @(cb); // Send first read command to DUT

    // Wait for 1-cycle synchronous BRAM latency
    for (i = 0; i < 4; i++) begin
        @(cb); // Edge where valid data emerges on dout
        read_data = cb.tb_dout;
        
        // Last pushed should be first popped: 4,3,2,1
        `FAIL_UNLESS_LOG(read_data == test_data[3-i],
            $sformatf("LIFO: expected 0x%04h, got 0x%04h", test_data[3-i], read_data));
    end

    cb.tb_en <= 1'b0;
`SVTEST_END

//--------------------------------------------------------------------------
// test07: Enable gating
//   Verify that when en=0, no operations occur.
//--------------------------------------------------------------------------
`SVTEST(test07_enable_gating)
    logic [B-1:0] data_after;

    // Push one value
    cb.tb_en <= 1'b1;
    cb.tb_op <= 1'b1;
    cb.tb_din <= 16'hAAAA;
    @(cb);

    // Try to push with en=0 (should be ignored)
    cb.tb_en <= 1'b0;
    cb.tb_din <= 16'hBBBB;
    @(cb);

    // Pop the one value that was pushed
    cb.tb_en <= 1'b1;
    cb.tb_op <= 1'b0;
    @(cb);
    data_after = cb.tb_dout;

    // Should be AAAA (only first push happened, BBBB was with en=0)
    `FAIL_UNLESS_LOG(data_after == 16'hAAAA,
        $sformatf("Enable gating: expected 0xAAAA, got 0x%04h", data_after));

    cb.tb_en <= 1'b0;
`SVTEST_END