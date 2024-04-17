module latency_reg
	(
		clk		,
		din		,
		dout
	);

// Parameters.
parameter N = 2;	// Latency.
parameter B = 8;	// Data width.

// Ports.
input 			clk;
input	[B-1:0]	din;
output	[B-1:0]	dout;

// Shift register.
reg [B-1:0]	shift_r [0:N-1];

// Array initialization.
integer i;
initial begin
	for (i=0; i<N; i=i+1)
		shift_r [i] = 0;
end


generate
genvar j;
	for (j=1; j<N; j=j+1) begin : GEN_reg
		/*************/
		/* Registers */
		/*************/
		always @(posedge clk) begin
			// Shift register.
			shift_r	[j] <= shift_r[j-1];
		end
	end
endgenerate

/*************/
/* Registers */
/*************/
always @(posedge clk) begin
	// Shift register.
	shift_r	[0] <= din;
end

// Output.
assign dout = shift_r[N-1];

endmodule

