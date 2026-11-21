`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : mult_32x32
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    mult_32x32.sv
//!
//! @brief   Pipelined 32x32 unsigned multiplier.
//!
//! @details
//! Optimized for 32x32 unsigned multiplication: both operands are wider than
//! 27 bits (26 for unsigned), so the product maps to 4 DSP48 slices. The
//! 1-cycle input pipeline + 5-cycle output pipeline (6 total) matches the
//! DSP48 cascade depth needed for full-speed (200+ MHz) operation.
//!
//! Latency (din_a/din_b -> dout): 6 cycles.
//!
//! Used by phase_ctrl_sgmux8 for the phase-coherent modulo arithmetic
//! (PINC*N_DDS and PINC*cnt_n products).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module mult_32x32 (
    input  logic        clk,   //! Clock.
    input  logic [31:0] din_a, //! Operand A (unsigned).
    input  logic [31:0] din_b, //! Operand B (unsigned).
    output logic [63:0] dout   //! Product, 6 cycles after din_a/din_b.
);

    // Input pipeline.
    logic [31:0] din_a_r1;
    logic [31:0] din_b_r1;

    // Product.
    logic [63:0] p;

    // Output pipeline.
    logic [63:0] p_r1;
    logic [63:0] p_r2;
    logic [63:0] p_r3;
    logic [63:0] p_r4;
    logic [63:0] p_r5;

    assign p = din_a_r1 * din_b_r1;

    always_ff @(posedge clk) begin
        // Input pipeline.
        din_a_r1 <= din_a;
        din_b_r1 <= din_b;

        // Output pipeline.
        p_r1 <= p;
        p_r2 <= p_r1;
        p_r3 <= p_r2;
        p_r4 <= p_r3;
        p_r5 <= p_r4;
    end

    assign dout = p_r5;

endmodule
