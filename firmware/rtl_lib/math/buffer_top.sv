///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : buffer_top
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    buffer_top.sv
//!
//! @brief   BUFFER_TOP block receives an input stream of samples (s_axis),
//!
//! @details
//!
//! captures and stores them in an internal memory when indicated and generates
//! one output stream with raw captured data (m_axis). Capturing flow is
//! controlled by the BUFFER FSM block and is initiated by an external trigger
//! after the buffer has been enabled. Number of captured samples and address
//! where to store them are configurable. Captured samples are internally
//! stored in BRAM memory. Output stream is generated and controlled from the
//! DATA_READER (bram_to_axis) FSM block. Address to start reading and number
//! of samples are configurable. It can be interfaced with an AXIS DMA module.
//!
//! Sibling of avg_top: same structure (buffer + bram_tdp + bram_to_axis +
//! cdc_gray_sync resync), but a single output stream since raw capture has
//! no "pre-memory" computed value worth tapping live (unlike avg_top's
//! m1_axis, which taps the accumulator result before it lands in memory).
//!
//! @author  QICK Development Team
//!
//! @version 1.0

module buffer_top #(
  //! memory depth as 2**N
  parameter int N = 10,
  //! memory data width
  parameter int B = 16
) (
  // Reset and clock
  input logic rstn,
  input logic clk,

  // Trigger input
  input logic trigger_i,

  // Data input
  input logic din_valid_i,
  input logic [2*B-1:0] din_i,

  // Reset and clock for m_axis
  input logic m_axis_aclk,
  input logic m_axis_aresetn,

  // AXIS Master for output
  output logic m_axis_tvalid,
  input logic m_axis_tready,
  output logic [2*B-1:0] m_axis_tdata,
  output logic m_axis_tlast,

  // Registers (renamed to snake_case for lint)
  input logic buf_start_reg,
  input logic [N-1:0] buf_addr_reg,
  input logic [N-1:0] buf_len_reg,
  input logic dr_start_reg,
  input logic [N-1:0] dr_addr_reg,
  input logic [N:0] dr_len_reg
);

  //////////////////////////////////////////////////////////////////////////////
  // Internal signals
  //////////////////////////////////////////////////////////////////////////////
  logic mem_we_int;
  logic mem_en_int;
  logic [N-1:0] mem_addra_int, mem_addrb_int;
  logic [2*B-1:0] mem_di_int, mem_do_int;

  logic buf_start_reg_resync;
  logic dr_start_reg_resync;

  //////////////////////////////////////////////////////////////////////////////
  // Architecture
  //////////////////////////////////////////////////////////////////////////////

  // buf_start_reg_resync
  cdc_gray_sync #(
             .N (2),
             .M (1)
           ) buf_start_reg_resync_i (
             .i_rstn (rstn),
             .i_clk  (clk),
             .i_d    (buf_start_reg),
             .o_d    (buf_start_reg_resync)
           );

  // dr_start_reg_resync
  cdc_gray_sync #(
             .N (2),
             .M (1)
           ) dr_start_reg_resync_i (
             .i_rstn (m_axis_aresetn),
             .i_clk  (m_axis_aclk),
             .i_d    (dr_start_reg),
             .o_d    (dr_start_reg_resync)
           );

  // Buffer block
  buffer #(
        .N (N),
        .B (B)
      ) buffer_i (
        // Reset and clock
        .rstn        (rstn),
        .clk         (clk),

        // Trigger input
        .trigger_i   (trigger_i),

        // Data input
        .din_valid_i (din_valid_i),
        .din_i       (din_i),

        // Memory interface
        .mem_we_o    (mem_we_int),
        .mem_addr_o  (mem_addra_int),
        .mem_di_o    (mem_di_int),

        // Registers
        .start_reg   (buf_start_reg_resync),
        .addr_reg    (buf_addr_reg),
        .len_reg     (buf_len_reg)
      );

  // Dual port BRAM
  bram_tdp #(
    .NB_DATA(2*B),
    .NB_ADDR(N)
  ) bram_i (
    .clka  (clk),
    .rsta  (~rstn),
    .ena   (1'b1),
    .wea   (mem_we_int),
    .addra (mem_addra_int),
    .dia   (mem_di_int),
    .doa   ( ),

    .clkb  (m_axis_aclk),
    .rstb  (~m_axis_aresetn),
    .enb   (mem_en_int),
    .web   (1'b0),
    .addrb (mem_addrb_int),
    .dib   ({2*B{1'b0}}),
    .dob   (mem_do_int)
  );

  // Data reader
  bram_to_axis #(
      .BRAM_ADDR_WIDTH(N),
      .BRAM_DATA_WIDTH(2*B)
  ) u_bram_to_axis (
      .rstn      (m_axis_aresetn),
      .clk       (m_axis_aclk),
      .mem_en    (mem_en_int),
      .mem_we    ( ),
      .mem_addr  (mem_addrb_int),
      .mem_dout  (mem_do_int),
      .mem_din   ( ),
      .m_axis_tready (m_axis_tready),
      .m_axis_tvalid (m_axis_tvalid),
      .m_axis_tdata  (m_axis_tdata),
      .m_axis_tlast  (m_axis_tlast),
      .start_reg(dr_start_reg_resync),
      .addr_reg (dr_addr_reg),
      .len_reg  (dr_len_reg)
  );

endmodule
