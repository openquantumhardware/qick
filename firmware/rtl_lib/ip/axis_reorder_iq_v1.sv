`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_reorder_iq_v1
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_reorder_iq_v1.sv
//!
//! @brief   Interleaves I and Q lanes: {Q[L-1..0], I[L-1..0]} ->
//!          {Q[L-1] I[L-1] ... Q[0] I[0]}.
//!
//! @details
//! Faithful port of the legacy QICK IP (openquantumhardware/qick firmware/ip/
//! axis_reorder_iq_v1/src/axis_reorder_iq_v1.sv,
//! QICK:QICK:axis_reorder_iq_v1:1.0), same ports and parameters. Purely
//! combinational: m_axis_tvalid = s_axis_tvalid, s_axis_tready = 1,
//! m_axis_tready ignored. Formats RFDC IQ data for a PFB.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_reorder_iq_v1 #(
    parameter int B = 16,  //! Bits per I or Q sample
    parameter int L = 4    //! Lanes (complex samples per word)
) (
    input  logic             aresetn,        // verilog_lint: waive unused (combinational, kept for the BD)
    input  logic             aclk,           // verilog_lint: waive unused (combinational, kept for the BD)

    input  logic [2*B*L-1:0] s_axis_tdata,
    input  logic             s_axis_tvalid,
    output logic             s_axis_tready,

    output logic [2*B*L-1:0] m_axis_tdata,
    output logic             m_axis_tvalid,
    input  logic             m_axis_tready   // verilog_lint: waive unused (no backpressure)
);

    for (genvar i = 0; i < L; i++) begin : g_lane
        assign m_axis_tdata[2*B*i +: 2*B] = {s_axis_tdata[B*L + i*B +: B], s_axis_tdata[i*B +: B]};
    end

    assign s_axis_tready = 1'b1;
    assign m_axis_tvalid = s_axis_tvalid;

endmodule
