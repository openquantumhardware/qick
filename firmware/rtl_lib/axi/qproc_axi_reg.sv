///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : qproc_axi_reg
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    qproc_axi_reg.sv
//!
//! @brief   AXI4-Lite control/status register bank for the tProcessor v2.
//!
//! @details
//!
//!
//! Register map (byte-addressed, 32-bit registers, 6-bit address = 16 regs):
//!
//! addr 0x00  TPROC_CTRL   (r/w, [15:0])  - auto-clears to 0 one cycle after
//!                                          any nonzero write (one-shot pulse
//!                                          control register).
//! addr 0x04  TPROC_CFG    (r/w, [15:0])
//! addr 0x08  MEM_ADDR     (r/w, [15:0])
//! addr 0x0C  MEM_LEN      (r/w, [15:0])
//! addr 0x10  MEM_DT_I     (r/w, [31:0])
//! addr 0x14  TPROC_W_DT1  (r/w, [31:0])
//! addr 0x18  TPROC_W_DT2  (r/w, [31:0])
//! addr 0x1C  CORE_CFG     (r/w, [7:0])
//! addr 0x20  READ_SEL     (r/w, [7:0])
//! addr 0x24  (r/o)  fixed constant 32'd9 - core/version id.
//! addr 0x28  MEM_DT_O     (r/o, [31:0])
//! addr 0x2C  TPROC_R_DT1  (r/o, [31:0])
//! addr 0x30  TPROC_R_DT2  (r/o, [31:0])
//! addr 0x34  TIME_USR     (r/o, [31:0])
//! addr 0x38  TPROC_STATUS (r/o, [31:0])
//! addr 0x3C  TPROC_DEBUG  (r/o, [31:0])
//!
//! Reuses the shared axil_slv register-bank core (same AXI4-Lite protocol
//! FSM used across the repo) rather than hand-rolling a second one; the
//! TPROC_CTRL auto-clear pulse behavior is provided by axil_slv's
//! AUTO_CLEAR_BIT0 parameter (see firmware/rtl_lib/axi/axil_slv.sv).
//!
//! This replaces the legacy two-file split (`qproc_axi_reg.sv` thin wrapper
//! -> `axi_slv_qproc.vhd` AXI FSM): the VHDL engine is retired in favor of
//! axil_slv, and the `TYPE_IF_AXI_REG` interface (from the legacy
//! `_qproc_defines.svh`) is replaced by the modernized `axi4_lite_if`.
//!
//! @author  QICK Development Team
//!
//! @version 1.0

module qproc_axi_reg (
    input  logic          ps_aclk,
    input  logic          ps_aresetn,

    axi4_lite_if.slave     s_axi,

    output logic [15:0]   tproc_ctrl_o,
    output logic [15:0]   tproc_cfg_o,
    output logic [15:0]   mem_addr_o,
    output logic [15:0]   mem_len_o,
    output logic [31:0]   mem_dt_i_o,
    output logic [31:0]   tproc_w_dt1_o,
    output logic [31:0]   tproc_w_dt2_o,
    output logic [7:0]    core_cfg_o,
    output logic [7:0]    read_sel_o,

    input  logic [31:0]   mem_dt_o_i,
    input  logic [31:0]   tproc_r_dt1_i,
    input  logic [31:0]   tproc_r_dt2_i,
    input  logic [31:0]   time_usr_i,
    input  logic [31:0]   tproc_status_i,
    input  logic [31:0]   tproc_debug_i
);

    localparam int NUM_REGS = 16;
    localparam int AXI_AW   = 6;

    // Bits [15:9] (addr 9 fixed-id + addr 10-15 status pass-through) are
    // read-only; bits [8:0] (TPROC_CTRL..READ_SEL) are read/write.
    localparam logic [NUM_REGS-1:0] REG_IS_READONLY = {7'b1111111, 9'b0};

    logic [31:0] o_slv_regs [NUM_REGS];
    logic [31:0] i_slv_regs [NUM_REGS];

    axil_slv #(
        .AXI_DW          (32),
        .AXI_AW          (AXI_AW),
        .NUM_REGS        (NUM_REGS),
        .AUTO_CLEAR_BIT0 (1'b1)
    ) u_axil_slv (
        .s_axi_aclk         (ps_aclk),
        .s_axi_aresetn      (ps_aresetn),

        .s_axi_awaddr       (s_axi.awaddr[AXI_AW-1:0]),
        .s_axi_awprot       (s_axi.awprot),
        .s_axi_awvalid      (s_axi.awvalid),
        .s_axi_awready      (s_axi.awready),

        .s_axi_wdata        (s_axi.wdata),
        .s_axi_wstrb        (s_axi.wstrb),
        .s_axi_wvalid       (s_axi.wvalid),
        .s_axi_wready       (s_axi.wready),

        .s_axi_bresp        (s_axi.bresp),
        .s_axi_bvalid       (s_axi.bvalid),
        .s_axi_bready       (s_axi.bready),

        .s_axi_araddr       (s_axi.araddr[AXI_AW-1:0]),
        .s_axi_arprot       (s_axi.arprot),
        .s_axi_arvalid      (s_axi.arvalid),
        .s_axi_arready      (s_axi.arready),

        .s_axi_rdata        (s_axi.rdata),
        .s_axi_rresp        (s_axi.rresp),
        .s_axi_rvalid       (s_axi.rvalid),
        .s_axi_rready       (s_axi.rready),

        .o_slv_regs         (o_slv_regs),
        .i_slv_regs         (i_slv_regs),
        .i_reg_is_readonly  (REG_IS_READONLY)
    );

    // Read-only register contents (addr 9-15).
    assign i_slv_regs[0] = '0; // Unused (writable region, axil_slv reads o_slv_regs instead).
    assign i_slv_regs[1] = '0;
    assign i_slv_regs[2] = '0;
    assign i_slv_regs[3] = '0;
    assign i_slv_regs[4] = '0;
    assign i_slv_regs[5] = '0;
    assign i_slv_regs[6] = '0;
    assign i_slv_regs[7] = '0;
    assign i_slv_regs[8] = '0;
    assign i_slv_regs[9]  = 32'd9; // Fixed core/version id, matching legacy.
    assign i_slv_regs[10] = mem_dt_o_i;
    assign i_slv_regs[11] = tproc_r_dt1_i;
    assign i_slv_regs[12] = tproc_r_dt2_i;
    assign i_slv_regs[13] = time_usr_i;
    assign i_slv_regs[14] = tproc_status_i;
    assign i_slv_regs[15] = tproc_debug_i;

    // Writable register outputs (addr 0-8).
    assign tproc_ctrl_o  = o_slv_regs[0][15:0];
    assign tproc_cfg_o   = o_slv_regs[1][15:0];
    assign mem_addr_o    = o_slv_regs[2][15:0];
    assign mem_len_o     = o_slv_regs[3][15:0];
    assign mem_dt_i_o    = o_slv_regs[4];
    assign tproc_w_dt1_o = o_slv_regs[5];
    assign tproc_w_dt2_o = o_slv_regs[6];
    assign core_cfg_o    = o_slv_regs[7][7:0];
    assign read_sel_o    = o_slv_regs[8][7:0];

endmodule
