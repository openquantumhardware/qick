///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : bram_tdp_banked
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    bram_tdp_banked.sv
//!
//! @brief   Dual-clock dual-port block RAM wrapper used by the tProcessor v2
//!          memory subsystem. Maps legacy `bram_dual_port_dc` interface to
//!          one or more `bram_tdp` primitives.
//!
//! @details
//!
//! - For `MEM_DW <= 72` a single `bram_tdp` is instantiated.
//! - For `MEM_DW > 72` multiple `bram_tdp` instances are instantiated
//!   (72-bit banks) to cover the requested width.
//! - `RAM_OUT` is mapped to `OUT_REG_A` / `OUT_REG_B` of `bram_tdp`.
//!
//! @generic
//! MEM_AW  : unsigned int – address width (default 16 -> 65536 words).
//! MEM_DW  : unsigned int – data width (default 32).
//! RAM_OUT : string – "NO_REGISTERED" (default) or "REGISTERED".
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////

module bram_tdp_banked #(
    parameter int unsigned MEM_AW  = 16,
    parameter int unsigned MEM_DW  = 32,
    parameter string       RAM_OUT = "NO_REGISTERED"
)(
    // Port A
    input  wire                 clk_a_i,
    input  wire                 en_a_i,
    input  wire                 we_a_i,
    input  wire [MEM_AW-1:0]    addr_a_i,
    input  wire [MEM_DW-1:0]    dt_a_i,
    output wire [MEM_DW-1:0]    dt_a_o,

    // Port B
    input  wire                 clk_b_i,
    input  wire                 en_b_i,
    input  wire                 we_b_i,
    input  wire [MEM_AW-1:0]    addr_b_i,
    input  wire [MEM_DW-1:0]    dt_b_i,
    output wire [MEM_DW-1:0]    dt_b_o
);

    localparam int MAX_BW   = 72;
    localparam int BANKS    = (MEM_DW + MAX_BW - 1) / MAX_BW;
    localparam int LAST_BW  = MEM_DW - (BANKS - 1) * MAX_BW;

    wire [MEM_DW-1:0] dt_a_o_int;
    wire [MEM_DW-1:0] dt_b_o_int;

    generate
        for (genvar i = 0; i < BANKS; i++) begin : gen_bank
            localparam int BW = (i == BANKS-1) ? LAST_BW : MAX_BW;

            wire [BW-1:0] bank_dt_a_i;
            wire [BW-1:0] bank_dt_a_o;
            wire [BW-1:0] bank_dt_b_i;
            wire [BW-1:0] bank_dt_b_o;

            assign bank_dt_a_i = dt_a_i[i*MAX_BW +: BW];
            assign bank_dt_b_i = dt_b_i[i*MAX_BW +: BW];
            assign dt_a_o_int[i*MAX_BW +: BW] = bank_dt_a_o;
            assign dt_b_o_int[i*MAX_BW +: BW] = bank_dt_b_o;

            bram_tdp #(
                .NB_DATA      (BW),
                .NB_ADDR      (MEM_AW),
                .MEM_BIN_FILE (""),
                .OUT_REG_A    (RAM_OUT == "REGISTERED" ? 1 : 0),
                .OUT_REG_B    (RAM_OUT == "REGISTERED" ? 1 : 0)
            ) u_bram (
                .clka   (clk_a_i),
                .rsta   (1'b0),
                .ena    (en_a_i),
                .wea    (we_a_i),
                .addra  (addr_a_i),
                .dia    (bank_dt_a_i),
                .doa    (bank_dt_a_o),

                .clkb   (clk_b_i),
                .rstb   (1'b0),
                .enb    (en_b_i),
                .web    (we_b_i),
                .addrb  (addr_b_i),
                .dib    (bank_dt_b_i),
                .dob    (bank_dt_b_o)
            );
        end
    endgenerate

    assign dt_a_o = dt_a_o_int;
    assign dt_b_o = dt_b_o_int;

endmodule
