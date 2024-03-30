module ddsprod
	(
		// Clock.
		input	wire			aclk			,

		// S_AXIS for input data.
		input	wire			s_axis_tvalid	,
		input	wire	[31:0]	s_axis_tdata	,

		// M_AXIS for output data.
		output	wire			m_axis_tvalid	,
		output	wire	[31:0]	m_axis_tdata	,

		// Registers.
		input	wire	[31:0]	PINC_REG		,
		input	wire	[31:0]	POFF_REG
	);

/********************/
/* Internal signals */
/********************/
// Data input latency.
wire	[31:0]	din_la			;

// DDS output.
wire			dds_dout_valid	;
wire	[31:0]	dds_dout		;

// Real/Imaginary parts of product.
wire	[15:0]	din_real		;
wire	[15:0]	din_imag		;
wire	[15:0]	dds_real		;
wire	[15:0]	dds_imag		;

// Full-precision product output.
wire	[31:0]	prod_real		;
wire	[31:0]	prod_imag		;

// Quantized product.
wire	[15:0]	prod_real_q		;
wire	[15:0]	prod_imag_q		;
wire	[31:0]	prod			;
reg		[31:0]	prod_r1			;

// Latency for output valid.
wire			valid_la		;


/**********************/
/* Begin Architecture */
/**********************/

// DDS block.
// Latency: 19.
dds_top dds_top_i
	(
		// Clock.
		.aclk		(aclk			),

		// Input valid.
		.din_valid	(s_axis_tvalid	),

		// Output data.
		.dout_valid	(dds_dout_valid	),
		.dout		(dds_dout		),

		// Registers.
		.PINC_REG	,
		.POFF_REG
	);

// Latency for input data.
// Latency = 19 (dds top).
latency_reg
	#(
		.N(19),
		.B(32)
	)
	latency_reg_din_i
	(
		.clk	(aclk			),
		.din	(s_axis_tdata	),
		.dout	(din_la			)
	);

// Real/Imaginary parts of product.
assign din_real	= din_la 	[15:0]	;
assign din_imag	= din_la 	[31:16]	;
assign dds_real	= dds_dout 	[15:0]	;
assign dds_imag	= dds_dout 	[31:16]	;

// Full-speed, 16x16 complex product.
// Latency: 4.
cmult_16x16 cmult_i
	(
		.clk	(aclk		),
		.din_i0	(din_real	),
		.din_q0	(din_imag	),
		.din_i1	(dds_real	),
		.din_q1	(dds_imag	),
		.dout_i	(prod_real	),
		.dout_q	(prod_imag	)
	);

// Quantized prodoct.
assign prod_real_q	= prod_real [30 -: 16];
assign prod_imag_q	= prod_imag [30 -: 16];
assign prod			= {prod_imag_q, prod_real_q};

// Latency for output valid.
// Latency = 4 (cmult) + 1 (output register).
latency_reg
	#(
		.N(5),
		.B(1)
	)
	latency_reg_valid_i
	(
		.clk	(aclk			),
		.din	(dds_dout_valid	),
		.dout	(valid_la		)
	);

// Registers.
always @(posedge aclk) begin
	// Quantized product.
	prod_r1 <= prod;
end

// Assign outputs.
assign m_axis_tvalid	= valid_la	;
assign m_axis_tdata		= prod_r1	;

endmodule

