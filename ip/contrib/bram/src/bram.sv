/***********************************************
 *
 *  Copyright (C) 2022 - Stratum Labs
 *
 *  Project:    Common
 *  Author:     Ramiro Moral <ramiro.moral@stratum-labs.com>
 *
 *  File: bram.sv
 *  Description: Simple dual-port, one clock, read-first block RAM
 *
 * ********************************************/
 module bram
#(
    parameter int unsigned              NB_DATA         = 32,
    parameter int unsigned              NB_ADDR         = 4,
    parameter string                    MEM_BIN_FILE    = ""
)
(
    input   logic                       i_clk,
    input   logic                       i_wr_enb,
    input   logic                       i_rd_enb,
    input   logic   [NB_ADDR-1 : 0]     i_wr_addr,
    input   logic   [NB_ADDR-1 : 0]     i_rd_addr,
    input   logic   [NB_DATA-1 : 0]     i_data,
    output  logic   [NB_DATA-1 : 0]     o_data
);

    localparam int unsigned DEPTH = 2**NB_ADDR;

    (* ram_style = "block" *) logic [NB_DATA-1:0] bram_data [DEPTH];

    logic [NB_DATA-1:0] data_out;

    initial begin
        if(MEM_BIN_FILE != "") begin
            $display({"Reading ", MEM_BIN_FILE});
            $readmemb(MEM_BIN_FILE, bram_data);
        end
    end

    always_ff @ (posedge i_clk) begin
        if(i_wr_enb) begin
            bram_data[i_wr_addr] <= i_data;
        end
    end

    always_ff @(posedge i_clk) begin
        if (i_rd_enb) begin
            data_out <= bram_data[i_rd_addr];
        end
    end

    assign o_data = data_out;

endmodule
