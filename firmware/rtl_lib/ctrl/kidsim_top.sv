`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : kidsim_top
// Project: QICK / axis_kidsim_v3
///////////////////////////////////////////////////////////////////////////////
//! @file    kidsim_top.sv
//!
//! @brief   One-lane KID simulator wrapper: puncturing + kidsim + bypass mux.
//!
//! @details
//!
//! Wraps the kidsim datapath for a single lane. A punct block selects one
//! sample per frame (index PUNCT_ID_REG); only that sample enables the kidsim
//! processing. The output multiplexes between the processed sample and a
//! latency-matched bypass of the input, so streaming timing is preserved.
//!
//! Datapath:
//!   din --[din_align, 2]--> kidsim (lat KIDSIM_LAT) --> kidsim_dout
//!    |                                                      |
//!    \--[bypass, BYPASS_LAT]-------------------------------+--> mux --> dout
//!                                                          |
//!   din_valid/last --> punct (lat 2) --> kidsim_din_valid = punct_valid & en
//!                       |
//!                       \--[valid/last delayed KIDSIM_LAT]--> dout_valid/last
//!
//! LATENCY ALIGNMENT (important):
//!   punct adds 2 cycles of latency on the valid/last path. The kidsim block
//!   does NOT align din with the punct valid (its internal din_la=DDS_LATENCY
//!   aligns din with the DDS carrier, a different constraint). So din must be
//!   delayed by 2 (din_align) to enter kidsim in sync with kidsim_din_valid.
//!
//!   Reference: everything is aligned to raw-din + (2 + KIDSIM_LAT):
//!     - kidsim processed : 2 (din_align) + KIDSIM_LAT           = 16
//!     - input bypass      : BYPASS_LAT = KIDSIM_LAT + 2          = 16
//!     - valid/last        : punct (2) + KIDSIM_LAT               = 16
//!   Total kidsim_top latency (raw din -> o_dout) = 16.
//!
//!   KIDSIM_LAT must equal kidsim's real clock latency, which depends on the
//!   DDS IP: it adds 0 clocks (output valid = input valid), see kidsim.sv.
//!   With a wrong KIDSIM_LAT the mux below never sees kidsim_dout_valid in the
//!   cycle the valid comes out, and every sample leaves through the bypass.
//!
//! Output mux: when kidsim produced a valid processed sample this cycle, emit
//! it; otherwise pass the bypassed input. o_dout_valid (punct_valid delayed by
//! KIDSIM_LAT) qualifies either source. This is structural (parametrized by
//! KIDSIM_LAT), not a hand-tuned magic constant.
//!
//! Register writes (WE_REG) come from a different clock domain and are
//! resynchronized with cdc_bit_sync before latching the configuration.
//! OUTSEL defaults to 2 (bypass) until a valid write configures the lane.
//!
//! @author  @lharnaldi
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module kidsim_top #(
    //! kidsim main-path latency (DDS_LATENCY 2 + cmult 4 + iir 4 + cmult 4).
    parameter int KIDSIM_LAT = 14
) (
    input  logic        i_clk,        //! Clock.
    input  logic        i_rstn,       //! Synchronous active-low reset.

    input  logic        i_trigger,    //! Modulation trigger (already synced upstream).

    input  logic        i_din_valid,  //! Input valid.
    input  logic [31:0] i_din,        //! Input sample {Q, I}.
    input  logic        i_din_last,   //! Input frame last.

    output logic        o_dout_valid, //! Output valid.
    output logic [31:0] o_dout,       //! Output sample {Q, I}.
    output logic        o_dout_last,  //! Output frame last.

    // Register bank (from AXI, in a different clock domain; latched on WE).
    input  logic [15:0] i_dds_bval_reg,   //! Chirp ramp start B.
    input  logic [15:0] i_dds_slope_reg,  //! Chirp ramp slope M.
    input  logic [15:0] i_dds_steps_reg,  //! Chirp ramp steps N.
    input  logic [15:0] i_dds_wait_reg,   //! Chirp ramp wait W.
    input  logic [15:0] i_dds_freq_reg,   //! DDS base frequency.
    input  logic [15:0] i_iir_c0_reg,     //! IIR coefficient C0.
    input  logic [15:0] i_iir_c1_reg,     //! IIR coefficient C1.
    input  logic [15:0] i_iir_g_reg,      //! IIR gain G.
    input  logic [ 1:0] i_outsel_reg,     //! Output selection.
    input  logic [15:0] i_punct_id_reg,   //! Puncturing sample index.
    input  logic        i_we_reg          //! Write-enable (different clock domain).
);

    //! din delayed to line up with punct's valid at the kidsim input.
    logic [31:0] din_align;

    //! Punct outputs.
    logic punct_valid;
    logic punct_last;
    logic punct_en;

    //! Delayed valid/last (aligned to the kidsim output).
    logic punct_valid_la;
    logic punct_last_la;

    //! kidsim gating and outputs.
    logic        kidsim_din_valid;
    logic [31:0] kidsim_dout;
    logic        kidsim_dout_valid;

    //! Input bypass (latency-matched to the kidsim output).
    logic [31:0] din_la_mux;

    //! Muxed output.
    logic [31:0] dout_mux;

    //! Resynchronized write-enable (different clock domain).
    logic we_reg_resync;

    //! Latched configuration registers.
    logic [15:0] dds_bval_r;
    logic [15:0] dds_slope_r;
    logic [15:0] dds_steps_r;
    logic [15:0] dds_wait_r;
    logic [15:0] dds_freq_r;
    logic [15:0] iir_c0_r;
    logic [15:0] iir_c1_r;
    logic [15:0] iir_g_r;
    logic [ 1:0] outsel_r;
    logic [15:0] punct_id_r;

    //! Bypass path latency from raw din (2 din_align + KIDSIM_LAT).
    localparam int BYPASS_LAT = KIDSIM_LAT + 2;

    // ------------------------------------------------------------------------
    // WE resync (different clock domain -> i_clk).
    // ------------------------------------------------------------------------
    cdc_bit_sync #(
        .NSTAGES(2)
    ) we_resync_i (
        .i_clk   (i_clk),
        .i_rstn  (i_rstn),
        .i_async (i_we_reg),
        .o_sync  (we_reg_resync)
    );

    // ------------------------------------------------------------------------
    // Configuration registers (latched when the resynced WE is asserted).
    // ------------------------------------------------------------------------
    always_ff @(posedge i_clk) begin
        if (i_rstn == 1'b0) begin
            dds_bval_r  <= '0;
            dds_slope_r <= '0;
            dds_steps_r <= '0;
            dds_wait_r  <= '0;
            dds_freq_r  <= '0;
            iir_c0_r    <= '0;
            iir_c1_r    <= '0;
            iir_g_r     <= '0;
            outsel_r    <= 2'd2;   //! bypass by default
            punct_id_r  <= '0;
        end else if (we_reg_resync == 1'b1) begin
            dds_bval_r  <= i_dds_bval_reg;
            dds_slope_r <= i_dds_slope_reg;
            dds_steps_r <= i_dds_steps_reg;
            dds_wait_r  <= i_dds_wait_reg;
            dds_freq_r  <= i_dds_freq_reg;
            iir_c0_r    <= i_iir_c0_reg;
            iir_c1_r    <= i_iir_c1_reg;
            iir_g_r     <= i_iir_g_reg;
            outsel_r    <= i_outsel_reg;
            punct_id_r  <= i_punct_id_reg;
        end
    end

    // ------------------------------------------------------------------------
    // Align din with punct's valid (2-cycle punct latency).
    // ------------------------------------------------------------------------
    delay_line #(.N(2), .M(32)) din_align_i (
        .i_clk  (i_clk),
        .i_rstn (i_rstn),
        .i_data (i_din),
        .o_data (din_align)
    );

    // ------------------------------------------------------------------------
    // Puncturing: select one sample per frame. Latency 2.
    // ------------------------------------------------------------------------
    punct punct_i (
        .i_clk        (i_clk),
        .i_rstn       (i_rstn),
        .i_din_valid  (i_din_valid),
        .i_din_last   (i_din_last),
        .o_dout_valid (punct_valid),
        .o_dout_last  (punct_last),
        .o_dout_en    (punct_en),
        .i_id_reg     (punct_id_r)
    );

    //! kidsim processes only the selected sample of each frame.
    assign kidsim_din_valid = punct_valid & punct_en;

    // ------------------------------------------------------------------------
    // KID simulator datapath. Takes din_align. Latency KIDSIM_LAT.
    // ------------------------------------------------------------------------
    kidsim #(
        .DDS_LATENCY (2)
    ) kidsim_i (
        .i_clk           (i_clk),
        .i_rstn          (i_rstn),
        .i_trigger       (i_trigger),
        .i_din           (din_align),
        .i_din_valid     (kidsim_din_valid),
        .o_dout          (kidsim_dout),
        .o_dout_valid    (kidsim_dout_valid),
        .i_dds_bval_reg  (dds_bval_r),
        .i_dds_slope_reg (dds_slope_r),
        .i_dds_steps_reg (dds_steps_r),
        .i_dds_wait_reg  (dds_wait_r),
        .i_dds_freq_reg  (dds_freq_r),
        .i_iir_c0_reg    (iir_c0_r),
        .i_iir_c1_reg    (iir_c1_r),
        .i_iir_g_reg     (iir_g_r),
        .i_outsel_reg    (outsel_r)
    );

    // ------------------------------------------------------------------------
    // Latency lines (aligned so all sources reach the output at raw-din + 16).
    // ------------------------------------------------------------------------
    //! Input bypass from raw din (BYPASS_LAT = KIDSIM_LAT + 2 = 16).
    delay_line #(.N(BYPASS_LAT), .M(32)) din_la_mux_i (
        .i_clk  (i_clk),
        .i_rstn (i_rstn),
        .i_data (i_din),
        .o_data (din_la_mux)
    );

    //! Valid delayed by the kidsim latency (punct already added 2).
    delay_line #(.N(KIDSIM_LAT), .M(1)) punct_valid_la_i (
        .i_clk  (i_clk),
        .i_rstn (i_rstn),
        .i_data (punct_valid),
        .o_data (punct_valid_la)
    );

    //! Last delayed by the kidsim latency.
    delay_line #(.N(KIDSIM_LAT), .M(1)) punct_last_la_i (
        .i_clk  (i_clk),
        .i_rstn (i_rstn),
        .i_data (punct_last),
        .o_data (punct_last_la)
    );

    // ------------------------------------------------------------------------
    // Output mux: processed sample if kidsim produced one, else the bypass.
    // ------------------------------------------------------------------------
    assign dout_mux = (kidsim_dout_valid == 1'b1) ? kidsim_dout : din_la_mux;

    assign o_dout       = dout_mux;
    assign o_dout_valid = punct_valid_la;
    assign o_dout_last  = punct_last_la;

endmodule

