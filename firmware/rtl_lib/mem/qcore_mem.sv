///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : qcore_mem
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    qcore_mem.sv
//!
//! @brief   Program/data/wave memory bank for the QICK tProcessor v2 core.
//!
//! @details
//!
//!
//! Instantiates three independent dual-clock, dual-port BRAMs (program,
//! data, wave), each accessible from the core datapath on port A
//! (c_clk_i domain) and from an external debug/PS access port B
//! (ps_clk_i domain). ps_sel_i selects which of the three banks the
//! external port B currently targets; ps_r_dt_o is zero-extended to the
//! widest bank (wave memory, 168 bits) regardless of which bank was read.
//!
//! ps_sel_i encoding:
//! * 2'b01 : program memory
//! * 2'b10 : data memory
//! * 2'b11 : wave memory
//! * 2'b00 : none (no bank selected, ps_r_dt_o = 0)
//!
//! @author  QICK Development Team
//!
//! @version 1.0

module qcore_mem #(
    parameter int PMEM_AW = 16,
    parameter int DMEM_AW = 16,
    parameter int WMEM_AW = 16
)(
    // Clock & reset
    input  logic         c_clk_i,
    input  logic         c_rst_ni,
    input  logic         ps_clk_i,
    input  logic         ps_rst_ni,
    input  logic [1:0]   ps_sel_i,
    input  logic         ps_we_i,
    input  logic [15:0]  ps_addr_i,
    input  logic [167:0] ps_w_dt_i,
    output logic [167:0] ps_r_dt_o,

    // Program memory
    input  logic                  c_pmem_en_i,
    input  logic [PMEM_AW-1:0]    c_pmem_addr_i,
    output logic [71:0]           c_pmem_r_dt_o,

    // Data memory
    input  logic                  c_dmem_we_i,
    input  logic [DMEM_AW-1:0]    c_dmem_addr_i,
    input  logic [31:0]           c_dmem_w_dt_i,
    output logic [31:0]           c_dmem_r_dt_o,

    // Wave memory
    input  logic                  c_wmem_we_i,
    input  logic [WMEM_AW-1:0]    c_wmem_addr_i,
    input  logic [167:0]          c_wmem_w_dt_i,
    output logic [167:0]          c_wmem_r_dt_o
);

    logic [71 :0] ps_p_r_dt;
    logic [31 :0] ps_d_r_dt;
    logic [167:0] ps_w_r_dt;

    // External (PS-side) port-B enables, decoded from ps_sel_i.
    logic ext_p_mem_en, ext_d_mem_en, ext_w_mem_en;
    logic ext_p_mem_we, ext_d_mem_we, ext_w_mem_we;

    assign ext_p_mem_en = (ps_sel_i == 2'b01);
    assign ext_d_mem_en = (ps_sel_i == 2'b10);
    assign ext_w_mem_en = (ps_sel_i == 2'b11);

    assign ext_p_mem_we = ext_p_mem_en & ps_we_i;
    assign ext_d_mem_we = ext_d_mem_en & ps_we_i;
    assign ext_w_mem_we = ext_w_mem_en & ps_we_i;

    always_comb begin
        unique case (ps_sel_i)
            2'b01:   ps_r_dt_o = {96'd0,  ps_p_r_dt};
            2'b10:   ps_r_dt_o = {136'd0, ps_d_r_dt};
            2'b11:   ps_r_dt_o = ps_w_r_dt;
            default: ps_r_dt_o = '0;
        endcase
    end

    //--------------------------------------------------------------------------
    // Program memory
    //--------------------------------------------------------------------------
    bram_tdp_banked #(
        .MEM_AW  (PMEM_AW),
        .MEM_DW  (72),
        .RAM_OUT ("NO_REGISTERED")
    ) p_mem_i (
        .clk_a_i  (c_clk_i),
        .en_a_i   (c_pmem_en_i),
        .we_a_i   (1'b0),
        .addr_a_i (c_pmem_addr_i),
        .dt_a_i   (72'd0),
        .dt_a_o   (c_pmem_r_dt_o),
        .clk_b_i  (ps_clk_i),
        .en_b_i   (ext_p_mem_en),
        .we_b_i   (ext_p_mem_we),
        .addr_b_i (ps_addr_i[PMEM_AW-1:0]),
        .dt_b_i   (ps_w_dt_i[71:0]),
        .dt_b_o   (ps_p_r_dt)
    );

    //--------------------------------------------------------------------------
    // Data memory
    //--------------------------------------------------------------------------
    bram_tdp_banked #(
        .MEM_AW  (DMEM_AW),
        .MEM_DW  (32),
        .RAM_OUT ("NO_REGISTERED")
    ) d_mem_i (
        .clk_a_i  (c_clk_i),
        .en_a_i   (1'b1),
        .we_a_i   (c_dmem_we_i),
        .addr_a_i (c_dmem_addr_i),
        .dt_a_i   (c_dmem_w_dt_i),
        .dt_a_o   (c_dmem_r_dt_o),
        .clk_b_i  (ps_clk_i),
        .en_b_i   (ext_d_mem_en),
        .we_b_i   (ext_d_mem_we),
        .addr_b_i (ps_addr_i[DMEM_AW-1:0]),
        .dt_b_i   (ps_w_dt_i[31:0]),
        .dt_b_o   (ps_d_r_dt)
    );

    //--------------------------------------------------------------------------
    // Wave memory
    //--------------------------------------------------------------------------
    bram_tdp_banked #(
        .MEM_AW  (WMEM_AW),
        .MEM_DW  (168),
        .RAM_OUT ("NO_REGISTERED")
    ) w_mem_i (
        .clk_a_i  (c_clk_i),
        .en_a_i   (1'b1),
        .we_a_i   (c_wmem_we_i),
        .addr_a_i (c_wmem_addr_i),
        .dt_a_i   (c_wmem_w_dt_i),
        .dt_a_o   (c_wmem_r_dt_o),
        .clk_b_i  (ps_clk_i),
        .en_b_i   (ext_w_mem_en),
        .we_b_i   (ext_w_mem_we),
        .addr_b_i (ps_addr_i[WMEM_AW-1:0]),
        .dt_b_i   (ps_w_dt_i),
        .dt_b_o   (ps_w_r_dt)
    );

endmodule
