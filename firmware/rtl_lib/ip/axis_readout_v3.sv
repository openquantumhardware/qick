`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_readout_v3
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_readout_v3.sv
//!
//! @brief   axis_readout_v3
//!
//! @details
//!
//! Top level of the QICK tProc-controlled readout IP (v3): 4 parallel
//! real-ADC-sample x complex-DDS demodulators feeding an 4x decimating
//! lowpass FIR, single decimated output (no separate "before decimation"
//! tap, unlike axis_dyn_readout_v1/axis_readout_v2).
//!
//! Like axis_dyn_readout_v1, this IP has NO AXI-Lite register block --
//! configuration (frequency/phase/nsamp/outsel/mode/phrst, 88-bit
//! descriptor) arrives entirely over the s0_axis descriptor stream, pushed
//! by the tProc at run time (matches the production driver's
//! `AbsDynReadout`, which is a connectivity-only DummyIP with no register
//! I/O; `AxisReadoutV3(AbsDynReadout)`, DOWNSAMPLING=4).
//!
//! One clock domain (aclk).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_readout_v3 #(
    parameter int N = 4  //! Number of parallel demodulator lanes (fixed by the FIR: 4).
)(
    // Reset and clock.
    input  logic aresetn,
    input  logic aclk,

    // s0_axis: for pushing demodulation descriptors.
    output logic         s0_axis_tready,
    input  logic         s0_axis_tvalid,
    input  logic [87:0]  s0_axis_tdata,

    // s1_axis: for input data (N real samples per clock).
    input  logic             s1_axis_tvalid,
    output logic             s1_axis_tready,
    input  logic [N*16-1:0]  s1_axis_tdata,

    // m_axis: for output data (1 complex sample per clock, decimated).
    input  logic         m_axis_tready,
    output logic         m_axis_tvalid,
    output logic [31:0]  m_axis_tdata
);

    logic         fifo_wr_en;
    logic [87:0]  fifo_din;
    logic         fifo_full;

    assign fifo_wr_en = s0_axis_tvalid;
    assign fifo_din   = s0_axis_tdata;

    readout_top_ro_v3 #(
        .N (N)
    ) readout_top_i (
        .aresetn (aresetn),
        .aclk    (aclk),

        .fifo_wr_en (fifo_wr_en),
        .fifo_full  (fifo_full),
        .fifo_din   (fifo_din),

        .s_axis_tdata  (s1_axis_tdata),
        .s_axis_tvalid (s1_axis_tvalid),
        .s_axis_tready (s1_axis_tready),

        .m_axis_tready (m_axis_tready),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tdata  (m_axis_tdata)
    );

    assign s0_axis_tready = ~fifo_full;

endmodule
