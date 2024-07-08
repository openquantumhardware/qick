module kidsim
	(
		// Reset and clock.
		input 	wire 		rstn			,
		input 	wire 		clk				,

		// Modulation trigger.
		input	wire		trigger			,

		// Input data.
		input	wire [31:0]	din				,
		input	wire		din_valid		,

		// Output data.
		output	wire [31:0]	dout			,
		output	wire		dout_valid		,

		// Registers.
		input	wire [15:0]	DDS_BVAL_REG	,
		input	wire [15:0]	DDS_SLOPE_REG	,
		input	wire [15:0]	DDS_STEPS_REG	,
		input	wire [15:0]	DDS_WAIT_REG	,
		input	wire [15:0]	DDS_FREQ_REG	,
		input	wire [15:0]	IIR_C0_REG		,
		input	wire [15:0]	IIR_C1_REG		,
		input	wire [15:0]	IIR_G_REG		,
		input	wire [ 1:0]	OUTSEL_REG
	);

/*************/
/* Internals */
/*************/
// Data input latency.
wire	[31:0]	din_la			;
wire	[31:0]	din_la_mux		;

// DDS output.
wire			dds_valid		;
wire	[31:0]	dds_dout		;
wire	[31:0]	dds_dout_la		;
wire	[31:0]	dds_dout_la_mux	;


// Product 0 output.
wire			prod0_valid		;
wire	[31:0]	prod0_dout		;

// IIR output.
wire			iir_valid		;
wire	[31:0]	iir_dout		;

// Product 1 output.
wire			prod1_valid		;
wire	[31:0]	prod1_dout		;

// Muxed output.
wire	[31:0]	dout_mux		;

/****************/
/* Architecture */
/****************/

// DDS Block.
// Latency = 2.
dds_top
	dds_top_i
	(
		// Reset and clock.
		.rstn		(rstn			),
		.clk		(clk			),

		// Modulation trigger.
		.trigger	(trigger		),

		// Data input.
		.din_valid	(din_valid		),

		// Data output.
		.dout_valid	(dds_valid		),
		.dout		(dds_dout		),

		// Registers.
		.BVAL_REG	(DDS_BVAL_REG	),
		.SLOPE_REG	(DDS_SLOPE_REG	),
		.STEPS_REG	(DDS_STEPS_REG	),
		.WAIT_REG	(DDS_WAIT_REG	),
		.FREQ_REG	(DDS_FREQ_REG	)
	);

// Product by e^-jw.
// Latency = 4.
prod
	#(
		.CONJA	(0	),
		.CONJB	(1	),
		.B		(16	)
	)
	prod0_i
	(
		// Reset and clock.
		.rstn		(rstn			),
		.clk		(clk			),

		// Input data.
		.din_valid	(dds_valid		),
		.dina		(din_la			),
		.dinb		(dds_dout		),

		// Output data.
		.dout_valid	(prod0_valid	),
		.dout		(prod0_dout		)
	);
	
// IIR.
// Latency = 4.
iir_iq
	#(
		.B 	(16	),
		.BA	(20	)
	)
	iir_iq_i
	(
		// Reset and clock.
		.rstn		(rstn			),
		.clk		(clk			),

		// Input data.
		.din_valid	(prod0_valid	),
		.din		(prod0_dout		),

		// Output data.
		.dout_valid	(iir_valid		),
		.dout		(iir_dout		),

		// Registers.
		.C0_REG		(IIR_C0_REG		),
		.C1_REG		(IIR_C1_REG		),
		.G_REG		(IIR_G_REG		)
	);

// Product by e^jw.
// Latency = 4.
prod
	#(
		.CONJA	(0	),
		.CONJB	(0	),
		.B		(16	)
	)
	prod1_i
	(
		// Reset and clock.
		.rstn		(rstn			),
		.clk		(clk			),

		// Input data.
		.din_valid	(iir_valid		),
		.dina		(iir_dout		),
		.dinb		(dds_dout_la	),

		// Output data.
		.dout_valid	(prod1_valid	),
		.dout		(prod1_dout		)
	);

// din latency.
latency_reg
	#(
		// Latency.
		.N(2),

		// Data width.
		.B(32)
	)
	latency_reg_din_i
	(
		// Reset and clock.
		.rstn	(rstn	),
		.clk	(clk	),

		// Data input.
		.din	(din	),

		// Data output.
		.dout	(din_la	)
	);

// din latency (mux output).
latency_reg
	#(
		// Latency.
		.N(12),

		// Data width.
		.B(32)
	)
	latency_reg_din_mux_i
	(
		// Reset and clock.
		.rstn	(rstn		),
		.clk	(clk		),

		// Data input.
		.din	(din_la		),

		// Data output.
		.dout	(din_la_mux	)
	);

// dds_dout latency.
latency_reg
	#(
		// Latency.
		.N(8),

		// Data width.
		.B(32)
	)
	latency_reg_dds_dout_i
	(
		// Reset and clock.
		.rstn	(rstn			),
		.clk	(clk			),

		// Data input.
		.din	(dds_dout		),

		// Data output.
		.dout	(dds_dout_la	)
	);

// dds_dout latency (mux output).
latency_reg
	#(
		// Latency.
		.N(4),

		// Data width.
		.B(32)
	)
	latency_reg_dds_dout_mux_i
	(
		// Reset and clock.
		.rstn	(rstn				),
		.clk	(clk				),

		// Data input.
		.din	(dds_dout_la		),

		// Data output.
		.dout	(dds_dout_la_mux	)
	);

// Muxed output.
assign dout_mux	=	(OUTSEL_REG == 0)? prod1_dout		:
					(OUTSEL_REG == 1)? dds_dout_la_mux	:
					(OUTSEL_REG == 2)? din_la_mux		:
					32'h0000_0000;

// Assign outputs.
assign dout			= dout_mux;
assign dout_valid	= prod1_valid;

endmodule
