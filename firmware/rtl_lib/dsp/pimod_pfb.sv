`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : pimod_pfb
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    pimod_pfb.sv
//!
//! @brief   The PFB readouts' pi modulation after the FFT: on every other
//!          frame, the odd lanes are negated, which undoes the half-channel
//!          frequency shift of the 50 %-overlap polyphase filter bank.
//!
//! @details
//! Faithful port of the legacy VHDL (openquantumhardware/qick firmware/ip/
//! axis_pfb_readout_v4/src/pfb/pimod_pfb.vhd with its fifo_axi = fifo +
//! rd2axi, identical in v3), merged into one module; the FIFO is qick:mem:fifo
//! (the port of the same fifo.vhd). With L lanes of {Q, I}, B bits each:
//!
//! - Input FIFO: {tlast, tdata} words, 4 deep (3 words: the legacy fifo),
//!   written on s_axis_tvalid (s_axis_tready = not full), read through the
//!   legacy rd2axi adapter: one clock after it sees the FIFO not empty it
//!   reads the head word (READ_FIRST), shows it from the next clock on, and
//!   pops the following ones on m_axis_tready; its output reads 0 while it
//!   shows empty.
//! - Two registers follow; m_axis_tvalid is the adapter's not-empty delayed
//!   two clocks, and m_axis_tlast likewise.
//! - A counter of read words (m_axis_tready and not empty, one clock late)
//!   flips `sel` every NFFT/L words. While `sel` is 1 the odd lanes (I and Q)
//!   are negated, -(-2^(B-1)) saturating to 2^(B-1) - 1.
//! - Synchronous, active-low reset.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module pimod_pfb #(
    parameter int NFFT = 64,   //! FFT length (frame = NFFT/L clocks)
    parameter int B    = 16,   //! Bits per I or Q sample
    parameter int L    = 8     //! Lanes (I/Q pairs per clock)
) (
    input  logic             aresetn,
    input  logic             aclk,

    input  logic [2*B*L-1:0] s_axis_tdata,
    input  logic             s_axis_tlast,
    input  logic             s_axis_tvalid,
    output logic             s_axis_tready,

    output logic [2*B*L-1:0] m_axis_tdata,
    output logic             m_axis_tlast,
    output logic             m_axis_tvalid,
    input  logic             m_axis_tready
);

    localparam int NBITS  = 2 * B * L;
    localparam int T      = NFFT / L;
    localparam int T_LOG2 = (T > 1) ? $clog2(T) : 1;
    localparam logic signed [B-1:0] MAX_P = {1'b0, {(B-1){1'b1}}};
    localparam logic signed [B-1:0] MIN_N = {1'b1, {(B-1){1'b0}}};

    // ------------------------------------------------------------------
    // Input FIFO + legacy rd2axi adapter
    // ------------------------------------------------------------------
    typedef enum logic [1:0] {WAIT_EMPTY_ST, READ_FIRST_ST, READ_ST, READ_LAST_ST} rd_state_t;
    rd_state_t        rd_state;
    logic [NBITS:0]   fifo_dout;
    logic             fifo_full, fifo_empty, fifo_rd_en;
    logic             ad_empty;            // adapter's empty
    logic [NBITS:0]   ad_dout;             // adapter's dout

    fifo #(.B(NBITS + 1), .N(4)) u_fifo (
        .rstn  (aresetn),
        .clk   (aclk),
        .wr_en (s_axis_tvalid),
        .din   ({s_axis_tlast, s_axis_tdata}),
        .rd_en (fifo_rd_en),
        .dout  (fifo_dout),
        .full  (fifo_full),
        .empty (fifo_empty)
    );

    assign s_axis_tready = ~fifo_full;

    always_ff @(posedge aclk) begin
        if (!aresetn) rd_state <= WAIT_EMPTY_ST;
        else case (rd_state)
            WAIT_EMPTY_ST: if (!fifo_empty)   rd_state <= READ_FIRST_ST;
            READ_FIRST_ST:                    rd_state <= READ_ST;
            READ_ST:       if (fifo_empty)    rd_state <= m_axis_tready ? WAIT_EMPTY_ST : READ_LAST_ST;
            READ_LAST_ST:  if (m_axis_tready) rd_state <= WAIT_EMPTY_ST;
            default:                          rd_state <= WAIT_EMPTY_ST;
        endcase
    end

    assign ad_empty   = (rd_state == WAIT_EMPTY_ST) || (rd_state == READ_FIRST_ST);
    assign fifo_rd_en = (rd_state == READ_FIRST_ST) || ((rd_state == READ_ST) && m_axis_tready);
    assign ad_dout    = ad_empty ? '0 : fifo_dout;

    // ------------------------------------------------------------------
    // Pi modulation
    // ------------------------------------------------------------------
    logic [NBITS-1:0] d_r, d_rr, d_pm, d_mux;
    logic             empty_r, empty_rr, last_r, last_rr;
    logic [T_LOG2-1:0] cnt;
    logic             sel;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            d_r      <= '0;
            d_rr     <= '0;
            empty_r  <= 1'b1;
            empty_rr <= 1'b1;
            last_r   <= 1'b0;
            last_rr  <= 1'b0;
            cnt      <= '0;
            sel      <= 1'b0;
        end else begin
            d_r      <= ad_dout[NBITS-1:0];
            d_rr     <= d_mux;
            empty_r  <= ad_empty;
            empty_rr <= empty_r;
            last_r   <= ad_dout[NBITS];
            last_rr  <= last_r;
            if (m_axis_tready && !empty_r) begin
                if (cnt < T_LOG2'(T - 1)) begin
                    cnt <= cnt + 1'b1;
                end else begin
                    cnt <= '0;
                    sel <= ~sel;
                end
            end
        end
    end

    // Negate the odd lanes' I and Q (lane = {Q, I}, 2B bits).
    for (genvar i = 0; i < L; i++) begin : g_pm
        logic signed [B-1:0] di, dq;
        assign di = d_r[2*i*B     +: B];
        assign dq = d_r[(2*i+1)*B +: B];
        if (i % 2 == 0) begin : g_even
            assign d_pm[2*i*B     +: B] = di;
            assign d_pm[(2*i+1)*B +: B] = dq;
        end else begin : g_odd
            assign d_pm[2*i*B     +: B] = (di == MIN_N) ? MAX_P : -di;
            assign d_pm[(2*i+1)*B +: B] = (dq == MIN_N) ? MAX_P : -dq;
        end
    end

    assign d_mux = sel ? d_pm : d_r;

    assign m_axis_tdata  = d_rr;
    assign m_axis_tlast  = last_rr;
    assign m_axis_tvalid = ~empty_rr;

endmodule
