///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : dds_phasegen_sincos_ow16_lat8
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    dds_phasegen_sincos_ow16_lat8.sv
//!
//! @brief   dds_phasegen_sincos_ow16_lat8
//!
//! @details
//!
//!
//! Fixed-configuration wrapper around dds_compiler_model matching
//! dds_phasegen_sincos_ow16_lat8.xci (Component_Name-renamed Xilinx IP,
//! grupo "signal_gen": axis_sg_int4_v2, axis_signal_gen_v5,
//! axis_signal_gen_v6).
//!
//! Thin pass-through: fixes LATENCY/PHASE_WIDTH/DUAL_OUTPUT to this
//! variant's values so parent RTL can instantiate this module by name
//! with zero parameters, identically whether the sim model or the real
//! .xci is elaborated (FuseSoC target picks the fileset; the module name
//! stays consistent either way).
//!
//! Values sourced from dds_phasegen_sincos_ow16_lat8.xci: Latency=8,
//! Phase_Width=32, Output_Selection=Sine_and_Cosine (dual output).
//!
//! Phase_Increment=Streaming with no TREADY: the real IP's pipeline moves only
//! on s_axis_phase_tvalid, so m_axis_data_tvalid comes out in the SAME cycle as
//! the input valid (0 clocks, not 8) and carries the output of the transaction
//! 8 valids earlier. PHASE_GATED=1 models exactly that (checked against the
//! dds_compiler_v6_0_28 xsim model). A caller that feeds it sparse valids
//! (kidsim, gated by punct) sees 0 clocks of latency and 8 transactions of
//! delay; the old free-running model hid that.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module dds_phasegen_sincos_ow16_lat8 (
   input  logic        aclk,
   input  logic        s_axis_phase_tvalid,
   input  logic [31:0] s_axis_phase_tdata, //! 32b (matches .xci size_left=32, size_right=0)
   output logic        m_axis_data_tvalid,
   output logic [31:0] m_axis_data_tdata
);

   dds_compiler_model #(
      .LATENCY     (8),
      .PHASE_WIDTH (16),
      .DUAL_OUTPUT (1'b1),
      .STREAMING   (1'b1), //! Streaming pinc (accumulate internally); 0 = phase pre-accumulated upstream (signal_gen)
      .PHASE_GATED (1'b1)  //! pipeline moves on the input valid; output valid = input valid
   ) core_i (
      .aclk                (aclk),
      .s_axis_phase_tvalid (s_axis_phase_tvalid),
      .s_axis_phase_tdata  (s_axis_phase_tdata),
      .m_axis_data_tvalid  (m_axis_data_tvalid),
      .m_axis_data_tdata   (m_axis_data_tdata)
   );

endmodule
