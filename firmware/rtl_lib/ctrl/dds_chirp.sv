`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : dds_chirp
// Project: QICK / axis_kidsim_v3
///////////////////////////////////////////////////////////////////////////////
//! @file    dds_chirp.sv
//!
//! @brief   DDS with linear frequency modulation (chirp) generator.
//!
//! @details
//!
//! Generates a complex exponential e^{j*w(t)} whose phase increment is swept
//! linearly on trigger (chirp), then settles back to the base frequency.
//!
//! Datapath:
//!   dds_phase_ctrl (lat 2)  ->  DDS IP (lat 8)  ->  {sin[31:16], cos[15:0]}
//!
//! dds_phase_ctrl produces the DDS control word {phase=0, pinc}, where
//!   pinc = FREQ_REG - ramp(n),  ramp(n) = B - n*M  (see ramp_gen).
//! The DDS IP (dds_phasegen_sincos_ow16_lat8) turns it into sine/cosine.
//!
//! Total latency (i_din_valid -> o_dout_valid): 10 (2 + 8).
//!
//! DDS control word format (to the IP):
//!   | 31 .. 16 | 15 .. 0 |
//!   |  phase=0 |  pinc    |
//!
//! @author  @lharnaldi
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module dds_chirp (
    input  logic        i_clk,        //! Clock.
    input  logic        i_rstn,       //! Synchronous active-low reset.

    input  logic        i_trigger,    //! Modulation trigger (async, other domain).
    input  logic        i_din_valid,  //! Input data valid.

    output logic        o_dout_valid, //! Output valid (aligned to o_dout).
    output logic [31:0] o_dout,       //! DDS output {sin[31:16], cos[15:0]}.

    // Register bank (all 16-bit).
    input  logic [15:0] i_bval_reg,   //! Ramp start value B.
    input  logic [15:0] i_slope_reg,  //! Ramp slope M.
    input  logic [15:0] i_steps_reg,  //! Number of ramp steps N.
    input  logic [15:0] i_wait_reg,   //! Wait cycles per step W.
    input  logic [15:0] i_freq_reg    //! Base frequency (phase increment).
);

    //! DDS control word from the phase controller.
    logic        ctrl_valid;
    logic [31:0] ctrl_dout;

    // ------------------------------------------------------------------------
    // DDS phase-increment controller (chirp). Latency: 2.
    // ------------------------------------------------------------------------
    dds_phase_ctrl dds_phase_ctrl_i (
        .i_clk        (i_clk),
        .i_rstn       (i_rstn),
        .i_trigger    (i_trigger),
        .i_din_valid  (i_din_valid),
        .o_dout_valid (ctrl_valid),
        .o_dout       (ctrl_dout),
        .i_bval_reg   (i_bval_reg),
        .i_slope_reg  (i_slope_reg),
        .i_steps_reg  (i_steps_reg),
        .i_wait_reg   (i_wait_reg),
        .i_freq_reg   (i_freq_reg)
    );

    // ------------------------------------------------------------------------
    // DDS IP (renamed dds_0). Latency: 8. Generates e^{jw}.
    // Instantiated by name: resolves to behavioural model for sim/lint and to
    // the real Xilinx .xci for synthesis/packaging.
    // ------------------------------------------------------------------------
    dds_phasegen_sincos_ow16_lat8 dds_i (
        .aclk                (i_clk),
        .s_axis_phase_tvalid (ctrl_valid),
        .s_axis_phase_tdata  (ctrl_dout),
        .m_axis_data_tvalid  (o_dout_valid),
        .m_axis_data_tdata   (o_dout)
    );

endmodule

