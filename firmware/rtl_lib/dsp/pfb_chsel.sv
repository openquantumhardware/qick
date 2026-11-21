`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : pfb_chsel
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    pfb_chsel.sv
//!
//! @brief   Picks one PFB channel out of every frame: one output sample per
//!          frame.
//!
//! @details
//! Faithful port of the legacy pfb_chsel (openquantumhardware/qick firmware/ip/
//! axis_pfb_readout_v4/src/pfb/pfb_chsel.sv, identical in v3). A frame is
//! the clocks from one s_axis_tlast to the next, L words of B bits per clock:
//!
//! - id_reg[7:0] (packet) is the clock within the frame, counted from 0 on
//!   the clock after tlast; id_reg[15:8] (index) is the word within that
//!   clock. Both are registered once before use.
//! - The frame word of clock `packet` is captured; on the clock after tlast
//!   word `index` of it is registered to m_axis_tdata, and m_axis_tvalid is
//!   high one clock later, for one clock per frame.
//! - An index >= L reads past the captured word (X in simulation), as in the
//!   legacy block. No reset.
//!
//! PFB channel k (frame position clock k/8, word k%8 at N = 64, L = 8) is
//! id_reg = {k % 8, k / 8}.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module pfb_chsel #(
    parameter int B = 32,   //! Word width
    parameter int L = 8     //! Words per clock
) (
    input  logic           aclk,
    input  logic [L*B-1:0] s_axis_tdata,
    input  logic           s_axis_tlast,
    output logic           m_axis_tvalid,
    output logic [B-1:0]   m_axis_tdata,
    input  logic [15:0]    id_reg
);

    logic [7:0]     cnt = '0;
    logic [7:0]     packet_reg, index_reg;
    logic [L*B-1:0] tdata_r;
    logic [B-1:0]   data_mux_r;
    logic           tlast_r1, tlast_r2;

    always_ff @(posedge aclk) begin
        cnt        <= s_axis_tlast ? '0 : cnt + 1'b1;
        packet_reg <= id_reg[7:0];
        index_reg  <= id_reg[15:8];
        if (cnt == packet_reg) tdata_r <= s_axis_tdata;
        if (tlast_r1)          data_mux_r <= tdata_r[index_reg*B +: B];
        tlast_r1   <= s_axis_tlast;
        tlast_r2   <= tlast_r1;
    end

    assign m_axis_tvalid = tlast_r2;
    assign m_axis_tdata  = data_mux_r;

endmodule
