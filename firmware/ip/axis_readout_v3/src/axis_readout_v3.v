module axis_readout_v3
	(
		// Reset and clock.
		input	wire				aresetn			,
		input	wire				aclk			,

    	// s0_axis for pushing waveforms.
		output	wire				s0_axis_tready	,
		input	wire				s0_axis_tvalid	,
		input	wire	[87:0]		s0_axis_tdata	,

    	// s1_axis for input data (4 real samples per clock).
		output	wire				s1_axis_tready	,
		input	wire				s1_axis_tvalid	,
		input	wire	[4*16-1:0]	s1_axis_tdata	,

		// m_axis for output data (1 complex sample per clock).
		input	wire				m_axis_tready	,
		output	wire				m_axis_tvalid	,
		output	wire	[31:0]		m_axis_tdata
	);

/********************/
/* Internal Signals */
/********************/

// Fifo.
wire			fifo_wr_en	;
wire	[87:0]	fifo_din	;
wire			fifo_rd_en	;
wire	[87:0]	fifo_dout	;
wire			fifo_full	;
wire			fifo_empty	;

/**********************/
/* Begin Architecture */
/**********************/

// Fifo for queuing waveforms.
fifo
	#(
		// Data width.
		.B	(88),
		
		// Fifo depth.
		.N	(8)
	)
	fifo_i
	( 
		.rstn	(aresetn	),
		.clk 	(aclk		),
		
		// Write I/F.
		.wr_en 	(fifo_wr_en	),
		.din    (fifo_din	),
		
		// Read I/F.
		.rd_en 	(fifo_rd_en	),
		.dout  	(fifo_dout	),
		
		// Flags.
		.full   (fifo_full	),
		.empty  (fifo_empty	)
	);

// Fifo connections.
assign fifo_wr_en	= s0_axis_tvalid;
assign fifo_din		= s0_axis_tdata;

// Down-conversion + Decimation FIR.
down_conversion_fir 
	down_conversion_fir_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// Fifo interface.
		.fifo_rd_en		(fifo_rd_en		),
		.fifo_empty		(fifo_empty		),
		.fifo_dout		(fifo_dout		),

    	// s_axis for input data (N samples per clock).
		.s_axis_tready	(s1_axis_tready	),
		.s_axis_tvalid	(s1_axis_tvalid	),
		.s_axis_tdata	(s1_axis_tdata	),

		// m_axis for output data.
		.m_axis_tready	(m_axis_tready	),
		.m_axis_tvalid	(m_axis_tvalid	),
		.m_axis_tdata	(m_axis_tdata	)
	);

// Assign outputs.
assign s0_axis_tready	= ~fifo_full;

endmodule

