module iir_iq
	#(
		parameter B 	= 16,
		parameter BA	= 20
	)
	(
		// Reset and clock.
		input 	wire 			rstn		,
		input 	wire 			clk			,

		// Input data.
		input	wire			din_valid	,
		input 	wire [2*B-1:0]	din			,

		// Output data.
		output  wire			dout_valid	,
		output 	wire [2*B-1:0]	dout		,

		// Registers.
		input	wire [B-1:0]	C0_REG		,
		input	wire [B-1:0]	C1_REG		,
		input	wire [B-1:0]	G_REG
	);

/*************/
/* Internals */
/*************/
wire [B-1:0]	din_real;
wire [B-1:0]	din_imag;
wire [B-1:0]	dout_real;
wire [B-1:0]	dout_imag;

/****************/
/* Architecture */
/****************/
assign din_real	= din[0 +: B];
assign din_imag	= din[B +: B];

// IIR for real part.
iir
	#(
		.B	(B	),
		.BA	(BA	)
	)
	iir_real_i
	(
		// Reset and clock.
		.rstn		(rstn		),
		.clk		(clk		),

		// Input data.
		.din_valid	(din_valid	),
		.din		(din_real	),

		// Output data.
		.dout_valid	(dout_valid	),
		.dout		(dout_real	),

		// Registers.
		.C0_REG		(C0_REG		),
		.C1_REG		(C1_REG		),
		.G_REG		(G_REG		)
	);

// IIR for imaginary part.
iir
	#(
		.B	(B	),
		.BA	(BA	)
	)
	iir_imag_i
	(
		// Reset and clock.
		.rstn		(rstn		),
		.clk		(clk		),

		// Input data.
		.din_valid	(din_valid	),
		.din		(din_imag	),

		// Output data.
		.dout_valid	(			),
		.dout		(dout_imag	),

		// Registers.
		.C0_REG		(C0_REG		),
		.C1_REG		(C1_REG		),
		.G_REG		(G_REG		)
	);

// Assign outputs.
assign dout			= {dout_imag,dout_real};

endmodule

