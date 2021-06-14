module dither
	#(
		parameter N 	= 8,	// Bits of input.
		parameter M 	= 6, 	// Bits of output.
		parameter SEED 	= 0		// Random Number Generator.
	)
	(
		input			rstn	,
		input			clk		,
		input [N-1:0]	din		,
		output [M-1:0]	dout	,
		
		// Registers.
		input [N-1:0]	RNDQ_REG
	);

// Random number.
wire signed [N-1:0] rnd_int;
wire signed	[N-1:0] rnd_q;
reg signed 	[N:0] 	rnd_r1;
reg signed 	[N:0] 	rnd_r2;
reg signed 	[N:0] 	rnd_r3;
reg signed 	[N:0] 	rnd_r4;

// Signal + Noise.
wire signed [N:0]	x;
wire signed	[N:0]	y;
wire signed	[N:0]	q;
reg signed	[M-1:0]	q_r;

// Random Number Generator.
random_gen
	#(
		.W		(N		),
		.SEED	(SEED	)
	)
	random_gen_i
	(
		.rstn	(rstn		),
		.clk	(clk		),
		.dout	(rnd_int	)
	);

// Noise (divide to lower amplitude).
assign rnd_q	= rnd_int >>> RNDQ_REG;

// Signal + Noise.
assign x		= {din[N-1],din};
assign y		= x + rnd_r4;
assign q		= y >>> (N+1-M);

// Registes.
always @(posedge clk) begin
	if (~rstn) begin
		// Random number.
		rnd_r1	<= 0;
		rnd_r2	<= 0;
		rnd_r3	<= 0;
		rnd_r4	<= 0;
		
		// Signal + Noise.
		q_r		<= 0;
	end
	else begin
		// Random number.
		rnd_r1	<= {rnd_q[N-1],rnd_q};
		rnd_r2	<= rnd_r1;
		rnd_r3	<= rnd_r2;
		rnd_r4	<= rnd_r3;
		
		// Signal + Noise.
		q_r		<= q[0 +: M];
	end
end

// Assign outputs.
assign dout = q_r;

endmodule

