`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : readout_top_ro_v3
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    readout_top_ro_v3.sv
//!
//! @brief   Top-level datapath for axis_readout_v3.
//!
//! @details
//! Faithful port of axis_readout_v3's down_conversion_fir.sv (its own
//! "top-level with DDS product + x4 decimation filter") plus the
//! descriptor FIFO from axis_readout_v3.v. Unlike axis_dyn_readout_v1 /
//! axis_readout_v2, this IP has only ONE output stream (no separate
//! "before decimation" tap).
//!
//! Building blocks:
//!
//! - fifo_sync             : demodulation descriptor FIFO (88-bit, depth
//!                            16 -- legacy was 8, bumped for fifo_sync's
//!                            XPM_FIFO_SYNC 16-entry minimum).
//! - down_conversion_ro_v3 : N=4 real x complex-DDS demodulation.
//! - fir_decim4_ro_v3      : decimate-by-4 lowpass (I/Q), 18-bit/channel.
//!
//! Final output extraction (matches down_conversion_fir.sv exactly): the
//! FIR's 18-bit-per-channel output is truncated to 16 bits by dropping the
//! LSB and the top (sign-duplicate) bit -- bits [16:1] of each 18-bit
//! field -- then packed {imag,real}.
//!
//! One clock domain (aclk) -- no AXI-Lite, no separate envelope-write
//! domain; configuration arrives entirely over the descriptor stream
//! (s0_axis in the packaged IP).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module readout_top_ro_v3 #(
    parameter int N = 4  //! Number of parallel demodulator lanes (fixed by the FIR: 4).
)(
    // Reset and clock.
    input  logic aresetn,
    input  logic aclk,

    // Fifo interface (descriptor push from the AXI-Lite-free config stream).
    input  logic         fifo_wr_en,
    output logic         fifo_full,
    input  logic [87:0]  fifo_din,

    // S_AXIS: for input data (N real samples per clock).
    input  logic             s_axis_tvalid,
    output logic             s_axis_tready,
    input  logic [N*16-1:0]  s_axis_tdata,

    // M_AXIS: for output data (1 complex sample per clock, decimated).
    input  logic         m_axis_tready,
    output logic         m_axis_tvalid,
    output logic [31:0]  m_axis_tdata
);

    logic         fifo_rd_en;
    logic [87:0]  fifo_dout;
    logic         fifo_empty;

    // Down-conversion output.
    logic         tvalid_i;
    logic         tready_i;
    logic [127:0] tdata_i;

    // Fir output.
    logic [47:0] tdata_fir;
    logic [17:0] tdata_real;
    logic [17:0] tdata_imag;

    // Down-conversion block (product with fast DDS). Latency: 16.
    down_conversion_ro_v3 #(
        .N (N)
    ) down_conversion_i (
        .aresetn (aresetn),
        .aclk    (aclk),

        .fifo_rd_en (fifo_rd_en),
        .fifo_empty (fifo_empty),
        .fifo_dout  (fifo_dout),

        .s_axis_tready (s_axis_tready),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tdata  (s_axis_tdata),

        .m_axis_tready (tready_i),
        .m_axis_tvalid (tvalid_i),
        .m_axis_tdata  (tdata_i)
    );

    // FIR with x4 decimation.
    fir_decim4_ro_v3 #(
        .N (N)
    ) fir_i (
        .aclk               (aclk),
        .s_axis_data_tvalid (tvalid_i),
        .s_axis_data_tready (tready_i),
        .s_axis_data_tdata  (tdata_i),
        .m_axis_data_tvalid (m_axis_tvalid),
        .m_axis_data_tdata  (tdata_fir)
    );

    // Real/imaginary parts (18 bits).
    assign tdata_real = tdata_fir[17:0];
    assign tdata_imag = tdata_fir[41:24];

    // Assign output.
    assign m_axis_tdata = {tdata_imag[16:1], tdata_real[16:1]};

    // Fifo for queuing demodulation descriptors.
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
