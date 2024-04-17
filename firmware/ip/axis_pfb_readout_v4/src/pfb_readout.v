/*
 * Top-leve block which instantiates the following:
 *
 * 1) PFB, 50 % Overlap, 64 Channels, 8 selectable outputs.
 * 2) DDS, 8 channels, independent freq/phase, phase coherent.
 */
module pfb_readout
	#(
		// Number of channels.
		parameter N = 32,
		
		// Number of Lanes (Input).
		parameter L = 4
	)
	(
		// Reset and clock.
		input	wire				aresetn			,
		input	wire				aclk			,

		// S_AXIS for input data.
		input	wire				s_axis_tvalid	,
		input	wire	[L*32-1:0]	s_axis_tdata	,

		// M_AXIS for output data.
		output	wire				m_axis_tvalid	,
		output	wire	[31:0]		m0_axis_tdata	,
		output	wire	[31:0]		m1_axis_tdata	,
		output	wire	[31:0]		m2_axis_tdata	,
		output	wire	[31:0]		m3_axis_tdata	,
		output	wire	[31:0]		m4_axis_tdata	,
		output	wire	[31:0]		m5_axis_tdata	,
		output	wire	[31:0]		m6_axis_tdata	,
		output	wire	[31:0]		m7_axis_tdata	,

		// Registers.
		input	wire	[15:0]		ID0_REG			,
		input	wire	[15:0]		ID1_REG			,
		input	wire	[15:0]		ID2_REG			,
		input	wire	[15:0]		ID3_REG			,
		input	wire	[15:0]		ID4_REG			,
		input	wire	[15:0]		ID5_REG			,
		input	wire	[15:0]		ID6_REG			,
		input	wire	[15:0]		ID7_REG			,
		input	wire	[31:0]		PINC0_REG		,
		input	wire	[31:0]		POFF0_REG		,
		input	wire	[31:0]		PINC1_REG		,
		input	wire	[31:0]		POFF1_REG		,
		input	wire	[31:0]		PINC2_REG		,
		input	wire	[31:0]		POFF2_REG		,
		input	wire	[31:0]		PINC3_REG		,
		input	wire	[31:0]		POFF3_REG		,
		input	wire	[31:0]		PINC4_REG		,
		input	wire	[31:0]		POFF4_REG		,
		input	wire	[31:0]		PINC5_REG		,
		input	wire	[31:0]		POFF5_REG		,
		input	wire	[31:0]		PINC6_REG		,
		input	wire	[31:0]		POFF6_REG		,
		input	wire	[31:0]		PINC7_REG		,
		input	wire	[31:0]		POFF7_REG
	);

/********************/
/* Internal signals */
/********************/

wire			tvalid_i;
wire	[31:0]	tdata0_i;
wire	[31:0]	tdata1_i;
wire	[31:0]	tdata2_i;
wire	[31:0]	tdata3_i;
wire	[31:0]	tdata4_i;
wire	[31:0]	tdata5_i;
wire	[31:0]	tdata6_i;
wire	[31:0]	tdata7_i;

/**********************/
/* Begin Architecture */
/**********************/
// PFB.
pfb_top
	#(
		// Number of channels.
		.N(N),
		
		// Number of Lanes (Input).
		.L(L)
	)
	pfb_top_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tdata	(s_axis_tdata	),

		// M_AXIS for output data.
		.m_axis_tvalid	(tvalid_i		),
		.m0_axis_tdata	(tdata0_i		),
		.m1_axis_tdata	(tdata1_i		),
		.m2_axis_tdata	(tdata2_i		),
		.m3_axis_tdata	(tdata3_i		),
		.m4_axis_tdata	(tdata4_i		),
		.m5_axis_tdata	(tdata5_i		),
		.m6_axis_tdata	(tdata6_i		),
		.m7_axis_tdata	(tdata7_i		),

		// Registers.
		.ID0_REG		(ID0_REG		),
		.ID1_REG		(ID1_REG		),
		.ID2_REG		(ID2_REG		),
		.ID3_REG		(ID3_REG		),
		.ID4_REG		(ID4_REG		),
		.ID5_REG		(ID5_REG		),
		.ID6_REG		(ID6_REG		),
		.ID7_REG		(ID7_REG		)
	);

// DDS.
ddsprod_v ddsprod_v_i
	(
		// Clock.
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tvalid	(tvalid_i		),
		.s0_axis_tdata	(tdata0_i		),
		.s1_axis_tdata	(tdata1_i		),
		.s2_axis_tdata	(tdata2_i		),
		.s3_axis_tdata	(tdata3_i		),
		.s4_axis_tdata	(tdata4_i		),
		.s5_axis_tdata	(tdata5_i		),
		.s6_axis_tdata	(tdata6_i		),
		.s7_axis_tdata	(tdata7_i		),

		// M_AXIS for output data.
		.m_axis_tvalid	(m_axis_tvalid	),
		.m0_axis_tdata	(m0_axis_tdata	),
		.m1_axis_tdata	(m1_axis_tdata	),
		.m2_axis_tdata	(m2_axis_tdata	),
		.m3_axis_tdata	(m3_axis_tdata	),
		.m4_axis_tdata	(m4_axis_tdata	),
		.m5_axis_tdata	(m5_axis_tdata	),
		.m6_axis_tdata	(m6_axis_tdata	),
		.m7_axis_tdata	(m7_axis_tdata	),

		// Registers.
		.PINC0_REG		(PINC0_REG		),
		.POFF0_REG		(POFF0_REG		),
		.PINC1_REG		(PINC1_REG		),
		.POFF1_REG		(POFF1_REG		),
		.PINC2_REG		(PINC2_REG		),
		.POFF2_REG		(POFF2_REG		),
		.PINC3_REG		(PINC3_REG		),
		.POFF3_REG		(POFF3_REG		),
		.PINC4_REG		(PINC4_REG		),
		.POFF4_REG		(POFF4_REG		),
		.PINC5_REG		(PINC5_REG		),
		.POFF5_REG		(POFF5_REG		),
		.PINC6_REG		(PINC6_REG		),
		.POFF6_REG		(POFF6_REG		),
		.PINC7_REG		(PINC7_REG		),
		.POFF7_REG		(POFF7_REG		)
	);

endmodule

