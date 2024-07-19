module kidsim_top
	(
		// Reset and clock.
		input 	wire 		rstn			,
		input 	wire 		clk				,

		// Modulation trigger.
		input	wire		trigger			,

		// Input data.
		input	wire		din_valid		,
		input	wire [31:0]	din				,
		input	wire		din_last		,

		// Output data.
		output	wire		dout_valid		,
		output	wire [31:0]	dout			,
		output	wire		dout_last		,

		// Registers.
		input	wire [15:0]	DDS_BVAL_REG	,
		input	wire [15:0]	DDS_SLOPE_REG	,
		input	wire [15:0]	DDS_STEPS_REG	,
		input	wire [15:0]	DDS_WAIT_REG	,
		input	wire [15:0]	DDS_FREQ_REG	,
		input	wire [15:0]	IIR_C0_REG		,
		input	wire [15:0]	IIR_C1_REG		,
		input	wire [15:0]	IIR_G_REG		,
		input	wire [ 1:0]	OUTSEL_REG		,
		input	wire [15:0]	PUNCT_ID_REG	,
		input	wire		WE_REG
	);

/*************/
/* Internals */
/*************/

// din latency.
wire	[31:0]	din_la0				;
wire	[31:0]	din_la1				;

// Punct.
wire			punct_valid			;
wire			punct_last			;
wire			punct_en			;

// punct_valid latency.
wire			punct_valid_la		;

// punct_last latency.
wire			punct_last_la		;

// Kidsim.
wire			kidsim_din_valid	;
wire	[31:0]	kidsim_dout			;
wire			kidsim_dout_valid	;

// Muxed output.
wire	[31:0]	dout_mux			;

// Registers.
reg 	[15:0]	DDS_BVAL_REG_r		;
reg 	[15:0]	DDS_SLOPE_REG_r		;
reg 	[15:0]	DDS_STEPS_REG_r		;
reg 	[15:0]	DDS_WAIT_REG_r		;
reg 	[15:0]	DDS_FREQ_REG_r		;
reg 	[15:0]	IIR_C0_REG_r		;
reg 	[15:0]	IIR_C1_REG_r		;
reg 	[15:0]	IIR_G_REG_r			;
reg 	[ 1:0]	OUTSEL_REG_r		;
reg 	[15:0]	PUNCT_ID_REG_r		;
reg				WE_REG_resync		;


/****************/
/* Architecture */
/****************/

// WE_REG_resync.
synchronizer_n WE_REG_resync_i
	(
		.rstn	    (rstn			),
		.clk 		(clk			),
		.data_in	(WE_REG			),
		.data_out	(WE_REG_resync	)
	);

// Registers.
always @(posedge clk) begin
	if (~rstn) begin
		DDS_BVAL_REG_r	<= 0;
		DDS_SLOPE_REG_r	<= 0;
		DDS_STEPS_REG_r	<= 0;
		DDS_WAIT_REG_r	<= 0;
		DDS_FREQ_REG_r	<= 0;
		IIR_C0_REG_r	<= 0;
		IIR_C1_REG_r	<= 0;
		IIR_G_REG_r		<= 0;
		OUTSEL_REG_r	<= 2;	// By-pass by default.
		PUNCT_ID_REG_r	<= 0;
	end
	else begin
		if ( WE_REG_resync == 1'b1) begin
			DDS_BVAL_REG_r	<= DDS_BVAL_REG	;
			DDS_SLOPE_REG_r	<= DDS_SLOPE_REG;
			DDS_STEPS_REG_r	<= DDS_STEPS_REG;
			DDS_WAIT_REG_r	<= DDS_WAIT_REG	;
			DDS_FREQ_REG_r	<= DDS_FREQ_REG	;
			IIR_C0_REG_r	<= IIR_C0_REG	;
			IIR_C1_REG_r	<= IIR_C1_REG	;
			IIR_G_REG_r		<= IIR_G_REG	;
			OUTSEL_REG_r	<= OUTSEL_REG	;
			PUNCT_ID_REG_r	<= PUNCT_ID_REG	;
		end
	end
end

// Puncturing block.
// Latency : 2.
punct
	punct_i
	(
		// Reset and clock.
		.rstn		(rstn			),
		.clk		(clk			),

		// Input data.
		.din_valid	(din_valid		),
		.din_last	(din_last		),

		// Output data.
		.dout_valid	(punct_valid	),
		.dout_last	(punct_last		),
		.dout_en	(punct_en		),

		// Registers.
		.ID_REG		(PUNCT_ID_REG_r	)
	);

assign kidsim_din_valid	= punct_valid & punct_en;

// KID Simulator.
// Latency : 14.
kidsim
	kidsim_i
	(
		// Reset and clock.
		.rstn			(rstn				),
		.clk			(clk				),

		// Modulation trigger.
		.trigger		(trigger			),

		// Input data.
		.din			(din_la0			),
		.din_valid		(kidsim_din_valid	),

		// Output data.
		.dout			(kidsim_dout		),
		.dout_valid		(kidsim_dout_valid	),

		// Registers.
		.DDS_BVAL_REG	(DDS_BVAL_REG_r		),
		.DDS_SLOPE_REG	(DDS_SLOPE_REG_r	),
		.DDS_STEPS_REG	(DDS_STEPS_REG_r	),
		.DDS_WAIT_REG	(DDS_WAIT_REG_r		),
		.DDS_FREQ_REG	(DDS_FREQ_REG_r		),
		.IIR_C0_REG		(IIR_C0_REG_r		),
		.IIR_C1_REG		(IIR_C1_REG_r		),
		.IIR_G_REG		(IIR_G_REG_r		),
		.OUTSEL_REG		(OUTSEL_REG_r		)
	);

// din latency.
latency_reg
	#(
		// Latency.
		.N(2),

		// Data width.
		.B(32)
	)
	latency_reg_din_0i
	(
		// Reset and clock.
		.rstn	(rstn		),
		.clk	(clk		),

		// Data input.
		.din	(din		),

		// Data output.
		.dout	(din_la0	)
	);

latency_reg
	#(
		// Latency.
		.N(14),

		// Data width.
		.B(32)
	)
	latency_reg_din_1i
	(
		// Reset and clock.
		.rstn	(rstn		),
		.clk	(clk		),

		// Data input.
		.din	(din_la0	),

		// Data output.
		.dout	(din_la1	)
	);

// punct_valid latency.
latency_reg
	#(
		// Latency.
		.N(14),

		// Data width.
		.B(1)
	)
	latency_reg_punct_valid_i
	(
		// Reset and clock.
		.rstn	(rstn			),
		.clk	(clk			),

		// Data input.
		.din	(punct_valid	),

		// Data output.
		.dout	(punct_valid_la	)
	);

// punct_last latency.
latency_reg
	#(
		// Latency.
		.N(14),

		// Data width.
		.B(1)
	)
	latency_reg_punct_last_i
	(
		// Reset and clock.
		.rstn	(rstn			),
		.clk	(clk			),

		// Data input.
		.din	(punct_last		),

		// Data output.
		.dout	(punct_last_la	)
	);

// Muxed output.
assign dout_mux = (kidsim_dout_valid == 1'b1)? kidsim_dout : din_la1;

// Assign outputs.
assign dout_valid 	= punct_valid_la;
assign dout			= dout_mux;
assign dout_last	= punct_last_la;

endmodule
