`include "alu_pkg.sv"

module alu_bitwise_unit#(
    parameter int B = 16
  )(
    input  logic             clk,
    input  logic             rstn,
    input  logic [B-1:0]     din_a,
    input  logic [B-1:0]     din_b,
    input  logic [3:0]       op,
    output logic [B-1:0]     dout
  );

  import alu_pkg::*;

  // Input registers
  logic [B-1:0] din_a_r;
  logic [B-1:0] din_b_r;
  logic [3:0]   op_r;

  // Operation wires
  logic [B-1:0] and_i;
  logic [B-1:0] or_i;
  logic [B-1:0] xor_i;
  logic [B-1:0] not_i;
  logic [B-1:0] ls_mux;
  logic [B-1:0] rs_mux;

  // Output pipeline
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
      din_a_r <= din_a;
      din_b_r <= din_b;
      op_r    <= op;
      dout_r   <= dout_mux;
      dout_rr  <= dout_r;
    end
  end

  // Bitwise Operations
  assign and_i = din_a_r & din_b_r;
  assign or_i  = din_a_r | din_b_r;
  assign xor_i = din_a_r ^ din_b_r;
  assign not_i = ~din_b_r;

  // Shifts: Using SV native operators for clarity
  // Shift amount is extracted from the lower bits of din_b
  assign ls_mux = din_a_r << din_b_r;
  assign rs_mux = din_a_r >> din_b_r;

  // Output Mux
  always_comb begin
    case (op_r)
      alu_pkg::BITW_AND    : dout_mux = and_i;
      alu_pkg::BITW_OR     : dout_mux = or_i;
      alu_pkg::BITW_XOR    : dout_mux = xor_i;
      alu_pkg::BITW_NOT    : dout_mux = not_i;
      alu_pkg::BITW_LSHIFT : dout_mux = ls_mux;
      alu_pkg::BITW_RSHIFT : dout_mux = rs_mux;
      default:              dout_mux = '0;
    endcase
  end

  assign dout = dout_rr;

endmodule

