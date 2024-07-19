module pfb
	(
		// Reset and clock.
		aresetn			,
		aclk			,

		// S_AXIS for input data.
		s_axis_tready	,
		s_axis_tvalid	,
		s_axis_tdata	,

		// M_AXIS for output data.
		m_axis_tvalid	,
		m_axis_tlast	,
		m_axis_tdata	,

		// Registers.
		QOUT_REG
	);

/**************/
/* Parameters */
/**************/
// Number of channels.
parameter N = 32;

// Number of Lanes (Input).
parameter L = 4;

/*********/
/* Ports */
/*********/
input					aresetn;
input					aclk;

output					s_axis_tready;
input					s_axis_tvalid;
input	[L*32-1:0]		s_axis_tdata;

output					m_axis_tvalid;
output					m_axis_tlast;
output	[2*L*32-1:0]	m_axis_tdata;

input	[31:0]			QOUT_REG;

/********************/
/* Internal signals */
/********************/
wire				firs_tvalid;
wire				firs_tlast;
wire[2*L*32-1:0]	firs_tdata;

wire				switch_tvalid;
wire				switch_tlast;
wire[2*L*32-1:0]	switch_tdata;

wire				ssrfft_tvalid;
wire				ssrfft_tlast;
wire[2*L*32-1:0]	ssrfft_tdata;

/**********************/
/* Begin Architecture */
/**********************/

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
		.s_axis_tready	(s_axis_tready	),
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tdata	(s_axis_tdata	),

		// M_AXIS for output data.
		.m_axis_tvalid	(firs_tvalid	),
		.m_axis_tlast	(firs_tlast		),
		.m_axis_tdata	(firs_tdata		)
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
		.s_axis_tvalid	(firs_tvalid	),
		.s_axis_tlast	(firs_tlast		),
		.s_axis_tdata	(firs_tdata		),

		// M_AXIS for output data.
		.m_axis_tvalid	(switch_tvalid	),
		.m_axis_tlast	(switch_tlast	),
		.m_axis_tdata	(switch_tdata	)
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
		.s_axis_tdata	(switch_tdata	),
		.s_axis_tlast	(switch_tlast	),
		.s_axis_tvalid	(switch_tvalid	),

		// AXIS Master.
		.m_axis_tdata	(ssrfft_tdata	),
		.m_axis_tlast	(ssrfft_tlast	),
		.m_axis_tvalid	(ssrfft_tvalid	),

		// Registers.
		.SCALE_REG		(0				),
		.QOUT_REG		(QOUT_REG		)
    );

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
		.s_axis_tdata	(ssrfft_tdata 	),
		.s_axis_tlast	(ssrfft_tlast 	),
		.s_axis_tvalid	(ssrfft_tvalid	),
		.s_axis_tready	(				),

		// M_AXIS for output.
		.m_axis_tdata	(m_axis_tdata 	),
		.m_axis_tlast	(m_axis_tlast 	),
		.m_axis_tvalid	(m_axis_tvalid	),
		.m_axis_tready	(1'b1			)
	);

endmodule

