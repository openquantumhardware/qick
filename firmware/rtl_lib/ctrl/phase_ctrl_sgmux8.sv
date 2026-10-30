`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : phase_ctrl_sgmux8
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    phase_ctrl_sgmux8.sv
//!
//! @brief   Phase-coherent per-lane phase/increment generator for one
//!          axis_sg_mux8_v1 output channel.
//!
//! @details
//! Drives N_DDS parallel DDS lanes that together synthesize one output wave
//! (the DDSs are interleaved, each producing every N_DDS-th sample). To keep
//! the interleaved lanes phase-coherent, this block:
//!
//!  - runs a free-running sample counter cnt_n (step N_DDS/cycle) so the
//!    absolute sample index is always known, even while PINC/POFF are held;
//!  - computes pinc_N = (PINC * N_DDS) mod 2^32 : the phase step between
//!    consecutive cycles of the SAME lane;
//!  - computes pinc_Nm = (PINC * cnt_n) mod 2^32 : the phase already
//!    accumulated up to the current absolute sample, used to re-seed the
//!    phase of every lane so a PINC/POFF update never causes a phase jump;
//!  - per lane i: phase_v0[i] = PINC * i (its offset within one interleaved
//!    group), phase_v1[i] = phase_v0[i] + pinc_Nm + POFF.
//!
//! The two 32x32 products (PINC*N_DDS, PINC*cnt_n) are computed by the
//! pipelined mult_32x32 core; only the lower 32 bits are kept (modulo 2^32
//! is intentional -- phase accumulators wrap).
//!
//! WE_REG is resynchronized (cdc_bit_sync, replaces the legacy
//! synchronizer_n) since it originates in the AXI-Lite clock domain; PINC/POFF
//! are only latched while the resynchronized WE_REG is high.
//!
//! DDS control word format (per lane, 72 bits): {opcode[7:0]=8'h01,
//! phase[63:32]=phase_v1, phase[31:0]=pinc_N} -- matches dds_compiler's
//! phase-increment input.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module phase_ctrl_sgmux8 #(
    parameter int N_DDS = 2  //! Number of interleaved parallel DDS lanes.
)(
    input  logic                 rstn,        //! Synchronous active-low reset.
    input  logic                 clk,         //! Clock.

    output logic [N_DDS*72-1:0]  dds_ctrl_o,  //! Per-lane DDS control words.

    input  logic [31:0]          pinc_reg,    //! Phase increment register.
    input  logic [31:0]          poff_reg,    //! Phase offset register.
    input  logic                 we_reg       //! Write-enable (AXI-Lite domain).
);

    // Pinc.
    logic [31:0] pinc_r1a;
    logic [31:0] pinc_r1b;
    logic [31:0] pinc_r1c;
    logic [63:0] pinc_nf;
    logic [31:0] pinc_n;
    logic [31:0] pinc_n_r1;
    logic [63:0] pinc_nmf;
    logic [31:0] pinc_nm;
    logic [31:0] pnm_off_r;   //! pinc_nm + poff, registered (see g_phase)

    // Poff.
    logic [31:0] poff_r1;

    // Phase vectors.
    logic [31:0] phase_v0    [N_DDS];
    logic [31:0] phase_v0_r1 [N_DDS];
    logic [31:0] phase_v1    [N_DDS];
    logic [31:0] phase_v1_r1 [N_DDS];

    // Non-stop counter for phase coherent behavior.
    logic [31:0] cnt_n;
    logic [31:0] cnt_n_r1;

    // Registers.
    logic [31:0] pinc_reg_r;
    logic [31:0] poff_reg_r;
    logic        we_reg_resync;

    // we_reg resync (AXI-Lite domain -> clk domain).
    cdc_bit_sync #(
        .NSTAGES (2)
    ) we_reg_resync_i (
        .i_clk   (clk),
        .i_rstn  (rstn),
        .i_async (we_reg),
        .o_sync  (we_reg_resync)
    );

    // PINC x N_DDS: 32x32 product, optimized for full-speed.
    mult_32x32 mult0_i (
        .clk   (clk),
        .din_a (pinc_r1a),
        .din_b (32'(N_DDS)),
        .dout  (pinc_nf)
    );

    // Preserve lower 32 bits for modulo operation.
    assign pinc_n = pinc_nf[31:0];

    // PINC x cnt_n: 32x32 product, optimized for full-speed.
    mult_32x32 mult1_i (
        .clk   (clk),
        .din_a (pinc_r1c),
        .din_b (cnt_n_r1),
        .dout  (pinc_nmf)
    );

    // Preserve lower 32 bits for modulo operation.
    assign pinc_nm = pinc_nmf[31:0];

    // NOTE (deviation from legacy phase_ctrl.sv): the legacy always block had
    // no rstn branch at all and relied on Verilog "reg ... = 0" initial
    // values for a defined state at time 0. That is fragile outside
    // simulation-with-initial-values, so this port adds an explicit
    // synchronous active-low reset for every register in this block,
    // matching the rest of this repo's convention.
    always_ff @(posedge clk) begin
        if (!rstn) begin
            pinc_r1a   <= '0;
            pinc_r1b   <= '0;
            pinc_r1c   <= '0;
            pinc_n_r1  <= '0;
            pnm_off_r  <= '0;
            poff_r1    <= '0;
            cnt_n      <= '0;
            cnt_n_r1   <= '0;
            pinc_reg_r <= '0;
            poff_reg_r <= '0;
        end else begin
            // Pinc.
            pinc_r1a   <= pinc_reg_r;
            pinc_r1b   <= pinc_reg_r;
            pinc_r1c   <= pinc_reg_r;
            pinc_n_r1  <= pinc_n;
            // One register for the sum of the two lane-independent terms: the value
            // equals the former pinc_nm_r1 + poff_r2 on every clock (both were
            // registered from pinc_nm / poff_r1 in this same cycle), so latency is
            // unchanged, and each lane is left with a 2-input add at the DAC clock
            // (the 3-input add failed timing at 614.4 MHz on the ZCU216).
            pnm_off_r  <= pinc_nm + poff_r1;

            // Poff.
            poff_r1 <= poff_reg_r;

            // Non-stop counter for phase coherent behavior.
            cnt_n    <= cnt_n + 32'(N_DDS);
            cnt_n_r1 <= cnt_n;

            // Registers.
            if (we_reg_resync == 1'b1) begin
                pinc_reg_r <= pinc_reg;
                poff_reg_r <= poff_reg;
            end
        end
    end

    // Phase vectors.
    for (genvar i = 0; i < N_DDS; i = i + 1) begin : g_phase
        // v0.
        assign phase_v0[i] = pinc_r1b * 32'(i);

        // v1.
        assign phase_v1[i] = phase_v0_r1[i] + pnm_off_r;

        // dds_ctrl_o output.
        assign dds_ctrl_o[i*72+:72] = {8'h01, phase_v1_r1[i], pinc_n_r1};

        always_ff @(posedge clk) begin
            if (!rstn) begin
                phase_v0_r1[i] <= '0;
                phase_v1_r1[i] <= '0;
            end else begin
                // v0.
                phase_v0_r1[i] <= phase_v0[i];

                // v1.
                phase_v1_r1[i] <= phase_v1[i];
            end
        end
    end

endmodule
