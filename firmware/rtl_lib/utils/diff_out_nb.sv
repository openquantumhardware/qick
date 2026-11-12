///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi National Accelerator Laboratory
//
// Module: diff_out_nd.sv
// Project: QICK
// Description:
// A file containing a module that use the Xilinx
// OBUFDS primitive. The module is parametrizable,
// allowing for easy adjustment of the bus width.
// This module drives a differential output bus from
// a single-ended input bus.
// The bus width is controlled by the `NB` parameter.
//
//Inputs:
// - i_se        single-ended input
//Outputs:
// - o_diff_out_p/n differential outputs
//
//Parameters:
// - NB          bus width
//
//
// Change history: 09/08/25 - Started by @lharnaldi
//
///////////////////////////////////////////////////////////////////////////////
module diff_out_nb#(
  parameter integer NB = 16 // The width of the differential bus.
)(
  input  logic [NB-1:0] i_se,     // Single-ended input
  output logic [NB-1:0] o_diff_p, // Positive differential output
  output logic [NB-1:0] o_diff_n  // Negative differential output
);

  // Use a `generate` block to instantiate the OBUFDS primitives for each bit.
  generate
    for (genvar i = 0; i < NB; i = i + 1) begin : g_obufds_gen
      OBUFDS obuf_ds_inst (
        .O  (o_diff_p[i]),
        .OB (o_diff_n[i]),
        .I  (i_se[i]    )
      );
    end
  endgenerate

endmodule

