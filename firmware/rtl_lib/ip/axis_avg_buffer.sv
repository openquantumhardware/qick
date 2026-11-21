`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_avg_buffer
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_avg_buffer.sv
//!
//! @brief   axis_avg_buffer
//!
//! @details
//!
//! Top level of the QICK averager + raw buffer IP: receives an input
//! stream of samples (s_axis) and generates three output streams -- one
//! with processed averaged data (m0_axis), one with raw captured data
//! (m1_axis), and one with averaged data as soon as it's calculated,
//! prior to being stored in internal memory (m2_axis, typically fed to a
//! tProc register). Capture on either buffer (avg or buf) is initiated by
//! an external trigger once that buffer has been armed via its own
//! START_REG.
//!
//! Wraps the avg_buffer datapath (avg_top + buffer_top + shared trigger
//! resync) with an AXI4-Lite register block (axil_slv) exposing all 15
//! AVG_*/BUF_* control registers, matching the production driver
//! (`AxisAvgBufferV1pt2` in qick_lib/qick/drivers/readout.py) exactly.
//!
//! Versioned as v1.2 (not v1.1): the register map, RTL and FSMs here are
//! byte-for-byte identical to the legacy source checked into
//! firmware/ip/axis_avg_buffer/src/ in the private development repository (there labeled
//! v1.0 in its stale component.xml) and in openquantumhardware/qick (there labeled v1.2).
//! v1.1's photon-mode registers are present in both, so this RTL already
//! IS the v1.2 revision -- there is no RTL difference to port for v1.2,
//! only a version/bindto correction. See CHANGELOG for the diff trail.
//!
//! Two clock domains:
//!
//! - s_axi_aclk : AXI4-Lite configuration.
//! - s_axis_aclk / m_axis_aclk : capture (write side) / readout (read
//!   side) datapath. These may be the same physical clock in a given
//!   integration but are independent ports here, matching the legacy IP.
//!
//! Register map (axil_slv, byte-addressed, regwidth = 32) -- matches
//! AxisAvgBufferV1pt2.REGISTERS exactly:
//! 0x00 AVG_START_REG       : averager enable, bit 0 (sw=rw).
//! 0x04 AVG_ADDR_REG        : averager write start address (sw=rw).
//! 0x08 AVG_LEN_REG         : averager sample count (sw=rw).
//! 0x0C AVG_DR_START_REG    : averager data-reader enable, bit 0 (sw=rw).
//! 0x10 AVG_DR_ADDR_REG     : averager data-reader start address (sw=rw).
//! 0x14 AVG_DR_LEN_REG      : averager data-reader sample count (sw=rw).
//! 0x18 BUF_START_REG       : buffer enable, bit 0 (sw=rw).
//! 0x1C BUF_ADDR_REG        : buffer write start address (sw=rw).
//! 0x20 BUF_LEN_REG         : buffer sample count (sw=rw).
//! 0x24 BUF_DR_START_REG    : buffer data-reader enable, bit 0 (sw=rw).
//! 0x28 BUF_DR_ADDR_REG     : buffer data-reader start address (sw=rw).
//! 0x2C BUF_DR_LEN_REG      : buffer data-reader sample count (sw=rw).
//! 0x30 AVG_PHOTON_MODE_REG : averager mode select, bit 0 (0=accumulate,
//!                            1=edge/photon counter) (sw=rw).
//! 0x34 AVG_H_THRSH_REG     : photon-mode high threshold (sw=rw).
//! 0x38 AVG_L_THRSH_REG     : photon-mode low threshold (sw=rw).
//!
//! All *_START_REG fields are LEVELs, not self-clearing: software is
//! expected to hold them high through an entire capture cycle and drop
//! them to release the FSM back to its idle state, matching the avg/
//! buffer FSMs' own documented protocol.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_avg_buffer #(
    //! averager memory depth as 2**N_AVG
    parameter int N_AVG = 10,
    //! buffer memory depth as 2**N_BUF
    parameter int N_BUF = 10,
    //! sample data width in bits
    parameter int B = 16
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

    // Trigger input (async, external).
    input  logic trigger,

    // AXIS Slave for input data.
    input  logic            s_axis_aclk,
    input  logic            s_axis_aresetn,
    input  logic            s_axis_tvalid,
    output logic            s_axis_tready,
    input  logic [2*B-1:0]  s_axis_tdata,

    // Reset and clock for m0/m1/m2 axis.
    input  logic m_axis_aclk,
    input  logic m_axis_aresetn,

    // AXIS Master for averaged output.
    output logic            m0_axis_tvalid,
    input  logic            m0_axis_tready,
    output logic [4*B-1:0]  m0_axis_tdata,
    output logic            m0_axis_tlast,

    // AXIS Master for raw output.
    output logic            m1_axis_tvalid,
    input  logic            m1_axis_tready,
    output logic [2*B-1:0]  m1_axis_tdata,
    output logic            m1_axis_tlast,

    // AXIS Master for register output.
    output logic            m2_axis_tvalid,
    input  logic            m2_axis_tready,
    output logic [4*B-1:0]  m2_axis_tdata
);

    // --------------------------------------------------------------------------
    // Register map indices.
    // --------------------------------------------------------------------------
    localparam int NUM_REGS          = 15;
    localparam int R_AVG_START       = 0;
    localparam int R_AVG_ADDR        = 1;
    localparam int R_AVG_LEN         = 2;
    localparam int R_AVG_DR_START    = 3;
    localparam int R_AVG_DR_ADDR     = 4;
    localparam int R_AVG_DR_LEN      = 5;
    localparam int R_BUF_START       = 6;
    localparam int R_BUF_ADDR        = 7;
    localparam int R_BUF_LEN         = 8;
    localparam int R_BUF_DR_START    = 9;
    localparam int R_BUF_DR_ADDR     = 10;
    localparam int R_BUF_DR_LEN      = 11;
    localparam int R_AVG_PHOTON_MODE = 12;
    localparam int R_AVG_H_THRSH     = 13;
    localparam int R_AVG_L_THRSH     = 14;

    logic [31:0] slv_regs_o [NUM_REGS];

    // --------------------------------------------------------------------------
    // AXI4-Lite register block. Every register is plain R/W.
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
    // Averager + buffer datapath.
    // --------------------------------------------------------------------------
    avg_buffer #(
        .N_AVG (N_AVG),
        .N_BUF (N_BUF),
        .B     (B)
    ) avg_buffer_i (
        .s_axis_aclk    (s_axis_aclk),
        .s_axis_aresetn (s_axis_aresetn),

        .trigger (trigger),

        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .s_axis_tdata  (s_axis_tdata),

        .m_axis_aclk    (m_axis_aclk),
        .m_axis_aresetn (m_axis_aresetn),

        .m0_axis_tvalid (m0_axis_tvalid),
        .m0_axis_tready (m0_axis_tready),
        .m0_axis_tdata  (m0_axis_tdata),
        .m0_axis_tlast  (m0_axis_tlast),

        .m1_axis_tvalid (m1_axis_tvalid),
        .m1_axis_tready (m1_axis_tready),
        .m1_axis_tdata  (m1_axis_tdata),
        .m1_axis_tlast  (m1_axis_tlast),

        .m2_axis_tvalid (m2_axis_tvalid),
        .m2_axis_tready (m2_axis_tready),
        .m2_axis_tdata  (m2_axis_tdata),

        .avg_start_reg       (slv_regs_o[R_AVG_START][0]),
        .avg_addr_reg        (slv_regs_o[R_AVG_ADDR][N_AVG-1:0]),
        .avg_len_reg         (slv_regs_o[R_AVG_LEN]),
        .avg_photon_mode_reg (slv_regs_o[R_AVG_PHOTON_MODE][0]),
        .avg_h_thrsh_reg     (slv_regs_o[R_AVG_H_THRSH][B-1:0]),
        .avg_l_thrsh_reg     (slv_regs_o[R_AVG_L_THRSH][B-1:0]),
        .avg_dr_start_reg    (slv_regs_o[R_AVG_DR_START][0]),
        .avg_dr_addr_reg     (slv_regs_o[R_AVG_DR_ADDR][N_AVG-1:0]),
        .avg_dr_len_reg      (slv_regs_o[R_AVG_DR_LEN][N_AVG:0]),

        .buf_start_reg    (slv_regs_o[R_BUF_START][0]),
        .buf_addr_reg     (slv_regs_o[R_BUF_ADDR][N_BUF-1:0]),
        .buf_len_reg      (slv_regs_o[R_BUF_LEN][N_BUF-1:0]),
        .buf_dr_start_reg (slv_regs_o[R_BUF_DR_START][0]),
        .buf_dr_addr_reg  (slv_regs_o[R_BUF_DR_ADDR][N_BUF-1:0]),
        .buf_dr_len_reg   (slv_regs_o[R_BUF_DR_LEN][N_BUF:0])
    );

endmodule
