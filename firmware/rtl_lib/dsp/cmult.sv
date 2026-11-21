`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : cmult
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    cmult.sv
//!
//! @brief   Configurable complex (I/Q) multiplier with optional conjugation,
//!
//! @details
//!
//!
//! rounding and saturation.
//!
//! Computes  dout = op(dina) * op(dinb)  where op() optionally
//! conjugates each operand:
//! a = a_r + j*a_i    (a_i negated if conja)
//! b = b_r + j*b_i    (b_i negated if conjb)
//! dout_real = a_r*b_r - a_i*b_i     (ac - bd)
//! dout_imag = a_r*b_i + a_i*b_r     (ad + bc)
//!
//! Packing convention (matches iir_iq / kidsim datapath):
//! dina/dinb/dout = { Q[.-1:0], I[.-1:0] }  (I low half, Q high).
//!
//! Fixed-point handling (anti-overflow):
//!
//!
//! - Each partial product a*b is signed (BIN x BIN) -> 2*BIN bits.
//! - Sum/difference of two partial products is accumulated with ONE
//! guard bit (ACCW = 2*BIN+1) so ac-bd / ad+bc never overflow.
//!
//!
//! - Accumulator is re-quantized to BOUT bits: a Q(BIN-1)*Q(BIN-1)
//! product has its binary point at bit (2*BIN-2); the top BOUT bits
//! from there are taken (dropping the duplicated sign bit).
//!
//!
//! - ROUND=1 adds a half-LSB before truncation (round half-up).
//! - SAT=1 clamps to +/- full-scale instead of wrapping.
//!
//! Conjugation is static (CONJA/CONJB) or dynamic (i_conja/i_conjb)
//! when CONF_DYNAMIC=1.
//!
//! Pipeline latency = 4 valid cycles. Feed-forward (no recursion) so it
//! tolerates bubbles on i_valid naturally.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module cmult #(
    parameter int BIN          = 16,    //! Per-component input width, Q(BIN-1).
    parameter int BOUT         = 16,    //! Per-component output width, Q(BOUT-1).
    parameter bit CONJA        = 1'b0,  //! Static conjugate A (when CONF_DYNAMIC=0).
    parameter bit CONJB        = 1'b0,  //! Static conjugate B (when CONF_DYNAMIC=0).
    parameter bit CONF_DYNAMIC = 1'b0,  //! 1: use i_conja/i_conjb; 0: use params.
    parameter bit ROUND        = 1'b1,  //! 1: round half-up; 0: truncate.
    parameter bit SAT          = 1'b1   //! 1: saturate to +/- full-scale; 0: wrap.
)(
    input  logic                 i_clk,    //! System clock (rising edge).
    input  logic                 i_rstn,   //! Synchronous reset, active low.
    input  logic                 i_conja,  //! Dynamic conjugate-A (if CONF_DYNAMIC).
    input  logic                 i_conjb,  //! Dynamic conjugate-B (if CONF_DYNAMIC).
    input  logic                 i_valid,  //! Input valid qualifier.
    input  logic [2*BIN-1:0]     i_dina,   //! Packed complex operand A { Q, I }.
    input  logic [2*BIN-1:0]     i_dinb,   //! Packed complex operand B { Q, I }.
    output logic                 o_valid,  //! Output valid (latency = 4).
    output logic [2*BOUT-1:0]    o_dout    //! Packed complex product { Q, I }.
);
    //-------------------------------------------------------------------------
    // Derived parameters
    //-------------------------------------------------------------------------
    localparam int PW    = 2*BIN;                   //! Partial-product width.
    localparam int ACCW  = 2*BIN + 1;               //! Accumulator width (1 guard).
    localparam int SHIFT = (2*BIN-2) - (BOUT-1);    //! LSBs dropped on quantize.
    localparam logic signed [BOUT-1:0] SAT_MAX =  (1 <<< (BOUT-1)) - 1; //! +full-scale.
    localparam logic signed [BOUT-1:0] SAT_MIN = -(1 <<< (BOUT-1));     //! -full-scale.

    //! Conjugation selects (static or dynamic).
    logic conja_s, conjb_s;
    assign conja_s = CONF_DYNAMIC ? i_conja : CONJA;
    assign conjb_s = CONF_DYNAMIC ? i_conjb : CONJB;

    //! Stage 0: registered inputs + conj selects.
    logic [2*BIN-1:0] dina_r, dinb_r;
    logic             conja_r, conjb_r;

    //! Operand components (imag sign handled by conj).
    logic signed [BIN-1:0] a_re, a_im, b_re, b_im;
    assign a_re = dina_r[0     +: BIN];
    assign a_im = conja_r ? -$signed(dina_r[BIN +: BIN]) : $signed(dina_r[BIN +: BIN]);
    assign b_re = dinb_r[0     +: BIN];
    assign b_im = conjb_r ? -$signed(dinb_r[BIN +: BIN]) : $signed(dinb_r[BIN +: BIN]);

    //! Stage 1: partial products.
    logic signed [PW-1:0] pp_rr, pp_ii, pp_ri, pp_ir;
    assign pp_rr = a_re * b_re;
    assign pp_ii = a_im * b_im;
    assign pp_ri = a_re * b_im;
    assign pp_ir = a_im * b_re;
    logic signed [PW-1:0] pp_rr_r, pp_ii_r, pp_ri_r, pp_ir_r;

    //! Stage 2: accumulate with guard bit (no overflow).
    logic signed [ACCW-1:0] acc_re, acc_im;
    assign acc_re = ACCW'(pp_rr_r) - ACCW'(pp_ii_r);   //! ac - bd
    assign acc_im = ACCW'(pp_ri_r) + ACCW'(pp_ir_r);   //! ad + bc
    logic signed [ACCW-1:0] acc_re_r, acc_im_r;

    //! Stage 3: round + saturate to BOUT.
    logic signed [BOUT-1:0] q_re_r, q_im_r;

    //! Re-quantize an accumulator value to BOUT bits (round + saturate).
    function automatic logic signed [BOUT-1:0] requant(input logic signed [ACCW-1:0] acc);
        logic signed [ACCW-1:0] v;
        logic signed [BOUT-1:0] out;
        begin
            v = acc;
            if (ROUND && (SHIFT > 0))
                v = v + (1 <<< (SHIFT-1));
            out = BOUT'(v >>> SHIFT);
            if (SAT) begin
                if      ((v >>> SHIFT) > SAT_MAX) out = SAT_MAX;
                else if ((v >>> SHIFT) < SAT_MIN) out = SAT_MIN;
            end
            return out;
        end
    endfunction

    //! Valid pipeline (latency = 4).
    logic valid_r1, valid_r2, valid_r3, valid_r4;

    always_ff @(posedge i_clk) begin
        if (~i_rstn) begin
            dina_r   <= '0;  dinb_r   <= '0;
            conja_r  <= 1'b0; conjb_r  <= 1'b0;
            pp_rr_r  <= '0;  pp_ii_r  <= '0;  pp_ri_r <= '0;  pp_ir_r <= '0;
            acc_re_r <= '0;  acc_im_r <= '0;
            q_re_r   <= '0;  q_im_r   <= '0;
            valid_r1 <= 1'b0; valid_r2 <= 1'b0; valid_r3 <= 1'b0; valid_r4 <= 1'b0;
        end
        else begin
            // Stage 0
            dina_r  <= i_dina;
            dinb_r  <= i_dinb;
            conja_r <= conja_s;
            conjb_r <= conjb_s;
            // Stage 1
            pp_rr_r <= pp_rr;
            pp_ii_r <= pp_ii;
            pp_ri_r <= pp_ri;
            pp_ir_r <= pp_ir;
            // Stage 2
            acc_re_r <= acc_re;
            acc_im_r <= acc_im;
            // Stage 3
            q_re_r  <= requant(acc_re_r);
            q_im_r  <= requant(acc_im_r);
            // Valid pipeline
            valid_r1 <= i_valid;
            valid_r2 <= valid_r1;
            valid_r3 <= valid_r2;
            valid_r4 <= valid_r3;
        end
    end

    //! Outputs (repack { Q, I }).
    assign o_dout  = {q_im_r, q_re_r};
    assign o_valid = valid_r4;

`ifndef SYNTHESIS
    initial begin
        assert (BOUT <= 2*BIN)
            else $error("cmult: BOUT (%0d) > 2*BIN (%0d) not supported", BOUT, 2*BIN);
        assert (SHIFT >= 0)
            else $error("cmult: negative SHIFT (%0d); check BIN/BOUT", SHIFT);
    end
`endif // SYNTHESIS
endmodule

