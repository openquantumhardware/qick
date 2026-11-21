///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : avg_top
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    avg_top.sv
//!
//! @brief   AVG_TOP block receives an input stream of samples (s_axis),
//!
//! @details
//!
//! captures and stores them in an internal memory when indicated and generates
//! two output streams, one with averaged data stored in internal memory (m0_axis)
//! and one with averaged data as soon as it's calculated prior to internal
//! memory (m1_axis). Capturing flow is controlled by the AVG FSM block and is
//! initiated by an external trigger after the buffer has been enabled. Number of
//! captured samples and address where to store them are configurable. Captured
//! samples are internally stored in BRAM memory. Output stream is generated and
//! controlled from the DATA_READER FSM block. Address to start reading and
//! number of samples are configurable. It can be interfaced with an AXIS DMA
//! module.
//!
//! @author  QICK Development Team
//!
//! @version 1.0

module avg_top #(
    //! memory depth as 2**N
    parameter int N = 10,  // Memory depth (2**N)
    //! memory data width
    parameter int B = 16   // Number of bits
  ) (
    // Reset and clock
    input logic rstn,
    input logic clk,

    // Trigger input
    input logic trigger_i,

    // Data input
    input logic din_valid_i,
    input logic [2*B-1:0] din_i,

    // Reset and clock for m0_axis and m1_axis
    input logic m_axis_aclk,
    input logic m_axis_aresetn,

    // AXIS Master for output
    output logic m0_axis_tvalid,
    input logic m0_axis_tready,
    output logic [4*B-1:0] m0_axis_tdata,
    output logic m0_axis_tlast,

    // AXIS Master for register output
    output logic m1_axis_tvalid,
    input logic m1_axis_tready,
    output logic [4*B-1:0] m1_axis_tdata,
    output logic m1_axis_tlast,

    // Registers (renamed to snake_case for lint)
    input logic avg_start_reg,
    input logic [N-1:0] avg_addr_reg,
    input logic [31:0] avg_len_reg,
    input logic dr_start_reg,
    input logic [N-1:0] dr_addr_reg,
    input logic [N:0] dr_len_reg,
    input logic avg_photon_mode_reg,
    input logic [B-1:0] avg_h_thrsh_reg,
    input logic [B-1:0] avg_l_thrsh_reg
  );

  //////////////////////////////////////////////////////////////////////////////
  // Internal signals
  //////////////////////////////////////////////////////////////////////////////
  logic mem_we_int;
  logic mem_en_int;
  logic [N-1:0] mem_addra_int, mem_addrb_int;
  logic [4*B-1:0] mem_di_int, mem_do_int;

  logic avg_start_reg_resync;
  logic dr_start_reg_resync;

  logic fifo_empty;

  //////////////////////////////////////////////////////////////////////////////
  // Architecture
  //////////////////////////////////////////////////////////////////////////////

  // avg_start_reg_resync
  cdc_gray_sync #(
             .N (2),
             .M (1)
           ) avg_start_reg_resync_i (
             .i_rstn (rstn),
             .i_clk  (clk),
             .i_d    (avg_start_reg),
             .o_d    (avg_start_reg_resync)
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

  // Average block
  avg #(
        .N (N),
        .B (B)
      ) avg_i (
        // Reset and clock
        .rstn            (rstn),
        .clk             (clk),

        // Trigger input
        .trigger_i       (trigger_i),

        // Data input
        .din_valid_i     (din_valid_i),
        .din_i           (din_i),

        // Memory interface
        .mem_we_o        (mem_we_int),
        .mem_addr_o      (mem_addra_int),
        .mem_di_o        (mem_di_int),

        // Registers
        .start_reg       (avg_start_reg_resync),
        .addr_reg        (avg_addr_reg),
        .len_reg         (avg_len_reg),
        .photon_mode_reg (avg_photon_mode_reg),
        .h_thrsh_reg     (avg_h_thrsh_reg),
        .l_thrsh_reg     (avg_l_thrsh_reg)
      );

  // Dual port BRAM
  bram_tdp #(
    .NB_DATA(4*B),
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
    .dib   ({4*B{1'b0}}),
    .dob   (mem_do_int)
  );

  // Data reader
  //data_reader #(
  //              .N (N),
  //              .B (4*B)
  //            ) data_reader_i (
  //              // Reset and clock
  //              .rstn    (m_axis_aresetn),
  //              .clk     (m_axis_aclk),

  //              // Memory I/F
  //              .mem_en  (mem_en_int),
  //              .mem_we  (),
  //              .mem_addr (mem_addrb_int),
  //              .mem_dout (mem_do_int),

  //              // Data out
  //              .dout    (m0_axis_tdata),
  //              .dready  (m0_axis_tready),
  //              .dvalid  (m0_axis_tvalid),
  //              .dlast   (m0_axis_tlast),

  //              // Registers
  //              .start_reg (dr_start_reg_resync),
  //              .addr_reg  (dr_addr_reg),
  //              .len_reg   (dr_len_reg)
  //            );
   // DUT
  bram_to_axis #(
      .BRAM_ADDR_WIDTH(N),
      .BRAM_DATA_WIDTH(4*B)
  ) u_bram_to_axis (
      .rstn      (m_axis_aresetn),
      .clk       (m_axis_aclk),
      .mem_en    (mem_en_int),
      .mem_we    ( ),
      .mem_addr  (mem_addrb_int),
      .mem_dout  (mem_do_int),
      .mem_din   ( ),
      .m_axis_tready (m0_axis_tready),
      .m_axis_tvalid (m0_axis_tvalid),
      .m_axis_tdata  (m0_axis_tdata),
      .m_axis_tlast  (m0_axis_tlast),
      .start_reg(dr_start_reg_resync),
      .addr_reg (dr_addr_reg),
      .len_reg  (dr_len_reg)
  );

  // -------------------------------------------------------------------------
  // Asynchronous FIFO Instantiation (fifo_dc replacement)
  // -------------------------------------------------------------------------
  fifo_async #(
    .B (4*B),
    .N (16)
  ) u_fifo_async (
    // Write domain
    .wr_rstn    (rstn),
    .wr_clk     (clk),
    .wr_en      (mem_we_int),
    .din        (mem_di_int),
    .full       (),
    .wr_err     (),

    // Read domain
    .rd_rstn    (m_axis_aresetn),
    .rd_clk     (m_axis_aclk),
    .rd_en      (m1_axis_tready),
    .dout       (m1_axis_tdata),
    .empty      (fifo_empty),
    .data_valid (m1_axis_tvalid)
  );

  // Assign outputs
  //assign m1_axis_tvalid = ~fifo_empty;

endmodule
