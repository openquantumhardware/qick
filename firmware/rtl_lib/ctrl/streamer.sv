///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : streamer
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    streamer.sv
//!
//! @brief   AXI4-Stream buffer: captures an input stream into a dual-clock FIFO
//!          and re-emits it in packets of nsamp_reg beats (for DMA readout).
//!
//! @details
//!
//! Register map (driven by the AXI-Lite wrapper):
//!   start_reg  RW  LEVEL enable. 0 = idle, 1 = capture and stream. It is not
//!                  a pulse: dropping it while running ends the run.
//!   flush_reg  RW  resynchronised internally. Behaviour when leaving RUN with
//!                  a partial packet held:
//!                  1 = drain what is left, final beat carries tlast;
//!                  0 = discard it, nothing more is emitted.
//!   mode_reg   RW  0 = one-shot (one packet, then wait for start_reg to be
//!                  toggled), 1 = continuous (back-to-back packets).
//!                  FLUSH does not apply to a one-shot packet that completed:
//!                  see ONE-SHOT END below.
//!   nsamp_reg  RW  beats per packet. 0 keeps the block in IDLE.
//!   lost_reg   RO  see WHAT LOST ACTUALLY COUNTS below. Latched when the
//!                  block leaves RUN.
//!
//! OUTPUT BEAT REGISTER - read this before touching anything below
//!   One beat is held in {last_dout, last_dv, last_cnt}. tlast travels WITH the
//!   beat inside last_cnt, so backpressure can never separate the two.
//!
//!   In RUN, tlast is known at capture time: the popped word closes the packet
//!   when cnt == nsamp_reg_r-1. For a TRUNCATED packet (flush) it is not known
//!   at capture time: the held beat only becomes "the last one" once the FIFO
//!   has actually drained, one cycle later. last_rdy holds such a beat back
//!   until then. This is the same one-cycle stall the original had, but
//!   expressed without making tvalid depend on tready.
//!
//!   last_rdy is monotonic while a beat is held, so tvalid is never withdrawn
//!   without a handshake. The cost is one deliberate deviation from the
//!   original: with flush_reg = 0 a beat that is already on the bus completes
//!   its handshake instead of being dropped. See section 7.
//!
//! ONE-SHOT END
//!   The source keeps producing after the last word of a one-shot packet, and
//!   the write side only sees the end of the run a few s_axis_aclk cycles
//!   later. The words written in between belong to no packet. Once the last
//!   word has been captured (pkt_closed), the FIFO is read and discarded
//!   whatever flush_reg says, so:
//!     - no second, truncated packet follows the one-shot packet (it would
//!       wait forever for a DMA transfer that software never armed);
//!     - a sink stalled on the last beat cannot make the FIFO overrun, so it
//!       does not show up in lost_reg.
//!
//! STOPPING IS NOT INSTANTANEOUS
//!   start_reg crosses two flops before the FSM sees it, so after software
//!   writes 0 the block keeps streaming normally for a few m_axis_aclk cycles.
//!   A driver must not assume the output stops on the next beat.
//!
//! WHAT LOST ACTUALLY COUNTS
//!   It counts CYCLES in which the source offered data while the FIFO was full,
//!   not distinct beats. The two only coincide for a source that produces one
//!   new sample per clock and cannot be stalled, which is the intended use:
//!   an ADC feeding this block, and a DMA draining it. There,
//!
//!       samples offered == samples stored + LOST
//!
//!   holds exactly, and LOST is the number of samples that fell on the floor.
//!
//!   Put a well-behaved AXI4-Stream master in front instead and the meaning
//!   changes: that master holds one beat across every stalled cycle, so the
//!   same beat is counted many times and nothing is actually lost. In that
//!   configuration LOST measures backpressure, not loss. Note also that a
//!   free-running converter is NOT an AXI4-Stream master, since it keeps
//!   changing tdata while tready is low.
//!
//! CAPTURE DEPTH
//!   The block holds N_FIFO+1 words in the FIFO plus one in the output beat
//!   register, so with N_FIFO = 16 it absorbs 18 samples of DMA hiccup. A
//!   gapless record longer than that needs the sink to keep up on average;
//!   size N_FIFO for the worst expected DMA stall, not for the packet length.
//!
//! BACKPRESSURE
//!   s_axis_tready is ~fifo_full and is deliberately NOT gated by the run state:
//!   this block is a passive tap and must never stall its producer. Beats
//!   offered while the block is idle are dropped silently and are NOT counted
//!   in lost_reg (only beats dropped while running are).
//!
//! PORT NAMES
//!   Do not rename the s_axis_* / m_axis_* ports: Vivado infers the AXI4-Stream
//!   interfaces from exactly these names when the IP is packaged.
//!
//! @author  QICK Development Team
//!
//! @version 2.0

`timescale 1ns/1ps

module streamer #(
    parameter int B_TDATA = 16,   //! input data payload width
    parameter int B_TUSER = 8,    //! input user side-channel width
    parameter int B_AXIS  = 32,   //! output data bus width
    parameter int N_FIFO  = 16,   //! internal FIFO depth (power of two, >= 16)
    //! FIFO storage primitive, forwarded to XPM's FIFO_MEMORY_TYPE.
    //! "auto" lets Vivado pick, which gives LUTRAM for a shallow buffer and
    //! block RAM for a deep one — the behaviour you want either way. Override
    //! with "distributed" or "block" to pin it down. (Check whether your XPM
    //! version accepts "ultra"; the doc header in the older fifo_dc_axi lists
    //! only auto/block/distributed.)
    //!
    //! ! DELIBERATELY UNTYPED, and the default is deliberately a PLAIN STRING
    //! LITERAL. Two separate reasons:
    //!   - Untyped, because XPM does not merely compare these parameters, it
    //!     BIT-SLICES them as packed vectors. A SystemVerilog `string` is a
    //!     dynamic type whose indexing means something else, so the slices
    //!     inside XPM stop decoding. Same reason fifo_sync's USE_ADV_FEATURES
    //!     was reverted to untyped (commit "fix a parameter passing to xpm
    //!     instantiation").
    //!   - A plain literal, because Verible's explicit-parameter-storage-type
    //!     rule exempts untyped parameters whose default is a string literal,
    //!     but not one whose default is an expression such as a ternary. Keep
    //!     it a literal and no lint waiver is needed.
    parameter FIFO_MEM_TYPE = "auto"
) (
    // AXI4-Stream slave (input), "s" clock domain
    input  logic                s_axis_aresetn,   //! active-low reset, s domain
    input  logic                s_axis_aclk,      //! input stream clock
    input  logic                s_axis_tvalid,    //! input beat valid
    output logic                s_axis_tready,    //! input beat ready
    input  logic [B_TDATA-1:0]  s_axis_tdata,     //! input payload
    input  logic [B_TUSER-1:0]  s_axis_tuser,     //! input side-channel

    // AXI4-Stream master (output), "m" clock domain
    input  logic                m_axis_aresetn,   //! active-low reset, m domain
    input  logic                m_axis_aclk,      //! output stream clock
    output logic                m_axis_tvalid,    //! output beat valid
    input  logic                m_axis_tready,    //! output beat ready
    output logic [B_AXIS-1:0]   m_axis_tdata,     //! output payload
    output logic                m_axis_tlast,     //! end of packet

    // Control registers, m domain
    input  logic                start_reg,        //! level enable
    input  logic                flush_reg,        //! drain (1) or discard (0)
    input  logic                mode_reg,         //! 0 = one-shot, 1 = continuous
    input  logic [31:0]         nsamp_reg,        //! beats per packet
    output logic [31:0]         lost_reg,         //! dropped input beats

    //! Status flags for the register wrapper. MIND THE CLOCK DOMAINS: these are
    //! meant to be synchronised INDIVIDUALLY, they are not coherent as a group.
    //!   [0] running    m domain, FSM in RUN
    //!   [1] done       m domain, FSM in END (one-shot packet finished)
    //!   [2] idle       m domain, FSM in IDLE (safe to reconfigure)
    //!   [3] overflow   s domain, sticky, samples lost in this or the last run
    //!   [4] fifo_full  s domain
    //!   [5] fifo_empty m domain
    output logic [5:0]          o_status,

    output logic [31:0]         dbg_probe         //! debug probe, see bottom
);

    // -----------------------------------------------------------------------
    // Local constants
    // -----------------------------------------------------------------------
    localparam int W_FIFO = B_TDATA + B_TUSER;    //! stored word width

    //! m_axis_aclk cycles the FIFO must read empty, with the write side already
    //! stopped, before a truncated packet is declared finished. See section 7.
    localparam int DRAIN_SETTLE = 4;
    localparam int DRAIN_W      = $clog2(DRAIN_SETTLE + 1);

    typedef enum logic [1:0] {
        IDLE_ST     = 2'd0,
        RUN_ST      = 2'd1,
        WAIT_END_ST = 2'd2,
        END_ST      = 2'd3
    } state_t;

    // -----------------------------------------------------------------------
    // Internal signals
    // -----------------------------------------------------------------------
    (* fsm_encoding = "one_hot" *) state_t state;

    logic               idle_state;
    logic               run_state;
    logic               wait_end_state;
    logic               end_state;
    logic               ovf_sticky;         //! sticky overflow, s domain

    logic [31:0]        cnt;                //! beats popped in the current packet
    logic [31:0]        cnt_full;           //! running count of dropped beats

    logic               start_reg_resync;   //! start_reg in the m domain
    logic               flush_reg_sync;     //! flush_reg in the m domain
    logic               run_state_sclk;     //! run_state in the s domain
    logic               run_state_sclk_d;   //! delayed, for edge detection
    logic               run_state_ack;      //! run_state_sclk back in the m domain

    logic               mode_reg_r;         //! latched while stopped
    logic [31:0]        nsamp_reg_r;        //! latched while stopped
    logic [31:0]        lost_reg_r;         //! latched when leaving RUN

    logic               fifo_wr_en;
    logic [W_FIFO-1:0]  fifo_din;
    logic               fifo_rd_en;
    logic [W_FIFO-1:0]  fifo_dout;
    logic               fifo_full;
    logic               fifo_empty;

    logic [W_FIFO-1:0]  last_dout;          //! held output beat
    logic               last_dv;            //! held beat is valid
    logic               last_cnt;           //! held beat carries tlast

    logic               last_rdy;           //! held beat may be presented
    logic               out_hs;             //! output beat handshake
    logic               beat_free;          //! beat register can take a word
    logic               discard_now;        //! held beat is about to be dropped
    logic               nsamp_valid;        //! nsamp_reg_r is usable
    logic               pkt_end_capture;    //! captured beat closes the packet
    logic               pkt_closed;         //! one-shot packet fully captured
    logic               beat_load;          //! popped word goes to the beat register

    logic [DRAIN_W-1:0] drain_cnt;          //! cycles the FIFO has read empty
    logic               drain_ready;        //! a drain may now be declared over

    // -----------------------------------------------------------------------
    // 1) Control CDC
    // -----------------------------------------------------------------------
    cdc_bit_sync #(.NSTAGES(2)) u_sync_start (
        .i_clk   (m_axis_aclk     ),
        .i_rstn  (m_axis_aresetn  ),
        .i_async (start_reg       ),
        .o_sync  (start_reg_resync)
    );

    //! flush_reg is quasi-static (written before start_reg, only consulted in
    //! WAIT_END), but it feeds COMBINATIONAL logic in this domain. Without a
    //! synchroniser a metastable value could momentarily steer the block down
    //! the wrong branch: drain a packet that should have been discarded, or the
    //! reverse. One flop pair removes the question.
    cdc_bit_sync #(.NSTAGES(2)) u_sync_flush (
        .i_clk   (m_axis_aclk   ),
        .i_rstn  (m_axis_aresetn),
        .i_async (flush_reg     ),
        .o_sync  (flush_reg_sync)
    );

    cdc_bit_sync #(.NSTAGES(2)) u_sync_run_state (
        .i_clk   (s_axis_aclk     ),
        .i_rstn  (s_axis_aresetn  ),
        .i_async (run_state       ),
        .o_sync  (run_state_sclk  )
    );

    cdc_bit_sync #(.NSTAGES(2)) u_sync_run_ack (
        .i_clk   (m_axis_aclk     ),
        .i_rstn  (m_axis_aresetn  ),
        .i_async (run_state_sclk  ),
        .o_sync  (run_state_ack   )
    );

    // -----------------------------------------------------------------------
    // 2) Dual-clock FIFO
    // -----------------------------------------------------------------------
    //! READ_MODE must be "fwft": the read path below assumes dout already holds
    //! the head word when empty is low, and treats rd_en as a pop acknowledge.
    fifo_async #(
        .B                (W_FIFO       ),
        .N                (N_FIFO       ),
        .READ_MODE        ("fwft"       ),
        .FIFO_MEMORY_TYPE (FIFO_MEM_TYPE),
        .CDC_SYNC_STAGES  (2            )
    ) u_fifo_async (
        .wr_rstn    (s_axis_aresetn),
        .wr_clk     (s_axis_aclk   ),
        .wr_en      (fifo_wr_en    ),
        .din        (fifo_din      ),
        .full       (fifo_full     ),
        .wr_err     (              ),
        .rd_rstn    (m_axis_aresetn),
        .rd_clk     (m_axis_aclk   ),
        .rd_en      (fifo_rd_en    ),
        .dout       (fifo_dout     ),
        .empty      (fifo_empty    ),
        .data_valid (              )
    );

    // -----------------------------------------------------------------------
    // 3) FIFO write control, s domain
    // -----------------------------------------------------------------------
    assign fifo_wr_en = run_state_sclk & s_axis_tvalid;
    assign fifo_din   = {s_axis_tuser, s_axis_tdata};

    // -----------------------------------------------------------------------
    // 4) FIFO read control, m domain
    // -----------------------------------------------------------------------
    //! The beat register can accept a new word when it is empty, when it is
    //! being handed over in this very cycle, or when the word it holds is
    //! going to be discarded anyway. Gating the pop with this instead of with
    //! m_axis_tready is what stops an already-presented beat from being
    //! overwritten.
    assign discard_now = wait_end_state & ~flush_reg_sync & ~last_rdy;
    assign beat_free   = ~last_dv | out_hs | discard_now;

    //! Popping is allowed in every state except END_ST. beat_free already
    //! enforces backpressure while flushing (it needs the handshake), and makes
    //! the discard path free-running, so no extra qualifier is needed here.
    //! After a one-shot packet is closed, the FIFO drains freely and nothing
    //! more reaches the beat register (see ONE-SHOT END in the header).
    assign fifo_rd_en = ~fifo_empty &
                        (idle_state |
                         ((run_state | wait_end_state) & (beat_free | pkt_closed)));
    assign beat_load  = fifo_rd_en & (run_state | wait_end_state) & ~pkt_closed;

    // -----------------------------------------------------------------------
    // 5) Lost-sample counter, s domain
    // -----------------------------------------------------------------------
    always_ff @(posedge s_axis_aclk) begin
        if (!s_axis_aresetn) begin
            cnt_full         <= 32'd0;
            lost_reg_r       <= 32'd0;
            run_state_sclk_d <= 1'b0;
            ovf_sticky       <= 1'b0;
        end
        else begin
            run_state_sclk_d <= run_state_sclk;

            if (!run_state_sclk && run_state_sclk_d) begin
                // Falling edge of the run state: publish the count.
                lost_reg_r <= cnt_full;
                cnt_full   <= 32'd0;
            end
            else if (run_state_sclk && s_axis_tvalid && fifo_full) begin
                cnt_full   <= cnt_full + 1;
                ovf_sticky <= 1'b1;
            end

            //! Sticky overflow is cleared when a NEW run starts, so software
            //! reads a flag that belongs to the run it just observed.
            if (run_state_sclk && !run_state_sclk_d) begin
                ovf_sticky <= 1'b0;
            end
        end
    end

    // -----------------------------------------------------------------------
    // 6) Packet counter and configuration latching, m domain
    // -----------------------------------------------------------------------
    assign nsamp_valid     = (nsamp_reg_r != 32'd0);
    assign pkt_end_capture = run_state & nsamp_valid & (cnt == nsamp_reg_r - 32'd1);

    always_ff @(posedge m_axis_aclk) begin
        if (!m_axis_aresetn) begin
            cnt         <= 32'd0;
            pkt_closed  <= 1'b0;
            mode_reg_r  <= 1'b0;
            nsamp_reg_r <= 32'd0;
        end
        else begin
            if (!run_state) begin
                cnt <= 32'd0;
            end
            else if (beat_load) begin
                if (pkt_end_capture) cnt <= 32'd0;
                else                 cnt <= cnt + 1;
            end

            //! Set when the last word of a one-shot packet is captured, not when
            //! it is delivered: from then on nothing may follow it, even if
            //! start_reg drops while that beat is still waiting for tready.
            if (idle_state) begin
                pkt_closed <= 1'b0;
            end
            else if (beat_load && pkt_end_capture && !mode_reg_r) begin
                pkt_closed <= 1'b1;
            end

            // Configuration is only sampled while the block is stopped, so it
            // is stable for the whole run.
            if (!start_reg_resync) begin
                mode_reg_r  <= mode_reg;
                nsamp_reg_r <= nsamp_reg;
            end
        end
    end

    // -----------------------------------------------------------------------
    // 7) Drain settling
    // -----------------------------------------------------------------------
    //! In an asynchronous FIFO, empty is computed against the SYNCHRONISED
    //! write pointer, so empty == 1 does not prove that no word is in flight.
    //! run_state_ack (the run state round-tripped through the write domain)
    //! proves the write side has stopped, but it is only as deep as the FIFO's
    //! own pointer synchroniser, so on its own it can fall on the very edge the
    //! last pointer update arrives. Requiring the FIFO to read empty
    //! CONTINUOUSLY for DRAIN_SETTLE cycles afterwards covers both.
    //!
    //! This replaces the old 3-stage synchroniser on fifo_wr_en: that signal is
    //! a pulse train, and a one-cycle pulse in a fast write domain can be
    //! missed entirely by a slower read clock.
    always_ff @(posedge m_axis_aclk) begin
        if (!m_axis_aresetn) begin
            drain_cnt <= '0;
        end
        else if (!wait_end_state || run_state_ack || !fifo_empty) begin
            drain_cnt <= '0;
        end
        else if (drain_cnt != DRAIN_W'(DRAIN_SETTLE)) begin
            drain_cnt <= drain_cnt + 1;
        end
    end

    assign drain_ready = (drain_cnt == DRAIN_W'(DRAIN_SETTLE));

    // -----------------------------------------------------------------------
    // 8) Output beat register (holds data + tlast together)
    // -----------------------------------------------------------------------
    //! last_rdy is the key to an AXI-legal tvalid. It says "the tlast of the
    //! beat I am holding is resolved, so it may be presented". It is only ever
    //! SET while a beat is held, never cleared, so tvalid can never be
    //! withdrawn without a handshake.
    //!
    //!   captured in RUN      -> tlast known at capture time  -> ready at once
    //!   captured in WAIT_END -> unknown, we do not yet know whether another
    //!                           word follows, so the beat is held back until
    //!                           the FIFO reveals the answer, one cycle later
    always_ff @(posedge m_axis_aclk) begin
        if (!m_axis_aresetn) begin
            last_dout <= '0;
            last_dv   <= 1'b0;
            last_cnt  <= 1'b0;
            last_rdy  <= 1'b0;
        end
        else begin
            if (beat_load) begin
                //! beat_free guarantees the register is free or is being handed
                //! over right now, so nothing is ever overwritten unsent.
                last_dout <= fifo_dout;
                last_cnt  <= pkt_end_capture;
                last_dv   <= 1'b1;
                last_rdy  <= run_state;
            end
            else if (out_hs) begin
                last_dv   <= 1'b0;
                last_cnt  <= 1'b0;
                last_rdy  <= 1'b0;
            end
            else if (wait_end_state && flush_reg_sync && last_dv && !last_rdy) begin
                if (!fifo_empty) begin
                    //! Another word is queued behind it: not the last beat.
                    last_rdy <= 1'b1;
                end
                else if (drain_ready) begin
                    //! The FIFO has settled empty with the write side stopped:
                    //! this beat closes the truncated packet.
                    last_cnt <= 1'b1;
                    last_rdy <= 1'b1;
                end
            end

            //! Partial packet dropped when flushing is disabled. ONLY a beat
            //! that was never presented may be dropped: withdrawing tvalid
            //! would violate AXI, so a beat already on the bus completes its
            //! handshake first. This is a deliberate deviation from the
            //! original implementation, which could only ever present a beat
            //! while tready was already high.
            if (discard_now) begin
                last_dv  <= 1'b0;
                last_cnt <= 1'b0;
            end
        end
    end

    // -----------------------------------------------------------------------
    // 9) FSM, m domain
    // -----------------------------------------------------------------------
    always_ff @(posedge m_axis_aclk) begin
        if (!m_axis_aresetn) begin
            state <= IDLE_ST;
        end
        else begin
            case (state)
                IDLE_ST: begin
                    //! nsamp_reg_r == 0 would make the packet-end condition
                    //! unreachable, so the block simply refuses to start.
                    if (start_reg_resync && nsamp_valid && fifo_empty) begin
                        state <= RUN_ST;
                    end
                end

                RUN_ST: begin
                    if (!start_reg_resync) begin
                        state <= WAIT_END_ST;
                    end
                    //! End of packet detected on the beat that was ACTUALLY
                    //! delivered, not on the cycle the word was popped.
                    else if (last_cnt && out_hs && !mode_reg_r) begin
                        state <= WAIT_END_ST;      // one-shot: one packet only
                    end
                end

                WAIT_END_ST: begin
                    //! Wait for the write side to have observed the stop, then
                    //! for the pipeline to be empty.
                    if (!run_state_ack && fifo_empty && !last_dv) begin
                        state <= END_ST;
                    end
                end

                END_ST: begin
                    if (!start_reg_resync) begin
                        state <= IDLE_ST;
                    end
                end

                default: state <= IDLE_ST;
            endcase
        end
    end

    always_comb begin
        idle_state     = 1'b0;
        run_state      = 1'b0;
        wait_end_state = 1'b0;
        end_state      = 1'b0;

        case (state)
            IDLE_ST:     idle_state     = 1'b1;
            RUN_ST:      run_state      = 1'b1;
            WAIT_END_ST: wait_end_state = 1'b1;
            default:     end_state      = 1'b1;   // END_ST
        endcase
    end

    // -----------------------------------------------------------------------
    // 10) Stream outputs
    // -----------------------------------------------------------------------
    assign out_hs = m_axis_tvalid & m_axis_tready;

    //! Neither term depends on m_axis_tready, and last_rdy is monotonic while
    //! a beat is held, so tvalid is asserted only once per beat and stays up
    //! until the handshake completes.
    assign m_axis_tvalid = last_dv & last_rdy;
    assign m_axis_tdata  = {{(B_AXIS-W_FIFO){1'b0}}, last_dout};
    assign m_axis_tlast  = last_cnt;

    assign s_axis_tready = ~fifo_full;
    assign lost_reg      = lost_reg_r;

    assign o_status = {fifo_empty, fifo_full, ovf_sticky,
                       idle_state, end_state, run_state};

    // -----------------------------------------------------------------------
    // 11) Debug probe
    // -----------------------------------------------------------------------
    //! [7:0]   flags, note bit 3 now exposes run_state_sclk so a testbench can
    //!         tell when the WRITE side has actually started capturing.
    assign dbg_probe[ 7: 0] = {fifo_full, fifo_empty, fifo_rd_en, fifo_wr_en,
                               run_state_sclk, mode_reg_r, flush_reg_sync, start_reg_resync};
    assign dbg_probe[15: 8] = {6'b0, state};
    assign dbg_probe[23:16] = {lost_reg_r[3:0], nsamp_reg_r[3:0]};
    assign dbg_probe[31:24] = {cnt_full[3:0], cnt[3:0]};

endmodule

