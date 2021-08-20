module readout_top 
	(
		// Reset and clock (s1_axis, m0_axis, m1_axis).
    	aresetn			,
		aclk			,

    	// S1_AXIS: for input data (8x samples per clock).
		s_axis_tdata	,
		s_axis_tvalid	,
		s_axis_tready	,

		// M0_AXIS: for output data (before filter and decimation, 8x samples
		// per clock).
		m0_axis_tready	,
		m0_axis_tvalid	,
		m0_axis_tdata	,

		// M1_AXIS: for output data.
		m1_axis_tready	,
		m1_axis_tvalid	,
		m1_axis_tdata	,

		// Registers.
		OUTSEL_REG		,
		DDS_FREQ_REG
	);

/**************/
/* Parameters */
/**************/
// Number of parallel dds blocks.
localparam [15:0] N_DDS = 8;

/*********/
/* Ports */
/*********/
input						aresetn;
input						aclk;

output						s_axis_tready;
input						s_axis_tvalid;
input		[N_DDS*16-1:0]	s_axis_tdata;

input						m0_axis_tready;
output						m0_axis_tvalid;
output		[N_DDS*32-1:0]	m0_axis_tdata;

input						m1_axis_tready;
output						m1_axis_tvalid;
output		[32-1:0]		m1_axis_tdata;

input		[1:0]			OUTSEL_REG;
input		[15:0]			DDS_FREQ_REG;

/********************/
/* Internal signals */
/********************/

/**********************/
/* Begin Architecture */
/**********************/

// Down-conversion + Filter +  Decimation.
down_conversion_fir
	down_conversion_fir_i
	(
		// Reset and clock.
		.rstn				(aresetn		),
		.clk				(aclk			),

		// S_AXIS for input.
		.s_axis_tready_o	(s_axis_tready	),
		.s_axis_tvalid_i	(s_axis_tvalid	),
		.s_axis_tdata_i		(s_axis_tdata	),

		// M0_AXIS for output data (before filter and decimation).
		.m0_axis_tready_i	(m0_axis_tready	),
		.m0_axis_tvalid_o	(m0_axis_tvalid	),
		.m0_axis_tdata_o	(m0_axis_tdata	),

		// M1_AXIS for output data.
		.m1_axis_tready_i	(m1_axis_tready	),
		.m1_axis_tvalid_o	(m1_axis_tvalid	),
		.m1_axis_tdata_o	(m1_axis_tdata	),

		// Registers.
		.OUTSEL_REG			(OUTSEL_REG		),
		.DDS_FREQ_REG		(DDS_FREQ_REG	)
		);

endmodule

