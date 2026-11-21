///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : tpv2_alu
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    tpv2_alu.sv
//!
//! @brief      Two-input (a, b) combinational ALU for the tProcessor v2 core. Produces a
//!
//! @details
//!
//! 32-bit result plus Zero/Carry/Sign flags. No clock, no reset.
//!
//! Operation encoding (alu_op_i, 4 bits) — see alu_pkg (TPV2_ALU_*):
//! bit  0     : unit select  -> 0 = ARITH group, 1 = LOGIC group
//! bits [3:1] : sub-operation
//!
//! Flags:
//! z_o : result[31:0] == 0  (32-bit zero; carry ignored)
//! c_o : result[32]  carry-out (ADD) / borrow (SUB). Valid only for ADD/SUB;
//! 0 for all other operations (their results never set bit 32).
//! s_o : result[31]  (sign / MSB)
//!
//! @author  QICK Development Team
//!
//! @version 1.0
`include "alu_pkg.sv"

module tpv2_alu (
   input  wire signed [31:0]  a_i           ,
   input  wire signed [31:0]  b_i           ,
   input  wire        [3:0]   alu_op_i      ,
   output wire                z_o           ,
   output wire                c_o           ,
   output wire                s_o           ,
   output wire signed [31:0]  alu_result_o
);

   import alu_pkg::*;

   reg  [32:0] result;
   wire zero_flag, carry_flag, sign_flag;

   wire [3:0] shift;
   assign shift = b_i[3:0];

   // 33-bit add/sub to capture the carry-out / borrow in bit 32.
   // Zero-extend operands to 33 bits before the operation.
   wire [32:0] a_plus_b_33  = {1'b0, a_i} + {1'b0, b_i};
   wire [32:0] a_minus_b_33 = {1'b0, a_i} - {1'b0, b_i};

   // 32-bit helpers for the remaining operations (bit 32 stays 0 for these).
   wire [31:0] neg_b, abs_b;
   wire [31:0] msh_a, lsh_a, swap_a;
   wire [31:0] a_cat_b, a_sl_b, a_lsr_b, a_asr_b;

   assign neg_b    = -b_i;
   assign abs_b    = b_i[31] ? neg_b : b_i;
   assign msh_a    = {16'b0, a_i[31:16]};
   assign lsh_a    = {16'b0, a_i[15:0]};
   assign swap_a   = {a_i[15:0], a_i[31:16]};
   assign a_cat_b  = {a_i[15:0], b_i[15:0]};
   assign a_sl_b   = a_i <<  shift;
   assign a_lsr_b  = a_i >>  shift;
   assign a_asr_b  = a_i >>> shift;

   always_comb begin
      case (alu_op_i)
         // ARITHMETIC group
         TPV2_ALU_ADD : result = a_plus_b_33;          // 33-bit -> carry in bit 32
         TPV2_ALU_SUB : result = a_minus_b_33;         // 33-bit -> borrow in bit 32
         TPV2_ALU_AND : result = {1'b0, a_i & b_i};
         TPV2_ALU_ASR : result = {1'b0, a_asr_b};
         TPV2_ALU_ABS : result = {1'b0, abs_b};
         TPV2_ALU_MSH : result = {1'b0, msh_a};
         TPV2_ALU_LSH : result = {1'b0, lsh_a};
         TPV2_ALU_SWAP: result = {1'b0, swap_a};
         // LOGIC group
         TPV2_ALU_NOT : result = {1'b0, ~a_i};
         TPV2_ALU_OR  : result = {1'b0, a_i | b_i};
         TPV2_ALU_XOR : result = {1'b0, a_i ^ b_i};
         TPV2_ALU_CAT : result = {1'b0, a_cat_b};
         TPV2_ALU_ZERO: result = '0;
         TPV2_ALU_PAR : result = {32'b0, ^a_i};
         TPV2_ALU_LSL : result = {1'b0, a_sl_b};
         TPV2_ALU_LSR : result = {1'b0, a_lsr_b};
         default      : result = '0;
      endcase
   end

   assign zero_flag  = (result[31:0] == 0);
   assign carry_flag = result[32];
   assign sign_flag  = result[31];

   assign alu_result_o = result[31:0];
   assign z_o          = zero_flag;
   assign c_o          = carry_flag;
   assign s_o          = sign_flag;

endmodule
