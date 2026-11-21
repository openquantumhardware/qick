`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : fir_decim8_dynro
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    fir_decim8_dynro.sv
//!
//! @brief   Behavioural model of the Xilinx FIR Compiler instance used by
//!          axis_dyn_readout_v1 (for sim/lint only).
//!
//! @details
//! Same interface as the real Xilinx IP (fir_decim8_dynro.xci, FIR Compiler 7.2): decimate-by-8,
//! 120-tap symmetric lowpass, 2 paths (I/Q), 16-bit integer coefficients (fir_decim8_dynro.coe, hard
//! coded here), 16-bit output, symmetric rounding to zero.
//!
//! s_axis_data_tdata packing: N_DDS=8 lanes x 32 bits, {imag[31:16], real[15:0]} per lane, one block of 8
//! time-consecutive demodulated samples per clock (lane 0 = oldest, lane 7 = newest), as
//! down_conversion_dynro produces them. m_axis_data_tdata: one {imag, real} sample per block.
//!
//! Exact, checked against the IP (tests/vendor/run_vendor_check.sh): for the block t the result is
//!
//!     y = saturate16( round_to_zero( sum_{k=0..119} c[k] * x[8t + 7 - k] / 2^19 ) )
//!
//! with x[8t + 7] the newest sample of the block (lane 7), rounded to the nearest integer with ties
//! toward zero. The DC gain is sum(c)/2^19 = 0.516. It appears LATENCY = 67 clocks after the block and
//! m_axis_data_tvalid follows s_axis_data_tvalid with that delay (the IP raises it 67 clocks after the
//! first valid block). The history only advances with s_axis_data_tvalid (the callers tie it high).
//!
//! 1.0.1: the 1.0.0 model scaled by 2^-15 instead of 2^-19 (16 times the gain, saturating any signal
//! above 1/16 of full scale) and had a latency of 10; found when the QICK emulator ran the dynamic
//! readout. The IP synthesised from the .xci was never affected.
//!
//! @author  QICK Development Team
//!
//! @version 1.0.1
///////////////////////////////////////////////////////////////////////////////
module fir_decim8_dynro #(
    parameter int N_DDS   = 8,  //! Lanes per input block (fixed by the decimation rate: 8).
    parameter int LATENCY = 67  //! Input block -> output sample latency (cycles), as measured on the IP.
)(
    input  logic          aclk,
    input  logic          s_axis_data_tvalid,
    output logic          s_axis_data_tready,
    input  logic [N_DDS*32-1:0] s_axis_data_tdata,
    output logic          m_axis_data_tvalid,
    output logic [31:0]   m_axis_data_tdata
);

    localparam int NTAPS = 120;
    localparam int SHIFT = 19;

    //! Filter coefficients (fir_decim8_dynro.coe, Radix 10).
    localparam int H [NTAPS] = '{
        -56, -4, 13, 47, 97, 166, 252, 353, 463, 573,
        674, 754, 801, 804, 753, 643, 473, 249, -20, -314,
        -611, -885, -1107, -1248, -1285, -1201, -989, -651, -206, 318,
        878, 1425, 1903, 2254, 2428, 2383, 2094, 1556, 786, -172,
        -1251, -2364, -3408, -4271, -4839, -5010, -4696, -3838, -2410, -422,
        2076, 4993, 8205, 11560, 14889, 18012, 20758, 22971, 24523, 25322,
        25322, 24523, 22971, 20758, 18012, 14889, 11560, 8205, 4993, 2076,
        -422, -2410, -3838, -4696, -5010, -4839, -4271, -3408, -2364, -1251,
        -172, 786, 1556, 2094, 2383, 2428, 2254, 1903, 1425, 878,
        318, -206, -651, -989, -1201, -1285, -1248, -1107, -885, -611,
        -314, -20, 249, 473, 643, 753, 804, 801, 754, 674,
        573, 463, 353, 252, 166, 97, 47, 13, -4, -56
    };

    //! Sample history: index 0 = newest sample of the previous block ... NTAPS-1 = oldest.
    logic signed [15:0] hist_re [NTAPS];
    logic signed [15:0] hist_im [NTAPS];

    logic signed [15:0] din_re [N_DDS];
    logic signed [15:0] din_im [N_DDS];
    for (genvar g = 0; g < N_DDS; g = g + 1) begin : g_unpack
        assign din_re[g] = s_axis_data_tdata[g*32+:16];
        assign din_im[g] = s_axis_data_tdata[g*32+16+:16];
    end

    //! Round to the nearest integer, ties toward zero, and saturate to 16 bits.
    function automatic logic signed [15:0] round_sat(input longint acc);
        longint mag;
        longint q;
        mag = (acc < 0) ? -acc : acc;
        q   = (mag + (64'(1) << (SHIFT - 1)) - 1) >>> SHIFT;
        if (acc < 0) q = -q;
        if (q > 32767)  return 16'sd32767;
        if (q < -32768) return -16'sd32768;
        return 16'(q);
    endfunction

    //! Dot product of the taps with the window that ends at the newest sample of the CURRENT block.
    logic signed [15:0] y_re;
    logic signed [15:0] y_im;
    always_comb begin
        longint acc_re;
        longint acc_im;
        acc_re = 0;
        acc_im = 0;
        for (int k = 0; k < NTAPS; k++) begin
            if (k < N_DDS) begin
                acc_re += longint'(H[k]) * longint'(din_re[N_DDS-1-k]);
                acc_im += longint'(H[k]) * longint'(din_im[N_DDS-1-k]);
            end else begin
                acc_re += longint'(H[k]) * longint'(hist_re[k-N_DDS]);
                acc_im += longint'(H[k]) * longint'(hist_im[k-N_DDS]);
            end
        end
        y_re = round_sat(acc_re);
        y_im = round_sat(acc_im);
    end

    initial begin
        for (int k = 0; k < NTAPS; k++) begin
            hist_re[k] = '0;
            hist_im[k] = '0;
        end
    end

    always_ff @(posedge aclk) begin
        if (s_axis_data_tvalid) begin
            for (int k = NTAPS-1; k >= N_DDS; k--) begin
                hist_re[k] <= hist_re[k-N_DDS];
                hist_im[k] <= hist_im[k-N_DDS];
            end
            for (int g = 0; g < N_DDS; g++) begin
                hist_re[g] <= din_re[N_DDS-1-g];
                hist_im[g] <= din_im[N_DDS-1-g];
            end
        end
    end

    //! Output pipeline: LATENCY clocks from the block to the result; the valid bit travels with it.
    logic [32:0] pipe [LATENCY];
    initial begin
        for (int k = 0; k < LATENCY; k++) pipe[k] = '0;
    end
    always_ff @(posedge aclk) begin
        pipe[0] <= {s_axis_data_tvalid, y_im, y_re};
        for (int k = 1; k < LATENCY; k++)
            pipe[k] <= pipe[k-1];
    end

    assign m_axis_data_tdata  = pipe[LATENCY-1][31:0];
    assign m_axis_data_tvalid = pipe[LATENCY-1][32];
    assign s_axis_data_tready = 1'b1;

endmodule
