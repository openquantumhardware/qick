`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_weighted_buffer
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_weighted_buffer.sv
//!
//! @brief   axis_weighted_buffer
//!
//! @details
//!
//! Top level of the QICK weighted averager + raw buffer IP: like
//! axis_avg_buffer, but with a matched-filter front end (weighted_buffer)
//! that multiplies the incoming stream by a DMA-loaded weight envelope
//! before it reaches the averager/buffer. Generates the same three output
//! streams (m0=averaged BRAM readback, m1=raw/filtered BRAM readback,
//! m2=averaged live feed).
//!
//! Versioned as v1.3 (matches AxisWeightedBufferV1pt3, the deployed
//! revision with the first-output-sample bug fixed -- see
//! axis_avg_buffer.sv's own v1.1->v1.2 correction for the same class of
//! finding on the sibling IP). Faithful port of legacy source at
//! openquantumhardware/qick firmware/ip/axis_weighted_buffer/ (component.xml
//! <spirit:version>1.3</spirit:version>).
//!
//! Register map is NOT a copy of axis_avg_buffer's: axi_slv.vhd (the
//! legacy hand-written AXI slave) packs AVG_START_REG/BUF_START_REG into
//! bits [0]/[1] of a single reg0, and AVG_DR_START_REG/BUF_DR_START_REG/
//! WGT_DW_START_REG into bits [0]/[1]/[2] of a single reg3 -- confirmed
//! by direct read of axi_slv.vhd's "Register Map" assignments, and this
//! is exactly what AxisWeightedBuffer.REGISTERS
//! (qick_lib/qick/drivers/readout.py) expects (`start_reg`/`dr_start_reg`
//! combined fields, `enable(avg, buf)` ORs bit0/bit1 into `start_reg`).
//!
//! Three clock domains:
//!
//! - s_axi_aclk  : AXI4-Lite configuration AND weight-programming DMA
//!                 write domain (matches legacy avg_buffer.v's
//!                 write_clk => s_axi_aclk wiring).
//! - s_axis_aclk : capture (write side) datapath.
//! - m_axis_aclk : readout (read side) datapath.
//!
//! Register map (axil_slv, byte-addressed, regwidth = 32) -- matches
//! AxisWeightedBuffer.REGISTERS exactly:
//! 0x00 start_reg       : bit0 = averager enable, bit1 = buffer enable.
//! 0x04 avg_addr_reg    : averager write start address.
//! 0x08 avg_len_reg     : averager sample count (also matched_filter's
//!                        envelope window length).
//! 0x0C dr_start_reg    : bit0 = avg data-reader, bit1 = buf data-reader,
//!                        bit2 = weight data-reader (mutually exclusive
//!                        in practice, decoded independently in hardware).
//! 0x10 avg_dr_addr_reg : averager data-reader start address.
//! 0x14 avg_dr_len_reg  : averager data-reader sample count.
//! 0x18 buf_addr_reg    : buffer write start address.
//! 0x1C buf_len_reg     : buffer sample count.
//! 0x20 buf_dr_addr_reg : buffer data-reader start address.
//! 0x24 buf_dr_len_reg  : buffer data-reader sample count.
//! 0x28 avg_photon_mode_reg : averager mode select, bit 0.
//! 0x2C avg_h_threshold_reg : photon-mode high threshold.
//! 0x30 avg_l_threshold_reg : photon-mode low threshold.
//! 0x34 wgt_dw_addr_reg     : weight-envelope DMA write start address.
//! 0x38 wgt_trunc_reg       : matched_filter output-quantizer right-shift
//!                           . Resets to B
//!                            -- bit-exact with the legacy fixed shift --
//!                            software only needs to touch it to trade
//!                            gain for headroom against a differently
//!                            scaled weight envelope.
//!
//! All *start* fields are LEVELs, not self-clearing.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_weighted_buffer #(
    //! averager memory depth as 2**N_AVG
    parameter int N_AVG = 10,
    //! buffer memory depth as 2**N_BUF
    parameter int N_BUF = 10,
    //! weight envelope memory depth as 2**N_WGT
    parameter int N_WGT = 10,
    //! sample data width in bits
    parameter int B = 16
)(
    // AXI4-Lite slave (configuration + weight-programming write clock).
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

    // AXIS Slave for weight programming.
    input  logic            s1_axis_tvalid,
    output logic            s1_axis_tready,
    input  logic [2*B-1:0]  s1_axis_tdata,

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

    // AXIS Master for raw (filtered) output.
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
    localparam int NUM_REGS   = 15;
    localparam int R_START    = 0;  // bit0=avg, bit1=buf
    localparam int R_AVG_ADDR = 1;
    localparam int R_AVG_LEN  = 2;
    localparam int R_DR_START = 3;  // bit0=avg, bit1=buf, bit2=wgt
    localparam int R_AVG_DR_ADDR     = 4;
    localparam int R_AVG_DR_LEN      = 5;
    localparam int R_BUF_ADDR        = 6;
    localparam int R_BUF_LEN         = 7;
    localparam int R_BUF_DR_ADDR     = 8;
    localparam int R_BUF_DR_LEN      = 9;
    localparam int R_AVG_PHOTON_MODE = 10;
    localparam int R_AVG_H_THRSH     = 11;
    localparam int R_AVG_L_THRSH     = 12;
    localparam int R_WGT_DW_ADDR     = 13;
    localparam int R_WGT_TRUNC       = 14;

    // Reset value per register: every register is 0 except R_WGT_TRUNC,
    // which resets to B so the matched filter's truncation is bit-exact
    // with the legacy fixed shift until software chooses to change it.
    // Built with a function (not an indexed assignment pattern) -- xsim's
    // parser rejects '{default: '0, [idx]: val} on a packed array type.
    function automatic bit [NUM_REGS-1:0][31:0] build_reg_init_val();
        bit [NUM_REGS-1:0][31:0] v;
        v = '{default: '0};
        v[R_WGT_TRUNC] = 32'(B);
        return v;
    endfunction
    localparam bit [NUM_REGS-1:0][31:0] REG_INIT_VAL = build_reg_init_val();

    logic [31:0] slv_regs_o [NUM_REGS];

    // --------------------------------------------------------------------------
    // AXI4-Lite register block. Every register is plain R/W.
    // --------------------------------------------------------------------------
    axil_slv #(
        .AXI_DW       (32),
        .AXI_AW       (6),
        .NUM_REGS     (NUM_REGS),
        .REG_INIT_VAL (REG_INIT_VAL)
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
    // Weighted averager + buffer datapath.
    // --------------------------------------------------------------------------
    weighted_buffer #(
        .N_AVG (N_AVG),
        .N_BUF (N_BUF),
        .N_WGT (N_WGT),
        .B     (B)
    ) weighted_buffer_i (
        .s_axis_aclk    (s_axis_aclk),
        .s_axis_aresetn (s_axis_aresetn),

        .s_axi_aclk    (s_axi_aclk),
        .s_axi_aresetn (s_axi_aresetn),

        .trigger (trigger),

        .s1_axis_tvalid (s1_axis_tvalid),
        .s1_axis_tready (s1_axis_tready),
        .s1_axis_tdata  (s1_axis_tdata),

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

        .avg_start_reg       (slv_regs_o[R_START][0]),
        .avg_addr_reg        (slv_regs_o[R_AVG_ADDR][N_AVG-1:0]),
        .avg_len_reg         (slv_regs_o[R_AVG_LEN]),
        .avg_photon_mode_reg (slv_regs_o[R_AVG_PHOTON_MODE][0]),
        .avg_h_thrsh_reg     (slv_regs_o[R_AVG_H_THRSH][B-1:0]),
        .avg_l_thrsh_reg     (slv_regs_o[R_AVG_L_THRSH][B-1:0]),
        .avg_dr_start_reg    (slv_regs_o[R_DR_START][0]),
        .avg_dr_addr_reg     (slv_regs_o[R_AVG_DR_ADDR][N_AVG-1:0]),
        .avg_dr_len_reg      (slv_regs_o[R_AVG_DR_LEN][N_AVG:0]),

        .buf_start_reg    (slv_regs_o[R_START][1]),
        .buf_addr_reg     (slv_regs_o[R_BUF_ADDR][N_BUF-1:0]),
        .buf_len_reg      (slv_regs_o[R_BUF_LEN][N_BUF-1:0]),
        .buf_dr_start_reg (slv_regs_o[R_DR_START][1]),
        .buf_dr_addr_reg  (slv_regs_o[R_BUF_DR_ADDR][N_BUF-1:0]),
        .buf_dr_len_reg   (slv_regs_o[R_BUF_DR_LEN][N_BUF:0]),

        .wgt_dw_addr_reg  (slv_regs_o[R_WGT_DW_ADDR][N_WGT-1:0]),
        .wgt_dw_start_reg (slv_regs_o[R_DR_START][2]),
        .wgt_trunc_reg    (slv_regs_o[R_WGT_TRUNC][7:0])
    );

endmodule
