///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_pipe
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_pipe.sv
//!
//! @brief   AXI-Stream pipeline stage
//!
//! @details
//!
//! One-entry register slice. The whole beat is registered: tdata, tlast and
//! the tstrb/tkeep/tuser/tid/tdest sidebands. Up to 0.1.0 only tdata was
//! registered and m_axis.tlast and the sidebands were never driven (X
//! downstream); the axi4_stream_if checkers (-d SVUNIT) flagged it as
//! AXI4STREAM_ERRM_TLAST_X / TSTRB_X.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module axis_pipe #(
  parameter int DWIDTH = 32
)(
  input  logic         clk,
  input  logic         rstn,

  axi4_stream_if.slave s_axis,
  axi4_stream_if.master m_axis
);

  // Internal storage
  logic [DWIDTH-1:0]               data_r;
  logic                            last_r;
  logic [$bits(s_axis.tstrb)-1:0]  strb_r;
  logic [$bits(s_axis.tkeep)-1:0]  keep_r;
  logic [$bits(s_axis.tuser)-1:0]  user_r;
  logic [$bits(s_axis.tid)-1:0]    id_r;
  logic [$bits(s_axis.tdest)-1:0]  dest_r;
  logic                            full;

  // ===============================
  // READY logic
  // ===============================
  // Can accept if buffer empty
  // or downstream will consume this cycle
  assign s_axis.tready = !full || (m_axis.tready && m_axis.tvalid);

  // ===============================
  // Sequential storage
  // ===============================
  always_ff @(posedge clk) begin
    if (!rstn) begin
      full <= 1'b0;
    end else begin
      case ({s_axis.tvalid && s_axis.tready, m_axis.tready && m_axis.tvalid})
        2'b10: begin
          // push only
          full   <= 1'b1;
        end
        2'b01: begin
          // pop only
          full <= 1'b0;
        end
        2'b11: begin
          // push + pop (replace)
          full   <= 1'b1;
        end
        default: ; // idle
      endcase
    end
  end

  // Beat register: loaded on every accepted input beat (push, push + pop)
  always_ff @(posedge clk) begin
    if (rstn && s_axis.tvalid && s_axis.tready) begin
      data_r <= s_axis.tdata;
      last_r <= s_axis.tlast;
      strb_r <= s_axis.tstrb;
      keep_r <= s_axis.tkeep;
      user_r <= s_axis.tuser;
      id_r   <= s_axis.tid;
      dest_r <= s_axis.tdest;
    end
  end

  assign m_axis.tdata  = data_r;
  assign m_axis.tlast  = last_r;
  assign m_axis.tstrb  = strb_r;
  assign m_axis.tkeep  = keep_r;
  assign m_axis.tuser  = user_r;
  assign m_axis.tid    = id_r;
  assign m_axis.tdest  = dest_r;
  assign m_axis.tvalid = full;

endmodule

