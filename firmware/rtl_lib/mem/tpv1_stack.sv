//------------------------------------------------------------------------------
// Module: tpv1_stack
// Description:
//   Stack block with 256 words (8-bit address).
//   - op=1: push operation (write to stack, pointer decrements).
//   - op=0: pop operation  (read from stack, pointer increments).
//   Empty when sp=255, full when sp=0.
//
// Parameters:
//   B - Data width in bits (default: 16).
//
// Ports:
//   clk   - Clock input.
//   rstn  - Active-low reset (sets sp to all 1s = empty).
//   en    - Enable signal.
//   op    - Operation: 1=push, 0=pop.
//   din   - Input data (B bits).
//   dout  - Output data (B bits).
//   empty - Empty flag (1 when stack is empty).
//   full  - Full flag (1 when stack is full).
//
// Dependencies:
//   bram - Simple dual-port BRAM (N address bits, B data bits).
//
// Notes:
//   - Push writes to sp, then sp--
//   - Pop reads from sp+1, then sp++
//   - Write enable on BRAM is op (write during push, read during pop).
//   - Auto-generated conversion from VHDL. Review before use.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : tpv1_stack
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    tpv1_stack.sv
//!
//! @brief   TODO: one-line description.
//!
//! @author  QICK Development Team
//!
//! @version 1.0

module tpv1_stack #(
    parameter int B = 16,       // Data width
    parameter int N = 8         // Address width (2^N words)
) (
    // Clock and reset
    input  logic               clk,
    input  logic               rstn,

    // Control
    input  logic               en,
    input  logic               op,    // 1=push, 0=pop

    // Data
    input  logic [B-1:0]       din,
    output logic [B-1:0]       dout,

    // Flags
    output logic               empty,
    output logic               full
);

    //--------------------------------------------------------------------------
    // Local parameters
    //--------------------------------------------------------------------------
    localparam int MAX = (1 << N) - 1;     // Max stack pointer value (empty)

    //--------------------------------------------------------------------------
    // Internal signals
    //--------------------------------------------------------------------------
    logic [N-1:0] mem_addr;       // BRAM address
    logic [N-1:0] sp;             // Stack pointer (next write address)
    logic [N-1:0] sp_1;           // Stack pointer + 1 (read address)
    logic         empty_i;        // Internal empty flag
    logic         full_i;         // Internal full flag

    //--------------------------------------------------------------------------
    // BRAM instance
    //--------------------------------------------------------------------------
    bram_simple_sp #(
        .NB_DATA            ( B           ),
        .NB_ADDR            ( N           ),
        .MEM_BIN_FILE       ( ""          )
    ) bram_i (
        .i_clk              ( clk         ),
        .i_ena              ( en          ),    // Write: enabled AND push
        .i_wea              ( op          ),    // Read: enabled AND pop
        .i_addra            ( mem_addr    ),    // Write to sp (current pointer)
        .i_dia              ( din         ),
        .o_doa              ( dout        )
    );

    //--------------------------------------------------------------------------
    // Stack pointer register
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rstn) begin
            sp <= MAX;             // Reset to empty
        end else if (en) begin
            if (op) begin          // Push
                if (!full_i) begin
                    sp <= sp - 1'b1;
                end
            end else begin         // Pop
                if (!empty_i) begin
                    sp <= sp + 1'b1;
                end
            end
        end
    end

    //--------------------------------------------------------------------------
    // Read address (sp + 1)
    //--------------------------------------------------------------------------
    assign sp_1 = sp + 1'b1;

    //--------------------------------------------------------------------------
    // Memory address mux
    //   push: write to sp
    //   pop:  read from sp+1
    //--------------------------------------------------------------------------
    assign mem_addr = op ? sp : sp_1;

    //--------------------------------------------------------------------------
    // Empty / Full flags
    //--------------------------------------------------------------------------
    assign empty_i = (sp == MAX);
    assign full_i  = (sp == '0);

    assign empty = empty_i;
    assign full  = full_i;

endmodule
