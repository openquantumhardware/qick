`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : dds_top_mixmux8
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    dds_top_mixmux8.sv
//!
//! @brief   N_DDS-lane interleaved I/Q DDS + gain stage for one
//!          axis_sg_mixmux8_v1 output channel.
//!
//! @details
//! Identical structure to dds_top_sgmux8, but the DDS lane now produces a
//! DUAL_OUTPUT {sin,cos} pair (dds_compiler_signal_gen_mixmux, 32-bit:
//! bits[31:16]=sin/Q, bits[15:0]=cos/I) instead of a single real sample, and
//! the gain multiply is applied independently to both I and Q:
//!
//!   prod_real = dds_dout_la[15:0]  * gain   (Q2.30 -> Q1.15, bits[30:15])
//!   prod_imag = dds_dout_la[31:16] * gain   (Q2.30 -> Q1.15, bits[30:15])
//!   dout      = {prod_imag_r1, prod_real_r1}
//!
//! phase_ctrl_sgmux8 is reused as-is (identical PINC/POFF/WE_REG behavior
//! -- the legacy phase_ctrl.sv is byte-for-byte identical between mux8 and
//! mixmux8, only the DDS/gain stage differs).
//!
//! Output latency: same as dds_top_sgmux8 (18 cycles).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module dds_top_mixmux8 #(
    parameter int N_DDS = 2  //! Number of interleaved parallel DDS lanes.
)(
    input  logic                rstn,        //! Synchronous active-low reset.
    input  logic                clk,         //! Clock.

    output logic [N_DDS*32-1:0] dds_dout_o,  //! Gain-scaled {Q,I} output, per lane.

    input  logic [31:0]         pinc_reg,    //! Phase increment register.
    input  logic [31:0]         poff_reg,    //! Phase offset register.
    input  logic [15:0]         gain_reg,    //! Signed Q1.15 gain register.
    input  logic                we_reg       //! Write-enable (AXI-Lite domain).
);

    // DDS input control.
    logic [N_DDS*72-1:0] dds_ctrl_int;
    logic [N_DDS*72-1:0] dds_ctrl_int_r;

    // DDS output (dual: {sin/Q, cos/I}).
    logic [31:0] dds_dout    [N_DDS];
    logic [31:0] dds_dout_la [N_DDS];

    // Product.
    logic signed [15:0] gain;
    logic signed [15:0] prod_a_real  [N_DDS];
    logic signed [15:0] prod_a_imag  [N_DDS];
    logic signed [31:0] prod_real    [N_DDS];
    logic signed [31:0] prod_imag    [N_DDS];
    logic        [31:0] prod_real_r1 [N_DDS];
    logic        [31:0] prod_imag_r1 [N_DDS];
    logic        [15:0] prod_real_q  [N_DDS];
    logic        [15:0] prod_imag_q  [N_DDS];
    logic        [31:0] prod         [N_DDS];
    logic        [31:0] prod_r1      [N_DDS];

    // Phase control block (identical to dds_top_sgmux8's; the legacy
    // phase_ctrl.sv is byte-for-byte identical between mux8/mixmux8).
    phase_ctrl_sgmux8 #(
        .N_DDS (N_DDS)
    ) phase_ctrl_i (
        .rstn       (rstn),
        .clk        (clk),
        .dds_ctrl_o (dds_ctrl_int),
        .pinc_reg   (pinc_reg),
        .poff_reg   (poff_reg),
        .we_reg     (we_reg)
    );

    for (genvar i = 0; i < N_DDS; i = i + 1) begin : g_dds
        // DDS (dual I/Q output). Latency: 10.
        dds_compiler_signal_gen_mixmux dds_i (
            .aclk                (clk),
            .s_axis_phase_tvalid (1'b1),
            .s_axis_phase_tdata  (dds_ctrl_int_r[i*72+:72]),
            .m_axis_data_tvalid  (),
            .m_axis_data_tdata   (dds_dout[i])
        );

        // Latency for dds_dout.
        delay_line #(
            .N (4),
            .M (32)
        ) dds_dout_delay_i (
            .i_clk  (clk),
            .i_rstn (rstn),
            .i_data (dds_dout[i]),
            .o_data (dds_dout_la[i])
        );

        // Product.
        assign prod_a_real[i] = dds_dout_la[i][15:0];
        assign prod_a_imag[i] = dds_dout_la[i][31:16];
        assign prod_real[i]   = prod_a_real[i] * gain;
        assign prod_imag[i]   = prod_a_imag[i] * gain;
        assign prod_real_q[i] = prod_real_r1[i][30-:16];
        assign prod_imag_q[i] = prod_imag_r1[i][30-:16];
        assign prod[i]        = {prod_imag_q[i], prod_real_q[i]};

        always_ff @(posedge clk) begin
            if (!rstn) begin
                prod_real_r1[i] <= '0;
                prod_imag_r1[i] <= '0;
                prod_r1[i]      <= '0;
            end else begin
                // Product.
                prod_real_r1[i] <= prod_real[i];
                prod_imag_r1[i] <= prod_imag[i];
                prod_r1[i]      <= prod[i];
            end
        end

        // Outputs.
        assign dds_dout_o[i*32+:32] = prod_r1[i];
    end

    // Gain.
    assign gain = gain_reg;

    always_ff @(posedge clk) begin
        if (!rstn)
            dds_ctrl_int_r <= '0;
        else
            // DDS input control.
            dds_ctrl_int_r <= dds_ctrl_int;
    end

endmodule
