`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_kidsim_v3
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_kidsim_v3.sv
//!
//! @brief   KID (Kinetic Inductance Detector) simulator IP, L parallel lanes.
//!
//! @details
//!
//! Top level of the axis_kidsim_v3 IP. Wraps L parallel kidsim_top lanes with
//! an AXI4-Lite register block (axil_slv) exposing the per-lane configuration.
//!
//! Each lane processes one 32-bit {Q,I} sub-word of the packed AXIS input
//! (s_axis_tdata is 32*L bits). A lane simulates a resonator: it demodulates
//! the input by a (possibly chirped) DDS carrier, filters with a 1-pole/1-zero
//! IIR, and remodulates. See kidsim / kidsim_top.
//!
//! Per-lane register writes are addressed by ADDR_REG: a write with WE_REG=1
//! lands on lane number ADDR_REG. WE_REG crosses into the aclk domain inside
//! kidsim_top (cdc_bit_sync). The modulation trigger is per-lane (trigger[i]);
//! it is resynchronized inside dds_phase_ctrl.
//!
//! Register map (axil_slv, byte-addressed, 32-bit regs):
//!   0x00 DDS_BVAL_REG  : chirp ramp start B         [15:0]
//!   0x04 DDS_SLOPE_REG : chirp ramp slope M         [15:0]
//!   0x08 DDS_STEPS_REG : chirp ramp steps N         [15:0]
//!   0x0C DDS_WAIT_REG  : chirp ramp wait W          [15:0]
//!   0x10 DDS_FREQ_REG  : DDS base frequency         [15:0]
//!   0x14 IIR_C0_REG    : IIR coefficient C0         [15:0]
//!   0x18 IIR_C1_REG    : IIR coefficient C1         [15:0]
//!   0x1C IIR_G_REG     : IIR gain G                 [15:0]
//!   0x20 OUTSEL_REG    : output select              [1:0]
//!   0x24 PUNCT_ID_REG  : puncturing sample index    [15:0]
//!   0x28 ADDR_REG      : target lane for a write     [ADDR_W-1:0]
//!   0x2C WE_REG        : write enable, bit 0
//!
//! @author  @lharnaldi
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_kidsim_v3 #(
    //! Number of parallel lanes.
    parameter int L = 8
) (
    // Per-lane modulation trigger.
    input  logic [L-1:0]      trigger,

    // AXI4-Lite slave (configuration).
    input  logic              s_axi_aclk,
    input  logic              s_axi_aresetn,
    input  logic [7:0]        s_axi_awaddr,
    input  logic [2:0]        s_axi_awprot,
    input  logic              s_axi_awvalid,
    output logic              s_axi_awready,
    input  logic [31:0]       s_axi_wdata,
    input  logic [3:0]        s_axi_wstrb,
    input  logic              s_axi_wvalid,
    output logic              s_axi_wready,
    output logic [1:0]        s_axi_bresp,
    output logic              s_axi_bvalid,
    input  logic              s_axi_bready,
    input  logic [7:0]        s_axi_araddr,
    input  logic [2:0]        s_axi_arprot,
    input  logic              s_axi_arvalid,
    output logic              s_axi_arready,
    output logic [31:0]       s_axi_rdata,
    output logic [1:0]        s_axi_rresp,
    output logic              s_axi_rvalid,
    input  logic              s_axi_rready,

    // Datapath clock/reset.
    input  logic              aresetn,
    input  logic              aclk,

    // AXIS slave: input.
    input  logic              s_axis_tvalid,
    input  logic [32*L-1:0]   s_axis_tdata,
    input  logic              s_axis_tlast,

    // AXIS master: output.
    output logic              m_axis_tvalid,
    output logic [32*L-1:0]   m_axis_tdata,
    output logic              m_axis_tlast
);

    // ------------------------------------------------------------------------
    // Register map.
    // ------------------------------------------------------------------------
    localparam int NUM_REGS     = 12;
    localparam int R_DDS_BVAL   = 0;
    localparam int R_DDS_SLOPE  = 1;
    localparam int R_DDS_STEPS  = 2;
    localparam int R_DDS_WAIT   = 3;
    localparam int R_DDS_FREQ   = 4;
    localparam int R_IIR_C0     = 5;
    localparam int R_IIR_C1     = 6;
    localparam int R_IIR_G      = 7;
    localparam int R_OUTSEL     = 8;
    localparam int R_PUNCT_ID   = 9;
    localparam int R_ADDR       = 10;
    localparam int R_WE         = 11;

    logic [31:0] slv_regs_o [NUM_REGS];
    logic [31:0] slv_regs_i [NUM_REGS];
    logic [NUM_REGS-1:0] reg_ro;

    //! Register fields.
    logic [15:0] dds_bval_reg;
    logic [15:0] dds_slope_reg;
    logic [15:0] dds_steps_reg;
    logic [15:0] dds_wait_reg;
    logic [15:0] dds_freq_reg;
    logic [15:0] iir_c0_reg;
    logic [15:0] iir_c1_reg;
    logic [15:0] iir_g_reg;
    logic [ 1:0] outsel_reg;
    logic [15:0] punct_id_reg;
    logic [ 7:0] addr_reg;
    logic        we_reg;

    assign dds_bval_reg  = slv_regs_o[R_DDS_BVAL][15:0];
    assign dds_slope_reg = slv_regs_o[R_DDS_SLOPE][15:0];
    assign dds_steps_reg = slv_regs_o[R_DDS_STEPS][15:0];
    assign dds_wait_reg  = slv_regs_o[R_DDS_WAIT][15:0];
    assign dds_freq_reg  = slv_regs_o[R_DDS_FREQ][15:0];
    assign iir_c0_reg    = slv_regs_o[R_IIR_C0][15:0];
    assign iir_c1_reg    = slv_regs_o[R_IIR_C1][15:0];
    assign iir_g_reg     = slv_regs_o[R_IIR_G][15:0];
    assign outsel_reg    = slv_regs_o[R_OUTSEL][1:0];
    assign punct_id_reg  = slv_regs_o[R_PUNCT_ID][15:0];
    assign addr_reg      = slv_regs_o[R_ADDR][7:0];
    assign we_reg        = slv_regs_o[R_WE][0];

    //! All registers are read-write (loop back their written value).
    assign reg_ro = '0;
    always_comb begin
        for (int k = 0; k < NUM_REGS; k++)
            slv_regs_i[k] = slv_regs_o[k];
    end

    // ------------------------------------------------------------------------
    // Per-lane signals.
    // ------------------------------------------------------------------------
    logic [L-1:0] we_lane;       //! per-lane write enable
    logic [31:0]  din_v      [L];
    logic [L-1:0] dout_valid;
    logic [31:0]  dout_v     [L];
    logic [L-1:0] dout_last;

    // ------------------------------------------------------------------------
    // AXI4-Lite register block.
    // ------------------------------------------------------------------------
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
        .o_slv_regs        (slv_regs_o),
        .i_slv_regs        (slv_regs_i),
        .i_reg_is_readonly (reg_ro)
    );

    // ------------------------------------------------------------------------
    // L parallel kidsim lanes.
    // ------------------------------------------------------------------------
    generate
        for (genvar i = 0; i < L; i = i + 1) begin : gen_kidsim
            //! Per-lane input sub-word.
            assign din_v[i] = s_axis_tdata[i*32 +: 32];

            //! Write lands on the lane selected by ADDR_REG.
            assign we_lane[i] = we_reg & (addr_reg == i[7:0]);

            kidsim_top kidsim_top_i (
                .i_clk           (aclk),
                .i_rstn          (aresetn),
                .i_trigger       (trigger[i]),
                .i_din_valid     (s_axis_tvalid),
                .i_din           (din_v[i]),
                .i_din_last      (s_axis_tlast),
                .o_dout_valid    (dout_valid[i]),
                .o_dout          (dout_v[i]),
                .o_dout_last     (dout_last[i]),
                .i_dds_bval_reg  (dds_bval_reg),
                .i_dds_slope_reg (dds_slope_reg),
                .i_dds_steps_reg (dds_steps_reg),
                .i_dds_wait_reg  (dds_wait_reg),
                .i_dds_freq_reg  (dds_freq_reg),
                .i_iir_c0_reg    (iir_c0_reg),
                .i_iir_c1_reg    (iir_c1_reg),
                .i_iir_g_reg     (iir_g_reg),
                .i_outsel_reg    (outsel_reg),
                .i_punct_id_reg  (punct_id_reg),
                .i_we_reg        (we_lane[i])
            );

            //! Per-lane output sub-word.
            assign m_axis_tdata[i*32 +: 32] = dout_v[i];
        end
    endgenerate

    // ------------------------------------------------------------------------
    // Output valid/last taken from lane 0 (all lanes share timing).
    // ------------------------------------------------------------------------
    assign m_axis_tvalid = dout_valid[0];
    assign m_axis_tlast  = dout_last[0];

endmodule

