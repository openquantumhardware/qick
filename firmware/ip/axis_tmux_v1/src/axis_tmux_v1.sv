module axis_tmux_v1
	#(
		// Number of outputs.
		parameter N = 8,

		// Number of data bits.
		parameter B = 16
	)
	(
		// Reset and clock.
		input	wire			aresetn			,
		input	wire			aclk			,

		// S_AXIS for input data.
		output	wire 			s_axis_tready	,
		input	wire 			s_axis_tvalid	,
		input	wire 	[B-1:0]	s_axis_tdata	,

		// M_AXIS for output data.
		output	wire			m0_axis_tvalid	,
		output	wire	[B-1:0]	m0_axis_tdata	,

		output	wire			m1_axis_tvalid	,
		output	wire	[B-1:0]	m1_axis_tdata	,

		output	wire			m2_axis_tvalid	,
		output	wire	[B-1:0]	m2_axis_tdata	,

		output	wire			m3_axis_tvalid	,
		output	wire	[B-1:0]	m3_axis_tdata	,

		output	wire			m4_axis_tvalid	,
		output	wire	[B-1:0]	m4_axis_tdata	,

		output	wire			m5_axis_tvalid	,
		output	wire	[B-1:0]	m5_axis_tdata	,

		output	wire			m6_axis_tvalid	,
		output	wire	[B-1:0]	m6_axis_tdata	,

		output	wire			m7_axis_tvalid	,
		output	wire	[B-1:0]	m7_axis_tdata
	);

/**********************/
/* Begin Architecture */
/**********************/
tmux
	#(
		// Number of outputs.
		.N(N),

		// Number of data bits.
		.B(B)
	)
	tmux_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tready	(s_axis_tready	),
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tdata	(s_axis_tdata	),

		// M_AXIS for output data.
		.m0_axis_tvalid	(m0_axis_tvalid	),
		.m0_axis_tdata	(m0_axis_tdata	),

		.m1_axis_tvalid	(m1_axis_tvalid	),
		.m1_axis_tdata	(m1_axis_tdata	),

		.m2_axis_tvalid	(m2_axis_tvalid	),
		.m2_axis_tdata	(m2_axis_tdata	),

		.m3_axis_tvalid	(m3_axis_tvalid	),
		.m3_axis_tdata	(m3_axis_tdata	),

		.m4_axis_tvalid	(m4_axis_tvalid	),
		.m4_axis_tdata	(m4_axis_tdata	),

		.m5_axis_tvalid	(m5_axis_tvalid	),
		.m5_axis_tdata	(m5_axis_tdata	),

		.m6_axis_tvalid	(m6_axis_tvalid	),
		.m6_axis_tdata	(m6_axis_tdata	),

		.m7_axis_tvalid	(m7_axis_tvalid	),
		.m7_axis_tdata	(m7_axis_tdata	)
	);

endmodule

