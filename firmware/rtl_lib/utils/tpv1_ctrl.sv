///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : tpv1_ctrl
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    tpv1_ctrl.sv
//!
//! @brief     Multi-cycle control unit for the QICK tProcessor v1. Decodes the 8-bit opcode
//!
//! @details
//!
//! from the Instruction Register (IR) and generates all datapath control signals
//! across multiple clock cycles. Does not perform any arithmetic itself — it is
//! purely a Moore FSM with combinational output logic.
//!
//! Instruction set summary (opcode → FSM path):
//!
//! I-Type (immediate operand):
//! 0x10 pushi   : PUSHI0
//! 0x11 popi    : POPI0 → POPI1 → POPI2
//! 0x12 mathi   : MATHI0 → MATHI1 → MATHI2 → MATHI3  (ALU 2-cycle latency)
//! 0x13 seti    : SETI0 → SETI1 (holds on fifo_full)
//! 0x14 synci   : SYNCI0 → SYNCI1
//! 0x15 waiti   : WAITI0 → WAITI1 (holds on fifo_full) → WAIT_ACK
//! 0x16 bitwi   : BITWI0 → BITWI1 → BITWI2 → BITWI3
//! 0x17 memri   : MEMRI0 → MEMRI1 → MEMRI2
//! 0x18 memwi   : MEMWI0
//! 0x19 regwi   : REGWI0
//! 0x1A setbi   : SETI0 → SETI1 (same path as seti)
//!
//! J-Type (jump):
//! 0x30 loopnz  : LOOPNZ0 → LOOPNZ1 → LOOPNZ2 → LOOPNZ3 (or FETCH if zero)
//! 0x31 condj   : CONDJ0 → CONDJ1 → (CONDJ2 if taken, else FETCH)
//! 0x3F end     : END_ST
//!
//! R-Type (register operands):
//! 0x50 math    : MATH0 → MATH1 → MATH2 → MATH3
//! 0x51 set     : SET0 → SET1 (holds on fifo_full)
//! 0x52 sync    : SYNC0 → SYNC1
//! 0x53 read    : READ0
//! 0x54 wait    : WAIT0 → WAIT1 (holds on fifo_full) → WAIT_ACK
//! 0x55 bitw    : BITW0 → BITW1 → BITW2 → BITW3
//! 0x56 memr    : MEMR0 → MEMR1 → MEMR2
//! 0x57 memw    : MEMW0
//! 0x58 setb    : SET0 → SET1 (same path as set)
//!
//! Error/terminal:
//! ERR_INSTR_ST → END_ST
//! ERR_STACK_ST → END_ST
//! END_ST       → INIT_ST (when start deasserted)
//!
//! Key output signal semantics:
//! pc_src    : 0 = PC+1, 1 = jump address
//! pc_en     : qualified by alu_zero (loopnz) and cond_flag (condj)
//! alu_src_b : 00 = imm, 01 = D1, 10 = -1
//! alut_src_b: 0 = D1 (register), 1 = imm
//! reg_src   : 000 = imm, 001 = ALU out, 010 = stack, 011 = s_axis, 100 = memory
//! t_en      : master clock enable (deasserted only in START_MC_ST)
//!
//! FSM encoding: one_hot (Xilinx attribute preserved)
//!
//! @author  QICK Development Team
//!
//! @version 1.0
`include "tproc_pkg.sv"

module tpv1_ctrl(
    input  logic        clk,
    input  logic        rstn,

    // Start/stop
    input  logic        start,

    // Opcode from IR
    input  logic [7:0]  opcode,

    // IR control
    output logic        ir_en,

    // Program counter control
    output logic        pc_src,
    output logic        pc_en,
    output logic        pc_rst,

    // ALU control
    output logic [1:0]  alu_src_b,
    input  logic        alu_zero,

    // ALU Time control
    output logic        alut_src_b,

    // Register file write control
    output logic [2:0]  reg_src,
    output logic        reg_wen,

    // Conditional jump flag
    input  logic        cond_flag,

    // Stack control
    output logic        stack_en,
    output logic        stack_op,
    input  logic        stack_full,
    input  logic        stack_empty,

    // Timed-instruction FIFO control
    output logic        fifo_wr_en,
    input  logic        fifo_full,

    // Data memory control
    output logic        dmem_we,
    output logic        addr_src,

    // Master clock control
    output logic        t_en,
    output logic        t_sync_en,

    // Wait handshake
    input  logic        waitt,
    output logic        waitt_ack
  );

  import tproc_pkg::*;

  //--------------------------------------------------------------------------
  // FSM State Encoding (one_hot for Xilinx synthesis)
  //--------------------------------------------------------------------------
  (* fsm_encoding = "one_hot" *)  tpv1_ctrl_state_t state;

  // Internal flags qualifying pc_en / pc_src output muxes
  logic state_loopnz;
  logic state_condj;

  // Internal output signals
  logic        ir_en_i;
  logic        pc_src_i;
  logic        pc_en_i;
  logic        pc_rst_i;
  logic [1:0]  alu_src_b_i;
  logic        alut_src_b_i;
  logic [2:0]  reg_src_i;
  logic        reg_wen_i;
  logic        stack_en_i;
  logic        stack_op_i;
  logic        fifo_wr_en_i;
  logic        dmem_we_i;
  logic        addr_src_i;
  logic        t_en_i;
  logic        t_sync_en_i;
  logic        waitt_ack_i;

  //--------------------------------------------------------------------------
  // FSM: Sequential State Register
  //--------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!rstn) begin
      state <= INIT_ST;
    end else begin
      unique case (state)
        INIT_ST:
          if (start) state <= PC_RST_ST;

        PC_RST_ST:  state <= START_MC_ST;
        START_MC_ST: state <= FETCH_ST;
        FETCH_ST:   state <= DECODE_ST;

        DECODE_ST: begin
          unique case (opcode)
            OP_PUSHI :             state <= PUSHI0_ST;
            OP_POPI  :             state <= POPI0_ST;
            OP_MATHI :             state <= MATHI0_ST;
            OP_SETI,  OP_SETBI :   state <= SETI0_ST;
            OP_SYNCI :             state <= SYNCI0_ST;
            OP_WAITI :             state <= WAITI0_ST;
            OP_BITWI :             state <= BITWI0_ST;
            OP_MEMRI :             state <= MEMRI0_ST;
            OP_MEMWI :             state <= MEMWI0_ST;
            OP_REGWI :             state <= REGWI0_ST;
            OP_LOOPNZ:             state <= LOOPNZ0_ST;
            OP_CONDJ :             state <= CONDJ0_ST;
            OP_END   :             state <= END_ST;
            OP_MATH  :             state <= MATH0_ST;
            OP_SET,   OP_SETB :    state <= SET0_ST;
            OP_SYNC  :             state <= SYNC0_ST;
            OP_READ  :             state <= READ0_ST;
            OP_WAIT  :             state <= WAIT0_ST;
            OP_BITW  :             state <= BITW0_ST;
            OP_MEMR  :             state <= MEMR0_ST;
            OP_MEMW  :             state <= MEMW0_ST;
            default  :             state <= ERR_INSTR_ST;
          endcase
        end

        // MATHI pipeline (4 cycles)
        MATHI0_ST:  state <= MATHI1_ST;
        MATHI1_ST:  state <= MATHI2_ST;
        MATHI2_ST:  state <= MATHI3_ST;
        MATHI3_ST:  state <= DECODE_ST;

        // BITWI pipeline (4 cycles)
        BITWI0_ST:  state <= BITWI1_ST;
        BITWI1_ST:  state <= BITWI2_ST;
        BITWI2_ST:  state <= BITWI3_ST;
        BITWI3_ST:  state <= DECODE_ST;

        // MATH pipeline (4 cycles)
        MATH0_ST:   state <= MATH1_ST;
        MATH1_ST:   state <= MATH2_ST;
        MATH2_ST:   state <= MATH3_ST;
        MATH3_ST:   state <= DECODE_ST;

        // BITW pipeline (4 cycles)
        BITW0_ST:   state <= BITW1_ST;
        BITW1_ST:   state <= BITW2_ST;
        BITW2_ST:   state <= BITW3_ST;
        BITW3_ST:   state <= DECODE_ST;

        // Stack
        PUSHI0_ST:
          state <= stack_full ? ERR_STACK_ST : DECODE_ST;
        POPI0_ST:
          state <= stack_empty ? ERR_STACK_ST : POPI1_ST;
        POPI1_ST:   state <= POPI2_ST;
        POPI2_ST:   state <= DECODE_ST;

        // Loop
        LOOPNZ0_ST: state <= alu_zero ? FETCH_ST : LOOPNZ1_ST;
        LOOPNZ1_ST: state <= LOOPNZ2_ST;
        LOOPNZ2_ST: state <= LOOPNZ3_ST;
        LOOPNZ3_ST: state <= FETCH_ST;

        // Timed set (immediate)
        SETI0_ST:   state <= SETI1_ST;
        SETI1_ST:   if (!fifo_full) state <= FETCH_ST;

        // Timed set (register)
        SET0_ST:    state <= SET1_ST;
        SET1_ST:    if (!fifo_full) state <= FETCH_ST;

        // Sync
        SYNCI0_ST:  state <= SYNCI1_ST;
        SYNCI1_ST:  state <= DECODE_ST;
        SYNC0_ST:   state <= SYNC1_ST;
        SYNC1_ST:   state <= DECODE_ST;

        // Conditional jump
        CONDJ0_ST:  state <= CONDJ1_ST;
        CONDJ1_ST:  state <= cond_flag ? CONDJ2_ST : FETCH_ST;
        CONDJ2_ST:  state <= FETCH_ST;

        // Read input port
        READ0_ST:   state <= DECODE_ST;

        // Memory read (immediate address)
        MEMRI0_ST:  state <= MEMRI1_ST;
        MEMRI1_ST:  state <= MEMRI2_ST;
        MEMRI2_ST:  state <= DECODE_ST;

        // Memory read (register address)
        MEMR0_ST:   state <= MEMR1_ST;
        MEMR1_ST:   state <= MEMR2_ST;
        MEMR2_ST:   state <= DECODE_ST;

        // Memory write
        MEMWI0_ST:  state <= DECODE_ST;
        MEMW0_ST:   state <= DECODE_ST;

        // Register write immediate
        REGWI0_ST:  state <= DECODE_ST;

        // Timed wait (immediate)
        WAITI0_ST:  state <= WAITI1_ST;
        WAITI1_ST:  if (!fifo_full) state <= WAIT_ACK_ST;

        // Timed wait (register)
        WAIT0_ST:   state <= WAIT1_ST;
        WAIT1_ST:   if (!fifo_full) state <= WAIT_ACK_ST;

        // Wait for timed_ictrl acknowledgement
        WAIT_ACK_ST: if (waitt) state <= FETCH_ST;

        // Error / terminal
        ERR_INSTR_ST: state <= END_ST;
        ERR_STACK_ST: state <= END_ST;
        END_ST:       if (!start) state <= INIT_ST;

        default: state <= INIT_ST;
      endcase
    end
  end

  //--------------------------------------------------------------------------
  // FSM: Combinational Output Logic
  //--------------------------------------------------------------------------
  always_comb begin
    // Safe defaults
    state_loopnz  = 1'b0;
    state_condj   = 1'b0;
    ir_en_i       = 1'b0;
    pc_src_i      = 1'b0;
    pc_en_i       = 1'b0;
    pc_rst_i      = 1'b0;
    alu_src_b_i   = 2'b00;
    alut_src_b_i  = 1'b0;
    reg_src_i     = 3'b000;
    reg_wen_i     = 1'b0;
    stack_en_i    = 1'b0;
    stack_op_i    = 1'b0;
    fifo_wr_en_i  = 1'b0;
    dmem_we_i     = 1'b0;
    addr_src_i    = 1'b0;
    t_en_i        = 1'b1;  // master clock runs by default
    t_sync_en_i   = 1'b0;
    waitt_ack_i   = 1'b0;

    unique case (state)
      PC_RST_ST:
        pc_rst_i      = 1'b1;

      START_MC_ST:
        t_en_i        = 1'b0;  // hold master clock during startup

      FETCH_ST: begin
        ir_en_i       = 1'b1;
        pc_src_i      = 1'b0;
        pc_en_i       = 1'b1;
      end

      // MATHI: alu_src_b=imm across all pipeline stages; write on _3
      MATHI0_ST, MATHI1_ST, MATHI2_ST:
        alu_src_b_i   = 2'b00;
      MATHI3_ST: begin
        ir_en_i       = 1'b1;
        pc_src_i      = 1'b0;
        pc_en_i       = 1'b1;
        alu_src_b_i   = 2'b00;
        reg_src_i     = 3'b001;
        reg_wen_i     = 1'b1;
      end

      // BITWI: same structure as MATHI
      BITWI0_ST, BITWI1_ST, BITWI2_ST:
        alu_src_b_i   = 2'b00;
      BITWI3_ST: begin
        ir_en_i       = 1'b1;
        pc_src_i      = 1'b0;
        pc_en_i       = 1'b1;
        alu_src_b_i   = 2'b00;
        reg_src_i     = 3'b001;
        reg_wen_i     = 1'b1;
      end

      // MATH: alu_src_b=D1
      MATH0_ST, MATH1_ST, MATH2_ST:
        alu_src_b_i   = 2'b01;
      MATH3_ST: begin
        ir_en_i       = 1'b1;
        pc_src_i      = 1'b0;
        pc_en_i       = 1'b1;
        alu_src_b_i   = 2'b01;
        reg_src_i     = 3'b001;
        reg_wen_i     = 1'b1;
      end

      // BITW: same structure as MATH
      BITW0_ST, BITW1_ST, BITW2_ST:
        alu_src_b_i   = 2'b01;
      BITW3_ST: begin
        ir_en_i       = 1'b1;
        pc_src_i      = 1'b0;
        pc_en_i       = 1'b1;
        alu_src_b_i   = 2'b01;
        reg_src_i     = 3'b001;
        reg_wen_i     = 1'b1;
      end

      PUSHI0_ST: begin
        ir_en_i       = 1'b1;
        pc_src_i      = 1'b0;
        pc_en_i       = 1'b1;
        reg_src_i     = 3'b000;  // imm
        reg_wen_i     = 1'b1;
        stack_en_i    = 1'b1;
        stack_op_i    = 1'b1;    // push
      end

      POPI0_ST: begin
        stack_en_i    = 1'b1;
        stack_op_i    = 1'b0;    // pop
      end
      POPI1_ST:
        reg_src_i     = 3'b010;  // stack out
      POPI2_ST: begin
        ir_en_i       = 1'b1;
        pc_src_i      = 1'b0;
        pc_en_i       = 1'b1;
        reg_src_i     = 3'b010;
        reg_wen_i     = 1'b1;
      end

      // LOOPNZ: pc_src=jump, alu_src_b=-1 during countdown stages
      LOOPNZ0_ST, LOOPNZ1_ST, LOOPNZ2_ST: begin
        state_loopnz  = 1'b1;
        pc_src_i      = 1'b1;
        pc_en_i       = 1'b1;
        alu_src_b_i   = 2'b10;  // -1
      end
      LOOPNZ3_ST: begin
        reg_src_i     = 3'b001;  // ALU out (decremented value)
        reg_wen_i     = 1'b1;
      end

      // SETI/SETBI: alut_src_b=imm; write FIFO on _1
      SETI0_ST:
        alut_src_b_i  = 1'b1;
      SETI1_ST: begin
        alut_src_b_i  = 1'b1;
        fifo_wr_en_i  = 1'b1;
      end

      // SET/SETB: alut_src_b=reg; write FIFO on _1
      SET0_ST:
        alut_src_b_i  = 1'b0;
      SET1_ST: begin
        alut_src_b_i  = 1'b0;
        fifo_wr_en_i  = 1'b1;
      end

      // SYNCI
      SYNCI0_ST:
        alut_src_b_i  = 1'b1;
      SYNCI1_ST: begin
        ir_en_i       = 1'b1;
        pc_src_i      = 1'b0;
        pc_en_i       = 1'b1;
        alut_src_b_i  = 1'b1;
        t_sync_en_i   = 1'b1;
      end

      // SYNC
      SYNC0_ST:
        alut_src_b_i  = 1'b0;
      SYNC1_ST: begin
        ir_en_i       = 1'b1;
        pc_src_i      = 1'b0;
        pc_en_i       = 1'b1;
        alut_src_b_i  = 1'b0;
        t_sync_en_i   = 1'b1;
      end

      // CONDJ
      CONDJ0_ST:
        state_condj   = 1'b1;
      CONDJ1_ST: begin
        state_condj   = 1'b1;
        pc_src_i      = 1'b1;
        pc_en_i       = 1'b1;
      end
      CONDJ2_ST:
        state_condj   = 1'b1;

      // READ from s_axis input port
      READ0_ST: begin
        ir_en_i       = 1'b1;
        pc_src_i      = 1'b0;
        pc_en_i       = 1'b1;
        reg_src_i     = 3'b011;  // s_axis input
        reg_wen_i     = 1'b1;
      end

      // MEMRI: read from memory at immediate address (3 cycles)
      MEMRI0_ST, MEMRI1_ST: begin
        reg_src_i     = 3'b100;
        dmem_we_i     = 1'b0;
        addr_src_i    = 1'b0;   // imm
      end
      MEMRI2_ST: begin
        ir_en_i       = 1'b1;
        pc_src_i      = 1'b0;
        pc_en_i       = 1'b1;
        reg_src_i     = 3'b100;
        reg_wen_i     = 1'b1;
        dmem_we_i     = 1'b0;
        addr_src_i    = 1'b0;
      end

      // MEMR: read from memory at register address (3 cycles)
      MEMR0_ST, MEMR1_ST: begin
        reg_src_i     = 3'b100;
        dmem_we_i     = 1'b0;
        addr_src_i    = 1'b1;   // reg
      end
      MEMR2_ST: begin
        ir_en_i       = 1'b1;
        pc_src_i      = 1'b0;
        pc_en_i       = 1'b1;
        reg_src_i     = 3'b100;
        reg_wen_i     = 1'b1;
        dmem_we_i     = 1'b0;
        addr_src_i    = 1'b1;
      end

      // MEMWI: write memory at immediate address
      MEMWI0_ST: begin
        ir_en_i       = 1'b1;
        pc_src_i      = 1'b0;
        pc_en_i       = 1'b1;
        dmem_we_i     = 1'b1;
        addr_src_i    = 1'b0;
      end

      // MEMW: write memory at register address
      MEMW0_ST: begin
        ir_en_i       = 1'b1;
        pc_src_i      = 1'b0;
        pc_en_i       = 1'b1;
        dmem_we_i     = 1'b1;
        addr_src_i    = 1'b1;
      end

      // REGWI: write immediate into register
      REGWI0_ST: begin
        ir_en_i       = 1'b1;
        pc_src_i      = 1'b0;
        pc_en_i       = 1'b1;
        reg_src_i     = 3'b000;  // imm
        reg_wen_i     = 1'b1;
      end

      // WAITI: timed wait (immediate timestamp)
      WAITI0_ST:
        alut_src_b_i  = 1'b1;
      WAITI1_ST: begin
        alut_src_b_i  = 1'b1;
        fifo_wr_en_i  = 1'b1;
      end

      // WAIT: timed wait (register timestamp)
      WAIT0_ST:
        alut_src_b_i  = 1'b0;
      WAIT1_ST: begin
        alut_src_b_i  = 1'b0;
        fifo_wr_en_i  = 1'b1;
      end

      // Wait for timed_ictrl to signal completion
      WAIT_ACK_ST:
        waitt_ack_i   = 1'b1;

      // All other states (INIT, DECODE, ERROR, END): keep defaults
      default: ;
    endcase
  end

  //--------------------------------------------------------------------------
  // Output Assignments (with conditional qualifications for PC)
  //--------------------------------------------------------------------------
  assign ir_en      = ir_en_i;
  assign pc_rst     = pc_rst_i;
  assign alu_src_b  = alu_src_b_i;
  assign alut_src_b = alut_src_b_i;
  assign reg_src    = reg_src_i;
  assign reg_wen    = reg_wen_i;
  assign stack_en   = stack_en_i;
  assign stack_op   = stack_op_i;
  assign fifo_wr_en = fifo_wr_en_i;
  assign dmem_we    = dmem_we_i;
  assign addr_src   = addr_src_i;
  assign t_en       = t_en_i;
  assign t_sync_en  = t_sync_en_i;
  assign waitt_ack  = waitt_ack_i;

  // pc_src: during condj, gate with cond_flag
  assign pc_src = state_condj ? (pc_src_i & cond_flag) : pc_src_i;

  // pc_en: qualified by alu_zero (loopnz) or cond_flag (condj)
  assign pc_en =
    ( state_loopnz & !state_condj) ? (pc_en_i & !alu_zero)  :
    (!state_loopnz &  state_condj) ? (pc_en_i &  cond_flag) :
                                     pc_en_i;

endmodule

