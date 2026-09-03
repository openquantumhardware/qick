// -----------------------------------------------------------------------------
// fifo_axi_sv : SystemVerilog translation of fifo_axi.vhd
// -----------------------------------------------------------------------------
// Single-clock AXI-compatible FIFO: standard ring-buffer FIFO (fifo_sv) with a
// first-word-fall-through read adapter (rd2axi_sv) on the read side.
//
// Literal translation of the original VHDL structural architecture.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module fifo_axi_sv #(
    // Data width.
    parameter int B = 16,
    // Fifo depth.
    parameter int N = 4
)(
    input  logic            rstn,
    input  logic            clk,

    // Write I/F.
    input  logic            wr_en,
    input  logic [B-1:0]    din,

    // Read I/F.
    input  logic            rd_en,
    output logic [B-1:0]    dout,

    // Flags.
    output logic            full,
    output logic            empty
);

    logic           rd_en_i;
    logic [B-1:0]   dout_i;
    logic           empty_i;

    // FIFO.
    fifo_sv #(
        .B (B),
        .N (N)
    ) fifo_i (
        .rstn  (rstn),
        .clk   (clk),
        .wr_en (wr_en),
        .din   (din),
        .rd_en (rd_en_i),
        .dout  (dout_i),
        .full  (full),
        .empty (empty_i)
    );

    // FIFO read to AXI adapter.
    rd2axi_sv #(
        .B (B)
    ) rd2axi_i (
        .rstn       (rstn),
        .clk        (clk),
        .fifo_rd_en (rd_en_i),
        .fifo_dout  (dout_i),
        .fifo_empty (empty_i),
        .rd_en      (rd_en),
        .dout       (dout),
        .empty      (empty)
    );

endmodule
