// Reference copy of the legacy RTL, used only as the golden model by qick_vec2bit_tc00.sv.
// Source: openquantumhardware/qick firmware/ip/qick_vec2bit/src/qick_vec2bit.v (QICK:QICK:qick_vec2bit:1.0),
// unchanged except for the module name (qick_vec2bit -> qick_vec2bit_legacy).
`timescale 1ns / 1ps

module qick_vec2bit_legacy # (
   parameter IN_DW        =  16 ,
   parameter OUT_QTY      =  4 
)(
   input  wire [IN_DW-1:0] din,
   output wire             dout0  ,
   output wire             dout1  ,
   output wire             dout2  ,
   output wire             dout3  ,
	output wire             dout4  ,
	output wire             dout5  ,
	output wire             dout6  ,
	output wire             dout7  ,
	output wire             dout8  ,
	output wire             dout9  ,
	output wire             dout10 ,
	output wire             dout11 ,
	output wire             dout12 ,
	output wire             dout13 ,
	output wire             dout14 ,
	output wire             dout15 );
   
// OUTPUTS
/////////////////////////////////////////////////

   assign dout0  = din[0];
	assign dout1  = din[1];
	assign dout2  = din[2];
	assign dout3  = din[3];
	assign dout4  = din[4];
	assign dout5  = din[5];
	assign dout6  = din[6];
	assign dout7  = din[7];
	assign dout8  = din[8];
	assign dout9  = din[9];
	assign dout10 = din[10];
	assign dout11 = din[11];
	assign dout12 = din[12];
	assign dout13 = din[13];
	assign dout14 = din[14];
	assign dout15 = din[15];
   
endmodule
