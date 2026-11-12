`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_set_reg
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_set_reg.sv
//!
//! @brief   axis_set_reg
//!
//! @details
//!
//! Simple AXI‑Stream receiver that stores the latest data word.
//!
//! This module implements a minimal AXI‑Stream slave that:
//!
//! * Accepts a data word of width **DATA_WIDTH** (default 16 bits)
//! when *tvalid* is asserted.
//!
//! * Always asserts *tready* (`1`) → the master can always send data.
//! * Stores the received word in a one‑cycle‑deep register (`data_r`).
//! * Presents the registered value on the output port **dout**.
//!
//! The design has a **latency of one clock cycle** from the moment the input
//! data is captured (`tvalid` high) to when it appears on **dout**.
//!
//! No flow‑control logic beyond the constant *tready* is required; therefore,
//! this block is typically used in test‑bench environments or in pipelines
//! where back‑pressure is not needed.
//!
//! @generic
//! DATA_WIDTH : integer = 16
//! Width of the AXI‑Stream data bus (must be >0).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module axis_set_reg #(
    parameter int DATA_WIDTH = 16               // Data bus width
  ) (
    // AXI‑Stream slave interface
    input  logic                     s_axis_aclk,      // clock
    input  logic                     s_axis_aresetn,   // active‑low reset
    output logic                     s_axis_tready,    // always ready
    input  logic [DATA_WIDTH-1:0]    s_axis_tdata,     // data word
    input  logic [(DATA_WIDTH/8)-1:0] s_axis_tstrb,    // byte‑enable (unused)
    input  logic                     s_axis_tlast,     // last beat (unused)
    input  logic                     s_axis_tvalid,    // data valid
    // Registered output
    output logic [DATA_WIDTH-1:0]    dout              // registered data
  );

  // -------------------------------------------------------------------------
  // Internal register that stores the last captured data word
  // -------------------------------------------------------------------------
  logic [DATA_WIDTH-1:0] dout_r;

  // -------------------------------------------------------------------------
  // Sequential logic: on every rising clock edge capture s_axis_tdata
  // when tvalid is asserted. Reset clears the register.
  // -------------------------------------------------------------------------
  always_ff @(posedge s_axis_aclk)
  begin
    if (!s_axis_aresetn)
    begin
      dout_r <= '0;                     // wide zero reset
    end
    else if (s_axis_tvalid)
    begin
      dout_r <= s_axis_tdata;           // latch new data
    end
    // else: retain previous value
  end

  // -------------------------------------------------------------------------
  // The slave is always ready to accept data; no back‑pressure logic required.
  // -------------------------------------------------------------------------
  assign s_axis_tready = 1'b1;

  // -------------------------------------------------------------------------
  // Drive the output port with the registered data.
  // -------------------------------------------------------------------------
  assign dout = dout_r;

endmodule
