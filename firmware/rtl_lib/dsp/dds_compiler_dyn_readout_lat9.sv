///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : dds_compiler_dyn_readout_lat9
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    dds_compiler_dyn_readout_lat9.sv
//!
//! @brief   dds_compiler_dyn_readout_lat9
//!
//! @details
//!
//!
//! Fixed-configuration wrapper around dds_compiler_model matching
//! dds_compiler_dyn_readout_lat9.xci: dds_compiler_dyn_readout.xci with
//! Latency 9 instead of 8, every other parameter identical.
//! Used by: down_conversion_dynro (axis_dyn_readout_v1).
//!
//! Why a latency-9 variant: at Latency 8 the phase
//! accumulator DSP48E2 of the core has CREG=0 and OPMODEREG=0, so the path
//! from the fabric register that drives s_axis_phase_tdata goes through a
//! LUT into the DSP C input and the ALU to the P register in one clock. At
//! the 4x2 ADC x2 clock (552.96 MHz) those paths were 927 of the 2356
//! failing endpoints of 4x2/tpv2_std. From Latency 9 the core sets CREG=1
//! and OPMODEREG=1 (out-of-context synthesis, Vivado 2023.1, xczu48dr).
//!
//! The real core at Latency 9 gives, every clock, exactly the output and
//! tvalid of the Latency 8 core one clock later (simulated side by side,
//! see the core README). The model follows with LATENCY = 9.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module dds_compiler_dyn_readout_lat9 (
   input  logic        aclk,
   input  logic        s_axis_phase_tvalid,
   input  logic [71:0] s_axis_phase_tdata,
   output logic        m_axis_data_tvalid,
   output logic [31:0] m_axis_data_tdata
);

   dds_compiler_model #(
      .LATENCY     (9),
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
