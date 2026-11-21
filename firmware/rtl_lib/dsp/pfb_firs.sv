`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : pfb_firs
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    pfb_firs.sv
//!
//! @brief   Polyphase filter stage of the PFB readouts: eight FIRs over the
//!          L input lanes and their copies delayed by one FIR vector, with the
//!          control that configures and frames them.
//!
//! @details
//! Faithful port of the legacy firs (openquantumhardware/qick firmware/ip/
//! axis_pfb_readout_v4/src/pfb/firs.sv, identical in v3):
//!
//! - Input: L lanes of {Q, I} (32 bits each). Lane i feeds FIR 2i+1 as is and
//!   FIR 2i delayed by N/(2L) accepted words (zn_nb), which is the time
//!   advance of the second half of the filter bank. The FIRs' tvalid is
//!   s_axis_tvalid registered once, while their data is the current word
//!   (as in the legacy block; with the continuous ADC source this is the
//!   same stream one clock later).
//! - Output: m_axis_tdata[32k +: 32] is FIR k (k = 0..2L-1); tvalid and tlast
//!   are FIR 0's.
//! - pfb_ctrl sends the FIRs their coefficient sets after reset and drives
//!   their tlast (fr_out), re-aligning on FIR 0's missing-tlast event.
//! - The FIRs and the delay line have no reset (neither had the legacy
//!   ones); aresetn only resets pfb_ctrl.
//!
//! The FIRs are fir_pfb_ro_0..7, so L = 4 (and N/(2L) = 8 FIR channels, N =
//! 64) are the only working values; N and L keep the legacy interface.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module pfb_firs #(
    parameter int N = 64,   //! Number of PFB channels
    parameter int L = 4     //! Input lanes (samples per clock)
) (
    input  logic              aresetn,
    input  logic              aclk,

    input  logic              s_axis_tvalid,
    input  logic [L*32-1:0]   s_axis_tdata,

    output logic              m_axis_tvalid,
    output logic              m_axis_tlast,
    output logic [2*L*32-1:0] m_axis_tdata
);

    localparam int NCH = N / (2 * L);   // channels per FIR

    logic            valid_r = 1'b0;
    logic [L*32-1:0] data_d;
    logic [31:0]     fir_din  [2*L];
    logic [31:0]     fir_dout [2*L];

    logic            cfg_tvalid, cfg_tready, cfg_tlast;
    logic [7:0]      cfg_tdata;
    logic            fr_sync, fr_out;

    always_ff @(posedge aclk) valid_r <= s_axis_tvalid;

    for (genvar i = 0; i < L; i++) begin : g_lane
        assign fir_din[2*i]     = data_d[i*32 +: 32];
        assign fir_din[2*i + 1] = s_axis_tdata[i*32 +: 32];
    end
    for (genvar k = 0; k < 2*L; k++) begin : g_out
        assign m_axis_tdata[k*32 +: 32] = fir_dout[k];
    end

    pfb_ctrl #(.N(NCH)) u_ctrl (
        .aresetn              (aresetn),
        .aclk                 (aclk),
        .m_axis_config_tvalid (cfg_tvalid),
        .m_axis_config_tready (cfg_tready),
        .m_axis_config_tlast  (cfg_tlast),
        .m_axis_config_tdata  (cfg_tdata),
        .cfg_en               (1'b1),
        .tready               (m_axis_tvalid),
        .tvalid               (m_axis_tvalid),
        .fr_sync              (fr_sync),
        .fr_out               (fr_out)
    );

    // One FIR vector of delay; no reset (as the legacy zn_nb).
    zn_nb #(.B(L*32), .N(NCH)) u_delay (
        .aclk          (aclk),
        .aresetn       (1'b1),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tdata  (s_axis_tdata),
        .m_axis_tvalid (),
        .m_axis_tdata  (data_d)
    );

`define PFB_FIRS_FIR(K, CFG_READY, M_VALID, M_LAST, EV_MISS) \
    fir_pfb_ro_``K u_fir``K ( \
        .aclk                            (aclk), \
        .s_axis_data_tvalid              (valid_r), \
        .s_axis_data_tready              (), \
        .s_axis_data_tlast               (fr_out), \
        .s_axis_data_tdata               (fir_din[K]), \
        .s_axis_config_tvalid            (cfg_tvalid), \
        .s_axis_config_tready            (CFG_READY), \
        .s_axis_config_tlast             (cfg_tlast), \
        .s_axis_config_tdata             (cfg_tdata), \
        .m_axis_data_tvalid              (M_VALID), \
        .m_axis_data_tlast               (M_LAST), \
        .m_axis_data_tdata               (fir_dout[K]), \
        .event_s_data_tlast_missing      (EV_MISS), \
        .event_s_data_tlast_unexpected   (), \
        .event_s_config_tlast_missing    (), \
        .event_s_config_tlast_unexpected () \
    );

    `PFB_FIRS_FIR(0, cfg_tready, m_axis_tvalid, m_axis_tlast, fr_sync)
    `PFB_FIRS_FIR(1, , , , )
    `PFB_FIRS_FIR(2, , , , )
    `PFB_FIRS_FIR(3, , , , )
    `PFB_FIRS_FIR(4, , , , )
    `PFB_FIRS_FIR(5, , , , )
    `PFB_FIRS_FIR(6, , , , )
    `PFB_FIRS_FIR(7, , , , )
`undef PFB_FIRS_FIR

endmodule
