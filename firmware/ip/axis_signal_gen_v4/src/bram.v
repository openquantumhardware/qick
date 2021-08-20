module bram (clk,ena,wea,addra,dia,doa);

// Memory address size.
parameter N = 16;
// Data width.
parameter B = 16;

input 			clk;
input 			ena;
input 			wea;
input [N-1:0]	addra;
input [B-1:0]	dia;
output [B-1:0]	doa;

// Ram type.
reg [B-1:0] RAM [0:2**N-1];
reg [B-1:0]	doa;

always @(posedge clk)
begin
	if (ena)
	begin
    	if (wea) begin
    	    RAM[addra] <= dia;
		end
		else begin
			doa <= RAM[addra];
    	end
	end
end

endmodule

