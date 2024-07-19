module axis_dyn_readout_v1
	( 

		// Reset and clock (s_axis, m0_axis, m1_axis).
    	aresetn			,
		aclk			,

        // s0_axis: for pushing configurations.
        s0_axis_tready  ,
        s0_axis_tvalid  ,
        s0_axis_tdata   ,

    	// s0_axis: for input data (8x samples per clock).
		s1_axis_tdata	,
		s1_axis_tvalid	,
		s1_axis_tready	,

		// M0_AXIS: for output data (before filter and decimation, 8x samples
		// per clock).
		m0_axis_tready	,
		m0_axis_tvalid	,
		m0_axis_tdata	,

		// M1_AXIS: for output data.
		m1_axis_tready	,
		m1_axis_tvalid	,
		m1_axis_tdata
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

output                      s0_axis_tready;
input                       s0_axis_tvalid;
input       [87:0]          s0_axis_tdata;

output						s1_axis_tready;
input						s1_axis_tvalid;
input		[N_DDS*16-1:0]	s1_axis_tdata;

input						m0_axis_tready;
output						m0_axis_tvalid;
output		[N_DDS*32-1:0]	m0_axis_tdata;

input						m1_axis_tready;
output						m1_axis_tvalid;
output		[32-1:0]		m1_axis_tdata;

/********************/
/* Internal signals */
/********************/

// Fifo.
wire            fifo_wr_en  ;
wire    [87:0]  fifo_din    ;
wire            fifo_full   ;

// Fifo connections.
assign fifo_wr_en   = s0_axis_tvalid;
assign fifo_din     = s0_axis_tdata;

// Readout Top.
readout_top readout_top_i
	(
		// Reset and clock (s0_axis, s1_axis, m0_axis, m1_axis).
    	.aresetn		(aresetn		),
		.aclk			(aclk			),

        // Fifo interface.
        .fifo_wr_en     (fifo_wr_en     ),
        .fifo_full      (fifo_full      ),
        .fifo_din       (fifo_din       ),

    	// S_AXIS: for input data (8x samples per clock).
		.s_axis_tdata	(s1_axis_tdata 	),
		.s_axis_tvalid	(s1_axis_tvalid	),
		.s_axis_tready	(s1_axis_tready	),

		// M0_AXIS: for output data (before filter and decimation, 8x samples
		// per clock).
		.m0_axis_tready	(m0_axis_tready	),
		.m0_axis_tvalid	(m0_axis_tvalid	),
		.m0_axis_tdata	(m0_axis_tdata	),

		// M1_AXIS: for output data.
		.m1_axis_tready	(m1_axis_tready	),
		.m1_axis_tvalid	(m1_axis_tvalid	),
		.m1_axis_tdata	(m1_axis_tdata	)
	);

// Assign outputs.
assign s0_axis_tready   = ~fifo_full;

endmodule

