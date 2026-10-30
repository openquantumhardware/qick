`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : sg_int4_top
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    sg_int4_top.sv
//!
//! @brief   Top-level of the interpolated (x4) arbitrary signal generator.
//!
//! @details
//! Assembles axis_sg_int4_v2 from the same verified building blocks as
//! sgv4_top, differing in the envelope memory: ONE real + ONE imag bank
//! (not N_DDS parallel banks) with the datapath (sg_int4) reconstructing
//! N_DDS=4 interpolated samples per address via fir_interp4_sgint.
//!
//! Building blocks:
//!
//! - fifo_sync       : waveform-descriptor FIFO (160-bit, depth 16).
//! - axis_to_bram_sg : AXI4-Stream envelope writer, single table (not _nt).
//! - bram_tdp (x2)   : dual-port, dual-clock envelope memories (real+imag).
//! - sg_int4         : datapath (envelope FIR-interpolation x DDS, gain).
//!
//! Two clock domains:
//!
//! - s0_axis_aclk : envelope loading (BRAM port A write side).
//! - aclk         : descriptor FIFO, sg_int4, BRAM port B read side, output.
//! The dual-clock BRAM (bram_tdp) resolves the crossing.
//!
//! Envelope memory layout: ONE bank pair, each 16 bits wide and 2**N deep.
//! The 32-bit stream word is split: din[15:0] -> real, din[31:16] -> imag.
//!
//! Registers (from the top-level AXI-Lite slave, mirroring legacy):
//!
//! - start_addr_reg : envelope write start address.
//! - we_reg         : envelope write enable (capture).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module sg_int4_top #(
    parameter int N     = 16,  //! Envelope-memory address width (depth 2**N).
    parameter int N_DDS = 4    //! Number of interpolated lanes (fixed by the FIR: x4).
)(
    // Reset and clock (main domain).
    input  logic                 aresetn,          //! Active-low sync reset (aclk domain).
    input  logic                 aclk,             //! Main clock (FIFO, sg_int4, read side, output).
    // AXIS slave: envelope sample loading.
    input  logic                 s0_axis_aresetn,  //! Active-low sync reset (envelope-load domain).
    input  logic                 s0_axis_aclk,     //! Envelope-load clock (BRAM port A).
    input  logic [31:0]          s0_axis_tdata_i,  //! 32-bit envelope word: [15:0]=real, [31:16]=imag.
    input  logic                 s0_axis_tvalid_i, //! Envelope stream valid.
    output logic                 s0_axis_tready_o, //! Envelope stream ready.
    // AXIS slave: waveform descriptor queue.
    input  logic [159:0]         s1_axis_tdata_i,  //! 160-bit waveform descriptor (v4/int4 layout).
    input  logic                 s1_axis_tvalid_i, //! Descriptor valid.
    output logic                 s1_axis_tready_o, //! Descriptor ready (FIFO not full).
    // M_AXIS output.
    input  logic                 m_axis_tready_i,  //! Output ready.
    output logic                 m_axis_tvalid_o,  //! Output valid.
    output logic [N_DDS*32-1:0]  m_axis_tdata_o,   //! N_DDS x 32-bit {imag,real} output samples.
    // Registers.
    input  logic [31:0]          start_addr_reg,   //! Envelope write start address.
    input  logic                 we_reg            //! Envelope write enable (capture).
);

    // --------------------------------------------------------------------------
    // FIFO signals.
    // --------------------------------------------------------------------------
    logic         fifo_wr_en;
    logic [159:0] fifo_din;
    logic         fifo_rd_en;
    logic [159:0] fifo_dout;
    logic         fifo_full;
    logic         fifo_empty;

    // --------------------------------------------------------------------------
    // Envelope memory: read side (aclk).
    // --------------------------------------------------------------------------
    logic [N-1:0] mem_addrb;
    logic [15:0]  mem_dob_real;
    logic [15:0]  mem_dob_imag;

    logic mem_en;

    // --------------------------------------------------------------------------
    // Waveform descriptor FIFO.
    // --------------------------------------------------------------------------
    fifo_sync #(
        .B         (160),
        .N         (16),
        // legacy FIFO semantics: the ctrl latches the descriptor one cycle
        // after rd_en (see fifo_sync header)
        .HOLD_DOUT (1'b1)
    ) fifo_i (
        .rstn          (aresetn),
        .clk           (aclk),
        .wr_en         (fifo_wr_en),
        .din           (fifo_din),
        .rd_en         (fifo_rd_en),
        .dout          (fifo_dout),
        .full          (fifo_full),
        .empty         (fifo_empty),
        .wr_data_count (),
        .rd_data_count (),
        .prog_full     (),
        .prog_empty    ()
    );

    assign fifo_wr_en = s1_axis_tvalid_i & s1_axis_tready_o;
    assign fifo_din   = s1_axis_tdata_i;

    // --------------------------------------------------------------------------
    // Envelope write interfaces (s0_axis_aclk domain).
    // --------------------------------------------------------------------------
    axi4_stream_if #(.TDATA_WIDTH(32)) axis_wr (
        .aclk    (s0_axis_aclk),
        .aresetn (s0_axis_aresetn)
    );

    bram_if #(.NB_DATA(32), .NB_ADDR(N)) bram_wr (
        .i_clk (s0_axis_aclk),
        .i_rst (~s0_axis_aresetn)
    );

    assign axis_wr.tdata    = s0_axis_tdata_i;
    assign axis_wr.tvalid   = s0_axis_tvalid_i;
    assign s0_axis_tready_o = axis_wr.tready;
    assign axis_wr.tlast    = 1'b0;

    // --------------------------------------------------------------------------
    // Envelope writer: AXIS -> shared BRAM write port (single table).
    // --------------------------------------------------------------------------
    axis_to_bram_sg #(
        .N (N),
        .B (32)
    ) writer_i (
        .rstn           (s0_axis_aresetn),
        .clk            (s0_axis_aclk),
        .axis           (axis_wr.slave),
        .bram           (bram_wr.master),
        .start_addr_reg (start_addr_reg),
        .capture_reg    (we_reg),
        .o_overflow     ()
    );

    assign mem_en = 1'b1;

    // --------------------------------------------------------------------------
    // Envelope memories: single bank pair, real + imag.
    //   Port A (write, s0_axis_aclk): din split real/imag.
    //   Port B (read, aclk):          mem_addrb from sg_int4.
    // --------------------------------------------------------------------------
    bram_tdp #(
        .NB_DATA (16),
        .NB_ADDR (N)
    ) mem_real_i (
        .clka  (s0_axis_aclk),
        .rsta  (~s0_axis_aresetn),
        .ena   (mem_en),
        .wea   (bram_wr.we),
        .addra (bram_wr.addr),
        .dia   (bram_wr.din[15:0]),
        .doa   (),
        .clkb  (aclk),
        .rstb  (~aresetn),
        .enb   (1'b1),
        .web   (1'b0),
        .addrb (mem_addrb),
        .dib   (16'h0000),
        .dob   (mem_dob_real)
    );

    bram_tdp #(
        .NB_DATA (16),
        .NB_ADDR (N)
    ) mem_imag_i (
        .clka  (s0_axis_aclk),
        .rsta  (~s0_axis_aresetn),
        .ena   (mem_en),
        .wea   (bram_wr.we),
        .addra (bram_wr.addr),
        .dia   (bram_wr.din[31:16]),
        .doa   (),
        .clkb  (aclk),
        .rstb  (~aresetn),
        .enb   (1'b1),
        .web   (1'b0),
        .addrb (mem_addrb),
        .dib   (16'h0000),
        .dob   (mem_dob_imag)
    );

    // --------------------------------------------------------------------------
    // Signal generator datapath.
    // --------------------------------------------------------------------------
    sg_int4 #(
        .N     (N),
        .N_DDS (N_DDS)
    ) sg_int4_i (
        .rstn (aresetn),
        .clk  (aclk),

        .fifo_rd_en_o (fifo_rd_en),
        .fifo_empty_i (fifo_empty),
        .fifo_dout_i  (fifo_dout),

        .mem_addr_o      (mem_addrb),
        .mem_dout_real_i (mem_dob_real),
        .mem_dout_imag_i (mem_dob_imag),

        .m_axis_tready_i (m_axis_tready_i),
        .m_axis_tvalid_o (m_axis_tvalid_o),
        .m_axis_tdata_o  (m_axis_tdata_o)
    );

    // --------------------------------------------------------------------------
    // Descriptor backpressure.
    // --------------------------------------------------------------------------
    assign s1_axis_tready_o = ~fifo_full;

endmodule
