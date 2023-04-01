// Top-level with:
// * DDS product.
// * x4 decimation filter.
// 
// Input is 4 real samples per clock.
// Output is 1 complex sample per clock.
// Input/output are always valid.
module down_conversion_fir 
	(
		// Reset and clock.
		input	wire				aresetn			,
		input	wire				aclk			,

		// Fifo interface.
		output	wire				fifo_rd_en		,
		input	wire				fifo_empty		,
		input	wire	[87:0]		fifo_dout		,

    	// s_axis for input data (N real samples per clock).
		output	wire				s_axis_tready	,
		input	wire				s_axis_tvalid	,
		input	wire	[4*16-1:0]	s_axis_tdata	,

		// m_axis for output data (1 complex sample per clock).
		input	wire				m_axis_tready	,
		output	wire				m_axis_tvalid	,
		output	wire	[31:0]		m_axis_tdata
	);

/********************/
/* Internal signals */
/********************/
localparam N = 4;

// Down conversion output.
wire 			tvalid_i	;
wire 			tready_i	;
wire [127:0]	tdata_i		;

// Fir output.
wire [47:0]		tdata_fir	;
wire [17:0]		tdata_real	;
wire [17:0]		tdata_imag	;

/**********************/
/* Begin Architecture */
/**********************/
// Down-conversion block (product with fast DDS).
// Latency: 16.
down_conversion
	#(
		.N(N)
	)
	down_conversion_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// Fifo interface.
		.fifo_rd_en		(fifo_rd_en		),
		.fifo_empty		(fifo_empty		),
		.fifo_dout		(fifo_dout		),

    	// s_axis for input data (N samples per clock).
		.s_axis_tready	(s_axis_tready	),
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tdata	(s_axis_tdata	),

		// m_axis for output data.
		.m_axis_tready	(tready_i		),
		.m_axis_tvalid	(tvalid_i		),
		.m_axis_tdata	(tdata_i		)
	);

// FIR with x4 decimation.
// Latency: 114.
fir_0 fir_0_i
	(
		.aclk				(aclk			),
		.s_axis_data_tvalid	(tvalid_i		),
		.s_axis_data_tready	(tready_i		),
		.s_axis_data_tdata	(tdata_i		),
		.m_axis_data_tvalid	(m_axis_tvalid	),
		.m_axis_data_tdata	(tdata_fir		)
	);

// Real/imaginary parts (18 bits).
assign tdata_real = tdata_fir[17:0];
assign tdata_imag = tdata_fir[41:24];

// Assign output.
assign m_axis_tdata = {tdata_imag[16:1], tdata_real[16:1]};

endmodule

