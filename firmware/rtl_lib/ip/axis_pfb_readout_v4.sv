`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_pfb_readout_v4
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_pfb_readout_v4.sv
//!
//! @brief   PFB readout: a 64-channel, 50 %-overlap polyphase filter bank
//!          on the ADC stream, 8 selectable channels, each down-converted by
//!          its own phase-coherent DDS.
//!
//! @details
//! Faithful port of the legacy QICK IP (openquantumhardware/qick firmware/ip/
//! axis_pfb_readout_v4, QICK:QICK:axis_pfb_readout_v4:1.0) on the ported
//! qick:dsp:pfb_readout (NOUT = 8) and the generic axil_slv. Same ports and
//! parameter.
//!
//! Two clock domains:
//! - s_axi_aclk: AXI4-Lite configuration.
//! - aclk: ADC input (4 samples per clock), filter bank, outputs.
//!
//! Register map (axil_slv, 64 x 32 bits, all read/write, reset 0; the
//! registers cross into aclk as they are, quasi-static, as in the legacy):
//!   0x00 + 4i, i = 0..7: IDi_REG[15:0], output i's channel: [7:0] clock in
//!                        the PFB frame, [15:8] word (channel k = {k%8, k/8}).
//!   0x20 + 8i: PINCi_REG, output i's DDS phase increment per output sample.
//!   0x24 + 8i: POFFi_REG, output i's DDS phase offset.
//!   0x60..0xFC: unused, read/write storage (as in the legacy slave).
//!
//! Outputs: m<i>_axis_tdata = {Q, I} of output i, one sample per 8 aclk;
//! every m<i>_axis_tvalid is the same strobe. No tready.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_pfb_readout_v4 #(
    parameter int N = 64   //! PFB channels (only 64 is built)
) (
    input  logic         s_axi_aclk,
    input  logic         s_axi_aresetn,
    input  logic [7:0]   s_axi_awaddr,
    input  logic [2:0]   s_axi_awprot,
    input  logic         s_axi_awvalid,
    output logic         s_axi_awready,
    input  logic [31:0]  s_axi_wdata,
    input  logic [3:0]   s_axi_wstrb,
    input  logic         s_axi_wvalid,
    output logic         s_axi_wready,
    output logic [1:0]   s_axi_bresp,
    output logic         s_axi_bvalid,
    input  logic         s_axi_bready,
    input  logic [7:0]   s_axi_araddr,
    input  logic [2:0]   s_axi_arprot,
    input  logic         s_axi_arvalid,
    output logic         s_axi_arready,
    output logic [31:0]  s_axi_rdata,
    output logic [1:0]   s_axi_rresp,
    output logic         s_axi_rvalid,
    input  logic         s_axi_rready,

    input  logic         aresetn,
    input  logic         aclk,

    input  logic         s_axis_tvalid,
    input  logic [127:0] s_axis_tdata,

    output logic         m0_axis_tvalid,
    output logic [31:0]  m0_axis_tdata,
    output logic         m1_axis_tvalid,
    output logic [31:0]  m1_axis_tdata,
    output logic         m2_axis_tvalid,
    output logic [31:0]  m2_axis_tdata,
    output logic         m3_axis_tvalid,
    output logic [31:0]  m3_axis_tdata,
    output logic         m4_axis_tvalid,
    output logic [31:0]  m4_axis_tdata,
    output logic         m5_axis_tvalid,
    output logic [31:0]  m5_axis_tdata,
    output logic         m6_axis_tvalid,
    output logic [31:0]  m6_axis_tdata,
    output logic         m7_axis_tvalid,
    output logic [31:0]  m7_axis_tdata
);

    localparam int NOUT     = 8;
    localparam int NUM_REGS = 64;

    logic [31:0] regs [NUM_REGS];
    logic [31:0] ro_regs [NUM_REGS];
    logic [15:0] id   [NOUT];
    logic [31:0] pinc [NOUT];
    logic [31:0] poff [NOUT];
    logic        valid;
    logic [31:0] dout [NOUT];

    assign ro_regs = '{default: '0};

    axil_slv #(
        .AXI_DW   (32),
        .AXI_AW   (8),
        .NUM_REGS (NUM_REGS)
    ) axil_slv_i (
        .s_axi_aclk        (s_axi_aclk),
        .s_axi_aresetn     (s_axi_aresetn),
        .s_axi_awaddr      (s_axi_awaddr),
        .s_axi_awprot      (s_axi_awprot),
        .s_axi_awvalid     (s_axi_awvalid),
        .s_axi_awready     (s_axi_awready),
        .s_axi_wdata       (s_axi_wdata),
        .s_axi_wstrb       (s_axi_wstrb),
        .s_axi_wvalid      (s_axi_wvalid),
        .s_axi_wready      (s_axi_wready),
        .s_axi_bresp       (s_axi_bresp),
        .s_axi_bvalid      (s_axi_bvalid),
        .s_axi_bready      (s_axi_bready),
        .s_axi_araddr      (s_axi_araddr),
        .s_axi_arprot      (s_axi_arprot),
        .s_axi_arvalid     (s_axi_arvalid),
        .s_axi_arready     (s_axi_arready),
        .s_axi_rdata       (s_axi_rdata),
        .s_axi_rresp       (s_axi_rresp),
        .s_axi_rvalid      (s_axi_rvalid),
        .s_axi_rready      (s_axi_rready),
        .o_slv_regs        (regs),
        .i_slv_regs        (ro_regs),
        .i_reg_is_readonly ('0)
    );

    for (genvar i = 0; i < NOUT; i++) begin : g_regs
        assign id[i]   = regs[i][15:0];
        assign pinc[i] = regs[8 + 2*i];
        assign poff[i] = regs[9 + 2*i];
    end

    pfb_readout #(.N(N), .L(4), .NOUT(NOUT)) pfb_readout_i (
        .aresetn       (aresetn),
        .aclk          (aclk),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tdata  (s_axis_tdata),
        .m_axis_tvalid (valid),
        .m_axis_tdata  (dout),
        .id_reg        (id),
        .pinc_reg      (pinc),
        .poff_reg      (poff)
    );

    assign {m7_axis_tvalid, m6_axis_tvalid, m5_axis_tvalid, m4_axis_tvalid,
            m3_axis_tvalid, m2_axis_tvalid, m1_axis_tvalid, m0_axis_tvalid} = {NOUT{valid}};
    assign m0_axis_tdata = dout[0];
    assign m1_axis_tdata = dout[1];
    assign m2_axis_tdata = dout[2];
    assign m3_axis_tdata = dout[3];
    assign m4_axis_tdata = dout[4];
    assign m5_axis_tdata = dout[5];
    assign m6_axis_tdata = dout[6];
    assign m7_axis_tdata = dout[7];

endmodule
