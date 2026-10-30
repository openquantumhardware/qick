///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : cdc_gray_sync
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    cdc_gray_sync.sv
//!
//! @brief   N-stage, M-bit vector synchronizer (per-bit independent).
//!
//! @details
//! Each bit of the M-bit vector is synchronized through its own N-stage
//! flip-flop chain, independently of the others -- there is no gray decode
//! logic here, "gray" in the name refers to the intended use case, not a
//! transform performed by this module.
//!
//! Safe for:
//!  - a genuinely gray-coded vector (by construction at most one bit changes
//!    per source-clock edge, so a torn/inconsistent sample can't happen), or
//!  - M independent, unrelated single-bit signals bundled into one vector
//!    purely for port convenience (each bit has no coherence requirement
//!    with the others, so independent per-bit sync is exactly correct).
//!
//! NOT safe for: an arbitrary coherent multi-bit binary value (e.g. a raw
//! counter, address or data word) where more than one bit can change at
//! once -- different bits can then land on opposite sides of the source
//! transition and be sampled torn. Use `cdc_handshake` for that case.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module cdc_gray_sync#(
    parameter int N = 2,  // number of stages
    parameter int M = 8   // data width
  )(
    input logic          i_clk,
    input logic          i_rstn,
    input logic  [M-1:0] i_d,
    output logic [M-1:0] o_d
  );

  // ASYNC_REG attribute for proper CDC placement (Vivado)
  (* ASYNC_REG = "TRUE" *) logic [M-1:0] d_r [N];
  logic [M-1:0] d_n [N];

  always_ff @(posedge i_clk)
  begin
    if (!i_rstn)
    begin
      d_r <= '{default:0};
    end
    else
    begin
      d_r <= d_n;
    end
  end

  always_comb
  begin
    d_n[0] = i_d;
    for (int i = 1; i < N; i++)
    begin
      d_n[i] = d_r[i-1];
    end
  end

  assign o_d = d_r[N-1];

endmodule
