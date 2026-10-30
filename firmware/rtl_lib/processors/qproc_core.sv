///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : qproc_core
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    qproc_core.sv
//!
//! @brief   Ties the QICK tProcessor v2 CPU datapath (qcore_cpu) to its
//!          program/data/wave memory (qcore_mem) and captures input-port
//!          reads.
//!
//! @details
//!
//!
//! Adds one piece of glue beyond a plain qcore_cpu + qcore_mem wiring: a
//! registered `in_port_dt_r` that latches `port_dt_i[port_o.p_addr[3:0]]`
//! whenever `qcore_cpu` signals a port read (`port_re`), then feeds it back
//! into `qcore_cpu`'s `sreg_port_dt_i` (split into two 32-bit halves) on
//! the next instruction.
//!
//! Ported from firmware/ip/qick_processor/src/qproc_core.sv (unchanged;
//! assembled entirely from the already-ported qcore_cpu/qcore_mem lib cores
//! and tpv2_pkg -- no new primitives needed).
//!
//! @author  QICK Development Team
//!
//! @version 1.0

`include "tpv2_pkg.sv"

module qproc_core #(
    parameter int LFSR        = 1,
    parameter int IN_PORT_QTY = 1,
    parameter int PMEM_AW     = 8,
    parameter int DMEM_AW     = 8,
    parameter int WMEM_AW     = 8,
    parameter int REG_AW      = 4
) (
    input  logic c_clk_i,
    input  logic c_rst_ni,
    input  logic ps_clk_i,
    input  logic ps_rst_ni,
    input  logic en_i,
    input  logic restart_i,
    // Core ctrl
    input  logic [1:0]  lfsr_cfg_i,
    output logic [31:0] core_status_o,
    output logic [31:0] core_debug_o,
    output logic [31:0] lfsr_o,
    // AXI registers
    input  logic [63:0] port_dt_i [IN_PORT_QTY],
    input  logic         flag_i,
    // Special-function registers
    output logic [7:0]  sreg_cfg_o,
    output logic [7:0]  sreg_ctrl_o,
    input  logic [31:0] sreg_arith_i,
    input  logic [31:0] sreg_div_i[2],
    input  logic [31:0] sreg_status_i,
    input  logic [31:0] sreg_core_r_dt_i[2],
    input  logic [31:0] sreg_time_dt_i,
    output logic [31:0] sreg_core_w_dt_o[2],
    // Peripherals
    output logic         usr_en_o,
    output logic [7:0]   usr_ctrl_o,
    output logic [31:0]  usr_dt_a_o,
    output logic [31:0]  usr_dt_b_o,
    output logic [31:0]  usr_dt_c_o,
    output logic [31:0]  usr_dt_d_o,

    // Memory
    input  logic [1:0]   ps_mem_sel_i,
    input  logic         ps_mem_we_i,
    input  logic [15:0]  ps_mem_addr_i,
    input  logic [167:0] ps_mem_w_dt_i,
    output logic [167:0] ps_mem_r_dt_o,
    // Port
    output logic              port_we_o,
    output tpv2_pkg::PORT_DT  port_o,
    // Debug
    output logic [31:0] core_do
);

    logic [PMEM_AW-1:0] pmem_addr;
    logic                pmem_en;
    logic [71:0]         pmem_dt;
    logic                dmem_we;
    logic [DMEM_AW-1:0]  dmem_addr;
    logic [31:0]         dmem_w_dt;
    logic [31:0]         dmem_r_dt;
    logic                wmem_we;
    logic [WMEM_AW-1:0]  wmem_addr;
    logic [167:0]        wmem_w_dt;
    logic [167:0]        wmem_r_dt;

    logic port_re;

    logic [63:0] in_port_dt_r;

    qcore_cpu #(
        .LFSR    (LFSR),
        .PMEM_AW (PMEM_AW),
        .DMEM_AW (DMEM_AW),
        .WMEM_AW (WMEM_AW),
        .REG_AW  (REG_AW)
    ) core_cpu_i (
        .clk_i       (c_clk_i),
        .rst_ni      (c_rst_ni),
        .restart_i   (restart_i),
        .en_i        (en_i),
        .lfsr_cfg_i  (lfsr_cfg_i),
        .lfsr_o      (lfsr_o),
        .flag_i      (flag_i), // External condition
        .sreg_cfg_o       (sreg_cfg_o),
        .sreg_ctrl_o      (sreg_ctrl_o),
        .sreg_arith_i     (sreg_arith_i),     // Arith input
        .sreg_div_i       (sreg_div_i),       // Div input
        .sreg_status_i    (sreg_status_i),
        .sreg_core_r_dt_i (sreg_core_r_dt_i),
        .sreg_port_dt_i   ('{in_port_dt_r[31:0], in_port_dt_r[63:32]}),
        .sreg_time_dt_i   (sreg_time_dt_i),
        .sreg_core_w_dt_o (sreg_core_w_dt_o),
        .usr_ctrl_o  (usr_ctrl_o),
        .usr_en_o    (usr_en_o),
        .usr_dt_a_o  (usr_dt_a_o),
        .usr_dt_b_o  (usr_dt_b_o),
        .usr_dt_c_o  (usr_dt_c_o),
        .usr_dt_d_o  (usr_dt_d_o),
        .pmem_addr_o (pmem_addr),
        .pmem_en_o   (pmem_en),
        .pmem_dt_i   (pmem_dt),
        .dmem_we_o   (dmem_we),
        .dmem_addr_o (dmem_addr),
        .dmem_w_dt_o (dmem_w_dt),
        .dmem_r_dt_i (dmem_r_dt),
        .wmem_we_o   (wmem_we),
        .wmem_addr_o (wmem_addr),
        .wmem_w_dt_o (wmem_w_dt),
        .wmem_r_dt_i (wmem_r_dt),
        .port_we_o   (port_we_o),
        .port_re_o   (port_re),
        .port_o      (port_o),
        .core_do     (core_do)
    );

    // Port read
    ///////////////////////////////////////////////////////////////////////////
    always_ff @(posedge c_clk_i) begin
        if (restart_i)
            in_port_dt_r <= 0;
        else if (port_re)
            in_port_dt_r <= port_dt_i[port_o.p_addr[3:0]];
    end


    qcore_mem #(
        .PMEM_AW (PMEM_AW),
        .DMEM_AW (DMEM_AW),
        .WMEM_AW (WMEM_AW)
    ) core_mem_i (
        .c_clk_i       (c_clk_i),
        .c_rst_ni      (c_rst_ni),
        .ps_clk_i      (ps_clk_i),
        .ps_rst_ni     (ps_rst_ni),
        .ps_sel_i      (ps_mem_sel_i),
        .ps_we_i       (ps_mem_we_i),
        .ps_addr_i     (ps_mem_addr_i),
        .ps_w_dt_i     (ps_mem_w_dt_i),
        .ps_r_dt_o     (ps_mem_r_dt_o),
        .c_pmem_en_i   (pmem_en),
        .c_pmem_addr_i (pmem_addr),
        .c_pmem_r_dt_o (pmem_dt),
        .c_dmem_we_i   (dmem_we),
        .c_dmem_addr_i (dmem_addr),
        .c_dmem_w_dt_i (dmem_w_dt),
        .c_dmem_r_dt_o (dmem_r_dt),
        .c_wmem_we_i   (wmem_we),
        .c_wmem_addr_i (wmem_addr),
        .c_wmem_w_dt_i (wmem_w_dt),
        .c_wmem_r_dt_o (wmem_r_dt)
    );

    assign core_status_o = 0;
    assign core_debug_o  = 0;

endmodule
