`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : dds_top_sgmux8
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    dds_top_sgmux8.sv
//!
//! @brief   N_DDS-lane interleaved DDS + gain stage for one axis_sg_mux8_v1
//!          output channel.
//!
//! @details
//! Drives phase_ctrl_sgmux8 to produce N_DDS phase-coherent control words,
//! feeds each into its own dds_compiler_signal_gen_mux lane (latency 10),
//! aligns the outputs with delay_line (latency 4, matches the legacy
//! latency_reg), then applies a signed Q1.15 x Q1.15 gain multiply per lane:
//!
//!   prod_real = dds_dout_la * gain               (Q2.30, 32-bit signed)
//!   dout      = prod_real_r1[30:15]               (Q1.15, drop dup. sign bit)
//!
//! Output latency (PINC/POFF/GAIN write -> dds_dout_o): phase_ctrl (2) +
//! dds compiler (10) + alignment delay (4) + gain pipeline (2) = 18 cycles,
//! matching the legacy dds_top.v structure exactly.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module dds_top_sgmux8 #(
    parameter int N_DDS = 2  //! Number of interleaved parallel DDS lanes.
)(
    input  logic                rstn,        //! Synchronous active-low reset.
    input  logic                clk,         //! Clock.

    output logic [N_DDS*16-1:0] dds_dout_o,  //! Gain-scaled DDS output, per lane.

    input  logic [31:0]         pinc_reg,    //! Phase increment register.
    input  logic [31:0]         poff_reg,    //! Phase offset register.
    input  logic [15:0]         gain_reg,    //! Signed Q1.15 gain register.
    input  logic                we_reg       //! Write-enable (AXI-Lite domain).
);

    // DDS input control.
    logic [N_DDS*72-1:0] dds_ctrl_int;
    logic [N_DDS*72-1:0] dds_ctrl_int_r;

    // DDS output.
    logic [15:0] dds_dout    [N_DDS];
    logic [15:0] dds_dout_la [N_DDS];

    // Product.
    logic signed [15:0] gain;
    logic signed [15:0] prod_a_real  [N_DDS];
    logic signed [31:0] prod_real    [N_DDS];
    logic        [31:0] prod_real_r1 [N_DDS];
    logic        [15:0] prod_real_q  [N_DDS];
    logic        [15:0] prod         [N_DDS];
    logic        [15:0] prod_r1      [N_DDS];

    // Phase control block.
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
        // DDS. Latency: 10.
        dds_compiler_signal_gen_mux dds_i (
            .aclk                (clk),
            .s_axis_phase_tvalid (1'b1),
            .s_axis_phase_tdata  (dds_ctrl_int_r[i*72+:72]),
            .m_axis_data_tvalid  (),
            .m_axis_data_tdata   (dds_dout[i])
        );

        // Latency for dds_dout.
        delay_line #(
            .N (4),
            .M (16)
        ) dds_dout_delay_i (
            .i_clk  (clk),
            .i_rstn (rstn),
            .i_data (dds_dout[i]),
            .o_data (dds_dout_la[i])
        );

        // Product.
        assign prod_a_real[i] = dds_dout_la[i];
        assign prod_real[i]   = prod_a_real[i] * gain;
        assign prod_real_q[i] = prod_real_r1[i][30-:16];
        assign prod[i]        = prod_real_q[i];

        always_ff @(posedge clk) begin
            if (!rstn) begin
                prod_real_r1[i] <= '0;
                prod_r1[i]      <= '0;
            end else begin
                // Product.
                prod_real_r1[i] <= prod_real[i];
                prod_r1[i]      <= prod[i];
            end
        end

        // Outputs.
        assign dds_dout_o[i*16+:16] = prod_r1[i];
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
