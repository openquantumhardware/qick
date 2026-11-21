///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : alu_arith_unit
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    alu_arith_unit.sv
//!
//! @brief   TODO: one-line description.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
`include "alu_pkg.sv"

module alu_arith_unit#(
      //! Operand/result width in bits.
      parameter int B = 16
   )(
      //! Clock.
      input  logic         clk,
      //! Active-low synchronous reset.
      input  logic         rstn,
      //! Operand A.
      input  logic [B-1:0] din_a,
      //! Operand B.
      input  logic [B-1:0] din_b,
      //! Opcode: selects add/sub/mul (see alu_pkg::ARITH_*).
      input  logic [3:0]   op,
      //! Asserted when din_a == 0 (combinational).
      output logic          zero_a,
      //! Asserted when din_b == 0 (combinational).
      output logic          zero_b,
      //! Registered result, 2-cycle latency from din_a/din_b/op.
      output logic [B-1:0] dout
   );

  import alu_pkg::*;

  // Internal signals (signed for arithmetic)
  logic signed [B-1:0] din_a_r;
  logic signed [B-1:0] din_b_r;
  logic [3:0]          op_r;

  logic signed [B-1:0] add_i;
  logic signed [B-1:0] sub_i;
  logic signed [B-1:0] prod_i;

  logic [B-1:0] dout_mux;
  logic [B-1:0] dout_r;
  logic [B-1:0] dout_rr;

  // Sequential logic
  always_ff @(posedge clk) begin
    if (!rstn) begin
      din_a_r <= '0;
      din_b_r <= '0;
      op_r    <= '0;
      dout_r   <= '0;
      dout_rr  <= '0;
    end else begin
      din_a_r <= signed'(din_a);
      din_b_r <= signed'(din_b);
      op_r    <= op;
      dout_r   <= dout_mux;
      dout_rr  <= dout_r;
    end
  end

  // Arithmetic operations
  assign add_i = din_a_r + din_b_r;
  assign sub_i = din_a_r - din_b_r;
  // Product: takes B/2 lower bits from din_a and din_b as per VHDL
  assign prod_i = din_a_r[B/2-1:0] * din_b_r[B/2-1:0];

  // Output Mux
  always_comb begin
    case (op_r)
      alu_pkg::ARITH_ADD: dout_mux = {B{1'b0}} | add_i; // Cast to unsigned logic
      alu_pkg::ARITH_SUB: dout_mux = {B{1'b0}} | sub_i;
      alu_pkg::ARITH_MUL: dout_mux = {B{1'b0}} | prod_i;
      default:            dout_mux = '0;
    endcase
  end

  // Zero detection (Combinational as per VHDL)
  assign zero_a = (din_a == '0);
  assign zero_b = (din_b == '0);

  assign dout = dout_rr;

endmodule

