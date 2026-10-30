///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_signal_gen_v6
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_signal_gen_v6.sv
//!
//! @brief   axis_signal_gen_v6
//!
//! @details
//!
//! Top level of the QICK v6 arbitrary signal generator IP.
//!
//! Wraps the SG-v6 datapath (sgv6_top) with an AXI4-Lite register block
//! (axil_slv) that exposes the envelope-writer control and status registers.
//!
//! Three clock domains:
//!
//! - s_axi_aclk   : AXI4-Lite configuration.
//! - s0_axis_aclk : envelope sample loading (BRAM write side).
//! - aclk         : descriptor FIFO, signal generator, output.
//!
//! Register map (axil_slv, byte-addressed, regwidth = 32):
//! 0x00 START_ADDR_REG : envelope write start address (32-bit, sw=rw).
//! 0x04 WE_REG         : envelope write enable, bit 0 (sw=rw).
//! 0x08 RNDQ_REG       : DEPRECATED - rounding-select removed from the IP
//! (32-bit, sw=rw; retained for register-map
//! compatibility, no functional effect).
//! 0x0C STATUS_REG     : status (read-only from SW).
//! bit 0 SATURATING - sticky flag, set to 1 when the
//! output has been clamped to +/-MAXV since the last
//! clear. Cleared via CTRL_REG.SAT_CLEAR.
//! 0x10 CTRL_REG       : control.
//! bit 0 SAT_CLEAR - write 1 to clear the sticky
//! SATURATING flag in STATUS_REG.
//!
//! @note    Amplitude fix (v1.0.0, BREAKING): the envelope x DDS product is
//!
//! @note    quantized as [30:15] (previously [31:16]) to recover a factor of 2, the
//!
//! @note    baseband >>1 was removed, and the gain-stage output is now saturated to
//!
//! @note    +/-MAXV. STATUS_REG.SATURATING / CTRL_REG.SAT_CLEAR expose that
//!
//! @note    saturation to software. Envelope pulses now reach full scale; the SW
//!
//! @note    flat_top gain/2 workaround must be reverted.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module axis_signal_gen_v6 #(
   //! Envelope-memory address width per bank (depth 2**N).
   parameter int    N             = 12,
   //! Number of parallel banks / DDS lanes.
   parameter int    N_DDS         = 16,
   //! "TRUE" up-converts with the DDS; "FALSE" baseband only.
   parameter string GEN_DDS       = "TRUE",
   //! "COMPLEX" (real+imag banks) or "REAL".
   parameter string ENVELOPE_TYPE = "COMPLEX"
)(
   // AXI4-Lite slave (configuration).
   input  logic        s_axi_aclk,
   input  logic        s_axi_aresetn,
   input  logic [5:0]  s_axi_awaddr,
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
   input  logic [5:0]  s_axi_araddr,
   input  logic [2:0]  s_axi_arprot,
   input  logic        s_axi_arvalid,
   output logic        s_axi_arready,
   output logic [31:0] s_axi_rdata,
   output logic [1:0]  s_axi_rresp,
   output logic        s_axi_rvalid,
   input  logic        s_axi_rready,
   // AXIS slave: envelope sample loading.
   input  logic        s0_axis_aclk,
   input  logic        s0_axis_aresetn,
   input  logic [31:0] s0_axis_tdata,
   input  logic        s0_axis_tvalid,
   output logic        s0_axis_tready,
   // s1_* and m_* clock/reset.
   input  logic        aclk,
   input  logic        aresetn,
   // AXIS slave: waveform descriptor queue.
   input  logic [159:0] s1_axis_tdata,
   input  logic         s1_axis_tvalid,
   output logic         s1_axis_tready,
   // AXIS master: output.
   input  logic         m_axis_tready,
   output logic         m_axis_tvalid,
   output logic [N_DDS*16-1:0] m_axis_tdata,
   // Saturation flag (instantaneous, aclk domain) — for hardware debug/ILA.
   output logic                saturating
);

   // --------------------------------------------------------------------------
   // Register map indices.
   // --------------------------------------------------------------------------
   localparam int NUM_REGS      = 5;
   localparam int R_START_ADDR  = 0;
   localparam int R_WE          = 1;
   localparam int R_RNDQ        = 2;
   localparam int R_STATUS      = 3;   // read-only: bit0 = sat sticky
   localparam int R_CTRL        = 4;   // write: bit0 = sat clear

   logic [31:0] slv_regs_o [NUM_REGS];
   logic [31:0] slv_regs_i [NUM_REGS];
   logic [NUM_REGS-1:0] reg_ro;
   // Register fields.
   logic [31:0] start_addr_reg;
   logic        we_reg;
   logic        sat_clear;

   // Register fields.
   assign start_addr_reg = slv_regs_o[R_START_ADDR];
   assign we_reg         = slv_regs_o[R_WE][0];
   assign sat_clear      = slv_regs_o[R_CTRL][0];   // in s_axi_aclk domain

   // STATUS_REG is read-only (driven by i_slv_regs).
   assign reg_ro = '0 | (1 << R_STATUS);

   // --------------------------------------------------------------------------
   // Saturation flag from the datapath (aclk domain).
   // --------------------------------------------------------------------------
   logic o_sat_aclk;   // instantaneous, from sgv6_top

   // Instantaneous output port (aclk domain) for hardware debug.
   assign saturating = o_sat_aclk;

   // Sticky flag in aclk domain, cleared by sat_clear (synced from s_axi).
   logic sat_clear_aclk;
   cdc_gray_sync #(.N(2), .M(1)) sat_clear_sync_i (
      .i_clk  (aclk),
      .i_rstn (aresetn),
      .i_d    (sat_clear),
      .o_d    (sat_clear_aclk)
   );

   logic sat_sticky;
   always_ff @(posedge aclk) begin
      if (!aresetn)              sat_sticky <= 1'b0;
      else if (sat_clear_aclk)   sat_sticky <= 1'b0;
      else if (o_sat_aclk)       sat_sticky <= 1'b1;
   end

   // CDC: sticky flag aclk -> s_axi_aclk for the STATUS register.
   logic sat_sticky_axi;
   cdc_gray_sync #(.N(2), .M(1)) sat_sticky_sync_i (
      .i_clk  (s_axi_aclk),
      .i_rstn (s_axi_aresetn),
      .i_d    (sat_sticky),
      .o_d    (sat_sticky_axi)
   );

   // Feed read-only registers back to the slave.
   //   - Writable regs loop back their written value.
   //   - STATUS_REG reflects the sticky saturation flag.
   always_comb begin
      for (int k = 0; k < NUM_REGS; k++)
         slv_regs_i[k] = slv_regs_o[k];
      slv_regs_i[R_STATUS] = {31'b0, sat_sticky_axi};
   end

   // --------------------------------------------------------------------------
   // AXI4-Lite register block.
   // --------------------------------------------------------------------------
   axil_slv #(
      .AXI_DW   (32),
      .AXI_AW   (6),
      .NUM_REGS (NUM_REGS)
   ) axil_slv_i (
      .s_axi_aclk    (s_axi_aclk),
      .s_axi_aresetn (s_axi_aresetn),
      .s_axi_awaddr  (s_axi_awaddr),
      .s_axi_awprot  (s_axi_awprot),
      .s_axi_awvalid (s_axi_awvalid),
      .s_axi_awready (s_axi_awready),
      .s_axi_wdata   (s_axi_wdata),
      .s_axi_wstrb   (s_axi_wstrb),
      .s_axi_wvalid  (s_axi_wvalid),
      .s_axi_wready  (s_axi_wready),
      .s_axi_bresp   (s_axi_bresp),
      .s_axi_bvalid  (s_axi_bvalid),
      .s_axi_bready  (s_axi_bready),
      .s_axi_araddr  (s_axi_araddr),
      .s_axi_arprot  (s_axi_arprot),
      .s_axi_arvalid (s_axi_arvalid),
      .s_axi_arready (s_axi_arready),
      .s_axi_rdata   (s_axi_rdata),
      .s_axi_rresp   (s_axi_rresp),
      .s_axi_rvalid  (s_axi_rvalid),
      .s_axi_rready  (s_axi_rready),
      .o_slv_regs    (slv_regs_o),
      .i_slv_regs    (slv_regs_i),
      .i_reg_is_readonly (reg_ro)
   );

   // --------------------------------------------------------------------------
   // Signal generator (datapath + memory + FIFO + DDS).
   // --------------------------------------------------------------------------
   sgv6_top #(
      .N             (N),
      .N_DDS         (N_DDS),
      .GEN_DDS       (GEN_DDS),
      .ENVELOPE_TYPE (ENVELOPE_TYPE)
   ) sgv6_top_i (
      .aresetn          (aresetn),
      .aclk             (aclk),
      .s0_axis_aresetn  (s0_axis_aresetn),
      .s0_axis_aclk     (s0_axis_aclk),
      .s0_axis_tdata_i  (s0_axis_tdata),
      .s0_axis_tvalid_i (s0_axis_tvalid),
      .s0_axis_tready_o (s0_axis_tready),
      .s1_axis_tdata_i  (s1_axis_tdata),
      .s1_axis_tvalid_i (s1_axis_tvalid),
      .s1_axis_tready_o (s1_axis_tready),
      .m_axis_tready_i  (m_axis_tready),
      .m_axis_tvalid_o  (m_axis_tvalid),
      .m_axis_tdata_o   (m_axis_tdata),
      .start_addr_reg   (start_addr_reg),
      .we_reg           (we_reg),
      .o_sat            (o_sat_aclk)
   );

endmodule
