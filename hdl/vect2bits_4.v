`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/14/2020 04:56:49 PM
// Design Name: 
// Module Name: vect2bits_4
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


module vect2bits_4(
    input [159:0] din,
    output dout0,
    output dout1,
    output dout2,
    output dout3,
    output dout14,
    output dout15
    );

	assign dout0 = din[0];
	assign dout1 = din[1];
	assign dout2 = din[2];
	assign dout3 = din[3];
	assign dout14 = din[14];
	assign dout15 = din[15];
endmodule
