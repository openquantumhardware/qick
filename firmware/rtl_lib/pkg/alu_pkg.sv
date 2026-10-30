`ifndef ALU_PKG_SV
`define ALU_PKG_SV

package alu_pkg;

  //===========================================================================
  // tProcessor v1 ALU
  //===========================================================================
  // Data width default
  localparam int B = 16;

  // Operation codes for Arithmetic Unit
  typedef enum logic [3:0] {
    ARITH_ADD = 4'b0000,
    ARITH_SUB = 4'b0001,
    ARITH_MUL = 4'b0010
  } arith_op_e;

  // Operation codes for Bitwise Unit
  typedef enum logic [3:0] {
    BITW_AND    = 4'b0000,
    BITW_OR     = 4'b0001,
    BITW_XOR    = 4'b0010,
    BITW_NOT    = 4'b0011,
    BITW_LSHIFT = 4'b0100,
    BITW_RSHIFT = 4'b0101
  } bitw_op_e;

  //===========================================================================
  // tProcessor v2 ALU  (tpv2_alu)
  //===========================================================================
  // Two-input combinational ALU. The 4-bit opcode is encoded as:
  //   bit  0     : unit select  -> 0 = ARITHMETIC group, 1 = LOGIC group
  //   bits [3:1] : sub-operation within the selected group
  //
  // Below, full 4-bit opcodes (sub_op[2:0] in the upper 3 bits, unit_sel in
  // bit 0) are provided as named constants so tests/decoders stay readable.
  // Encoding helper: {sub_op[2:0], unit_sel}.

  // Unit selector (bit 0)
  localparam logic TPV2_ALU_ARITH = 1'b0;
  localparam logic TPV2_ALU_LOGIC = 1'b1;

  // ARITHMETIC group (bit0 = 0). Value = {sub_op, 1'b0}.
  localparam logic [3:0] TPV2_ALU_ADD  = {3'b000, TPV2_ALU_ARITH}; // A + B
  localparam logic [3:0] TPV2_ALU_SUB  = {3'b001, TPV2_ALU_ARITH}; // A - B
  localparam logic [3:0] TPV2_ALU_AND  = {3'b010, TPV2_ALU_ARITH}; // A & B
  localparam logic [3:0] TPV2_ALU_ASR  = {3'b011, TPV2_ALU_ARITH}; // A >>> B
  localparam logic [3:0] TPV2_ALU_ABS  = {3'b100, TPV2_ALU_ARITH}; // |B|
  localparam logic [3:0] TPV2_ALU_MSH  = {3'b101, TPV2_ALU_ARITH}; // A high half -> low
  localparam logic [3:0] TPV2_ALU_LSH  = {3'b110, TPV2_ALU_ARITH}; // A low half (zero-ext)
  localparam logic [3:0] TPV2_ALU_SWAP = {3'b111, TPV2_ALU_ARITH}; // swap A halves

  // LOGIC group (bit0 = 1). Value = {sub_op, 1'b1}.
  localparam logic [3:0] TPV2_ALU_NOT  = {3'b000, TPV2_ALU_LOGIC}; // ~A
  localparam logic [3:0] TPV2_ALU_OR   = {3'b001, TPV2_ALU_LOGIC}; // A | B
  localparam logic [3:0] TPV2_ALU_XOR  = {3'b010, TPV2_ALU_LOGIC}; // A ^ B
  localparam logic [3:0] TPV2_ALU_CAT  = {3'b011, TPV2_ALU_LOGIC}; // {A[15:0], B[15:0]}
  localparam logic [3:0] TPV2_ALU_ZERO = {3'b100, TPV2_ALU_LOGIC}; // 0
  localparam logic [3:0] TPV2_ALU_PAR  = {3'b101, TPV2_ALU_LOGIC}; // parity(A)
  localparam logic [3:0] TPV2_ALU_LSL  = {3'b110, TPV2_ALU_LOGIC}; // A << B
  localparam logic [3:0] TPV2_ALU_LSR  = {3'b111, TPV2_ALU_LOGIC}; // A >> B

endpackage

`endif
