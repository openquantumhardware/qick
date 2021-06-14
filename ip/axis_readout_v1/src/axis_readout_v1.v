// Readout V1.
// s_axi_aclk	: clock for s_axi_*
// aclk			: clock for s0_axis_*, s1_axis_*, and m0_axis_* and m1_axis_*
//
module axis_readout_v1
	( 
		// AXI Slave I/F for configuration.
		s_axi_aclk		,
		s_axi_aresetn	,

		s_axi_awaddr	,
		s_axi_awprot	,
		s_axi_awvalid	,
		s_axi_awready	,

		s_axi_wdata		,
		s_axi_wstrb		,
		s_axi_wvalid	,
		s_axi_wready	,

		s_axi_bresp		,
		s_axi_bvalid	,
		s_axi_bready	,

		s_axi_araddr	,
		s_axi_arprot	,
		s_axi_arvalid	,
		s_axi_arready	,

		s_axi_rdata		,
		s_axi_rresp		,
		s_axi_rvalid	,
		s_axi_rready	,

		// Reset and clock (s_axis, m0_axis, m1_axis).
    	aresetn			,
		aclk			,

    	// S_AXIS: for input data (8x samples per clock).
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
	);

/**************/
/* Parameters */
/**************/
// Number of parallel dds blocks.
localparam [15:0] N_DDS = 8;

/*********/
/* Ports */
/*********/
input						s_axi_aclk;
input						s_axi_aresetn;

input		[5:0]			s_axi_awaddr;
input		[2:0]			s_axi_awprot;
input						s_axi_awvalid;
output						s_axi_awready;

input		[31:0]			s_axi_wdata;
input		[3:0]			s_axi_wstrb;
input						s_axi_wvalid;
output						s_axi_wready;

output		[1:0]			s_axi_bresp;
output						s_axi_bvalid;
input						s_axi_bready;

input		[5:0]			s_axi_araddr;
input		[2:0]			s_axi_arprot;
input						s_axi_arvalid;
output						s_axi_arready;

output		[31:0]			s_axi_rdata;
output		[1:0]			s_axi_rresp;
output						s_axi_rvalid;
input						s_axi_rready;

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

/********************/
/* Internal signals */
/********************/
// Registers.
wire	[1:0]				OUTSEL_REG;
wire	[15:0]				DDS_FREQ_REG;


/**********************/
/* Begin Architecture */
/**********************/
// AXI Slave.
axi_slv axi_slv_i
	(
		.aclk			(s_axi_aclk	 	),
		.aresetn		(s_axi_aresetn	),

		// Write Address Channel.
		.awaddr			(s_axi_awaddr 	),
		.awprot			(s_axi_awprot 	),
		.awvalid		(s_axi_awvalid	),
		.awready		(s_axi_awready	),

		// Write Data Channel.
		.wdata			(s_axi_wdata	),
		.wstrb			(s_axi_wstrb	),
		.wvalid			(s_axi_wvalid   ),
		.wready			(s_axi_wready	),

		// Write Response Channel.
		.bresp			(s_axi_bresp	),
		.bvalid			(s_axi_bvalid	),
		.bready			(s_axi_bready	),

		// Read Address Channel.
		.araddr			(s_axi_araddr 	),
		.arprot			(s_axi_arprot 	),
		.arvalid		(s_axi_arvalid	),
		.arready		(s_axi_arready	),

		// Read Data Channel.
		.rdata			(s_axi_rdata	),
		.rresp			(s_axi_rresp	),
		.rvalid			(s_axi_rvalid	),
		.rready			(s_axi_rready	),

		// Registers.
		.OUTSEL_REG		(OUTSEL_REG		),
		.DDS_FREQ_REG	(DDS_FREQ_REG	)
	);

// Readout Top.
readout_top readout_top_i
	(
		// Reset and clock (s0_axis, s1_axis, m0_axis, m1_axis).
    	.aresetn			(aresetn			),
		.aclk				(aclk				),

    	// S_AXIS: for input data (8x samples per clock).
		.s_axis_tdata		(s_axis_tdata 		),
		.s_axis_tvalid		(s_axis_tvalid		),
		.s_axis_tready		(s_axis_tready		),

		// M0_AXIS: for output data (before filter and decimation, 8x samples
		// per clock).
		.m0_axis_tready		(m0_axis_tready		),
		.m0_axis_tvalid		(m0_axis_tvalid		),
		.m0_axis_tdata		(m0_axis_tdata		),

		// M1_AXIS: for output data.
		.m1_axis_tready		(m1_axis_tready		),
		.m1_axis_tvalid		(m1_axis_tvalid		),
		.m1_axis_tdata		(m1_axis_tdata		),

		// Registers.
		.OUTSEL_REG			(OUTSEL_REG			),
		.DDS_FREQ_REG		(DDS_FREQ_REG		)
	);

endmodule

