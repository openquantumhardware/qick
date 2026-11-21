`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : pfb_ctrl
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    pfb_ctrl.sv
//!
//! @brief   Control of the PFB readouts' polyphase FIRs: sends their one
//!          coefficient-set configuration after reset and generates the
//!          tlast framing that keeps them aligned.
//!
//! @details
//! Faithful port of the legacy VHDL (openquantumhardware/qick firmware/ip/
//! axis_pfb_readout_v4/src/pfb/{pfb_ctrl,pfb_cfg,pfb_framing,
//! pfb_ctrl_pkg}.vhd, identical in v3), the entities merged:
//!
//! - Configuration: once cfg_en and m_axis_config_tready are both high, N
//!   words 0..N-1 go out on N consecutive clocks (tlast on the last; tready
//!   is only looked at to start), assigning coefficient set i to channel i.
//!   Then nothing more is sent until cfg_en drops and rises again. The word
//!   counter is only cleared by reset, so a restart through cfg_en runs on
//!   from N through its wrap back to N-1 (256 words for N = 8), as in the
//!   legacy block; the PFB ties cfg_en high. m_axis_config_tdata is 8 bits
//!   for N <= 256 (the legacy f_nbit_axis).
//! - Framing: fr_out is high while an internal counter of accepted outputs
//!   (tvalid && tready) sits at N-1, i.e. on the FIRs' last channel. When the
//!   FIRs report a missing tlast (fr_sync), the counter skips one output to
//!   shift the frame by one channel, then waits 10*N clocks before listening
//!   to fr_sync again (the FIRs report it a few clocks late).
//! - Synchronous, active-low reset of both state machines.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module pfb_ctrl #(
    parameter  int N        = 8,   //! FIR channels (vector length)
    // Width of the config word: the legacy f_nbit_axis(N), whole bytes.
    localparam int CFG_BITS = ($clog2(N) <= 8)  ? 8  :
                              ($clog2(N) <= 16) ? 16 :
                              ($clog2(N) <= 24) ? 24 : 32
) (
    input  logic                  aresetn,
    input  logic                  aclk,

    output logic                  m_axis_config_tvalid,
    input  logic                  m_axis_config_tready,
    output logic                  m_axis_config_tlast,
    output logic [CFG_BITS-1:0]   m_axis_config_tdata,

    input  logic                  cfg_en,

    input  logic                  tready,
    input  logic                  tvalid,
    input  logic                  fr_sync,
    output logic                  fr_out
);

    localparam int NW       = (N > 1) ? $clog2(N) : 1;
    localparam int WAIT_C   = 10 * N;
    localparam int WW       = $clog2(WAIT_C);

    // ------------------------------------------------------------------
    // Configuration
    // ------------------------------------------------------------------
    typedef enum logic [1:0] {CFG_INIT, CFG_CNT, CFG_END} cfg_state_t;
    cfg_state_t          cfg_state;
    logic [CFG_BITS-1:0] cfg_cnt;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            cfg_state <= CFG_INIT;
            cfg_cnt   <= '0;
        end else begin
            case (cfg_state)
                CFG_INIT: if (cfg_en && m_axis_config_tready) cfg_state <= CFG_CNT;
                CFG_CNT:  if (cfg_cnt == CFG_BITS'(N - 1))     cfg_state <= CFG_END;
                CFG_END:  if (!cfg_en)                         cfg_state <= CFG_INIT;
                default:                                       cfg_state <= CFG_INIT;
            endcase
            if (cfg_state == CFG_CNT) cfg_cnt <= cfg_cnt + 1'b1;
        end
    end

    assign m_axis_config_tvalid = (cfg_state == CFG_CNT);
    assign m_axis_config_tlast  = (cfg_cnt == CFG_BITS'(N - 1));
    assign m_axis_config_tdata  = cfg_cnt;

    // ------------------------------------------------------------------
    // Framing
    // ------------------------------------------------------------------
    typedef enum logic [1:0] {FR_INIT, FR_SHIFT, FR_WAIT} fr_state_t;
    fr_state_t      fr_state;
    logic [NW-1:0]  fr_cnt;
    logic [WW-1:0]  wait_cnt;
    logic           fr_cnt_en;

    assign fr_cnt_en = (fr_state == FR_INIT) || (fr_state == FR_WAIT);

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            fr_state <= FR_INIT;
            fr_cnt   <= '0;
            wait_cnt <= '0;
        end else begin
            case (fr_state)
                FR_INIT:  if (fr_sync) fr_state <= FR_SHIFT;
                FR_SHIFT: fr_state <= FR_WAIT;
                FR_WAIT:  if (wait_cnt == WW'(WAIT_C - 1)) fr_state <= FR_INIT;
                default:  fr_state <= FR_INIT;
            endcase
            if (fr_cnt_en && tready && tvalid)
                fr_cnt <= (fr_cnt < NW'(N - 1)) ? fr_cnt + 1'b1 : '0;
            if (fr_state == FR_WAIT)
                wait_cnt <= (wait_cnt < WW'(WAIT_C - 1)) ? wait_cnt + 1'b1 : '0;
        end
    end

    assign fr_out = (fr_cnt == NW'(N - 1));

endmodule
