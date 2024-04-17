module latency_reg
	(
		rstn	,
		clk		,

		din		,
		dout
	);

// Parameters.
parameter N = 2;	// Latency.
parameter B = 8;	// Data width.

// Ports.
input 			rstn;
input 			clk;
input	[B-1:0]	din;
output	[B-1:0]	dout;

// Shift register.
(* srl_style = "register" *) reg [B-1:0]	shift_r [0:N-1];

generate
genvar i;
	for (i=1; i<N; i=i+1) begin : GEN_reg

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
				shift_r	[i] <= shift_r[i-1];
			end
		end
	end
endgenerate

/*************/
/* Registers */
/*************/
always @(posedge clk) begin
	if (~rstn) begin
		// Shift register.
		shift_r	[0]	<= 0;
	end
	else begin
		// Shift register.
		shift_r	[0] <= din;
	end
end

// Output.
assign dout = shift_r[N-1];

endmodule

