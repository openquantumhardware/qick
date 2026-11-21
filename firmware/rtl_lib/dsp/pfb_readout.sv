`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : pfb_readout
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    pfb_readout.sv
//!
//! @brief   The PFB readouts' datapath: a 64-channel polyphase filter bank,
//!          NOUT selectable channels, each down-converted by its own
//!          phase-coherent DDS.
//!
//! @details
//! Faithful port of the legacy pfb_readout + pfb_top + ddsprod_v (openquantumhardware/qick
//! firmware/ip/axis_pfb_readout_v4/src/: NOUT = 8; axis_pfb_readout_v3: the
//! same with NOUT = 4), merged, with array ports:
//!
//! - pfb (N = 64, L = 4) with qout fixed at 5.
//! - Output i: pfb_chsel picks channel id_reg[i] = {word, clock} (channel k
//!   = {k%8, k/8}) once per frame; its sample is registered, down-converted
//!   by pfb_ddsprod with pinc_reg[i]/poff_reg[i], and registered again.
//!   The input valid of every pfb_ddsprod is output 0's selector valid,
//!   registered once; m_axis_tvalid is output 0's pfb_ddsprod valid,
//!   registered once. One sample per frame (N/(2L) clocks) per output.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module pfb_readout #(
    parameter int N    = 64,   //! PFB channels
    parameter int L    = 4,    //! Input lanes
    parameter int NOUT = 8     //! Selectable outputs (v4: 8, v3: 4)
) (
    input  logic            aresetn,
    input  logic            aclk,

    input  logic            s_axis_tvalid,
    input  logic [L*32-1:0] s_axis_tdata,

    output logic            m_axis_tvalid,
    output logic [31:0]     m_axis_tdata [NOUT],

    input  logic [15:0]     id_reg   [NOUT],
    input  logic [31:0]     pinc_reg [NOUT],
    input  logic [31:0]     poff_reg [NOUT]
);

    logic              pfb_tvalid, pfb_tlast;
    logic [2*L*32-1:0] pfb_tdata;

    pfb #(.N(N), .L(L)) u_pfb (
        .aresetn       (aresetn),
        .aclk          (aclk),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tdata  (s_axis_tdata),
        .m_axis_tvalid (pfb_tvalid),
        .m_axis_tlast  (pfb_tlast),
        .m_axis_tdata  (pfb_tdata),
        .qout_reg      (8'd5)
    );

    logic [NOUT-1:0] sel_valid, dp_valid;
    logic [31:0]     sel_data [NOUT];
    logic [31:0]     din_r    [NOUT];
    logic [31:0]     dp_data  [NOUT];
    logic [31:0]     dout_r   [NOUT];
    logic            vin_r, vout_r;

    for (genvar i = 0; i < NOUT; i++) begin : g_out
        pfb_chsel #(.B(32), .L(2*L)) u_chsel (
            .aclk          (aclk),
            .s_axis_tdata  (pfb_tdata),
            .s_axis_tlast  (pfb_tlast),
            .m_axis_tvalid (sel_valid[i]),
            .m_axis_tdata  (sel_data[i]),
            .id_reg        (id_reg[i])
        );

        pfb_ddsprod u_ddsprod (
            .aclk          (aclk),
            .s_axis_tvalid (vin_r),
            .s_axis_tdata  (din_r[i]),
            .m_axis_tvalid (dp_valid[i]),
            .m_axis_tdata  (dp_data[i]),
            .pinc_reg      (pinc_reg[i]),
            .poff_reg      (poff_reg[i])
        );

        always_ff @(posedge aclk) begin
            din_r[i]  <= sel_data[i];
            dout_r[i] <= dp_data[i];
        end
        assign m_axis_tdata[i] = dout_r[i];
    end

    always_ff @(posedge aclk) begin
        vin_r  <= sel_valid[0];
        vout_r <= dp_valid[0];
    end

    assign m_axis_tvalid = vout_r;

endmodule
