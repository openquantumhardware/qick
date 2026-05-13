`timescale 1ns / 1ps
//
// iq_power.v
//
// Computes exact magnitude squared:  power_o = i_in*i_in + q_in*q_in
// Two DSP48E2 multipliers (one per channel) plus a 32-bit add.
// Fully pipelined, 3-cycle latency, 1 sample/cycle throughput.
//
// Range:
//   Worst case I, Q = -2^(IQ_WIDTH-1) -> i^2 = q^2 = 2^(2*IQ_WIDTH-2)
//   For IQ_WIDTH=16:  i^2 + q^2 <= 2^31, fits in POW_WIDTH=32 unsigned.
//
// Pipeline (target c_clk = 200 MHz on RFSoC 4x2):
//   P0  i_in, q_in   -> i_r, q_r              (DSP A reg, 1 LUT level)
//   P1  i_sq <= i_r * i_r;  q_sq <= q_r * q_r (DSP M reg, 16x16 mul ~1.5 ns)
//   P2  power_o <= i_sq + q_sq                (32-bit add or DSP P)
//

module iq_power #(
    parameter integer IQ_WIDTH  = 16,
    parameter integer POW_WIDTH = 32
)(
    input  wire                          clk,
    input  wire                          rst_n,

    input  wire signed [IQ_WIDTH-1:0]    i_in,
    input  wire signed [IQ_WIDTH-1:0]    q_in,
    input  wire                          valid_in,

    output reg         [POW_WIDTH-1:0]   power_o,
    output reg                           valid_o
);

    // P0: input regs
    reg signed [IQ_WIDTH-1:0]   i_r,  q_r;
    reg                         vld_r0;

    // P1: squared
    (* use_dsp = "yes" *) reg [2*IQ_WIDTH-1:0] i_sq;
    (* use_dsp = "yes" *) reg [2*IQ_WIDTH-1:0] q_sq;
    reg                         vld_r1;

    always @(posedge clk) begin
        if (!rst_n) begin
            i_r     <= {IQ_WIDTH{1'b0}};
            q_r     <= {IQ_WIDTH{1'b0}};
            i_sq    <= {(2*IQ_WIDTH){1'b0}};
            q_sq    <= {(2*IQ_WIDTH){1'b0}};
            power_o <= {POW_WIDTH{1'b0}};
            vld_r0  <= 1'b0;
            vld_r1  <= 1'b0;
            valid_o <= 1'b0;
        end else begin
            // P0
            i_r    <= i_in;
            q_r    <= q_in;
            vld_r0 <= valid_in;
            // P1: signed * signed -> non-negative
            i_sq   <= $signed(i_r) * $signed(i_r);
            q_sq   <= $signed(q_r) * $signed(q_r);
            vld_r1 <= vld_r0;
            // P2
            power_o <= i_sq + q_sq;
            valid_o <= vld_r1;
        end
    end

endmodule
