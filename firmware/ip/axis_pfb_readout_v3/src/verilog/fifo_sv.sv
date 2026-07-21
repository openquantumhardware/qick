// -----------------------------------------------------------------------------
// fifo_sv : SystemVerilog behavioural translation of fifo.vhd
// -----------------------------------------------------------------------------
// Single-clock ring-buffer FIFO built around bram_simple_dp_sv.
//   full  <= (wptr == rptr - 1)
//   empty <= (wptr == rptr)
//   Read data (dout) comes straight from the BRAM registered-read port, so it
//   is available one clock after rd_en is asserted.
//
// Cycle-accurate, literal translation of the original VHDL.
// ceil(log2(N)) -> $clog2(N).
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module fifo_sv #(
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

    // Number of bits of depth.
    localparam int N_LOG2 = (N > 1) ? $clog2(N) : 1;

    // Pointers.
    logic [N_LOG2-1:0]  wptr;
    logic [N_LOG2-1:0]  rptr;

    // Memory signals.
    logic               mem_wea;
    logic [B-1:0]       mem_dob;

    // Flags.
    logic               full_i;
    logic               empty_i;

    // FIFO memory.
    bram_simple_dp_sv #(
        .N (N_LOG2),
        .B (B)
    ) mem_i (
        .clk   (clk),
        .ena   (1'b1),
        .enb   (rd_en),
        .wea   (mem_wea),
        .addra (wptr),
        .addrb (rptr),
        .dia   (din),
        .dob   (mem_dob)
    );

    // Memory connections.
    assign mem_wea = (full_i == 1'b0) ? wr_en : 1'b0;

    // Full/empty signals.
    assign full_i  = (wptr == (rptr - 1'b1)) ? 1'b1 : 1'b0;
    assign empty_i = (wptr == rptr)          ? 1'b1 : 1'b0;

    // Registers.
    always_ff @(posedge clk) begin
        if (rstn == 1'b0) begin
            wptr <= '0;
            rptr <= '0;
        end else begin
            // Write.
            if (wr_en == 1'b1 && full_i == 1'b0) begin
                wptr <= wptr + 1'b1;
            end
            // Read.
            if (rd_en == 1'b1 && empty_i == 1'b0) begin
                rptr <= rptr + 1'b1;
            end
        end
    end

    // Assign outputs.
    assign dout  = mem_dob;
    assign full  = full_i;
    assign empty = empty_i;

endmodule
