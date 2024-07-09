module readout_top 
	(
		// Reset and clock.
    	aresetn			,
		aclk			,

       // Fifo interface.
        fifo_wr_en      ,
        fifo_full       ,
        fifo_din        ,

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
		m1_axis_tdata

		// Registers.
//		FREQ_REG		,
//		PHASE_REG		,
//		NSAMP_REG		,
//		OUTSEL_REG		,
//		MODE_REG		,
//		WE_REG
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

input                       fifo_wr_en;
output                      fifo_full;
input       [87:0]          fifo_din;

output						s_axis_tready;
input						s_axis_tvalid;
input		[N_DDS*16-1:0]	s_axis_tdata;

input						m0_axis_tready;
output						m0_axis_tvalid;
output		[N_DDS*32-1:0]	m0_axis_tdata;

input						m1_axis_tready;
output						m1_axis_tvalid;
output		[32-1:0]		m1_axis_tdata;

//input		[31:0]			FREQ_REG;
//input		[31:0]			PHASE_REG;
//input		[15:0]			NSAMP_REG;
//input		[1:0]			OUTSEL_REG;
//input						MODE_REG;
//input						WE_REG;

/********************/
/* Internal signals */
/********************/
//wire			we;
//reg				we_r;

wire			fifo_wr_en;
wire	[87:0]	fifo_din;
wire			fifo_rd_en;
wire	[87:0]	fifo_dout;
wire			fifo_full;
wire			fifo_empty;

/**********************/
/* Begin Architecture */
/**********************/

// WE_REG sync.
//synchronizer_n
//	WE_REG_resync_i 
//	(
//		.rstn	    (aresetn	),
//		.clk 		(aclk		),
//		.data_in	(WE_REG		),
//		.data_out	(we			)
//	);

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

		// Fifo interface.
		.fifo_rd_en_o		(fifo_rd_en		),
		.fifo_empty_i		(fifo_empty		),
		.fifo_dout_i		(fifo_dout		)
		);

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
//assign fifo_wr_en	= we & ~we_r;
//assign fifo_din		= {MODE_REG,OUTSEL_REG,NSAMP_REG,PHASE_REG,FREQ_REG};

//always @(posedge aclk) begin
//	if (~aresetn)
//		we_r <= 0;	
//	else
//		we_r <= we;
//end

endmodule

