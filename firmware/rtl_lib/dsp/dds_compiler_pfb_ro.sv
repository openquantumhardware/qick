///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : dds_compiler_pfb_ro
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    dds_compiler_pfb_ro.sv
//! @brief   dds_compiler_pfb_ro
//! @details
//! Fixed-configuration wrapper around dds_compiler_model matching
//! dds_compiler_pfb_ro.xci (Component_Name-renamed Xilinx IP, the legacy
//! dds_0 of axis_pfb_readout_v3/v4's dds_top).
//! Thin pass-through: fixes the model parameters to this variant's values so
//! parent RTL can instantiate this module by name with zero parameters,
//! identically whether the sim model or the real .xci is elaborated.
//! Values sourced from dds_compiler_pfb_ro.xci: Latency=10, Phase_Width=32,
//! Output_Selection=Sine_and_Cosine (dual output), Negative_Sine=true,
//! Phase_Increment/Phase_offset=Streaming, Resync=true.
//! Model mode PHASE_GATED=1 + RESYNC=1 + NEGATIVE_SINE=1. The consumer
//! (dds_ctrl) sends resync=1 on every word with an absolute phase.
//! See the core's commit for the check against dds_compiler_v6_0 generated
//! from this .xci.
//! @author  QICK Development Team
//! @version 1.0
module dds_compiler_pfb_ro (
   input  logic        aclk,
   input  logic        s_axis_phase_tvalid,
   input  logic [71:0] s_axis_phase_tdata,
   output logic        m_axis_data_tvalid,
   output logic [31:0] m_axis_data_tdata
);

   dds_compiler_model #(
      .LATENCY       (10),
      .PHASE_WIDTH   (32),
      .DUAL_OUTPUT   (1'b1),
      .PHASE_GATED   (1'b1),
      .RESYNC        (1'b1),
      .NEGATIVE_SINE (1'b1)
   ) core_i (
      .aclk                (aclk),
      .s_axis_phase_tvalid (s_axis_phase_tvalid),
      .s_axis_phase_tdata  (s_axis_phase_tdata),
      .m_axis_data_tvalid  (m_axis_data_tvalid),
      .m_axis_data_tdata   (m_axis_data_tdata)
   );

endmodule
