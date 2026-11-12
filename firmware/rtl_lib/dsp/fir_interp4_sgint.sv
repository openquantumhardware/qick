`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : fir_interp4_sgint
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    fir_interp4_sgint.sv
//!
//! @brief   Behavioural model of the Xilinx FIR Compiler instance used by
//!          axis_sg_int4_v2 (for sim/lint only).
//!
//! @details
//! Same interface as the real Xilinx IP (fir_0.xci): interpolate-by-4,
//! 21-tap, symmetric linear-phase lowpass, packed complex (I/Q) input/output
//! -- one raw envelope sample in per cycle, 4 interpolated samples out per
//! cycle. Coefficients (from fir_0.coe, Q1.15-scale real values) hardcoded
//! as the exact filter this IP was generated with; NOT a general-purpose
//! FIR core.
//!
//! s_axis_data_tdata / m_axis_data_tdata packing (matches the real Xilinx
//! IP / legacy signal_gen.v's `env_din = {mem_imag_r1, mem_real_r1}`):
//!   input  [31:16]=imag, [15:0]=real            (one raw sample)
//!   output lane p (p=0..3): [p*32+31:p*32+16]=imag, [p*32+15:p*32]=real
//!
//! Implemented via the standard polyphase decomposition: for interpolation
//! rate L=4 and N=21 taps, output phase p (p=0..3) at input-relative time n
//! is y[4n+p] = sum_{m=0}^{5} h[4m+p] * x[n-m] (taps beyond index 20 are
//! zero). Computed in real arithmetic (not bit/cycle-exact to the Vivado
//! core's internal MAC/rounding, same disclaimer as dds_compiler_model),
//! then rounded to a signed Q1.15 sample per phase.
//!
//! Latency (input sample -> corresponding 4-lane output group): matches the
//! legacy comment in signal_gen.v ("Cycle latency + 1 = 11 + 1 = 12").
//!
//! s_axis_data_tvalid is expected tied high by the caller (matches
//! signal_gen.v's `.s_axis_data_tvalid(1'b1)`); m_axis_data_tvalid is
//! likewise always high here, mirroring dds_compiler_model's convention.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module fir_interp4_sgint #(
    parameter int LATENCY = 12  //! Input sample -> output group latency (cycles).
)(
    input  logic         aclk,
    input  logic         s_axis_data_tvalid,
    output logic         s_axis_data_tready,
    input  logic [31:0]  s_axis_data_tdata,
    output logic         m_axis_data_tvalid,
    output logic [127:0] m_axis_data_tdata
);

    localparam int NTAPS = 21;
    localparam int L     = 4;
    localparam int NPHASE_TAPS = 6;  // ceil(NTAPS/L)

    //! Filter coefficients (fir_0.coe, Radix=10 fractional values).
    real h [NTAPS];
    initial begin
        h[0]  =  0.004708; h[1]  =  0.005461; h[2]  =  0.000000;
        h[3]  = -0.013987; h[4]  = -0.029332; h[5]  = -0.030123;
        h[6]  =  0.000000; h[7]  =  0.065216; h[8]  =  0.149630;
        h[9]  =  0.221652; h[10] =  0.250000; h[11] =  0.221652;
        h[12] =  0.149630; h[13] =  0.065216; h[14] =  0.000000;
        h[15] = -0.030123; h[16] = -0.029332; h[17] = -0.013987;
        h[18] =  0.000000; h[19] =  0.005461; h[20] =  0.004708;
    end

    //! Polyphase sub-filter taps: hp[p][m] = h[4*m+p] (0 where 4*m+p >= NTAPS).
    real hp [L][NPHASE_TAPS];
    initial begin
        for (int p = 0; p < L; p++)
            for (int m = 0; m < NPHASE_TAPS; m++)
                hp[p][m] = (4*m+p < NTAPS) ? h[4*m+p] : 0.0;
    end

    //! Raw (pre-interpolation) sample history, index 0 = most recent.
    real hist_real [NPHASE_TAPS];
    real hist_imag [NPHASE_TAPS];

    logic signed [15:0] din_real, din_imag;
    assign din_real = s_axis_data_tdata[15:0];
    assign din_imag = s_axis_data_tdata[31:16];

    logic signed [15:0] out_real [L];
    logic signed [15:0] out_imag [L];

    //! Combinational polyphase dot-products, computed from the CURRENT
    //! sample history (i.e. one cycle before the new sample shifts in --
    //! matches din_real/din_imag not yet being part of hist_*).
    real acc_real [L];
    real acc_imag [L];
    real sample_real [L];
    real sample_imag [L];
    always_comb begin
        for (int p = 0; p < L; p++) begin
            acc_real[p] = 0.0;
            acc_imag[p] = 0.0;
            for (int m = 0; m < NPHASE_TAPS; m++) begin
                acc_real[p] += hp[p][m] * hist_real[m];
                acc_imag[p] += hp[p][m] * hist_imag[m];
            end
            sample_real[p] = acc_real[p] * 32768.0;
            sample_imag[p] = acc_imag[p] * 32768.0;
        end
    end

    always_ff @(posedge aclk) begin
        for (int m = NPHASE_TAPS-1; m > 0; m--) begin
            hist_real[m] <= hist_real[m-1];
            hist_imag[m] <= hist_imag[m-1];
        end
        hist_real[0] <= real'(din_real) / 32768.0;
        hist_imag[0] <= real'(din_imag) / 32768.0;

        for (int p = 0; p < L; p++) begin
            out_real[p] <= (sample_real[p] >  32767.0) ? 16'sd32767 :
                           (sample_real[p] < -32768.0) ? 16'sh8000  :
                           16'($rtoi(sample_real[p]));
            out_imag[p] <= (sample_imag[p] >  32767.0) ? 16'sd32767 :
                           (sample_imag[p] < -32768.0) ? 16'sh8000  :
                           16'($rtoi(sample_imag[p]));
        end
    end

    logic [127:0] sample_word;
    for (genvar p = 0; p < L; p++) begin : g_pack
        assign sample_word[p*32+:16]    = out_real[p];
        assign sample_word[p*32+16+:16] = out_imag[p];
    end

    logic [127:0] pipe [LATENCY];
    always_ff @(posedge aclk) begin
        pipe[0] <= sample_word;
        for (int k = 1; k < LATENCY; k++)
            pipe[k] <= pipe[k-1];
    end

    assign m_axis_data_tdata  = pipe[LATENCY-1];
    assign m_axis_data_tvalid = 1'b1;
    assign s_axis_data_tready = 1'b1;

endmodule
