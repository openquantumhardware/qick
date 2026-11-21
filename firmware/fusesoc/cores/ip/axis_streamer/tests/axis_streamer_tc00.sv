// ============================================================================
// File: axis_streamer_tc00.sv
// Project: QICK
// Description: SVUnit integration testbench for the axis_streamer IP.
//
//   Three asynchronous domains: s_axi_aclk (100 MHz), s_axis_aclk (150 MHz),
//   m_axis_aclk (200 MHz). Configuration goes in over AXI4-Lite, data over
//   s_axis, results come out on m_axis.
//
//   START IS A LEVEL, AND IT CROSSES THREE DOMAINS
//     s_axi register -> cdc_bit_sync to m_axis -> cdc_bit_sync to s_axis.
//     That is four to six flops, so a fixed "repeat(10)" after the register
//     write is a guess, not a handshake. start_block() waits for
//     dbg_probe[3] (run_state_sclk), which is the WRITE side reporting that it
//     has started capturing. Data pushed before that point is accepted on the
//     bus and silently dropped, because s_axis_tready is ~fifo_full and is not
//     gated by the run state.
//
//   SCOREBOARD
//     Input monitor : records a beat only when the core actually stored it,
//                     dbg_probe[4] (fifo_wr_en) high with dbg_probe[7]
//                     (fifo_full) low.
//     Output monitor: every m_axis handshake pops the expected word, checks the
//                     payload, checks that the unused tdata bits are zero, and
//                     records the beat index of each tlast so packet boundaries
//                     are verified separately from the data.
//
//   TUSER IS A REAL SIDEBAND HERE, not packed into the upper tdata bits. That
//   is how Vivado will infer the interface once the IP is packaged, and it is
//   what makes the interface TUSER assertions do any work.
//
//   TB_N_FIFO / TB_MEM select the buffer depth and its storage type:
//     make sim IP=axis_streamer
//     make sim IP=axis_streamer FIFO=1024 MEM=block
//   TB_MEM 0 lets the RTL derive the type from the depth, 1 = distributed,
//   2 = block, 3 = ultra. Keep the depth small for the functional suite: the
//   overrun tests scale themselves off it, so a deep buffer only lengthens the
//   run. A block-RAM build is worth running once, since first-word
//   fall-through over BRAM adds output registers that LUTRAM does not have.
//
//   Requires -d SVUNIT in xelab_options, otherwise the protocol assertions
//   inside axi4_stream_if are not compiled.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

`ifndef TB_N_FIFO
  `define TB_N_FIFO 16
`endif
`ifndef TB_MEM
  `define TB_MEM 0
`endif

module axis_streamer_unit_test;

  import svunit_pkg::svunit_testcase;

  string          name;
  svunit_testcase svunit_ut;

  //---------------------------------------------------------------------------
  // Configuration
  //---------------------------------------------------------------------------
  localparam real AXI_FREQ    = 100.0e6;
  localparam real S_AXIS_FREQ = 150.0e6;
  localparam real M_AXIS_FREQ = 200.0e6;

  localparam int  B_TDATA = 16;
  localparam int  B_TUSER = 8;
  localparam int  B_AXIS  = 32;
  localparam int  N_FIFO  = `TB_N_FIFO;
  localparam int  W_IN    = B_TDATA + B_TUSER;

  //! 0 selects the same expression the RTL uses by default.
  localparam      MEM_TYPE = (`TB_MEM == 1) ? "distributed" :
                             (`TB_MEM == 2) ? "block"       :
                             (`TB_MEM == 3) ? "ultra"       :
                             "auto";   //! matches the RTL default

  //! Overrun stimulus, sized off the buffer so the LOST tests stay meaningful
  //! at any depth.
  localparam int  OVF_WORDS = N_FIFO + 48;
  localparam int  OVF_WAIT  = 400;

  //! Register byte addresses.
  localparam logic [5:0] REG_START  = 6'h00;
  localparam logic [5:0] REG_FLUSH  = 6'h04;
  localparam logic [5:0] REG_MODE   = 6'h08;
  localparam logic [5:0] REG_NSAMP  = 6'h0C;
  localparam logic [5:0] REG_LOST   = 6'h10;
  localparam logic [5:0] REG_STATUS = 6'h14;

  //! STATUS bit positions.
  localparam int ST_RUNNING = 0;
  localparam int ST_DONE    = 1;
  localparam int ST_IDLE    = 2;
  localparam int ST_OVF     = 3;
  localparam int ST_FULL    = 4;
  localparam int ST_EMPTY   = 5;

  //! Generous: a stop has to travel out to the write side and back.
  localparam int CDC_WAIT = 64;

  //---------------------------------------------------------------------------
  // Clocks and resets
  //---------------------------------------------------------------------------
  logic s_axi_aclk;
  logic s_axis_aclk;
  logic m_axis_aclk;

  logic s_axi_aresetn  = 1'b0;
  logic s_axis_aresetn = 1'b0;
  logic m_axis_aresetn = 1'b0;

  clk_gen #(.FREQ(AXI_FREQ   )) u_axi_clk (.i_enable(1'b1), .o_clk(s_axi_aclk ));
  clk_gen #(.FREQ(S_AXIS_FREQ)) u_s_clk   (.i_enable(1'b1), .o_clk(s_axis_aclk));
  clk_gen #(.FREQ(M_AXIS_FREQ)) u_m_clk   (.i_enable(1'b1), .o_clk(m_axis_aclk));

  //---------------------------------------------------------------------------
  // Interfaces
  //---------------------------------------------------------------------------
  axi4_lite_if #(
    .DATA_WIDTH (32),
    .ADDR_WIDTH (6 )
  ) s_axi (
    .aclk    (s_axi_aclk   ),
    .aresetn (s_axi_aresetn)
  );

  axi4_stream_if #(
    .TDATA_WIDTH (B_TDATA),
    .TUSER_WIDTH (B_TUSER),
    .HAS_TUSER   (1'b1   )
  ) s_axis_if (
    .aclk    (s_axis_aclk   ),
    .aresetn (s_axis_aresetn)
  );

  axi4_stream_if #(
    .TDATA_WIDTH (B_AXIS)
  ) m_axis_if (
    .aclk    (m_axis_aclk   ),
    .aresetn (m_axis_aresetn)
  );

  //---------------------------------------------------------------------------
  // Debug probe aliases
  //---------------------------------------------------------------------------
  logic [31:0] dbg_probe;

  wire       dbg_start_sync = dbg_probe[0];
  wire       dbg_run_sclk   = dbg_probe[3];
  wire       dbg_wr_en      = dbg_probe[4];
  wire       dbg_empty      = dbg_probe[6];
  wire       dbg_full       = dbg_probe[7];
  wire [7:0] dbg_state      = dbg_probe[15:8];

  localparam logic [7:0] ST_IDLE_ENC     = 8'h00;
  localparam logic [7:0] ST_RUN_ENC      = 8'h01;
  localparam logic [7:0] ST_WAIT_END_ENC = 8'h02;
  localparam logic [7:0] ST_END_ENC      = 8'h03;

  //---------------------------------------------------------------------------
  // Scoreboard state
  //---------------------------------------------------------------------------
  logic [W_IN-1:0] exp_q [$];
  int              last_pos_q [$];
  bit              mon_en;
  bit              tx_done;
  int              sb_rx;
  int              sb_errors;
  int              sb_stored;
  int              sb_dropped;

  //---------------------------------------------------------------------------
  // Park every driven signal before the first clock edge
  //---------------------------------------------------------------------------
  initial begin
    s_axis_if.tvalid = 1'b0;
    s_axis_if.tdata  = '0;
    s_axis_if.tuser  = '0;
    s_axis_if.tlast  = 1'b0;
    m_axis_if.tready = 1'b0;
    tx_done          = 1'b1;
  end

  initial begin
    $dumpfile("axis_streamer.vcd");
    $dumpvars();
  end

  //---------------------------------------------------------------------------
  // DUT
  //---------------------------------------------------------------------------
  axis_streamer #(
    .B_TDATA       (B_TDATA ),
    .B_TUSER       (B_TUSER ),
    .B_AXIS        (B_AXIS  ),
    .N_FIFO        (N_FIFO  ),
    .FIFO_MEM_TYPE (MEM_TYPE)
  ) dut (
    .s_axi_aclk     (s_axi_aclk    ),
    .s_axi_aresetn  (s_axi_aresetn ),
    .s_axi_awaddr   (s_axi.awaddr  ),
    .s_axi_awprot   (s_axi.awprot  ),
    .s_axi_awvalid  (s_axi.awvalid ),
    .s_axi_awready  (s_axi.awready ),
    .s_axi_wdata    (s_axi.wdata   ),
    .s_axi_wstrb    (s_axi.wstrb   ),
    .s_axi_wvalid   (s_axi.wvalid  ),
    .s_axi_wready   (s_axi.wready  ),
    .s_axi_bresp    (s_axi.bresp   ),
    .s_axi_bvalid   (s_axi.bvalid  ),
    .s_axi_bready   (s_axi.bready  ),
    .s_axi_araddr   (s_axi.araddr  ),
    .s_axi_arprot   (s_axi.arprot  ),
    .s_axi_arvalid  (s_axi.arvalid ),
    .s_axi_arready  (s_axi.arready ),
    .s_axi_rdata    (s_axi.rdata   ),
    .s_axi_rresp    (s_axi.rresp   ),
    .s_axi_rvalid   (s_axi.rvalid  ),
    .s_axi_rready   (s_axi.rready  ),

    .s_axis_aresetn (s_axis_aresetn ),
    .s_axis_aclk    (s_axis_aclk    ),
    .s_axis_tvalid  (s_axis_if.tvalid),
    .s_axis_tready  (s_axis_if.tready),
    .s_axis_tdata   (s_axis_if.tdata ),
    .s_axis_tuser   (s_axis_if.tuser ),

    .m_axis_aresetn (m_axis_aresetn  ),
    .m_axis_aclk    (m_axis_aclk     ),
    .m_axis_tvalid  (m_axis_if.tvalid),
    .m_axis_tready  (m_axis_if.tready),
    .m_axis_tdata   (m_axis_if.tdata ),
    .m_axis_tlast   (m_axis_if.tlast ),

    .dbg_probe      (dbg_probe       )
  );

  //---------------------------------------------------------------------------
  // Input monitor: only what the core actually stored
  //---------------------------------------------------------------------------
  always @(posedge s_axis_aclk) begin
    if (mon_en && s_axis_aresetn === 1'b1) begin
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
  // Output monitor: payload, padding and packet boundaries
  //---------------------------------------------------------------------------
  always @(posedge m_axis_aclk) begin
    logic [W_IN-1:0] exp;
    if (mon_en && m_axis_aresetn === 1'b1 &&
        m_axis_if.tvalid === 1'b1 && m_axis_if.tready === 1'b1) begin

      if (m_axis_if.tdata[B_AXIS-1:W_IN] !== '0) begin
        $display("[SB] beat %0d: padding bits are not zero (0x%08h)",
                 sb_rx, m_axis_if.tdata);
        sb_errors++;
      end

      if (exp_q.size() == 0) begin
        $display("[SB] beat %0d: SPURIOUS output 0x%06h, nothing was stored",
                 sb_rx, m_axis_if.tdata[W_IN-1:0]);
        sb_errors++;
      end
      else begin
        exp = exp_q.pop_front();
        if (m_axis_if.tdata[W_IN-1:0] !== exp) begin
          $display("[SB] beat %0d: expected 0x%06h got 0x%06h",
                   sb_rx, exp, m_axis_if.tdata[W_IN-1:0]);
          sb_errors++;
        end
      end

      if (m_axis_if.tlast === 1'b1) last_pos_q.push_back(sb_rx);
      sb_rx++;
    end
  end

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

  task automatic sb_check(input string tag);
    `FAIL_IF_LOG(sb_errors != 0,
                 $sformatf("%s: %0d scoreboard errors (stored=%0d rx=%0d)",
                           tag, sb_errors, sb_stored, sb_rx))
  endtask

  //! Assert the exact set of tlast beat indices, e.g. '{3, 7} for two packets
  //! of four.
  task automatic check_last_positions(input string tag, input int expected[]);
    `FAIL_IF_LOG(last_pos_q.size() != expected.size(),
                 $sformatf("%s: saw %0d tlast, expected %0d (positions %p)",
                           tag, last_pos_q.size(), expected.size(), last_pos_q))
    foreach (expected[i]) begin
      if (i < last_pos_q.size()) begin
        `FAIL_IF_LOG(last_pos_q[i] != expected[i],
                     $sformatf("%s: tlast %0d at beat %0d, expected beat %0d",
                               tag, i, last_pos_q[i], expected[i]))
      end
    end
  endtask

  //---------------------------------------------------------------------------
  // Register access
  //---------------------------------------------------------------------------
  task automatic reg_write(input logic [5:0] addr, input logic [31:0] data);
    s_axi.axi_write(addr, data);
  endtask

  task automatic reg_read(input logic [5:0] addr, output logic [31:0] data);
    s_axi.axi_read(addr, data);
  endtask

  task automatic read_status(output logic [31:0] st);
    reg_read(REG_STATUS, st);
  endtask

  //! Poll STATUS until a bit reaches the wanted value. This is what real
  //! software does, so it is worth exercising rather than peeking at dbg_probe.
  task automatic poll_status_bit(input int bit_idx, input bit want,
                                 output bit ok, input int tries = 200);
    logic [31:0] st;
    ok = 1'b0;
    for (int i = 0; i < tries; i++) begin
      read_status(st);
      if (st[bit_idx] === want) begin
        ok = 1'b1;
        return;
      end
    end
    read_status(st);
    $display("[TB] poll_status_bit(%0d,%0b) gave up, STATUS=0x%08h", bit_idx, want, st);
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

  task automatic axis_master_idle();
    s_axis_if.tvalid <= 1'b0;
    s_axis_if.tdata  <= '0;
    s_axis_if.tuser  <= '0;
    s_axis_if.tlast  <= 1'b0;
  endtask

  //! Drive one word per clock, holding the payload until tready is sampled
  //! high. tlast stays low: this block builds its own packet boundaries from
  //! NSAMP and has no s_axis_tlast port.
  //!
  //! NEVER kill this task with `disable fork` while it may be mid-beat. Once
  //! tvalid is asserted, AXI4-Stream forbids withdrawing it before the
  //! handshake, and dropping it trips AXIS_TVALID_STABLE. If the sink is
  //! stalled, open it first, wait for tx_done, and only then tear down.
  task automatic send_words(input logic [W_IN-1:0] words[]);
    tx_done = 1'b0;
    foreach (words[i]) begin
      s_axis_if.tvalid <= 1'b1;
      s_axis_if.tdata  <= words[i][B_TDATA-1:0];
      s_axis_if.tuser  <= words[i][W_IN-1:B_TDATA];
      s_axis_if.tlast  <= 1'b0;
      @(posedge s_axis_aclk);
      while (s_axis_if.tready !== 1'b1) @(posedge s_axis_aclk);
    end
    axis_master_idle();
    tx_done = 1'b1;
  endtask

  //! Model the REAL source: a free-running ADC. It presents one new sample per
  //! clock and never looks at tready, because the converter cannot be stalled.
  //!
  //! Such a source is NOT an AXI4-Stream master: while tready is low it keeps
  //! changing tdata, which violates TDATA_STABLE. The protocol simply does not
  //! describe it, so the tests that use this task switch the assertions on
  //! s_axis_if off for their duration. That is the point of the block: whatever
  //! cannot be stored is dropped and counted in LOST.
  //!
  //! offered counts every sample the source put on the wire.
  task automatic send_words_freerun(input logic [W_IN-1:0] words[],
                                    output int offered);
    tx_done = 1'b0;
    offered = 0;
    foreach (words[i]) begin
      s_axis_if.tvalid <= 1'b1;
      s_axis_if.tdata  <= words[i][B_TDATA-1:0];
      s_axis_if.tuser  <= words[i][W_IN-1:B_TDATA];
      s_axis_if.tlast  <= 1'b0;
      @(posedge s_axis_aclk);      // one sample per clock, come what may
      offered++;
    end
    axis_master_idle();
    tx_done = 1'b1;
  endtask

  //! Wait for a forked send_words() to retire cleanly.
  task automatic wait_tx_done(output bit ok, input int timeout = 20000);
    int t;
    t  = 0;
    ok = 1'b1;
    while (tx_done !== 1'b1) begin
      @(posedge s_axis_aclk);
      if (++t > timeout) begin
        ok = 1'b0;
        $display("[TB] wait_tx_done timed out, tready=%0b", s_axis_if.tready);
        return;
      end
    end
  endtask

  task automatic set_tready(input bit v);
    m_axis_if.tready <= v;
  endtask

  task automatic recv_beat(output logic [B_AXIS-1:0] d,
                           output logic              last,
                           output bit                ok,
                           input  int                timeout = 5000);
    int t;
    t    = 0;
    ok   = 1'b0;
    d    = 'x;
    last = 1'bx;
    forever begin
      @(posedge m_axis_aclk);
      if (m_axis_if.tvalid === 1'b1 && m_axis_if.tready === 1'b1) begin
        d    = m_axis_if.tdata;
        last = m_axis_if.tlast;
        ok   = 1'b1;
        return;
      end
      if (++t > timeout) return;
    end
  endtask

  task automatic expect_quiet(input int cycles, input string tag);
    repeat (cycles) begin
      @(posedge m_axis_aclk);
      `FAIL_IF_LOG(m_axis_if.tvalid === 1'b1,
                   $sformatf("%s: unexpected tvalid while the block should be quiet", tag))
    end
  endtask

  //---------------------------------------------------------------------------
  // Control sequence
  //---------------------------------------------------------------------------
  task automatic configure(input int nsamp, input bit mode, input bit flush = 1'b0);
    reg_write(REG_NSAMP, nsamp);
    reg_write(REG_MODE,  {31'd0, mode});
    reg_write(REG_FLUSH, {31'd0, flush});
  endtask

  //! Set START and wait until the WRITE side is really capturing.
  task automatic start_block(input int timeout = 4000);
    int t;
    t = 0;
    reg_write(REG_START, 32'd1);
    while (dbg_run_sclk !== 1'b1) begin
      @(posedge s_axis_aclk);
      if (++t > timeout) begin
        $display("[TB] start_block timed out, state=0x%0h STATUS-ish probe=0x%08h",
                 dbg_state, dbg_probe);
        return;
      end
    end
    repeat (2) @(posedge s_axis_aclk);
  endtask

  task automatic stop_block();
    reg_write(REG_START, 32'd0);
  endtask

  //! Wait for the FSM to leave RUN. Opening the sink before this lets perfectly
  //! legitimate RUN traffic out, which has nothing to do with stop behaviour.
  task automatic wait_left_run(output bit ok, input int timeout = 4000);
    int t;
    t  = 0;
    ok = 1'b1;
    while (dbg_state === ST_RUN_ENC) begin
      @(posedge m_axis_aclk);
      if (++t > timeout) begin
        ok = 1'b0;
        $display("[TB] wait_left_run timed out, state=0x%0h", dbg_state);
        return;
      end
    end
  endtask

  task automatic wait_idle(output bit ok, input int timeout = 20000);
    int t;
    t  = 0;
    ok = 1'b1;
    while (dbg_state !== ST_IDLE_ENC) begin
      @(posedge m_axis_aclk);
      if (++t > timeout) begin
        ok = 1'b0;
        $display("[TB] wait_idle timed out in state 0x%0h", dbg_state);
        return;
      end
    end
  endtask

  //---------------------------------------------------------------------------
  // SVUnit boilerplate
  //---------------------------------------------------------------------------
  function void build();
    name = $sformatf("axis_streamer_ut_N%0d_%0s", N_FIFO, MEM_TYPE);
    svunit_ut = new(name);
  endfunction

  initial begin
    $display("[CFG] axis_streamer TB: s_axi=%.1f s_axis=%.1f m_axis=%.1f MHz  N_FIFO=%0d  MEM=%0s",
             AXI_FREQ/1.0e6, S_AXIS_FREQ/1.0e6, M_AXIS_FREQ/1.0e6, N_FIFO, MEM_TYPE);
  end

  task automatic dut_reset();
    mon_en         = 1'b0;
    s_axi_aresetn <= 1'b0;
    s_axis_aresetn<= 1'b0;
    m_axis_aresetn<= 1'b0;
    axis_master_idle();
    set_tready(1'b0);
    repeat (10) @(posedge s_axi_aclk);
    repeat (10) @(posedge m_axis_aclk);
    s_axi_aresetn <= 1'b1;
    s_axis_aresetn<= 1'b1;
    m_axis_aresetn<= 1'b1;
    repeat (5) @(posedge s_axi_aclk);
    s_axi.reset();
    repeat (CDC_WAIT) @(posedge m_axis_aclk);
    sb_clear();
    mon_en = 1'b1;
  endtask

  task setup();
    svunit_ut.setup();
    dut_reset();
  endtask

  task teardown();
    svunit_ut.teardown();
    mon_en = 1'b0;
    axis_master_idle();
    set_tready(1'b0);
    repeat (5) @(posedge m_axis_aclk);
  endtask

  initial begin
    #20ms;
    $display("[TB] GLOBAL TIMEOUT reached");
    $finish;
  end

  `SVUNIT_TESTS_BEGIN
  `include "axis_streamer_tests.sv"
  `SVUNIT_TESTS_END

endmodule

