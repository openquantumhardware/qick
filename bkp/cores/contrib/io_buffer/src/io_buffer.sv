/***********************************************
 *
 *  Copyright (C) 2023 - Stratum Labs
 *
 *  Project: Stratum Labs - Common Library
 *  Author: Horacio Arnaldi <horacio.arnaldi@stratum-labs.com>
 *
 *  File: io_buffer.sv
 *  Description: Common IO buffer interface for AXI4 signals
 *
 *
 * ********************************************/

module io_buffer #
(
  parameter integer DWIDTH = 32
)
(
  input  logic              i_clk,
  input  logic              i_rst,

  input  logic [DWIDTH-1:0] i_data,
  input  logic              i_valid,
  output logic              i_ready,

  output logic [DWIDTH-1:0] o_data,
  output logic              o_valid,
  input  logic              o_ready
);

  logic [DWIDTH-1:0] data_s;
  logic valid_s, ready_s;

  in_buffer #(
    .DWIDTH(DWIDTH)
  ) u_ibuf (
    .i_clk  ( i_clk   ), 
    .i_rst  ( i_rst   ),
    .i_data ( i_data  ), 
    .i_valid( i_valid ), 
    .i_ready( i_ready ),
    .o_data ( data_s  ), 
    .o_valid( valid_s ), 
    .o_ready( ready_s )
  );

  out_buffer #(
    .DWIDTH(DWIDTH)
  ) u_obuf (
    .i_clk  ( i_clk   ), 
    .i_rst  ( i_rst   ),
    .i_data ( data_s  ), 
    .i_valid( valid_s ), 
    .i_ready( ready_s ),
    .o_data ( o_data  ), 
    .o_valid( o_valid ), 
    .o_ready( o_ready )
  );

endmodule
