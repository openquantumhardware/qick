///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_tap
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_tap.sv
//!
//! @brief   Tap AXI-Stream for monitoring interfaces
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module axis_tap#(
  parameter int NB = 16
)(
  input  logic           aclk,
  input  logic           aresetn,

  // stream observado (pasivo)
  axi4_stream_if.slave   s_axis,

  // stream de monitoreo
  axi4_stream_if.master  m_axis,

  input  logic           i_enable
);

  logic [NB-1:0] tap_data;
  logic          tap_last;
  logic          tap_valid;

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      tap_valid <= 1'b0;
    end else begin
      if (i_enable && s_axis.tvalid && s_axis.tready) begin
        tap_data  <= s_axis.tdata;
        tap_last  <= s_axis.tlast;
        tap_valid <= 1'b1;
      end else if (m_axis.tready) begin
        tap_valid <= 1'b0;
      end
    end
  end

  assign m_axis.tdata  = tap_data;
  assign m_axis.tlast  = tap_last;
  assign m_axis.tvalid = tap_valid;

endmodule

