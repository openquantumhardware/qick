///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : tpv2_arith
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    tpv2_arith.sv
//!
//! @brief   DSP48-backed multiply-accumulate peripheral for tProcessor v2
//! (the "user peripheral" reachable from software via `usr_ctrl`).
//!
//! @details
//!
//! Faithful port of `arith` (firmware/ip/qick_processor/src/_qproc_ips.sv),
//! instantiated once in `qick_processor.sv` (gated by the `ARITH` generate
//! parameter). Pulse `start_i` for one cycle with `a_i`/`b_i`/`c_i`/`d_i` and
//! `alu_op_i` (only bits [3:0] used; see `tpv2_dsp_macro` for the 9-way
//! instruction table) valid; `ready_o` is high while idle and low for a
//! fixed 4 clock cycles while the DSP macro computes. `arith_result_o` is
//! the DSP macro's 46-bit product/sum, sign-extended to 64 bits.
//!
//! Latency is fixed by this module's own `working`/`working_r`/`working_r2`/
//! `working_r3` chain (not derived from `tpv2_dsp_macro`), exactly as in the
//! original — a real change to the underlying DSP48 pipeline depth would
//! silently desync `ready_o` from `arith_result_o` in the original design
//! too; this port does not change that.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module tpv2_arith (
    input  logic                clk_i,
    input  logic                rst_ni,
    input  logic                start_i,
    input  logic signed [31:0]  a_i,
    input  logic signed [31:0]  b_i,
    input  logic signed [31:0]  c_i,
    input  logic signed [31:0]  d_i,
    input  logic         [4:0]  alu_op_i,
    output logic                ready_o,
    output logic signed [63:0]  arith_result_o
);

    logic signed [45:0] arith_result;
    logic         [3:0] alu_op_r;
    logic signed [26:0] a_dt;
    logic signed [17:0] b_dt;
    logic signed [31:0] c_dt;
    logic signed [26:0] d_dt;
    logic working, working_r, working_r2, working_r3;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            a_dt       <= '0;
            b_dt       <= '0;
            c_dt       <= '0;
            d_dt       <= '0;
            alu_op_r   <= '0;
            working    <= 1'b0;
            working_r  <= 1'b0;
            working_r2 <= 1'b0;
            working_r3 <= 1'b0;
        end else begin
            working_r  <= working;
            working_r2 <= working_r;
            working_r3 <= working_r2;
            if (start_i) begin
                a_dt     <= a_i[26:0];
                b_dt     <= b_i[17:0];
                c_dt     <= c_i[31:0];
                d_dt     <= d_i[26:0];
                alu_op_r <= alu_op_i[3:0];
                working  <= 1'b1;
            end else if (working_r3) begin
                working    <= 1'b0;
                working_r  <= 1'b0;
                working_r2 <= 1'b0;
                working_r3 <= 1'b0;
            end
        end
    end

    tpv2_dsp_macro dsp_i (
        .clk_i (clk_i),
        .sel_i (alu_op_r),
        .a_i   (a_dt),
        .b_i   (b_dt),
        .c_i   (c_dt),
        .d_i   (d_dt),
        .p_o   (arith_result)
    );

    assign arith_result_o = {{18{arith_result[45]}}, arith_result};
    assign ready_o = ~working;

endmodule
