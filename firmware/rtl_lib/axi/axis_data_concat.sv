///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_data_concat
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_data_concat.sv
//!
//! @brief   Prepends i_offset to every AXI-Stream beat: m.tdata = {i_offset, s.tdata}.
//!
//! @details
//!
//! Combinational: tvalid, tready and tlast pass straight through. The other
//! sidebands (tstrb, tkeep, tuser, tid, tdest) are not carried. m_axis must be
//! NB_OFF bits wider than s_axis, and s_axis must be NB_IN bits wide.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module axis_data_concat #(
  parameter int NB_IN  = 16,
  parameter int NB_OFF = 16
)(
  input  logic i_clk,
  input  logic i_rstn,

  axi4_stream_if.slave  s_axis,
  axi4_stream_if.master m_axis,

  input logic [NB_OFF-1:0] i_offset
);

  generate
    if (s_axis.TDATA_WIDTH != NB_IN || m_axis.TDATA_WIDTH != NB_IN + NB_OFF) begin : g_check_width
      $fatal(1, "axis_data_concat: s_axis must be NB_IN bits and m_axis NB_IN+NB_OFF bits wide");
    end
  endgenerate

  // Handshake passes straight through
  assign m_axis.tvalid = s_axis.tvalid;
  assign s_axis.tready = m_axis.tready;

  // Payload transform
  assign m_axis.tdata  = {i_offset, s_axis.tdata};
  assign m_axis.tlast  = s_axis.tlast;

endmodule
