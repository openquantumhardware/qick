///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Testbench : fifo_async_unit_test
// Project   : QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    fifo_async_tc00.sv
//!
//! @brief   SVUnit testbench top for fifo_async (XPM_FIFO_ASYNC wrapper).
//!
//! @details
//!
//! COMPILE-TIME CONFIGURATION (FuseSoC vlogdefine parameters)
//!   FWFT       0 = READ_MODE "std" (default) , 1 = READ_MODE "fwft"
//!   TB_B       data width                    (default 32)
//!   TB_N       FIFO depth                    (default 2048)
//!   SWAP_CLK   0 = wr_clk fast / rd_clk slow (default) , 1 = the other way
//!
//!     make sim IP=fifo_async
//!     make sim IP=fifo_async MODE=fwft DEPTH=16 WIDTH=24 SWAP_CLK=1
//!     make sim-fifo-matrix                       # full sweep
//!
//!   The active configuration is printed at time 0 as a [CFG] line AND encoded
//!   in the SVUnit test-case name. ALWAYS check that line: if the defines do
//!   not reach xvlog the TB silently falls back to std/32/2048.
//!
//! SAMPLING CONVENTION (no clocking blocks, on purpose)
//!   - Every TB drive (wr_en/din/rd_en) uses non-blocking assignment, so it
//!     lands in the NBA region and is stable before the next clock edge.
//!   - Every TB read of a DUT output happens right after @(posedge clk), i.e.
//!     in the active region, which returns the PRE-edge value: exactly the
//!     value the DUT itself sampled at that edge. Drives and samples therefore
//!     agree with the RTL by construction, with no skew to tune.
//!   - Two asynchronous domains means two of everything: never sample a
//!     read-domain signal from a write-domain process or vice versa.
//!
//! SCOREBOARD (black box, monitor based)
//!   - Write monitor : records din on every beat the FIFO actually ACCEPTED,
//!                     i.e. (wr_en && !full) at a wr_clk edge.
//!   - Read monitor  : pops the expected word on every beat that actually
//!                     CAME OUT. This is the only mode-dependent part:
//!                       std  -> capture dout when data_valid  (1 cycle after pop)
//!                       fwft -> capture dout when (rd_en && !empty) (valid BEFORE pop)
//!   - No test pushes to the model queue by hand. That removes the whole class
//!     of "pushed at schedule time, the write never committed" desyncs, which
//!     stay invisible at N=2048 and explode at N=16.
//!   - The TB never peeks at dut.wr_rst_busy / dut.rd_rst_busy. Backpressure
//!     must be visible through 'full' alone (see test09).
//!
//! @author  QICK Development Team
//!
//! @version 2.0

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

`ifndef FWFT
  `define FWFT 0
`endif
`ifndef TB_B
  `define TB_B 32
`endif
`ifndef TB_N
  `define TB_N 2048
`endif
`ifndef SWAP_CLK
  `define SWAP_CLK 0
`endif

module fifo_async_unit_test;

  import svunit_pkg::svunit_testcase;

  svunit_testcase svunit_ut;
  string          name;

  //---------------------------------------------------------------------------
  // Configuration
  //---------------------------------------------------------------------------
  localparam bit    FWFT_MODE = (`FWFT != 0);            //! selected read mode
  localparam string RD_MODE   = FWFT_MODE ? "fwft" : "std";
  localparam int    B         = `TB_B;                   //! data width
  localparam int    N         = `TB_N;                   //! fifo depth

  //! A 16-deep FIFO does not deserve a whole BRAM.
  localparam string MEM_TYPE  = (N <= 64) ? "distributed" : "block";

  //! Expected usable depth (XPM: std = N-1, fwft = N+1).
  localparam int    EFF_DEPTH = FWFT_MODE ? (N + 1) : (N - 1);

  //! Real system clock pair: 307.20 MHz RFSoC datapath vs 100 MHz PS/DMA.
  localparam real   FAST_FREQ = 307.20e6;
  localparam real   SLOW_FREQ = 100.00e6;
  localparam real   WR_FREQ   = (`SWAP_CLK != 0) ? SLOW_FREQ : FAST_FREQ;
  localparam real   RD_FREQ   = (`SWAP_CLK != 0) ? FAST_FREQ : SLOW_FREQ;

  //! Slow-clock cycles allowed for a flag to cross the CDC, with margin.
  localparam int    CDC_WAIT  = 32;

  //---------------------------------------------------------------------------
  // Signals
  //---------------------------------------------------------------------------
  logic               wr_clk;
  logic               rd_clk;
  logic               wr_rstn;
  logic               rd_rstn;

  logic               wr_en;
  logic [B-1:0]       din;
  logic               full;
  logic               wr_err;

  logic               rd_en;
  logic [B-1:0]       dout;
  logic               empty;
  logic               data_valid;

  //---------------------------------------------------------------------------
  // Scoreboard state
  //---------------------------------------------------------------------------
  logic [B-1:0] exp_q [$];   //! words accepted by the FIFO, still in flight
  bit           mon_en;      //! monitors armed
  int           sb_words;    //! words compared
  int           sb_errors;   //! mismatches + spurious outputs
  int           sb_wr;       //! words accepted on the write side

  //---------------------------------------------------------------------------
  // Waveforms
  //---------------------------------------------------------------------------
  initial begin
    $dumpfile("fifo_async.vcd");
    $dumpvars();
  end

  //---------------------------------------------------------------------------
  // Clocks
  //---------------------------------------------------------------------------
  clk_gen #(.FREQ(WR_FREQ)) u_wr_clk_gen (.i_enable(1'b1), .o_clk(wr_clk));
  clk_gen #(.FREQ(RD_FREQ)) u_rd_clk_gen (.i_enable(1'b1), .o_clk(rd_clk));

  //---------------------------------------------------------------------------
  // DUT
  //---------------------------------------------------------------------------
  fifo_async #(
    .B                (B        ),
    .N                (N        ),
    .READ_MODE        (RD_MODE  ),
    .FIFO_MEMORY_TYPE (MEM_TYPE ),
    .CDC_SYNC_STAGES  (2        )
  ) dut (
    // write domain
    .wr_rstn    (wr_rstn    ),
    .wr_clk     (wr_clk     ),
    .wr_en      (wr_en      ),
    .din        (din        ),
    .full       (full       ),
    .wr_err     (wr_err     ),
    // read domain
    .rd_rstn    (rd_rstn    ),
    .rd_clk     (rd_clk     ),
    .rd_en      (rd_en      ),
    .dout       (dout       ),
    .empty      (empty      ),
    .data_valid (data_valid )
  );

  //---------------------------------------------------------------------------
  // Write monitor: one entry per beat the FIFO actually accepted
  //---------------------------------------------------------------------------
  always @(posedge wr_clk) begin
    if (mon_en && wr_rstn === 1'b1 && rd_rstn === 1'b1) begin
      if (wr_en === 1'b1 && full === 1'b0) begin
        exp_q.push_back(din);
        sb_wr++;
      end
    end
  end

  //---------------------------------------------------------------------------
  // Read monitor: one check per beat that actually came out
  //---------------------------------------------------------------------------
  logic capture;
  assign capture = FWFT_MODE ? (rd_en === 1'b1 && empty === 1'b0)
                             : (data_valid === 1'b1);

  always @(posedge rd_clk) begin
    logic [B-1:0] exp;
    if (mon_en && wr_rstn === 1'b1 && rd_rstn === 1'b1 && capture) begin
      if (exp_q.size() == 0) begin
        $display("[SB] SPURIOUS OUTPUT at %0t: dout=0x%0h with nothing written",
                 $time, dout);
        sb_errors++;
      end
      else begin
        exp = exp_q.pop_front();
        if (dout !== exp) begin
          $display("[SB] MISMATCH word %0d at %0t: expected 0x%0h got 0x%0h",
                   sb_words, $time, exp, dout);
          sb_errors++;
        end
        sb_words++;
      end
    end
  end

  //---------------------------------------------------------------------------
  // Protocol assertions (DUT side)
  //---------------------------------------------------------------------------
`ifndef SYNTHESIS
  //! Flags must never be X once out of reset.
  a_flags_known_wr: assert property (
    @(posedge wr_clk) disable iff (wr_rstn !== 1'b1) !$isunknown(full)
  ) else $error("full is X/Z");

  a_flags_known_rd: assert property (
    @(posedge rd_clk) disable iff (rd_rstn !== 1'b1) !$isunknown({empty, data_valid})
  ) else $error("empty/data_valid is X/Z");

  //! Data presented as valid must never be X.
  a_dout_known: assert property (
    @(posedge rd_clk) disable iff (rd_rstn !== 1'b1) capture |-> !$isunknown(dout)
  ) else $error("dout is X/Z while being consumed");

  //! Overflow can only follow a write attempt while full.
  a_wr_err_cause: assert property (
    @(posedge wr_clk) disable iff (wr_rstn !== 1'b1)
      wr_err |-> $past(wr_en && full)
  ) else $error("wr_err asserted without a write attempt while full");
`endif

  //---------------------------------------------------------------------------
  // Scoreboard helpers
  //---------------------------------------------------------------------------
  //! Drop everything in flight and restart the counters.
  task automatic sb_clear();
    exp_q.delete();
    sb_words  = 0;
    sb_errors = 0;
    sb_wr     = 0;
  endtask

  //! Standard end-of-test check: no errors, nothing stuck, something happened.
  //! Order matters: "words accepted that never came out" is a far more specific
  //! diagnosis than "nothing was compared", so it must be reported first.
  task automatic sb_check(input string tag);
    `FAIL_IF_LOG(sb_errors != 0,
                 $sformatf("%s: %0d scoreboard errors (accepted=%0d read=%0d)",
                           tag, sb_errors, sb_wr, sb_words))
    `FAIL_IF_LOG(exp_q.size() != 0,
                 $sformatf("%s: %0d of %0d accepted words never came out (%0d read back)",
                           tag, exp_q.size(), sb_wr, sb_words))
    `FAIL_IF_LOG(sb_words == 0,
                 $sformatf("%s: nothing was compared, accepted=%0d - test is vacuous",
                           tag, sb_wr))
  endtask

  //---------------------------------------------------------------------------
  // Reset helpers
  //---------------------------------------------------------------------------
  //! Idle both interfaces.
  task automatic bus_idle();
    wr_en <= 1'b0;
    rd_en <= 1'b0;
    din   <= '0;
  endtask

  //! Assert both resets, release them, and let the XPM settle. Clears the
  //! scoreboard, because a reset flushes the FIFO in BOTH domains.
  task automatic apply_reset(input int settle = CDC_WAIT);
    mon_en = 1'b0;
    bus_idle();
    wr_rstn = 1'b0;
    rd_rstn = 1'b0;
    repeat (8) @(posedge wr_clk);
    repeat (8) @(posedge rd_clk);
    wr_rstn = 1'b1;
    rd_rstn = 1'b1;
    repeat (settle) @(posedge rd_clk);
    repeat (settle) @(posedge wr_clk);
    sb_clear();
    mon_en = 1'b1;
  endtask

  //! Reset with NO settling time: used to probe the reset-busy window.
  task automatic apply_reset_fast();
    mon_en = 1'b0;
    bus_idle();
    wr_rstn = 1'b0;
    rd_rstn = 1'b0;
    repeat (8) @(posedge wr_clk);
    repeat (8) @(posedge rd_clk);
    sb_clear();
    mon_en  = 1'b1;
    wr_rstn = 1'b1;
    rd_rstn = 1'b1;
  endtask

  //---------------------------------------------------------------------------
  // Write side
  //---------------------------------------------------------------------------
  //! Wait for room, then write one word. 'accepted' reports whether the FIFO
  //! took it (full sampled low on the capture edge).
  task automatic write_word(input  logic [B-1:0] data,
                            output bit           accepted,
                            input  int           timeout = 4096);
    int t;
    t        = 0;
    accepted = 1'b0;
    while (full === 1'b1) begin
      @(posedge wr_clk);
      if (++t > timeout) begin
        wr_en <= 1'b0;
        return;
      end
    end
    wr_en <= 1'b1;
    din   <= data;
    @(posedge wr_clk);                 // DUT samples here
    accepted = (full !== 1'b1);
    wr_en   <= 1'b0;
  endtask

  //! Write one word without checking 'full' first (used to force overflow).
  task automatic write_attempt(input  logic [B-1:0] data,
                               output bit           accepted);
    wr_en <= 1'b1;
    din   <= data;
    @(posedge wr_clk);                 // DUT samples here
    accepted = (full !== 1'b1);
    wr_en   <= 1'b0;
  endtask

  //! Back-to-back burst: wr_en stays high, one attempt per clock.
  //! Returns how many beats the FIFO accepted.
  task automatic write_burst(input int n, output int accepted);
    accepted = 0;
    for (int i = 0; i < n; i++) begin
      wr_en <= 1'b1;
      din   <= $urandom;
      @(posedge wr_clk);               // DUT samples here
      if (full !== 1'b1) accepted++;
    end
    wr_en <= 1'b0;
    @(posedge wr_clk);
  endtask

  //---------------------------------------------------------------------------
  // Read side
  //---------------------------------------------------------------------------
  //! Wait until the FIFO reports data available.
  task automatic wait_not_empty(output bit ok, input int timeout = 4096);
    int t;
    t  = 0;
    ok = 1'b1;
    while (empty === 1'b1) begin
      @(posedge rd_clk);
      if (++t > timeout) begin
        ok = 1'b0;
        return;
      end
    end
  endtask

  //! Read exactly one word, honouring the configured read mode.
  //! THIS TASK IS THE ONLY PLACE THAT KNOWS ABOUT std vs fwft.
  task automatic read_word(output logic [B-1:0] data,
                           output bit           ok,
                           input  int           timeout = 4096);
    int t;
    data = 'x;
    wait_not_empty(ok, timeout);
    if (!ok) return;

    if (FWFT_MODE) begin
      // FWFT: dout already holds the head word; rd_en is a pop/ack.
      data   = dout;                   // sample BEFORE the pop
      rd_en <= 1'b1;
      @(posedge rd_clk);               // DUT consumes here
      rd_en <= 1'b0;
    end
    else begin
      // STD: dout becomes valid one cycle AFTER the pop.
      rd_en <= 1'b1;
      @(posedge rd_clk);               // DUT consumes here
      rd_en <= 1'b0;
      t = 0;
      while (data_valid !== 1'b1) begin
        @(posedge rd_clk);
        if (++t > 8) begin
          ok = 1'b0;
          return;
        end
      end
      data = dout;
    end
    ok = 1'b1;
  endtask

  //! Hold rd_en high while data is available, until the FIFO stays empty for
  //! CDC_WAIT consecutive cycles (or the timeout expires).
  task automatic drain_all(input int timeout = 100000);
    int t;
    int idle;
    t    = 0;
    idle = 0;
    while (t < timeout && idle < CDC_WAIT) begin
      rd_en <= (empty !== 1'b1);
      @(posedge rd_clk);
      if (empty === 1'b1) idle++;
      else                idle = 0;
      t++;
    end
    rd_en <= 1'b0;
    @(posedge rd_clk);
  endtask

  //---------------------------------------------------------------------------
  // SVUnit boilerplate
  //---------------------------------------------------------------------------
  function void build();
    name = $sformatf("fifo_async_ut_%0s_B%0d_N%0d_swap%0d",
                     RD_MODE, B, N, `SWAP_CLK);
    svunit_ut = new(name);
  endfunction

  initial begin
    $display("[CFG] fifo_async TB: READ_MODE=%0s B=%0d N=%0d MEM=%0s",
             RD_MODE, B, N, MEM_TYPE);
    $display("[CFG] wr_clk=%.2f MHz  rd_clk=%.2f MHz  expected usable depth=%0d",
             WR_FREQ/1.0e6, RD_FREQ/1.0e6, EFF_DEPTH);
    $display("[CFG] If this does not match your make call, the defines never reached xvlog.");
  end

  task setup();
    svunit_ut.setup();
    apply_reset();
  endtask

  task teardown();
    svunit_ut.teardown();
    mon_en = 1'b0;
    bus_idle();
    exp_q.delete();
  endtask

  //! Safety net so a hung handshake fails the run instead of hanging CI.
  initial begin
    #20ms;
    $display("[TB] GLOBAL TIMEOUT reached");
    $finish;
  end

  `SVUNIT_TESTS_BEGIN
  `include "tests.sv"
  `SVUNIT_TESTS_END

endmodule