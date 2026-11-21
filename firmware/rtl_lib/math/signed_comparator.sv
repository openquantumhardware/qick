`timescale 1ns/1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : signed_comparator
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    signed_comparator.sv
//!
//! @brief   signed_comparator
//!
//! @details
//!
//! Conditional comparator with a one‑cycle latency.
//!
//! This module receives two signed operands (`din_a` and `din_b`) of configurable width
//! `B`.  The 4‑bit control `op` selects which relational operation is evaluated.
//! The result is presented on the output `flag`, which is asserted (`1`) when the
//! selected condition is true, otherwise de‑asserted (`0`).  All inputs are
//! registered on the rising edge of `clk`; the output is therefore available
//! one clock cycle after the inputs become stable.
//!
//! The supported operations are:
//!
//! | op  | Meaning | Condition                                    |
//! |-----|---------|----------------------------------------------|
//! | 4'b0000 | `>`   | `din_a >  din_b`    |
//! | 4'b0001 | `>=`  | `din_a >= din_b`    |
//! | 4'b0010 | `<`   | `din_a <  din_b`    |
//! | 4'b0011 | `<=`  | `din_a <= din_b`    |
//! | 4'b0100 | `==`  | `din_a == din_b`    |
//! | 4'b0101 | `!=`  | `din_a != din_b`    |
//! | else    | —     | `flag = 0`          |
//!
//! @generic
//! B : integer = 16
//! Width of the input operands (must be > 0).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module signed_comparator #(
    parameter int B = 16
) (
    input  logic                 clk,
    input  logic                 rstn,
    input  logic [B-1:0]         din_a,
    input  logic [B-1:0]         din_b,
    input  logic [3:0]           op,
    output logic                 flag
);

    // --------------------------------------------------------------------
    // 1.  Registered inputs (pipeline stage)
    // --------------------------------------------------------------------
    logic signed [B-1:0] din_a_r;
    logic signed [B-1:0] din_b_r;
    logic [3:0]          op_r;

    always_ff @(posedge clk) begin
        if (!rstn) begin
            din_a_r <= '0;
            din_b_r <= '0;
            op_r    <= '0;
        end else begin
            din_a_r <= $signed(din_a);
            din_b_r <= $signed(din_b);
            op_r    <= op;
        end
    end

    // --------------------------------------------------------------------
    // 2.  Condition flags (combinatorial)
    // --------------------------------------------------------------------
    logic cond_gt;   // din_a >  din_b
    logic cond_eq;   // din_a == din_b
    logic cond_lt;   // din_a <  din_b
    logic cond_ge;   // din_a >= din_b
    logic cond_le;   // din_a <= din_b
    logic cond_ne;   // din_a != din_b

    assign cond_gt = (din_a_r > din_b_r);
    assign cond_eq = (din_a_r == din_b_r);
    assign cond_lt = (din_a_r < din_b_r);

    // Derive the remaining flags from the three primitives
    assign cond_ge = cond_gt | cond_eq;
    assign cond_le = cond_lt | cond_eq;
    assign cond_ne = ~cond_eq;

    // --------------------------------------------------------------------
    // 3.  Mux to produce the final flag according to op_r
    // --------------------------------------------------------------------
    always_comb begin
        unique case (op_r)
            4'b0000 : flag = cond_gt; // >
            4'b0001 : flag = cond_ge; // >=
            4'b0010 : flag = cond_lt; // <
            4'b0011 : flag = cond_le; // <=
            4'b0100 : flag = cond_eq; // ==
            4'b0101 : flag = cond_ne; // !=
            default : flag = 1'b0;    // undefined op → 0
        endcase
    end

endmodule : signed_comparator

