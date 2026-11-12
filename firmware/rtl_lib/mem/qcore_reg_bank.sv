///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : qcore_reg_bank
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    qcore_reg_bank.sv
//!
//! @brief   Register bank for the QICK tProcessor v2 core.
//!
//! @details
//!
//!
//! Holds the three register pages addressed by `w_addr_i`/`rs_a_addr_i`/
//! `rs_d_addr_i` ([6:5] selects the page):
//! * 2'b00 : special-function registers (16 entries, `sreg_32_dt`) -- a mix
//!           of read-only status wires (arith/div/status/time/ext ports),
//!           the CFG/CTRL byte pair (address 2), and four general-purpose
//!           CORE_W/S_ADDR registers (addresses 12-15, `sreg_dt`).
//! * 2'b01 : general-purpose data registers (`dreg_32_dt`, `2**REG_AW`
//!           entries, address = `w_addr_i[REG_AW-1:0]`).
//! * 2'b10 : wave-parameter registers (`wreg_32_dt`, 6 entries, address =
//!           `w_addr_i[2:0]`); loaded either individually (`we_i`) or in a
//!           single burst from `wave_dt_i` (`wave_we_i`, one 168-bit wave
//!           word split across all 6 32-bit slots).
//!
//! Address 0/1 in the SFR page double as the LFSR control bits (`lfsr_step`/
//! `lfsr_we`); the CFG register (address 2) also carries a one-shot CTRL
//! byte that self-clears the cycle after it is written.
//!
//! Ported from firmware/ip/qick_processor/src/qcore_reg_bank.sv (behavior
//! unchanged; the stale `_qproc_defines.svh` include was dropped since this
//! module does not use any of its types/macros, and the private `LFSR`
//! primitive was replaced by the generic qick:utils:lfsr core).
//!
//! @author  QICK Development Team
//!
//! @version 1.0

module qcore_reg_bank #(
    parameter int LFSR    = 1,
    parameter int PMEM_AW = 8,
    parameter int REG_AW  = 4
) (
    input  logic          clk_i,
    input  logic          halt_i,
    input  logic          rst_ni,
    input  logic          clear_i,
    input  logic  [1:0]   lfsr_cfg_i,
    input  logic  [31:0]  reg_arith_i,
    input  logic  [31:0]  reg_div_i   [2],
    input  logic  [31:0]  reg_port_i  [2],
    input  logic  [31:0]  tproc_ext_i [2],
    input  logic  [31:0]  time_dt_i,
    input  logic  [167:0] wave_dt_i,
    input  logic  [31:0]  status_i,
    output logic  [7:0]   reg_cfg_o,
    output logic  [7:0]   reg_ctrl_o,
    input  logic          wave_we_i,
    input  logic          we_i,
    input  logic  [6:0]   w_addr_i,
    input  logic  [31:0]  w_dt_i,
    input  logic  [5:0]   rs_a_addr_i [2],
    input  logic  [6:0]   rs_d_addr_i [2],
    output logic  [31:0]  rs_d_dt_o   [2],
    output logic  [31:0]  rs_a_dt_o   [2],
    output logic  [31:0]  sreg_dt_o   [2],
    output logic  [PMEM_AW-1:0] out_addr_o,
    output logic  [31:0]  out_time_o,
    output logic  [167:0] out_wreg_o,
    output logic  [31:0]  lfsr_o
);

    ///////////////////////////////////////////////////////////////////////////
    // PARAMETERS
    localparam int REG_QTY = (2 ** REG_AW);

    ///////////////////////////////////////////////////////////////////////////
    // LFSR
    logic [31:0] lfsr_reg;
    logic        lfsr_en;
    logic        lfsr_sel, lfsr_we, lfsr_step;

    ///////////////////////////////////////////////////////////////////////////
    // SPECIAL REGISTER BANK: addresses 00_00000 to 00_11111
    logic [31:0] sreg_dt [4]; // Four SFR (addresses 12-15)
    logic        sreg_en, sreg_we;

    logic [7:0]  sreg_cfg_dt;  // Configuration byte (lower 16 bits of address 2)
    logic [7:0]  sreg_ctrl_dt; // One-shot control byte (upper 16 bits of address 2)
    logic        sreg_cfg_en, sreg_cfg_we;

    assign sreg_en      = w_addr_i[6:2] == 5'b00_011; // Registers 12 to 15 selected
    assign sreg_we      = we_i & sreg_en;
    assign sreg_cfg_en  = w_addr_i == 7'b00_00010;    // Register 2 selected
    assign sreg_cfg_we  = we_i & sreg_cfg_en;

    ///////////////////////////////////////////////////////////////////////////
    // General data registers: addresses 01_00000 to 01_11111
    logic [31:0]       dreg_32_dt [REG_QTY];
    logic [REG_AW-1:0] dreg_32_addr;
    logic              dreg_32_en, dreg_32_we;

    assign dreg_32_addr = w_addr_i[REG_AW-1:0];
    assign dreg_32_en   = w_addr_i[6:5] == 2'b01;
    assign dreg_32_we   = we_i & dreg_32_en;

    ///////////////////////////////////////////////////////////////////////////
    // Wave-parameter registers: addresses 10_00000 to 10_00110
    logic [31:0] wreg_32_dt [6];
    logic [2:0]  wreg_32_addr;
    logic        wreg_32_en, wreg_32_we;

    assign wreg_32_addr = w_addr_i[2:0];
    assign wreg_32_en   = w_addr_i[6:5] == 2'b10;
    assign wreg_32_we   = we_i & wreg_32_en;

    ///////////////////////////////////////////////////////////////////////////
    // DATA, WAVE and SFR REGISTER BANK
    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            dreg_32_dt   <= '{default: '0};
            wreg_32_dt   <= '{default: '0};
            sreg_dt      <= '{default: '0};
            sreg_cfg_dt  <= '0;
            sreg_ctrl_dt <= '0;
        end else if (clear_i) begin
            dreg_32_dt   <= '{default: '0};
            wreg_32_dt   <= '{default: '0};
            sreg_dt      <= '{default: '0};
            sreg_cfg_dt  <= '0;
            sreg_ctrl_dt <= '0;
        end else if (~halt_i) begin
            if (dreg_32_we)
                dreg_32_dt[dreg_32_addr] <= w_dt_i;
            if (wreg_32_we)
                wreg_32_dt[wreg_32_addr] <= w_dt_i;
            else if (wave_we_i) begin
                wreg_32_dt[5] <= wave_dt_i[167:152];
                wreg_32_dt[4] <= wave_dt_i[151:120];
                wreg_32_dt[3] <= wave_dt_i[119:88];
                wreg_32_dt[2] <= wave_dt_i[87:64];
                wreg_32_dt[1] <= wave_dt_i[63:32];
                wreg_32_dt[0] <= wave_dt_i[31:0];
            end
            if (sreg_we)
                sreg_dt[w_addr_i[1:0]] <= w_dt_i;
            if (sreg_cfg_we) begin
                sreg_cfg_dt  <= w_dt_i[7:0];
                sreg_ctrl_dt <= w_dt_i[23:16];
            end else if (|sreg_ctrl_dt)
                sreg_ctrl_dt <= 8'd0;

            // Unused upper half of the S_ADDR register tied to GND.
            sreg_dt[3][31:16] <= '{default: '0};
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // LFSR
    // lfsr_cfg_i: 00-free running, 01-always enabled, 10-step on read,
    //             11-step on write-to-zero.
    generate
        if (LFSR == 1) begin : gen_lfsr
            (* ASYNC_REG = "TRUE" *) logic [1:0] lfsr_cfg_cdc, lfsr_cfg_sync;
            always_ff @(posedge clk_i) begin
                lfsr_cfg_cdc  <= lfsr_cfg_i;
                lfsr_cfg_sync <= lfsr_cfg_cdc;
            end
            always_comb
                unique case (lfsr_cfg_sync)
                    2'b00:   lfsr_en = 1'b0;
                    2'b01:   lfsr_en = 1'b1;
                    2'b10:   lfsr_en = lfsr_sel;
                    2'b11:   lfsr_en = lfsr_step;
                endcase
            assign lfsr_sel  = (rs_d_addr_i[0] == 7'b0000001);
            assign lfsr_we   = we_i & (w_addr_i == 7'b0000001);
            assign lfsr_step = we_i & (w_addr_i == 7'b0000000);
            lfsr lfsr_i (
                .clk_i     (clk_i),
                .rst_ni    (rst_ni),
                .en_i      (lfsr_en),
                .load_we_i (lfsr_we),
                .load_dt_i (w_dt_i),
                .lfsr_dt_o (lfsr_reg)
            );
        end else begin : gen_no_lfsr
            assign lfsr_sel  = 1'b0;
            assign lfsr_we   = 1'b0;
            assign lfsr_step = 1'b0;
            assign lfsr_reg  = '0;
        end
    endgenerate

    ///////////////////////////////////////////////////////////////////////////
    // SFR ASSEMBLY
    logic [31:0] sreg_32_dt [16];

    assign sreg_32_dt[0]  = '0;
    assign sreg_32_dt[1]  = lfsr_reg;
    assign sreg_32_dt[2]  = sreg_cfg_dt;
    assign sreg_32_dt[3]  = reg_arith_i;
    assign sreg_32_dt[4]  = reg_div_i[0];
    assign sreg_32_dt[5]  = reg_div_i[1];
    assign sreg_32_dt[6]  = tproc_ext_i[0];
    assign sreg_32_dt[7]  = tproc_ext_i[1];
    assign sreg_32_dt[8]  = reg_port_i[0];
    assign sreg_32_dt[9]  = reg_port_i[1];
    assign sreg_32_dt[10] = status_i;
    assign sreg_32_dt[11] = time_dt_i;
    assign sreg_32_dt[12] = sreg_dt[0]; // CORE_W_DT1
    assign sreg_32_dt[13] = sreg_dt[1]; // CORE_W_DT2
    assign sreg_32_dt[14] = sreg_dt[2]; // OUT_TIME
    assign sreg_32_dt[15] = sreg_dt[3]; // PC_NXT_ADDR

    ///////////////////////////////////////////////////////////////////////////
    // Output MUX for rsA[0] and rsA[1] (bit 5 selects dreg vs sreg page)
    logic [31:0] data_a [2];

    for (genvar ind_a = 0; ind_a < 2; ind_a++) begin : gen_data_a
        assign data_a[ind_a] = rs_a_addr_i[ind_a][5]
            ? dreg_32_dt[rs_a_addr_i[ind_a][REG_AW-1:0]]
            : sreg_32_dt[rs_a_addr_i[ind_a][3:0]];
    end

    logic [31:0] data_d [2];

    ///////////////////////////////////////////////////////////////////////////
    // Output MUX for rsD[0] and rsD[1] (bits [6:5] select the page)
    for (genvar ind_d = 0; ind_d < 2; ind_d++) begin : gen_data_d
        always_comb begin
            unique case (rs_d_addr_i[ind_d][6:5])
                2'b00:   data_d[ind_d] = sreg_32_dt[rs_d_addr_i[ind_d][3:0]];
                2'b01:   data_d[ind_d] = dreg_32_dt[rs_d_addr_i[ind_d][REG_AW-1:0]];
                2'b10:   data_d[ind_d] = wreg_32_dt[rs_d_addr_i[ind_d][2:0]];
                2'b11:   data_d[ind_d] = '0;
            endcase
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // OUTPUT ASSIGNMENT
    assign rs_a_dt_o = data_a;
    assign rs_d_dt_o = data_d;

    assign lfsr_o     = lfsr_reg;
    assign reg_cfg_o  = sreg_cfg_dt;
    assign reg_ctrl_o = sreg_ctrl_dt;
    assign sreg_dt_o[0] = sreg_32_dt[12];
    assign sreg_dt_o[1] = sreg_32_dt[13];
    assign out_time_o   = sreg_32_dt[14];
    assign out_addr_o   = sreg_32_dt[15][PMEM_AW-1:0];

    assign out_wreg_o[167:152] = wreg_32_dt[5][15:0];
    assign out_wreg_o[151:120] = wreg_32_dt[4];
    assign out_wreg_o[119:88]  = wreg_32_dt[3];
    assign out_wreg_o[87:64]   = wreg_32_dt[2][23:0];
    assign out_wreg_o[63:32]   = wreg_32_dt[1];
    assign out_wreg_o[31:0]    = wreg_32_dt[0];

endmodule
