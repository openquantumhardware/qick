`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : down_conversion_ro_v2
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    down_conversion_ro_v2.sv
//!
//! @brief   Digital down-conversion (real ADC sample x complex DDS) for
//!          axis_readout_v2.
//!
//! @details
//! Faithful port of axis_readout_v2's down_conversion.v -- identical
//! demodulation math to down_conversion_dynro (N_DDS lanes, each
//! multiplying one real 16-bit input sample by its own complex DDS output,
//! rounded to Q1.15, output-source mux 0=product/1=DDS only/2=raw
//! input/3=zero), only the control block differs: ctrl_ro_v2 (83-bit
//! descriptor, no phrst) instead of ctrl_dyn_ro (88-bit, phrst-capable).
//!
//! No FIFO/decimation here -- feeds into fir_decim8_dynro (reused
//! unchanged: axis_readout_v2's fir.coe is byte-for-byte identical to
//! axis_dyn_readout_v1's) for the decimated output.
//!
//! s_axis_tready_o / m_axis_tvalid_o are both tied high (continuous
//! streaming, no backpressure), matching the legacy exactly.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module down_conversion_ro_v2 #(
    parameter int N_DDS = 8  //! Number of parallel demodulator lanes.
)(
    // Reset and clock.
    input  logic                 rstn,
    input  logic                 clk,

    // S_AXIS for input.
    output logic                 s_axis_tready_o,
    input  logic                 s_axis_tvalid_i,
    input  logic [N_DDS*16-1:0]  s_axis_tdata_i,

    // M_AXIS for output.
    input  logic                 m_axis_tready_i,
    output logic                 m_axis_tvalid_o,
    output logic [N_DDS*32-1:0]  m_axis_tdata_o,

    // Fifo interface.
    output logic          fifo_rd_en_o,
    input  logic          fifo_empty_i,
    input  logic [82:0]   fifo_dout_i
);

    //! 0.5 for rounding.
    localparam logic [31:0] RND_0P5 = 32'(2 ** 15);

    // DDS input control.
    logic                  dds_tvalid_r;
    logic [N_DDS*72-1:0]   dds_ctrl_int;
    logic [N_DDS*72-1:0]   dds_ctrl_int_r;

    // Output selection.
    logic [1:0] outsel_int;

    // DDS output.
    logic [31:0] dds_dout    [N_DDS];
    logic [31:0] dds_dout_r1 [N_DDS];
    logic [31:0] dds_dout_r2 [N_DDS];
    logic [31:0] dds_dout_r3 [N_DDS];
    logic [31:0] dds_dout_r4 [N_DDS];

    // Input data.
    logic        [15:0] din_r1 [N_DDS];
    logic signed [15:0] din_r2 [N_DDS];
    logic        [15:0] din_r3 [N_DDS];
    logic        [15:0] din_r4 [N_DDS];

    // Product.
    logic signed [15:0] pa_real          [N_DDS];
    logic signed [15:0] pa_imag          [N_DDS];
    logic signed [31:0] py_full_real     [N_DDS];
    logic signed [31:0] py_full_imag     [N_DDS];
    logic signed [31:0] py_full_real_r   [N_DDS];
    logic signed [31:0] py_full_imag_r   [N_DDS];
    logic signed [31:0] py_round_real    [N_DDS];
    logic signed [31:0] py_round_imag    [N_DDS];
    logic        [15:0] py_real          [N_DDS];
    logic        [15:0] py_imag          [N_DDS];
    logic        [31:0] py               [N_DDS];
    logic        [31:0] py_r             [N_DDS];

    // Muxed output.
    logic [31:0] dout_mux   [N_DDS];
    logic [31:0] dout_mux_r [N_DDS];

    // Control block.
    ctrl_ro_v2 #(
        .N_DDS (N_DDS)
    ) ctrl_i (
        .aresetn      (rstn),
        .aclk         (clk),
        .fifo_rd_en_o (fifo_rd_en_o),
        .fifo_empty_i (fifo_empty_i),
        .fifo_dout_i  (fifo_dout_i),
        .dds_ctrl_o   (dds_ctrl_int),
        .outsel_o     (outsel_int)
    );

    for (genvar i = 0; i < N_DDS; i = i + 1) begin : g_dds
        // DDS.
        dds_compiler_dyn_readout dds_i (
            .aclk                (clk),
            .s_axis_phase_tvalid (dds_tvalid_r),
            .s_axis_phase_tdata  (dds_ctrl_int_r[i*72+:72]),
            .m_axis_data_tvalid  (),
            .m_axis_data_tdata   (dds_dout[i])
        );

        always_ff @(posedge clk) begin
            if (!rstn) begin
                dds_dout_r1[i]    <= '0;
                dds_dout_r2[i]    <= '0;
                dds_dout_r3[i]    <= '0;
                dds_dout_r4[i]    <= '0;
                din_r1[i]         <= '0;
                din_r2[i]         <= '0;
                din_r3[i]         <= '0;
                din_r4[i]         <= '0;
                py_full_real_r[i] <= '0;
                py_full_imag_r[i] <= '0;
                py_r[i]           <= '0;
                dout_mux_r[i]     <= '0;
            end else begin
                // DDS output.
                dds_dout_r1[i] <= dds_dout[i];
                dds_dout_r2[i] <= dds_dout_r1[i];
                dds_dout_r3[i] <= dds_dout_r2[i];
                dds_dout_r4[i] <= dds_dout_r3[i];

                // Input data.
                din_r1[i] <= s_axis_tdata_i[i*16+:16];
                din_r2[i] <= din_r1[i];
                din_r3[i] <= din_r2[i];
                din_r4[i] <= din_r3[i];

                // Product.
                py_full_real_r[i] <= py_full_real[i];
                py_full_imag_r[i] <= py_full_imag[i];
                py_r[i]            <= py[i];

                // Muxed output.
                dout_mux_r[i] <= dout_mux[i];
            end
        end

        // Product.
        assign pa_real[i]      = dds_dout_r2[i][15:0];
        assign pa_imag[i]      = dds_dout_r2[i][31:16];
        assign py_full_real[i] = pa_real[i] * din_r2[i];
        assign py_full_imag[i] = pa_imag[i] * din_r2[i];
        assign py_round_real[i] = py_full_real_r[i] + $signed(RND_0P5);
        assign py_round_imag[i] = py_full_imag_r[i] + $signed(RND_0P5);
        assign py_real[i] = py_round_real[i][31:16];
        assign py_imag[i] = py_round_imag[i][31:16];
        assign py[i]      = {py_imag[i], py_real[i]};

        // Muxed output.
        assign dout_mux[i] = (outsel_int == 2'd0) ? py_r[i] :
                              (outsel_int == 2'd1) ? dds_dout_r4[i] :
                              (outsel_int == 2'd2) ? {16'h0000, din_r4[i]} :
                              32'h0000_0000;

        // Outputs.
        assign m_axis_tdata_o[i*32+:32] = dout_mux_r[i];
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            dds_tvalid_r   <= 1'b0;
            dds_ctrl_int_r <= '0;
        end else begin
            dds_tvalid_r   <= 1'b1;
            dds_ctrl_int_r <= dds_ctrl_int;
        end
    end

    // Outputs.
    assign s_axis_tready_o = 1'b1;
    assign m_axis_tvalid_o = 1'b1;

endmodule
