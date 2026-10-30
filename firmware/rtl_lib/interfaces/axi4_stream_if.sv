`timescale 1ns/1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Interface : axi4_stream_if
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axi4_stream_if.sv
//!
//! @brief   SystemVerilog interface encapsulating the AXI4-Stream protocol signals, verification tasks, and assertions.
//!
//! @details
//!
//!
//! This interface provides standard hardware modports for RTL integration alongside specialized
//! clocking blocks and automated tasks for testbench environments (e.g., SVUnit). It centralizes
//! simulation drivers and bus-compliance protocol checking.
//! References:
//!
//!
//! - AXI4-Stream protocol specification: https://developer.arm.com/documentation/ihi0051/a/
//! - AXI4-Stream protocol assertions: https://developer.arm.com/documentation/dui0534/b/
//!
//! @author  QICK Development Team
//!
//! @version 1.2
interface axi4_stream_if #(
  //! Data channel width in bits. Must be an integer multiple of 8.
  parameter int TDATA_WIDTH = 32,
  parameter int TUSER_WIDTH = 32,
  parameter int TID_WIDTH   = 32,
  parameter int TDEST_WIDTH = 32,
  //! Flag to indicate presence of the TKEEP signal.
  parameter bit HAS_TKEEP   = 0,
  //! Flag to indicate presence of the TUSER signal.
  parameter bit HAS_TUSER   = 0,
  //! Flag to indicate presence of the TID signal.
  parameter bit HAS_TID     = 0,
  //! Flag to indicate presence of the TDEST signal.
  parameter bit HAS_TDEST   = 0,
  //! Flag to indicate presence of the TSTRB signal.
  parameter bit HAS_TSTRB   = 0
)(
  input logic aclk,    /**< Global system clock source */
  input logic aresetn  /**< Global synchronous active-low reset */
);

  // ============================================================
  // STATIC CHECKS
  // ============================================================
  if ((TDATA_WIDTH/8) == 0) begin : g_check_tdata_width
    initial $fatal(1, "axi4_stream_if: TDATA_WIDTH must be a multiple of 8 bits and greater than 0.");
  end

  // ============================================================
  // AXI4-STREAM CORE SIGNALS
  // ============================================================
  logic [TDATA_WIDTH-1:0]     tdata;  /**< Primary data payload bus channel */
  logic                       tvalid; /**< Indicates that the master is driving a valid transfer beat */
  logic                       tready; /**< Indicates that the slave can accept a transfer beat */
  logic                       tlast;  /**< Identifies the final packet beat in a frame/stream burst */

  // ============================================================
  // AXI4-STREAM SIDEBAND SIGNALS
  // ============================================================
  logic [(TDATA_WIDTH/8)-1:0] tkeep;  /**< Byte qualifier indicating valid payload bytes */
  logic [TUSER_WIDTH-1:0]     tuser;  /**< User-defined sideband metadata bus */
  logic [(TDATA_WIDTH/8)-1:0] tstrb;  /**< Byte qualifier marking sparse/positional bytes */
  logic [TID_WIDTH-1:0]       tid;    /**< Stream data identifier stream tag */
  logic [TDEST_WIDTH-1:0]     tdest;  /**< Routing destination identifier channel */

  // ============================================================
  // RTL MODPORTS
  // ============================================================

  /** Modport for capturing RTL Master port assignments */
  modport master (
    output tvalid, tdata, tstrb, tkeep, tlast, tid, tdest, tuser,
    input  tready
  );

  /** Modport for capturing RTL Slave port assignments */
  modport slave (
    input  tvalid, tdata, tstrb, tkeep, tlast, tid, tdest, tuser,
    output tready
  );

  // ============================================================
  // SIMULATION-ONLY CODE
  // ============================================================
  `ifndef SYNTHESIS
    `ifndef VERILATOR

      // ------------------------------------------------------------
      // CLOCKING BLOCKS
      // ------------------------------------------------------------

      /**
       * @clocking m_cb
       * @brief Master driver clocking block. Samples inputs on #1step and schedules outputs at #2.
       */
      clocking m_cb @(posedge aclk);
        default input #1step output #2;
        output tvalid, tdata, tstrb, tkeep, tlast, tid, tdest, tuser;
        input  tready;
      endclocking

      /**
       * @clocking s_cb
       * @brief Slave monitor/responder clocking block. Samples inputs on #1step and schedules outputs at #2.
       */
      clocking s_cb @(posedge aclk);
        default input #1step output #2;
        input  tvalid, tdata, tstrb, tkeep, tlast, tid, tdest, tuser;
        output tready;
      endclocking

      /** Modport designated for testbench master emulation environments */
      modport tb_master (
        clocking m_cb,
        import   tx,
        import   m_reset,
        import   burst_tx,
        import   sample_tlast,
        import   idle,
        import   send_bubble
      );

      /** Modport designated for testbench slave emulation environments */
      modport tb_slave  (
        clocking  s_cb,
        import    s_reset,
        import    rx,
        import    burst_rx,
        import    wait_for_beat,
        import    sample_tdata
      );

      // ============================================================
      // RESET TASKS
      // ============================================================

      /**
       * @task m_reset
       * @brief Initializes master signals to an idle state and waits for active-low reset deassertion.
       * @param timeout_cycles Maximum cycle threshold to prevent permanent hangs.
       */
      task automatic m_reset(input int timeout_cycles = 1000);
        m_cb.tvalid <= 1'b0;
        m_cb.tdata  <= '0;
        m_cb.tlast  <= 1'b0;
        m_cb.tstrb  <= '0;
        m_cb.tkeep  <= '0;
        m_cb.tid    <= '0;
        m_cb.tdest  <= '0;
        m_cb.tuser  <= '0;

        fork
          begin
            wait(aresetn === 1'b1);
          end
          begin
            repeat (timeout_cycles) @(m_cb);
            $fatal(1, "[AXIS_FATAL] Master reset sequencing timed out.");
          end
        join_any
        disable fork;

        repeat (3) @(m_cb);  // Post-reset stabilization buffer
      endtask

      /**
       * @task s_reset
       * @brief Places the slave interface in an unready state until reset deassertion, then sets tready high.
       */
      task automatic s_reset(input int timeout_cycles = 1000);
        s_cb.tready <= 1'b0;
        // If the reset is active, wait with timeout for it to be released.
        // If it's already released, don't block.
        if (aresetn === 1'b0) begin
          fork
            begin wait(aresetn === 1'b1); end
            begin
              repeat (timeout_cycles) @(s_cb);
              $fatal(1, "[AXIS_FATAL] Slave reset sequencing timed out.");
            end
          join_any
          disable fork;
        end
        repeat (3) @(s_cb);   // stabilization
        s_cb.tready <= 1'b1;
      endtask
      // ------------------------------------------------------------
      // TRANSACTION API TASKS (SINGLE BEAT)
      // ------------------------------------------------------------

      /**
       * @task tx
       * @brief Transmits a single data word beat on the master channel with standard timeout checking.
       * @param data    The data value to broadcast.
       * @param last    Asserts the tlast sideband flag when high (default = 0).
       * @param timeout Cycle threshold limit before throwing a simulation fatal error.
       */
      task automatic tx(
        input logic [TDATA_WIDTH-1:0] data,
        input logic last = 1'b0,
        input int timeout = 1000
        );
        int cnt = 0;
        @(m_cb);                    // lineup first
        m_cb.tdata  <= data;        // now the drive falls in T0+skew
        m_cb.tlast  <= last;
        m_cb.tvalid <= 1'b1;
        m_cb.tstrb  <= '1;

        do begin
          @(m_cb);                  // in T1 the DUT already sees tvalid: the ready signal is valid
          if (++cnt > timeout)
            $fatal(1, "[AXIS_FATAL] TX timeout");
        end while (!m_cb.tready);

        m_cb.tvalid <= 1'b0;
        m_cb.tlast  <= 1'b0;

      endtask

      /**
       * @task rx
       * @brief Receives a single data beat on the slave channel interface.
       * @param data    Output reference to capture data bus contents.
       * @param last    Output reference to capture the state of tlast.
       * @param timeout Cycle threshold limit before throwing a simulation fatal error.
       */
      task automatic rx(
      output logic [TDATA_WIDTH-1:0] data,
      output logic last,
      input int timeout = 1000
      );
      int cnt = 0;

      // DEBUG 1: Advice the input to the task
      //$display("[%0t] [RX_DEBUG] Init wait RX. Rising tready...", $time);
      s_cb.tready <= 1'b1;

      do begin
        @(s_cb);
        if (++cnt > timeout) begin
          // DEBUG 2: Detailed info before dead because of timeout
          $display("[%0t] [RX_DEBUG] ERROR: Timeout reached after %0d cycles.", $time, cnt);
          $fatal(1, "[AXIS_FATAL] RX timeout");
        end
      end while (!s_cb.tvalid);

      data = s_cb.tdata;
      last = s_cb.tlast;

      // DEBUG 3: Success. We print the data in hexadecimal and binary
      //$display("[%0t] [RX_DEBUG] Successful handshake. Received data: tdata=0x%h, tlast=%b (wait cycles=%0d)", $time, data, last, cnt);

      // Low tready immediately, without wait for another clock
      s_cb.tready <= 1'b0;
    endtask

    /**
     * @task wait_for_beat
     * @brief Blocking slave task that halts execution until a successful, synchronized valid handshake occurs.
     * @note In this case, reading the raw signal is safe: with output #2, the signal
     *       changes only 2 ns after a clocking event, so it is stable at the sampling edge.
     */
    task automatic wait_for_beat();
      do @(s_cb); while (!s_cb.tvalid || !tready);
    endtask

    /**
     * @function sample_tdata
     * @brief Direct, asynchronous read access of the physical tdata bus.
     * @return Logic array containing current bus sample.
     * @note Only for waveform debugging, never for checkers
     */
    function automatic logic [TDATA_WIDTH-1:0] sample_tdata();
      return tdata;
    endfunction

    /**
     * @function sample_tlast
     * @brief Direct, asynchronous read access of the physical tlast boundary signal.
     * @return Logic state of tlast.
     * @note Only for waveform debugging, never for checkers
     */
    function automatic logic sample_tlast();
      return tlast;
    endfunction

    /**
     * @task idle
     * @brief Immediately deasserts both validation and termination controls to put the master in an idle state.
     */
    task automatic idle();
      m_cb.tvalid <= 1'b0;
      m_cb.tlast  <= 1'b0;
    endtask

    /**
     * @task send_bubble
     * @brief Simulates protocol starvation or idle conditions by dropping TVALID for specific cycles.
     * @param cycles Number of clock cycles to preserve the pipeline bubble condition (default = 1).
     */
    task automatic send_bubble(input int cycles = 1);
      m_cb.tdata  <= '0;
      m_cb.tvalid <= 1'b0;
      m_cb.tlast  <= 1'b0;
      repeat (cycles) @(m_cb);
    endtask

    // ============================================================
    // BLOCK TRANSFERS (BURSTS)
    // ============================================================

    /**
     * @task burst_tx
     * @brief Drives a contiguous or streamed collection array block across the master bus interface.
     * @param data_array Unpacked dynamic array representing frame payloads.
     * @param n_beats    Number of array elements targeted for streaming.
     * @param timeout    Timeout boundary limit evaluated per data beat.
     */
    task automatic burst_tx(
      input logic [TDATA_WIDTH-1:0] data_array[],
      input int unsigned n_beats,
      input int unsigned timeout = 1000
    );
      int unsigned wait_cycles;
      if (n_beats == 0) return;

      for (int i = 0; i < n_beats; i++) begin
        wait_cycles = 0;
        m_cb.tdata  <= data_array[i];
        m_cb.tvalid <= 1'b1;
        m_cb.tlast  <= (i == n_beats-1);

        do begin
          @(m_cb);
          wait_cycles++;
          if (wait_cycles > timeout)
            $fatal(1, "[AXIS_FATAL] Burst TX timeout at beat %0d", i);
        end while (!m_cb.tready);
      end

      m_cb.tvalid <= 1'b0;
      m_cb.tlast  <= 1'b0;
    endtask

    /**
     * @task burst_rx
     * @brief Absorbs a complete stream array from a master device up to detecting a TLAST packet marker.
     * @param data_array Output queue capturing incoming payload records sequentially.
     * @param timeout    Global maximum cycle stall boundary allowed before truncation and error throwing.
     */
    task automatic burst_rx(
      output logic [TDATA_WIDTH-1:0] data_array[$],
      input int unsigned timeout = 1000
    );
      int unsigned wait_cycles = 0;
      data_array.delete();
      s_cb.tready <= 1'b1;
      @(s_cb);    // the tready drive only takes effect AFTER this edge;
                  // from the next one onwards, every sampled tvalid is a valid handshake

      while (1) begin
        @(s_cb);
        wait_cycles++;

        if (wait_cycles > timeout)
          $fatal(1, "[AXIS_FATAL] Burst RX timeout");

        if (s_cb.tvalid && tready) begin
          data_array.push_back(s_cb.tdata);
          wait_cycles = 0; // Resetear timeout tras un dato válido
          if (s_cb.tlast) break; // Salir inmediatamente al ver tlast
        end
      end

      s_cb.tready <= 1'b0; // Bajar tready sin @(s_cb) extra
    endtask

    `endif // VERILATOR
  `endif // SYNTHESIS

  // ============================================================
  // PROTOCOL CHECKERS (simulation with -d SVUNIT, xsim)
  // ============================================================
  // Each check fails the running SVUnit test (svunit_assert_macros). The
  // AXI4STREAM_ERRM_* names follow the usual AXI4-Stream protocol-assertion
  // naming (ERRM: an error of the master side). Only the signals the instance
  // declares present (HAS_*) are checked besides tvalid, tdata and tlast.
  `ifdef SVUNIT
    `ifndef SYNTHESIS
      `ifndef VERILATOR

        `include "svunit_assert_macros.svh"

        // One property per signal, expanded by macro: a property formal argument
        // passed to $stable/$past crashes xelab 2025.2 (SIGSEGV; a typed formal
        // hangs it), see TESTBENCH_PATTERNS section 33.

        // NAME: a beat offered and not yet taken keeps SIG until the handshake.
        `define AXIS_HOLD(NAME, SIG, MSG) \
          property NAME; \
            @(posedge aclk) disable iff (!aresetn) (tvalid && !tready) |=> $stable(SIG); \
          endproperty \
          `ASSERT_CONCURRENT_LOG(NAME, MSG)

        // NAME: a beat offered out of reset carries no X/Z on SIG.
        `define AXIS_KNOWN(NAME, SIG, MSG) \
          property NAME; \
            @(posedge aclk) (aresetn && tvalid) |-> !$isunknown(SIG); \
          endproperty \
          `ASSERT_CONCURRENT_LOG(NAME, MSG)

        // Reset: tvalid low in the cycle after reset is seen, and in the first
        // cycle out of reset.
        property VALID_RST;
          @(posedge aclk) !aresetn |=> !tvalid;
        endproperty
        `ASSERT_CONCURRENT_LOG(VALID_RST, "axi4_stream_if: tvalid high in the cycle after reset was asserted")

        property AXI4STREAM_ERRM_TVALID_RESET;
          @(posedge aclk) (aresetn && $past(!aresetn)) |-> !tvalid;
        endproperty
        `ASSERT_CONCURRENT_LOG(AXI4STREAM_ERRM_TVALID_RESET,
                               "axi4_stream_if: tvalid high in the first cycle after reset was released")

        `AXIS_HOLD(AXIS_TVALID_STABLE, tvalid, "axi4_stream_if: tvalid dropped during a stall")
        `AXIS_HOLD(AXI4STREAM_ERRM_TDATA_STABLE, tdata, "axi4_stream_if: tdata changed during a stall")
        `AXIS_HOLD(AXI4STREAM_ERRM_TLAST_STABLE, tlast, "axi4_stream_if: tlast changed during a stall")
        `AXIS_KNOWN(AXI4STREAM_ERRM_TDATA_X, tdata, "axi4_stream_if: tdata has X/Z in a valid beat")
        `AXIS_KNOWN(AXI4STREAM_ERRM_TLAST_X, tlast, "axi4_stream_if: tlast is X/Z in a valid beat")

        if (HAS_TSTRB) begin : g_check_tstrb
          `AXIS_HOLD(AXI4STREAM_ERRM_TSTRB_STABLE, tstrb, "axi4_stream_if: tstrb changed during a stall")
          `AXIS_KNOWN(AXI4STREAM_ERRM_TSTRB_X, tstrb, "axi4_stream_if: tstrb has X/Z in a valid beat")
        end
        if (HAS_TKEEP) begin : g_check_tkeep
          `AXIS_HOLD(AXI4STREAM_ERRM_TKEEP_STABLE, tkeep, "axi4_stream_if: tkeep changed during a stall")
          `AXIS_KNOWN(AXI4STREAM_ERRM_TKEEP_X, tkeep, "axi4_stream_if: tkeep has X/Z in a valid beat")
        end
        if (HAS_TID) begin : g_check_tid
          `AXIS_HOLD(AXI4STREAM_ERRM_TID_STABLE, tid, "axi4_stream_if: tid changed during a stall")
          `AXIS_KNOWN(AXI4STREAM_ERRM_TID_X, tid, "axi4_stream_if: tid has X/Z in a valid beat")
        end
        if (HAS_TDEST) begin : g_check_tdest
          `AXIS_HOLD(AXI4STREAM_ERRM_TDEST_STABLE, tdest, "axi4_stream_if: tdest changed during a stall")
          `AXIS_KNOWN(AXI4STREAM_ERRM_TDEST_X, tdest, "axi4_stream_if: tdest has X/Z in a valid beat")
        end
        if (HAS_TUSER) begin : g_check_tuser
          `AXIS_HOLD(AXI4STREAM_ERRM_TUSER_STABLE, tuser, "axi4_stream_if: tuser changed during a stall")
          `AXIS_KNOWN(AXI4STREAM_ERRM_TUSER_X, tuser, "axi4_stream_if: tuser has X/Z in a valid beat")
        end

        `undef AXIS_HOLD
        `undef AXIS_KNOWN

      `endif // VERILATOR
    `endif // SYNTHESIS
  `endif // SVUNIT

endinterface : axi4_stream_if
