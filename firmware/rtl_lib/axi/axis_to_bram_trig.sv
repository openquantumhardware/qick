///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_to_bram_trig
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_to_bram_trig.sv
//!
//! @brief   Triggered AXI4-Stream to BRAM capture block.
//!
//! @details
//!
//! Waits for an external hardware trigger, then captures exactly 2**N samples
//! from the AXI4-Stream input into memory starting at address 0. An internal
//! FIFO decouples the stream from memory timing.
//!
//! FSM: INIT_ST -> TRIGGER_ST -> CAPTURE_ST -> END_ST
//!
//! INIT_ST    : wait for capture_reg=1; counters held cleared
//! TRIGGER_ST : wait for a trigger pulse
//! CAPTURE_ST : accept stream data, move it FIFO -> BRAM
//! END_ST     : stop accepting new data, finish moving whatever is still in
//!              the FIFO into BRAM, then wait for capture_reg=0
//!
//! Data-loss rules (these are the invariants the block guarantees):
//!
//! - Every beat accepted on the stream (tvalid && tready) is written to the
//!   FIFO exactly once. fifo_wr_en is the handshake, not tvalid alone, so a
//!   full FIFO can never swallow a duplicate.
//! - Every word read out of the FIFO while the capture window still has room
//!   is committed to BRAM. The BRAM write pipeline is driven from fifo_rd_en
//!   itself, so a state change can no longer cancel a write that has already
//!   been popped.
//! - END_ST keeps moving FIFO contents into BRAM instead of discarding them,
//!   so the tail of a capture is not lost when capture_reg drops.
//! - Once the window is full (2**N samples) further FIFO words are drained but
//!   NOT written, so address 0 is never overwritten by a wrap-around, and the
//!   FSM can still reach fifo_empty and return to INIT_ST.
//!
//! @note    Ported from mr_buffer_et/src/data_writer.vhd
//!
//! @author  QICK Development Team
//!
//! @version 1.1
`timescale 1ns/1ps

module axis_to_bram_trig #(
  //! BRAM address width (capture depth = 2**N samples)
  parameter int N = 8,
  //! data width in bits (must match bram_if.NB_DATA and axis N_BYTES*8)
  parameter int B = 16
) (
  input  logic         rstn,
  input  logic         clk,

  // Hardware trigger
  input  logic         trigger,

  // AXI4-Stream slave — incoming data
  output logic         s_axis_tready,
  input  logic [B-1:0] s_axis_tdata,
  input  logic         s_axis_tvalid,
  input  logic         s_axis_tlast, // verilog_lint: waive unused

  // BRAM master — write only
  output logic         mem_en,
  output logic         mem_we,
  output logic [N-1:0] mem_addr,
  output logic [B-1:0] mem_di,

  // Software control register
  input  logic         capture_reg,
  //! High while in END_ST: the capture has finished (level, not sticky)
  output logic         o_capture_done
);

  // -------------------------------------------------------------------------
  // FSM state encoding
  // -------------------------------------------------------------------------
  typedef enum logic [1:0] {
    INIT_ST    = 2'd0,
    TRIGGER_ST = 2'd1,
    CAPTURE_ST = 2'd2,
    END_ST     = 2'd3
  } state_t;

  state_t current_state, next_state;

  // capture-complete flag (level): high while draining/holding in END_ST
  assign o_capture_done = (current_state == END_ST);

  // -------------------------------------------------------------------------
  // FSM outputs
  // -------------------------------------------------------------------------
  //! High only in CAPTURE_ST: the block accepts new stream data
  logic accept_en;
  //! High in CAPTURE_ST and END_ST: the FIFO is being moved into BRAM
  logic drain_en;

  // -------------------------------------------------------------------------
  // Internal FIFO signals
  // -------------------------------------------------------------------------
  logic         fifo_wr_en;
  logic         fifo_rd_en;
  logic [B-1:0] fifo_dout;
  logic         fifo_full;
  logic         fifo_empty;

  // -------------------------------------------------------------------------
  // Address counter, window-full flag, registered memory outputs
  // -------------------------------------------------------------------------
  logic [N-1:0] addr_cnt;
  //! Set once 2**N samples have been committed; stops further BRAM writes
  logic         window_full;
  logic         mem_we_r;
  logic [N-1:0] mem_addr_r;
  logic [B-1:0] mem_di_r;

  // -------------------------------------------------------------------------
  // Internal FIFO (depth=16, FWFT mode)
  // -------------------------------------------------------------------------
  fifo_sync #(
    .B (B),
    .N (16),
    .USE_ADV_FEATURES ("1707"),
    .ENABLE_COUNTERS (1)
  ) fifo_i (
    .rstn  (rstn),
    .clk   (clk),
    .wr_en (fifo_wr_en),
    .din   (s_axis_tdata[B-1:0]),
    .rd_en (fifo_rd_en),
    .dout  (fifo_dout),
    .full  (fifo_full),
    .empty (fifo_empty)
  );

  // -------------------------------------------------------------------------
  // FIFO control
  // -------------------------------------------------------------------------
  // Write on the AXI handshake, never on tvalid alone: with tvalid held high
  // across a stalled cycle the old form wrote the same beat several times.
  assign fifo_wr_en = s_axis_tvalid & s_axis_tready;

  // Pop whenever the FIFO is being drained.  Note this is NOT gated by
  // window_full: once the window is full the words are still popped (and
  // discarded) so that fifo_empty can be reached and the FSM can retire.
  assign fifo_rd_en = drain_en & ~fifo_empty;

  // -------------------------------------------------------------------------
  // AXI4-Stream backpressure
  // -------------------------------------------------------------------------
  assign s_axis_tready = accept_en & ~fifo_full;

  // -------------------------------------------------------------------------
  // Sequential: FSM + address counter + memory pipeline
  // -------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!rstn) begin
      current_state <= INIT_ST;
      addr_cnt      <= '0;
      window_full   <= 1'b0;
      mem_we_r      <= '0;
      mem_addr_r    <= '0;
      mem_di_r      <= '0;
    end else begin
      current_state <= next_state;

      // Counters are only cleared while the block is idle or armed-and-waiting,
      // so a capture that is retiring through END_ST keeps its address state.
      if (current_state == INIT_ST || current_state == TRIGGER_ST) begin
        addr_cnt    <= '0;
        window_full <= 1'b0;
        mem_we_r    <= 1'b0;
        mem_addr_r  <= '0;
        mem_di_r    <= '0;
      end else begin
        // Default: no BRAM write this cycle
        mem_we_r <= 1'b0;

        // A word leaving the FIFO is committed to BRAM as long as the capture
        // window still has room.  Driving the write pipeline from fifo_rd_en
        // (rather than from the state) is what guarantees no popped word is
        // ever dropped on a state transition.
        if (fifo_rd_en && !window_full) begin
          mem_addr_r <= addr_cnt;
          mem_di_r   <= fifo_dout;
          mem_we_r   <= 1'b1;
          addr_cnt   <= addr_cnt + 1'b1;
          if (addr_cnt == '1)
            window_full <= 1'b1;   // last address just consumed
        end
      end
    end
  end

  // -------------------------------------------------------------------------
  // Next-state logic (combinational)
  // -------------------------------------------------------------------------
  always_comb begin
    next_state = current_state;

    unique case (current_state)
      INIT_ST:
        if (capture_reg) next_state = TRIGGER_ST;

      TRIGGER_ST:
        // Allow the arm to be cancelled before the trigger arrives
        if (!capture_reg)     next_state = INIT_ST;
        else if (trigger)     next_state = CAPTURE_ST;

      CAPTURE_ST:
        // Abort if capture_reg drops, or retire once the window is full.
        // Either way END_ST finishes moving the FIFO into BRAM first.
        if (!capture_reg || window_full) next_state = END_ST;

      END_ST:
        // Hold the done flag until software acknowledges by clearing
        // capture_reg, and do not retire with words still in flight
        if (!capture_reg && fifo_empty) next_state = INIT_ST;

      default: next_state = INIT_ST;
    endcase
  end

  // -------------------------------------------------------------------------
  // FSM output decode (combinational)
  // -------------------------------------------------------------------------
  always_comb begin
    accept_en = 1'b0;
    drain_en  = 1'b0;
    unique case (current_state)
      CAPTURE_ST: begin
        accept_en = 1'b1;
        drain_en  = 1'b1;
      end
      END_ST: begin
        accept_en = 1'b0;   // stop accepting new beats
        drain_en  = 1'b1;   // but finish the ones already captured
      end
      default: begin
        accept_en = 1'b0;
        drain_en  = 1'b0;
      end
    endcase
  end

  // -------------------------------------------------------------------------
  // BRAM interface output assignments
  // -------------------------------------------------------------------------
  assign mem_en   = 1'b1;
  assign mem_we   = mem_we_r;
  assign mem_addr = mem_addr_r;
  assign mem_di   = mem_di_r;

endmodule

