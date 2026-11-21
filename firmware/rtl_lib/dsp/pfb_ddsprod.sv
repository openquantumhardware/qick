`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : pfb_ddsprod
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    pfb_ddsprod.sv
//!
//! @brief   Down-converts one selected PFB channel: multiplies it by its own
//!          phase-coherent DDS.
//!
//! @details
//! Faithful port of the legacy ddsprod + dds_top + dds_ctrl + cmult_16x16 +
//! cmult_sub (openquantumhardware/qick firmware/ip/axis_pfb_readout_v4/src/, identical in
//! v3), merged into one module:
//!
//! - DDS control (dds_ctrl): a counter of input samples n (s_axis_tvalid),
//!   and on every clock the phase word {resync = 1, poff + pinc*n, pinc}
//!   for the DDS, with pinc/poff registered from pinc_reg/poff_reg (pinc
//!   twice) and pinc*n the low 32 bits of mult_32x32. The DDS input valid is
//!   s_axis_tvalid delayed 9 clocks.
//! - DDS: dds_compiler_pfb_ro (sin/cos, Negative_Sine, latency 10).
//! - The input sample is delayed 19 clocks to meet the DDS output, then
//!   multiplied by it ({Q, I} x {sin, cos}): full-precision products,
//!   4 clocks (cmult_sub), keep bits [30:15], one more register.
//! - m_axis_tvalid is the DDS output valid delayed 5 clocks.
//! - No reset; every register starts at 0 (in the legacy only the counters
//!   and delay lines had initial values, the product registers started X in
//!   simulation; 0 in hardware either way).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module pfb_ddsprod (
    input  logic        aclk,
    input  logic        s_axis_tvalid,
    input  logic [31:0] s_axis_tdata,
    output logic        m_axis_tvalid,
    output logic [31:0] m_axis_tdata,
    input  logic [31:0] pinc_reg,
    input  logic [31:0] poff_reg
);

    // ------------------------------------------------------------------
    // DDS control
    // ------------------------------------------------------------------
    logic [31:0] cnt = '0, cnt_r1 = '0, pinc_r1 = '0, pinc_r2 = '0, poff_r1 = '0;
    logic [31:0] poff_out_r1 = '0;
    logic [63:0] mult_out;
    logic [8:0]  en_sr = '0;           // s_axis_tvalid, 9 clocks
    logic [71:0] ctrl_dout;

    always_ff @(posedge aclk) begin
        if (s_axis_tvalid) cnt <= cnt + 1'b1;
        cnt_r1      <= cnt;
        pinc_r1     <= pinc_reg;
        pinc_r2     <= pinc_r1;
        poff_r1     <= poff_reg;
        poff_out_r1 <= poff_r1 + mult_out[31:0];
        en_sr       <= {en_sr[7:0], s_axis_tvalid};
    end

    mult_32x32 u_mult (
        .clk   (aclk),
        .din_a (pinc_r1),
        .din_b (cnt_r1),
        .dout  (mult_out)
    );

    assign ctrl_dout = {7'b0, 1'b1, poff_out_r1, pinc_r2};

    // ------------------------------------------------------------------
    // DDS
    // ------------------------------------------------------------------
    logic        dds_valid;
    logic [31:0] dds_dout;

    dds_compiler_pfb_ro u_dds (
        .aclk                (aclk),
        .s_axis_phase_tvalid (en_sr[8]),
        .s_axis_phase_tdata  (ctrl_dout),
        .m_axis_data_tvalid  (dds_valid),
        .m_axis_data_tdata   (dds_dout)
    );

    // ------------------------------------------------------------------
    // Input delay, complex product, output
    // ------------------------------------------------------------------
    logic [31:0] din_sr [19] = '{default: '0};
    logic [4:0]  valid_sr = '0;
    logic [31:0] din_la;

    always_ff @(posedge aclk) begin
        din_sr[0] <= s_axis_tdata;
        for (int k = 1; k < 19; k++) din_sr[k] <= din_sr[k-1];
        valid_sr <= {valid_sr[3:0], dds_valid};
    end
    assign din_la = din_sr[18];

    // cmult_sub x2: re = a*b - c*d, im = a*b + c*d with
    //   re: a = din_I, b = dds_I, c = din_Q, d = dds_Q
    //   im: a = din_I, b = dds_Q, c = din_Q, d = dds_I
    // ab takes 3 register stages, cd 3 (c, d delayed once more), result 1.
    logic signed [15:0] re_a1 = '0, re_b1 = '0, re_c1 = '0, re_c2 = '0, re_d1 = '0, re_d2 = '0;
    logic signed [15:0] im_a1 = '0, im_b1 = '0, im_c1 = '0, im_c2 = '0, im_d1 = '0, im_d2 = '0;
    logic signed [31:0] re_ab1 = '0, re_ab2 = '0, re_cd1 = '0, re_res = '0;
    logic signed [31:0] im_ab1 = '0, im_ab2 = '0, im_cd1 = '0, im_res = '0;
    logic [31:0]        prod_r1 = '0;

    always_ff @(posedge aclk) begin
        re_a1 <= din_la[15:0];   re_b1 <= dds_dout[15:0];
        re_c1 <= din_la[31:16];  re_c2 <= re_c1;
        re_d1 <= dds_dout[31:16]; re_d2 <= re_d1;
        re_ab1 <= re_a1 * re_b1; re_ab2 <= re_ab1;
        re_cd1 <= re_c2 * re_d2;
        re_res <= re_ab2 - re_cd1;

        im_a1 <= din_la[15:0];   im_b1 <= dds_dout[31:16];
        im_c1 <= din_la[31:16];  im_c2 <= im_c1;
        im_d1 <= dds_dout[15:0]; im_d2 <= im_d1;
        im_ab1 <= im_a1 * im_b1; im_ab2 <= im_ab1;
        im_cd1 <= im_c2 * im_d2;
        im_res <= im_ab2 + im_cd1;

        prod_r1 <= {im_res[30 -: 16], re_res[30 -: 16]};
    end

    assign m_axis_tvalid = valid_sr[4];
    assign m_axis_tdata  = prod_r1;

endmodule
