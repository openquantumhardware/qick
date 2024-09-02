`timescale 1ns / 1ps
module filter_spi_bits(
    input	[3:0]	din		,
    output			dout0	,
    output 			dout1	,
    output 			dout2	,
    output 			dout3
    );

assign dout0 = din[0];
assign dout1 = din[1];
assign dout2 = din[2];
assign dout3 = din[3];

endmodule
