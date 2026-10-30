///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : restoring_divider
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    restoring_divider.sv
//!
//! @brief   Bit-serial (DW-cycle) unsigned restoring divider, used by tProcessor v2.
//!
//! @details
//!
//! Faithful port of `div_r` (firmware/ip/qick_processor/src/_qproc_ips.sv),
//! instantiated once in `qick_processor.sv`. Computes `A_i / B_i` (unsigned,
//! DW bits) as `div_quotient_o` / `div_remainder_o`, one quotient bit per
//! clock over DW cycles, using the classic shift/compare/subtract restoring
//! algorithm. Pulse `start_i` for one cycle to launch a division; `ready_o`
//! is high while idle and goes low for the duration of the computation.
//! Behavior with `B_i == 0` is whatever falls out of the restoring algorithm
//! (no explicit divide-by-zero guard in the original — not added here).
//!
//! Inherited quirk (traced from the original, not introduced by this port):
//! the FSM only runs DW-1 "working" cycles before `ind_bit` reaches 0 and
//! `div_end` fires (the `div_end` branch has priority over `working` in the
//! register update, so the last iteration's result for bit index DW-1 is
//! never computed). `div_quotient_o[DW-1]` is therefore always 0 -
//! effectively a (DW-1)-bit unsigned quotient out of a DW-bit divider.
//! Verified empirically by this port's testbench; not "fixed" here, to
//! stay a faithful translation.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module restoring_divider #(
    parameter int DW = 32
)(
    input  logic             clk_i,
    input  logic             rst_ni,
    input  logic             start_i,
    input  logic [DW-1:0]    a_i,
    input  logic [DW-1:0]    b_i,
    output logic             ready_o,
    output logic [DW-1:0]    div_quotient_o,
    output logic [DW-1:0]    div_remainder_o
);

    logic [DW-1:0] inb;
    logic [DW-1:0] r_temp, q_temp;
    logic [4:0]    ind_bit;

    logic working;

    logic             qtb;
    logic [2*DW-1:0]  sub_temp;
    logic [DW-1:0]    r_temp_nxt;

    logic [31:0] ind_bit_m1;
    logic        div_start, div_end;

    assign ind_bit_m1 = ind_bit - 5'b00001;
    assign div_start  = start_i;
    assign div_end    = (ind_bit == 0);

    // State machine
    ///////////////////////////////////////////////////////////////////////
    typedef enum {IDLE, WORKING} div_st_t;
    div_st_t div_st, div_st_nxt;

    always_ff @(posedge clk_i)
        if (!rst_ni) div_st <= IDLE;
        else         div_st <= div_st_nxt;

    always_comb begin
        div_st_nxt = div_st;
        working    = 1'b0;
        case (div_st)
            IDLE: begin
                if (div_start) div_st_nxt = WORKING;
            end
            WORKING: begin
                working = 1'b1;
                if (div_end) div_st_nxt = IDLE;
            end
            default: ;
        endcase
    end

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            ind_bit <= 31;
            q_temp  <= 0;
            r_temp  <= 0;
        end else if (div_start) begin
            ind_bit <= 31;
            q_temp  <= 0;
            r_temp  <= a_i;
            inb     <= b_i;
        end else if (div_end) begin
            ind_bit <= 31;
            q_temp  <= 0;
            r_temp  <= a_i;
            inb     <= b_i;
        end else if (working) begin
            ind_bit             <= ind_bit_m1[4:0];
            r_temp              <= r_temp_nxt;
            q_temp[ind_bit_m1]  <= qtb;
        end
    end

    ///////////////////////////////////////////////////////////////////////
    // Combinational part
    always_comb begin
        qtb        = 1'b0;
        r_temp_nxt = r_temp;
        sub_temp   = inb << ind_bit_m1;
        if (r_temp_nxt >= sub_temp) begin
            qtb        = 1'b1;
            r_temp_nxt = r_temp_nxt - sub_temp;
        end
    end

    ///////////////////////////////////////////////////////////////////////
    // Output register
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            div_quotient_o  <= 0;
            div_remainder_o <= 0;
        end else if (div_end) begin
            div_quotient_o  <= q_temp;
            div_remainder_o <= r_temp_nxt;
        end
    end

    assign ready_o = ~working;

endmodule
