// ============================================================================
// File: axis_tprocv1_tests.sv
// Description: SVUnit test cases for axis_tprocv1.
// Included by axis_tprocv1_tc00.sv inside `SVUNIT_TESTS_BEGIN/END.
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 00: Register reset values — all control registers read 0 after reset.
// ----------------------------------------------------------------------------
`SVTEST(tc00_register_reset)
    logic [AXI_DW-1:0] rd;
    reg_read(REG_START_SRC, rd);
    `FAIL_IF_LOG(rd !== '0, $sformatf("tc00: START_SRC=0x%0h", rd));
    reg_read(REG_START, rd);
    `FAIL_IF_LOG(rd !== '0, $sformatf("tc00: START=0x%0h", rd));
    reg_read(REG_MEM_MODE, rd);
    `FAIL_IF_LOG(rd !== '0, $sformatf("tc00: MEM_MODE=0x%0h", rd));
    reg_read(REG_MEM_START, rd);
    `FAIL_IF_LOG(rd !== '0, $sformatf("tc00: MEM_START=0x%0h", rd));
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 01: Register write/read round-trip on all control registers.
// ----------------------------------------------------------------------------
`SVTEST(tc01_register_roundtrip)
    logic [AXI_DW-1:0] rd;
    reg_write(REG_START_SRC, 32'h1);  reg_read(REG_START_SRC, rd);
    `FAIL_IF_LOG(rd[0] !== 1'b1, $sformatf("tc01: START_SRC=0x%0h", rd));
    reg_write(REG_MEM_MODE, 32'h1);   reg_read(REG_MEM_MODE, rd);
    `FAIL_IF_LOG(rd[0] !== 1'b1, $sformatf("tc01: MEM_MODE=0x%0h", rd));
    reg_write(REG_MEM_ADDR, 32'h0000_00AB); reg_read(REG_MEM_ADDR, rd);
    `FAIL_IF_LOG(rd[7:0] !== 8'hAB, $sformatf("tc01: MEM_ADDR=0x%0h", rd));
    reg_write(REG_MEM_LEN, 32'h0000_0040);  reg_read(REG_MEM_LEN, rd);
    `FAIL_IF_LOG(rd[7:0] !== 8'h40, $sformatf("tc01: MEM_LEN=0x%0h", rd));
    // Clear back
    reg_write(REG_START_SRC, 32'h0);
    reg_write(REG_MEM_MODE, 32'h0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 02: Single write/read to DMEM via the upper AXI window.
//   Mirrors driver single_write()/single_read() (array[addr + NREG]).
// ----------------------------------------------------------------------------
`SVTEST(tc02_dmem_single_write_read)
    logic [AXI_DW-1:0] rd;
    dmem_single_write(10, 32'hDEAD_BEEF);
    dmem_single_read (10, rd);
    `FAIL_IF_LOG(rd !== 32'hDEAD_BEEF,
        $sformatf("tc02: addr10 expected 0xDEADBEEF got 0x%0h", rd));
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 03: Multiple single writes to distinct addresses, read back in order.
// ----------------------------------------------------------------------------
`SVTEST(tc03_dmem_single_multi)
    localparam int CNT = 8;
    logic [AXI_DW-1:0] rd;
    for (int i = 0; i < CNT; i++)
        dmem_single_write(i, 32'h1000_0000 + AXI_DW'(i));
    for (int i = 0; i < CNT; i++) begin
        dmem_single_read(i, rd);
        `FAIL_IF_LOG(rd !== (32'h1000_0000 + AXI_DW'(i)),
            $sformatf("tc03: addr%0d expected 0x%0h got 0x%0h",
                      i, 32'h1000_0000 + i, rd));
    end
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 04: Single read at boundary addresses (0 and DEPTH-1).
// ----------------------------------------------------------------------------
`SVTEST(tc04_dmem_boundary)
    logic [AXI_DW-1:0] rd;
    dmem_single_write(0,         32'h0000_0001);
    dmem_single_write(DEPTH-1,   32'hFFFF_FFFE);
    dmem_single_read (0, rd);
    `FAIL_IF_LOG(rd !== 32'h0000_0001, $sformatf("tc04: addr0=0x%0h", rd));
    dmem_single_read (DEPTH-1, rd);
    `FAIL_IF_LOG(rd !== 32'hFFFF_FFFE, $sformatf("tc04: addrMax=0x%0h", rd));
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 05: AXIS write to DMEM, then single-read back the data.
//   1. MEM_MODE=1 (write), MEM_ADDR=base, MEM_LEN=N, MEM_START=1.
//   2. Stream N beats on s0_axis.
//   3. MEM_START=0.
//   4. Single-read each location, verify.
// ----------------------------------------------------------------------------
`SVTEST(tc05_axis_write_then_single_read)
    localparam int LEN  = 8;
    localparam int BASE = 16;
    logic [AXI_DW-1:0] rd;
    // Configure AXIS write
    reg_write(REG_MEM_MODE,  32'h1);
    reg_write(REG_MEM_ADDR,  AXI_DW'(BASE));
    reg_write(REG_MEM_LEN,   AXI_DW'(LEN));
    reg_write(REG_MEM_START, 32'h1);
    //// Wait for arbiter to accept (busy) — give CDC/FSM margin
    //repeat(10) @(posedge s_axi_aclk);
    //// Stream LEN beats on s0_axis (writer asserts tready in WRITE_ST)
    //for (int i = 0; i < LEN; i++)
    //    s0_axis_if.tx(32'h2000 + AXI_DW'(i), (i == LEN-1));
    // Esperar a que el writer asserte tready (FSM en WRITE_ST) antes de enviar
    @(s0_axis_if.m_cb);
    while (!s0_axis_if.tready) @(s0_axis_if.m_cb);
    for (int i = 0; i < LEN; i++)
        s0_axis_if.tx(32'h2000 + AXI_DW'(i), (i == LEN-1));
    // Let transfer complete, then stop
    repeat(20) @(posedge s_axi_aclk);
    reg_write(REG_MEM_START, 32'h0);
    repeat(10) @(posedge s_axi_aclk);
    // Single-read back
    for (int i = 0; i < LEN; i++) begin
        dmem_single_read(BASE + i, rd);
        `FAIL_IF_LOG(rd !== (32'h2000 + AXI_DW'(i)),
            $sformatf("tc05: addr%0d expected 0x%0h got 0x%0h",
                      BASE+i, 32'h2000+i, rd));
    end
    reg_write(REG_MEM_MODE, 32'h0);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 06: Single-write data, then AXIS read it out on m0_axis.
//   1. Single-write N words at base.
//   2. MEM_MODE=0 (read), MEM_ADDR=base, MEM_LEN=N, MEM_START=1.
//   3. Drain N beats on m0_axis, verify data and tlast.
// ----------------------------------------------------------------------------
`SVTEST(tc06_single_write_then_axis_read)
    localparam int LEN  = 8;
    localparam int BASE = 32;
    logic [31:0] word;
    logic        last;
    int          tlast_cnt = 0;
    // Preload via single writes
    for (int i = 0; i < LEN; i++)
        dmem_single_write(BASE + i, 32'h3000 + AXI_DW'(i));
    // Configure AXIS read
    reg_write(REG_MEM_MODE,  32'h0);
    reg_write(REG_MEM_ADDR,  AXI_DW'(BASE));
    reg_write(REG_MEM_LEN,   AXI_DW'(LEN));
    reg_write(REG_MEM_START, 32'h1);
    // Drain LEN beats
    m0_axis_if.s_cb.tready <= 1'b1;          // sustained during the entire burst
    for (int i = 0; i < LEN; i++) begin
        do @(m0_axis_if.s_cb); while (!m0_axis_if.s_cb.tvalid);
        $display("[dump] beat%0d tdata=0x%08h tlast=%b",
                 i, m0_axis_if.s_cb.tdata, m0_axis_if.s_cb.tlast);
    end
    m0_axis_if.s_cb.tready <= 1'b0;

    reg_write(REG_MEM_START, 32'h0);
    repeat(10) @(posedge s_axi_aclk);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 07: End-to-end AXIS write then AXIS read back the same region.
// ----------------------------------------------------------------------------
`SVTEST(tc07_axis_write_then_axis_read)
    localparam int LEN  = 8;
    localparam int BASE = 48;
    logic [31:0] word;
    logic        last;

    // ---- AXIS WRITE ----
    reg_write(REG_MEM_MODE,  32'h1);
    reg_write(REG_MEM_ADDR,  AXI_DW'(BASE));
    reg_write(REG_MEM_LEN,   AXI_DW'(LEN));
    reg_write(REG_MEM_START, 32'h1);
    // wait for writer to assert tready (WRITE_ST) before streaming
    @(s0_axis_if.m_cb);
    while (!s0_axis_if.tready) @(s0_axis_if.m_cb);
    for (int i = 0; i < LEN; i++)
        s0_axis_if.tx(32'hCAFE_0000 + AXI_DW'(i), (i == LEN-1));
    // wait until the writer leaves WRITE_ST (tready drops) => burst consumed
    @(s0_axis_if.m_cb);
    while (s0_axis_if.tready) @(s0_axis_if.m_cb);
    // stop the AXIS transaction and wait for arbiter to return to idle
    reg_write(REG_MEM_START, 32'h0);
    repeat(30) @(posedge s_axi_aclk);   // CDC + END_ST -> INIT_ST margin

    // ---- AXIS READ ----
    reg_write(REG_MEM_MODE,  32'h0);
    reg_write(REG_MEM_ADDR,  AXI_DW'(BASE));
    reg_write(REG_MEM_LEN,   AXI_DW'(LEN));
    reg_write(REG_MEM_START, 32'h1);
    m0_axis_if.s_cb.tready <= 1'b1;
    for (int i = 0; i < LEN; i++) begin
        do @(m0_axis_if.s_cb); while (!m0_axis_if.s_cb.tvalid);
        word = m0_axis_if.s_cb.tdata;
        last = m0_axis_if.s_cb.tlast;
        `FAIL_IF_LOG(word !== (32'hCAFE_0000 + AXI_DW'(i)),
            $sformatf("tc07: beat%0d expected 0x%0h got 0x%0h",
                      i, 32'hCAFE0000+i, word));
    end
    m0_axis_if.s_cb.tready <= 1'b0;
    reg_write(REG_MEM_START, 32'h0);
    repeat(10) @(posedge s_axi_aclk);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 08: SLVERR on single access while AXIS transfer is in progress.
//   With MEM_START=1 the memory arbiter is busy; a single read/write to the
//   DMEM window must return RRESP/BRESP = SLVERR (2'b10).
//   (Requires axi4_lite_if to expose the response code.)
// ----------------------------------------------------------------------------
`SVTEST(tc08_slverr_when_busy)
    logic [AXI_DW-1:0] rd;
    logic [1:0]        resp;
    // Start a long AXIS read so the arbiter stays busy
    reg_write(REG_MEM_MODE,  32'h0);
    reg_write(REG_MEM_ADDR,  32'h0);
    reg_write(REG_MEM_LEN,   AXI_DW'(DEPTH));   // long burst
    reg_write(REG_MEM_START, 32'h1);
    // Do NOT drain m0_axis -> busy stays asserted
    repeat(10) @(posedge s_axi_aclk);
    // Attempt a single read -> expect SLVERR
    dmem_single_read_resp(0, rd, resp);
    `FAIL_IF_LOG(resp !== RESP_SLVERR,
        $sformatf("tc08: expected SLVERR while busy, got resp=0x%0h", resp));
    // Cleanup: drain a bit and stop
    m0_axis_if.s_cb.tready <= 1'b1;
    repeat(DEPTH*2) @(m0_axis_if.s_cb);
    m0_axis_if.s_cb.tready <= 1'b0;
    reg_write(REG_MEM_START, 32'h0);
    repeat(10) @(posedge s_axi_aclk);
`SVTEST_END

// ----------------------------------------------------------------------------
// TEST 09: OKAY response on register and single access when not busy.
// ----------------------------------------------------------------------------
`SVTEST(tc09_okay_when_idle)
    logic [AXI_DW-1:0] rd;
    logic [1:0]        resp;
    // Ensure idle
    reg_write(REG_MEM_START, 32'h0);
    repeat(5) @(posedge s_axi_aclk);
    dmem_single_write(5, 32'h5555_AAAA);
    dmem_single_read_resp(5, rd, resp);
    `FAIL_IF_LOG(resp !== RESP_OKAY,
        $sformatf("tc09: expected OKAY when idle, got resp=0x%0h", resp));
    `FAIL_IF_LOG(rd !== 32'h5555_AAAA,
        $sformatf("tc09: data mismatch 0x%0h", rd));
`SVTEST_END
