`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : readout_top_dynro
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    readout_top_dynro.sv
//!
//! @brief   Top-level datapath for axis_dyn_readout_v1.
//!
//! @details
//! Faithful port of readout_top.v (which itself just wires
//! down_conversion_fir.v + a descriptor FIFO -- down_conversion.v, the
//! N_DDS-parametric predecessor module, is dead/unused code in the legacy
//! tree, superseded by down_conversion_fir.v).
//!
//! Building blocks:
//!
//! - fifo_sync             : waveform (demodulation) descriptor FIFO
//!                            (88-bit, depth 8).
//! - down_conversion_dynro : N_DDS=8 real x complex-DDS demodulation.
//! - fir_decim8_dynro      : decimate-by-8 lowpass (I/Q).
//!
//! One clock domain (aclk) -- no AXI-Lite, no separate envelope-write
//! domain; configuration arrives entirely over the descriptor stream
//! (s0_axis in the packaged IP).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module readout_top_dynro #(
    parameter int N_DDS = 8  //! Number of parallel demodulator lanes (fixed by the FIR: 8).
)(
    // Reset and clock.
    input  logic aresetn,
    input  logic aclk,

    // Fifo interface (descriptor push from the AXI-Lite-free config stream).
    input  logic         fifo_wr_en,
    output logic         fifo_full,
    input  logic [87:0]  fifo_din,

    // S_AXIS: for input data (N_DDS samples per clock).
    input  logic                 s_axis_tvalid,
    output logic                 s_axis_tready,
    input  logic [N_DDS*16-1:0]  s_axis_tdata,

    // M0_AXIS: for output data (before filter and decimation, N_DDS samples
    // per clock).
    input  logic                 m0_axis_tready,
    output logic                 m0_axis_tvalid,
    output logic [N_DDS*32-1:0]  m0_axis_tdata,

    // M1_AXIS: for output data (decimated).
    input  logic         m1_axis_tready,
    output logic         m1_axis_tvalid,
    output logic [31:0]  m1_axis_tdata
);

    logic         fifo_rd_en;
    logic [87:0]  fifo_dout;
    logic         fifo_empty;

    // Down-conversion + Filter + Decimation.
    down_conversion_dynro #(
        .N_DDS (N_DDS)
    ) down_conversion_i (
        .rstn (aresetn),
        .clk  (aclk),

        .s_axis_tready_o (s_axis_tready),
        .s_axis_tvalid_i (s_axis_tvalid),
        .s_axis_tdata_i  (s_axis_tdata),

        .m_axis_tready_i (m0_axis_tready),
        .m_axis_tvalid_o (m0_axis_tvalid),
        .m_axis_tdata_o  (m0_axis_tdata),

        .fifo_rd_en_o (fifo_rd_en),
        .fifo_empty_i (fifo_empty),
        .fifo_dout_i  (fifo_dout)
    );

    // FIR: 8x decimation, multi-rate implementation, I/Q (2 channels).
    fir_decim8_dynro #(
        .N_DDS (N_DDS)
    ) fir_i (
        .aclk               (aclk),
        .s_axis_data_tvalid (1'b1),
        .s_axis_data_tready (),
        .s_axis_data_tdata  (m0_axis_tdata),
        .m_axis_data_tvalid (m1_axis_tvalid),
        .m_axis_data_tdata  (m1_axis_tdata)
    );

    // Fifo for queuing demodulation descriptors. Legacy depth was 8;
    // fifo_sync's XPM_FIFO_SYNC backend has a hard 16-entry minimum, so
    // this is deeper than the legacy fifo (harmless -- more BRAM, same
    // behavior).
    fifo_sync #(
        .B         (88),
        .N         (16),
        // legacy FIFO semantics: the ctrl latches the descriptor one cycle
        // after rd_en (see fifo_sync header)
        .HOLD_DOUT (1'b1)
    ) fifo_i (
        .rstn (aresetn),
        .clk  (aclk),

        .wr_en (fifo_wr_en),
        .din   (fifo_din),

        .rd_en (fifo_rd_en),
        .dout  (fifo_dout),

        .full  (fifo_full),
        .empty (fifo_empty),

        .wr_data_count (),
        .rd_data_count (),
        .prog_full     (),
        .prog_empty    ()
    );

endmodule
