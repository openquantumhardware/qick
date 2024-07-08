module pfb_switch
	#(
		// Bits.
		parameter B = 32,
		
		// Number of Lanes.
		parameter L = 4	,
		
		// Number of channels.
		parameter N = 32
	)
	(
		// Reset and clock.
		input wire 				aresetn			,
		input wire 				aclk			,

		// S_AXIS for input data.
		input wire [2*L*B-1:0]	s_axis_tdata	,
		input wire				s_axis_tlast	,
		input wire				s_axis_tvalid	,

		// M_AXIS for output data.
		output wire [2*L*B-1:0]	m_axis_tdata	,
		output wire				m_axis_tlast	,
		output wire				m_axis_tvalid
	);

/********************/
/* Internal signals */
/********************/
wire			tvalid;
wire			tlast;
wire[2*L*B-1:0]	tdata;

/**********************/
/* Begin Architecture */
/**********************/

// Swap block.
pfb_swap
	#(
		.B(B),
		.L(L),
		.N(N)
	)
	pfb_swap_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tlast	(s_axis_tlast	),
		.s_axis_tdata	(s_axis_tdata	),

		// M_AXIS for output data.
		.m_axis_tvalid	(tvalid			),
		.m_axis_tlast	(tlast			),
		.m_axis_tdata	(tdata			)
	);

// Reorder block.
pfb_reorder
	#(
		.B(B),
		.L(L)
	)
	pfb_reorder_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tvalid	(tvalid			),
		.s_axis_tlast	(tlast			),
		.s_axis_tdata	(tdata			),

		// M_AXIS for output data.
		.m_axis_tvalid	(m_axis_tvalid	),
		.m_axis_tlast	(m_axis_tlast	),
		.m_axis_tdata	(m_axis_tdata	)
	);

endmodule

