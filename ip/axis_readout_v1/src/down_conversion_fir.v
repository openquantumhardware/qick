module down_conversion_fir (
	// Reset and clock.
	rstn				,
	clk					,

	// S_AXIS for input data.
	s_axis_tready_o		,
	s_axis_tvalid_i		,
	s_axis_tdata_i		,

	// M0_AXIS for output data (before filter and decimation).
	m0_axis_tready_i	,
	m0_axis_tvalid_o	,
	m0_axis_tdata_o		,

	// M1_AXIS for output data.
	m1_axis_tready_i	,
	m1_axis_tvalid_o	,
	m1_axis_tdata_o		,

	// Registers.
	OUTSEL_REG			,
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
input						rstn;
input						clk;

output						s_axis_tready_o;
input						s_axis_tvalid_i;
input		[N_DDS*16-1:0]	s_axis_tdata_i;

input						m0_axis_tready_i;
output						m0_axis_tvalid_o;
output		[N_DDS*32-1:0]	m0_axis_tdata_o;

input						m1_axis_tready_i;
output						m1_axis_tvalid_o;
output		[32-1:0]		m1_axis_tdata_o;

input		[1:0]			OUTSEL_REG;
input		[15:0]			DDS_FREQ_REG;

/********************/
/* Internal signals */
/********************/

/**********************/
/* Begin Architecture */
/**********************/
// Down-conversion block (product with fast DDS).
down_conversion 
	#(
		.N_DDS	(N_DDS)
	)
	down_conversion_i
	(
		// Reset and clock.
		.rstn				(rstn				),
		.clk				(clk				),

		// S_AXIS for input.
		.s_axis_tready_o	(s_axis_tready_o	),
		.s_axis_tvalid_i	(s_axis_tvalid_i	),
		.s_axis_tdata_i		(s_axis_tdata_i		),

		// M_AXIS for output.
		.m_axis_tready_i	(m0_axis_tready_i	),
		.m_axis_tvalid_o	(m0_axis_tvalid_o	),
		.m_axis_tdata_o		(m0_axis_tdata_o	),

		// Registers.
		.OUTSEL_REG			(OUTSEL_REG			),
		.DDS_FREQ_REG		(DDS_FREQ_REG		)
	);

// FIR: 8x decimation, multi-rate implementation, I/Q (2 channels).
fir_compiler_0 
	fir_i
	(
  		.aclk				(clk				),
  		.s_axis_data_tvalid	(1'b1				),
  		.s_axis_data_tready	(					),
  		.s_axis_data_tdata	(m0_axis_tdata_o	),
  		.m_axis_data_tvalid	(m1_axis_tvalid_o	),
  		.m_axis_data_tdata	(m1_axis_tdata_o	)
	);

endmodule

