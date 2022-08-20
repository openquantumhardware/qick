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
		m_axis_tdata
	);

/**************/
/* Parameters */
/**************/
// Number of Lanes (Input).
parameter L = 4;

// Input is interleaved I+Q, compatible with quad ADC (if false, input is not interleaved - compatible with dual ADC + combiner) 
parameter INTERLEAVED_INPUT = 1;


/*********/
/* Ports */
/*********/
input					aresetn;
input					aclk;

output					s_axis_tready;
input					s_axis_tvalid;
input	[L*32-1:0]		s_axis_tdata;

output					m_axis_tvalid;
output	[2*L*32-1:0]	m_axis_tdata;

/********************/
/* Internal signals */
/********************/
wire				tvalid_fir;
wire[2*L*32-1:0]	tdata_fir;

wire				tvalid_fft;
wire[2*L*32-1:0]	tdata_fft;

reg [31:0]			SCALE_REG 	= 0;
reg [31:0]			QOUT_REG	= 0;

/**********************/
/* Begin Architecture */
/**********************/

// Polyphase Filter Bank.
firs
	#(
		.L(L),
		.INTERLEAVED_INPUT(INTERLEAVED_INPUT)
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
		.m_axis_tvalid	(tvalid_fir		),
		.m_axis_tdata	(tdata_fir		)
	);

// SSR FFT 8x8.
ssrfft_8x8
	#(
		.NFFT	(2*L),
		.SSR	(2*L),
		.B		(16	)
	)
    ssrfft_8x8_i
    (
		// Reset and clock.
		.aresetn		(aresetn	),
		.aclk			(aclk		),

		// AXIS Slave.
		.s_axis_tdata	(tdata_fir	),
		.s_axis_tvalid	(tvalid_fir	),

		// AXIS Master.
		.m_axis_tdata	(tdata_fft	),
		.m_axis_tvalid	(tvalid_fft	),

		// Registers.
		.SCALE_REG		(SCALE_REG	),
		.QOUT_REG		(QOUT_REG	)
    );

// Pi modulation.
pimod
	#(
		// Number of bits.
		.B(16	),
		// FFT size.
		.N(2*L	)
	)
	pimod_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// AXIS Slave I/F.
		.s_axis_tdata	(tdata_fft		),
		.s_axis_tvalid	(tvalid_fft		),

		// AXIS Master I/F.
		.m_axis_tdata	(m_axis_tdata	),
		.m_axis_tvalid	(m_axis_tvalid	)
	);


endmodule

