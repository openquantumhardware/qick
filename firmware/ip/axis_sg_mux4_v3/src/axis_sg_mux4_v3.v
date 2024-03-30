// Signal Generator V4.
// s_axi_aclk	: clock for s_axi_*
// aclk			: clock for s_axis_* and m_axis_*
//
module axis_sg_mux4_v3
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

		// s_* and m_* reset/clock.
		aclk			,
		aresetn			,

    	// S_AXIS to queue waveforms.
		s_axis_tready	,
		s_axis_tvalid	,
		s_axis_tdata	,

		// AXIS Master for output.
		m_axis_tready	,
		m_axis_tvalid	,
		m_axis_tdata
	);

/**************/
/* Parameters */
/**************/
// Number of parallel dds blocks.
parameter [31:0] N_DDS = 2;

/*********/
/* Ports */
/*********/
input					s_axi_aclk;
input					s_axi_aresetn;

input	[5:0]			s_axi_awaddr;
input	[2:0]			s_axi_awprot;
input					s_axi_awvalid;
output					s_axi_awready;

input	[31:0]			s_axi_wdata;
input	[3:0]			s_axi_wstrb;
input					s_axi_wvalid;
output					s_axi_wready;

output	[1:0]			s_axi_bresp;
output					s_axi_bvalid;
input					s_axi_bready;

input	[5:0]			s_axi_araddr;
input	[2:0]			s_axi_arprot;
input					s_axi_arvalid;
output					s_axi_arready;

output	[31:0]			s_axi_rdata;
output	[1:0]			s_axi_rresp;
output					s_axi_rvalid;
input					s_axi_rready;

input					aresetn;
input					aclk;

output					s_axis_tready;
input					s_axis_tvalid;
input 	[39:0]			s_axis_tdata;

input					m_axis_tready;
output					m_axis_tvalid;
output	[N_DDS*16-1:0]	m_axis_tdata;

/********************/
/* Internal signals */
/********************/
// Registers.
wire [31:0] PINC0_REG;
wire [31:0] PINC1_REG;
wire [31:0] PINC2_REG;
wire [31:0] PINC3_REG;
wire [15:0] GAIN0_REG;
wire [15:0] GAIN1_REG;
wire [15:0] GAIN2_REG;
wire [15:0] GAIN3_REG;
wire 		WE_REG;

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
		.PINC0_REG		(PINC0_REG		),
		.PINC1_REG		(PINC1_REG		),
		.PINC2_REG		(PINC2_REG		),
		.PINC3_REG		(PINC3_REG		),
		.GAIN0_REG		(GAIN0_REG		),
		.GAIN1_REG		(GAIN1_REG		),
		.GAIN2_REG		(GAIN2_REG		),
		.GAIN3_REG		(GAIN3_REG		),
		.WE_REG			(WE_REG			)
	);

sg_mux4
	#(
		.N_DDS	(N_DDS	)
	)
	sg_mux4_i
	(
		// Reset and clock.
    	.aresetn			(aresetn		),
		.aclk				(aclk			),

    	// S_AXIS to queue waveforms.
		.s_axis_tready_o	(s_axis_tready	),
		.s_axis_tvalid_i	(s_axis_tvalid	),
		.s_axis_tdata_i		(s_axis_tdata 	),

		// M_AXIS for output.
		.m_axis_tready_i	(m_axis_tready	),
		.m_axis_tvalid_o	(m_axis_tvalid	),
		.m_axis_tdata_o		(m_axis_tdata	),

		// Registers.
		.PINC0_REG			(PINC0_REG		),
		.PINC1_REG			(PINC1_REG		),
		.PINC2_REG			(PINC2_REG		),
		.PINC3_REG			(PINC3_REG		),
		.GAIN0_REG			(GAIN0_REG		),
		.GAIN1_REG			(GAIN1_REG		),
		.GAIN2_REG			(GAIN2_REG		),
		.GAIN3_REG			(GAIN3_REG		),
		.WE_REG				(WE_REG			)
	);

endmodule

