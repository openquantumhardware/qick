`timescale 1ns/1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_tprocv1
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_tprocv1.sv
//!
//! @brief     Top-level wrapper for the QICK tProcessor V1. Assembles:
//!
//! @details
//!
//! axi_slv_tprocv1: custom AXI4-Lite slave (registers + single DMEM access)
//! dmem           : data-memory arbiter (single R/W, AXIS read, AXIS write)
//! bram_tdp       : true dual-port data memory (port A = AXI side,
//! port B = tProcessor side)
//! tprocv1        : the tProcessor core (program execution, 4 in / 8 out
//! AXI4-Stream channels)
//!
//! Two clock domains:
//!
//! - s_axi_aclk : AXI-Lite configuration + DMEM port A + dmem arbiter.
//! - aclk       : tProcessor core + DMEM port B.
//!
//! AXIS top-level ports are kept FLAT (Vivado IP / block-design compatible).
//! Internally they are bridged to axi4_stream_if instances required by
//! dmem (s0/m0, 32-bit) and tprocv1 (s1..s4 64-bit in, m1..m8 160-bit out).
//!
//! Driver compatibility: axi_slv_tprocv1 (custom) is retained unchanged so
//! the existing Python driver (register access + single_read/single_write
//! via the upper AXI address map) works without modification.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module axis_tprocv1 #(
    //! program memory depth (log2 of 64-bit words)
    parameter int PMEM_N = 16,
    //! data memory depth    (log2 of 32-bit words)
    parameter int DMEM_N = 10
)(
    //==========================================================================
    // s_axi_aclk domain
    //==========================================================================
    input  logic        s_axi_aclk,
    input  logic        s_axi_aresetn,

    // AXI4-Lite slave (configuration)
    input  logic [31:0] s_axi_awaddr,
    input  logic [2:0]  s_axi_awprot,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,
    input  logic [31:0] s_axi_araddr,
    input  logic [2:0]  s_axi_arprot,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // Slave AXIS for writing into Data Memory (32-bit)
    input  logic        s0_axis_aclk,    // IF only, not connected
    input  logic        s0_axis_aresetn, // IF only, not connected
    input  logic [31:0] s0_axis_tdata,
    input  logic        s0_axis_tlast,
    input  logic        s0_axis_tvalid,
    output logic        s0_axis_tready,

    // Master AXIS 0 to read from Data Memory (32-bit)
    input  logic        m0_axis_aclk,    // IF only, not connected
    input  logic        m0_axis_aresetn, // IF only, not connected
    output logic [31:0] m0_axis_tdata,
    output logic        m0_axis_tlast,
    output logic        m0_axis_tvalid,
    input  logic        m0_axis_tready,

    //==========================================================================
    // aclk domain
    //==========================================================================
    input  logic        aclk,
    input  logic        aresetn,

    // Start/stop
    input  logic        start,

    // Program Memory Interface
    output logic [PMEM_N-1:0] pmem_addr,
    input  logic [63:0]       pmem_do,

    // Slave AXIS 1..4 ("read" on tProcessor, 64-bit)
    input  logic [63:0] s1_axis_tdata,
    input  logic        s1_axis_tvalid,
    output logic        s1_axis_tready,
    input  logic [63:0] s2_axis_tdata,
    input  logic        s2_axis_tvalid,
    output logic        s2_axis_tready,
    input  logic [63:0] s3_axis_tdata,
    input  logic        s3_axis_tvalid,
    output logic        s3_axis_tready,
    input  logic [63:0] s4_axis_tdata,
    input  logic        s4_axis_tvalid,
    output logic        s4_axis_tready,

    // Master AXIS 1..8 (channels 0..7, 160-bit)
    output logic [159:0] m1_axis_tdata,
    output logic         m1_axis_tvalid,
    input  logic         m1_axis_tready,
    output logic [159:0] m2_axis_tdata,
    output logic         m2_axis_tvalid,
    input  logic         m2_axis_tready,
    output logic [159:0] m3_axis_tdata,
    output logic         m3_axis_tvalid,
    input  logic         m3_axis_tready,
    output logic [159:0] m4_axis_tdata,
    output logic         m4_axis_tvalid,
    input  logic         m4_axis_tready,
    output logic [159:0] m5_axis_tdata,
    output logic         m5_axis_tvalid,
    input  logic         m5_axis_tready,
    output logic [159:0] m6_axis_tdata,
    output logic         m6_axis_tvalid,
    input  logic         m6_axis_tready,
    output logic [159:0] m7_axis_tdata,
    output logic         m7_axis_tvalid,
    input  logic         m7_axis_tready,
    output logic [159:0] m8_axis_tdata,
    output logic         m8_axis_tvalid,
    input  logic         m8_axis_tready
);

    //==========================================================================
    // Internal connections
    //==========================================================================
    // Program memory address (internal, 64-bit word based)
    logic [PMEM_N-1:0] pmem_addr_int;

    // axi_slv_tprocv1 (custom) <-> dmem single-access handshake
    logic              busy_int;
    logic              oper_int;
    logic [31:0]       addr_int;       // 32-bit from slave; truncated below
    logic [31:0]       dwrite_int;
    logic [31:0]       dread_int;
    logic              exec_int;
    logic              exec_ack_int;

    // Control registers
    logic              start_src_reg;
    logic              start_reg;
    logic              mem_mode_reg;
    logic              mem_start_reg;
    logic [31:0]       mem_addr_reg;
    logic [31:0]       mem_len_reg;

    // dmem -> bram port A
    logic              dmem_wea;
    logic [DMEM_N-1:0] dmem_addra;
    logic [31:0]       dmem_dia;
    logic [31:0]       dmem_doa;

    // tProc -> bram port B
    logic              dmem_web;
    logic [DMEM_N-1:0] dmem_addrb;
    logic [31:0]       dmem_dib;
    logic [31:0]       dmem_dob;

    //==========================================================================
    // AXI4-Stream interface instances (bridge flat ports <-> dmem / tprocv1)
    //==========================================================================
    // dmem AXIS write (s0) and read (m0): 32-bit, s_axi_aclk domain
    axi4_stream_if #(.TDATA_WIDTH(32)) s0_if (.aclk(s_axi_aclk), .aresetn(s_axi_aresetn));
    axi4_stream_if #(.TDATA_WIDTH(32)) m0_if (.aclk(s_axi_aclk), .aresetn(s_axi_aresetn));

    // tProc slave inputs s1..s4: 64-bit, aclk domain
    axi4_stream_if #(.TDATA_WIDTH(64)) s1_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(64)) s2_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(64)) s3_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(64)) s4_if (.aclk(aclk), .aresetn(aresetn));

    // tProc master outputs m1..m8: 160-bit, aclk domain
    axi4_stream_if #(.TDATA_WIDTH(160)) m1_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m2_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m3_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m4_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m5_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m6_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m7_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m8_if (.aclk(aclk), .aresetn(aresetn));

    //==========================================================================
    // Flat <-> interface wiring
    //==========================================================================
    // s0 : external master drives -> s0_if (consumed by dmem as slave)
    assign s0_if.tdata    = s0_axis_tdata;
    assign s0_if.tlast    = s0_axis_tlast;
    assign s0_if.tvalid   = s0_axis_tvalid;
    assign s0_axis_tready = s0_if.tready;

    // m0 : m0_if (driven by dmem as master) -> external flat outputs
    assign m0_axis_tdata  = m0_if.tdata;
    assign m0_axis_tlast  = m0_if.tlast;
    assign m0_axis_tvalid = m0_if.tvalid;
    assign m0_if.tready   = m0_axis_tready;

    // s1..s4 : external masters drive -> interface slaves (consumed by tprocv1)
    assign s1_if.tdata = s1_axis_tdata; assign s1_if.tvalid = s1_axis_tvalid; assign s1_axis_tready = s1_if.tready;
    assign s2_if.tdata = s2_axis_tdata; assign s2_if.tvalid = s2_axis_tvalid; assign s2_axis_tready = s2_if.tready;
    assign s3_if.tdata = s3_axis_tdata; assign s3_if.tvalid = s3_axis_tvalid; assign s3_axis_tready = s3_if.tready;
    assign s4_if.tdata = s4_axis_tdata; assign s4_if.tvalid = s4_axis_tvalid; assign s4_axis_tready = s4_if.tready;
    // tlast for s1..s4 unused by tprocv1 inputs; tie low on the interface side.
    assign s1_if.tlast = 1'b0; assign s2_if.tlast = 1'b0;
    assign s3_if.tlast = 1'b0; assign s4_if.tlast = 1'b0;

    // m1..m8 : interface masters (driven by tprocv1) -> external flat outputs
    assign m1_axis_tdata = m1_if.tdata; assign m1_axis_tvalid = m1_if.tvalid; assign m1_if.tready = m1_axis_tready;
    assign m2_axis_tdata = m2_if.tdata; assign m2_axis_tvalid = m2_if.tvalid; assign m2_if.tready = m2_axis_tready;
    assign m3_axis_tdata = m3_if.tdata; assign m3_axis_tvalid = m3_if.tvalid; assign m3_if.tready = m3_axis_tready;
    assign m4_axis_tdata = m4_if.tdata; assign m4_axis_tvalid = m4_if.tvalid; assign m4_if.tready = m4_axis_tready;
    assign m5_axis_tdata = m5_if.tdata; assign m5_axis_tvalid = m5_if.tvalid; assign m5_if.tready = m5_axis_tready;
    assign m6_axis_tdata = m6_if.tdata; assign m6_axis_tvalid = m6_if.tvalid; assign m6_if.tready = m6_axis_tready;
    assign m7_axis_tdata = m7_if.tdata; assign m7_axis_tvalid = m7_if.tvalid; assign m7_if.tready = m7_axis_tready;
    assign m8_axis_tdata = m8_if.tdata; assign m8_axis_tvalid = m8_if.tvalid; assign m8_if.tready = m8_axis_tready;

    //==========================================================================
    // AXI4-Lite slave (custom): registers + single DMEM access handshake
    //==========================================================================
    axi_slv_tprocv1 axi_slv_i (
        // Reset and clock
        .aclk_i        (s_axi_aclk),
        .aresetn_i     (s_axi_aresetn),
        // Write Address Channel
        .awaddr_i      (s_axi_awaddr),
        .awprot_i      (s_axi_awprot),
        .awvalid_i     (s_axi_awvalid),
        .awready_o     (s_axi_awready),
        // Write Data Channel
        .wdata_i       (s_axi_wdata),
        .wstrb_i       (s_axi_wstrb),
        .wvalid_i      (s_axi_wvalid),
        .wready_o      (s_axi_wready),
        // Write Response Channel
        .bresp_o       (s_axi_bresp),
        .bvalid_o      (s_axi_bvalid),
        .bready_i      (s_axi_bready),
        // Read Address Channel
        .araddr_i      (s_axi_araddr),
        .arprot_i      (s_axi_arprot),
        .arvalid_i     (s_axi_arvalid),
        .arready_o     (s_axi_arready),
        // Read Data Channel
        .rdata_o       (s_axi_rdata),
        .rresp_o       (s_axi_rresp),
        .rvalid_o      (s_axi_rvalid),
        .rready_i      (s_axi_rready),
        // Single Access Handshake
        .busy_i        (busy_int),
        .oper_o        (oper_int),
        .addr_o        (addr_int),
        .dwrite_o      (dwrite_int),
        .dread_i       (dread_int),
        .exec_o        (exec_int),
        .exec_ack_i    (exec_ack_int),
        // Registers
        .start_src_reg (start_src_reg),
        .start_reg     (start_reg),
        .mem_mode_reg  (mem_mode_reg),
        .mem_start_reg (mem_start_reg),
        .mem_addr_reg  (mem_addr_reg),
        .mem_len_reg   (mem_len_reg)
    );

    //==========================================================================
    // Data Memory arbiter (dmem)
    //==========================================================================
    dmem #(
        .N (DMEM_N),
        .B (32)
    ) data_mem_i (
        .clk        (s_axi_aclk),
        .rstn       (s_axi_aresetn),
        // Single-access handshake
        .busy_o     (busy_int),
        .oper_i     (oper_int),
        .addr_i     (addr_int[DMEM_N-1:0]),   // 32-bit slave addr -> DMEM width
        .din_i      (dwrite_int),
        .dout_o     (dread_int),
        .exec_i     (exec_int),
        .exec_ack_o (exec_ack_int),
        // External BRAM port A
        .mem_we_o   (dmem_wea),
        .mem_di_o   (dmem_dia),
        .mem_do_i   (dmem_doa),
        .mem_addr_o (dmem_addra),
        // AXIS interfaces (32-bit)
        .s_axis     (s0_if.slave),
        .m_axis     (m0_if.master),
        // Registers
        .mode_reg   (mem_mode_reg),
        .start_reg  (mem_start_reg),
        .addr_reg   (mem_addr_reg[DMEM_N-1:0]),
        .len_reg    (mem_len_reg[DMEM_N-1:0])
    );

    //==========================================================================
    // Data memory (true dual-port BRAM)
    //==========================================================================
    bram_tdp #(
        .NB_DATA (32),
        .NB_ADDR (DMEM_N)
    ) dmem_i (
        // Port A: s_axi_aclk domain (dmem arbiter)
        .clka  (s_axi_aclk),
        .rsta  (~s_axi_aresetn),
        .ena   (1'b1),
        .wea   (dmem_wea),
        .addra (dmem_addra),
        .dia   (dmem_dia),
        .doa   (dmem_doa),
        // Port B: aclk domain (tProcessor)
        .clkb  (aclk),
        .rstb  (~aresetn),
        .enb   (1'b1),
        .web   (dmem_web),
        .addrb (dmem_addrb),
        .dib   (dmem_dib),
        .dob   (dmem_dob)
    );

    //==========================================================================
    // tProcessor core (tprocv1)
    //==========================================================================
    tprocv1 #(
        .N (PMEM_N),
        .M (DMEM_N)
    ) tproc_i (
        // Clock and reset
        .clk           (aclk),
        .rstn          (aresetn),
        // Start/stop
        .start         (start),
        // Program memory
        .pmem_addr     (pmem_addr_int),
        .pmem_do       (pmem_do),
        // Data memory (port B)
        .dmem_we       (dmem_web),
        .dmem_addr     (dmem_addrb),
        .dmem_di       (dmem_dib),
        .dmem_do       (dmem_dob),
        // Slave AXIS inputs (s0..s3 of tprocv1 <- s1..s4 top)
        .s0_axis       (s1_if.slave),
        .s1_axis       (s2_if.slave),
        .s2_axis       (s3_if.slave),
        .s3_axis       (s4_if.slave),
        // Master AXIS outputs (m0..m7 of tprocv1 -> m1..m8 top)
        .m0_axis       (m1_if.master),
        .m1_axis       (m2_if.master),
        .m2_axis       (m3_if.master),
        .m3_axis       (m4_if.master),
        .m4_axis       (m5_if.master),
        .m5_axis       (m6_if.master),
        .m6_axis       (m7_if.master),
        .m7_axis       (m8_if.master),
        // Register control inputs
        .start_src_reg (start_src_reg),
        .start_reg     (start_reg)
    );

    //==========================================================================
    // Program memory address: multiply by 8 (64-bit word -> byte address)
    //==========================================================================
    assign pmem_addr = {pmem_addr_int[PMEM_N-4:0], 3'b000};

endmodule
