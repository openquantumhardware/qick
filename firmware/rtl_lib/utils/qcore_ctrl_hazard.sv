///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : qcore_ctrl_hazard
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    qcore_ctrl_hazard.sv
//!
//! @brief   Data-hazard forwarding/stalling unit for the QICK tProcessor v2
//!          5-stage pipeline (IF/ID/RD/X1/X2).
//!
//! @details
//!
//!
//! Data hazards happen when an instruction in the RD stage needs a value an
//! earlier instruction still in the pipeline has not written back yet.
//!
//! - Forwarding: compares the source register(s) of the instruction in RD
//!   against the destination register of every instruction still in flight
//!   (X1, X2) and, if the data is already available combinationally
//!   (ALU/immediate result), forwards it instead of the stale register-file
//!   value.
//! - Stalling: when the needed data is not available yet (e.g. still being
//!   fetched from DMEM, or a special register whose source is being
//!   updated), asserts a one-cycle bubble instead.
//!
//! Possible register sources tracked: the data-register write-back path
//! (ALU/DMEM/immediate), the WREG bank, the peripheral (core) return-data
//! registers, the input-port registers, STATUS, TIME_USR, S_ADDR (jump
//! target) and S_RAND (LFSR).
//!
//! The stall of a special-register read after a peripheral instruction
//! (CORE_R_DT s6/s7, STATUS s10, TIME_USR s11) compares the reader, which is
//! the instruction in RD, against the OLDER instructions only (X1, X2). The
//! RD instruction itself is not "earlier": a PA/PB (or TIME inc_ref ...) that
//! reads s6/s7/s10/s11 as a source is itself a peripheral instruction, and
//! counting its own `rd_periph_use` made it wait for a result that it has to
//! issue first, which never comes (openquantumhardware/qick#359). The
//! address-section sources (rs_a_addr_i) take part in the same check.
//!
//! Ported from firmware/ip/qick_processor/src/qcore_ctrl_hazard.sv (behavior
//! unchanged except for the self-hazard above; ported to the tpv2_pkg
//! CTRL_REG type, made all previously implicit nets explicit, and renamed
//! rs_A_*/rs_D_*/reg_A_*/reg_D_* ports to lowercase for the repo's
//! signal-naming convention).
//!
//! @author  QICK Development Team
//!
//! @version 1.0

`include "tpv2_pkg.sv"

module qcore_ctrl_hazard (
    input  logic       clk_i,
    input  logic       rst_ni,
    input  logic       halt_i,
    input  logic [5:0] rs_a_addr_i [2],
    input  logic [31:0] rs_a_dt_i  [2],
    input  logic [6:0] rs_d_addr_i [2],
    input  logic [31:0] rs_d_dt_i  [2],
    // Register write-enable/destination per pipeline stage
    input  tpv2_pkg::CTRL_REG id_reg_i,
    input  tpv2_pkg::CTRL_REG rd_reg_i,
    input  tpv2_pkg::CTRL_REG x1_reg_i,
    input  tpv2_pkg::CTRL_REG x2_reg_i,
    input  tpv2_pkg::CTRL_REG wr_reg_i,
    // Peripheral
    input  logic       rd_periph_use,
    input  logic       x1_periph_use,
    input  logic       x2_periph_use,
    // Wave register
    input  logic       id_wmem_we,
    // Flag
    input  logic       id_flag_used,
    input  logic       flag_we,
    // PC jump
    input  logic       id_jmp_i,
    // ALU (00) data in each pipeline stage
    input  logic [31:0] x1_alu_dt_i,
    input  logic [31:0] x2_alu_dt_i,
    // DMEM (01) in each pipeline stage
    input  logic [31:0] x2_dmem_dt_i,
    // Immediate (11) data in each pipeline stage. rd_imm_dt_i is part of the
    // legacy interface but unused by this block's logic (kept for drop-in
    // compatibility with qcore_cpu).
    input  logic [31:0] rd_imm_dt_i,
    input  logic [31:0] x1_imm_dt_i,
    input  logic [31:0] x2_imm_dt_i,
    // Forwarded data
    output logic [31:0] reg_a_dt_o [2],
    output logic [31:0] reg_d_dt_o [2],
    // Bubble in RD and wait for data
    output logic        bubble_id_o,
    output logic        bubble_rd_o
);

    /* verilator lint_off UNUSED */
    wire unused_rd_imm_dt_i = |rd_imm_dt_i;
    /* verilator lint_on UNUSED */

    // DATA HAZARD

    // STALLING
    logic stall_id_w;    // Give time to update R_WAVE
    logic stall_id_f;    // Give time to update FLAG
    logic stall_id_j;    // Give time to update S_ADDR when JUMP
    logic stall_id_rand; // Gives time to update rand number

    logic stall_rd_core_rdt; // Gives time to update core_r_dt after Peripheral or S_CTRL
    logic stall_rd_port;     // Gives time to update PORT_L & PORT_H after DPORT_RD
    logic stall_rd_status;   // Gives time to update STATUS after Peripheral or S_CTRL
    logic stall_rd_stime;    // Gives time to update s_out_time after TIME instruction
    logic [1:0] w_stall_d_rd; // Gives time to update R_WAVE when REG_WR r_wave
    logic [1:0] d_stall_d_rd; // Gives time to READ MEMORY
    logic [1:0] stall_a_rd;   // Gives time to READ MEMORY

    // DATA FORWARDING
    logic [1:0]  fwd_d_x1, fwd_d_x2;
    logic [31:0] reg_d_nxt [2];

    // ADDRESS FORWARDING
    logic [1:0]  fwd_a_x1, fwd_a_x2;
    logic [31:0] reg_a_nxt [2];

    logic [1:0] rfrom_rand_r, rfrom_core_r, rfrom_port_r, rfrom_status_r, rfrom_stime_r;
    // Same classification, but for the address-section sources (rs_a_addr_i).
    // Without these, reading s1/s6/s7/s8/s9/s10/s11 through the A/B operand
    // slots (e.g. PA/PB's DATA_A/DATA_B, or ARITH's RsA/RsB) missed the
    // corresponding stall below -- see openquantumhardware/qick#359
    // (openquantumhardware/qick#359): using s6/s7 as a PA/PB source register
    // hung the core because the read-after-peripheral-write hazard was only
    // ever checked on the D-section sources.
    logic [1:0] afrom_rand_r, afrom_core_r, afrom_port_r, afrom_status_r, afrom_stime_r;

    logic rfrom_rand, rfrom_core_rdt, rfrom_port, rfrom_status, rfrom_stime;
    logic port_re;
    logic wto_r_wave, wto_wreg, wto_qp, wto_s_cfg, wto_s_addr, wto_s_rand;

    assign rfrom_rand     = (|rfrom_rand_r)   | (|afrom_rand_r);   // READ FROM S_RAND (s1)
    assign rfrom_core_rdt = (|rfrom_core_r)   | (|afrom_core_r);   // READ FROM CORE_R_DT (s6, s7)
    assign rfrom_port     = (|rfrom_port_r)   | (|afrom_port_r);   // READ FROM IN_PORT (s8, s9)
    assign rfrom_status   = (|rfrom_status_r) | (|afrom_status_r); // READ FROM STATUS (s10)
    assign rfrom_stime    = (|rfrom_stime_r)  | (|afrom_stime_r);  // READ FROM TIME_USR (s11)
    assign port_re = rd_reg_i.port_re | x1_reg_i.port_re | x2_reg_i.port_re; // PORT READ COMMAND

    // WREG IS BEING UPDATED
    assign wto_r_wave = rd_reg_i.r_wave_we | x1_reg_i.r_wave_we | x2_reg_i.r_wave_we;
    assign wto_wreg   = rd_reg_i.addr[6:5] == 2'b10 | x1_reg_i.addr[6:5] == 2'b10 | x2_reg_i.addr[6:5] == 2'b10;
    // PERIPHERAL IS BEING UPDATED
    assign wto_qp = rd_periph_use | x1_periph_use | x2_periph_use;
    // Same, without the instruction in RD (the one that reads): for the stalls of reads in RD (see the header)
    logic wto_qp_prev;
    assign wto_qp_prev = x1_periph_use | x2_periph_use;
    // SFR CFG OR CTRL IS BEING UPDATED
    assign wto_s_cfg = (rd_reg_i.addr == 7'b0000010) | (x1_reg_i.addr == 7'b0000010)
                      | (x2_reg_i.addr == 7'b0000010) | (wr_reg_i.addr == 7'b0000010);
    // SFR S_ADDR IS BEING UPDATED
    assign wto_s_addr = (rd_reg_i.addr == 7'b00_01111) | (x1_reg_i.addr == 7'b00_01111)
                       | (x2_reg_i.addr == 7'b00_01111);
    // SFR S_RAND IS BEING UPDATED
    assign wto_s_rand = (rd_reg_i.addr == 7'b00_00001) | (x1_reg_i.addr == 7'b00_00001)
                       | (x2_reg_i.addr == 7'b00_00001);

    // (A and B) READ dreg, sreg, wreg or DMEM
    ///////////////////////////////////////////////////////////////////////////
    // REG_WR after REG_WR
    for (genvar ind_d = 0; ind_d < 2; ind_d++) begin : gen_fwd_d
        // Check for read
        always_comb begin
            rfrom_rand_r[ind_d]   = (rs_d_addr_i[ind_d][6:0] == 7'b00_00001); // sfr(s1)
            rfrom_status_r[ind_d] = (rs_d_addr_i[ind_d][6:0] == 7'b00_01010); // sfr(s10)
            rfrom_stime_r[ind_d]  = (rs_d_addr_i[ind_d][6:0] == 7'b00_01011); // sfr(s11)
            rfrom_core_r[ind_d]   = (rs_d_addr_i[ind_d][6:1] == 6'b00_0011);  // sfr, address 6 or 7
            rfrom_port_r[ind_d]   = (rs_d_addr_i[ind_d][6:1] == 6'b00_0100);  // sfr, address 8 or 9
        end
        // 1- Use data register after REG_WR to register
        always_comb begin
            reg_d_nxt[ind_d]    = rs_d_dt_i[ind_d];
            d_stall_d_rd[ind_d] = 1'b0;
            fwd_d_x1[ind_d] = ((rs_d_addr_i[ind_d] == x1_reg_i.addr) & x1_reg_i.we); // Data is in X1 stage
            fwd_d_x2[ind_d] = ((rs_d_addr_i[ind_d] == x2_reg_i.addr) & x2_reg_i.we); // Data is in X2 stage
            if (fwd_d_x1[ind_d]) // Data is in X1 stage
                unique case (x1_reg_i.src)
                    2'b00:   reg_d_nxt[ind_d]    = x1_alu_dt_i; // Data comes from ALU
                    2'b01:   d_stall_d_rd[ind_d] = 1'b1;        // Data comes from data memory
                    2'b11:   reg_d_nxt[ind_d]    = x1_imm_dt_i; // Data comes from immediate
                    default: ;
                endcase
            else if (fwd_d_x2[ind_d]) // Data is in X2 stage
                unique case (x2_reg_i.src)
                    2'b00:   reg_d_nxt[ind_d] = x2_alu_dt_i;  // Data comes from ALU
                    2'b01:   reg_d_nxt[ind_d] = x2_dmem_dt_i; // Data comes from data memory
                    2'b11:   reg_d_nxt[ind_d] = x2_imm_dt_i;  // Data comes from immediate
                    default: ;
                endcase
        end
        // 2) Use WREG after REG_WR r_wave
        always_comb begin
            w_stall_d_rd[ind_d] = rs_d_addr_i[ind_d][6:5] == 2'b10 & wto_r_wave; // WREG read and modified
        end
    end

    for (genvar ind_a = 0; ind_a < 2; ind_a++) begin : gen_fwd_a
        // Check for read (mirrors gen_fwd_d's classification above, but for
        // the narrower 6-bit address-section source; s1/s6-s11 all fit
        // within 6 bits so the same address constants apply, just without
        // the always-0 top bit of the 7-bit rs_d_addr_i field).
        always_comb begin
            afrom_rand_r[ind_a]   = (rs_a_addr_i[ind_a][5:0] == 6'b00_0001); // sfr(s1)
            afrom_status_r[ind_a] = (rs_a_addr_i[ind_a][5:0] == 6'b00_1010); // sfr(s10)
            afrom_stime_r[ind_a]  = (rs_a_addr_i[ind_a][5:0] == 6'b00_1011); // sfr(s11)
            afrom_core_r[ind_a]   = (rs_a_addr_i[ind_a][5:1] == 5'b0_0011);  // sfr, address 6 or 7
            afrom_port_r[ind_a]   = (rs_a_addr_i[ind_a][5:1] == 5'b0_0100);  // sfr, address 8 or 9
        end
        // 1-ADDRESS) REG_WR from address register after REG_WR to register
        always_comb begin
            reg_a_nxt[ind_a]  = rs_a_dt_i[ind_a];
            stall_a_rd[ind_a] = 1'b0;
            fwd_a_x1[ind_a] = (({1'b0, rs_a_addr_i[ind_a]} == x1_reg_i.addr) & x1_reg_i.we); // Address is in X1 stage
            fwd_a_x2[ind_a] = (({1'b0, rs_a_addr_i[ind_a]} == x2_reg_i.addr) & x2_reg_i.we); // Address is in X2 stage
            if (fwd_a_x1[ind_a]) // Address is in X1 stage
                unique case (x1_reg_i.src)
                    2'b00:   reg_a_nxt[ind_a]  = x1_alu_dt_i; // Address comes from ALU
                    2'b01:   stall_a_rd[ind_a] = 1'b1;        // Address comes from data memory
                    2'b11:   reg_a_nxt[ind_a]  = x1_imm_dt_i; // Address comes from immediate
                    default: ;
                endcase
            else if (fwd_a_x2[ind_a]) // Address is in X2 stage
                unique case (x2_reg_i.src)
                    2'b00:   reg_a_nxt[ind_a] = x2_alu_dt_i;  // Address comes from ALU
                    2'b01:   reg_a_nxt[ind_a] = x2_dmem_dt_i; // Address comes from data memory
                    2'b11:   reg_a_nxt[ind_a] = x2_imm_dt_i;  // Address comes from immediate
                    default: ;
                endcase
        end
    end

    // (C) READ r_wave
    ///////////////////////////////////////////////////////////////////////////
    // 3) WMEM_WR after REG_WR r_wave or wreg write
    always_comb begin
        stall_id_w = 1'b0;
        if (id_wmem_we)
            if (wto_r_wave | wto_wreg)
                stall_id_w = 1'b1;
    end

    // (D) CORE_R_DT
    ///////////////////////////////////////////////////////////////////////////
    // 4) CORE_R_DT read after S_CONF write
    always_comb begin
        stall_rd_core_rdt = 1'b0;
        if (rfrom_core_rdt)
            if (wto_qp_prev | wto_s_cfg)
                stall_rd_core_rdt = 1'b1;
    end

    // (E) IN_PORT
    ///////////////////////////////////////////////////////////////////////////
    // 5) IN_PORT read after DPORT_RD
    always_comb begin
        stall_rd_port = 1'b0;
        if (rfrom_port)
            if (port_re)
                stall_rd_port = 1'b1;
    end

    // (F) STATUS
    ///////////////////////////////////////////////////////////////////////////
    // 6) STATUS read after S_CTRL write or write to peripheral
    always_comb begin
        stall_rd_status = 1'b0;
        if (rfrom_status)
            if (wto_qp_prev | wto_s_cfg)
                stall_rd_status = 1'b1;
    end

    // (G) TIME_USR
    ///////////////////////////////////////////////////////////////////////////
    // 7) TIME_USR read after peripheral (TIME inc_ref is peripheral)
    always_comb begin
        stall_rd_stime = 1'b0;
        if (rfrom_stime)
            if (wto_qp_prev)
                stall_rd_stime = 1'b1;
    end

    // (H) S_ADDR
    ///////////////////////////////////////////////////////////////////////////
    // 8) JUMP after WRITE_REG s_addr -> STALL
    always_comb begin
        stall_id_j = 1'b0;
        if (wto_s_addr)
            if (id_jmp_i)
                stall_id_j = 1'b1;
    end

    // (I) Flag used
    ///////////////////////////////////////////////////////////////////////////
    // 9)  -if() after -uf -> STALL
    // 10) -if() after s_cfg -> STALL
    // 11) -if() after FLAG set or clear
    always_comb begin
        stall_id_f = 1'b0;
        if (id_flag_used) begin // Flag is used
            if (flag_we)              // a) ALU flag is being updated
                stall_id_f = 1'b1;
            else if (wto_s_cfg)       // b) SRC flag could be updated or cleared
                stall_id_f = 1'b1;
            else if (wto_qp)          // c) Peripheral was used
                stall_id_f = 1'b1;
        end
    end

    // (J) RAND used
    ///////////////////////////////////////////////////////////////////////////
    // 12) RAND read after READ -> STALL
    // 13) RAND read after WRITE -> STALL
    always_comb begin
        stall_id_rand = 1'b0;
        if (wto_s_rand | rfrom_rand)
            stall_id_rand = 1'b1;
    end

    // OUTPUTS
    ///////////////////////////////////////////////////////////////////////////
    // Data-forwarding register
    logic [31:0] reg_a [2];
    logic [31:0] reg_d [2];

    always_ff @(posedge clk_i, negedge rst_ni)
        if (!rst_ni) begin
            reg_a <= '{default: '0};
            reg_d <= '{default: '0};
        end else if (~halt_i) begin
            reg_a <= reg_a_nxt;
            reg_d <= reg_d_nxt;
        end

    assign reg_a_dt_o  = reg_a;
    assign reg_d_dt_o  = reg_d;
    assign bubble_id_o = stall_id_j | stall_id_f | stall_id_w | stall_id_rand;
    assign bubble_rd_o = |stall_a_rd | |d_stall_d_rd | |w_stall_d_rd | stall_rd_stime | stall_rd_status
                        | stall_rd_port | stall_rd_core_rdt;

endmodule
