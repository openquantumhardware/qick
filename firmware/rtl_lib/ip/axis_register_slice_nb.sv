`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_register_slice_nb
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_register_slice_nb.sv
//!
//! @brief   N-stage register pipeline for an AXI4-Stream that never stalls
//!          ("nb": no backpressure).
//!
//! @details
//! Faithful port of the legacy QICK IP (openquantumhardware/qick firmware/ip/
//! axis_register_slice_nb/src/axis_register_slice_nb.vhd, QICK:QICK:
//! axis_register_slice_nb:1.0). Same ports, parameters and behaviour:
//!
//! - s_axis_tdata is shifted through N registers on every aclk edge;
//!   m_axis_tdata is the last stage (latency N clocks).
//! - The handshake is not implemented: s_axis_tready and m_axis_tvalid are
//!   constant 1, s_axis_tvalid and m_axis_tready are ignored. This is only
//!   correct on streams that never stall, such as RFDC ADC/DAC streams. It
//!   exists instead of the Xilinx axis_register_slice because it is plain
//!   flip-flops (no skid buffer, no TREADY fan-out), which is what closed
//!   timing between the RFDC ADC and the readouts at 552.96 MHz.
//! - The stages are kept as flip-flops (shreg_extract = "no"); see shift_r.
//! - aresetn (synchronous, active low) clears every stage to 0.
//!
//! The legacy VHDL needs N >= 2; this port also accepts N = 1.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_register_slice_nb #(
    parameter int B = 16,  //! Data width (bits)
    parameter int N = 4    //! Number of register stages (latency in clocks), >= 1
) (
    input  logic         aclk,
    input  logic         aresetn,

    input  logic [B-1:0] s_axis_tdata,
    input  logic         s_axis_tvalid,  // verilog_lint: waive unused (no handshake, see header)
    output logic         s_axis_tready,

    output logic [B-1:0] m_axis_tdata,
    output logic         m_axis_tvalid,
    input  logic         m_axis_tready   // verilog_lint: waive unused (no handshake, see header)
);

    //! Flip-flops, never SRLs. Without this Vivado packs the stages into SRL16Es (it moves the synchronous reset
    //! to a separate flop), which are slow to set up (~0.1 ns more than a flop at 614.4 MHz on the ZCU216) and
    //! cannot be spread across the die. Both defeat the point of this slice. Seen in 216/tpv2_demo, 2026-09-25:
    //! mux8 -> slice paths at -62 ps, all ending on shift_r_reg[3][*]_srl4.
    (* shreg_extract = "no" *) logic [B-1:0] shift_r [N];

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            for (int i = 0; i < N; i++) shift_r[i] <= '0;
        end else begin
            shift_r[0] <= s_axis_tdata;
            for (int i = 1; i < N; i++) shift_r[i] <= shift_r[i-1];
        end
    end

    assign s_axis_tready = 1'b1;
    assign m_axis_tdata  = shift_r[N-1];
    assign m_axis_tvalid = 1'b1;

endmodule
