`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_resampler_2x1_v1
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_resampler_2x1_v1.sv
//!
//! @brief   Halves the number of lanes of a stream that is valid every other
//!          clock: one N-lane word in, two N/2-lane words out.
//!
//! @details
//! Faithful port of the legacy QICK IP (openquantumhardware/qick firmware/ip/
//! axis_resampler_2x1_v1/src/axis_resampler_2x1_v1.sv,
//! QICK:QICK:axis_resampler_2x1_v1:1.0), same ports, parameters and timing:
//!
//! - Input words must be valid at most every other clock (the legacy comment:
//!   "a faster input data rate will make the block fail"). There is no check.
//! - For an input word sampled (tvalid = 1) at edge k, the output shows its
//!   low half after edge k+2 and its high half after edge k+3, each with
//!   m_axis_tvalid = 1.
//! - s_axis_tready is constant 1; m_axis_tready is ignored.
//! - aresetn (synchronous, active low) clears the pipeline.
//!
//! In 216/tpv2_demo it sits between the RFDC ADC and axis_readout_v3's
//! s1_axis.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_resampler_2x1_v1 #(
    parameter int B = 16,  //! Bits per lane
    parameter int N = 8    //! Input lanes (even)
) (
    input  logic             aclk,
    input  logic             aresetn,

    output logic             s_axis_tready,
    input  logic             s_axis_tvalid,
    input  logic [N*B-1:0]   s_axis_tdata,

    input  logic             m_axis_tready,  // verilog_lint: waive unused (no backpressure, see header)
    output logic             m_axis_tvalid,
    output logic [N/2*B-1:0] m_axis_tdata
);

    logic [N*B-1:0]   din_r1, din_r2;
    logic [N/2*B-1:0] d_mux, d_mux_r1;
    logic             valid_r1, valid_r2, valid_r3, valid_r4;

    // Low half while the word's valid is in stage 2, high half one clock later.
    assign d_mux = valid_r2 ? din_r2[0 +: N/2*B] : din_r2[N/2*B +: N/2*B];

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            din_r1   <= '0;
            din_r2   <= '0;
            d_mux_r1 <= '0;
            valid_r1 <= 1'b0;
            valid_r2 <= 1'b0;
            valid_r3 <= 1'b0;
            valid_r4 <= 1'b0;
        end else begin
            din_r1   <= s_axis_tdata;
            if (valid_r1) din_r2 <= din_r1;
            d_mux_r1 <= d_mux;
            valid_r1 <= s_axis_tvalid;
            valid_r2 <= valid_r1;
            valid_r3 <= valid_r2;
            valid_r4 <= valid_r3;
        end
    end

    assign s_axis_tready = 1'b1;
    assign m_axis_tvalid = valid_r3 || valid_r4;
    assign m_axis_tdata  = d_mux_r1;

endmodule
