// ============================================================================
// File: streamer_tc00.sv
// Project: QICK
// Description: SVUnit testbench top for streamer.
//
//   ASYNC_CLK  0 = single clock, s and m share 307.2 MHz (default, functional)
//              1 = s at 307.2 MHz, m at 100 MHz (CDC smoke test)
//   TB_N_FIFO  internal FIFO depth, default 16
//   TB_MEM     0 = let the RTL derive the storage type from the depth,
//              1 = distributed, 2 = block, 3 = ultra
//
//     make sim IP=streamer
//     make sim IP=streamer ASYNC=1
//     make sim IP=streamer FIFO=1024 MEM=block
//
//   KEEP THE DEPTH SMALL FOR THE FUNCTIONAL SUITE. tc05 deliberately overruns
//   the buffer, so a deep FIFO only makes the run longer without covering more
//   control logic; depth itself is already covered by the fifo_async suite.
//   What IS worth running once is a block-RAM build, because first-word
//   fall-through over BRAM adds internal output registers that LUTRAM does not
//   have. The tests that fill the FIFO scale themselves off N_FIFO.
//
//   WHY start_reg IS NOT PULSED
//     start_reg is a LEVEL enable. The FSM leaves RUN as soon as it reads back
//     zero, so a two-cycle pulse makes the block stop before it ever streams.
//     start_block() raises it and then waits until the WRITE side has actually
//     started capturing, which dbg_probe[3] (run_state_sclk) reports. Sending
//     data before that point is silently dropped, because s_axis_tready is
//     ~fifo_full and is not gated by the run state.
//
//   WHY THE MASTER IS DRIVEN BY HAND
//     send_words() drives s_axis_if.tvalid/tdata directly with an explicit AXI
//     handshake instead of calling tb_master.burst_tx(). The first attempt with
//     burst_tx lost the first beat and produced one extra beat at the end, and
//     the input monitor agreed with the DUT, so the mismatch was in the driver,
//     not in the block. A driver this small is worth owning here.
//
//   SCOREBOARD
//     Input monitor : a beat is stored only when fifo_wr_en is high and the
//                     FIFO is not full -> dbg_probe[4] && !dbg_probe[7].
//     Output monitor: every m_axis handshake pops the expected word and records
//                     the beat index of each tlast, so packet boundaries are
//                     checked separately from the payload.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

`ifndef ASYNC_CLK
  `define ASYNC_CLK 0
`endif
`ifndef TB_N_FIFO
  `define TB_N_FIFO 16
`endif
`ifndef TB_MEM
  `define TB_MEM 0
`endif

module streamer_unit_test;

  import svunit_pkg::svunit_testcase;

  svunit_testcase svunit_ut;
  string          name;

  //---------------------------------------------------------------------------
  // Configuration
  //---------------------------------------------------------------------------
  localparam int  B_TDATA = 16;
  localparam int  B_TUSER = 8;
  localparam int  B_AXIS  = 32;
  localparam int  N_FIFO  = `TB_N_FIFO;
  localparam int  W_IN    = B_TDATA + B_TUSER;   // packed {tuser, tdata}

  //! 0 selects the same expression the RTL uses by default.
  localparam      MEM_TYPE = (`TB_MEM == 1) ? "distributed" :
                             (`TB_MEM == 2) ? "block"       :
                             (`TB_MEM == 3) ? "ultra"       :
                             "auto";   //! matches the RTL default

  //! Overrun stimulus, sized off the buffer so tc05 stays meaningful at any
  //! depth: enough words to fill it with margin, then enough idle cycles for
  //! the drop counter to accumulate.
  localparam int  OVF_WORDS = N_FIFO + 32;
  localparam int  OVF_WAIT  = 200;

  localparam real S_FREQ  = 307.20e6;
  localparam real M_FREQ  = (`ASYNC_CLK != 0) ? 100.00e6 : 307.20e6;

  //! Generous, because a stop has to cross both directions of the CDC.
  localparam int  CDC_WAIT = 64;

  //---------------------------------------------------------------------------
  // Clocks and reset
  //---------------------------------------------------------------------------
  logic s_clk;
  logic m_clk;
  logic tb_rstn = 1'b0;

  clk_gen #(.FREQ(S_FREQ)) u_s_clk (.i_enable(1'b1), .o_clk(s_clk));

  generate
    if (`ASYNC_CLK != 0) begin : g_async_clk
      clk_gen #(.FREQ(M_FREQ)) u_m_clk (.i_enable(1'b1), .o_clk(m_clk));
    end
    else begin : g_single_clk
      assign m_clk = s_clk;
    end
  endgenerate

  //---------------------------------------------------------------------------
  // Interfaces
  //---------------------------------------------------------------------------
  //! TUSER is a real sideband here, not packed into the upper tdata bits as in
  //! the original testbench: that is how the block will be wired once the IP is
  //! packaged, and it is what makes the interface TUSER assertions meaningful.
  axi4_stream_if #(
    .TDATA_WIDTH (B_TDATA),
    .TUSER_WIDTH (B_TUSER),
    .HAS_TUSER   (1'b1)
  ) s_axis_if (
    .aclk    (s_clk  ),
    .aresetn (tb_rstn)
  );

  axi4_stream_if #(
    .TDATA_WIDTH (B_AXIS)
  ) m_axis_if (
    .aclk    (m_clk  ),
    .aresetn (tb_rstn)
  );

  //---------------------------------------------------------------------------
  // Control registers
  //---------------------------------------------------------------------------
  logic        start_reg = 1'b0;
  logic        flush_reg = 1'b0;
  logic        mode_reg  = 1'b0;
  logic [31:0] nsamp_reg = 32'd0;

  logic [31:0] lost_reg;
  logic [31:0] dbg_probe;

  // Readable aliases for the debug probe bits used by the testbench.
  wire dbg_start_sync = dbg_probe[0];
  wire dbg_flush      = dbg_probe[1];
  wire dbg_mode       = dbg_probe[2];
  wire dbg_run_sclk   = dbg_probe[3];
  wire dbg_wr_en      = dbg_probe[4];
  wire dbg_rd_en      = dbg_probe[5];
  wire dbg_empty      = dbg_probe[6];
  wire dbg_full       = dbg_probe[7];
  wire [7:0] dbg_state = dbg_probe[15:8];

  localparam logic [7:0] ST_IDLE     = 8'h00;
  localparam logic [7:0] ST_RUN      = 8'h01;
  localparam logic [7:0] ST_WAIT_END = 8'h02;
  localparam logic [7:0] ST_END      = 8'h03;

  //---------------------------------------------------------------------------
  // Scoreboard state
  //---------------------------------------------------------------------------
  logic [W_IN-1:0] exp_q [$];   //! words the block actually stored
  int              last_pos_q[$]; //! beat index of every tlast seen
  bit              mon_en;
  int              sb_rx;       //! beats received
  int              sb_errors;
  int              sb_stored;   //! beats accepted into the FIFO
  int              sb_dropped;  //! beats offered while running but FIFO full

  //---------------------------------------------------------------------------
  // Waveforms
  //---------------------------------------------------------------------------
  //! Before any clock edge, so the interface reset assertions never see X.
  initial begin
    s_axis_if.tvalid = 1'b0;
    s_axis_if.tdata  = '0;
    s_axis_if.tuser  = '0;
    s_axis_if.tlast  = 1'b0;
    m_axis_if.tready = 1'b0;
  end

  initial begin
    $dumpfile("streamer.vcd");
    $dumpvars();
  end

  //---------------------------------------------------------------------------
  // DUT
  //---------------------------------------------------------------------------
  streamer #(
    .B_TDATA       (B_TDATA ),
    .B_TUSER       (B_TUSER ),
    .B_AXIS        (B_AXIS  ),
    .N_FIFO        (N_FIFO  ),
    .FIFO_MEM_TYPE (MEM_TYPE)
  ) dut (
    .s_axis_aresetn (tb_rstn                        ),
    .s_axis_aclk    (s_clk                          ),
    .s_axis_tvalid  (s_axis_if.tvalid               ),
    .s_axis_tready  (s_axis_if.tready               ),
    .s_axis_tdata   (s_axis_if.tdata                ),
    .s_axis_tuser   (s_axis_if.tuser                ),

    .m_axis_aresetn (tb_rstn                        ),
    .m_axis_aclk    (m_clk                          ),
    .m_axis_tvalid  (m_axis_if.tvalid               ),
    .m_axis_tready  (m_axis_if.tready               ),
    .m_axis_tdata   (m_axis_if.tdata                ),
    .m_axis_tlast   (m_axis_if.tlast                ),

    .start_reg      (start_reg                      ),
    .flush_reg      (flush_reg                      ),
    .mode_reg       (mode_reg                       ),
    .nsamp_reg      (nsamp_reg                      ),
    .lost_reg       (lost_reg                       ),
    .dbg_probe      (dbg_probe                      )
  );

  //---------------------------------------------------------------------------
  // Input monitor: what the block actually stored
  //---------------------------------------------------------------------------
  always @(posedge s_clk) begin
    if (mon_en && tb_rstn === 1'b1) begin
      if (dbg_wr_en === 1'b1 && dbg_full === 1'b0) begin
        exp_q.push_back({s_axis_if.tuser, s_axis_if.tdata});
        sb_stored++;
      end
      else if (dbg_wr_en === 1'b1 && dbg_full === 1'b1) begin
        sb_dropped++;
      end
    end
  end

  //---------------------------------------------------------------------------
  // Output monitor: what actually came out, and where the packet ends were
  //---------------------------------------------------------------------------
  always @(posedge m_clk) begin
    logic [W_IN-1:0] exp;
    if (mon_en && tb_rstn === 1'b1 &&
        m_axis_if.tvalid === 1'b1 && m_axis_if.tready === 1'b1) begin

      if (m_axis_if.tdata[B_AXIS-1:W_IN] !== '0) begin
        $display("[SB] beat %0d: unused tdata bits are not zero (0x%0h)",
                 sb_rx, m_axis_if.tdata);
        sb_errors++;
      end

      if (exp_q.size() == 0) begin
        $display("[SB] beat %0d: SPURIOUS output 0x%0h, nothing was stored",
                 sb_rx, m_axis_if.tdata[W_IN-1:0]);
        sb_errors++;
      end
      else begin
        exp = exp_q.pop_front();
        if (m_axis_if.tdata[W_IN-1:0] !== exp) begin
          $display("[SB] beat %0d: expected 0x%0h got 0x%0h",
                   sb_rx, exp, m_axis_if.tdata[W_IN-1:0]);
          sb_errors++;
        end
      end

      if (m_axis_if.tlast === 1'b1) last_pos_q.push_back(sb_rx);
      sb_rx++;
    end
  end

  //---------------------------------------------------------------------------
  // Protocol assertions
  //---------------------------------------------------------------------------
  //! Deliberately empty. axi4_stream_if ships AXI4STREAM_ERRM_TVALID_STABLE,
  //! TDATA_STABLE, TLAST_STABLE, TDATA_X, TLAST_X and TUSER_X under `ifdef
  //! SVUNIT, on BOTH interfaces. Keeping local copies here only duplicated the
  //! reports. Make sure -d SVUNIT is in xelab_options or none of them compile.

  //---------------------------------------------------------------------------
  // Scoreboard helpers
  //---------------------------------------------------------------------------
  task automatic sb_clear();
    exp_q.delete();
    last_pos_q.delete();
    sb_rx      = 0;
    sb_errors  = 0;
    sb_stored  = 0;
    sb_dropped = 0;
  endtask

  //! Payload check. Packet boundaries are checked per test via last_pos_q.
  task automatic sb_check(input string tag);
    `FAIL_IF_LOG(sb_errors != 0,
                 $sformatf("%s: %0d scoreboard errors (stored=%0d rx=%0d)",
                           tag, sb_errors, sb_stored, sb_rx))
  endtask

  //! Assert the exact set of tlast positions, e.g. '{3, 7} for two packets of 4.
  task automatic check_last_positions(input string tag, input int expected[]);
    `FAIL_IF_LOG(last_pos_q.size() != expected.size(),
                 $sformatf("%s: saw %0d tlast, expected %0d",
                           tag, last_pos_q.size(), expected.size()))
    foreach (expected[i]) begin
      if (i < last_pos_q.size()) begin
        `FAIL_IF_LOG(last_pos_q[i] != expected[i],
                     $sformatf("%s: tlast %0d at beat %0d, expected beat %0d",
                               tag, i, last_pos_q[i], expected[i]))
      end
    end
  endtask

  //---------------------------------------------------------------------------
  // Stimulus helpers
  //---------------------------------------------------------------------------
  function automatic logic [W_IN-1:0] make_word(input byte pattern, input int index);
    return {pattern, index[B_TDATA-1:0]};
  endfunction

  task automatic make_packet(input int ns, input byte pattern,
                             output logic [W_IN-1:0] packet[]);
    packet = new[ns];
    for (int i = 0; i < ns; i++) packet[i] = make_word(pattern, i);
  endtask

  //! Park every input-side signal at a known value.
  task automatic axis_master_idle();
    s_axis_if.tvalid <= 1'b0;
    s_axis_if.tdata  <= '0;
    s_axis_if.tuser  <= '0;
    s_axis_if.tlast  <= 1'b0;
  endtask

  //! Drive one word per clock, holding tvalid/tdata until tready is sampled
  //! high, which is the AXI rule the block relies on.
  //! Every master signal the interface asserts on must be driven, tlast and
  //! tuser included, or they sit at X and AXI4STREAM_ERRM_*_X fires on every
  //! beat. tlast stays low: this block builds its own packet boundaries from
  //! nsamp_reg and ignores the input tlast entirely.
  task automatic send_words(input logic [W_IN-1:0] words[]);
    foreach (words[i]) begin
      s_axis_if.tvalid <= 1'b1;
      s_axis_if.tdata  <= words[i][B_TDATA-1:0];
      s_axis_if.tuser  <= words[i][W_IN-1:B_TDATA];
      s_axis_if.tlast  <= 1'b0;
      @(posedge s_clk);
      while (s_axis_if.tready !== 1'b1) @(posedge s_clk);
    end
    s_axis_if.tvalid <= 1'b0;
    s_axis_if.tdata  <= '0;
    s_axis_if.tuser  <= '0;
  endtask

  task automatic dut_reset();
    mon_en    = 1'b0;
    tb_rstn  <= 1'b0;
    start_reg<= 1'b0;
    flush_reg<= 1'b0;
    mode_reg <= 1'b0;
    nsamp_reg<= 32'd0;
    m_axis_if.tready <= 1'b0;
    axis_master_idle();
    repeat (5) @(posedge s_clk);
    repeat (5) @(posedge m_clk);
    tb_rstn  <= 1'b1;
    repeat (CDC_WAIT) @(posedge m_clk);
    sb_clear();
    mon_en = 1'b1;
  endtask

  task automatic set_params(input int nsamp, input bit mode, input bit flush = 1'b0);
    nsamp_reg <= nsamp;
    mode_reg  <= mode;
    flush_reg <= flush;
    @(posedge m_clk);
  endtask

  //! Raise the level enable and wait until the WRITE side is really capturing.
  task automatic start_block(input int timeout = 1000);
    int t;
    t = 0;
    @(posedge m_clk);
    start_reg <= 1'b1;
    while (dbg_run_sclk !== 1'b1) begin
      @(posedge s_clk);
      if (++t > timeout) begin
        $display("[TB] start_block timed out, state=0x%0h", dbg_state);
        return;
      end
    end
    repeat (2) @(posedge s_clk);
  endtask

  task automatic stop_block();
    @(posedge m_clk);
    start_reg <= 1'b0;
  endtask

  //! Wait for the FSM to be back in IDLE after a stop.
  task automatic wait_idle(output bit ok, input int timeout = 5000);
    int t;
    t  = 0;
    ok = 1'b1;
    while (dbg_state !== ST_IDLE) begin
      @(posedge m_clk);
      if (++t > timeout) begin
        ok = 1'b0;
        $display("[TB] wait_idle timed out in state 0x%0h", dbg_state);
        return;
      end
    end
  endtask

  //! Wait until the FSM has actually left RUN. start_reg crosses two flops, so
  //! the block keeps streaming normally for a few cycles after stop_block():
  //! opening the sink before this returns lets legitimate RUN traffic out.
  task automatic wait_left_run(output bit ok, input int timeout = 1000);
    int t;
    t  = 0;
    ok = 1'b1;
    while (dbg_state === ST_RUN) begin
      @(posedge m_clk);
      if (++t > timeout) begin
        ok = 1'b0;
        $display("[TB] wait_left_run timed out, state=0x%0h", dbg_state);
        return;
      end
    end
  endtask

  task automatic set_tready(input bit v);
    m_axis_if.tready <= v;
  endtask

  //! Receive one beat by observing the handshake. Does not fight the interface
  //! for tready: the test owns that signal.
  task automatic recv_beat(output logic [B_AXIS-1:0] d,
                           output logic             last,
                           output bit               ok,
                           input  int               timeout = 5000);
    int t;
    t    = 0;
    ok   = 1'b0;
    d    = 'x;
    last = 1'bx;
    forever begin
      @(posedge m_clk);
      if (m_axis_if.tvalid === 1'b1 && m_axis_if.tready === 1'b1) begin
        d    = m_axis_if.tdata;
        last = m_axis_if.tlast;
        ok   = 1'b1;
        return;
      end
      if (++t > timeout) return;
    end
  endtask

  //! Check that nothing is offered for a while.
  task automatic expect_quiet(input int cycles, input string tag);
    repeat (cycles) begin
      @(posedge m_clk);
      `FAIL_IF_LOG(m_axis_if.tvalid === 1'b1,
                   $sformatf("%s: unexpected tvalid while the block should be quiet", tag))
    end
  endtask

  //---------------------------------------------------------------------------
  // SVUnit boilerplate
  //---------------------------------------------------------------------------
  function void build();
    name = $sformatf("streamer_ut_%0s_N%0d_%0s",
                     (`ASYNC_CLK != 0) ? "async" : "sync", N_FIFO, MEM_TYPE);
    svunit_ut = new(name);
  endfunction

  initial begin
    $display("[CFG] streamer TB: s_clk=%.2f MHz  m_clk=%.2f MHz  N_FIFO=%0d  MEM=%0s",
             S_FREQ/1.0e6, M_FREQ/1.0e6, N_FIFO, MEM_TYPE);
  end

  task setup();
    svunit_ut.setup();
    dut_reset();
  endtask

  task teardown();
    svunit_ut.teardown();
    mon_en = 1'b0;
    start_reg <= 1'b0;
    axis_master_idle();
    set_tready(1'b0);
    repeat (5) @(posedge m_clk);
  endtask

  initial begin
    #20ms;
    $display("[TB] GLOBAL TIMEOUT reached");
    $finish;
  end

  `SVUNIT_TESTS_BEGIN
  `include "streamer_tests.sv"
  `SVUNIT_TESTS_END

endmodule

