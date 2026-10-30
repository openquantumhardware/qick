///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : fifo_async_gated
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    fifo_async_gated.sv
//!
//! @brief   Dual-clock asynchronous FIFO with flush, used by tProcessor v2.
//!
//! @details
//!
//! Replaces the `BRAM_FIFO_DC_2` block originally defined in
//! `firmware/ip/qick_processor/src/_qproc_ips.sv` (XPM macro variant).
//!
//! This is a wrapper over `fifo_async` that:
//! - Maps the legacy `push_i`/`pop_i` gating into write/read enables.
//! - Uses `flush_i` directly as an active-high reset for both clock domains
//!   (assumed to be already synchronized to the system clock, as in the
//!   original design where `flush_i = core_rst`).
//! - Exposes `async_empty_o` and `async_full_o` in the read/write domain
//!   respectively, matching the original interface.
//!
//! @generic
//! FIFO_DW : unsigned int – data width in bits (default 16).
//! FIFO_AW : unsigned int – address width; depth = 2^FIFO_AW (default 8).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////

module fifo_async_gated #(
    parameter int FIFO_DW = 16,
    parameter int FIFO_AW = 8
)(
    input  wire                   wr_clk_i       ,
    input  wire                   wr_rst_ni      ,
    input  wire                   wr_en_i        ,
    input  wire                   push_i         ,
    input  wire [FIFO_DW - 1:0]   data_i         ,
    input  wire                   rd_clk_i       ,
    input  wire                   rd_rst_ni      ,
    input  wire                   rd_en_i        ,
    input  wire                   pop_i          ,
    input  wire                   flush_i        ,
    output wire  [FIFO_DW - 1:0]  data_o         ,
    output wire                   async_empty_o  ,
    output wire                   async_full_o
);

    wire fifo_full, fifo_empty;
    wire [FIFO_DW-1:0] fifo_dout;
    wire wr_rstn_flush, rd_rstn_flush;

    // Use flush_i as active-high reset, OR with domain resets.
    // flush_i is assumed to be synchronized externally (matches original
    // core_rst behavior).
    assign wr_rstn_flush = wr_rst_ni & ~flush_i;
    assign rd_rstn_flush = rd_rst_ni & ~flush_i;

    fifo_async #(
        .B                (FIFO_DW),
        .N                (2**FIFO_AW),
        .READ_MODE        ("fwft"),
        .FIFO_MEMORY_TYPE ("block"),
        .CDC_SYNC_STAGES  (2)
    ) u_fifo (
        .wr_rstn   (wr_rstn_flush),
        .wr_clk    (wr_clk_i),
        .wr_en     (wr_en_i & push_i),
        .din       (data_i),
        .full      (fifo_full),
        .wr_err    (),

        .rd_rstn   (rd_rstn_flush),
        .rd_clk    (rd_clk_i),
        .rd_en     (rd_en_i & pop_i),
        .dout      (fifo_dout),
        .empty     (fifo_empty),
        .data_valid()
    );

    assign data_o        = fifo_dout;
    assign async_empty_o = fifo_empty;
    assign async_full_o  = fifo_full;

endmodule
