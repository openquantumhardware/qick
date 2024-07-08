module pfb
	#(
		// Number of channels.
		parameter N = 32	,
		
		// Number of Lanes (Output).
		parameter L = 4
	)
	(
		// Reset and clock.
		input wire 				aresetn			,
		input wire 				aclk			,

		// S_AXIS for input data.
		input wire [2*L*32-1:0]	s_axis_tdata	,
		input wire 				s_axis_tlast	,
		input wire				s_axis_tvalid	,
		output wire				s_axis_tready	,

		// M_AXIS for output data.
		output wire [L*32-1:0]	m_axis_tdata	,
		output wire				m_axis_tvalid	,

		// Registers.
		input wire	[31:0]		QOUT_REG
	);

/********************/
/* Internal signals */
/********************/
wire[2*L*32-1:0]	pimod_tdata;
wire				pimod_tlast;
wire				pimod_tvalid;

wire[2*L*32-1:0]	conj_0_tdata;
wire				conj_0_tlast;
wire				conj_0_tvalid;

wire[2*L*32-1:0]	ssrfft_tdata;
wire				ssrfft_tlast;
wire				ssrfft_tvalid;

wire[2*L*32-1:0]	conj_1_tdata;
wire				conj_1_tlast;
wire				conj_1_tvalid;

wire[2*L*32-1:0]	switch_tdata;
wire				switch_tlast;
wire				switch_tvalid;


/**********************/
/* Begin Architecture */
/**********************/

// PI modulation block.
pimod_pfb
	#(
		// FFT size.
		.NFFT	(N		),
		// Number of bits.
		.B		(16		),
		// Number of Lanes.
		.L		(2*L	)
	)
	pimod_pfb_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input.
		.s_axis_tdata	(s_axis_tdata 	),
		.s_axis_tlast	(s_axis_tlast 	),
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tready	(				),

		// M_AXIS for output.
		.m_axis_tdata	(pimod_tdata 	),
		.m_axis_tlast	(pimod_tlast 	),
		.m_axis_tvalid	(pimod_tvalid	),
		.m_axis_tready	(1'b1			)
	);

// Complex conjugation.
pfb_conjugate
	#(
		// Number of bits of real/imaginary part.
		.B	(16		),

		// Number of lanes.
		.L	(2*L	)
	)
	conj_0_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tdata	(pimod_tdata	),
		.s_axis_tlast	(pimod_tlast	),
		.s_axis_tvalid	(pimod_tvalid	),

		// M_AXIS for output data.
		.m_axis_tdata	(conj_0_tdata	),
		.m_axis_tlast	(conj_0_tlast	),
		.m_axis_tvalid	(conj_0_tvalid	)
	);

// SSR FFT 8x256 Sync.
ssrfft_8x256_sync
	#(
		.NFFT	(N		),
		.SSR	(2*L	),
		.B		(16		)
	)
	ssrfft_i
    (
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// AXIS Slave.
		.s_axis_tdata	(conj_0_tdata	),
		.s_axis_tlast	(conj_0_tlast	),
		.s_axis_tvalid	(conj_0_tvalid	),

		// AXIS Master.
		.m_axis_tdata	(ssrfft_tdata	),
		.m_axis_tlast	(ssrfft_tlast	),
		.m_axis_tvalid	(ssrfft_tvalid	),

		// Registers.
		.SCALE_REG		(0				),
		.QOUT_REG		(QOUT_REG		)
    );

// Complex conjugation.
pfb_conjugate
	#(
		// Number of bits of real/imaginary part.
		.B	(16		),

		// Number of lanes.
		.L	(2*L	)
	)
	conj_1_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tdata	(ssrfft_tdata	),
		.s_axis_tlast	(ssrfft_tlast	),
		.s_axis_tvalid	(ssrfft_tvalid	),

		// M_AXIS for output data.
		.m_axis_tdata	(conj_1_tdata	),
		.m_axis_tlast	(conj_1_tlast	),
		.m_axis_tvalid	(conj_1_tvalid	)
	);

// PFB Switch to reorder samples.
pfb_switch
	#(
		.B(32),
		.L(L),
		.N(N)
	)
	pfb_switch_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tvalid	(conj_1_tvalid	),
		.s_axis_tlast	(conj_1_tlast	),
		.s_axis_tdata	(conj_1_tdata	),

		// M_AXIS for output data.
		.m_axis_tvalid	(switch_tvalid	),
		.m_axis_tlast	(switch_tlast	),
		.m_axis_tdata	(switch_tdata	)
	);


// Polyphase decomposition of base FIR.
firs 
	#(
		.N(N),
		.L(L)
	)
	firs_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tdata	(switch_tdata	),
		.s_axis_tlast	(switch_tlast	),
		.s_axis_tvalid	(switch_tvalid	),

		// M_AXIS for output data.
		.m_axis_tdata	(m_axis_tdata	),
		.m_axis_tvalid	(m_axis_tvalid	)
	);

// Assign outputs.
assign s_axis_tready 	= 1'b1;

endmodule

