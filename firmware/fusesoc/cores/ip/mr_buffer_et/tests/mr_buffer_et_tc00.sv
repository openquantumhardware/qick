// ============================================================================
// File: mr_buffer_et_tc00.sv
// Description: SVUnit testbench top-level for mr_buffer_et.
//
// Rewritten to drive both AXI4-Stream interfaces exclusively through the
// axi4_stream_if verification API (m_reset / tx / burst_rx) and the AXI4-Lite
// interface through axi_write / axi_read.  No raw-signal sampling anywhere in
// the checkers: every sampled value comes from a clocking block, which is what
// makes the results independent of simulator delta ordering.
//
//   Register map (AXI_DW=32, AXI_AW=6, byte-addressed, ADDR_LSB=2):
//     0x00  reg 0   dw_capture_reg : bit 0 = capture enable
//     0x04  reg 1   dr_start_reg   : bit 0 = read start
//     0x08  reg 2   status         : bit 0 = capture_done (RO)
//     0x3C  reg 15  debug_reg      : bit 0 = force trigger, bit 1 = tready force
//
// Three independent clock domains:
//   s_axi_aclk   (AXI_FREQ)    : AXI4-Lite register access
//   s_axis_aclk  (S_AXIS_FREQ) : write-side data capture
//   m_axis_aclk  (M_AXIS_FREQ) : read-side data output
//
// Read-burst protocol (bram_to_axis_nt):
//   One dr_start_reg write triggers a burst of TOTAL_WORDS = NM * 2**N beats.
//   Word order: ch0@addr0, ch1@addr0, ..., ch(NM-1)@addr0,
//               ch0@addr1, ..., ch(NM-1)@addr(2**N-1)  <- tlast
//   The whole burst MUST be consumed before dr_start_reg is written again,
//   otherwise leftover beats in the reader FIFO poison the next burst.
//   burst_rx() consumes up to tlast, so it enforces this by construction as
//   long as the returned beat count is checked.
//
// NOTE: s_reset() is deliberately NOT used on m_axis_if.  It leaves tready
// asserted, which would let a burst drain into nowhere while the test is busy
// elsewhere.  The sink is held idle explicitly instead.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module mr_buffer_et_unit_test;

    import svunit_pkg::svunit_testcase;

    string name = "mr_buffer_et_tests";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real AXI_FREQ    = 100e6;
    localparam real S_AXIS_FREQ = 150e6;
    localparam real M_AXIS_FREQ = 200e6;

    `ifndef MRBUF_NM
      `define MRBUF_NM 8
    `endif
    
    `ifndef MRBUF_N
      `define MRBUF_N  8
    `endif

    localparam int NM         = `MRBUF_NM;
    localparam int N          = `MRBUF_N;
    localparam int B          = 16;
    localparam int C_S_AXI_DW = 32;
    localparam int C_S_AXI_AW = 6;

    localparam int S_DATA_W    = NM * B;
    localparam int M_DATA_W    = B;   // mr_buffer_et output bus width
    localparam int DEPTH       = 2**N;
    localparam int TOTAL_WORDS = DEPTH * NM;

    // Per-channel offset used by send_beat: ch[i] = ch0 + i*CH_OFFSET
    localparam logic [B-1:0] CH_OFFSET = 16'h1000;

    // AXI4-Lite register byte addresses
    localparam logic [C_S_AXI_AW-1:0] REG_DW_CAPTURE = 6'h00;
    localparam logic [C_S_AXI_AW-1:0] REG_DR_START   = 6'h04;
    localparam logic [C_S_AXI_AW-1:0] REG_STATUS     = 6'h08;
    localparam logic [C_S_AXI_AW-1:0] REG_DEBUG      = 6'h3C;

    // axis_to_bram_trig FSM encoding (white-box handshake with the DUT)
    localparam int unsigned WR_INIT_ST    = 0;
    localparam int unsigned WR_TRIGGER_ST = 1;
    localparam int unsigned WR_CAPTURE_ST = 2;

    // =========================================================================
    // Clocks & Resets
    // =========================================================================
    logic s_axi_aclk     = 1'b0;
    logic s_axi_aresetn  = 1'b1;
    logic s_axis_aclk    = 1'b0;
    logic s_axis_aresetn = 1'b1;
    logic m_axis_aclk    = 1'b0;
    logic m_axis_aresetn = 1'b1;

    logic trigger = 1'b0;

    // =========================================================================
    // Interfaces
    // =========================================================================
    axi4_lite_if #(
        .DATA_WIDTH (C_S_AXI_DW),
        .ADDR_WIDTH (C_S_AXI_AW)
    ) s_axi (
        .aclk    (s_axi_aclk),
        .aresetn (s_axi_aresetn)
    );

    axi4_stream_if #(
        .TDATA_WIDTH (S_DATA_W),
        .HAS_TSTRB   (1'b1),
        .HAS_TKEEP   (1'b0),
        .HAS_TID     (1'b0),
        .HAS_TDEST   (1'b0),
        .HAS_TUSER   (1'b0)
    ) s_axis_if (
        .aclk    (s_axis_aclk),
        .aresetn (s_axis_aresetn)
    );

    axi4_stream_if #(
        .TDATA_WIDTH (M_DATA_W),
        .HAS_TSTRB   (1'b1),
        .HAS_TKEEP   (1'b0),
        .HAS_TID     (1'b0),
        .HAS_TDEST   (1'b0),
        .HAS_TUSER   (1'b0)
    ) m_axis_if (
        .aclk    (m_axis_aclk),
        .aresetn (m_axis_aresetn)
    );

    // =========================================================================
    // Clock generators
    // =========================================================================
    clk_gen #(.FREQ (AXI_FREQ))    u_clk_axi (.i_enable(1'b1), .o_clk(s_axi_aclk));
    clk_gen #(.FREQ (S_AXIS_FREQ)) u_clk_s   (.i_enable(1'b1), .o_clk(s_axis_aclk));
    clk_gen #(.FREQ (M_AXIS_FREQ)) u_clk_m   (.i_enable(1'b1), .o_clk(m_axis_aclk));

    // =========================================================================
    // Waveform dump
    // =========================================================================
    initial begin
        $dumpfile("mr_buffer_et.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    mr_buffer_et #(
        .NM         (NM),
        .N          (N),
        .B          (B),
        .C_S_AXI_DW (C_S_AXI_DW),
        .C_S_AXI_AW (C_S_AXI_AW),
        .DEBUG      (0)
    ) dut (
        .s_axi_aclk    (s_axi_aclk),
        .s_axi_aresetn (s_axi_aresetn),
        .s_axi_awaddr  (s_axi.awaddr),
        .s_axi_awprot  (s_axi.awprot),
        .s_axi_awvalid (s_axi.awvalid),
        .s_axi_awready (s_axi.awready),
        .s_axi_wdata   (s_axi.wdata),
        .s_axi_wstrb   (s_axi.wstrb),
        .s_axi_wvalid  (s_axi.wvalid),
        .s_axi_wready  (s_axi.wready),
        .s_axi_bresp   (s_axi.bresp),
        .s_axi_bvalid  (s_axi.bvalid),
        .s_axi_bready  (s_axi.bready),
        .s_axi_araddr  (s_axi.araddr),
        .s_axi_arprot  (s_axi.arprot),
        .s_axi_arvalid (s_axi.arvalid),
        .s_axi_arready (s_axi.arready),
        .s_axi_rdata   (s_axi.rdata),
        .s_axi_rresp   (s_axi.rresp),
        .s_axi_rvalid  (s_axi.rvalid),
        .s_axi_rready  (s_axi.rready),
        .s_axis_aclk    (s_axis_aclk),
        .s_axis_aresetn (s_axis_aresetn),
        .s_axis_tdata   (s_axis_if.tdata),
        .s_axis_tstrb   (s_axis_if.tstrb),
        .s_axis_tvalid  (s_axis_if.tvalid),
        .s_axis_tlast   (s_axis_if.tlast),
        .s_axis_tready  (s_axis_if.tready),
        .m_axis_aclk    (m_axis_aclk),
        .m_axis_aresetn (m_axis_aresetn),
        .m_axis_tdata   (m_axis_if.tdata),
        .m_axis_tstrb   (m_axis_if.tstrb),
        .m_axis_tvalid  (m_axis_if.tvalid),
        .m_axis_tlast   (m_axis_if.tlast),
        .m_axis_tready  (m_axis_if.tready),
        .trigger        (trigger),
        .s_dbg_probe    (),
        .m_dbg_probe    ()
    );

    // =========================================================================
    // AXI4-Lite register access helpers
    // =========================================================================
    task automatic set_capture(input logic val);
        s_axi.axi_write(REG_DW_CAPTURE, C_S_AXI_DW'({31'b0, val}));
    endtask

    task automatic set_start(input logic val);
        s_axi.axi_write(REG_DR_START, C_S_AXI_DW'({31'b0, val}));
    endtask

    task automatic set_debug(input logic [C_S_AXI_DW-1:0] val);
        s_axi.axi_write(REG_DEBUG, val);
    endtask

    task automatic read_reg(
        input  logic [C_S_AXI_AW-1:0]  addr,
        output logic [C_S_AXI_DW-1:0]  data
    );
        s_axi.axi_read(addr, data);
    endtask

    // =========================================================================
    // Write-side FSM handshake helpers (white-box)
    // =========================================================================

    // wait_wr_state: block until channel 0's capture FSM reaches `st`, with a
    // hard timeout so a stuck FSM fails the test instead of hanging the run.
    task automatic wait_wr_state(input int unsigned st, input int timeout = 2000);
        int cnt = 0;
        while (dut.mr_buffer_i.gen_channel[0].u_axis_to_bram_trig.current_state !== st) begin
            @(posedge s_axis_aclk);
            if (++cnt > timeout)
                $fatal(1, "[TB_FATAL] capture FSM did not reach state %0d (stuck in %0d)",
                       st, dut.mr_buffer_i.gen_channel[0].u_axis_to_bram_trig.current_state);
        end
    endtask

    // arm_and_trigger: arm the writer over AXI, wait for TRIGGER_ST, then pulse
    // the hardware trigger and wait for CAPTURE_ST.
    task automatic arm_and_trigger();
        set_capture(1'b1);
        wait_wr_state(WR_TRIGGER_ST);
        repeat (2) @(posedge s_axis_aclk);

        trigger <= 1'b1;
        @(posedge s_axis_aclk);
        trigger <= 1'b0;

        wait_wr_state(WR_CAPTURE_ST);
        repeat (2) @(posedge s_axis_aclk);
    endtask

    // disarm: drop capture over AXI; the abort path in axis_to_bram_trig drains
    // the FIFO and returns the FSM to INIT_ST on its own.
    task automatic disarm();
        set_capture(1'b0);
        wait_wr_state(WR_INIT_ST);
        repeat (5) @(posedge s_axis_aclk);
    endtask

    // =========================================================================
    // Stimulus helpers
    // =========================================================================

    // build_word: pack NM channel values (B bits each) into S_DATA_W bits.
    // ch[0] -> bits [B-1:0] (lowest, first word on the read side).
    function automatic logic [S_DATA_W-1:0] build_word(logic [B-1:0] ch [NM]);
        logic [S_DATA_W-1:0] w = '0;
        for (int i = 0; i < NM; i++)
            w[(i+1)*B-1 -: B] = ch[i];
        return w;
    endfunction

    // exp_ch: expected value for channel `ch` given the channel-0 value.
    function automatic logic [B-1:0] exp_ch(input logic [B-1:0] ch0_val, input int ch);
        return ch0_val + B'(ch) * CH_OFFSET;
    endfunction

    // send_beat: one S_DATA_W-bit beat on s_axis.  tx() drives tdata, tlast,
    // tvalid and tstrb and blocks until the handshake completes.
    task automatic send_beat(input logic [B-1:0] ch0_val, input logic last);
        logic [B-1:0] ch [NM];
        for (int i = 0; i < NM; i++)
            ch[i] = exp_ch(ch0_val, i);
        s_axis_if.tx(build_word(ch), last);
    endtask

    // do_capture: arm, trigger, send one beat, let the write pipeline settle,
    // disarm, then allow CDC margin into the read domain.
    task automatic do_capture(input logic [B-1:0] ch0_val);
        arm_and_trigger();
        send_beat(ch0_val, 1'b1);
        repeat (20) @(posedge s_axis_aclk);   // FIFO + BRAM write latency
        disarm();
        repeat (50) @(posedge m_axis_aclk);   // CDC margin
    endtask

    // =========================================================================
    // Read-side helpers
    // =========================================================================

    task automatic start_reader();
        set_start(1'b1);
        repeat (5) @(posedge m_axis_aclk);    // CDC into the read domain
    endtask

    task automatic stop_reader();
        set_start(1'b0);
        repeat (5) @(posedge m_axis_aclk);
    endtask

    // drain_burst: consume one full burst with burst_rx(), which holds tready
    // high and stops on tlast.  The returned queue length IS the tlast position
    // check: a short queue means tlast came early, and the $fatal inside
    // burst_rx covers the case where it never came at all.
    task automatic drain_burst(output logic [M_DATA_W-1:0] beats [$]);
        m_axis_if.burst_rx(beats);
    endtask

    // =========================================================================
    // SVUnit
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();

        // Park every TB-driven bus in a legal idle state BEFORE reset is
        // asserted.  Blocking assignments on the raw signals are used here on
        // purpose: m_reset() blocks until aresetn is high, so it cannot be the
        // thing that clears tvalid for the reset window itself.
        s_axis_if.tvalid = 1'b0;
        s_axis_if.tlast  = 1'b0;
        s_axis_if.tdata  = '0;
        s_axis_if.tstrb  = '1;
        s_axis_if.tkeep  = '0;
        s_axis_if.tuser  = '0;
        s_axis_if.tid    = '0;
        s_axis_if.tdest  = '0;
        m_axis_if.tready = 1'b0;
        trigger          = 1'b0;

        // Reset all three domains simultaneously
        s_axi_aresetn    = 1'b0;
        s_axis_aresetn   = 1'b0;
        m_axis_aresetn   = 1'b0;
        repeat (50) @(posedge s_axi_aclk);
        s_axi_aresetn    = 1'b1;
        s_axis_aresetn   = 1'b1;
        m_axis_aresetn   = 1'b1;

        // Hand the buses over to the clocking-block drivers.
        // NOTE: m_axis_if.s_reset() is intentionally not called — it leaves
        // tready asserted, which would silently drain a burst.
        s_axis_if.m_reset();
        s_axi.reset();

        // Allow XPM FIFOs, sync chains and axil_slv to settle
        repeat (50) @(posedge s_axi_aclk);
    endtask

    task teardown();
        svunit_ut.teardown();
        // Leave the master idle so the next setup()'s reset window is clean
        s_axis_if.idle();
        m_axis_if.s_cb.tready <= 1'b0;
    endtask

    // Global timeout
    initial begin
        #200_000_000;
        $display("INFO: Global timeout reached");
        $finish;
    end

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "mr_buffer_et_tests.sv"
    `SVUNIT_TESTS_END

endmodule