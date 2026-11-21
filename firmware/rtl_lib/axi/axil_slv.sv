///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axil_slv
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axil_slv.sv
//!
//! @brief   AXI4-Lite Slave interface for the XCOM core.
//!
//! @details
//!
//!
//! I/O ports corresponds to the AXI4 Interface definition.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module axil_slv#(
  // AXI parameters
  parameter integer AXI_DW = 32,           // Data width (32 or 64 bits)
  parameter integer AXI_AW = 8,            // Address width
  parameter integer NUM_REGS = 16,         // Number of registers
  parameter bit [NUM_REGS-1:0][AXI_DW-1:0] REG_INIT_VAL = '{default: '0},  // Initial value

  // Protection parameters (optional)
  parameter bit ENABLE_AW_EN = 1'b1,       // Enable aw_en logic (VHDL compatibility)
  parameter bit AUTO_CLEAR_BIT0 = 1'b0     // Auto-clear register 0 (whole word) one cycle after any nonzero write
)(
  // Global signals
  input  logic                                s_axi_aclk,
  input  logic                                s_axi_aresetn,

  // Write address channel
  input  logic [AXI_AW-1:0]                   s_axi_awaddr,
  input  logic [2:0]                          s_axi_awprot,
  input  logic                                s_axi_awvalid,
  output logic                                s_axi_awready,

  // Write data channel
  input  logic [AXI_DW-1:0]                   s_axi_wdata,
  input  logic [(AXI_DW/8)-1:0]               s_axi_wstrb,
  input  logic                                s_axi_wvalid,
  output logic                                s_axi_wready,

  // Write response channel
  output logic [1:0]                          s_axi_bresp,
  output logic                                s_axi_bvalid,
  input  logic                                s_axi_bready,

  // Read address channel
  input  logic [AXI_AW-1:0]                   s_axi_araddr,
  input  logic [2:0]                          s_axi_arprot,
  input  logic                                s_axi_arvalid,
  output logic                                s_axi_arready,

  // Read data channel
  output logic [AXI_DW-1:0]                   s_axi_rdata,
  output logic [1:0]                          s_axi_rresp,
  output logic                                s_axi_rvalid,
  input  logic                                s_axi_rready,

  // User registers interface
  output logic [AXI_DW-1:0]                   o_slv_regs [NUM_REGS],  // Writeable registers
  input  logic [AXI_DW-1:0]                   i_slv_regs [NUM_REGS],   // Read-only register values (external)
  input  logic [NUM_REGS-1:0]                 i_reg_is_readonly = '0   // Mask for read-only registers
);

  // AXI4-Lite internal signals
  logic                                axi_awready;
  logic                                axi_wready;
  logic [1:0]                          axi_bresp;
  logic                                axi_bvalid;
  logic                                axi_arready;
  logic [AXI_DW-1:0]                   axi_rdata;
  logic [1:0]                          axi_rresp;
  logic                                axi_rvalid;

  // Address latching
  logic [AXI_AW-1:0]                   axi_awaddr;
  logic [AXI_AW-1:0]                   axi_araddr;

  // Write enable control (from VHDL)
  logic                                aw_en;

  // Read address valid tracking
  logic                                rd_addr_accept;

  // Address decoding
  localparam integer BYTES_PER_WORD = AXI_DW / 8;
  localparam integer ADDR_LSB = $clog2(BYTES_PER_WORD);
  localparam integer ADDR_MSB = ADDR_LSB + $clog2(NUM_REGS) - 1;

  // Control signals
  logic                                slv_reg_wren;
  logic                                slv_reg_rden;

  // Register read data
  logic [AXI_DW-1:0]                   reg_data_out;

  // I/O connections assignment
  assign s_axi_awready = axi_awready;
  assign s_axi_wready  = axi_wready;
  assign s_axi_bresp   = axi_bresp;
  assign s_axi_bvalid  = axi_bvalid;
  assign s_axi_arready = axi_arready;
  assign s_axi_rdata   = axi_rdata;
  assign s_axi_rresp   = axi_rresp;
  assign s_axi_rvalid  = axi_rvalid;

  // ============================================
  // Write Address Channel with aw_en logic
  // (from VHDL for back-to-back transaction protection)
  // ============================================
  always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
      axi_awready <= 1'b0;
      aw_en <= 1'b1;
    end else begin
      if (ENABLE_AW_EN) begin
        // VHDL-compatible behavior with aw_en protection
        if (axi_awready == 1'b0 && s_axi_awvalid == 1'b1 &&
          s_axi_wvalid == 1'b1 && aw_en == 1'b1) begin
            axi_awready <= 1'b1;
            aw_en <= 1'b0;
          end else if (s_axi_bready == 1'b1 && axi_bvalid == 1'b1) begin
            aw_en <= 1'b1;
            axi_awready <= 1'b0;
          end else begin
            axi_awready <= 1'b0;
          end
      end else begin
        // Simplified version (assumes master follows protocol)
        if (~axi_awready && s_axi_awvalid && s_axi_wvalid) begin
          axi_awready <= 1'b1;
        end else begin
          axi_awready <= 1'b0;
        end
      end
    end
  end

  // Write address latching
  always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
      axi_awaddr <= {AXI_AW{1'b0}};
    end else begin
      if (ENABLE_AW_EN) begin
        // VHDL-compatible address latching
        if (axi_awready == 1'b0 && s_axi_awvalid == 1'b1 &&
          s_axi_wvalid == 1'b1 && aw_en == 1'b1) begin
            axi_awaddr <= s_axi_awaddr;
          end
      end else begin
        // Simplified version
        if (~axi_awready && s_axi_awvalid && s_axi_wvalid) begin
          axi_awaddr <= s_axi_awaddr;
        end
      end
    end
  end

  // ============================================
  // Write Data Channel
  // ============================================
  always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
      axi_wready <= 1'b0;
    end else begin
      if (ENABLE_AW_EN) begin
        // VHDL-compatible write ready
        if (axi_wready == 1'b0 && s_axi_wvalid == 1'b1 &&
          s_axi_awvalid == 1'b1 && aw_en == 1'b1) begin
            axi_wready <= 1'b1;
          end else begin
            axi_wready <= 1'b0;
          end
      end else begin
        // Simplified version
        if (~axi_wready && s_axi_wvalid && s_axi_awvalid) begin
          axi_wready <= 1'b1;
        end else begin
          axi_wready <= 1'b0;
        end
      end
    end
  end

  // Write enable generation
  assign slv_reg_wren = axi_wready && s_axi_wvalid && axi_awready && s_axi_awvalid;

  // ============================================
  // Register write logic with byte-enable support
  // and read-only register protection
  // ============================================
  always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
      // Initialize registers with parameterized values
      for (int i = 0; i < NUM_REGS; i++) begin
        o_slv_regs[i] <= REG_INIT_VAL[i];
      end
    end else begin
      // Auto-clear register 0 one cycle after it holds any nonzero value
      // (one-shot pulse register). Lower priority than the write below, so
      // a write to register 0 on this same cycle still lands.
      if (AUTO_CLEAR_BIT0 && (o_slv_regs[0] != '0)) begin
        o_slv_regs[0] <= '0;
      end
      if (slv_reg_wren) begin
        // Get register index from address
        automatic int reg_idx = axi_awaddr[ADDR_MSB:ADDR_LSB];

        // Only write if register is not read-only
        if (reg_idx < NUM_REGS && !i_reg_is_readonly[reg_idx]) begin
          // Only the byte lanes with their write strobe set (AXI4-Lite,
          // as the legacy Xilinx-template slaves do). PYNQ's MMIO always
          // writes whole words (all strobes set).
          for (int b = 0; b < AXI_DW/8; b++)
            if (s_axi_wstrb[b])
              o_slv_regs[reg_idx][8*b +: 8] <= s_axi_wdata[8*b +: 8];
        end
      end
    end
  end

  // ============================================
  // Write Response Channel
  // ============================================
  always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
      axi_bvalid <= 1'b0;
      axi_bresp  <= 2'b00;
    end else begin
      if (ENABLE_AW_EN) begin
        // VHDL-compatible response generation
        if (axi_awready == 1'b1 && s_axi_awvalid == 1'b1 &&
          axi_wready == 1'b1 && s_axi_wvalid == 1'b1 &&
          axi_bvalid == 1'b0) begin
            axi_bvalid <= 1'b1;
            axi_bresp  <= 2'b00;  // OKAY response
          end else if (s_axi_bready == 1'b1 && axi_bvalid == 1'b1) begin
            axi_bvalid <= 1'b0;
          end
      end else begin
        // Simplified version
        if (axi_awready && s_axi_awvalid && ~axi_bvalid &&
          axi_wready && s_axi_wvalid) begin
            axi_bvalid <= 1'b1;
            axi_bresp  <= 2'b00;
          end else if (s_axi_bready && axi_bvalid) begin
            axi_bvalid <= 1'b0;
          end
      end
    end
  end

  // ============================================
  // Read Address Channel
  // ============================================
  always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
      axi_arready <= 1'b0;
      axi_araddr  <= {AXI_AW{1'b0}};
      rd_addr_accept <= 1'b0;
    end else begin
      if (~axi_arready && s_axi_arvalid) begin
        axi_arready <= 1'b1;
        axi_araddr  <= s_axi_araddr;
        rd_addr_accept <= 1'b1;  // Mark that we're accepting an address
      end else begin
        axi_arready <= 1'b0;
        if (axi_rvalid && s_axi_rready) begin
          rd_addr_accept <= 1'b0;  // Clear after read completes
        end
      end
    end
  end

  // ============================================
  // Read Data Channel
  // ============================================
  always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
      axi_rvalid <= 1'b0;
      axi_rresp  <= 2'b00;
      axi_rdata  <= {AXI_DW{1'b0}};
    end else begin
      // Assert rvalid one cycle after accepting the address
      // (rd_addr_accept is set in cycle N, so rvalid goes high on cycle N+1)
      if (rd_addr_accept && ~axi_rvalid) begin
        axi_rvalid <= 1'b1;
        axi_rresp  <= 2'b00;  // OKAY response
        axi_rdata  <= reg_data_out;  // Latch data with properly latched address
      end else if (axi_rvalid && s_axi_rready) begin
        axi_rvalid <= 1'b0;
      end
    end
  end

  // Read enable generation (kept for backward compatibility, though not used)
  assign slv_reg_rden = axi_arready && s_axi_arvalid && ~axi_rvalid;

  // ============================================
  // Register read logic (combinational)
  // ============================================
  always_comb begin
    automatic int reg_idx = axi_araddr[ADDR_MSB:ADDR_LSB];

    if (reg_idx < NUM_REGS) begin
      // Read-only registers come from i_slv_regs; writable from o_slv_regs.
      reg_data_out = i_reg_is_readonly[reg_idx] ? i_slv_regs[reg_idx]
                                                : o_slv_regs[reg_idx];
    end else begin
      reg_data_out = {AXI_DW{1'b0}};
    end
  end

endmodule
