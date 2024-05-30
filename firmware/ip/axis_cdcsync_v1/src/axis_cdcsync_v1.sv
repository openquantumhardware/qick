module axis_cdcsync_v1
	#(
		// Number of inputs/outputs.
		parameter N = 2	,

		// Number of data bits.
		parameter B = 8
	)
	(
		// S_AXIS for input data.
		input	wire			s_axis_aresetn	,
		input	wire			s_axis_aclk		,

		output	wire 			s0_axis_tready	,
		input	wire 			s0_axis_tvalid	,
		input	wire 	[B-1:0]	s0_axis_tdata	,

		output	wire 			s1_axis_tready	,
		input	wire 			s1_axis_tvalid	,
		input	wire 	[B-1:0]	s1_axis_tdata	,

		output	wire			s2_axis_tready	,
		input	wire			s2_axis_tvalid	,
		input	wire	[B-1:0]	s2_axis_tdata	,

		output	wire			s3_axis_tready	,
		input	wire			s3_axis_tvalid	,
		input	wire	[B-1:0]	s3_axis_tdata	,

		output	wire			s4_axis_tready	,
		input	wire			s4_axis_tvalid	,
		input	wire	[B-1:0]	s4_axis_tdata	,

		output	wire			s5_axis_tready	,
		input	wire			s5_axis_tvalid	,
		input	wire	[B-1:0]	s5_axis_tdata	,

		output	wire			s6_axis_tready	,
		input	wire			s6_axis_tvalid	,
		input	wire	[B-1:0]	s6_axis_tdata	,

		output	wire			s7_axis_tready	,
		input	wire			s7_axis_tvalid	,
		input	wire	[B-1:0]	s7_axis_tdata	,

		// M_AXIS for output data.
		input	wire			m_axis_aresetn	,
		input	wire			m_axis_aclk		,

		input	wire 			m0_axis_tready	,
		output	wire			m0_axis_tvalid	,
		output	wire	[B-1:0]	m0_axis_tdata	,

		input	wire 			m1_axis_tready	,
		output	wire			m1_axis_tvalid	,
		output	wire	[B-1:0]	m1_axis_tdata	,

		input	wire 			m2_axis_tready	,
		output	wire			m2_axis_tvalid	,
		output	wire	[B-1:0]	m2_axis_tdata	,

		input	wire 			m3_axis_tready	,
		output	wire			m3_axis_tvalid	,
		output	wire	[B-1:0]	m3_axis_tdata	,

		input	wire 			m4_axis_tready	,
		output	wire			m4_axis_tvalid	,
		output	wire	[B-1:0]	m4_axis_tdata	,

		input	wire 			m5_axis_tready	,
		output	wire			m5_axis_tvalid	,
		output	wire	[B-1:0]	m5_axis_tdata	,

		input	wire 			m6_axis_tready	,
		output	wire			m6_axis_tvalid	,
		output	wire	[B-1:0]	m6_axis_tdata	,

		input	wire 			m7_axis_tready	,
		output	wire			m7_axis_tvalid	,
		output	wire	[B-1:0]	m7_axis_tdata
	);

/**********************/
/* Begin Architecture */
/**********************/
cdcsync
	#(
		// Number of inputs/outputs.
		.N(N),

		// Number of data bits.
		.B(B)
	)
	cdcsync_i
	(
		// S_AXIS for input data.
		.s_axis_aresetn	(s_axis_aresetn	),
		.s_axis_aclk	(s_axis_aclk	),

		.s0_axis_tready	(s0_axis_tready	),
		.s0_axis_tvalid	(s0_axis_tvalid	),
		.s0_axis_tdata	(s0_axis_tdata	),

		.s1_axis_tready	(s1_axis_tready	),
		.s1_axis_tvalid	(s1_axis_tvalid	),
		.s1_axis_tdata	(s1_axis_tdata	),

		.s2_axis_tready	(s2_axis_tready	),
		.s2_axis_tvalid	(s2_axis_tvalid	),
		.s2_axis_tdata	(s2_axis_tdata	),

		.s3_axis_tready	(s3_axis_tready	),
		.s3_axis_tvalid	(s3_axis_tvalid	),
		.s3_axis_tdata	(s3_axis_tdata	),

		.s4_axis_tready	(s4_axis_tready	),
		.s4_axis_tvalid	(s4_axis_tvalid	),
		.s4_axis_tdata	(s4_axis_tdata	),

		.s5_axis_tready	(s5_axis_tready	),
		.s5_axis_tvalid	(s5_axis_tvalid	),
		.s5_axis_tdata	(s5_axis_tdata	),

		.s6_axis_tready	(s6_axis_tready	),
		.s6_axis_tvalid	(s6_axis_tvalid	),
		.s6_axis_tdata	(s6_axis_tdata	),

		.s7_axis_tready	(s7_axis_tready	),
		.s7_axis_tvalid	(s7_axis_tvalid	),
		.s7_axis_tdata	(s7_axis_tdata	),

		// M_AXIS for output data.
		.m_axis_aresetn	(m_axis_aresetn	),
		.m_axis_aclk	(m_axis_aclk	),

		.m0_axis_tready	(m0_axis_tready	),
		.m0_axis_tvalid	(m0_axis_tvalid	),
		.m0_axis_tdata	(m0_axis_tdata	),

		.m1_axis_tready	(m1_axis_tready	),
		.m1_axis_tvalid	(m1_axis_tvalid	),
		.m1_axis_tdata	(m1_axis_tdata	),

		.m2_axis_tready	(m2_axis_tready	),
		.m2_axis_tvalid	(m2_axis_tvalid	),
		.m2_axis_tdata	(m2_axis_tdata	),

		.m3_axis_tready	(m3_axis_tready	),
		.m3_axis_tvalid	(m3_axis_tvalid	),
		.m3_axis_tdata	(m3_axis_tdata	),

		.m4_axis_tready	(m4_axis_tready	),
		.m4_axis_tvalid	(m4_axis_tvalid	),
		.m4_axis_tdata	(m4_axis_tdata	),

		.m5_axis_tready	(m5_axis_tready	),
		.m5_axis_tvalid	(m5_axis_tvalid	),
		.m5_axis_tdata	(m5_axis_tdata	),

		.m6_axis_tready	(m6_axis_tready	),
		.m6_axis_tvalid	(m6_axis_tvalid	),
		.m6_axis_tdata	(m6_axis_tdata	),

		.m7_axis_tready	(m7_axis_tready	),
		.m7_axis_tvalid	(m7_axis_tvalid	),
		.m7_axis_tdata	(m7_axis_tdata	)
	);

endmodule

