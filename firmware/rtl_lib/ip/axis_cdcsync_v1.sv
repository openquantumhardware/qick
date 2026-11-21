`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_cdcsync_v1
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_cdcsync_v1.sv
//!
//! @brief   Carries N AXI4-Stream channels across one clock-domain crossing
//!          together, through a single shared dual-clock FIFO (the tProc
//!          wave ports on their way to the generators' clocks).
//!
//! @details
//! Faithful port of the legacy QICK IP (openquantumhardware/qick firmware/ip/axis_cdcsync_v1/
//! src/{axis_cdcsync_v1.sv,cdcsync.sv} + firmware/hdl/fifo_dc_axi_xpm.sv,
//! QICK:QICK:axis_cdcsync_v1:1.0), with the wrapper and cdcsync merged:
//!
//! - One FIFO word is {valid_i, data_i} for every channel i < N, (B+1)*N bits,
//!   16 deep, first-word fall-through.
//! - A word is written on any s_axis_aclk edge where at least one s<i>_axis
//!   has tvalid; the channels without tvalid are written with valid_i = 0.
//!   Every s<i>_axis_tready (i < N) is ~full.
//! - m<i>_axis_tvalid = valid_i of the head word and not empty. The head word
//!   is popped only when every m<i>_axis_tready (i < N) is high: one output
//!   holding tready low stalls all of them, and the others keep presenting
//!   (and accepting, if their tready is high) the same word until it pops.
//! - s_axis_aresetn resets the FIFO. m_axis_aresetn is not used, as in the
//!   legacy IP.
//!
//! Differences from the legacy IP, both outside the steady state:
//! - The FIFO is qick:mem:fifo_async (the same xpm_fifo_async underneath).
//!   It holds tready low (full) while the FIFO comes out of reset
//!   (wr_rst_busy); the legacy IP showed full = 0 there and the XPM dropped
//!   the accepted words.
//! - Channels with index >= N are not part of the IP. The legacy RTL left
//!   their outputs undriven (X in simulation); here m<i>_axis_tvalid and
//!   tdata are 0 and s<i>_axis_tready is 1 (as in the legacy RTL).
//!
//! Defaults N = 2, B = 8 are those of the legacy packaged IP; the standard BDs
//! set B = 160 (tProc v1) or 168 (tProc v2) and N = 1..4.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_cdcsync_v1 #(
    parameter int N = 2,   //! Number of channels, 1..16
    parameter int B = 8    //! Data width (bits)
) (
    input  logic         s_axis_aresetn,
    input  logic         s_axis_aclk,

    output logic         s0_axis_tready,
    input  logic         s0_axis_tvalid,
    input  logic [B-1:0] s0_axis_tdata,
    output logic         s1_axis_tready,
    input  logic         s1_axis_tvalid,
    input  logic [B-1:0] s1_axis_tdata,
    output logic         s2_axis_tready,
    input  logic         s2_axis_tvalid,
    input  logic [B-1:0] s2_axis_tdata,
    output logic         s3_axis_tready,
    input  logic         s3_axis_tvalid,
    input  logic [B-1:0] s3_axis_tdata,
    output logic         s4_axis_tready,
    input  logic         s4_axis_tvalid,
    input  logic [B-1:0] s4_axis_tdata,
    output logic         s5_axis_tready,
    input  logic         s5_axis_tvalid,
    input  logic [B-1:0] s5_axis_tdata,
    output logic         s6_axis_tready,
    input  logic         s6_axis_tvalid,
    input  logic [B-1:0] s6_axis_tdata,
    output logic         s7_axis_tready,
    input  logic         s7_axis_tvalid,
    input  logic [B-1:0] s7_axis_tdata,
    output logic         s8_axis_tready,
    input  logic         s8_axis_tvalid,
    input  logic [B-1:0] s8_axis_tdata,
    output logic         s9_axis_tready,
    input  logic         s9_axis_tvalid,
    input  logic [B-1:0] s9_axis_tdata,
    output logic         s10_axis_tready,
    input  logic         s10_axis_tvalid,
    input  logic [B-1:0] s10_axis_tdata,
    output logic         s11_axis_tready,
    input  logic         s11_axis_tvalid,
    input  logic [B-1:0] s11_axis_tdata,
    output logic         s12_axis_tready,
    input  logic         s12_axis_tvalid,
    input  logic [B-1:0] s12_axis_tdata,
    output logic         s13_axis_tready,
    input  logic         s13_axis_tvalid,
    input  logic [B-1:0] s13_axis_tdata,
    output logic         s14_axis_tready,
    input  logic         s14_axis_tvalid,
    input  logic [B-1:0] s14_axis_tdata,
    output logic         s15_axis_tready,
    input  logic         s15_axis_tvalid,
    input  logic [B-1:0] s15_axis_tdata,

    // verilog_lint: waive-start unused
    input  logic         m_axis_aresetn,   //! Not used (legacy interface)
    // verilog_lint: waive-stop unused
    input  logic         m_axis_aclk,

    input  logic         m0_axis_tready,
    output logic         m0_axis_tvalid,
    output logic [B-1:0] m0_axis_tdata,
    input  logic         m1_axis_tready,
    output logic         m1_axis_tvalid,
    output logic [B-1:0] m1_axis_tdata,
    input  logic         m2_axis_tready,
    output logic         m2_axis_tvalid,
    output logic [B-1:0] m2_axis_tdata,
    input  logic         m3_axis_tready,
    output logic         m3_axis_tvalid,
    output logic [B-1:0] m3_axis_tdata,
    input  logic         m4_axis_tready,
    output logic         m4_axis_tvalid,
    output logic [B-1:0] m4_axis_tdata,
    input  logic         m5_axis_tready,
    output logic         m5_axis_tvalid,
    output logic [B-1:0] m5_axis_tdata,
    input  logic         m6_axis_tready,
    output logic         m6_axis_tvalid,
    output logic [B-1:0] m6_axis_tdata,
    input  logic         m7_axis_tready,
    output logic         m7_axis_tvalid,
    output logic [B-1:0] m7_axis_tdata,
    input  logic         m8_axis_tready,
    output logic         m8_axis_tvalid,
    output logic [B-1:0] m8_axis_tdata,
    input  logic         m9_axis_tready,
    output logic         m9_axis_tvalid,
    output logic [B-1:0] m9_axis_tdata,
    input  logic         m10_axis_tready,
    output logic         m10_axis_tvalid,
    output logic [B-1:0] m10_axis_tdata,
    input  logic         m11_axis_tready,
    output logic         m11_axis_tvalid,
    output logic [B-1:0] m11_axis_tdata,
    input  logic         m12_axis_tready,
    output logic         m12_axis_tvalid,
    output logic [B-1:0] m12_axis_tdata,
    input  logic         m13_axis_tready,
    output logic         m13_axis_tvalid,
    output logic [B-1:0] m13_axis_tdata,
    input  logic         m14_axis_tready,
    output logic         m14_axis_tvalid,
    output logic [B-1:0] m14_axis_tdata,
    input  logic         m15_axis_tready,
    output logic         m15_axis_tvalid,
    output logic [B-1:0] m15_axis_tdata
);

    localparam int BD = B + 1;      // one channel: {valid, data}
    localparam int BT = N * BD;     // one FIFO word

    logic [B-1:0]  s_data  [16];
    logic [15:0]   s_valid;
    logic [15:0]   s_ready;
    logic [B-1:0]  m_data  [16];
    logic [15:0]   m_valid;
    logic [15:0]   m_ready;

    logic          fifo_wr_en, fifo_rd_en, fifo_full, fifo_empty;
    logic [BT-1:0] fifo_din, fifo_dout;

    // Flat ports <-> arrays.
    assign s_data = '{s0_axis_tdata,  s1_axis_tdata,  s2_axis_tdata,  s3_axis_tdata,
                      s4_axis_tdata,  s5_axis_tdata,  s6_axis_tdata,  s7_axis_tdata,
                      s8_axis_tdata,  s9_axis_tdata,  s10_axis_tdata, s11_axis_tdata,
                      s12_axis_tdata, s13_axis_tdata, s14_axis_tdata, s15_axis_tdata};
    assign s_valid = {s15_axis_tvalid, s14_axis_tvalid, s13_axis_tvalid, s12_axis_tvalid,
                      s11_axis_tvalid, s10_axis_tvalid, s9_axis_tvalid,  s8_axis_tvalid,
                      s7_axis_tvalid,  s6_axis_tvalid,  s5_axis_tvalid,  s4_axis_tvalid,
                      s3_axis_tvalid,  s2_axis_tvalid,  s1_axis_tvalid,  s0_axis_tvalid};
    assign {s15_axis_tready, s14_axis_tready, s13_axis_tready, s12_axis_tready,
            s11_axis_tready, s10_axis_tready, s9_axis_tready,  s8_axis_tready,
            s7_axis_tready,  s6_axis_tready,  s5_axis_tready,  s4_axis_tready,
            s3_axis_tready,  s2_axis_tready,  s1_axis_tready,  s0_axis_tready} = s_ready;

    assign m_ready = {m15_axis_tready, m14_axis_tready, m13_axis_tready, m12_axis_tready,
                      m11_axis_tready, m10_axis_tready, m9_axis_tready,  m8_axis_tready,
                      m7_axis_tready,  m6_axis_tready,  m5_axis_tready,  m4_axis_tready,
                      m3_axis_tready,  m2_axis_tready,  m1_axis_tready,  m0_axis_tready};
    assign {m15_axis_tvalid, m14_axis_tvalid, m13_axis_tvalid, m12_axis_tvalid,
            m11_axis_tvalid, m10_axis_tvalid, m9_axis_tvalid,  m8_axis_tvalid,
            m7_axis_tvalid,  m6_axis_tvalid,  m5_axis_tvalid,  m4_axis_tvalid,
            m3_axis_tvalid,  m2_axis_tvalid,  m1_axis_tvalid,  m0_axis_tvalid} = m_valid;
    assign m0_axis_tdata  = m_data[0];
    assign m1_axis_tdata  = m_data[1];
    assign m2_axis_tdata  = m_data[2];
    assign m3_axis_tdata  = m_data[3];
    assign m4_axis_tdata  = m_data[4];
    assign m5_axis_tdata  = m_data[5];
    assign m6_axis_tdata  = m_data[6];
    assign m7_axis_tdata  = m_data[7];
    assign m8_axis_tdata  = m_data[8];
    assign m9_axis_tdata  = m_data[9];
    assign m10_axis_tdata = m_data[10];
    assign m11_axis_tdata = m_data[11];
    assign m12_axis_tdata = m_data[12];
    assign m13_axis_tdata = m_data[13];
    assign m14_axis_tdata = m_data[14];
    assign m15_axis_tdata = m_data[15];

    // Channels: pack into / unpack from the FIFO word. Channels >= N are
    // outside the IP: never valid, never holding the read.
    logic [15:0] ch_valid;   // s<i>_axis_tvalid of the channels that exist
    logic [15:0] ch_ready;   // m<i>_axis_tready, 1 for the channels that don't

    for (genvar i = 0; i < 16; i++) begin : g_ch
        if (i < N) begin : g_used
            assign ch_valid[i]          = s_valid[i];
            assign ch_ready[i]          = m_ready[i];
            assign s_ready[i]           = ~fifo_full;
            assign fifo_din[BD*i +: BD] = {s_valid[i], s_data[i]};
            assign m_data[i]            = fifo_dout[BD*i +: B];
            assign m_valid[i]           = fifo_dout[BD*i + B] & ~fifo_empty;
        end else begin : g_unused
            assign ch_valid[i] = 1'b0;
            assign ch_ready[i] = 1'b1;
            assign s_ready[i]  = 1'b1;
            assign m_data[i]   = '0;
            assign m_valid[i]  = 1'b0;
        end
    end

    assign fifo_wr_en = |ch_valid;
    assign fifo_rd_en = &ch_ready;

    // rd_rstn is tied off: xpm_fifo_async's reset must be synchronous to
    // wr_clk, and the legacy IP reset the FIFO from s_axis_aresetn only.
    fifo_async #(
        .B                (BT),
        .N                (16),
        .READ_MODE        ("fwft"),
        .FIFO_MEMORY_TYPE ("auto"),
        .CDC_SYNC_STAGES  (2)
    ) u_fifo (
        .wr_rstn    (s_axis_aresetn),
        .wr_clk     (s_axis_aclk),
        .wr_en      (fifo_wr_en),
        .din        (fifo_din),
        .full       (fifo_full),
        .wr_err     (),
        .rd_rstn    (1'b1),
        .rd_clk     (m_axis_aclk),
        .rd_en      (fifo_rd_en),
        .dout       (fifo_dout),
        .empty      (fifo_empty),
        .data_valid ()
    );

endmodule
