module cmult_16x16
	(
		input	wire			clk		,
		input	wire	[15:0]	din_i0	,
		input	wire	[15:0]	din_q0	,
		input	wire	[15:0]	din_i1	,
		input	wire	[15:0]	din_q1	,
		output	wire	[31:0]	dout_i	,
		output	wire	[31:0]	dout_q
	);

/****************/
/* Architecture */
/****************/

// Real part.
cmult_sub
	#(
		.op("sub")
	)
	cmult_real_i
	(
		.clk	(clk	),
		.a	(din_i0	),
		.b	(din_i1	),
		.c	(din_q0	),
		.d	(din_q1	),
		.x	(dout_i	)
	);

// Imaginary part.
cmult_sub
	#(
		.op("add")
	)
	cmult_imag_i
	(
		.clk	(clk	),
		.a	(din_i0	),
		.b	(din_q1	),
		.c	(din_q0	),
		.d	(din_i1	),
		.x	(dout_q	)
	);

endmodule
