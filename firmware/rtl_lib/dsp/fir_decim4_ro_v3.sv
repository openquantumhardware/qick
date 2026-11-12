`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : fir_decim4_ro_v3
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    fir_decim4_ro_v3.sv
//!
//! @brief   Behavioural model of the Xilinx FIR Compiler instance used by
//!          axis_readout_v3 (for sim/lint only).
//!
//! @details
//! Same interface as the real Xilinx IP (fir_0.xci): decimate-by-4,
//! 107-tap symmetric linear-phase lowpass, 2 paths (I/Q), 18-bit output per
//! channel (2 extra bits of headroom over the 16-bit input -- the
//! coefficient sum is ~4.25x full scale, matching the x4 decimation
//! processing gain). Coefficients (from fir.coe, Q1.15-scale integers)
//! hardcoded as the exact filter this IP was generated with; NOT a
//! general-purpose FIR core.
//!
//! s_axis_data_tdata packing: N=4 lanes x 32 bits, {imag[31:16],
//! real[15:0]} per lane, ALL VALID EVERY CYCLE (matches
//! down_conversion_ro_v3's m_axis_tdata -- one block of 4 time-consecutive
//! demodulated samples per clock, lane 0 = oldest, lane 3 = newest).
//! m_axis_data_tdata packing (48-bit, matches down_conversion_fir.sv's own
//! extraction: real=bits[17:0], imag=bits[41:24] -- a 6-bit gap between
//! the two 18-bit fields, mirroring the real IP's channel alignment):
//! one decimated {imag,real} sample, produced once per input block.
//!
//! Direct-form decimation: maintains a 107-sample history (I and Q
//! separately, oldest-to-newest), shifts in the new 4-lane block each
//! cycle, and convolves the FULL 107-tap coefficient set against the
//! history every cycle. Computed in real arithmetic (not bit/cycle-exact to
//! the Vivado core's internal MAC/rounding/polyphase structure, same
//! disclaimer as fir_decim8_dynro).
//!
//! Latency (input block -> corresponding output sample): approximate,
//! LATENCY parameter (default 8) -- NOT validated against the real IP's
//! actual pipeline depth (legacy comment says 114 for the real IP).
//!
//! s_axis_data_tvalid is expected tied high by the caller; m_axis_data_tvalid
//! mirrors it (constant high once past reset), matching dds_compiler_model's
//! convention.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module fir_decim4_ro_v3 #(
    parameter int N       = 4,  //! Lanes per input block (fixed by the decimation rate: 4).
    parameter int LATENCY = 8   //! Input block -> output sample latency (cycles).
)(
    input  logic         aclk,
    input  logic         s_axis_data_tvalid,
    output logic         s_axis_data_tready,
    input  logic [N*32-1:0] s_axis_data_tdata,
    output logic         m_axis_data_tvalid,
    output logic [47:0]  m_axis_data_tdata
);

    localparam int NTAPS = 107;
    localparam int NPHASE_TAPS = 27;  // ceil(NTAPS/N)

    //! Filter coefficients (fir.coe, Radix=10 integer values, Q1.15-scaled).
    real h [NTAPS];
    initial begin
        h[0]=-19;    h[1]=178;    h[2]=379;    h[3]=653;    h[4]=910;
        h[5]=1053;   h[6]=997;    h[7]=719;    h[8]=273;    h[9]=-208;
        h[10]=-558;  h[11]=-646;  h[12]=-438;  h[13]=-19;   h[14]=424;
        h[15]=684;   h[16]=623;   h[17]=247;   h[18]=-287;  h[19]=-726;
        h[20]=-844;  h[21]=-547;  h[22]=58;    h[23]=700;   h[24]=1059;
        h[25]=922;   h[26]=301;   h[27]=-547;  h[28]=-1218; h[29]=-1351;
        h[30]=-811;  h[31]=213;   h[32]=1262;  h[33]=1803;  h[34]=1492;
        h[35]=367;   h[36]=-1114; h[37]=-2244; h[38]=-2387; h[39]=-1307;
        h[40]=651;   h[41]=2636;  h[42]=3623;  h[43]=2887;  h[44]=414;
        h[45]=-2944; h[46]=-5678; h[47]=-6144; h[48]=-3225; h[49]=3142;
        h[50]=11784; h[51]=20585; h[52]=27137; h[53]=29559; h[54]=27137;
        h[55]=20585; h[56]=11784; h[57]=3142;  h[58]=-3225; h[59]=-6144;
        h[60]=-5678; h[61]=-2944; h[62]=414;   h[63]=2887;  h[64]=3623;
        h[65]=2636;  h[66]=651;   h[67]=-1307; h[68]=-2387; h[69]=-2244;
        h[70]=-1114; h[71]=367;   h[72]=1492;  h[73]=1803;  h[74]=1262;
        h[75]=213;   h[76]=-811;  h[77]=-1351; h[78]=-1218; h[79]=-547;
        h[80]=301;   h[81]=922;   h[82]=1059;  h[83]=700;   h[84]=58;
        h[85]=-547;  h[86]=-844;  h[87]=-726;  h[88]=-287;  h[89]=247;
        h[90]=623;   h[91]=684;   h[92]=424;   h[93]=-19;   h[94]=-438;
        h[95]=-646;  h[96]=-558;  h[97]=-208;  h[98]=273;   h[99]=719;
        h[100]=997;  h[101]=1053; h[102]=910;  h[103]=653;  h[104]=379;
        h[105]=178;  h[106]=-19;

        for (int k = 0; k < NTAPS; k++)
            h[k] = h[k] / 32768.0;
    end

    //! Polyphase sub-filter taps: hp[p][m] = h[N*m+p] (0 where N*m+p >= NTAPS).
    real hp [N][NPHASE_TAPS];
    initial begin
        for (int p = 0; p < N; p++)
            for (int m = 0; m < NPHASE_TAPS; m++)
                hp[p][m] = (N*m+p < NTAPS) ? h[N*m+p] : 0.0;
    end

    //! Sample history, oldest-to-newest, index NPHASE_TAPS-1 = oldest.
    real hist_real [NPHASE_TAPS];
    real hist_imag [NPHASE_TAPS];

    logic signed [15:0] din_real [N];
    logic signed [15:0] din_imag [N];
    for (genvar g = 0; g < N; g = g + 1) begin : g_unpack
        assign din_real[g] = s_axis_data_tdata[g*32+:16];
        assign din_imag[g] = s_axis_data_tdata[g*32+16+:16];
    end

    //! Combinational dot-product against the CURRENT history (i.e. one
    //! cycle before the new block shifts in) -- only phase 0 (the block
    //! boundary) is needed since decimation matches the block size.
    real acc_real;
    real acc_imag;
    real sample_real;
    real sample_imag;
    always_comb begin
        acc_real = 0.0;
        acc_imag = 0.0;
        for (int m = 0; m < NPHASE_TAPS; m++) begin
            acc_real += hp[0][m] * hist_real[m];
            acc_imag += hp[0][m] * hist_imag[m];
        end
        sample_real = acc_real * 32768.0;
        sample_imag = acc_imag * 32768.0;
    end

    logic signed [17:0] out_real;
    logic signed [17:0] out_imag;

    always_ff @(posedge aclk) begin
        for (int m = NPHASE_TAPS-1; m >= N; m--) begin
            hist_real[m] <= hist_real[m-N];
            hist_imag[m] <= hist_imag[m-N];
        end
        for (int g = 0; g < N; g++) begin
            hist_real[N-1-g] <= real'(din_real[g]) / 32768.0;
            hist_imag[N-1-g] <= real'(din_imag[g]) / 32768.0;
        end

        out_real <= (sample_real >  131071.0) ? 18'sd131071 :
                    (sample_real < -131072.0) ? 18'sh20000  :
                    18'($rtoi(sample_real));
        out_imag <= (sample_imag >  131071.0) ? 18'sd131071 :
                    (sample_imag < -131072.0) ? 18'sh20000  :
                    18'($rtoi(sample_imag));
    end

    logic [47:0] sample_word;
    assign sample_word[17:0]   = out_real;
    assign sample_word[23:18]  = '0;
    assign sample_word[41:24]  = out_imag;
    assign sample_word[47:42]  = '0;

    logic [47:0] pipe [LATENCY];
    always_ff @(posedge aclk) begin
        pipe[0] <= sample_word;
        for (int k = 1; k < LATENCY; k++)
            pipe[k] <= pipe[k-1];
    end

    assign m_axis_data_tdata  = pipe[LATENCY-1];
    assign m_axis_data_tvalid = 1'b1;
    assign s_axis_data_tready = 1'b1;

endmodule
