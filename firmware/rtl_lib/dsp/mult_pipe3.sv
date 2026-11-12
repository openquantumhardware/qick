`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : mult_pipe3
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    mult_pipe3.sv
//!
//! @brief   3-cycle pipelined signed multiply.
//!
//! @details
//!
//! Input register -> product register -> output register (3 total stages).
//! Models the legacy `dsp_macro_0` DSP48 IP (C_LATENCY=-1, auto-resolved)
//! used by matched_filter's 4 partial-product multiplies -- the VHDL's own
//! DSP_LATENCY=3 constant is the only available ground truth for this IP's
//! actual register configuration.
//!
//! Latency (a/b -> p): 3 cycles.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module mult_pipe3 #(
    parameter int B = 16   //! Per-operand width.
) (
    input  logic                   clk,   //! Clock.
    input  logic                   rstn,  //! Synchronous reset, active low.
    input  logic signed [B-1:0]    a,     //! Operand A (signed).
    input  logic signed [B-1:0]    b,     //! Operand B (signed).
    output logic signed [2*B-1:0]  p      //! Product, 3 cycles after a/b.
);
    logic signed [B-1:0]   a_r1, b_r1;
    logic signed [2*B-1:0] p_r2, p_r3;

    always_ff @(posedge clk) begin
        if (!rstn) begin
            a_r1 <= '0; b_r1 <= '0;
            p_r2 <= '0; p_r3 <= '0;
        end else begin
            a_r1 <= a;
            b_r1 <= b;
            p_r2 <= a_r1 * b_r1;
            p_r3 <= p_r2;
        end
    end

    assign p = p_r3;
endmodule
