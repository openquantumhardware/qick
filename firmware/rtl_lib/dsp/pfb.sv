`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : pfb
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    pfb.sv
//!
//! @brief   The PFB readouts' polyphase filter bank: N channels, 50 %
//!          overlap, decimation N/2, from L samples per clock.
//!
//! @details
//! Faithful port of the legacy pfb (openquantumhardware/qick firmware/ip/
//! axis_pfb_readout_v4/src/pfb/pfb.sv, identical in v3), structural:
//!
//!   s_axis (L x {Q,I}) -> pfb_firs -> pfb_switch -> ssrfft_8x64_sync
//!                      -> pimod_pfb -> m_axis (2L x {Q,I} per clock)
//!
//! The FFT runs with scale 0 and slices its 27-bit result from bit qout_reg
//! (QOUT_REG in the legacy); pimod's tready is tied high. A frame is N/(2L)
//! clocks carrying the N channels, 2L per clock, tlast on its last clock.
//! Only N = 64, L = 4 work (the FIRs and the FFT are built for them).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module pfb #(
    parameter int N = 64,   //! Channels
    parameter int L = 4     //! Input lanes
) (
    input  logic              aresetn,
    input  logic              aclk,

    input  logic              s_axis_tvalid,
    input  logic [L*32-1:0]   s_axis_tdata,

    output logic              m_axis_tvalid,
    output logic              m_axis_tlast,
    output logic [2*L*32-1:0] m_axis_tdata,

    input  logic [7:0]        qout_reg
);

    logic              firs_tvalid, firs_tlast;
    logic [2*L*32-1:0] firs_tdata;
    logic              switch_tvalid, switch_tlast;
    logic [2*L*32-1:0] switch_tdata;
    logic              fft_tvalid, fft_tlast;
    logic [2*L*32-1:0] fft_tdata;

    pfb_firs #(.N(N), .L(L)) u_firs (
        .aresetn       (aresetn),
        .aclk          (aclk),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tdata  (s_axis_tdata),
        .m_axis_tvalid (firs_tvalid),
        .m_axis_tlast  (firs_tlast),
        .m_axis_tdata  (firs_tdata)
    );

    pfb_switch #(.B(32), .L(L), .N(N)) u_switch (
        .aresetn       (aresetn),
        .aclk          (aclk),
        .s_axis_tvalid (firs_tvalid),
        .s_axis_tlast  (firs_tlast),
        .s_axis_tdata  (firs_tdata),
        .m_axis_tvalid (switch_tvalid),
        .m_axis_tlast  (switch_tlast),
        .m_axis_tdata  (switch_tdata)
    );

    ssrfft_8x64_sync #(.NFFT(N), .SSR(2*L), .B(16)) u_fft (
        .aresetn       (aresetn),
        .aclk          (aclk),
        .s_axis_tdata  (switch_tdata),
        .s_axis_tlast  (switch_tlast),
        .s_axis_tvalid (switch_tvalid),
        .m_axis_tdata  (fft_tdata),
        .m_axis_tlast  (fft_tlast),
        .m_axis_tvalid (fft_tvalid),
        .scale_reg     (32'd0),
        .qout_reg      (32'(qout_reg))
    );

    pimod_pfb #(.NFFT(N), .B(16), .L(2*L)) u_pimod (
        .aresetn       (aresetn),
        .aclk          (aclk),
        .s_axis_tdata  (fft_tdata),
        .s_axis_tlast  (fft_tlast),
        .s_axis_tvalid (fft_tvalid),
        .s_axis_tready (),
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tlast  (m_axis_tlast),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tready (1'b1)
    );

endmodule
