///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : qcore_cpu
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    qcore_cpu.sv
//!
//! @brief   5-stage pipelined CPU datapath for the QICK tProcessor v2 core.
//!
//! @details
//!
//!
//! Pipeline stages: IF (instruction fetch) -> ID (decode) -> RD (register
//! read, with forwarding/stalling from qcore_ctrl_hazard) -> X1 (address
//! calculation / ALU execute) -> X2 (memory/port write-back staging) ->
//! WRITE (register-bank commit).
//!
//! Ties together:
//! * qcore_ctrl_hazard : data-hazard forwarding/stalling.
//! * qcore_reg_bank     : SFR/data/wave register file (also owns the LFSR).
//! * tpv2_alu            : 2-input combinational ALU (X1 stage).
//! * tpv2_stack (LIFO)   : CALL/RET return-address stack.
//!
//! Ported from firmware/ip/qick_processor/src/qcore_cpu.sv (behavior
//! unchanged; ported to tpv2_pkg types, AB_alu/LIFO replaced by the
//! tpv2_alu/tpv2_stack lib cores, all previously-implicit nets made
//! explicit, and signals with embedded uppercase - PC_curr, id_HEADER,
//! rs_A_*, etc. - renamed to the repo's lowercase signal convention).
//!
//! @author  QICK Development Team
//!
//! @version 1.0

`include "tpv2_pkg.sv"

module qcore_cpu #(
    parameter int LFSR    = 1,
    parameter int PMEM_AW = 8,
    parameter int DMEM_AW = 8,
    parameter int WMEM_AW = 8,
    parameter int REG_AW  = 4
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        restart_i,
    input  logic        en_i,
    input  logic [1:0]  lfsr_cfg_i, // Configuration (LFSR)
    output logic [31:0] lfsr_o,
    // Debug
    output logic [31:0] core_do, // Core signal debug
    // Conditions
    input  logic         flag_i, // External condition
    // Special-function register interface
    output logic [7:0]  sreg_cfg_o,
    output logic [7:0]  sreg_ctrl_o,
    input  logic [31:0] sreg_arith_i,
    input  logic [31:0] sreg_div_i      [2],
    input  logic [31:0] sreg_status_i,
    input  logic [31:0] sreg_core_r_dt_i[2],
    input  logic [31:0] sreg_port_dt_i  [2],
    input  logic [31:0] sreg_time_dt_i,
    output logic [31:0] sreg_core_w_dt_o[2],
    output logic         usr_en_o,   // Control enable
    output logic [7:0]   usr_ctrl_o, // Control from current instruction
    output logic [31:0]  usr_dt_a_o, // Data A from current instruction (rsD0)
    output logic [31:0]  usr_dt_b_o, // Data B from current instruction (rsD1)
    output logic [31:0]  usr_dt_c_o, // Data C from current instruction (rsA0)
    output logic [31:0]  usr_dt_d_o, // Data D from current instruction (rsA1)
    // Program memory
    output logic [PMEM_AW-1:0] pmem_addr_o,
    output logic                pmem_en_o,
    input  logic [71:0]         pmem_dt_i,
    // Data memory
    output logic                dmem_we_o,
    output logic [DMEM_AW-1:0]  dmem_addr_o,
    output logic [31:0]         dmem_w_dt_o,
    input  logic [31:0]         dmem_r_dt_i,
    // Wave memory
    output logic                 wmem_we_o,
    output logic [WMEM_AW-1:0]   wmem_addr_o,
    output logic [167:0]         wmem_w_dt_o,
    input  logic [167:0]         wmem_r_dt_i,
    // Output ports
    output logic          port_we_o,
    output logic          port_re_o,
    output tpv2_pkg::PORT_DT port_o
);

    import tpv2_pkg::*;

    ///////////////////////////////////////////////////////////////////////////
    // Signal declaration

    // Address signals
    logic [10:0] r_id_imm_addr, r_rd_imm_addr;
    logic [5:0]  r_rd_rs_a1_addr;
    logic [PMEM_AW-1:0] reg_addr;
    // Data signals
    logic [31:0] r_id_imm_dt, r_rd_imm_dt, r_x1_imm_dt;
    logic [31:0] r_x1_alu_dt;
    // Data signals
    logic [31:0] x1_alu_dt;
    logic        x1_alu_fz, x1_alu_fc, x1_alu_fs;
    logic [WMEM_AW-1:0] x1_wave_addr;
    // Pipeline registers
    logic [PMEM_AW-1:0] pc_curr, pc_next, pc_prev;
    logic [2:0]          cfg_pc_nxt;

    logic       id_pc_change;
    logic       r_id_pc_change;
    logic [5:0] r_id_rs_a_addr [2]; // Address in the reg bank
    logic [6:0] r_id_rs_d_addr [2]; // Address in the reg bank
    logic [31:0] reg_d_fwd_dt [2];
    logic [31:0] reg_a_fwd_dt [2];
    logic [31:0] reg_time;

    // PROCESSOR STATUS
    ///////////////////////////////////////////////////////////////////////////
    logic halt, flush, stall, bubble_id, bubble_rd, fetch_en;

    assign halt     = ~en_i;
    assign flush    = id_pc_change | r_id_pc_change;
    assign stall    = bubble_id | bubble_rd;
    assign fetch_en = ~stall & ~halt;


    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // IF - 1 First stage IF_ (instruction fetch)
    ///////////////////////////////////////////////////////////////////////////////////////////////////

    logic [15:0] if_op_code;
    logic [55:0] if_op_data;
    logic [15:0] r_if_op_code;
    logic [55:0] r_if_op_data;
    logic        r_mem_rst;
    assign if_op_code = pmem_dt_i[71:56];
    assign if_op_data = pmem_dt_i[55:0];

    // Empty memory pipeline
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            r_mem_rst    <= 1;
            r_if_op_code <= 0;
            r_if_op_data <= 0;
        end else if (restart_i) begin
            r_mem_rst    <= 1;
            r_if_op_code <= 0;
            r_if_op_data <= 0;
        end else begin
            r_mem_rst <= 0;
            if (r_mem_rst) begin
                r_if_op_code <= 0;
                r_if_op_data <= 0;
            end else if (pmem_en_o) begin
                if (flush) begin
                    r_if_op_code <= 0;
                    r_if_op_data <= 0;
                end else begin
                    r_if_op_code <= if_op_code;
                    r_if_op_data <= if_op_data;
                end
            end
        end
    end


    ///////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // ID - 2 Second stage ID_ instruction decoder
    ///////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////

    // CONTROL
    ///////////////////////////////////////////////////////////
    logic [2:0] id_header;
    logic       id_ai;
    logic [1:0] id_df;
    logic [2:0] id_cond;
    logic       id_so, id_to;

    assign id_header = r_if_op_code[15:13];
    assign id_ai     = r_if_op_code[12];
    assign id_df     = r_if_op_code[11:10];
    assign id_cond   = r_if_op_code[9:7];
    assign id_so     = r_if_op_code[6];
    assign id_to     = r_if_op_code[5];


    logic id_type_cfg, id_type_br, id_type_int_ctrl, id_type_ext_ctrl;
    logic id_type_wr, id_type_wrd, id_type_wrw, id_type_wra;
    logic id_type_wp, id_type_wpd, id_type_wpw;
    logic id_type_wm, id_type_wmd, id_type_wmw;

    logic id_cfg_port_src, id_cfg_alu_src, id_cfg_dt_imm;
    logic [3:0] id_cfg_alu_op;
    logic [1:0] id_cfg_reg_src;
    logic cfg_dual_regs_en, cfg_flag_en, cfg_dual_port_en, cfg_dual_wmem_en;
    logic cfg_dual_regs_we, cfg_dual_port_we, cfg_dual_wmem_we;
    logic id_flag_we;
    logic id_dmem_we, id_wmem_we;
    logic id_dreg_we, id_r_wave_we;
    logic id_dport_re, id_dport_we, id_wport_we;

    logic id_call, id_ret;

    logic [8:0] id_usr_ctrl; // MSB indicates internal or external
    logic id_cond_ok, id_exec_ok, id_branch_cond_ok;
    logic alu_fz_r, alu_fs_r;

    always_comb begin : decoder
        id_type_cfg      = (id_header == CFG);
        id_type_br       = (id_header == BRANCH);
        id_type_wr       = (id_header == REG_WR);
        id_type_wm       = (id_header == MEM_WR);
        id_type_wp       = (id_header == PORT_WR);
        id_type_int_ctrl = (id_header == INT_CTRL);
        id_type_ext_ctrl = (id_header == EXT_CTRL);
        id_type_wra      = id_type_wr & (~id_so & ~id_to); // Write data register from ALU
        id_type_wrd      = id_type_wr & ~(id_so & ~id_to); // Write data register (ALU, MEM or IMM)
        id_type_wrw      = id_type_wr & (id_so & ~id_to);  // Write wave data register
        id_type_wmd      = id_type_wm & ~id_so;            // Write data memory
        id_type_wmw      = id_type_wm & id_so;             // Write wave memory
        id_type_wpd      = id_type_wp & ~id_so;            // Write data port
        id_type_wpw      = id_type_wp & id_so;             // Write wave port

        id_cfg_port_src = r_if_op_code[8];
        // Immediate input data
        id_cfg_dt_imm   = &id_df | ((id_type_wm | id_type_cfg) & id_to) | (id_type_wpd & id_cfg_port_src);
        id_cfg_alu_src  = (id_df == 2'b10); // With DF=10 source=1
        id_cfg_alu_op   = id_type_wra ? r_if_op_code[3:0] : {1'b0, r_if_op_code[1:0], 1'b0};
        id_cfg_reg_src  = id_type_wrd ? r_if_op_code[6:5] : {2{r_if_op_code[2]}}; // When writing WAVE, second option
        cfg_dual_regs_en = (id_type_wrw | id_type_wm | id_type_wp | id_type_br | id_type_cfg);
        cfg_flag_en      = cfg_dual_regs_en | id_type_wr; // Is possible to update flag
        cfg_dual_port_en = id_type_wrw | id_type_wmw;     // Is possible to dual PORT write
        cfg_dual_wmem_en = id_type_wrw | id_type_wpw;     // Is possible to dual WMEM write
        cfg_dual_regs_we = cfg_dual_regs_en & r_if_op_code[3]; // Dual register write enable
        cfg_dual_port_we = cfg_dual_port_en & r_if_op_code[7]; // Dual port write enable
        cfg_dual_wmem_we = cfg_dual_wmem_en & r_if_op_code[9]; // Dual WMEM write enable
        id_flag_we   = id_exec_ok & cfg_flag_en & r_if_op_code[4];        // Flag write enable
        id_dreg_we   = id_exec_ok & (id_type_wrd | cfg_dual_regs_we);     // DREG write enable
        id_r_wave_we = id_type_wrw;                                      // WREG write enable (the 167 bits)
        id_dmem_we   = id_exec_ok & id_type_wmd;                         // DMEM write enable
        id_wmem_we   = id_type_wmw | (cfg_dual_wmem_we & r_if_op_code[9]); // WMEM write enable
        id_dport_we  = id_type_wpd & r_if_op_code[7];                    // DPORT write enable
        id_dport_re  = id_type_wpd & ~r_if_op_code[7];                   // DPORT read enable
        id_wport_we  = id_type_wpw | cfg_dual_port_we;                   // WPORT write enable
        id_call = id_branch_cond_ok & id_so & ~id_to; // Execute CALL instruction (push)
        id_ret  = id_type_br & id_so & id_to;         // Execute RET instruction (pull)
        id_usr_ctrl = id_type_int_ctrl ? {id_exec_ok, 1'b0, r_if_op_code[6:0]}
                    : id_type_ext_ctrl ? {id_exec_ok, 1'b1, r_if_op_code[6:0]}
                    : 9'b0;
    end



    logic [31:0] id_imm_dt;
    logic [15:0] id_imm_addr;
    logic [5:0]  id_rs_a_addr [2];
    logic [6:0]  id_rs_d_addr [2];
    logic [6:0]  id_rd_addr;
    logic [PMEM_AW-1:0] pc_stack;

    ///////////////////////////////////////////////////////////////////////////
    // Data
    always_comb
        unique case (id_df)
            2'b00: id_imm_dt = id_imm_addr;                                    // 16-bit address space
            2'b01: id_imm_dt = {{16{r_if_op_data[22]}}, r_if_op_data[22:7]};   // 16-bit signed
            2'b10: id_imm_dt = {{8{r_if_op_data[30]}}, r_if_op_data[30:7]};    // 24-bit signed
            2'b11: id_imm_dt = r_if_op_data[38:7];                             // 32-bit
        endcase

    ///////////////////////////////////////////////////////////////////////////
    // Address
    // Immediate data is not register address
    logic id_use_rd0, id_use_rd1;
    assign id_use_rd0 = id_df != 2'b11;
    assign id_use_rd1 = id_df == 2'b01;

    always_comb begin
        id_imm_addr     = r_if_op_data[55:45];
        id_rs_a_addr[0] = r_if_op_data[50:45];
        id_rs_a_addr[1] = r_if_op_data[44:39];
        id_rs_d_addr[0] = id_use_rd0 ? r_if_op_data[37:31] : 0;
        id_rs_d_addr[1] = id_use_rd1 ? r_if_op_data[29:23] : 0;
        id_rd_addr      = r_if_op_data[6:0];
    end

    CTRL_REG    id_reg, rd_reg, x1_reg, x2_reg, wr_reg;
    CTRL_FLOW   id_ctrl, rd_ctrl, x1_ctrl, x2_ctrl;

    assign id_reg.we        = id_dreg_we;
    assign id_reg.r_wave_we = id_r_wave_we;
    assign id_reg.addr      = id_rd_addr;
    assign id_reg.src       = id_cfg_reg_src;
    assign id_reg.port_re   = id_dport_re;

    assign id_ctrl.cfg_addr_imm  = id_ai;
    assign id_ctrl.cfg_dt_imm    = id_cfg_dt_imm;
    assign id_ctrl.cfg_port_src  = id_cfg_port_src;
    assign id_ctrl.cfg_port_type = id_type_wpd;
    assign id_ctrl.cfg_port_time = id_type_wp & id_to;
    assign id_ctrl.cfg_cond      = id_cond;
    assign id_ctrl.cfg_alu_src   = id_cfg_alu_src;
    assign id_ctrl.cfg_alu_op    = id_cfg_alu_op;
    assign id_ctrl.usr_ctrl      = id_usr_ctrl;
    assign id_ctrl.flag_we       = id_flag_we;
    assign id_ctrl.dmem_we       = id_dmem_we;
    assign id_ctrl.wmem_we       = id_wmem_we;
    assign id_ctrl.port_we       = id_wport_we | id_dport_we;


    // CONDITION
    /////////////////////////////////////////////////

    logic id_cond_used, id_flag_used;
    always_comb begin
        unique case (id_cond)
            3'b000:  id_cond_ok = 1;        // ALWAYS
            3'b001:  id_cond_ok = alu_fz_r;  // EQ  - Z
            3'b010:  id_cond_ok = alu_fs_r;  // LT  - S
            3'b011:  id_cond_ok = ~alu_fz_r; // NZ  - not(Z)
            3'b100:  id_cond_ok = ~alu_fs_r; // NS  - not(S)
            3'b101:  id_cond_ok = flag_i;    // External flag
            3'b110:  id_cond_ok = ~flag_i;   // NOT external flag
            3'b111:  id_cond_ok = 0;         // RFU
        endcase
        id_cond_used = id_type_cfg | id_type_wra | id_type_wrd | id_type_wmd
                     | id_type_br | id_type_int_ctrl | id_type_ext_ctrl; // Conditional instruction
        id_flag_used      = id_cond_used & |id_cond;    // Condition should be checked
        id_exec_ok        = id_cond_ok | ~id_cond_used; // Execute instruction
        id_branch_cond_ok = id_type_br & id_exec_ok;    // Execute BRANCH
    end


    // PC_ADDR CALCULATION
    /////////////////////////////////////////////////
    always_comb begin
        cfg_pc_nxt = 2'b00; // Move to next address
        if (id_ret) cfg_pc_nxt = 2'b11; // Return from CALL, RET is not conditional
        else if (id_branch_cond_ok)
            if (id_ai) cfg_pc_nxt = 2'b01; // Jump to immediate address
            else       cfg_pc_nxt = 2'b10; // Jump to register address
    end

    logic id_jmp_reg_used;
    assign id_jmp_reg_used = (cfg_pc_nxt == 2'b10);

    assign id_pc_change = |cfg_pc_nxt;

    always_comb begin
        pc_next = pc_curr + 1;
        unique case (cfg_pc_nxt)
            2'b00:   pc_next = pc_curr + 1;
            2'b01:   pc_next = id_imm_addr;
            2'b10:   pc_next = reg_addr;
            2'b11:   pc_next = pc_stack;
            default: ;
        endcase
    end

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            pc_curr <= 0;
            pc_prev <= 0;
        end else begin
            if (restart_i) begin
                pc_curr <= 0;
                pc_prev <= 0;
            end else if (fetch_en) begin
                pc_curr <= pc_next;
                pc_prev <= pc_curr;
            end
        end
    end



    // X1 - 4 Fourth stage - address calculation - execute_1
    ///////////////////////////////////////////////////////////////////////////////////////////////////

    logic [31:0] x1_rs_d0_dt, x1_rs_d1_dt;
    logic [31:0] x1_rs_a1_dt, x1_rs_a0_dt;
    logic [31:0] rs_a_dt [2];
    logic [31:0] rs_d_dt [2];


    assign x1_rs_a0_dt = x1_ctrl.cfg_addr_imm ? r_rd_imm_addr : reg_a_fwd_dt[0];
    assign x1_rs_a1_dt = reg_a_fwd_dt[1];
    assign x1_rs_d0_dt = reg_d_fwd_dt[0];
    assign x1_rs_d1_dt = reg_d_fwd_dt[1];

    // Arithmetic unit
    /////////////////////////////////////////////////
    logic [31:0] x1_alu_in_a, x1_alu_in_b;
    assign x1_alu_in_a = x1_rs_d0_dt;
    assign x1_alu_in_b = x1_ctrl.cfg_alu_src ? r_rd_imm_dt : x1_rs_d1_dt;

    // Data memory
    /////////////////////////////////////////////////
    logic [DMEM_AW-1:0] x1_mem_addr;
    logic [31:0]         x1_mem_w_dt;
    assign x1_mem_addr = x1_rs_a0_dt + x1_rs_a1_dt;
    assign x1_mem_w_dt = x1_ctrl.cfg_dt_imm ? r_rd_imm_dt : x1_alu_dt;

    // Wave memory
    ///////////////////////////////////////////////////////////////////////////
    assign x1_wave_addr = x1_rs_a0_dt[WMEM_AW-1:0];

    // Port
    ///////////////////////////////////////////////////////////////////////////
    logic [5:0] x1_port_w_addr;
    assign x1_port_w_addr = r_rd_rs_a1_addr[5:0];


    ///////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // X2 - 5 Fifth stage X2_ - execute_2
    ///////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////

    logic [167:0] reg_wave_dt;

    // Input to register bank
    logic [31:0] x2_reg_w_dt;

    always_comb begin
        unique case (x2_reg.src)
            2'b00:   x2_reg_w_dt = r_x1_alu_dt;
            2'b01:   x2_reg_w_dt = dmem_r_dt_i;
            2'b10:   x2_reg_w_dt = r_x1_alu_dt;
            2'b11:   x2_reg_w_dt = r_x1_imm_dt;
        endcase
    end


    // Wave
    /////////////////////////////////////////////////
    // The wave memory is read synchronously with the address of the instruction in
    // X1. While the core is halted (dispatcher FIFO full, qproc_ctrl drops en_i) the
    // X2 instruction waits, but the memory output moves on to the address of the
    // instruction in X1. The word of a WPORT_WR / REG_WR r_wave wmem in X2 is
    // therefore held across the pause. This replaces the
    // stall_id_wp hazard, which kept two port writes 3 cycles apart.
    logic         halt_r;
    logic [167:0] wmem_r_dt_hold;
    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) halt_r <= 1'b0;
        else         halt_r <= halt;
    end
    always_ff @(posedge clk_i) begin
        if (!halt_r) wmem_r_dt_hold <= wmem_r_dt_i;
    end
    logic [167:0] wmem_r_dt_x2;
    assign wmem_r_dt_x2 = halt_r ? wmem_r_dt_hold : wmem_r_dt_i;

    logic [167:0] x2_wave_w_dt;
    assign x2_wave_w_dt = x2_ctrl.cfg_port_src ? reg_wave_dt : wmem_r_dt_x2;

    // Port
    /////////////////////////////////////////////////
    logic [167:0] x2_port_w_dt;
    logic [5:0]   r_x1_port_w_addr;


    logic [31:0] r_x1_port_dt;

    assign x2_port_w_dt = x2_ctrl.cfg_port_type ? r_x1_port_dt : x2_wave_w_dt;


    ///////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////
    // Instances
    ///////////////////////////////////////////////////////////////////////////////

    qcore_ctrl_hazard ctrl_hzrd_i (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .halt_i      (halt),
        .rs_a_addr_i (r_id_rs_a_addr),
        .rs_a_dt_i   (rs_a_dt),
        .rs_d_addr_i (r_id_rs_d_addr),
        .rs_d_dt_i   (rs_d_dt),
        // Register write enable
        .id_reg_i (id_reg),
        .rd_reg_i (rd_reg),
        .x1_reg_i (x1_reg),
        .x2_reg_i (x2_reg),
        .wr_reg_i (wr_reg),
        // Peripheral
        .rd_periph_use (rd_ctrl.usr_ctrl[8]),
        .x1_periph_use (x1_ctrl.usr_ctrl[8]),
        .x2_periph_use (x2_ctrl.usr_ctrl[8]),
        // Wave register
        .id_wmem_we (id_wmem_we), // r_wave will be read
        // Flag
        .id_flag_used (id_flag_used),
        .flag_we      (rd_ctrl.flag_we | x1_ctrl.flag_we),
        // PC jump
        .id_jmp_i (id_jmp_reg_used),
        // ALU (00) data in each pipeline stage
        .x1_alu_dt_i (x1_alu_dt),
        .x2_alu_dt_i (r_x1_alu_dt),
        // DMEM (01) in each pipeline stage
        .x2_dmem_dt_i (dmem_r_dt_i),
        // Immediate data in each pipeline stage
        .rd_imm_dt_i (r_id_imm_dt),
        .x1_imm_dt_i (r_rd_imm_dt),
        .x2_imm_dt_i (r_x1_imm_dt),
        // Forwarded data
        .reg_a_dt_o (reg_a_fwd_dt),
        .reg_d_dt_o (reg_d_fwd_dt),
        .bubble_id_o (bubble_id),
        .bubble_rd_o (bubble_rd)
    );

    // Reg bank
    /////////////////////////////////////////////////
    qcore_reg_bank #(
        .LFSR    (LFSR),
        .PMEM_AW (PMEM_AW),
        .REG_AW  (REG_AW)
    ) reg_bank_i (
        .clk_i       (clk_i),
        .halt_i      (halt),
        .rst_ni      (rst_ni),
        .clear_i     (restart_i),
        .lfsr_cfg_i  (lfsr_cfg_i),
        .reg_arith_i (sreg_arith_i),
        .reg_div_i   (sreg_div_i),
        .reg_port_i  (sreg_port_dt_i),
        .tproc_ext_i (sreg_core_r_dt_i),
        .status_i    (sreg_status_i),
        .reg_cfg_o   (sreg_cfg_o),
        .reg_ctrl_o  (sreg_ctrl_o),
        .time_dt_i   (sreg_time_dt_i),
        .wave_we_i   (x2_reg.r_wave_we),
        .we_i        (x2_reg.we),
        .w_addr_i    (x2_reg.addr),
        .w_dt_i      (x2_reg_w_dt),
        .wave_dt_i   (x2_wave_w_dt),
        .rs_a_addr_i (r_id_rs_a_addr),
        .rs_d_addr_i (r_id_rs_d_addr),
        .rs_a_dt_o   (rs_a_dt),
        .rs_d_dt_o   (rs_d_dt),
        .sreg_dt_o   (sreg_core_w_dt_o),
        .out_addr_o  (reg_addr),
        .out_time_o  (reg_time),
        .out_wreg_o  (reg_wave_dt),
        .lfsr_o      (lfsr_o)
    );

    // ALU - 2 inputs
    /////////////////////////////////////////////////
    tpv2_alu alu_i (
        .a_i          (x1_alu_in_a),
        .b_i          (x1_alu_in_b),
        .alu_op_i     (x1_ctrl.cfg_alu_op),
        .z_o          (x1_alu_fz),
        .c_o          (x1_alu_fc),
        .s_o          (x1_alu_fs),
        .alu_result_o (x1_alu_dt)
    );


    logic pc_stack_full;
    // PC stack
    /////////////////////////////////////////////////
    tpv2_stack #(
        .WIDTH (PMEM_AW),
        .DEPTH (8)
    ) pc_stack_i (
        .clk_i  (clk_i),
        .rst_ni (rst_ni),
        .data_i (pc_prev),
        .push   (id_call & fetch_en),
        .pop    (id_ret & fetch_en),
        .data_o (pc_stack),
        .full_o (pc_stack_full)
    );



    ///////////////////////////////////////////////////////////////////////////////
    // Pipeline
    ///////////////////////////////////////////////////////////////////////////////

    logic id_stage_keep, rd_stage_keep, rd_stage_zero, x1_stage_zero;
    assign id_stage_keep = !fetch_en;
    assign rd_stage_keep = bubble_rd;
    assign rd_stage_zero = bubble_id & !bubble_rd;
    assign x1_stage_zero = bubble_rd;


    // Data & address pipeline
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            // Control signals
            r_id_pc_change <= 0;
            rd_ctrl <= '{default: '0};
            x1_ctrl <= '{default: '0};
            x2_ctrl <= '{default: '0};
            rd_reg  <= '{default: '0};
            x1_reg  <= '{default: '0};
            x2_reg  <= '{default: '0};
            wr_reg  <= '{default: '0};
            // Address signals
            r_id_imm_addr   <= 0;
            r_rd_imm_addr   <= 0;
            r_rd_rs_a1_addr <= 0;
            r_id_rs_a_addr  <= '{default: '0};
            r_id_rs_d_addr  <= '{default: '0};
            // Data signals
            r_id_imm_dt <= 0;
            r_rd_imm_dt <= 0;
            r_x1_imm_dt <= 0;
            r_x1_alu_dt <= 0;
            r_x1_port_dt <= 0;
            alu_fz_r <= 0;
            alu_fs_r <= 0;
        end else if (restart_i) begin
            r_id_pc_change <= 0;
            rd_ctrl <= '{default: '0};
            x1_ctrl <= '{default: '0};
            x2_ctrl <= '{default: '0};
            rd_reg  <= '{default: '0};
            x1_reg  <= '{default: '0};
            x2_reg  <= '{default: '0};
            wr_reg  <= '{default: '0};
            r_id_imm_addr   <= 0;
            r_rd_imm_addr   <= 0;
            r_rd_rs_a1_addr <= 0;
            r_id_rs_a_addr  <= '{default: '0};
            r_id_rs_d_addr  <= '{default: '0};
            r_id_imm_dt <= 0;
            r_rd_imm_dt <= 0;
            r_x1_imm_dt <= 0;
            r_x1_alu_dt <= 0;
            r_x1_port_dt <= 0;
            alu_fz_r <= 0;
            alu_fs_r <= 0;
            r_x1_port_w_addr <= 0;
        end else begin
            if (~halt) begin

                /////////////////////////////////////////////////////////
                // STAGE > READ
                if (rd_stage_zero) begin
                    rd_ctrl        <= '{default: '0};
                    rd_reg         <= '{default: '0};
                    r_id_pc_change <= 1'b0;
                    r_id_imm_dt    <= '{default: '0};
                    r_id_imm_addr  <= '{default: '0};
                    r_id_rs_d_addr <= '{default: '0};
                    r_id_rs_a_addr <= '{default: '0};
                end else if (rd_stage_keep) begin
                    rd_ctrl        <= rd_ctrl;
                    rd_reg         <= rd_reg;
                    r_id_pc_change <= r_id_pc_change;
                    r_id_imm_dt    <= r_id_imm_dt;
                    r_id_imm_addr  <= r_id_imm_addr;
                    r_id_rs_d_addr <= r_id_rs_d_addr;
                    r_id_rs_a_addr <= r_id_rs_a_addr;
                end else begin
                    // Control signals
                    rd_ctrl        <= id_ctrl;
                    rd_reg         <= id_reg;
                    r_id_pc_change <= id_pc_change;
                    // Data signals
                    r_id_imm_dt    <= id_imm_dt;
                    r_id_imm_addr  <= id_imm_addr;
                    r_id_rs_d_addr <= id_rs_d_addr;
                    r_id_rs_a_addr <= id_rs_a_addr;
                end

                /////////////////////////////////////////////////////////
                // STAGE > EXECUTE 1
                if (x1_stage_zero) begin
                    x1_ctrl          <= '{default: '0};
                    x1_reg           <= '{default: '0};
                    r_rd_imm_dt      <= '{default: '0};
                    r_rd_imm_addr    <= '{default: '0};
                    r_rd_rs_a1_addr  <= '{default: '0};
                end else begin
                    x1_ctrl         <= rd_ctrl;
                    x1_reg          <= rd_reg;
                    r_rd_imm_dt     <= r_id_imm_dt;
                    r_rd_imm_addr   <= r_id_imm_addr;
                    r_rd_rs_a1_addr <= r_id_rs_a_addr[1];
                end

                /////////////////////////////////////////////////////////
                // STAGE > EXECUTE 2
                // Control signals
                x2_ctrl <= x1_ctrl;
                x2_reg  <= x1_reg;
                // Data signals
                r_x1_imm_dt      <= r_rd_imm_dt;
                r_x1_alu_dt      <= x1_alu_dt;
                r_x1_port_dt     <= x1_rs_a0_dt;
                r_x1_port_w_addr <= x1_port_w_addr;
                if (x1_ctrl.flag_we) begin
                    alu_fz_r <= x1_alu_fz;
                    alu_fs_r <= x1_alu_fs;
                end

                /////////////////////////////////////////////////////////
                // STAGE > WRITE
                // Control signals
                wr_reg <= x2_reg;

            end // ~halt
        end // !rst
    end // always


    /////////////////////////////////////////////////////////////////////////////////////////
    // Outputs
    /////////////////////////////////////////////////////////////////////////////////////////

    // Program memory
    assign pmem_en_o   = fetch_en | r_mem_rst;
    assign pmem_addr_o = pc_curr; // Disabled next instruction with pc_jump

    // Data memory
    assign dmem_we_o   = halt ? 0 : x1_ctrl.dmem_we;
    assign dmem_addr_o = x1_mem_addr;
    assign dmem_w_dt_o = x1_mem_w_dt;

    // Wave memory
    assign wmem_we_o   = halt ? 0 : x1_ctrl.wmem_we;
    assign wmem_addr_o = x1_wave_addr;
    assign wmem_w_dt_o = reg_wave_dt;

    // Peripheral out
    assign usr_en_o   = halt ? 0 : x1_ctrl.usr_ctrl[8];
    assign usr_ctrl_o = halt ? 0 : x1_ctrl.usr_ctrl[7:0];
    assign usr_dt_a_o = x1_rs_d0_dt;
    assign usr_dt_b_o = x1_ctrl.cfg_dt_imm ? r_rd_imm_dt : x1_rs_d1_dt;
    assign usr_dt_c_o = x1_rs_a0_dt;
    assign usr_dt_d_o = x1_rs_a1_dt;

    // Port output
    assign port_we_o = halt ? 0 : x2_ctrl.port_we;
    assign port_re_o = halt ? 0 : x2_reg.port_re;

    assign port_o.p_time = x2_ctrl.cfg_port_time ? r_x1_imm_dt : reg_time;
    assign port_o.p_type = x2_ctrl.cfg_port_type;
    assign port_o.p_addr = r_x1_port_w_addr;
    assign port_o.p_data = x2_port_w_dt;

    // Debug
    assign core_do[31:24] = {restart_i, stall, flush, id_flag_we, alu_fz_r, alu_fs_r, x2_ctrl.port_we, x2_reg.port_re};
    assign core_do[23:16] = {id_type_ext_ctrl, id_type_int_ctrl, id_type_cfg, id_type_br, id_type_wr, id_type_wm,
                              id_type_wp, pc_stack_full};
    assign core_do[15:8]  = r_x1_alu_dt[7:0];
    assign core_do[7:0]   = port_o.p_time[7:0];

endmodule
