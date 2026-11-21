`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_terminator
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_terminator.sv
//!
//! @brief   AXI4-Stream slave sink: accepts and discards everything.
//!
//! @details
//! Faithful port of the legacy QICK IP (openquantumhardware/qick firmware/ip/
//! axis_terminator/src/axis_terminator.vhd, QICK:QICK:axis_terminator:1.0):
//! s_axis_tready is constant 1 and the data is dropped. It closes an unused
//! AXI4-Stream master output in a block design (111 tpv1_rfbv1_std). Same
//! ports and parameter (DATA_WIDTH, multiple of 8).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_terminator #(
    parameter int DATA_WIDTH = 16  //! TDATA width (bits), multiple of 8
) (
    input  logic                    s_axis_aclk,     // verilog_lint: waive unused (sink, kept for the BD)
    input  logic                    s_axis_aresetn,  // verilog_lint: waive unused (sink, kept for the BD)
    output logic                    s_axis_tready,
    input  logic [DATA_WIDTH-1:0]   s_axis_tdata,    // verilog_lint: waive unused (discarded)
    input  logic [DATA_WIDTH/8-1:0] s_axis_tstrb,    // verilog_lint: waive unused (discarded)
    input  logic                    s_axis_tlast,    // verilog_lint: waive unused (discarded)
    input  logic                    s_axis_tvalid    // verilog_lint: waive unused (discarded)
);

    assign s_axis_tready = 1'b1;

endmodule
