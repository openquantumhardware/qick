`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : qick_vec2bit
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    qick_vec2bit.sv
//!
//! @brief   Splits a vector into individual single-bit outputs dout0..dout15.
//!
//! @details
//! Faithful port of the legacy QICK IP (openquantumhardware/qick firmware/ip/qick_vec2bit/
//! src/qick_vec2bit.v, QICK:QICK:qick_vec2bit:1.0): dout<i> = din[i]. Used to
//! fan a tProc data port out to separate trigger pins. The packaged IP shows
//! dout<i> only for i < OUT_QTY (OUT_QTY has no effect inside the RTL).
//!
//! qick_lib relies on the port names (dout<i> is output bit i when tracing
//! trigger pins), so they are kept as in the legacy IP.
//!
//! The legacy RTL read din[15] whatever IN_DW was (X in simulation for
//! IN_DW < 16); here outputs with i >= IN_DW are 0.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module qick_vec2bit #(
    parameter int IN_DW   = 16,  //! Input width (bits)
    parameter int OUT_QTY = 4    //! Outputs shown in the packaged IP (1..16); not used by the RTL
) (
    input  logic [IN_DW-1:0] din,
    output logic             dout0,
    output logic             dout1,
    output logic             dout2,
    output logic             dout3,
    output logic             dout4,
    output logic             dout5,
    output logic             dout6,
    output logic             dout7,
    output logic             dout8,
    output logic             dout9,
    output logic             dout10,
    output logic             dout11,
    output logic             dout12,
    output logic             dout13,
    output logic             dout14,
    output logic             dout15
);

    logic [15:0] bits;

    always_comb begin
        bits = '0;
        for (int i = 0; i < 16; i++)
            if (i < IN_DW) bits[i] = din[i];
    end

    assign {dout15, dout14, dout13, dout12, dout11, dout10, dout9, dout8,
            dout7,  dout6,  dout5,  dout4,  dout3,  dout2,  dout1, dout0} = bits;

endmodule
