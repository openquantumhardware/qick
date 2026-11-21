`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : fir_pfb_ro_3
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    fir_pfb_ro_3.sv
//!
//! @brief   Simulation stand-in for the Xilinx FIR Compiler instance
//!          fir_pfb_ro_3 (xci/fir_pfb_ro_3.xci, coefficients in
//!          fir_pfb_ro_3.coe): FIR 3 of the PFB readouts' polyphase filter.
//!
//! @details
//! Same ports as the IP. fir_pfb_ro_model with this FIR's coefficients, one
//! row per coefficient set (8 sets x 7 taps, copied from the .coe; the legacy
//! IP's fir_3.coe). Synthesis uses the real .xci. Checked against the real
//! core by qick:dsp:fir_pfb_ro_model tests/vendor/run_vendor_check.sh.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module fir_pfb_ro_3 (
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
          -174,   1312,  -3001,  21320,  -3381,    161,     -1,
          -116,   1095,  -3680,  22349,  -3813,    421,    -20,
           -68,    835,  -3979,  22799,  -3999,    697,    -49,
           -33,    558,  -3941,  22648,  -3874,    969,    -91,
            -9,    288,  -3624,  21904,  -3390,   1211,   -143,
             5,     43,  -3094,  20604,  -2511,   1396,   -206,
            11,   -164,  -2423,  18814,  -1224,   1496,   -277,
            12,   -323,  -1679,  16624,    461,   1487,   -349
    };

    fir_pfb_ro_model #(.COEFFS(COEFFS)) u_model (.*);

endmodule
