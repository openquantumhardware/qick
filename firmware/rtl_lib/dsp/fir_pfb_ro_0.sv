`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : fir_pfb_ro_0
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    fir_pfb_ro_0.sv
//!
//! @brief   Simulation stand-in for the Xilinx FIR Compiler instance
//!          fir_pfb_ro_0 (xci/fir_pfb_ro_0.xci, coefficients in
//!          fir_pfb_ro_0.coe): FIR 0 of the PFB readouts' polyphase filter.
//!
//! @details
//! Same ports as the IP. fir_pfb_ro_model with this FIR's coefficients, one
//! row per coefficient set (8 sets x 7 taps, copied from the .coe; the legacy
//! IP's fir_0.coe). Synthesis uses the real .xci. Checked against the real
//! core by qick:dsp:fir_pfb_ro_model tests/vendor/run_vendor_check.sh.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module fir_pfb_ro_0 (
    input  logic        aclk,
    input  logic        s_axis_data_tvalid,
    output logic        s_axis_data_tready,
    input  logic        s_axis_data_tlast,
    input  logic [31:0] s_axis_data_tdata,
    input  logic        s_axis_config_tvalid,
    output logic        s_axis_config_tready,
    input  logic        s_axis_config_tlast,
    input  logic [7:0]  s_axis_config_tdata,
    output logic        m_axis_data_tvalid,
    output logic        m_axis_data_tlast,
    output logic [31:0] m_axis_data_tdata,
    output logic        event_s_data_tlast_missing,
    output logic        event_s_data_tlast_unexpected,
    output logic        event_s_config_tlast_missing,
    output logic        event_s_config_tlast_unexpected
);

    localparam int signed COEFFS [56] = '{
          -409,  -1113,  14782,   1965,   1397,   -401,      0,
          -481,   -393,  12156,   4247,   1154,   -459,      0,
          -509,    245,   9446,   6773,    767,   -499,      0,
          -499,    767,   6773,   9446,    245,   -509,      0,
          -459,   1154,   4247,  12156,   -393,   -481,      0,
          -401,   1397,   1965,  14782,  -1113,   -409,      0,
          -331,   1501,      4,  17203,  -1868,   -288,     12,
          -259,   1480,  -1584,  19303,  -2600,   -116,     10
    };

    fir_pfb_ro_model #(.COEFFS(COEFFS)) u_model (.*);

endmodule
