`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_buffer_ddr
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_buffer_ddr.sv
//!
//! @brief   AXI4-Stream <-> DDR4 buffer: writes the input stream to DDR when
//!          triggered and reads a block back out on an AXI4-Stream.
//!
//! @details
//! Faithful port of the legacy QICK IP (openquantumhardware/qick firmware/ip/
//! axis_buffer_ddr, QICK:QICK:axis_buffer_ddr:1.1) on the ported
//! qick:axi:axi_mst_write, qick:axi:axi_mst_read and the generic axil_slv.
//! Same ports and parameters.
//!
//! Register map (axil_slv, 64 x 32 bits, all read/write, reset 0; the
//! registers cross into aclk through the 2-flop synchronizers of the master
//! channels, quasi-static):
//!   0x00 RSTART_REG  [0]  read start (hold until the read is done)
//!   0x04 RADDR_REG        read byte offset from TARGET_SLAVE_BASE_ADDR
//!   0x08 RLENGTH_REG      beats of the read burst (arlen = RLENGTH - 1)
//!   0x0C WSTART_REG  [0]  write start (armed; the write waits for `trigger`)
//!   0x10 WADDR_REG        write byte offset from TARGET_SLAVE_BASE_ADDR
//!   0x14 WNBURST_REG      write bursts (WNBURST_REG bursts of
//!                         BURST_SIZE + 1 beats; 0 never ends)
//!   0x18 WSTATUS_REG [0]  read only: an error response (BRESP) came back in the current or last write
//!   0x1C..0xFC: unused, read/write storage (as in the legacy slave).
//!
//! Two clock domains: s_axi_aclk (AXI4-Lite configuration) and aclk (the AXI4
//! master, both AXI4-Streams and the trigger).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module axis_buffer_ddr #(
    // verilog_lint: waive explicit-parameter-storage-type
    parameter TARGET_SLAVE_BASE_ADDR = 32'h40000000,  //! AXI address of the DDR window
    parameter int ID_WIDTH           = 1,             //! AXI ID width
    parameter int DATA_WIDTH         = 256,           //! AXI and stream data width
    parameter int BURST_SIZE         = 15,            //! Write burst length minus one
    parameter int DEBUG              = 0              //! Unused (kept for the legacy parameter list)
) (
      // Trigger.
      input    logic                 trigger        ,

      /***********************************/
      /* AXI Slave I/F for configuration */
      /***********************************/
      input    logic                 s_axi_aclk     ,
      input    logic                 s_axi_aresetn  ,

      input    logic  [7:0]          s_axi_awaddr   ,
      input    logic  [2:0]          s_axi_awprot   ,
      input    logic                 s_axi_awvalid  ,
      output   logic                 s_axi_awready  ,

      input    logic  [31:0]         s_axi_wdata    ,
      input    logic  [3:0]          s_axi_wstrb    ,
      input    logic                 s_axi_wvalid   ,
      output   logic                 s_axi_wready   ,

      output   logic  [1:0]          s_axi_bresp    ,
      output   logic                 s_axi_bvalid   ,
      input    logic                 s_axi_bready   ,

      input    logic  [7:0]          s_axi_araddr   ,
      input    logic  [2:0]          s_axi_arprot   ,
      input    logic                 s_axi_arvalid  ,
      output   logic                 s_axi_arready  ,

      output   logic  [31:0]         s_axi_rdata    ,
      output   logic  [1:0]          s_axi_rresp    ,
      output   logic                 s_axi_rvalid   ,
      input    logic                 s_axi_rready   ,

      // Reset and Clock (m_axi, s_axis, m_axis).
      input    logic                 aclk        ,
      input    logic                 aresetn        ,

      /***********************/
      /* AXI Master for DDR4 */
      /***********************/

      // Write Address Channel.
      output   logic  [ID_WIDTH-1:0] m_axi_awid     ,
      output   logic  [31:0]         m_axi_awaddr   ,
      output   logic  [7:0]          m_axi_awlen    ,
      output   logic  [2:0]          m_axi_awsize   ,
      output   logic  [1:0]          m_axi_awburst  ,
      output   logic                 m_axi_awlock   ,
      output   logic  [3:0]          m_axi_awcache  ,
      output   logic  [2:0]          m_axi_awprot   ,
      output   logic  [3:0]          m_axi_awregion ,
      output   logic  [3:0]          m_axi_awqos    ,
      output   logic                 m_axi_awvalid  ,
      input    logic                 m_axi_awready  ,

      // Write Data Channel.
      output   logic  [DATA_WIDTH-1:0]     m_axi_wdata    ,
      output   logic  [DATA_WIDTH/8-1:0]   m_axi_wstrb    ,
      output   logic                       m_axi_wlast    ,
      output   logic                       m_axi_wvalid   ,
      input    logic                       m_axi_wready   ,

      // Write Response Channel.
      input    logic  [ID_WIDTH-1:0]       m_axi_bid      ,
      input    logic  [1:0]                m_axi_bresp    ,
      input    logic                       m_axi_bvalid   ,
      output   logic                       m_axi_bready   ,

      // Read Address Channel.
      output   logic  [ID_WIDTH-1:0]       m_axi_arid     ,
      output   logic  [31:0]               m_axi_araddr   ,
      output   logic  [7:0]                m_axi_arlen    ,
      output   logic  [2:0]                m_axi_arsize   ,
      output   logic  [1:0]                m_axi_arburst  ,
      output   logic                       m_axi_arlock   ,
      output   logic  [3:0]                m_axi_arcache  ,
      output   logic  [2:0]                m_axi_arprot   ,
      output   logic  [3:0]                m_axi_arregion ,
      output   logic  [3:0]                m_axi_arqos    ,
      output   logic                       m_axi_arvalid  ,
      input    logic                       m_axi_arready  ,

      // Read Data Channel.
      input    logic  [ID_WIDTH-1:0]       m_axi_rid      ,
      input    logic  [DATA_WIDTH-1:0]     m_axi_rdata    ,
      input    logic  [1:0]                m_axi_rresp    ,
      input    logic                       m_axi_rlast    ,
      input    logic                       m_axi_rvalid   ,
      output   logic                       m_axi_rready   ,

      /*************************/
      /* AXIS Master Interfase */
      /*************************/
      output   logic                       m_axis_tvalid  ,
      output   logic  [DATA_WIDTH-1:0]     m_axis_tdata   ,
      output   logic  [DATA_WIDTH/8-1:0]   m_axis_tstrb   ,
      output   logic                       m_axis_tlast   ,
      input    logic                       m_axis_tready  ,

      /************************/
      /* AXIS Slave Interfase */
      /************************/
      output   logic                       s_axis_tready  ,
      input    logic  [DATA_WIDTH-1:0]     s_axis_tdata   ,
      input    logic  [DATA_WIDTH/8-1:0]   s_axis_tstrb   ,
      input    logic                       s_axis_tlast   ,
      input    logic                       s_axis_tvalid  ,

      // Debug
      output  logic   [31:0]               mst_write_probe_dbg,
      output  logic   [31:0]               mst_read_probe_dbg
);

    localparam int NUM_REGS    = 64;
    localparam int WSTATUS_REG = 6;

    logic [31:0] regs [NUM_REGS];
    logic [31:0] ro_regs [NUM_REGS];
    logic        bresp_err, bresp_err_sync;

    always_comb begin
        ro_regs = '{default: '0};
        ro_regs[WSTATUS_REG] = {31'b0, bresp_err_sync};
    end

    // aclk -> s_axi_aclk (the flag is sticky and read by software after the write)
    cdc_bit_sync bresp_err_sync_i (
        .i_clk   (s_axi_aclk),
        .i_rstn  (s_axi_aresetn),
        .i_async (bresp_err),
        .o_sync  (bresp_err_sync)
    );

    axil_slv #(
        .AXI_DW   (32),
        .AXI_AW   (8),
        .NUM_REGS (NUM_REGS)
    ) axil_slv_i (
        .s_axi_aclk        (s_axi_aclk),
        .s_axi_aresetn     (s_axi_aresetn),
        .s_axi_awaddr      (s_axi_awaddr),
        .s_axi_awprot      (s_axi_awprot),
        .s_axi_awvalid     (s_axi_awvalid),
        .s_axi_awready     (s_axi_awready),
        .s_axi_wdata       (s_axi_wdata),
        .s_axi_wstrb       (s_axi_wstrb),
        .s_axi_wvalid      (s_axi_wvalid),
        .s_axi_wready      (s_axi_wready),
        .s_axi_bresp       (s_axi_bresp),
        .s_axi_bvalid      (s_axi_bvalid),
        .s_axi_bready      (s_axi_bready),
        .s_axi_araddr      (s_axi_araddr),
        .s_axi_arprot      (s_axi_arprot),
        .s_axi_arvalid     (s_axi_arvalid),
        .s_axi_arready     (s_axi_arready),
        .s_axi_rdata       (s_axi_rdata),
        .s_axi_rresp       (s_axi_rresp),
        .s_axi_rvalid      (s_axi_rvalid),
        .s_axi_rready      (s_axi_rready),
        .o_slv_regs        (regs),
        .i_slv_regs        (ro_regs),
        .i_reg_is_readonly (NUM_REGS'(1) << WSTATUS_REG)
    );

    axi_mst_read #(
        .TARGET_SLAVE_BASE_ADDR (TARGET_SLAVE_BASE_ADDR),
        .ID_WIDTH               (ID_WIDTH),
        .DATA_WIDTH             (DATA_WIDTH)
    ) axi_mst_read_i (
        .clk                 (aclk),
        .rstn                (aresetn),
        .m_axi_arid          (m_axi_arid),
        .m_axi_araddr        (m_axi_araddr),
        .m_axi_arlen         (m_axi_arlen),
        .m_axi_arsize        (m_axi_arsize),
        .m_axi_arburst       (m_axi_arburst),
        .m_axi_arlock        (m_axi_arlock),
        .m_axi_arcache       (m_axi_arcache),
        .m_axi_arprot        (m_axi_arprot),
        .m_axi_arregion      (m_axi_arregion),
        .m_axi_arqos         (m_axi_arqos),
        .m_axi_arvalid       (m_axi_arvalid),
        .m_axi_arready       (m_axi_arready),
        .m_axi_rid           (m_axi_rid),
        .m_axi_rdata         (m_axi_rdata),
        .m_axi_rresp         (m_axi_rresp),
        .m_axi_rlast         (m_axi_rlast),
        .m_axi_rvalid        (m_axi_rvalid),
        .m_axi_rready        (m_axi_rready),
        .m_axis_tvalid       (m_axis_tvalid),
        .m_axis_tdata        (m_axis_tdata),
        .m_axis_tstrb        (m_axis_tstrb),
        .m_axis_tlast        (m_axis_tlast),
        .m_axis_tready       (m_axis_tready),
        .start_reg           (regs[0][0]),
        .addr_reg            (regs[1]),
        .length_reg          (regs[2]),
        .mst_read_probe_dbg1 (mst_read_probe_dbg)
    );

    axi_mst_write #(
        .TARGET_SLAVE_BASE_ADDR (TARGET_SLAVE_BASE_ADDR),
        .ID_WIDTH               (ID_WIDTH),
        .DATA_WIDTH             (DATA_WIDTH),
        .BURST_SIZE             (BURST_SIZE)
    ) axi_mst_write_i (
        .clk                  (aclk),
        .rstn                 (aresetn),
        .trigger              (trigger),
        .m_axi_awid           (m_axi_awid),
        .m_axi_awaddr         (m_axi_awaddr),
        .m_axi_awlen          (m_axi_awlen),
        .m_axi_awsize         (m_axi_awsize),
        .m_axi_awburst        (m_axi_awburst),
        .m_axi_awlock         (m_axi_awlock),
        .m_axi_awcache        (m_axi_awcache),
        .m_axi_awprot         (m_axi_awprot),
        .m_axi_awregion       (m_axi_awregion),
        .m_axi_awqos          (m_axi_awqos),
        .m_axi_awvalid        (m_axi_awvalid),
        .m_axi_awready        (m_axi_awready),
        .m_axi_wdata          (m_axi_wdata),
        .m_axi_wstrb          (m_axi_wstrb),
        .m_axi_wlast          (m_axi_wlast),
        .m_axi_wvalid         (m_axi_wvalid),
        .m_axi_wready         (m_axi_wready),
        .m_axi_bid            (m_axi_bid),
        .m_axi_bresp          (m_axi_bresp),
        .m_axi_bvalid         (m_axi_bvalid),
        .m_axi_bready         (m_axi_bready),
        .s_axis_tready        (s_axis_tready),
        .s_axis_tdata         (s_axis_tdata),
        .s_axis_tstrb         (s_axis_tstrb),
        .s_axis_tlast         (s_axis_tlast),
        .s_axis_tvalid        (s_axis_tvalid),
        .bresp_err            (bresp_err),
        .start_reg            (regs[3][0]),
        .addr_reg             (regs[4]),
        .nburst_reg           (regs[5]),
        .mst_write_probe_dbg1 (mst_write_probe_dbg)
    );

endmodule
