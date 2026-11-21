`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_constant
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_constant.sv
//!
//! @brief   AXI4-Stream master tie-off: never sends anything.
//!
//! @details
//! Faithful port of the legacy QICK IP (openquantumhardware/qick firmware/ip/axis_constant/
//! src/axis_constant.vhd, QICK:QICK:axis_constant:1.0): every output is 0,
//! so m_axis_tvalid is 0 and no transfer ever happens. It closes an unused
//! AXI4-Stream slave input in a block design (the 111 tpv1 rfbv1/rfbv2 BDs).
//! Same ports and parameter (DATA_WIDTH, multiple of 8).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_constant #(
    parameter int DATA_WIDTH = 16  //! TDATA width (bits), multiple of 8
) (
    input  logic                    m_axis_aclk,     // verilog_lint: waive unused (tie-off, kept for the BD)
    input  logic                    m_axis_aresetn,  // verilog_lint: waive unused (tie-off, kept for the BD)
    input  logic                    m_axis_tready,   // verilog_lint: waive unused (tie-off, kept for the BD)
    output logic [DATA_WIDTH-1:0]   m_axis_tdata,
    output logic [DATA_WIDTH/8-1:0] m_axis_tstrb,
    output logic                    m_axis_tlast,
    output logic                    m_axis_tvalid
);

    assign m_axis_tdata  = '0;
    assign m_axis_tstrb  = '0;
    assign m_axis_tlast  = 1'b0;
    assign m_axis_tvalid = 1'b0;

endmodule
