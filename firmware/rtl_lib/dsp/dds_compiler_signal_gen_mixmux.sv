///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : dds_compiler_signal_gen_mixmux
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    dds_compiler_signal_gen_mixmux.sv
//!
//! @brief   dds_compiler_signal_gen_mixmux
//!
//! @details
//!
//!
//! Fixed-configuration wrapper around dds_compiler_model matching
//! dds_compiler_signal_gen_mixmux.xci (Component_Name-renamed Xilinx IP).
//! Used by: axis_sg_mixmux8_v1, axis_sg_mux4_v2.
//!
//! Thin pass-through: fixes LATENCY/PHASE_WIDTH/DUAL_OUTPUT to this
//! variant's values so parent RTL can instantiate this module by name
//! with zero parameters.
//!
//! Values sourced from dds_compiler_signal_gen_mixmux.xci: Latency=10,
//! Phase_Width=32, Output_Selection=Sine_and_Cosine (32-bit packed output).
//!
//! Model mode PHASE_GATED=1 + RESYNC=1: the real core accumulates pinc per input
//! transaction, restarting on the tdata resync bit, and outputs sin/cos(acc + poff).
//! Checked 2026-09-24 against dds_compiler_v6_0_28 generated from this .xci, with
//! resync every cycle, resync only at segment starts, and gapped valids: <= 19
//! counts error, identical valid timing. The old free-running default was wrong
//! for every QICK consumer (errors ~full scale).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module dds_compiler_signal_gen_mixmux (
   input  logic        aclk,
   input  logic        s_axis_phase_tvalid,
   input  logic [71:0] s_axis_phase_tdata,
   output logic        m_axis_data_tvalid,
   output logic [31:0] m_axis_data_tdata
);

   dds_compiler_model #(
      .LATENCY     (10),
      .PHASE_WIDTH (32),
      .DUAL_OUTPUT (1'b1),
      .PHASE_GATED (1'b1),
      .RESYNC      (1'b1)
   ) core_i (
      .aclk                (aclk),
      .s_axis_phase_tvalid (s_axis_phase_tvalid),
      .s_axis_phase_tdata  (s_axis_phase_tdata),
      .m_axis_data_tvalid  (m_axis_data_tvalid),
      .m_axis_data_tdata   (m_axis_data_tdata)
   );

endmodule
