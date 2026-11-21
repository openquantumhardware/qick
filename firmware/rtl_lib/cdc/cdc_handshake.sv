///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi National Accelerator Laboratory
//
// Module: cdc_handshake.sv
// Project: QICK
// Description: Multi-bit, parametrizable clock domain crossing (CDC) using a
//              4-phase req/ack handshake. Safe for arbitrary binary data
//              (not just gray-coded vectors), since the data bus is held
//              stable by the source domain until the destination domain has
//              latched it and the transfer is fully acknowledged.
//
//              Throughput is low (several cycles per transfer, gated by the
//              slower of the two clocks) — this is NOT suitable for
//              streaming data. Use for infrequent control/status word
//              transfers (e.g. config registers, one-shot commands).
//
// Protocol:
//   1) Source loads i_data, pulses i_valid for one i_clk cycle.
//   2) req toggles and is synchronized into the dest domain.
//   3) Dest domain sees req toggle, latches o_data, pulses o_valid for one
//      o_clk cycle, and echoes ack (toggled) back.
//   4) Source domain sees ack toggle -> transfer complete, o_busy deasserts,
//      ready to accept a new i_valid.
//
// RESET: the two domains may be reset INDEPENDENTLY.
//   The transfer is encoded as a *toggle* of req (and of ack), so the two
//   sides only agree while their toggle bits stay consistent. If one side is
//   reset on its own, its bit returns to 0 while the other side still holds
//   1, and that difference is indistinguishable from a real request: the
//   destination fires a phantom o_valid and hands on whatever is on the data
//   bus (all zeros, right after a reset). In xcom_async that phantom word
//   decoded as op=0/dst=0 -- a broadcast XCOM_WRITE_FLAG that was executed --
//   once per RX link re-lock, which is exactly when the RX-side reset pulses
//   in normal operation (found 2026-09-29; TESTBENCH_PATTERNS.md, "Both sides of
//   a CDC need the same reset, or the crossing invents a transfer").
//
//   Each side therefore watches the other's reset, synchronized into its own
//   clock, and realigns to a common idle (both toggles 0, not busy) instead
//   of trusting a bit the peer may have just cleared. Holding the local state
//   in reset while the remote reset is asserted is what makes this safe in
//   both directions.
//
//   REQUIREMENT: a reset must be held long enough to be sampled in the OTHER
//   domain -- at least NS+1 cycles of the slower of the two clocks. This is
//   the usual rule for any reset that crosses a clock domain, and ordinary
//   reset sources (a reset synchronizer, a processor_system_reset block) far
//   exceed it. A shorter pulse is invisible to the peer, which then keeps its
//   toggle while the reset side clears: the phantom transfer is possible
//   again. The module still recovers and keeps working (test07).
//
// Change history: 07/07/26 - Created by @lharnaldi
//                 08/19/26 - Revived from backup and wired into the fusesoc
//                            tree: internal `synchronizer` instances retargeted
//                            to `cdc_bit_sync` (this repo's current 1-bit CDC
//                            primitive), and the previously-unused NS parameter
//                            is now actually forwarded into them.
//                 09/29/26 - Tolerate an independent reset of either domain
//                            (phantom transfer on an asymmetric reset).
//
///////////////////////////////////////////////////////////////////////////////
module cdc_handshake #(
   parameter int DW = 32,   // data width
   parameter int NS = 2     // synchronizer stages (2 min, 3 for very high freq)
)(
   // Source domain.
   input  logic          i_clk,
   input  logic          i_rstn,
   input  logic [DW-1:0] i_data,
   input  logic          i_valid,   // 1-cycle pulse: "transfer this data"
   output logic          o_busy,    // source domain: transfer in flight

   // Destination domain.
   input  logic          o_clk,
   input  logic          o_rstn,
   output logic [DW-1:0] o_data,
   output logic          o_valid    // 1-cycle pulse in o_clk domain
);

   // --------------------------------------------------------------------
   // Cross-visible resets (see the RESET note in the header). Each side sees
   // the other's reset as an active-high "peer in reset" level in its own
   // clock domain. cdc_bit_sync clears to 0 under its own reset, so the
   // inverted rstn is what must cross: a synchronizer held in local reset
   // then reports "peer not in reset", and the local reset already forces
   // the idle state, so the two never disagree about the outcome.
   // --------------------------------------------------------------------
   logic peer_rst_in_i;   // o_rstn asserted (low), seen in i_clk
   logic peer_rst_in_o;   // i_rstn asserted (low), seen in o_clk

   cdc_bit_sync #(.NSTAGES(NS)) peer_rst_i_sync (
      .i_clk   (i_clk),
      .i_rstn  (i_rstn),
      .i_async (~o_rstn),
      .o_sync  (peer_rst_in_i)
   );

   cdc_bit_sync #(.NSTAGES(NS)) peer_rst_o_sync (
      .i_clk   (o_clk),
      .i_rstn  (o_rstn),
      .i_async (~i_rstn),
      .o_sync  (peer_rst_in_o)
   );

   // --------------------------------------------------------------------
   // Source domain: data register + toggle-based request
   // --------------------------------------------------------------------
   logic [DW-1:0] data_r;
   logic          req_r;      // toggles on each new transfer
   logic          ack_sync;   // ack, synchronized back into i_clk domain
   logic          busy_r;

   always_ff @(posedge i_clk) begin
      if (!i_rstn || peer_rst_in_i) begin
         // Local reset, or the destination is in reset and has cleared its
         // half of the handshake: return to the common idle. Any transfer in
         // flight is abandoned -- its destination is being reset and would
         // not act on it anyway -- and o_busy drops so the source is not
         // left waiting for an ack that will never come.
         data_r <= '0;
         req_r  <= 1'b0;
         busy_r <= 1'b0;
      end else begin
         if (i_valid && !busy_r) begin
            data_r <= i_data;
            req_r  <= ~req_r;
            busy_r <= 1'b1;
         end else if (busy_r && (ack_sync == req_r)) begin
            // ack has caught up with req -> transfer complete
            busy_r <= 1'b0;
         end
      end
   end

   assign o_busy = busy_r;

   // --------------------------------------------------------------------
   // req: i_clk -> o_clk
   // --------------------------------------------------------------------
   logic req_sync;

   cdc_bit_sync #(.NSTAGES(NS)) req_sync_i (
      .i_clk   (o_clk),
      .i_rstn  (o_rstn),
      .i_async (req_r),
      .o_sync  (req_sync)
   );

   // --------------------------------------------------------------------
   // Data bus: no re-sync needed for the *value* itself, since it is held
   // stable by the source for the entire handshake window. We only need
   // it to be visible in the o_clk domain, which a plain cross-domain wire
   // provides as long as data_r does not change until req_toggled fires
   // (guaranteed by busy_r gating in the source FSM above).
   // --------------------------------------------------------------------
   logic [DW-1:0] i_data_sync;
   assign i_data_sync = data_r;

   // --------------------------------------------------------------------
   // Destination domain: edge-detect req_sync, latch data, ack back
   // --------------------------------------------------------------------
   logic req_sync_d;
   logic req_toggled;

   always_ff @(posedge o_clk) begin
      if (!o_rstn || peer_rst_in_o) begin
         // Local reset, or the source is in reset and has cleared req_r.
         // Tracking req_sync (rather than forcing 0) keeps req_sync_d equal
         // to req_sync as the source's cleared toggle propagates through the
         // synchronizer, so no edge is ever detected from it: this is what
         // suppresses the phantom transfer.
         req_sync_d <= req_sync;
         o_data     <= '0;
         o_valid    <= 1'b0;
      end else begin
         req_sync_d <= req_sync;
         o_valid    <= 1'b0;
         if (req_toggled) begin
            // i_data (data_r) has been stable since req_r toggled, and
            // req_sync has passed through NS flops of synchronization,
            // so data_r is guaranteed stable/settled here.
            o_data  <= i_data_sync;
            o_valid <= 1'b1;
         end
      end
   end

   assign req_toggled = (req_sync != req_sync_d);

   // --------------------------------------------------------------------
   // ack: o_clk -> i_clk (mirrors req_sync using the same toggle scheme)
   // --------------------------------------------------------------------
   logic ack_r;

   // ack_r must be cleared by the SOURCE's reset too, not just the local one.
   // Left stale at 1 while the source restarts from req_r = 0, the source's
   // very next transfer (req_r -> 1) would find ack_sync already 1 and drop
   // o_busy immediately, reporting the transfer complete before the
   // destination had seen it.
   always_ff @(posedge o_clk) begin
      if (!o_rstn || peer_rst_in_o) ack_r <= 1'b0;
      else if (req_toggled)         ack_r <= req_sync;
   end

   cdc_bit_sync #(.NSTAGES(NS)) ack_sync_i (
      .i_clk   (i_clk),
      .i_rstn  (i_rstn),
      .i_async (ack_r),
      .o_sync  (ack_sync)
   );

endmodule

