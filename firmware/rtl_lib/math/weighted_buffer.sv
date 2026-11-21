///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : weighted_buffer
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    weighted_buffer.sv
//!
//! @brief   AVG_BUFFER block with a matched-filter (weighted) front end:
//!
//! @details
//!
//! receives an input stream of samples (s_axis), multiplies it sample by
//! sample against a DMA-loaded weight envelope (matched_filter), and feeds
//! the filtered result into the same avg_top + buffer_top pair used by
//! plain avg_buffer -- generating three output streams: processed averaged
//! data (m0_axis), raw captured (filtered) data (m1_axis), and averaged
//! data as soon as it's calculated, prior to internal memory (m2_axis).
//!
//! Faithful port of legacy axis_weighted_buffer v1.3's avg_buffer.v. Like
//! avg_buffer.sv, trigger is asynchronous (external, hardware) and is
//! resynchronized to s_axis_aclk via cdc_bit_sync (replacing the legacy
//! synchronizer_n) before reaching matched_filter; matched_filter then
//! further delays it (trigger_o) to compensate its own DSP pipeline
//! latency before fanning out to avg_top/buffer_top -- avg_top/buffer_top
//! must NOT receive the raw trigger_resync directly, or their capture
//! window would start before the filtered data is actually available.
//!
//! Data is I,Q. I: lower B bits, Q: upper B bits throughout (avg_buffer's
//! convention; matched_filter uses the same packing end to end since its
//! v1.4 I/Q-order fix -- see matched_filter.sv).
//!
//! wgt_trunc_reg passes through to matched_filter's trunc_shift_reg
//!: defaults to B if unconnected.
//!
//! @author  QICK Development Team
//!
//! @version 1.0

module weighted_buffer #(
  //! averager memory depth as 2**N_AVG
  parameter int N_AVG = 10,
  //! buffer memory depth as 2**N_BUF
  parameter int N_BUF = 10,
  //! weight envelope memory depth as 2**N_WGT
  parameter int N_WGT = 10,
  //! sample data width in bits
  parameter int B = 16
) (
  // Reset and clock for s_axis (readout datapath)
  input logic s_axis_aclk,
  input logic s_axis_aresetn,

  // Reset and clock for s1_axis (weight-programming DMA)
  input logic s_axi_aclk,
  input logic s_axi_aresetn,

  // Trigger input (async, external)
  input logic trigger,

  // AXIS Slave for weight programming
  input  logic            s1_axis_tvalid,
  output logic            s1_axis_tready,
  input  logic [2*B-1:0]  s1_axis_tdata,

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

  // AXIS Master for raw (filtered) output
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
  input logic [N_BUF:0]      buf_dr_len_reg,

  // WGT registers
  input logic [N_WGT-1:0]    wgt_dw_addr_reg,
  input logic                wgt_dw_start_reg,
  //! matched_filter's output-quantizer shift; defaults to B (legacy
  //! behavior) if left unconnected.
  input logic [7:0]          wgt_trunc_reg = 8'(B)
);

  //////////////////////////////////////////////////////////////////////////////
  // Internal signals
  //////////////////////////////////////////////////////////////////////////////
  logic           trigger_resync;
  logic           trigger_filtered;
  logic [2*B-1:0] s_axis_filtered_tdata;
  logic           s_axis_filtered_tvalid;

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

  // Matched filter: weight-envelope complex multiply, DSP-latency-compensated
  // trigger and valid.
  matched_filter #(
    .N (N_WGT),
    .B (B)
  ) matched_filter_i (
    .clk         (s_axis_aclk),
    .rstn        (s_axis_aresetn),

    .write_rstn  (s_axi_aresetn),
    .write_clk   (s_axi_aclk),

    .trigger_i   (trigger_resync),
    .trigger_o   (trigger_filtered),

    .s_axis_tready (s1_axis_tready),
    .s_axis_tdata  (s1_axis_tdata),
    .s_axis_tvalid (s1_axis_tvalid),

    .din_valid_i (s_axis_tvalid),
    .din_i       (s_axis_tdata),

    .dout_o       (s_axis_filtered_tdata),
    .dout_valid_o (s_axis_filtered_tvalid),

    .len_reg          (avg_len_reg),
    .dw_addr_reg      (32'(wgt_dw_addr_reg)),
    .we_reg           (wgt_dw_start_reg),
    .trunc_shift_reg  (wgt_trunc_reg)
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
    .trigger_i   (trigger_filtered),

    // Data input
    .din_valid_i (s_axis_filtered_tvalid),
    .din_i       (s_axis_filtered_tdata),

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
    .trigger_i   (trigger_filtered),

    // Data input
    .din_valid_i (s_axis_filtered_tvalid),
    .din_i       (s_axis_filtered_tdata),

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
