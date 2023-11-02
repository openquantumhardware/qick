///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 11-2023
//  Version        : 2
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR :  tProc_v2
/* Description: 
   This block register the input of the sAxi.
   Indicates the arrival of new data in port_tnew_o
*/
//////////////////////////////////////////////////////////////////////////////

`include "_qproc_defines.svh"

module qproc_inport_reg # (
   parameter PORT_QTY    =  2 
)(
// CLK & RST.
   input  wire                c_clk_i     ,
   input  wire                c_rst_ni    ,
   input  wire                c_clear     ,
// DATA INPUT INTERFACE
   input   wire                 port_tvalid_i  [ PORT_QTY ]  ,
   input   wire [63:0]          port_tdata_i   [ PORT_QTY ] ,
// DATA OUTPUT INTERFACE
   output  wire [PORT_QTY-1:0 ] port_tnew_o      ,
   output  wire [63:0]          port_tdata_o   [ PORT_QTY ]  
    );
    
// REGISTR INPUTS
reg  [63:0]         port_dt_r   [PORT_QTY] ;
reg  [PORT_QTY-1:0] port_dt_new ;

genvar ind;
generate
   for (ind=0; ind < PORT_QTY; ind=ind+1) begin 
      always_ff @(posedge c_clk_i)
         if (!c_rst_ni) begin
            port_dt_r[ind]   <= 0 ;
            port_dt_new[ind] <= 0 ;
         end else begin
            if ( port_tvalid_i[ind] )  begin 
               port_dt_r[ind]    <=  port_tdata_i[ind];
               port_dt_new[ind]  <=  1'b1;
            end else if (c_clear)
               port_dt_new[ind]       <= 0 ;
         end
   end
endgenerate

assign port_tnew_o   = port_dt_new ;
assign port_tdata_o  = port_dt_r ;

endmodule
