`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : fir_pfb_ro_2
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    fir_pfb_ro_2.sv
//!
//! @brief   Simulation stand-in for the Xilinx FIR Compiler instance
//!          fir_pfb_ro_2 (xci/fir_pfb_ro_2.xci, coefficients in
//!          fir_pfb_ro_2.coe): FIR 2 of the PFB readouts' polyphase filter.
//!
//! @details
//! Same ports as the IP. fir_pfb_ro_model with this FIR's coefficients, one
//! row per coefficient set (8 sets x 7 taps, copied from the .coe; the legacy
//! IP's fir_2.coe). Synthesis uses the real .xci. Checked against the real
//! core by qick:dsp:fir_pfb_ro_model tests/vendor/run_vendor_check.sh.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module fir_pfb_ro_2 (
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
          -432,   -928,  14140,   2508,   1349,   -417,      0,
          -492,   -225,  11481,   4859,   1070,   -471,      0,
          -510,    387,   8770,   7431,    649,   -504,      0,
          -491,    877,   6123,  10125,     95,   -506,      0,
          -446,   1228,   3650,  12825,   -567,   -468,      0,
          -384,   1435,   1442,  15411,  -1301,   -383,     90,
          -313,   1507,   -430,  17763,  -2056,   -249,     12,
          -241,   1458,  -1918,  19765,  -2772,    -66,      9
    };

    fir_pfb_ro_model #(.COEFFS(COEFFS)) u_model (.*);

endmodule
