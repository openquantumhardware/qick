`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : fir_pfb_ro_1
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    fir_pfb_ro_1.sv
//!
//! @brief   Simulation stand-in for the Xilinx FIR Compiler instance
//!          fir_pfb_ro_1 (xci/fir_pfb_ro_1.xci, coefficients in
//!          fir_pfb_ro_1.coe): FIR 1 of the PFB readouts' polyphase filter.
//!
//! @details
//! Same ports as the IP. fir_pfb_ro_model with this FIR's coefficients, one
//! row per coefficient set (8 sets x 7 taps, copied from the .coe; the legacy
//! IP's fir_1.coe). Synthesis uses the real .xci. Checked against the real
//! core by qick:dsp:fir_pfb_ro_model tests/vendor/run_vendor_check.sh.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module fir_pfb_ro_1 (
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
          -190,   1356,  -2768,  20978,  -3243,    101,      2,
          -129,   1154,  -3547,  22144,  -3726,    353,    -14,
           -79,    903,  -3937,  22742,  -3979,    627,    -41,
           -41,    627,  -3979,  22742,  -3937,    903,    -79,
           -14,    353,  -3726,  22144,  -3547,   1154,   -129,
             2,    101,  -3243,  20978,  -2768,   1356,   -190,
            10,   -116,  -2600,  19303,  -1584,   1480,   -259,
            12,   -288,  -1868,  17203,      4,   1501,   -331
    };

    fir_pfb_ro_model #(.COEFFS(COEFFS)) u_model (.*);

endmodule
