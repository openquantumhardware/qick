// ============================================================================
// File: axis_buffer_ddr_tests.sv
// Description: SVUnit test cases for axis_buffer_ddr. Included by
//              axis_buffer_ddr_tc00.sv.
// ============================================================================

`SVTEST(tc_registers_match_the_legacy_slave)
    // 2000 random operations over all 64 registers (writes with random data and byte strobes to the unused storage
    // registers 7..63 (6 is the read-only status), reads of all of them); the IP and the legacy RTL must agree on every output of both clock
    // domains, and reads must return what a byte-lane model expects. The master registers 0..5 are exercised, with
    // legal values, by the next test.
    logic [31:0] shadow [64];
    logic [31:0] rd;
    foreach (shadow[r]) shadow[r] = '0;
    for (int n = 0; n < 2000; n++) begin
        int r = $urandom_range(63);
        if ($urandom_range(1) && r >= 7) begin
            logic [31:0] d = $urandom;
            logic [3:0]  s = 4'($urandom);
            axi_wr(8'(4 * r), d, s);
            for (int b = 0; b < 4; b++) if (s[b]) shadow[r][8*b +: 8] = d[8*b +: 8];
        end else begin
            axi_rd(8'(4 * r), rd);
            `FAIL_UNLESS_EQUAL(rd, shadow[r])
        end
    end
    `FAIL_UNLESS_EQUAL(mism_reg, 0)
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS(n_reads > 500)
`SVTEST_END

`SVTEST(tc_random_transfers_match_the_legacy_rtl)
    // Random legal transfers (reads of 1..40 beats inside a 4 kB page, writes of 1..3 bursts at a burst-aligned
    // address), start bits, trigger and stream timing: every output equal on every clock.
    for (int k = 0; k < 12; k++) begin
        for (int i = 0; i < 64; i++) mem[$urandom_range(4095)] = {$urandom, $urandom};
        p_aw = 20 + $urandom_range(80); p_w = 20 + $urandom_range(80); p_ar = 20 + $urandom_range(80);
        p_r = 20 + $urandom_range(80); p_b = 20 + $urandom_range(80);
        if (k % 2 == 0) begin
            reg_wr(1, 32'(8 * $urandom_range(200)));
            reg_wr(2, 32'($urandom_range(1, 40)));
            reg_wr(0, 32'd1);
            repeat (400) begin
                @(posedge aclk);
                m_axis_tready <= ($urandom_range(99) < 60);
            end
            m_axis_tready <= 1'b1;
            reg_wr(0, 32'd0);
        end else begin
            reg_wr(4, 32'(64 * $urandom_range(40)));
            reg_wr(5, 32'($urandom_range(1, 3)));
            reg_wr(3, 32'd1);
            repeat ($urandom_range(5, 30)) @(posedge aclk);
            @(posedge aclk) trigger <= 1'b1;
            send(30, 20 + k, 20 + $urandom_range(80));
            repeat (500) @(posedge aclk);
            trigger <= 1'b0;
            reg_wr(3, 32'd0);
        end
        repeat (40) @(posedge aclk);
    end
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS_EQUAL(mism_reg, 0)
    `FAIL_UNLESS_EQUAL(viol_4k, 0)
    `FAIL_UNLESS(n_ar >= 6)
    `FAIL_UNLESS(n_aw >= 6)
`SVTEST_END

`SVTEST(tc_register_map_reaches_the_masters)
    // RSTART/WSTART bit 0, the other four words whole.
    reg_wr(0, 32'hFFFF_FFFE);
    reg_wr(1, 32'h1111_1111);
    reg_wr(2, 32'h2222_2222);
    reg_wr(3, 32'h0000_0000);
    reg_wr(4, 32'h4444_4444);
    reg_wr(5, 32'h5555_5555);
    repeat (4) @(posedge s_axi_aclk);
    `FAIL_UNLESS_EQUAL(dut.regs[0][0], 1'b0)
    `FAIL_UNLESS_EQUAL(dut.regs[1], 32'h1111_1111)
    `FAIL_UNLESS_EQUAL(dut.regs[2], 32'h2222_2222)
    `FAIL_UNLESS_EQUAL(dut.regs[3][0], 1'b0)
    `FAIL_UNLESS_EQUAL(dut.regs[4], 32'h4444_4444)
    `FAIL_UNLESS_EQUAL(dut.regs[5], 32'h5555_5555)
    `FAIL_UNLESS_EQUAL(mism_reg, 0)
`SVTEST_END

`SVTEST(tc_write_after_the_trigger_fills_memory)
    // WNBURST = 3: 3 bursts of 8 beats = 24 words at byte offset 0x100, on the
    // words streamed after the trigger.
    int base = 'h100 >> WSH;
    int n0;
    reg_wr(4, 32'h100);
    reg_wr(5, 32'd3);
    reg_wr(3, 32'd1);
    repeat (20) @(posedge aclk);
    @(posedge aclk) trigger <= 1'b1;
    repeat (20) @(posedge aclk);
    send(48, 1, 80);
    repeat (400) @(posedge aclk);
    trigger <= 1'b0;
    reg_wr(3, 32'd0);
    repeat (40) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS_EQUAL(mism_reg, 0)
    `FAIL_UNLESS_EQUAL(n_aw, 3)
    `FAIL_UNLESS_EQUAL(n_w, 24)
    // The words are consecutive stream words: none is lost at the burst boundaries (the legacy lost one in NBURST_ST;
    // the golden model of this test has that one-line fix).
    n0 = -1;
    for (int i = 0; i < 24; i++) begin
        logic [DW-1:0] x;
        logic [31:0]   lo, hi;
        x  = mem[base + i] ^ 64'h0123_4567_89AB_CDEF;
        lo = x[31:0];
        hi = x[63:32];
        `FAIL_UNLESS_EQUAL(hi, 32'd1)
        if (i > 0) begin `FAIL_UNLESS_EQUAL(int'(lo), n0 + 1) end
        n0 = int'(lo);
    end
    `FAIL_UNLESS(mem[base + 24] === '0)
`SVTEST_END

`SVTEST(tc_read_returns_the_memory_block)
    // RLENGTH = 16 beats at byte offset 0x80 (the first 16 words out of the
    // stream are the block).
    int base = 'h80 >> WSH;
    for (int i = 0; i < 64; i++) mem[base + i] = pat(2, i);
    reg_wr(1, 32'h80);
    reg_wr(2, 32'd16);
    reg_wr(0, 32'd1);
    repeat (300) @(posedge aclk);
    reg_wr(0, 32'd0);
    repeat (40) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS_EQUAL(mism_reg, 0)
    `FAIL_UNLESS_EQUAL(n_ar, 1)
    `FAIL_UNLESS(o_data.size() >= 16)
    for (int i = 0; i < 16 && i < o_data.size(); i++) begin
        logic [DW-1:0] a, b;
        a = o_data[i]; b = pat(2, i);
        `FAIL_UNLESS(a === b)
    end
`SVTEST_END

`SVTEST(tc_read_with_backpressure_and_slow_responses)
    int base = 'h200 >> WSH;
    p_ar = 20; p_r = 30;
    for (int i = 0; i < 128; i++) mem[base + i] = pat(3, i);
    reg_wr(1, 32'h200);
    reg_wr(2, 32'd100);
    reg_wr(0, 32'd1);
    repeat (1500) begin
        @(posedge aclk);
        m_axis_tready <= ($urandom_range(99) < 40);
    end
    m_axis_tready <= 1'b1;
    repeat (200) @(posedge aclk);
    reg_wr(0, 32'd0);
    repeat (40) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS_EQUAL(mism_reg, 0)
    `FAIL_UNLESS(o_data.size() >= 100)
    for (int i = 0; i < 100 && i < o_data.size(); i++) begin
        logic [DW-1:0] a, b;
        a = o_data[i]; b = pat(3, i);
        `FAIL_UNLESS(a === b)
    end
`SVTEST_END

`SVTEST(tc_two_writes_in_a_row_and_slow_memory)
    int base0 = 'h400 >> WSH;
    int base1 = 'h800 >> WSH;
    p_aw = 15; p_w = 30; p_b = 20;
    reg_wr(4, 32'h400);
    reg_wr(5, 32'd2);
    reg_wr(3, 32'd1);
    repeat (10) @(posedge aclk);
    @(posedge aclk) trigger <= 1'b1;
    send(32, 4, 60);
    repeat (800) @(posedge aclk);
    trigger <= 1'b0;
    reg_wr(3, 32'd0);
    repeat (50) @(posedge aclk);
    reg_wr(4, 32'h800);
    reg_wr(5, 32'd1);
    reg_wr(3, 32'd1);
    repeat (10) @(posedge aclk);
    @(posedge aclk) trigger <= 1'b1;
    send(16, 5, 90);
    repeat (500) @(posedge aclk);
    trigger <= 1'b0;
    reg_wr(3, 32'd0);
    repeat (50) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS_EQUAL(mism_reg, 0)
    `FAIL_UNLESS_EQUAL(n_aw, 3)
    `FAIL_UNLESS_EQUAL(n_w, 24)
    `FAIL_UNLESS((mem[base0] ^ 64'h0123_4567_89AB_CDEF) >> 32 == 64'd4)
    `FAIL_UNLESS((mem[base1] ^ 64'h0123_4567_89AB_CDEF) >> 32 == 64'd5)
    for (int i = 1; i < 16; i++) begin                  // 2 bursts of 8: no word lost at the boundary
        logic [DW-1:0] a, b;
        a = mem[base0 + i] ^ 64'h0123_4567_89AB_CDEF;
        b = mem[base0 + i - 1] ^ 64'h0123_4567_89AB_CDEF;
        `FAIL_UNLESS_EQUAL(a[31:0], b[31:0] + 32'd1)
    end
`SVTEST_END

`SVTEST(tc_reset_in_the_middle_of_a_transfer)
    reg_wr(4, 32'h100);
    reg_wr(5, 32'd3);
    reg_wr(3, 32'd1);
    @(posedge aclk) trigger <= 1'b1;
    fork
        send(60, 6, 70);
        begin
            repeat (60) @(posedge aclk);
            aresetn <= 1'b0; s_axi_aresetn <= 1'b0;
            repeat (10) @(posedge aclk);
            aresetn <= 1'b1; s_axi_aresetn <= 1'b1;
        end
    join
    repeat (200) @(posedge aclk);
    reg_wr(1, 32'h80);
    reg_wr(2, 32'd8);
    reg_wr(0, 32'd1);
    repeat (200) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS_EQUAL(mism_reg, 0)
`SVTEST_END

`SVTEST(tc_read_of_more_than_256_beats_is_split)
    // 600 beats from 0: bursts of 256, 256 and 88 beats (arlen is 8 bits; the legacy RTL truncated 600 - 1 to 8 bits).
    cmp_en = 1'b0;
    for (int i = 0; i < 700; i++) mem[i] = pat(7, i);
    reg_wr(1, 32'd0);
    reg_wr(2, 32'd600);
    reg_wr(0, 32'd1);
    repeat (3000) @(posedge aclk);
    reg_wr(0, 32'd0);
    repeat (40) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(n_ar, 3)
    `FAIL_UNLESS_EQUAL(viol_4k, 0)
    `FAIL_UNLESS_EQUAL(o_data.size(), 600)
    for (int i = 0; i < 600 && i < o_data.size(); i++) begin
        logic [DW-1:0] a, b;
        a = o_data[i]; b = pat(7, i);
        `FAIL_UNLESS(a === b)
    end
`SVTEST_END

`SVTEST(tc_read_across_4kB_is_split)
    // 40 beats from byte 0xF80: 16 beats up to the 4 kB boundary, then 24 (the legacy RTL issued one burst across it).
    int base = 'hF80 >> WSH;
    cmp_en = 1'b0;
    for (int i = 0; i < 64; i++) mem[base + i] = pat(8, i);
    reg_wr(1, 32'hF80);
    reg_wr(2, 32'd40);
    reg_wr(0, 32'd1);
    repeat (800) @(posedge aclk);
    reg_wr(0, 32'd0);
    repeat (40) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(n_ar, 2)
    `FAIL_UNLESS_EQUAL(viol_4k, 0)
    `FAIL_UNLESS_EQUAL(o_data.size(), 40)
    for (int i = 0; i < 40 && i < o_data.size(); i++) begin
        logic [DW-1:0] a, b;
        a = o_data[i]; b = pat(8, i);
        `FAIL_UNLESS(a === b)
    end
`SVTEST_END

`SVTEST(tc_read_of_zero_beats_reads_nothing)
    // The legacy RTL read 256 beats for a length of 0.
    cmp_en = 1'b0;
    reg_wr(1, 32'd0);
    reg_wr(2, 32'd0);
    reg_wr(0, 32'd1);
    repeat (200) @(posedge aclk);
    reg_wr(0, 32'd0);
    repeat (40) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(n_arvalid, 0)
    `FAIL_UNLESS_EQUAL(o_data.size(), 0)
    `FAIL_UNLESS_EQUAL(int'(dut.axi_mst_read_i.state), 1)   // START_ST: ready for the next read
`SVTEST_END

`SVTEST(tc_write_of_zero_bursts_writes_one_and_ends)
    // The legacy RTL compared the burst count for equality after the first burst and never ended.
    reg_wr(4, 32'h100);
    reg_wr(5, 32'd0);
    reg_wr(3, 32'd1);
    repeat (10) @(posedge aclk);
    @(posedge aclk) trigger <= 1'b1;
    send(30, 9, 80);
    repeat (300) @(posedge aclk);
    trigger <= 1'b0;
    reg_wr(3, 32'd0);
    repeat (60) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS_EQUAL(mism_reg, 0)
    `FAIL_UNLESS_EQUAL(n_aw, 1)
    `FAIL_UNLESS_EQUAL(n_w, 8)
    `FAIL_UNLESS_EQUAL(int'(dut.axi_mst_write_i.state), 0)  // INIT_ST: ready for the next write
`SVTEST_END

`SVTEST(tc_clearing_wstart_before_the_trigger_disarms)
    // The legacy writer stayed armed: the trigger then started a write nobody asked for.
    reg_wr(4, 32'h100);
    reg_wr(5, 32'd1);
    reg_wr(3, 32'd1);
    repeat (40) @(posedge aclk);
    reg_wr(3, 32'd0);
    repeat (40) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(int'(dut.axi_mst_write_i.state), 0)           // INIT_ST
    @(posedge aclk) trigger <= 1'b1;
    send(20, 11, 90);
    repeat (100) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(n_aw, 0)
    trigger <= 1'b0;
    repeat (20) @(posedge aclk);
    // armed again, it writes
    reg_wr(3, 32'd1);
    repeat (20) @(posedge aclk);
    @(posedge aclk) trigger <= 1'b1;
    send(20, 12, 90);
    repeat (200) @(posedge aclk);
    trigger <= 1'b0;
    reg_wr(3, 32'd0);
    repeat (60) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS_EQUAL(mism_reg, 0)
    `FAIL_UNLESS_EQUAL(n_aw, 1)
    `FAIL_UNLESS_EQUAL(n_w, 8)
`SVTEST_END

`SVTEST(tc_error_response_sets_wstatus_until_the_next_write)
    // The legacy RTL ignored BRESP (and has no status register: the compare with it is off).
    logic [31:0] st;
    cmp_en = 1'b0;
    axi_rd(8'h18, st);
    `FAIL_UNLESS_EQUAL(st, 32'd0)
    bresp_err_next = 1'b1;
    reg_wr(4, 32'h100);
    reg_wr(5, 32'd2);
    reg_wr(3, 32'd1);
    repeat (10) @(posedge aclk);
    @(posedge aclk) trigger <= 1'b1;
    send(24, 13, 90);
    repeat (400) @(posedge aclk);
    trigger <= 1'b0;
    reg_wr(3, 32'd0);
    repeat (60) @(posedge aclk);
    axi_rd(8'h18, st);
    `FAIL_UNLESS_EQUAL(st, 32'd1)                                   // set, and it does not stop the write
    `FAIL_UNLESS_EQUAL(n_aw, 2)
    axi_wr(8'h18, 32'd0, 4'hf);                                       // read only: a write does nothing
    axi_rd(8'h18, st);
    `FAIL_UNLESS_EQUAL(st, 32'd1)
    bresp_err_next = 1'b0;                                            // a good write clears it when it starts
    reg_wr(3, 32'd1);
    repeat (10) @(posedge aclk);
    @(posedge aclk) trigger <= 1'b1;
    send(24, 14, 90);
    repeat (400) @(posedge aclk);
    trigger <= 1'b0;
    reg_wr(3, 32'd0);
    repeat (60) @(posedge aclk);
    axi_rd(8'h18, st);
    `FAIL_UNLESS_EQUAL(st, 32'd0)
    `FAIL_UNLESS_EQUAL(n_aw, 4)
`SVTEST_END

`SVTEST(tc_read_from_an_unaligned_address_still_makes_progress_and_keeps_4kB)
    // 0xFFC is 4 bytes before the boundary, less than one 8-byte beat: the first burst is one beat, the next starts at
    // 0x1004. Unaligned addresses are not supported (RADDR is a multiple of the bus width in bytes); the burst
    // split must still finish and never cross 4 kB.
    cmp_en = 1'b0;
    for (int i = 0; i < 600; i++) mem[i] = pat(15, i);
    reg_wr(1, 32'hFFC);
    reg_wr(2, 32'd3);
    reg_wr(0, 32'd1);
    repeat (300) @(posedge aclk);
    reg_wr(0, 32'd0);
    repeat (40) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(n_ar, 2)
    `FAIL_UNLESS_EQUAL(viol_4k, 0)
    `FAIL_UNLESS_EQUAL(o_data.size(), 3)
    `FAIL_UNLESS_EQUAL(int'(dut.axi_mst_read_i.state), 1)
`SVTEST_END

`SVTEST(tc_read_whose_last_beat_waits_for_a_full_fifo)
    // 80 beats into a stream that is held and then drained slowly: the last beat is presented while the FIFO is full
    // and has to wait (rready is low), the burst ends only when it is taken. Same as the legacy RTL on every clock.
    int base = 'h40 >> WSH;
    p_ar = 100; p_r = 100;
    for (int i = 0; i < 100; i++) mem[base + i] = pat(16, i);
    m_axis_tready = 1'b0;
    reg_wr(1, 32'h40);
    reg_wr(2, 32'd80);
    reg_wr(0, 32'd1);
    repeat (400) @(posedge aclk);
    repeat (1500) begin
        @(posedge aclk);
        m_axis_tready <= ($urandom_range(3) == 0);
    end
    m_axis_tready <= 1'b1;
    repeat (200) @(posedge aclk);
    reg_wr(0, 32'd0);
    repeat (40) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS_EQUAL(mism_reg, 0)
    `FAIL_UNLESS_EQUAL(o_data.size(), 80)
    for (int i = 0; i < 80 && i < o_data.size(); i++) begin
        logic [DW-1:0] a, b;
        a = o_data[i]; b = pat(16, i);
        `FAIL_UNLESS(a === b)
    end
`SVTEST_END

`SVTEST(tc_write_waits_for_the_trigger_to_fall_before_it_can_end)
    // WSTART is cleared while the trigger (a level) is still high: the writer stays in END_ST until the trigger falls.
    reg_wr(4, 32'h100);
    reg_wr(5, 32'd1);
    reg_wr(3, 32'd1);
    repeat (10) @(posedge aclk);
    @(posedge aclk) trigger <= 1'b1;
    send(20, 17, 90);
    repeat (200) @(posedge aclk);
    reg_wr(3, 32'd0);
    repeat (100) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(int'(dut.axi_mst_write_i.state), 9)          // END_ST: the trigger is still high
    trigger <= 1'b0;
    repeat (60) @(posedge aclk);
    `FAIL_UNLESS_EQUAL(int'(dut.axi_mst_write_i.state), 0)          // INIT_ST
    `FAIL_UNLESS_EQUAL(mism, 0)
    `FAIL_UNLESS_EQUAL(mism_reg, 0)
    `FAIL_UNLESS_EQUAL(n_aw, 1)
`SVTEST_END
