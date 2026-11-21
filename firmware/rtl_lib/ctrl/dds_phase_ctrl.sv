`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : dds_phase_ctrl
// Project: QICK / axis_kidsim_v3
///////////////////////////////////////////////////////////////////////////////
//! @file    dds_phase_ctrl.sv
//!
//! @brief   DDS phase-increment controller with linear frequency modulation.
//!
//! @details
//! Produces the DDS control word {phase[31:16]=0, pinc[15:0]} where the phase
//! increment is the base frequency minus a linear ramp (chirp):
//!
//!     pinc = FREQ_REG - ramp(n),   ramp(n) = B - n*M   (from ramp_gen)
//!
//! On trigger the ramp runs for N steps (every W cycles), then pinc settles
//! back to FREQ_REG. The trigger crosses from a different clock domain and is
//! resynchronized here with cdc_bit_sync before driving ramp_gen.
//!
//! DDS control word format:
//!   | 31 .. 16 | 15 .. 0 |
//!   |  phase=0 |  pinc    |
//!
//! Latency (din_valid -> o_dout_valid): 2 cycles.
//!
//! @author  @lharnaldi
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module dds_phase_ctrl (
    input  logic        i_clk,        //! Clock.
    input  logic        i_rstn,       //! Synchronous active-low reset.

    input  logic        i_trigger,    //! Modulation trigger (async, other domain).
    input  logic        i_din_valid,  //! Input data valid (enables ramp advance).

    output logic        o_dout_valid, //! Output valid (aligned to o_dout).
    output logic [31:0] o_dout,       //! DDS control word {phase=0, pinc}.

    // Register bank (all 16-bit).
    input  logic [15:0] i_bval_reg,   //! Ramp start value B.
    input  logic [15:0] i_slope_reg,  //! Ramp slope M.
    input  logic [15:0] i_steps_reg,  //! Number of ramp steps N.
    input  logic [15:0] i_wait_reg,   //! Wait cycles per step W.
    input  logic [15:0] i_freq_reg    //! Base frequency (phase increment).
);

    //! Resynchronized trigger (2-FF CDC).
    logic trigger_sync;

    //! Ramp output (signed modulation value).
    logic signed [15:0] mod_out;
    logic signed [15:0] mod_out_r1;

    //! Frequency (phase increment) = base - modulation.
    logic [15:0] freq;
    logic [15:0] freq_r1;

    //! Valid pipeline (2 stages to match the datapath latency).
    logic valid_r1;
    logic valid_r2;

    //! Latched base frequency register.
    logic [15:0] freq_reg_r;

    // ------------------------------------------------------------------------
    // Trigger CDC: bring the async trigger into i_clk domain (2 FF).
    // ------------------------------------------------------------------------
    cdc_bit_sync #(
        .NSTAGES(2)
    ) trigger_sync_i (
        .i_clk   (i_clk),
        .i_rstn  (i_rstn),
        .i_async (i_trigger),
        .o_sync  (trigger_sync)
    );

    // ------------------------------------------------------------------------
    // Ramp generator (linear frequency modulation). Latency: y is registered.
    // ------------------------------------------------------------------------
    ramp_gen #(
        .DATA_W (16),
        .CNT_W  (16)
    ) ramp_gen_i (
        .i_clk     (i_clk),
        .i_rstn    (i_rstn),
        .i_trigger (trigger_sync),     //! already synchronized here
        .i_en      (i_din_valid),
        .i_b       (i_bval_reg),
        .i_m       (i_slope_reg),
        .i_n_steps (i_steps_reg),
        .i_wait    (i_wait_reg),
        .o_y       (mod_out)
    );

    // ------------------------------------------------------------------------
    // Frequency addition and output pipeline.
    // ------------------------------------------------------------------------
    //! pinc = base - modulation (unsigned wrap is intentional: phase accumulator).
    assign freq = freq_reg_r - mod_out_r1;

    always_ff @(posedge i_clk) begin
        if (i_rstn == 1'b0) begin
            mod_out_r1 <= '0;
            freq_r1    <= '0;
            valid_r1   <= 1'b0;
            valid_r2   <= 1'b0;
            freq_reg_r <= '0;
        end else begin
            //! Base frequency register (always latched; it is static config).
            freq_reg_r <= i_freq_reg;

            //! Valid pipeline (always advances so downstream sees the gaps).
            valid_r1 <= i_din_valid;
            valid_r2 <= valid_r1;

            //! Datapath pipeline: advance ONLY on valid beats (AXIS-like gating).
            //! On bubbles every stage holds, so the sequence is continuous and
            //! there is no jump when valid resumes.
            if (i_din_valid == 1'b1) begin
                mod_out_r1 <= mod_out;
            end
            if (valid_r1 == 1'b1) begin
                freq_r1 <= freq;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Outputs: {phase=0, pinc}.
    // ------------------------------------------------------------------------
    assign o_dout       = {16'b0, freq_r1};
    assign o_dout_valid = valid_r2;

endmodule

