`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : fifo_axi
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    fifo_axi.sv
//!
//! @brief   Single-clock FIFO with the legacy `rd2axi` read adapter: a
//!          valid/ready-style read side on top of the plain `fifo`.
//!
//! @details
//! Faithful port of the legacy VHDL fifo_axi (fifo + rd2axi; openquantumhardware/qick
//! firmware/ip/axis_buffer_ddr/src/fifo/fifo_axi.vhd, identical in the PFB
//! readouts), on qick:mem:fifo. The adapter is the one of qick:dsp:pimod_pfb:
//! one clock after it sees the FIFO not empty it reads the head word
//! (READ_FIRST), shows it from the next clock on, and pops the next words on
//! `rd_en`. `empty` is the adapter's: it is high while the adapter has no word
//! to show, and `dout` reads 0 then. Capacity is N-1 words (the legacy fifo).
//!
//! Synchronous, active-low reset.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module fifo_axi #(
    parameter int B = 16,   //! Data width
    parameter int N = 4     //! Depth (power of 2)
) (
    input  logic         rstn,
    input  logic         clk,

    input  logic         wr_en,
    input  logic [B-1:0] din,

    input  logic         rd_en,
    output logic [B-1:0] dout,

    output logic         full,
    output logic         empty
);

    typedef enum logic [1:0] {WAIT_EMPTY_ST, READ_FIRST_ST, READ_ST, READ_LAST_ST} rd_state_t;
    rd_state_t    rd_state;
    logic [B-1:0] fifo_dout;
    logic         fifo_empty, fifo_rd_en;

    fifo #(.B(B), .N(N)) u_fifo (
        .rstn  (rstn),
        .clk   (clk),
        .wr_en (wr_en),
        .din   (din),
        .rd_en (fifo_rd_en),
        .dout  (fifo_dout),
        .full  (full),
        .empty (fifo_empty)
    );

    always_ff @(posedge clk) begin
        if (!rstn) rd_state <= WAIT_EMPTY_ST;
        else case (rd_state)
            WAIT_EMPTY_ST: if (!fifo_empty) rd_state <= READ_FIRST_ST;
            READ_FIRST_ST:                  rd_state <= READ_ST;
            READ_ST:       if (fifo_empty)  rd_state <= rd_en ? WAIT_EMPTY_ST : READ_LAST_ST;
            READ_LAST_ST:  if (rd_en)       rd_state <= WAIT_EMPTY_ST;
            default:                        rd_state <= WAIT_EMPTY_ST;
        endcase
    end

    assign empty      = (rd_state == WAIT_EMPTY_ST) || (rd_state == READ_FIRST_ST);
    assign fifo_rd_en = (rd_state == READ_FIRST_ST) || ((rd_state == READ_ST) && rd_en);
    assign dout       = empty ? '0 : fifo_dout;

endmodule
