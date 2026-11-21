///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : avg_buffer
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    avg_buffer.sv
//!
//! @brief   AVG_BUFFER block receives an input stream of samples (s_axis),
//!
//! @details
//!
//! and generates three output streams: one with processed averaged data
//! (m0_axis), one with raw captured data (m1_axis), and one with averaged
//! data as soon as it's calculated, prior to being stored in internal
//! memory (m2_axis, typically fed to a tProc register). Captured samples
//! are internally stored in PL memory. Capture is initiated by an external
//! trigger after the relevant buffer (avg or buf) has been enabled. Number
//! of captured samples and address where to store them are configurable
//! per buffer. Output stream generation is controlled with registers
//! where the address to start reading data and the number of samples can
//! be configured. Output streams can be interfaced to an AXIS-DMA module.
//!
//! trigger is asynchronous (external, hardware) and is resynchronized to
//! s_axis_aclk here via cdc_bit_sync (replaces the legacy hand-rolled
//! synchronizer_n) before being fanned out to both avg_top and buffer_top.
//!
//! Data is I,Q. I: lower B bits. Q: upper B bits.
//!
//! @author  QICK Development Team
//!
//! @version 1.0

module avg_buffer #(
  //! averager memory depth as 2**N_AVG
  parameter int N_AVG = 10,
  //! buffer memory depth as 2**N_BUF
  parameter int N_BUF = 10,
  //! sample data width in bits
  parameter int B = 16
) (
  // Reset and clock for s_axis
  input logic s_axis_aclk,
  input logic s_axis_aresetn,

  // Trigger input (async, external)
  input logic trigger,

  // AXIS Slave for input data
  input  logic            s_axis_tvalid,
  output logic            s_axis_tready,
  input  logic [2*B-1:0]  s_axis_tdata,

  // Reset and clock for m0_axis, m1_axis and m2_axis
  input logic m_axis_aclk,
  input logic m_axis_aresetn,

  // AXIS Master for averaged output
  output logic            m0_axis_tvalid,
  input  logic            m0_axis_tready,
  output logic [4*B-1:0]  m0_axis_tdata,
  output logic            m0_axis_tlast,

  // AXIS Master for raw output
  output logic            m1_axis_tvalid,
  input  logic            m1_axis_tready,
  output logic [2*B-1:0]  m1_axis_tdata,
  output logic            m1_axis_tlast,

  // AXIS Master for register output
  output logic            m2_axis_tvalid,
  input  logic            m2_axis_tready,
  output logic [4*B-1:0]  m2_axis_tdata,

  // AVG registers
  input logic                avg_start_reg,
  input logic [N_AVG-1:0]    avg_addr_reg,
  input logic [31:0]         avg_len_reg,
  input logic                avg_photon_mode_reg,
  input logic [B-1:0]        avg_h_thrsh_reg,
  input logic [B-1:0]        avg_l_thrsh_reg,
  input logic                avg_dr_start_reg,
  input logic [N_AVG-1:0]    avg_dr_addr_reg,
  input logic [N_AVG:0]      avg_dr_len_reg,

  // BUF registers
  input logic                buf_start_reg,
  input logic [N_BUF-1:0]    buf_addr_reg,
  input logic [N_BUF-1:0]    buf_len_reg,
  input logic                buf_dr_start_reg,
  input logic [N_BUF-1:0]    buf_dr_addr_reg,
  input logic [N_BUF:0]      buf_dr_len_reg
);

  //////////////////////////////////////////////////////////////////////////////
  // Internal signals
  //////////////////////////////////////////////////////////////////////////////
  logic trigger_resync;

  //////////////////////////////////////////////////////////////////////////////
  // Architecture
  //////////////////////////////////////////////////////////////////////////////

  // trigger_resync
  cdc_bit_sync #(
    .NSTAGES (2)
  ) trigger_resync_i (
    .i_clk   (s_axis_aclk),
    .i_rstn  (s_axis_aresetn),
    .i_async (trigger),
    .o_sync  (trigger_resync)
  );

  // Average block
  avg_top #(
    .N (N_AVG),
    .B (B)
  ) avg_top_i (
    // Reset and clock
    .rstn        (s_axis_aresetn),
    .clk         (s_axis_aclk),

    // Trigger input
    .trigger_i   (trigger_resync),

    // Data input
    .din_valid_i (s_axis_tvalid),
    .din_i       (s_axis_tdata),

    // Reset and clock for m0_axis and m1_axis
    .m_axis_aclk    (m_axis_aclk),
    .m_axis_aresetn (m_axis_aresetn),

    // AXIS Master for averaged output
    .m0_axis_tvalid (m0_axis_tvalid),
    .m0_axis_tready (m0_axis_tready),
    .m0_axis_tdata  (m0_axis_tdata),
    .m0_axis_tlast  (m0_axis_tlast),

    // AXIS Master for register output
    .m1_axis_tvalid (m2_axis_tvalid),
    .m1_axis_tready (m2_axis_tready),
    .m1_axis_tdata  (m2_axis_tdata),
    .m1_axis_tlast  ( ),

    // Registers
    .avg_start_reg       (avg_start_reg),
    .avg_addr_reg         (avg_addr_reg),
    .avg_len_reg          (avg_len_reg),
    .dr_start_reg         (avg_dr_start_reg),
    .dr_addr_reg          (avg_dr_addr_reg),
    .dr_len_reg           (avg_dr_len_reg),
    .avg_photon_mode_reg  (avg_photon_mode_reg),
    .avg_h_thrsh_reg      (avg_h_thrsh_reg),
    .avg_l_thrsh_reg      (avg_l_thrsh_reg)
  );

  // Buffer block
  buffer_top #(
    .N (N_BUF),
    .B (B)
  ) buffer_top_i (
    // Reset and clock
    .rstn        (s_axis_aresetn),
    .clk         (s_axis_aclk),

    // Trigger input
    .trigger_i   (trigger_resync),

    // Data input
    .din_valid_i (s_axis_tvalid),
    .din_i       (s_axis_tdata),

    // AXIS Master for output
    .m_axis_aclk    (m_axis_aclk),
    .m_axis_aresetn (m_axis_aresetn),
    .m_axis_tvalid  (m1_axis_tvalid),
    .m_axis_tready  (m1_axis_tready),
    .m_axis_tdata   (m1_axis_tdata),
    .m_axis_tlast   (m1_axis_tlast),

    // Registers
    .buf_start_reg (buf_start_reg),
    .buf_addr_reg  (buf_addr_reg),
    .buf_len_reg   (buf_len_reg),
    .dr_start_reg  (buf_dr_start_reg),
    .dr_addr_reg   (buf_dr_addr_reg),
    .dr_len_reg    (buf_dr_len_reg)
  );

  // Assign outputs
  assign s_axis_tready = 1'b1;

endmodule
