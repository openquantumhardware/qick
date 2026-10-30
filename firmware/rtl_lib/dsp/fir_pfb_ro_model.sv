`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : fir_pfb_ro_model
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    fir_pfb_ro_model.sv
//!
//! @brief   Simulation model of the PFB readouts' polyphase FIRs (Xilinx FIR
//!          Compiler 7.2, the configuration of fir_pfb_ro_0..7), bit- and
//!          cycle-exact against the real core.
//!
//! @details
//! The configuration it models (every fir_pfb_ro_<i>.xci): Interpolated,
//! Zero_Pack_Factor 2, 8 channels, 2 paths (I at [15:0], Q at [31:16]),
//! 16-bit data and coefficients, 8 coefficient sets chosen By_Channel through
//! the config channel, Symmetric_Rounding_to_Zero to 16 bits, Vector_Framing
//! tlast, input FIFO, no TREADY on the output, no ARESETn. What it does:
//!
//! - A free-running channel counter advances on every accepted input (it has
//!   no reset and never follows tlast). Channel c keeps its last 13 samples;
//!   out = round(sum_k COEFFS[set*NTAPS + k] * x[c][n - ZP*k] / 2^15), rounding
//!   to nearest with ties toward zero. The accumulator never overflows with
//!   these coefficients (max sum |c| per set 32466 < 2^15).
//! - Output LAT = 18 clocks after the input, one output per input (gaps
//!   included); m_axis_data_tlast on channel NCH-1.
//! - Coefficient sets: all channels start on set 0. A config packet of NCH
//!   set numbers is stored as it arrives; once complete, it is consumed from
//!   the next vector start (channel 0), one word per accepted input, and the
//!   new sets apply from that vector.
//! - event_s_data_tlast_missing/unexpected: tlast absent on channel NCH-1 /
//!   present on another channel. The first event stage updates only on an
//!   accepted input and holds through gaps, then EVLAT-1 = 3 more clocks.
//! - event_s_config_tlast_missing/unexpected: checked as each config word is
//!   consumed, a one-clock pulse CFG_EVLAT = 6 clocks later.
//! - s_axis_data_tready and s_axis_config_tready are constant 1.
//!
//! Checked against fir_compiler_v7_2 generated from each of the eight .xci
//! (tests/vendor/): data, tvalid, tlast, all four events and both treadys
//! equal on every clock, 8079 outputs per FIR, over config, reconfig, no
//! config, misaligned tlast, random input gaps, malformed config packets,
//! rounding ties and full-scale inputs.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module fir_pfb_ro_model #(
    parameter int NCH   = 8,     //! TDM channels
    parameter int NTAPS = 7,     //! Taps per coefficient set
    parameter int ZP    = 2,     //! Zero-packing factor (tap spacing)
    parameter int LAT   = 18,    //! Clocks from input to output
    parameter int EVLAT = 4,     //! Clocks from input to its data event
    parameter int signed COEFFS [NCH*NTAPS] = '{default: 0}  //! Set-major coefficients
) (
    input  logic        aclk,
    input  logic        s_axis_data_tvalid,
    output logic        s_axis_data_tready,
    input  logic        s_axis_data_tlast,
    input  logic [31:0] s_axis_data_tdata,
    input  logic        s_axis_config_tvalid,
    output logic        s_axis_config_tready,
    input  logic        s_axis_config_tlast,
    input  logic [7:0]  s_axis_config_tdata,
    output logic        m_axis_data_tvalid,
    output logic        m_axis_data_tlast,
    output logic [31:0] m_axis_data_tdata,
    output logic        event_s_data_tlast_missing,
    output logic        event_s_data_tlast_unexpected,
    output logic        event_s_config_tlast_missing,
    output logic        event_s_config_tlast_unexpected
);

    localparam int HL        = (NTAPS - 1) * ZP + 1;   // history per channel
    localparam int CFG_EVLAT = 6;

    assign s_axis_data_tready   = 1'b1;
    assign s_axis_config_tready = 1'b1;

    // Rounding to 16 bits, nearest with ties toward zero.
    function automatic logic [15:0] rnd(input longint acc);
        longint half, q;
        half = 64'sd1 <<< 14;
        if (acc >= 0) q = (acc + half - 1) >>> 15;
        else          q = -((-acc + half - 1) >>> 15);
        return 16'(q);
    endfunction

    // State. The real core has no reset: everything starts at zero.
    int                 ch       = 0;      // channel of the next input
    int                 set_act [NCH];     // coefficient set per channel
    int                 set_new [NCH];     // received config packet
    bit                 last_new[NCH];     // its tlast bits
    int                 cfg_cnt  = 0;      // config words received
    bit                 cfg_pend = 1'b0;   // complete packet waiting
    int                 cons_idx = -1;     // config word being consumed
    logic signed [15:0] hist_i [NCH][HL];
    logic signed [15:0] hist_q [NCH][HL];

    logic [LAT-1:0]       pv = '0, pl = '0;
    logic [31:0]          pd [LAT];
    logic [EVLAT-1:0]     pmiss = '0, punexp = '0;
    logic [CFG_EVLAT-1:0] pcmiss = '0, pcunexp = '0;

    initial begin
        for (int c = 0; c < NCH; c++) begin
            set_act[c] = 0; set_new[c] = 0; last_new[c] = 1'b0;
            for (int k = 0; k < HL; k++) begin hist_i[c][k] = '0; hist_q[c][k] = '0; end
        end
        for (int k = 0; k < LAT; k++) pd[k] = '0;
    end

    always @(posedge aclk) begin
        logic        v_in, l_in, miss, unexp, cmiss, cunexp;
        logic [31:0] d_in;
        int          cons;
        v_in = 1'b0; l_in = 1'b0; d_in = '0;
        miss = 1'b0; unexp = 1'b0; cmiss = 1'b0; cunexp = 1'b0; cons = -1;

        // Data sample (sees the config state before this clock's config word).
        if (s_axis_data_tvalid) begin
            longint acc_i, acc_q;
            if (ch == 0 && cfg_pend) begin
                for (int c = 0; c < NCH; c++) set_act[c] = set_new[c];
                cfg_pend = 1'b0;
                cons     = 0;
            end else if (cons_idx >= 0 && cons_idx < NCH - 1) begin
                cons     = cons_idx + 1;
            end
            if (cons >= 0) begin
                cmiss  = (cons == NCH - 1) && !last_new[cons];
                cunexp = (cons != NCH - 1) &&  last_new[cons];
            end
            cons_idx = (cons == NCH - 1) ? -1 : cons;

            for (int k = HL - 1; k > 0; k--) begin
                hist_i[ch][k] = hist_i[ch][k-1];
                hist_q[ch][k] = hist_q[ch][k-1];
            end
            hist_i[ch][0] = s_axis_data_tdata[15:0];
            hist_q[ch][0] = s_axis_data_tdata[31:16];
            acc_i = 0; acc_q = 0;
            for (int k = 0; k < NTAPS; k++) begin
                acc_i += longint'(COEFFS[set_act[ch]*NTAPS + k]) * hist_i[ch][k*ZP];
                acc_q += longint'(COEFFS[set_act[ch]*NTAPS + k]) * hist_q[ch][k*ZP];
            end
            v_in  = 1'b1;
            l_in  = (ch == NCH - 1);
            d_in  = {rnd(acc_q), rnd(acc_i)};
            miss  = (ch == NCH - 1) && !s_axis_data_tlast;
            unexp = (ch != NCH - 1) &&  s_axis_data_tlast;
            ch    = (ch == NCH - 1) ? 0 : ch + 1;
        end

        // Config word.
        if (s_axis_config_tvalid) begin
            set_new[cfg_cnt]  = int'(s_axis_config_tdata);
            last_new[cfg_cnt] = s_axis_config_tlast;
            if (cfg_cnt == NCH - 1) begin
                cfg_cnt  = 0;
                cfg_pend = 1'b1;
            end else begin
                cfg_cnt  = cfg_cnt + 1;
            end
        end

        // Pipelines.
        pv <= {pv[LAT-2:0], v_in};
        pl <= {pl[LAT-2:0], l_in};
        for (int k = LAT - 1; k > 0; k--) pd[k] <= pd[k-1];
        pd[0] <= d_in;
        pmiss[0]  <= s_axis_data_tvalid ? miss  : pmiss[0];
        punexp[0] <= s_axis_data_tvalid ? unexp : punexp[0];
        for (int k = 1; k < EVLAT; k++) begin
            pmiss[k]  <= pmiss[k-1];
            punexp[k] <= punexp[k-1];
        end
        pcmiss  <= {pcmiss[CFG_EVLAT-2:0], cmiss};
        pcunexp <= {pcunexp[CFG_EVLAT-2:0], cunexp};
    end

    assign m_axis_data_tvalid              = pv[LAT-1];
    assign m_axis_data_tlast               = pl[LAT-1] & pv[LAT-1];
    assign m_axis_data_tdata               = pd[LAT-1];
    assign event_s_data_tlast_missing      = pmiss[EVLAT-1];
    assign event_s_data_tlast_unexpected   = punexp[EVLAT-1];
    assign event_s_config_tlast_missing    = pcmiss[CFG_EVLAT-1];
    assign event_s_config_tlast_unexpected = pcunexp[CFG_EVLAT-1];

endmodule
