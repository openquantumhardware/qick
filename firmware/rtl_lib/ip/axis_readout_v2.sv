`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_readout_v2
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_readout_v2.sv
//!
//! @brief   axis_readout_v2
//!
//! @details
//!
//! Top level of the QICK PS-configured readout IP: 8 parallel real-ADC
//! sample x complex-DDS demodulators with an 8x decimating lowpass FIR,
//! configured over AXI-Lite (unlike axis_dyn_readout_v1, which is
//! tProc-streamed).
//!
//! Wraps the readout_top_ro_v2 datapath with an AXI4-Lite register block
//! (axil_slv) exposing FREQ/PHASE/NSAMP/OUTSEL/MODE/WE.
//!
//! Two clock domains:
//!
//! - s_axi_aclk : AXI4-Lite configuration.
//! - aclk       : ADC input, demodulation, decimation, output.
//!
//! Register map (axil_slv, byte-addressed, regwidth = 32):
//! 0x00 FREQ_REG   : phase increment (32-bit, sw=rw).
//! 0x04 PHASE_REG  : initial phase (32-bit, sw=rw).
//! 0x08 NSAMP_REG  : number of output samples (bits[15:0], sw=rw).
//! 0x0C OUTSEL_REG : output source, bits[1:0] (0=product,1=dds,2=input,
//!                   sw=rw).
//! 0x10 MODE_REG   : mode, bit 0 (0=nsamp,1=periodic, sw=rw).
//! 0x14 WE_REG     : write-enable strobe, bit 0 (sw=rw). A LEVEL, not
//!                   self-clearing: pushes one descriptor into the FIFO on
//!                   its rising edge (edge-detected in readout_top_ro_v2
//!                   after resynchronization), matching the production
//!                   driver's `update()` (`we_reg = 1; we_reg = 0`).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_readout_v2 #(
    parameter int N_DDS = 8  //! Number of parallel demodulator lanes (fixed by the FIR: 8).
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

    // Datapath clock/reset (ADC input, demod, decimation, output).
    input  logic aresetn,
    input  logic aclk,

    // S_AXIS: for input data (N_DDS samples per clock).
    input  logic                 s_axis_tvalid,
    output logic                 s_axis_tready,
    input  logic [N_DDS*16-1:0]  s_axis_tdata,

    // M0_AXIS: for output data (before filter and decimation).
    input  logic                 m0_axis_tready,
    output logic                 m0_axis_tvalid,
    output logic [N_DDS*32-1:0]  m0_axis_tdata,

    // M1_AXIS: for output data (decimated).
    input  logic         m1_axis_tready,
    output logic         m1_axis_tvalid,
    output logic [31:0]  m1_axis_tdata
);

    // --------------------------------------------------------------------------
    // Register map indices.
    // --------------------------------------------------------------------------
    localparam int NUM_REGS   = 6;
    localparam int R_FREQ     = 0;
    localparam int R_PHASE    = 1;
    localparam int R_NSAMP    = 2;
    localparam int R_OUTSEL   = 3;
    localparam int R_MODE     = 4;
    localparam int R_WE       = 5;

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
    // Readout datapath.
    // --------------------------------------------------------------------------
    readout_top_ro_v2 #(
        .N_DDS (N_DDS)
    ) readout_top_i (
        .aresetn (aresetn),
        .aclk    (aclk),

        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .s_axis_tdata  (s_axis_tdata),

        .m0_axis_tready (m0_axis_tready),
        .m0_axis_tvalid (m0_axis_tvalid),
        .m0_axis_tdata  (m0_axis_tdata),

        .m1_axis_tready (m1_axis_tready),
        .m1_axis_tvalid (m1_axis_tvalid),
        .m1_axis_tdata  (m1_axis_tdata),

        .freq_reg   (slv_regs_o[R_FREQ]),
        .phase_reg  (slv_regs_o[R_PHASE]),
        .nsamp_reg  (slv_regs_o[R_NSAMP][15:0]),
        .outsel_reg (slv_regs_o[R_OUTSEL][1:0]),
        .mode_reg   (slv_regs_o[R_MODE][0]),
        .we_reg     (slv_regs_o[R_WE][0])
    );

endmodule
