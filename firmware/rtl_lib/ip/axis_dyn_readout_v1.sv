`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_dyn_readout_v1
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_dyn_readout_v1.sv
//!
//! @brief   axis_dyn_readout_v1
//!
//! @details
//!
//! Top level of the QICK dynamic (tProc-controlled) readout IP: 8 parallel
//! real-ADC-sample x complex-DDS demodulators, with an 8x decimating
//! lowpass FIR.
//!
//! Unlike the signal generators, this IP has NO AXI-Lite register block --
//! configuration (frequency/phase/nsamp/outsel/mode/phrst) arrives entirely
//! over the s0_axis descriptor stream, pushed by the tProc at run time
//! (matches the production driver's `AbsDynReadout`, which is a
//! connectivity-only DummyIP with no PYNQ register interface).
//!
//! One clock domain (aclk).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_dyn_readout_v1 #(
    parameter int N_DDS = 8  //! Number of parallel demodulator lanes (fixed by the FIR: 8).
)(
    // Reset and clock (s1_axis, m0_axis, m1_axis).
    input  logic aresetn,
    input  logic aclk,

    // s0_axis: for pushing demodulation descriptors.
    output logic         s0_axis_tready,
    input  logic         s0_axis_tvalid,
    input  logic [87:0]  s0_axis_tdata,

    // s1_axis: for input data (N_DDS samples per clock).
    input  logic                 s1_axis_tvalid,
    output logic                 s1_axis_tready,
    input  logic [N_DDS*16-1:0]  s1_axis_tdata,

    // m0_axis: for output data (before filter and decimation, N_DDS
    // samples per clock).
    input  logic                 m0_axis_tready,
    output logic                 m0_axis_tvalid,
    output logic [N_DDS*32-1:0]  m0_axis_tdata,

    // m1_axis: for output data (decimated).
    input  logic         m1_axis_tready,
    output logic         m1_axis_tvalid,
    output logic [31:0]  m1_axis_tdata
);

    logic         fifo_wr_en;
    logic [87:0]  fifo_din;
    logic         fifo_full;

    assign fifo_wr_en = s0_axis_tvalid;
    assign fifo_din   = s0_axis_tdata;

    readout_top_dynro #(
        .N_DDS (N_DDS)
    ) readout_top_i (
        .aresetn (aresetn),
        .aclk    (aclk),

        .fifo_wr_en (fifo_wr_en),
        .fifo_full  (fifo_full),
        .fifo_din   (fifo_din),

        .s_axis_tdata  (s1_axis_tdata),
        .s_axis_tvalid (s1_axis_tvalid),
        .s_axis_tready (s1_axis_tready),

        .m0_axis_tready (m0_axis_tready),
        .m0_axis_tvalid (m0_axis_tvalid),
        .m0_axis_tdata  (m0_axis_tdata),

        .m1_axis_tready (m1_axis_tready),
        .m1_axis_tvalid (m1_axis_tvalid),
        .m1_axis_tdata  (m1_axis_tdata)
    );

    assign s0_axis_tready = ~fifo_full;

endmodule
