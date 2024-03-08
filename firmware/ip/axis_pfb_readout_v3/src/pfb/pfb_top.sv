// This block instantiates the PFB and one channel
// selector per lane.
//
// Even if the number of channels N and the number
// of (input) lanes are input parameters, they are
// fixed by the PFB design. In this case:
//
// N = 64
// L = 4 (input lanes)
//
// The number of lanes are duplicated due to the
// overlap nature of the PFB. This should be taken
// into consideration with instantiating the channel
// selection block.
//
// The number of outputs is fixed to 4 in this case.
module pfb_top
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

		// Registers.
		input	wire	[15:0]		ID0_REG			,
		input	wire	[15:0]		ID1_REG			,
		input	wire	[15:0]		ID2_REG			,
		input	wire	[15:0]		ID3_REG
	);

/********************/
/* Internal signals */
/********************/
localparam NOUT = 4;

// PFB outputs.
wire					tvalid_pfb;
wire					tlast_pfb;
wire	[2*L*32-1:0]	tdata_pfb	;

// Chsel outputs.
wire	[NOUT-1:0]	valid		;
wire	[31:0]		dout [NOUT]	;

// Registers.
wire	[15:0]		regs [NOUT]	;

/**********************/
/* Begin Architecture */
/**********************/
// Registers.
assign regs [0] = ID0_REG;
assign regs [1] = ID1_REG;
assign regs [2] = ID2_REG;
assign regs [3] = ID3_REG;

// QOUT_REG: optimized by simulation but should be
// LOG2(PFB ORDER) - 1.
pfb
	#(
		// Number of channels.
		.N(N),
		
		// Number of Lanes (Input).
		.L(L)
	)
	pfb_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tdata	(s_axis_tdata	),

		// M_AXIS for output data.
		.m_axis_tvalid	(tvalid_pfb		),
		.m_axis_tlast	(tlast_pfb		),
		.m_axis_tdata	(tdata_pfb		),

		// Registers.
		.QOUT_REG		(5				)
	);

genvar i;
generate
	for (i=0; i<NOUT; i=i+1) begin: GEN_output

		// Add one chsel block per desired output.
		pfb_chsel
			#(
				// Bits.
				.B(32),
		
				// Number of lanes.
				.L(2*L)
			)
			pfb_chsel_i
			(
				// Clock.
				.aclk			(aclk		),
		
				// S_AXIS for input data.
				.s_axis_tdata	(tdata_pfb	),
				.s_axis_tlast	(tlast_pfb	),
		
				// M_AXIS for output data.
				.m_axis_tvalid	(valid 	[i]	),
				.m_axis_tdata	(dout	[i]	),
		
				// Registers.
				.ID_REG			(regs	[i]	)
			);
	end
endgenerate

// Assign outputs.
assign m_axis_tvalid 	= valid[0];
assign m0_axis_tdata	= dout [0];
assign m1_axis_tdata	= dout [1];
assign m2_axis_tdata	= dout [2];
assign m3_axis_tdata	= dout [3];

endmodule

