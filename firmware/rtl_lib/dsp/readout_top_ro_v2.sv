`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : readout_top_ro_v2
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    readout_top_ro_v2.sv
//!
//! @brief   Top-level datapath for axis_readout_v2.
//!
//! @details
//! Faithful port of axis_readout_v2's readout_top.v. Structurally almost
//! identical to readout_top_dynro, but descriptors come from AXI-Lite
//! registers (FREQ/PHASE/NSAMP/OUTSEL/MODE, latched into the descriptor
//! FIFO on a WE_REG rising edge) instead of a streamed s0_axis push --
//! this IP is PS-configured, not tProc-streamed.
//!
//! WE_REG originates in the AXI-Lite clock domain (s_axi_aclk) and is
//! resynchronized here via cdc_bit_sync (replaces the legacy hand-rolled
//! synchronizer_n) before edge-detection; FREQ/PHASE/NSAMP/OUTSEL/MODE
//! themselves are NOT separately synchronized -- software is expected to
//! hold them stable across the WE_REG pulse (quasi-static CDC, same
//! pattern as axis_sg_mux8_v1's WE_REG/PINC/POFF crossing).
//!
//! Building blocks:
//!
//! - fifo_sync             : demodulation descriptor FIFO (83-bit,
//!                            depth 16 -- legacy was 8, bumped for
//!                            fifo_sync's XPM_FIFO_SYNC 16-entry minimum).
//! - down_conversion_ro_v2 : N_DDS=8 real x complex-DDS demodulation.
//! - fir_decim8_dynro       : decimate-by-8 lowpass (I/Q), reused unchanged
//!                            (axis_readout_v2's fir.coe is byte-for-byte
//!                            identical to axis_dyn_readout_v1's).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module readout_top_ro_v2 #(
    parameter int N_DDS = 8  //! Number of parallel demodulator lanes (fixed by the FIR: 8).
)(
    // Reset and clock.
    input  logic aresetn,
    input  logic aclk,

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
    output logic [31:0]  m1_axis_tdata,

    // Registers (s_axi_aclk domain; WE_REG is the only one resynchronized).
    input  logic [31:0] freq_reg,
    input  logic [31:0] phase_reg,
    input  logic [15:0] nsamp_reg,
    input  logic [1:0]  outsel_reg,
    input  logic        mode_reg,
    input  logic        we_reg
);

    logic we;
    logic we_r;

    logic         fifo_wr_en;
    logic [82:0]  fifo_din;
    logic         fifo_rd_en;
    logic [82:0]  fifo_dout;
    logic         fifo_full;
    logic         fifo_empty;

    // WE_REG resync (s_axi_aclk domain -> aclk domain).
    cdc_bit_sync #(
        .NSTAGES (2)
    ) we_reg_resync_i (
        .i_clk   (aclk),
        .i_rstn  (aresetn),
        .i_async (we_reg),
        .o_sync  (we)
    );

    // Down-conversion + Filter + Decimation.
    down_conversion_ro_v2 #(
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

    // Fifo for queuing the demodulation descriptor.
    fifo_sync #(
        .B         (83),
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

    // Fifo connections: one-shot push on the WE_REG rising edge.
    assign fifo_wr_en = we & ~we_r;
    assign fifo_din   = {mode_reg, outsel_reg, nsamp_reg, phase_reg, freq_reg};

    always_ff @(posedge aclk) begin
        if (!aresetn)
            we_r <= 1'b0;
        else
            we_r <= we;
    end

endmodule
