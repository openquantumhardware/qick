///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : bram_simple_sp
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    bram_simple_sp.sv
//!
//! @brief   Single-port block RAM, one clock, write-first, optional file image.
//!
//! @details
//!
//! 2**NB_ADDR words of NB_DATA bits behind one address port. On a clock edge
//! with i_ena high the word at i_addra is read into o_doa, or, with i_wea also
//! high, i_dia is written there and appears on o_doa at the same edge
//! (write-first). With i_ena low nothing changes and o_doa holds.
//!
//! When MEM_BIN_FILE is not empty the memory starts with that $readmemb image
//! (one binary word per line, address 0 first); otherwise it starts unknown.
//!
//! @author  QICK Development Team
//!
//! @version 1.1
module bram_simple_sp #(
    parameter int unsigned NB_DATA      = 32, //! word width
    parameter int unsigned NB_ADDR      = 4,  //! address width (2**NB_ADDR words)
    parameter string       MEM_BIN_FILE = ""  //! $readmemb image loaded at t=0, "" for none
)(
    input  logic               i_clk,
    input  logic               i_ena,   //! port enable
    input  logic               i_wea,   //! write (with i_ena)
    input  logic [NB_ADDR-1:0] i_addra,
    input  logic [NB_DATA-1:0] i_dia,
    output logic [NB_DATA-1:0] o_doa
);

    (* ram_style = "block" *) logic [NB_DATA-1:0] mem [2**NB_ADDR];

    initial if (MEM_BIN_FILE != "") $readmemb(MEM_BIN_FILE, mem);

    always_ff @(posedge i_clk) begin
        if (i_ena) begin
            if (i_wea) begin
                mem[i_addra] <= i_dia;
                o_doa        <= i_dia;
            end else begin
                o_doa        <= mem[i_addra];
            end
        end
    end

endmodule
