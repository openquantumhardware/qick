module latency_reg
	#(
		// Latency.
		parameter N = 2,

		// Data width.
		parameter B = 8
	)
	(
		// Reset and clock.
		input wire 			rstn	,
		input wire 			clk		,

		// Data input.
		input wire	[B-1:0]	din		,

		// Data output.
		output wire	[B-1:0]	dout
	);


// Shift register.
reg [B-1:0]	shift_r [0:N-1];

generate
genvar i;
	for (i=0; i<N; i=i+1) begin : GEN_reg
		wire [B-1:0] temp;
		assign temp = din;

		/*************/
		/* Registers */
		/*************/
		always @(posedge clk) begin
			if (~rstn) begin
				// Shift register.
				shift_r	[i]	<= 0;
			end
			else begin
				// Shift register.
				if (i == 0)
					shift_r[i] <= temp;
				else
					shift_r	[i] <= shift_r[i-1];
			end
		end
	end
endgenerate

// Output.
assign dout = shift_r[N-1];

endmodule

