`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : iir_iq
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    iir_iq.sv
//!
//! @brief   Complex (I/Q) first-order IIR: two independent iir_1p1z cores.
//!
//! @details
//!
//!
//! Splits the packed complex input word into its real (I) and
//! imaginary (Q) 16-bit components and filters each with an identical
//! single-channel iir_1p1z core (1-pole/1-zero, fixed-point). The two
//! channels are fully independent (no cross-coupling), sharing only the
//! coefficient/gain registers.
//!
//! Packing convention (matches kidsim / prod I/Q datapath):
//! i_data = { Q[B-1:0], I[B-1:0] }  (I in low half, Q in high half)
//! o_data = { Qout,     Iout      }
//!
//! Pipeline latency = 4 valid cycles (same as iir_1p1z).
//! Both channels have identical latency, so a single o_valid (taken
//! from the real channel) represents both; an assertion checks the
//! imaginary channel's valid tracks it.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module iir_iq #(
    /** @brief Per-component (I or Q) sample/coefficient width, Q(B-1). */
    parameter int B  = 16,
    /** @brief Internal accumulator/datapath width per core (BA >= B). */
    parameter int BA = 20
)(
    // Clock and Reset
    /** @brief System clock; all logic on the rising edge. */
    input  logic                    i_clk,
    /** @brief Synchronous reset, active low. */
    input  logic                    i_rstn,

    // Input Data Stream (packed complex)
    /** @brief Input sample valid. */
    input  logic                    i_valid,
    /** @brief Packed complex input { Q[B-1:0], I[B-1:0] }. */
    input  logic [2*B-1:0]          i_data,

    // Output Data Stream (packed complex)
    /** @brief Output sample valid (latency = 4). */
    output logic                    o_valid,
    /** @brief Packed complex output { Qout, Iout }. */
    output logic [2*B-1:0]          o_data,

    // Coefficient / Gain Registers (shared by both channels, signed Q(B-1))
    /** @brief Feed-forward (zero) coefficient C0. */
    input  logic signed [B-1:0]     i_c0,
    /** @brief Feed-back (pole) coefficient C1. */
    input  logic signed [B-1:0]     i_c1,
    /** @brief Output gain G. */
    input  logic signed [B-1:0]     i_g
);
    // Split input into real (I, low half) and imaginary (Q, high half).
    logic signed [B-1:0] din_real;
    logic signed [B-1:0] din_imag;
    logic signed [B-1:0] dout_real;
    logic signed [B-1:0] dout_imag;

    // Per-channel valids.
    logic valid_real;
    logic valid_imag;

    assign din_real = i_data[0   +: B];   // I
    assign din_imag = i_data[B   +: B];   // Q

    // Real (I) channel.
    iir_1p1z #(.B(B), .BA(BA)) u_iir_real (
        .i_clk   (i_clk),
        .i_rstn  (i_rstn),
        .i_valid (i_valid),
        .i_data  (din_real),
        .o_valid (valid_real),
        .o_data  (dout_real),
        .i_c0    (i_c0),
        .i_c1    (i_c1),
        .i_g     (i_g)
    );

    // Imaginary (Q) channel.
    iir_1p1z #(.B(B), .BA(BA)) u_iir_imag (
        .i_clk   (i_clk),
        .i_rstn  (i_rstn),
        .i_valid (i_valid),
        .i_data  (din_imag),
        .o_valid (valid_imag),   // tracked (was left unconnected in the original)
        .o_data  (dout_imag),
        .i_c0    (i_c0),
        .i_c1    (i_c1),
        .i_g     (i_g)
    );

    // Output assignments (repack { Q, I }).
    assign o_data  = {dout_imag, dout_real};
    assign o_valid = valid_real;   // both channels share latency

`ifndef SYNTHESIS
    // Both channels are identical => their valids must be aligned.
    always_ff @(posedge i_clk) begin
        if (i_rstn) begin
            assert (valid_real === valid_imag)
                else $error("iir_iq: I/Q valid misaligned (real=%0d imag=%0d)",
                            valid_real, valid_imag);
        end
    end
`endif // SYNTHESIS
endmodule

