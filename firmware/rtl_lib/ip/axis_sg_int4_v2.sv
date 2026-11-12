`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_sg_int4_v2
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_sg_int4_v2.sv
//!
//! @brief   axis_sg_int4_v2
//!
//! @details
//!
//! Top level of the QICK interpolated (x4) arbitrary signal generator IP.
//!
//! Wraps the sg_int4_top datapath (envelope FIR-interpolation x DDS
//! product, gain, single-word envelope memory) with an AXI4-Lite register
//! block (axil_slv) exposing the envelope-writer control registers. Unlike
//! axis_signal_gen_v4/v6, this IP's legacy axi_slv.vhd never grew a
//! saturation-status/RNDQ pair -- just START_ADDR_REG and WE_REG, matching
//! the production driver's `AbsIntSignalGen.REGISTERS = {'start_addr_reg':
//! 0, 'we_reg': 1}` exactly.
//!
//! Three clock domains:
//!
//! - s_axi_aclk   : AXI4-Lite configuration.
//! - s0_axis_aclk : envelope sample loading (BRAM write side).
//! - aclk         : descriptor FIFO, signal generator, output.
//!
//! Register map (axil_slv, byte-addressed, regwidth = 32):
//! 0x00 START_ADDR_REG : envelope write start address (32-bit, sw=rw).
//! 0x04 WE_REG         : envelope write enable, bit 0 (sw=rw).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_sg_int4_v2 #(
    //! Envelope-memory address width (depth 2**N).
    parameter int N     = 16,
    //! Number of interpolated lanes (fixed by the FIR: x4).
    parameter int N_DDS = 4
)(
    // AXI4-Lite slave (configuration).
    input  logic        s_axi_aclk,
    input  logic        s_axi_aresetn,
    input  logic [5:0]  s_axi_awaddr,
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
    input  logic [5:0]  s_axi_araddr,
    input  logic [2:0]  s_axi_arprot,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // AXIS slave: envelope sample loading.
    input  logic         s0_axis_aclk,
    input  logic         s0_axis_aresetn,
    input  logic [31:0]  s0_axis_tdata,
    input  logic         s0_axis_tvalid,
    output logic         s0_axis_tready,

    // s1_* and m_* clock/reset.
    input  logic          aclk,
    input  logic          aresetn,

    // AXIS slave: waveform descriptor queue.
    input  logic [159:0]  s1_axis_tdata,
    input  logic          s1_axis_tvalid,
    output logic          s1_axis_tready,

    // AXIS master: output.
    input  logic                 m_axis_tready,
    output logic                 m_axis_tvalid,
    output logic [N_DDS*32-1:0]  m_axis_tdata
);

    // --------------------------------------------------------------------------
    // Register map indices.
    // --------------------------------------------------------------------------
    localparam int NUM_REGS     = 2;
    localparam int R_START_ADDR = 0;
    localparam int R_WE         = 1;

    logic [31:0] slv_regs_o [NUM_REGS];

    // --------------------------------------------------------------------------
    // AXI4-Lite register block.
    // --------------------------------------------------------------------------
    axil_slv #(
        .AXI_DW   (32),
        .AXI_AW   (6),
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
    // Signal generator (datapath + memory + FIFO + FIR + DDS).
    // --------------------------------------------------------------------------
    sg_int4_top #(
        .N     (N),
        .N_DDS (N_DDS)
    ) sg_int4_top_i (
        .aresetn          (aresetn),
        .aclk             (aclk),
        .s0_axis_aresetn  (s0_axis_aresetn),
        .s0_axis_aclk     (s0_axis_aclk),
        .s0_axis_tdata_i  (s0_axis_tdata),
        .s0_axis_tvalid_i (s0_axis_tvalid),
        .s0_axis_tready_o (s0_axis_tready),
        .s1_axis_tdata_i  (s1_axis_tdata),
        .s1_axis_tvalid_i (s1_axis_tvalid),
        .s1_axis_tready_o (s1_axis_tready),
        .m_axis_tready_i  (m_axis_tready),
        .m_axis_tvalid_o  (m_axis_tvalid),
        .m_axis_tdata_o   (m_axis_tdata),
        .start_addr_reg   (slv_regs_o[R_START_ADDR]),
        .we_reg           (slv_regs_o[R_WE][0])
    );

endmodule
