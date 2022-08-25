module pfb_dds_mux
	(
		// Reset and clock.
		aresetn			,
		aclk			,

		// S_AXIS for input data.
		s_axis_tready	,
		s_axis_tvalid	,
		s_axis_tdata	,

		// M_AXIS for CH0 output.
		m0_axis_tvalid	,
		m0_axis_tdata	,

		// M_AXIS for CH1 output.
		m1_axis_tvalid	,
		m1_axis_tdata	,

		// M_AXIS for CH2 output.
		m2_axis_tvalid	,
		m2_axis_tdata	,

		// M_AXIS for CH3 output.
		m3_axis_tvalid	,
		m3_axis_tdata	,

		// Registers.
		FREQ0_REG		,
		FREQ1_REG		,
		FREQ2_REG		,
		FREQ3_REG		,
		FREQ4_REG		,
		FREQ5_REG		,
		FREQ6_REG		,
		FREQ7_REG		,
		OUTSEL_REG		,
		CH0SEL_REG		,
		CH1SEL_REG		,
		CH2SEL_REG		,
		CH3SEL_REG	
	);

/**************/
/* Parameters */
/**************/
// Input is interleaved I+Q, compatible with quad ADC (if false, input is not interleaved - compatible with dual ADC + combiner) 
parameter INTERLEAVED_INPUT = 1;

/*********/
/* Ports */
/*********/
input				aresetn;
input				aclk;

output				s_axis_tready;
input				s_axis_tvalid;
input	[4*32-1:0]	s_axis_tdata;

output				m0_axis_tvalid;
output	[31:0]		m0_axis_tdata;

output				m1_axis_tvalid;
output	[31:0]		m1_axis_tdata;

output				m2_axis_tvalid;
output	[31:0]		m2_axis_tdata;

output				m3_axis_tvalid;
output	[31:0]		m3_axis_tdata;

input	[31:0]		FREQ0_REG;
input	[31:0]		FREQ1_REG;
input	[31:0]		FREQ2_REG;
input	[31:0]		FREQ3_REG;
input	[31:0]		FREQ4_REG;
input	[31:0]		FREQ5_REG;
input	[31:0]		FREQ6_REG;
input	[31:0]		FREQ7_REG;
input	[1:0]		OUTSEL_REG;
input	[2:0]		CH0SEL_REG;
input	[2:0]		CH1SEL_REG;
input	[2:0]		CH2SEL_REG;
input	[2:0]		CH3SEL_REG;

/********************/
/* Internal signals */
/********************/

wire				tvalid_pfb;
wire	[8*32-1:0]	tdata_pfb;

wire				tvalid_dds;
wire	[8*32-1:0]	tdata_dds;

/**********************/
/* Begin Architecture */
/**********************/
pfb
	#(
		.L(4),
		.INTERLEAVED_INPUT(INTERLEAVED_INPUT)
	)
	pfb_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tready	(s_axis_tready	),
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tdata	(s_axis_tdata	),

		// M_AXIS for output data.
		.m_axis_tvalid	(tvalid_pfb		),
		.m_axis_tdata	(tdata_pfb		)
	);

ddsprod_v ddsprod_v_i
	(
		// Reset and clock.
		.aresetn		(aresetn	),
		.aclk			(aclk		),

		// S_AXIS for input data.
		.s_axis_tvalid	(tvalid_pfb	),
		.s_axis_tdata	(tdata_pfb	),

		// M_AXIS for output data.
		.m_axis_tvalid	(tvalid_dds	),
		.m_axis_tdata	(tdata_dds	),

		// Registers.
		.FREQ0_REG		(FREQ0_REG 	),
		.FREQ1_REG		(FREQ1_REG	), 
		.FREQ2_REG		(FREQ2_REG	), 
		.FREQ3_REG		(FREQ3_REG	), 
		.FREQ4_REG		(FREQ4_REG	), 
		.FREQ5_REG		(FREQ5_REG	), 
		.FREQ6_REG		(FREQ6_REG	), 
		.FREQ7_REG		(FREQ7_REG	), 
		.OUTSEL_REG		(OUTSEL_REG	)
	);

pfb_mux pfb_mux_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tvalid	(tvalid_dds		),
		.s_axis_tdata	(tdata_dds		),

		// M_AXIS for CH0 output.
		.m0_axis_tvalid	(m0_axis_tvalid	),
		.m0_axis_tdata	(m0_axis_tdata	),

		// M_AXIS for CH1 output.
		.m1_axis_tvalid	(m1_axis_tvalid	),
		.m1_axis_tdata	(m1_axis_tdata	),

		// M_AXIS for CH2 output.
		.m2_axis_tvalid	(m2_axis_tvalid	),
		.m2_axis_tdata	(m2_axis_tdata	),

		// M_AXIS for CH3 output.
		.m3_axis_tvalid	(m3_axis_tvalid	),
		.m3_axis_tdata	(m3_axis_tdata	),

		// Registers.
		.CH0SEL_REG		(CH0SEL_REG		),
		.CH1SEL_REG		(CH1SEL_REG		),
		.CH2SEL_REG		(CH2SEL_REG		),
		.CH3SEL_REG		(CH3SEL_REG		)
	);

endmodule

