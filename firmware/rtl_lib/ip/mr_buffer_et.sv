`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi National Accelerator Laboratory
//
// Module : mr_buffer_et.sv
// Project: QICK
// VLNV   : qick:ip:mr_buffer_et:1.2.0
//! @file  mr_buffer_et.sv
//! @brief Multi-Rate (MR) Buffer with External Trigger — AXI4-Lite wrapper.
//!
//! @details
//! Captures NM parallel channels (B bits each) into NM independent BRAMs
//! (depth 2**N) at full write-side rate (s_axis_aclk), armed by `dw_capture_reg`
//! and started by an external `trigger`. The captured window is then drained
//! on the read side (m_axis_aclk) as a single B-bit AXI4-Stream when
//! `dr_start_reg` pulses. Write and read run in independent clock domains
//! (CDC handled internally by cdc_gray_sync).
//!
//! Typical use (loop settling capture over DMA):
//!   1. SW writes dw_capture_reg=1        -> arm the writer
//!   2. External trigger fires            -> BRAMs fill with 2**N samples/ch
//!   3. SW writes dr_start_reg=1          -> stream the whole window out
//!   4. AXI-DMA S2MM drains M_AXIS to DDR (read burst = NM*2**N beats, tlast)
//!
//! Clock domains:
//!   - s_axi_aclk  : AXI4-Lite config
//!   - s_axis_aclk : write/capture datapath (full-rate, e.g. 307.2 MHz)
//!   - m_axis_aclk : read/drain datapath (e.g. 99 MHz to DMA/HP)
//!
//! AXI4-Lite register map (C_S_AXI_DW=32, NUM_REGS=16):
//!   reg[0]  [0]   dw_capture   (RW) : 1=arm writer (capture-enable)
//!   reg[1]  [0]   dr_start     (RW) : 1=start reader (drain window to M_AXIS)
//!   reg[2..14]    reserved     (RO, reads 0)
//!   reg[15] [31:0] debug       (RW) : [0]=force trigger, [1]=force s_axis_tready
//!
//! Output word order per read burst (TOTAL_WORDS = NM*2**N):
//!   w0=ch0@0, w1=ch1@0, ... w(NM-1)=ch(NM-1)@0, wNM=ch0@1, ... tlast on last.
//!
//! @author QICK Development Team
//! @version 1.2
///////////////////////////////////////////////////////////////////////////////

module mr_buffer_et #(
  parameter int NM         = 8,  // Number of memories (parallel channels)
  parameter int N          = 8,  // Address width of each memory (2^N depth)
  parameter int B          = 16, // Data width of each memory (bits)
  parameter int C_S_AXI_DW = 32, // AXI4 Data width
  parameter int C_S_AXI_AW = 6,  // AXI4 Address width
  parameter int DEBUG      = 0   // Enable debug
)(
    // Standard AXI Ports
    input  logic                               s_axi_aclk,
    input  logic                               s_axi_aresetn,
    input  logic [C_S_AXI_AW-1:0]              s_axi_awaddr,
    input  logic [2:0]                         s_axi_awprot,
    input  logic                               s_axi_awvalid,
    output logic                               s_axi_awready,
    input  logic [C_S_AXI_DW-1:0]              s_axi_wdata,
    input  logic [(C_S_AXI_DW/8)-1:0]          s_axi_wstrb,
    input  logic                               s_axi_wvalid,
    output logic                               s_axi_wready,
    output logic [1:0]                         s_axi_bresp,
    output logic                               s_axi_bvalid,
    input  logic                               s_axi_bready,
    input  logic [C_S_AXI_AW-1:0]              s_axi_araddr,
    input  logic [2:0]                         s_axi_arprot,
    input  logic                               s_axi_arvalid,
    output logic                               s_axi_arready,
    output logic [C_S_AXI_DW-1:0]              s_axi_rdata,
    output logic [1:0]                         s_axi_rresp,
    output logic                               s_axi_rvalid,
    input  logic                               s_axi_rready,

    // AXI-Stream Slave Ports
    input  logic                               s_axis_aclk,
    input  logic                               s_axis_aresetn,
    input  logic [NM*B-1:0]                    s_axis_tdata,
    input  logic [(NM*B/8)-1:0]                s_axis_tstrb,
    input  logic                               s_axis_tvalid,
    input  logic                               s_axis_tlast,
    output logic                               s_axis_tready,

    // AXI-Stream Master Ports
    input  logic                               m_axis_aclk,
    input  logic                               m_axis_aresetn,
    output logic [B-1:0]                       m_axis_tdata,
    output logic [(B/8)-1:0]                   m_axis_tstrb,
    output logic                               m_axis_tvalid,
    output logic                               m_axis_tlast,
    input  logic                               m_axis_tready,

    //trigger input
    input  logic                               trigger,

    //debug ports
    output logic [32-1:0]                      s_dbg_probe,
    output logic [32-1:0]                      m_dbg_probe
);

    // localparam for combined IQ width
    localparam int NUM_REGS = 16; // 16 for compatibility
    // mask by-register: only reg[2] (STATUS) is read-only
    localparam logic [NUM_REGS-1:0] RO_MASK = 16'b0000_0000_0000_0100;  // bit 2

    // Registers
    logic [32-1:0]         s_dbg_probe_r;
    logic [32-1:0]         m_dbg_probe_r;
    logic [C_S_AXI_DW-1:0] slv_regs_o [NUM_REGS];
    logic [C_S_AXI_DW-1:0] slv_regs_i [NUM_REGS];
    logic                  dw_capture_reg;
    logic                  dr_start_reg;
    logic [C_S_AXI_DW-1:0] debug_reg;
    // --- capture_done: crosses from s_axis_aclk (capture) to s_axi_aclk (regmap) ---
    logic capture_done_s;   // in s_axis_aclk, it comes from the mr_buffer core
    logic capture_done;     // in s_axi_aclk, for the regmap


    // ==========================================
    // AXI4-Lite Slave Instance
    // ==========================================
    axil_slv #(
        .AXI_DW   ( C_S_AXI_DW ),
        .AXI_AW   ( C_S_AXI_AW ),
        .NUM_REGS ( NUM_REGS   )
    ) axil_slv_i (
        .s_axi_aclk        ( s_axi_aclk         ),
        .s_axi_aresetn     ( s_axi_aresetn      ),
        .s_axi_awaddr      ( s_axi_awaddr       ),
        .s_axi_awprot      ( s_axi_awprot       ),
        .s_axi_awvalid     ( s_axi_awvalid      ),
        .s_axi_awready     ( s_axi_awready      ),
        .s_axi_wdata       ( s_axi_wdata        ),
        .s_axi_wstrb       ( s_axi_wstrb        ),
        .s_axi_wvalid      ( s_axi_wvalid       ),
        .s_axi_wready      ( s_axi_wready       ),
        .s_axi_bresp       ( s_axi_bresp        ),
        .s_axi_bvalid      ( s_axi_bvalid       ),
        .s_axi_bready      ( s_axi_bready       ),
        .s_axi_araddr      ( s_axi_araddr       ),
        .s_axi_arprot      ( s_axi_arprot       ),
        .s_axi_arvalid     ( s_axi_arvalid      ),
        .s_axi_arready     ( s_axi_arready      ),
        .s_axi_rdata       ( s_axi_rdata        ),
        .s_axi_rresp       ( s_axi_rresp        ),
        .s_axi_rvalid      ( s_axi_rvalid       ),
        .s_axi_rready      ( s_axi_rready       ),
        .o_slv_regs        ( slv_regs_o         ),
        .i_slv_regs        ( slv_regs_i         ),
        .i_reg_is_readonly ( RO_MASK            ) // Only reg[2] (STATUS) is read-only
    );

    //simple loopback for registers
    assign slv_regs_i[0]  = {31'b0, dw_capture_reg};
    assign slv_regs_i[1]  = {31'b0, dr_start_reg};
    assign slv_regs_i[2]  = {31'b0, capture_done};   // STATUS_REG[0] = CAPTURE_DONE (RO)
    // Generate block to assign a register range
    generate
        for (genvar i = 3; i <= 14; i++) begin : gen_slv_regs
            assign slv_regs_i[i] = '0;
        end
    endgenerate

    assign slv_regs_i[15] = debug_reg;

    assign dw_capture_reg = slv_regs_o[0][0]; // Extract dw_capture part from the register output
    assign dr_start_reg   = slv_regs_o[1][0]; // Extract dr_start part from the register output
    assign debug_reg      = slv_regs_o[15];   // Extract debug signal from the register output

    mr_buffer #(
        .NM ( NM ),
        .N  ( N  ),
        .B  ( B  )
    ) mr_buffer_i (
        .trigger        ( trigger        ),
        .s_axis_aclk    ( s_axis_aclk    ),
        .s_axis_aresetn ( s_axis_aresetn ),
        .s_axis_tready  ( s_axis_tready  ),
        .s_axis_tdata   ( s_axis_tdata   ),
        .s_axis_tstrb   ( s_axis_tstrb   ),
        .s_axis_tlast   ( s_axis_tlast   ),
        .s_axis_tvalid  ( s_axis_tvalid  ),
        .m_axis_aclk    ( m_axis_aclk    ),
        .m_axis_aresetn ( m_axis_aresetn ),
        .m_axis_tvalid  ( m_axis_tvalid  ),
        .m_axis_tdata   ( m_axis_tdata   ),
        .m_axis_tstrb   ( m_axis_tstrb   ),
        .m_axis_tlast   ( m_axis_tlast   ),
        .m_axis_tready  ( m_axis_tready  ),
        .dw_capture_reg ( dw_capture_reg ),
        .dr_start_reg   ( dr_start_reg   ),
        .debug_reg      ( debug_reg      ),
        .s_dbg_probe    ( s_dbg_probe_r  ),
        .m_dbg_probe    ( m_dbg_probe_r  ),
        .o_capture_done ( capture_done_s )
    );

    cdc_bit_sync #(.NSTAGES(2)) u_sync_cap_done (
        .i_clk   (s_axi_aclk),
        .i_rstn  (s_axi_aresetn),
        .i_async (capture_done_s),
        .o_sync  (capture_done)
    );
    // ==========================================
    // Debug generate block
    // ==========================================
    generate
        if (DEBUG == 1) begin : gen_debug
            assign s_dbg_probe = s_dbg_probe_r;
            assign m_dbg_probe = m_dbg_probe_r;
        end else begin : gen_ndebug
            assign s_dbg_probe = '0;
            assign m_dbg_probe = '0;
        end
    endgenerate

endmodule
