`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : ssrfft_8x64_sync
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    ssrfft_8x64_sync.sv
//!
//! @brief   The PFB readouts' FFT stage: frames the incoming stream on its
//!          tlast, runs the 64-point, 8-lane SysGen FFT (ssr_8x64) and cuts
//!          16 bits out of its 27-bit result.
//!
//! @details
//! Faithful port of the legacy VHDL (openquantumhardware/qick firmware/ip/
//! axis_pfb_readout_v4/src/pfb/fft/{ssrfft_8x64_sync,framing,tlast_gen}.vhd,
//! identical in v3), with the three entities merged:
//!
//! - Framing. After reset the block waits 256 clocks, then marks every
//!   clock valid (s_axis_tvalid is not looked at: the source is a continuous
//!   ADC stream) and counts NFFT/SSR clocks per frame. A tlast that comes on
//!   the last clock of a frame keeps it aligned. A tlast anywhere else lets
//!   the current frame finish, then stops marking clocks valid until the next
//!   tlast, which starts a new frame on the following clock. Data and valid
//!   go through two registers before the FFT.
//! - FFT: lane l of s_axis_tdata is {Q, I} at bits [2*B*l +: 2*B]; i_scale is
//!   scale_reg[5:0] (one halving per set bit).
//! - Output: 16 bits of each 27-bit FFT result, starting at bit
//!   qout_reg (qout_reg > 11 selects bit 0). m_axis_tvalid is the FFT's
//!   o_valid; m_axis_tlast is high on the last of every NFFT/SSR valid
//!   clocks, counted from reset.
//!
//! Reset clears the framing and the tlast counter, not the FFT (the SysGen
//! core has no reset): frames already inside it still come out after reset.
//!
//! The FFT is fixed at 64 points and 8 lanes of 16 bits: NFFT, SSR and B
//! keep the legacy interface, and the deployed values are the only working
//! ones (NFFT = 64, SSR = 8, B = 16).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module ssrfft_8x64_sync #(
    parameter int NFFT = 64,   //! FFT length
    parameter int SSR  = 8,    //! Samples per clock
    parameter int B    = 16    //! Bits per I or Q sample
) (
    input  logic                 aresetn,
    input  logic                 aclk,

    input  logic [2*SSR*B-1:0]   s_axis_tdata,
    input  logic                 s_axis_tlast,
    // verilog_lint: waive-start unused
    input  logic                 s_axis_tvalid,   //! Not used (continuous source)
    // verilog_lint: waive-stop unused

    output logic [2*SSR*B-1:0]   m_axis_tdata,
    output logic                 m_axis_tlast,
    output logic                 m_axis_tvalid,

    input  logic [31:0]          scale_reg,
    input  logic [31:0]          qout_reg
);

    localparam int CYCLES = NFFT / SSR;                 // clocks per frame
    localparam int CW     = (CYCLES > 1) ? $clog2(CYCLES) : 1;
    localparam int NWAIT  = 256;                        // clocks after reset

    // ------------------------------------------------------------------
    // Framing
    // ------------------------------------------------------------------
    typedef enum logic [2:0] {INIT_ST, RST_ST, S0_ST, S1_ST, S2_ST} state_t;
    state_t state, state_n;

    logic [7:0]          cnt_nwait;
    logic [CW-1:0]       cnt;
    logic                frame_valid;                   // valid_i of the VHDL
    logic [2*SSR*B-1:0]  data_r, data_rr;
    logic                valid_r, valid_rr;

    assign frame_valid = (state == S0_ST) || (state == S1_ST);

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state     <= INIT_ST;
            data_r    <= '0;
            data_rr   <= '0;
            valid_r   <= 1'b0;
            valid_rr  <= 1'b0;
            cnt_nwait <= '0;
            cnt       <= '0;
        end else begin
            state    <= state_n;
            data_r   <= s_axis_tdata;
            data_rr  <= data_r;
            valid_r  <= frame_valid;
            valid_rr <= valid_r;
            if (state == RST_ST) cnt_nwait <= cnt_nwait + 1'b1;
            if (frame_valid) cnt <= (cnt < CW'(CYCLES - 1)) ? cnt + 1'b1 : '0;
        end
    end

    always_comb begin
        state_n = state;
        case (state)
            INIT_ST: state_n = RST_ST;
            RST_ST:  if (cnt_nwait >= 8'(NWAIT - 1)) state_n = S0_ST;
            S0_ST:   if (s_axis_tlast && cnt != CW'(CYCLES - 1)) state_n = S1_ST;
            S1_ST:   if (cnt == CW'(CYCLES - 1)) state_n = S2_ST;
            S2_ST:   if (s_axis_tlast) state_n = S0_ST;
            default: state_n = INIT_ST;
        endcase
    end

    // ------------------------------------------------------------------
    // FFT
    // ------------------------------------------------------------------
    logic [B-1:0]  fft_re [SSR], fft_im [SSR];
    logic [26:0]   res_re [SSR], res_im [SSR];
    logic [0:0]    fft_ovalid;
    logic [3:0]    qout;

    assign qout = (qout_reg > 32'd11) ? 4'd0 : qout_reg[3:0];

    for (genvar i = 0; i < SSR; i++) begin : g_lane
        assign fft_re[i] = data_rr[i*2*B     +: B];
        assign fft_im[i] = data_rr[i*2*B + B +: B];
        assign m_axis_tdata[i*2*B     +: B] = res_re[i][qout +: B];
        assign m_axis_tdata[i*2*B + B +: B] = res_im[i][qout +: B];
    end

    ssr_8x64 u_fft (
        .clk     (aclk),
        .i_re_0  (fft_re[0]), .i_re_1 (fft_re[1]), .i_re_2 (fft_re[2]), .i_re_3 (fft_re[3]),
        .i_re_4  (fft_re[4]), .i_re_5 (fft_re[5]), .i_re_6 (fft_re[6]), .i_re_7 (fft_re[7]),
        .i_im_0  (fft_im[0]), .i_im_1 (fft_im[1]), .i_im_2 (fft_im[2]), .i_im_3 (fft_im[3]),
        .i_im_4  (fft_im[4]), .i_im_5 (fft_im[5]), .i_im_6 (fft_im[6]), .i_im_7 (fft_im[7]),
        .i_valid (valid_rr),
        .i_scale (scale_reg[5:0]),
        .o_re_0  (res_re[0]), .o_re_1 (res_re[1]), .o_re_2 (res_re[2]), .o_re_3 (res_re[3]),
        .o_re_4  (res_re[4]), .o_re_5 (res_re[5]), .o_re_6 (res_re[6]), .o_re_7 (res_re[7]),
        .o_im_0  (res_im[0]), .o_im_1 (res_im[1]), .o_im_2 (res_im[2]), .o_im_3 (res_im[3]),
        .o_im_4  (res_im[4]), .o_im_5 (res_im[5]), .o_im_6 (res_im[6]), .o_im_7 (res_im[7]),
        .o_valid (fft_ovalid),
        .o_scale ()
    );

    assign m_axis_tvalid = fft_ovalid[0];

    // ------------------------------------------------------------------
    // tlast: last of every CYCLES valid outputs
    // ------------------------------------------------------------------
    logic [CW-1:0] cnt_out;

    always_ff @(posedge aclk) begin
        if (!aresetn)          cnt_out <= '0;
        else if (fft_ovalid[0]) cnt_out <= (cnt_out < CW'(CYCLES - 1)) ? cnt_out + 1'b1 : '0;
    end

    assign m_axis_tlast = (cnt_out == CW'(CYCLES - 1));

endmodule
