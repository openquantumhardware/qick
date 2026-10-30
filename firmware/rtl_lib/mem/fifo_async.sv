///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : fifo_async
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    fifo_async.sv
//!
//! @brief   TODO: one-line description.
//!
//! @author  QICK Development Team
//!
//! @version 1.0

module fifo_async #(
    // -----------------------------------------------------------------
    //  Parameters – keep the same names that the test‑bench uses
    // -----------------------------------------------------------------
    parameter int B = 32,                       // Data width  (WRITE/READ_DATA_WIDTH)
    parameter int N = 2048,                     // FIFO depth (FIFO_WRITE_DEPTH)
    parameter     READ_MODE        = "std",     // "std" | "fwft"
    parameter     FIFO_MEMORY_TYPE = "block",   // "auto" | "block" | "distributed"
    parameter int CDC_SYNC_STAGES  = 2          // Number of synchronization stages for CDC
) (
    // -----------------------------------------------------------------
    //  Write domain (active‑low reset, as used by the test‑bench)
    // -----------------------------------------------------------------
    input  logic               wr_rstn,   // active‑low reset
    input  logic               wr_clk,
    input  logic               wr_en,
    input  logic [B-1:0]       din,
    output logic               full,
    output logic               wr_err,    // overflow flag

    // -----------------------------------------------------------------
    //  Read domain (active‑low reset)
    // -----------------------------------------------------------------
    input  logic               rd_rstn,   // active‑low reset
    input  logic               rd_clk,
    input  logic               rd_en,
    output logic [B-1:0]       dout,
    output logic               empty,
    output logic               data_valid // same meaning as XPM's "valid"
);

    // fwft OBLIGATES latency 0 (rule XPM)
    localparam int RD_LATENCY = (READ_MODE == "fwft") ? 0 : 1;

    // Calculate the exact required width for data counters dynamically
    localparam int CNT_WIDTH = $clog2(N) + 1;

    // -----------------------------------------------------------------
    //  Convert active‑low resets to the active‑high version required by
    //  XPM_FIFO_ASYNC (XPM uses a single reset input named "rst").
    // -----------------------------------------------------------------
    logic rst;                     // active‑high reset for the XPM
    assign rst = ~wr_rstn | ~rd_rstn;   // OR of the two active‑low resets

    // -----------------------------------------------------------------
    //  Unused XPM signals (tied‑off)
    // -----------------------------------------------------------------
    logic sleep_i = 1'b0;
    logic wr_rst_busy, rd_rst_busy;
    logic full_i, empty_i;              // raw XPM flags

    //! Hold backpressure while the FIFO is still coming out of reset: XPM keeps
    //! wr_rst_busy high for several cycles AFTER rst deasserts and silently drops
    //! writes during that window. Without this, an upstream master sees full=0,
    //! transfers, and the data disappears.
    assign full  = full_i  | wr_rst_busy;
    assign empty = empty_i | rd_rst_busy;

    // -----------------------------------------------------------------
    //  XPM_FIFO_ASYNC instance – exactly the parameter set you posted
    // -----------------------------------------------------------------
    xpm_fifo_async #(
        .CASCADE_HEIGHT      (0),
        .CDC_SYNC_STAGES     (CDC_SYNC_STAGES),
        .DOUT_RESET_VALUE    ("0"),
        .ECC_MODE            ("no_ecc"),
        .FIFO_MEMORY_TYPE    (FIFO_MEMORY_TYPE),
        .FIFO_READ_LATENCY   (RD_LATENCY),          // one‑cycle read latency (STD mode)
        .FIFO_WRITE_DEPTH    (N),
        .FULL_RESET_VALUE    (0),
        .PROG_EMPTY_THRESH   (5),
        .PROG_FULL_THRESH    (N-5),
        .RD_DATA_COUNT_WIDTH (CNT_WIDTH),
        .READ_DATA_WIDTH     (B),
        .READ_MODE           (READ_MODE),      // matches the test‑bench expectations
        .RELATED_CLOCKS      (0),
        .SIM_ASSERT_CHK      (0),
        .USE_ADV_FEATURES    ("1707"),
        .WAKEUP_TIME         (0),
        .WRITE_DATA_WIDTH    (B),
        .WR_DATA_COUNT_WIDTH (CNT_WIDTH)
    ) u_fifo_async (
        // -------------------------------------------------------------
        //  Global control
        // -------------------------------------------------------------
        .rst          (rst),          // single active‑high reset
        .sleep        (sleep_i),

        // -------------------------------------------------------------
        //  Write side
        // -------------------------------------------------------------
        .wr_clk       (wr_clk),
        .wr_en        (wr_en & ~wr_rst_busy), // gated like in the original IP
        .din          (din),
        .full         (full_i),
        .overflow     (wr_err),
        .wr_ack       ( ),
        .wr_data_count( ),
        .prog_full    ( ),
        .wr_rst_busy  (wr_rst_busy),

        // -------------------------------------------------------------
        //  Read side
        // -------------------------------------------------------------
        .rd_clk       (rd_clk),
        .rd_en        (rd_en & ~rd_rst_busy), // gated
        .dout         (dout),
        .empty        (empty_i),
        .data_valid   (data_valid),   // XPM's "valid" → test‑bench name
        .underflow    ( ),
        .rd_data_count( ),
        .prog_empty   ( ),
        .rd_rst_busy  (rd_rst_busy),

        // -------------------------------------------------------------
        //  Optional / unused ports
        // -------------------------------------------------------------
        .injectsbiterr(1'b0),
        .injectdbiterr(1'b0),
        .sbiterr      ( ),
        .dbiterr      ( )
    );

endmodule
