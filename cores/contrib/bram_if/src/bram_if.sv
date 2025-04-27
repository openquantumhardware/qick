/***********************************************
 *
 *  Copyright (C) 2023 - Stratum Labs
 *
 *  Project: Stratum Labs - Common Library
 *  Author: Horacio Arnaldi <horacio.arnaldi@stratum-labs.com>
 *
 *  File: bram_if.sv
 *  Description: BRAM block memory interface
 *
 *
 * ********************************************/

interface bram_if
#(
  parameter integer unsigned NB_DATA  = 32,
  parameter integer unsigned NB_ADDR  = 10
)
(
  input  logic                        i_clk,
  input  logic                        i_rst
);

   generate
   if (NB_DATA == 0) begin : g_check_bram_data_width_nonzero
     $fatal(1, "The DATA width of the BRAM cannot be zero.");
   end
   endgenerate

   generate
   if (NB_ADDR == 0) begin : g_check_bram_addr_width_nonzero
     $fatal(1, "The ADDRESS width of the BRAM cannot be zero.");
   end
   endgenerate

   logic [NB_ADDR-1:0]     addr;
   logic [NB_DATA-1:0]     data;
   logic [NB_DATA/8-1:0]   we;
   logic                   re;

   modport master_write (
     output   addr,
     output   data,
     output   we
   );

   modport slave_write (
     input   addr,
     input   data,
     input   we
   );

   modport slave_read (
    input    addr,
    output   data,
    input    re
  );

   modport master_read (
     output  addr,
     input   data,
     output  re
   );

endinterface
