///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : tpv2_stack
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    tpv2_stack.sv
//!
//! @brief   Register-based CALL/RET program-counter stack for tProcessor v2.
//!
//! @details
//!
//! Faithful port of `LIFO` (firmware/ip/qick_processor/src/_qproc_ips.sv),
//! whose only instance in the original is `qcore_cpu`'s `pc_stack_inst`
//! (WIDTH = PMEM_AW, DEPTH = 8). On `push`, `data_i` is written at `ptr` and
//! `ptr` increments; on `pop`, `ptr` decrements and `data_o` presents the
//! entry below the new `ptr` (`stack[ptr-1]`, i.e. push-then-read-back is
//! combinational through `data_o`, not registered). `push` takes priority
//! over `pop` when both are asserted in the same cycle.
//!
//! Inherited from the original (not changed by this port):
//! - The pointer is a fixed 3-bit counter (0-7) regardless of DEPTH, and
//! `full_o` compares it against DEPTH. For DEPTH=8 (the only value ever
//! instantiated) the 3-bit pointer can never equal 8, so `full_o` never
//! asserts; an 8th push wraps `ptr` back to 0 and silently overwrites
//! `stack[0]`. This module preserves that behavior rather than
//! generalizing the pointer width, to stay a faithful translation.
//! - No `empty_o` port: the original never exposed one (its only consumer,
//! `qcore_cpu`, does not check it), so `pop` on an empty stack is not
//! guarded by this module.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module tpv2_stack #(
    parameter int WIDTH = 16,  //! entry width in bits
    parameter int DEPTH = 8    //! MAX 8 - see @details (pointer is fixed 3-bit)
)(
    input  logic             clk_i,
    input  logic             rst_ni,
    input  logic [WIDTH-1:0] data_i,
    input  logic             push,
    input  logic             pop,
    output logic [WIDTH-1:0] data_o,
    output logic             full_o
);

    logic [2:0]         ptr_p1, ptr_m1;
    logic [2:0]         ptr;
    logic [WIDTH-1:0]   stack [DEPTH];

    assign ptr_p1 = ptr + 3'b001;
    assign ptr_m1 = ptr - 3'b001;

    always_ff @(posedge clk_i) begin
        if (!rst_ni)              ptr <= '0;
        else if (push & !full_o)  ptr <= ptr_p1;
        else if (pop  & !(~|ptr)) ptr <= ptr_m1;
    end

    always_ff @(posedge clk_i) begin
        if (!rst_ni)             stack <= '{default: '0};
        else if (push & !full_o) stack[ptr] <= data_i;
    end

    // NOTE: deliberately NOT truncating DEPTH to ptr's 3-bit width — the
    // original relies on Verilog's implicit zero-extension of `ptr` here,
    // which is exactly why full_o never asserts for DEPTH=8 (see @details).
    assign full_o = ~|(32'(ptr) ^ DEPTH);
    assign data_o = stack[ptr_m1];

endmodule
