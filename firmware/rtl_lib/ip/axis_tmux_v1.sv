`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_tmux_v1
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_tmux_v1.sv
//!
//! @brief   Routes each input word to one of N outputs, chosen by the word's
//!          own top byte (one tProc wave port shared by several
//!          tProc-configured readouts).
//!
//! @details
//! Faithful port of the legacy QICK IP (openquantumhardware/qick firmware/ip/axis_tmux_v1/
//! src/{axis_tmux_v1.sv,tmux.sv}, QICK:QICK:axis_tmux_v1:1.0), with the
//! wrapper and tmux merged into one module:
//!
//! - s_axis_tdata/tvalid go through two registers (latency 2 clocks).
//! - The selection is sel = tdata[B-1 -: 8][2:0], taken from the delayed
//!   word: the word is presented on every output, and only m<sel>_axis_tvalid
//!   rises. A sel >= N (or top-byte bits above bit 2) selects no output.
//! - The selection byte is not stripped: consumers see the full word.
//! - s_axis_tready is constant 1; the outputs have no tready.
//! - aresetn (synchronous, active low) clears both stages.
//!
//! Outputs with index >= N are not part of the IP (the packaged IP hides
//! them). The legacy RTL read past the end of its N-entry arrays for them
//! (X in simulation); here they are driven with tvalid = 0.
//!
//! Defaults N = 2, B = 16 are those of the legacy packaged IP (its RTL said
//! N = 8); the standard BDs set B = 168 and N = 3 or 4.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_tmux_v1 #(
    parameter int N = 2,   //! Number of outputs, 1..8
    parameter int B = 16   //! Data width (bits), >= 8
) (
    input  logic         aresetn,
    input  logic         aclk,

    output logic         s_axis_tready,
    input  logic         s_axis_tvalid,
    input  logic [B-1:0] s_axis_tdata,

    output logic         m0_axis_tvalid,
    output logic [B-1:0] m0_axis_tdata,
    output logic         m1_axis_tvalid,
    output logic [B-1:0] m1_axis_tdata,
    output logic         m2_axis_tvalid,
    output logic [B-1:0] m2_axis_tdata,
    output logic         m3_axis_tvalid,
    output logic [B-1:0] m3_axis_tdata,
    output logic         m4_axis_tvalid,
    output logic [B-1:0] m4_axis_tdata,
    output logic         m5_axis_tvalid,
    output logic [B-1:0] m5_axis_tdata,
    output logic         m6_axis_tvalid,
    output logic [B-1:0] m6_axis_tdata,
    output logic         m7_axis_tvalid,
    output logic [B-1:0] m7_axis_tdata
);

    logic         valid_r1, valid_r2;
    logic [B-1:0] din_r1, din_r2;
    logic [2:0]   sel;
    logic [7:0]   valid_v;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            valid_r1 <= 1'b0;
            valid_r2 <= 1'b0;
            din_r1   <= '0;
            din_r2   <= '0;
        end else begin
            valid_r1 <= s_axis_tvalid;
            valid_r2 <= valid_r1;
            din_r1   <= s_axis_tdata;
            din_r2   <= din_r1;
        end
    end

    // Selection: low 3 bits of the top byte of the delayed word.
    assign sel = din_r2[B-8 +: 3];

    always_comb begin
        for (int i = 0; i < 8; i++)
            valid_v[i] = (i < N) && (sel == 3'(i)) && valid_r2;
    end

    assign m0_axis_tvalid = valid_v[0];  assign m0_axis_tdata = din_r2;
    assign m1_axis_tvalid = valid_v[1];  assign m1_axis_tdata = din_r2;
    assign m2_axis_tvalid = valid_v[2];  assign m2_axis_tdata = din_r2;
    assign m3_axis_tvalid = valid_v[3];  assign m3_axis_tdata = din_r2;
    assign m4_axis_tvalid = valid_v[4];  assign m4_axis_tdata = din_r2;
    assign m5_axis_tvalid = valid_v[5];  assign m5_axis_tdata = din_r2;
    assign m6_axis_tvalid = valid_v[6];  assign m6_axis_tdata = din_r2;
    assign m7_axis_tvalid = valid_v[7];  assign m7_axis_tdata = din_r2;

    assign s_axis_tready = 1'b1;

endmodule
