`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/14/2020 04:56:49 PM
// Design Name: 
// Module Name: vect2bits_16
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module vect2bits_16(
    input [159:0] din,
    output dout0,
    output dout1,
    output dout2,
    output dout3,
    output dout4,
    output dout5,
    output dout6,
    output dout7,
    output dout8,
    output dout9,
    output dout10,
    output dout11,
    output dout12,
    output dout13,
    output dout14,
    output dout15
    );

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
