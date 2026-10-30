// ============================================================================
// File: mr_buffer_tc00.sv
// Description: SVUnit testbench top-level for the mr_buffer core.
//
// Brought in line with mr_buffer_et_tc00.sv:
//   - the s_axis master is parked in a legal idle state BEFORE reset, so the
//     protocol assertions (-d SVUNIT) do not fire on VALID_RST
//   - the DUT is connected to the plain interface signals, not to
//     modport-qualified expressions
//   - clocking blocks are used from the correct side: on s_axis the TB is the
//     MASTER (m_cb), on m_axis the TB is the SLAVE (s_cb).  Plain control
//     signals that are not part of either interface are timed off the raw
//     clock instead
//   - the read burst is drained with burst_rx(), not with a loop of rx().
//     rx() is a single-beat API: back-to-back calls cannot guarantee the
//     tready gap between them, so the DUT free-runs and beats are missed
//
// Output word order (TOTAL_WORDS = NM * 2**N words per read burst):
//   word 0            : ch0 @ addr 0
//   word NM-1         : ch(NM-1) @ addr 0
//   word NM           : ch0 @ addr 1
//   word NM*2**N - 1  : ch(NM-1) @ addr (2**N - 1)   <- tlast here
//
// Every start_reader() emits exactly TOTAL_WORDS beats ending in tlast.
// Consume the whole burst before stop_reader(), or the leftover beats poison
// the next one.  burst_rx() enforces this as long as the beat count is checked.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module mr_buffer_unit_test;

    import svunit_pkg::svunit_testcase;

    string name = "mr_buffer_tests";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters — must match the DUT instantiation below
    // =========================================================================
    localparam real CLK_S_FREQ = 150e6;
    localparam real CLK_M_FREQ = 200e6;

    localparam int NM = 8;
    localparam int N  = 8;
    localparam int B  = 16;

    localparam int S_DATA_W    = NM * B;
    localparam int M_DATA_W    = B;
    localparam int DEPTH       = 2**N;         // per-BRAM depth
    localparam int TOTAL_WORDS = DEPTH * NM;   // words per read burst

    // Per-channel offset used by send_beat: ch[i] = ch0 + i*CH_OFFSET
    localparam logic [B-1:0] CH_OFFSET = 16'h1000;

    // axis_to_bram_trig FSM encoding (white-box handshake with the DUT)
    localparam int unsigned WR_INIT_ST    = 0;
    localparam int unsigned WR_TRIGGER_ST = 1;
    localparam int unsigned WR_CAPTURE_ST = 2;

    // =========================================================================
    // Clocks & Resets
    // =========================================================================
    logic s_axis_aclk    = 1'b0;
    logic s_axis_aresetn = 1'b1;
    logic m_axis_aclk    = 1'b0;
    logic m_axis_aresetn = 1'b1;

    // =========================================================================
    // Control signals
    // =========================================================================
    logic        trigger        = 1'b0;
    logic        dw_capture_reg = 1'b0;
    logic        dr_start_reg   = 1'b0;
    logic [31:0] debug_reg      = '0;
    logic        o_capture_done;

    // Debug probes (wired but not checked)
    logic [31:0] s_dbg_probe;
    logic [31:0] m_dbg_probe;

    // Sticky observation of o_capture_done — the flag is a level that is only
    // high while the writer sits in END_ST, so it has to be caught as it goes by
    logic saw_capture_done = 1'b0;
    always @(posedge s_axis_aclk)
        if (o_capture_done) saw_capture_done <= 1'b1;

    // =========================================================================
    // AXI4-Stream interfaces
    // =========================================================================
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
    clk_gen #(.FREQ (CLK_S_FREQ)) u_clk_s (.i_enable(1'b1), .o_clk(s_axis_aclk));
    clk_gen #(.FREQ (CLK_M_FREQ)) u_clk_m (.i_enable(1'b1), .o_clk(m_axis_aclk));

    // =========================================================================
    // Waveform dump
    // =========================================================================
    initial begin
        $dumpfile("mr_buffer.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    mr_buffer #(
        .NM (NM),
        .N  (N),
        .B  (B)
    ) dut (
        .trigger        (trigger),
        .s_axis_aclk    (s_axis_aclk),
        .s_axis_aresetn (s_axis_aresetn),
        .s_axis_tready  (s_axis_if.tready),
        .s_axis_tdata   (s_axis_if.tdata),
        .s_axis_tstrb   (s_axis_if.tstrb),
        .s_axis_tlast   (s_axis_if.tlast),
        .s_axis_tvalid  (s_axis_if.tvalid),
        .m_axis_aclk    (m_axis_aclk),
        .m_axis_aresetn (m_axis_aresetn),
        .m_axis_tvalid  (m_axis_if.tvalid),
        .m_axis_tdata   (m_axis_if.tdata),
        .m_axis_tstrb   (m_axis_if.tstrb),
        .m_axis_tlast   (m_axis_if.tlast),
        .m_axis_tready  (m_axis_if.tready),
        .dw_capture_reg (dw_capture_reg),
        .dr_start_reg   (dr_start_reg),
        .debug_reg      (debug_reg),
        .s_dbg_probe    (s_dbg_probe),
        .m_dbg_probe    (m_dbg_probe),
        .o_capture_done (o_capture_done)
    );

    // =========================================================================
    // Write-side FSM handshake helpers (white-box)
    // =========================================================================

    task automatic wait_wr_state(input int unsigned st, input int timeout = 2000);
        int cnt = 0;
        while (dut.gen_channel[0].u_axis_to_bram_trig.current_state !== st) begin
            @(posedge s_axis_aclk);
            if (++cnt > timeout)
                $fatal(1, "[TB_FATAL] capture FSM did not reach state %0d (stuck in %0d)",
                       st, dut.gen_channel[0].u_axis_to_bram_trig.current_state);
        end
    endtask

    // arm_and_trigger: raise capture_reg, wait for TRIGGER_ST, pulse the
    // hardware trigger, wait for CAPTURE_ST.  Waiting on the FSM instead of
    // counting CDC cycles keeps this correct at any clock ratio.
    task automatic arm_and_trigger();
        @(posedge s_axis_aclk);
        dw_capture_reg <= 1'b1;
        wait_wr_state(WR_TRIGGER_ST);
        repeat (2) @(posedge s_axis_aclk);

        trigger <= 1'b1;
        @(posedge s_axis_aclk);
        trigger <= 1'b0;

        wait_wr_state(WR_CAPTURE_ST);
        repeat (2) @(posedge s_axis_aclk);
    endtask

    // disarm: drop capture_reg; the abort path drains the internal FIFO and
    // returns the FSM to INIT_ST on its own.
    task automatic disarm();
        @(posedge s_axis_aclk);
        dw_capture_reg <= 1'b0;
        wait_wr_state(WR_INIT_ST);
        repeat (5) @(posedge s_axis_aclk);
    endtask

    // =========================================================================
    // Stimulus helpers
    // =========================================================================

    // build_word: pack NM channel values (B bits each) into S_DATA_W bits.
    // ch[0] -> bits [B-1:0] (lowest channel, first word on the read side).
    function automatic logic [S_DATA_W-1:0] build_word(logic [B-1:0] ch [NM]);
        logic [S_DATA_W-1:0] w = '0;
        for (int i = 0; i < NM; i++)
            w[(i+1)*B-1 -: B] = ch[i];
        return w;
    endfunction

    // exp_ch: expected value on channel `ch` for a given channel-0 value.
    function automatic logic [B-1:0] exp_ch(input logic [B-1:0] ch0_val, input int ch);
        return ch0_val + B'(ch) * CH_OFFSET;
    endfunction

    // send_beat: one S_DATA_W-bit beat on s_axis.  tx() drives tdata, tlast,
    // tvalid and tstrb and blocks until the handshake actually completes.
    task automatic send_beat(input logic [B-1:0] ch0_val, input logic last);
        logic [B-1:0] ch [NM];
        for (int i = 0; i < NM; i++)
            ch[i] = exp_ch(ch0_val, i);
        s_axis_if.tx(build_word(ch), last);
    endtask

    // do_capture: arm, trigger, one beat, settle, disarm, CDC margin.
    task automatic do_capture(input logic [B-1:0] ch0_val);
        arm_and_trigger();
        send_beat(ch0_val, 1'b1);
        repeat (20) @(posedge s_axis_aclk);   // FIFO + BRAM write latency
        disarm();
        repeat (50) @(posedge m_axis_aclk);   // CDC margin into the read domain
    endtask

    // =========================================================================
    // Read-side helpers
    // =========================================================================

    task automatic start_reader();
        @(posedge m_axis_aclk);
        dr_start_reg <= 1'b1;
        repeat (5) @(posedge m_axis_aclk);
    endtask

    task automatic stop_reader();
        @(posedge m_axis_aclk);
        dr_start_reg <= 1'b0;
        repeat (5) @(posedge m_axis_aclk);
    endtask

    // drain_burst: consume one whole burst.  burst_rx() holds tready high for
    // the entire packet and stops on tlast, so the returned length IS the tlast
    // position check; a burst with no tlast at all hits the $fatal inside it.
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
        // asserted.  Blocking assignments on the raw signals on purpose:
        // m_reset() blocks until aresetn is high, so it cannot be what clears
        // tvalid for the reset window itself.
        s_axis_if.tvalid = 1'b0;
        s_axis_if.tlast  = 1'b0;
        s_axis_if.tdata  = '0;
        s_axis_if.tstrb  = '1;
        s_axis_if.tkeep  = '0;
        s_axis_if.tuser  = '0;
        s_axis_if.tid    = '0;
        s_axis_if.tdest  = '0;
        m_axis_if.tready = 1'b0;

        dw_capture_reg   = 1'b0;
        dr_start_reg     = 1'b0;
        trigger          = 1'b0;
        debug_reg        = '0;
        saw_capture_done = 1'b0;

        // Reset both domains
        s_axis_aresetn = 1'b0;
        m_axis_aresetn = 1'b0;
        repeat (20) begin
            @(posedge s_axis_aclk);
            @(posedge m_axis_aclk);
        end
        s_axis_aresetn = 1'b1;
        m_axis_aresetn = 1'b1;

        // Hand the write side over to the clocking-block driver.
        // NOTE: m_axis_if.s_reset() is deliberately NOT called — it leaves
        // tready asserted, which would silently drain a burst.
        s_axis_if.m_reset();

        // Allow XPM FIFOs and synchronisers to settle
        repeat (20) @(posedge s_axis_aclk);
        repeat (20) @(posedge m_axis_aclk);
    endtask

    task teardown();
        svunit_ut.teardown();
        s_axis_if.idle();
        m_axis_if.s_cb.tready <= 1'b0;
    endtask

    // Global timeout
    initial begin
        #100_000_000;
        $display("INFO: Global timeout reached");
        $finish;
    end

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "mr_buffer_tests.sv"
    `SVUNIT_TESTS_END

endmodule