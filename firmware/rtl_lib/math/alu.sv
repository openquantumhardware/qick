`include "alu_pkg.sv"

module alu#(
    parameter int B = 16
  )(
    input  logic       clk,
    input  logic       rstn,
    input  logic [B-1:0] din_a,
    input  logic [B-1:0] din_b,
    input  logic [3:0]   op,
    output logic       zero_a,
    output logic       zero_b,
    output logic [B-1:0] dout
  );

  import alu_pkg::*;

  // Pipeline registers for the operation code to match data latency
  logic [3:0] op_r;
  logic [3:0] op_rr;
  logic [3:0] op_rrr;

  logic [3:0] oper_i;
  logic       sel;

  logic [B-1:0] math_dout;
  logic [B-1:0] bitw_dout;

  // Arithmetic Unit instantiation
  alu_arith_unit #(
    .B(B)
  ) math_i (
    .clk    (clk),
    .rstn   (rstn),
    .din_a  (din_a),
    .din_b  (din_b),
    .op     (oper_i),
    .zero_a (zero_a),
    .zero_b (zero_b),
    .dout   (math_dout)
  );

  // Bitwise Unit instantiation
  alu_bitwise_unit #(
    .B(B)
  ) bitw_i (
    .clk    (clk),
    .rstn   (rstn),
    .din_a  (din_a),
    .din_b  (din_b),
    .op     (oper_i),
    .dout   (bitw_dout)
  );

  // Operation pipeline
  always_ff @(posedge clk) begin
    if (!rstn) begin
      op_r   <= '0;
      op_rr  <= '0;
      op_rrr <= '0;
    end else begin
      op_r   <= op;
      op_rr  <= op_r;
      op_rrr <= op_rr;
    end
  end

  // The most significant bit of 'op' determines the unit selection
  // The lower 3 bits are passed to the sub-modules
  assign oper_i = {1'b0, op[2:0]};
  assign sel    = op_rrr[3];

  // Final Output Mux
  assign dout = (sel == 1'b0) ? bitw_dout : math_dout;

endmodule

