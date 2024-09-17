///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 1-2024
//  Version        : 1
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR :  Custom Peripheral Template
/* Description: 
    File to add all the custom IPs needed for the peripheral
*/
//////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
/// Clock Domain Register Change
///////////////////////////////////////////////////////////////////////////////
module sync_reg # (
   parameter DW  = 32
)(
   input  wire [DW-1:0] dt_i     , 
   input  wire          clk_i  ,
   input  wire          rst_ni  ,
   output wire [DW-1:0] dt_o     );
   
(* ASYNC_REG = "TRUE" *) reg [DW-1:0] data_rcd, data_r ;
always_ff @(posedge clk_i)
   if(!rst_ni) begin
      data_rcd  <= 0;
      data_r    <= 0;
   end else begin 
      data_rcd  <= dt_i;
      data_r    <= data_rcd;
      end
assign dt_o = data_r ;

endmodule

///////////////////////////////////////////////////////////////////////////////
// DUAL PORT RAM
///////////////////////////////////////////////////////////////////////////////
module bram_dual_port_dc # (
   parameter MEM_AW  = 16 , 
   parameter MEM_DW  = 16 ,
   parameter RAM_OUT  = "NO_REGISTERED" // Select "NO_REGISTERED" or "REGISTERED" 
) ( 
   input  wire               clk_a_i  ,
   input  wire               en_a_i  ,
   input  wire               we_a_i  ,
   input  wire [MEM_AW-1:0]  addr_a_i  ,
   input  wire [MEM_DW-1:0]  dt_a_i  ,
   output wire [MEM_DW-1:0]  dt_a_o  ,
   input  wire               clk_b_i  ,
   input  wire               en_b_i  ,
   input  wire               we_b_i  ,
   input  wire [MEM_AW-1:0]  addr_b_i  ,
   input  wire [MEM_DW-1:0]  dt_b_i  ,
   output wire [MEM_DW-1:0]  dt_b_o  );

localparam RAM_SIZE = 2**MEM_AW ;
  
reg [MEM_DW-1:0] RAM [RAM_SIZE];
reg [MEM_DW-1:0] ram_dt_a = {MEM_DW{1'b0}};
reg [MEM_DW-1:0] ram_dt_b = {MEM_DW{1'b0}};

always @(posedge clk_a_i)
   if (en_a_i) begin
      ram_dt_a <= RAM[addr_a_i] ;
      if (we_a_i)
         RAM[addr_a_i] <= dt_a_i;
      //else
      //   ram_dt_a <= RAM[addr_a_i] ;
   end
always @(posedge clk_b_i)
   if (en_b_i)
      if (we_b_i)
         RAM[addr_b_i] <= dt_b_i;
      else
         ram_dt_b <= RAM[addr_b_i] ;

generate
   if (RAM_OUT == "NO_REGISTERED") begin: no_output_register // 1 clock cycle read
      assign dt_a_o = ram_dt_a ;
      assign dt_b_o = ram_dt_b ;
   end else begin: output_register // 2 clock cycle read
      reg [MEM_DW-1:0] ram_dt_a_r = {MEM_DW{1'b0}};
      reg [MEM_DW-1:0] ram_dt_b_r = {MEM_DW{1'b0}};
      always @(posedge clk_a_i) ram_dt_a_r <= ram_dt_a;
      always @(posedge clk_b_i) ram_dt_b_r <= ram_dt_b;
      assign dt_a_o = ram_dt_a_r ;
      assign dt_b_o = ram_dt_b_r ;
   end
endgenerate

endmodule

