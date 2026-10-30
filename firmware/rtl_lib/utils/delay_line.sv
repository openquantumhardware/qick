///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : delay_line
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    delay_line.sv
//!
//! @brief   delay_line
//!
//! @details
//!
//! Parameterizable M-bit, N-stage delay line for latency matching.
//!
//! Delays an M-bit data word by EXACTLY N clock cycles. Structure: stage 0 is
//! the combinational input, followed by N registers in series; o_data is the
//! N-th register. Therefore:
//!
//!   o_data(t) = i_data(t - N)      (latency = N, for N >= 1)
//!
//! LATENCY BUDGETING NOTE: when balancing paths, count this block as exactly N.
//! A value applied at clock edge k appears at o_data at edge k+N. Verified by
//! direct measurement in the testbench (tc_measure_latency).
//!
//! Used to align signals travelling through datapaths of different pipeline
//! depths within the SAME clock domain. This is NOT a CDC synchronizer — for
//! clock domain crossing use cdc_gray_sync / cdc_bit_sync (ASYNC_REG).
//!
//! Requires N >= 1. Synchronous active-low reset clears all stages.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module delay_line #(
   //! Number of delay stages / latency in cycles (minimum 1).
   parameter int N = 2,
   //! Data width in bits.
   parameter int M = 8
)(
   input  logic         i_clk  ,
   input  logic         i_rstn ,
   input  logic [M-1:0] i_data ,
   output logic [M-1:0] o_data
);

   logic [M-1:0] d_r [N];
   logic [M-1:0] d_n [N];

   always_ff @(posedge i_clk) begin
      if (!i_rstn)
         d_r <= '{default:'0};
      else
         d_r <= d_n;
   end

   always_comb begin
      d_n[0] = i_data;
      for (int i = 1; i < N; i++)
         d_n[i] = d_r[i-1];
   end

   assign o_data = d_r[N-1];

endmodule

