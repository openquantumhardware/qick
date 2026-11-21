`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_sg_mux8_v1
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_sg_mux8_v1.sv
//!
//! @brief   axis_sg_mux8_v1
//!
//! @details
//!
//! Top level of the QICK mux8 signal generator IP: 8 independently masked,
//! phase-coherent, gain-scaled DDS waves, summed into one interleaved
//! (N_DDS-wide) output stream.
//!
//! Wraps the sg_mux8 datapath with an AXI4-Lite register block (axil_slv)
//! that exposes the per-channel PINC/POFF/GAIN registers and the shared
//! write-enable strobe.
//!
//! Two clock domains:
//!
//! - s_axi_aclk : AXI4-Lite configuration.
//! - aclk       : waveform descriptor FIFO, DDS lanes, output.
//!
//! Register map (axil_slv, byte-addressed, regwidth = 32):
//! 0x00-0x1C PINC0_REG..PINC7_REG   : phase increment, channels 0-7.
//! 0x20-0x3C POFF0_REG..POFF7_REG   : phase offset, channels 0-7.
//! 0x40-0x5C GAIN0_REG..GAIN7_REG   : signed Q1.15 gain, channels 0-7
//!                                    (lower 16 bits only).
//! 0x60      WE_REG                : write-enable, bit 0. A level (not
//!                                    self-clearing): PINC/POFF/GAIN are
//!                                    latched into the datapath continuously
//!                                    while this bit is high, matching the
//!                                    legacy phase_ctrl behavior.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_sg_mux8_v1 #(
    parameter int N_DDS = 2  //! Number of interleaved parallel DDS lanes.
)(
    // AXI4-Lite slave (configuration).
    input  logic        s_axi_aclk,
    input  logic        s_axi_aresetn,
    input  logic [7:0]  s_axi_awaddr,
    input  logic [2:0]  s_axi_awprot,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,
    input  logic [7:0]  s_axi_araddr,
    input  logic [2:0]  s_axi_arprot,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // Datapath clock/reset (descriptor fifo, DDS lanes, output).
    input  logic                 aclk,
    input  logic                 aresetn,

    // AXIS slave: waveform descriptor queue.
    input  logic [39:0]          s_axis_tdata,
    input  logic                 s_axis_tvalid,
    output logic                 s_axis_tready,

    // AXIS master: output.
    input  logic                 m_axis_tready,
    output logic                 m_axis_tvalid,
    output logic [N_DDS*16-1:0]  m_axis_tdata
);

    // --------------------------------------------------------------------------
    // Register map indices.
    // --------------------------------------------------------------------------
    localparam int NUM_REGS = 25;
    localparam int R_PINC0  = 0;
    localparam int R_POFF0  = 8;
    localparam int R_GAIN0  = 16;
    localparam int R_WE     = 24;

    logic [31:0] slv_regs_o [NUM_REGS];

    // --------------------------------------------------------------------------
    // AXI4-Lite register block. Every register is plain R/W: no read-only
    // fields, so i_slv_regs simply loops back the writable value.
    // --------------------------------------------------------------------------
    axil_slv #(
        .AXI_DW   (32),
        .AXI_AW   (8),
        .NUM_REGS (NUM_REGS)
    ) axil_slv_i (
        .s_axi_aclk    (s_axi_aclk),
        .s_axi_aresetn (s_axi_aresetn),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awprot  (s_axi_awprot),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arprot  (s_axi_arprot),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),
        .o_slv_regs    (slv_regs_o),
        .i_slv_regs    (slv_regs_o),
        .i_reg_is_readonly ('0)
    );

    // --------------------------------------------------------------------------
    // Signal generator datapath.
    // --------------------------------------------------------------------------
    sg_mux8 #(
        .N_DDS (N_DDS)
    ) sg_mux8_i (
        .aresetn (aresetn),
        .aclk    (aclk),

        .s_axis_tready_o (s_axis_tready),
        .s_axis_tvalid_i (s_axis_tvalid),
        .s_axis_tdata_i  (s_axis_tdata),

        .m_axis_tready_i (m_axis_tready),
        .m_axis_tvalid_o (m_axis_tvalid),
        .m_axis_tdata_o  (m_axis_tdata),

        .pinc0_reg (slv_regs_o[R_PINC0+0]),
        .pinc1_reg (slv_regs_o[R_PINC0+1]),
        .pinc2_reg (slv_regs_o[R_PINC0+2]),
        .pinc3_reg (slv_regs_o[R_PINC0+3]),
        .pinc4_reg (slv_regs_o[R_PINC0+4]),
        .pinc5_reg (slv_regs_o[R_PINC0+5]),
        .pinc6_reg (slv_regs_o[R_PINC0+6]),
        .pinc7_reg (slv_regs_o[R_PINC0+7]),

        .poff0_reg (slv_regs_o[R_POFF0+0]),
        .poff1_reg (slv_regs_o[R_POFF0+1]),
        .poff2_reg (slv_regs_o[R_POFF0+2]),
        .poff3_reg (slv_regs_o[R_POFF0+3]),
        .poff4_reg (slv_regs_o[R_POFF0+4]),
        .poff5_reg (slv_regs_o[R_POFF0+5]),
        .poff6_reg (slv_regs_o[R_POFF0+6]),
        .poff7_reg (slv_regs_o[R_POFF0+7]),

        .gain0_reg (slv_regs_o[R_GAIN0+0][15:0]),
        .gain1_reg (slv_regs_o[R_GAIN0+1][15:0]),
        .gain2_reg (slv_regs_o[R_GAIN0+2][15:0]),
        .gain3_reg (slv_regs_o[R_GAIN0+3][15:0]),
        .gain4_reg (slv_regs_o[R_GAIN0+4][15:0]),
        .gain5_reg (slv_regs_o[R_GAIN0+5][15:0]),
        .gain6_reg (slv_regs_o[R_GAIN0+6][15:0]),
        .gain7_reg (slv_regs_o[R_GAIN0+7][15:0]),

        .we_reg (slv_regs_o[R_WE][0])
    );

endmodule
