//------------------------------------------------------------------------------
// Tests
//------------------------------------------------------------------------------

`SVTEST(test00_reset_state)
    `FAIL_IF_LOG(cb.tb_full == 1'b1, "Stack should not be full right after reset");
`SVTEST_END

`SVTEST(test01_single_push_pop)
    logic [WIDTH-1:0] data_in;

    data_in = 8'hAB;

    cb.tb_data_i <= data_in;
    cb.tb_push   <= 1'b1;
    @(cb);
    cb.tb_push   <= 1'b0;
    @(cb);

    `FAIL_UNLESS_LOG(cb.tb_data_o == data_in,
        $sformatf("Push/pop mismatch: wrote 0x%02h, read 0x%02h", data_in, cb.tb_data_o));

    cb.tb_pop <= 1'b1;
    @(cb);
    cb.tb_pop <= 1'b0;
    @(cb);
`SVTEST_END

`SVTEST(test02_nested_call_ret_lifo_order)
    // Simulate 3 nested CALLs (push return PCs 8'h10, 8'h20, 8'h30), then
    // RET 3 times (pop) and check LIFO order: last pushed, first popped.
    logic [WIDTH-1:0] pcs [3];
    int i;

    pcs[0] = 8'h10;
    pcs[1] = 8'h20;
    pcs[2] = 8'h30;

    for (i = 0; i < 3; i++) begin
        cb.tb_data_i <= pcs[i];
        cb.tb_push   <= 1'b1;
        @(cb);
    end
    cb.tb_push <= 1'b0;
    @(cb);

    for (i = 2; i >= 0; i--) begin
        `FAIL_UNLESS_LOG(cb.tb_data_o == pcs[i],
            $sformatf("RET %0d: expected 0x%02h, got 0x%02h", 2 - i, pcs[i], cb.tb_data_o));
        cb.tb_pop <= 1'b1;
        @(cb);
        cb.tb_pop <= 1'b0;
        @(cb);
    end
`SVTEST_END

`SVTEST(test03_full_never_asserts_up_to_depth)
    // Inherited from the original LIFO: the pointer is a fixed 3-bit
    // counter, so for DEPTH=8 (the only value tprocv2 ever instantiates)
    // full_o can never assert (0..7 zero-extended can never equal 8).
    int i;

    cb.tb_push <= 1'b1;
    for (i = 0; i < DEPTH; i++) begin
        cb.tb_data_i <= i[WIDTH-1:0];
        @(cb);
        `FAIL_IF_LOG(cb.tb_full == 1'b1,
            $sformatf("full_o asserted at push %0d - inherited quirk regressed", i));
    end
    cb.tb_push <= 1'b0;
    @(cb);
`SVTEST_END

`SVTEST(test04_ninth_push_wraps_and_overwrites_bottom)
    // 9 pushes with no pops: the pointer wraps 7->0, and the 9th push
    // overwrites the entry written by the 1st push (stack[0]).
    int i;

    cb.tb_push <= 1'b1;
    for (i = 0; i < 9; i++) begin
        cb.tb_data_i <= i[WIDTH-1:0];
        @(cb);
        `FAIL_IF_LOG(cb.tb_full == 1'b1,
            $sformatf("full_o asserted at push %0d", i));
    end
    cb.tb_push <= 1'b0;
    @(cb);

    `FAIL_UNLESS_LOG(cb.tb_data_o == 8'd8,
        $sformatf("Expected stack[0] overwritten with the 9th push (8), got 0x%02h",
                  cb.tb_data_o));
`SVTEST_END

`SVTEST(test05_push_has_priority_over_simultaneous_pop)
    logic [WIDTH-1:0] first, second;

    first  = 8'h11;
    second = 8'h22;

    cb.tb_data_i <= first;
    cb.tb_push   <= 1'b1;
    @(cb);   // ptr: 0 -> 1, stack[0] = first

    cb.tb_data_i <= second;
    cb.tb_push   <= 1'b1;
    cb.tb_pop    <= 1'b1;   // both asserted: push must win (matches original priority)
    @(cb);   // ptr: 1 -> 2, stack[1] = second ; pop ignored this cycle
    cb.tb_push <= 1'b0;
    cb.tb_pop  <= 1'b0;
    @(cb);

    `FAIL_UNLESS_LOG(cb.tb_data_o == second,
        $sformatf("Expected push priority to win (top = 0x%02h), got 0x%02h",
                  second, cb.tb_data_o));
`SVTEST_END
