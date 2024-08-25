// Signal Generator V4.
// s_axi_aclk	: clock for s_axi_*
// s0_axis_aclk	: clock for s0_axis_*
// aclk			: clock for s1_axis_* and m_axis_*
//
module axis_sg_int4_v2
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

    	// AXIS Slave to load memory samples.
		s0_axis_aclk	,
		s0_axis_aresetn	,
		s0_axis_tdata	,
		s0_axis_tvalid	,
		s0_axis_tready	,

		// s1_* and m_* reset/clock.
		aclk			,
		aresetn			,

    	// AXIS Slave to queue waveforms.
		s1_axis_tdata	,
		s1_axis_tvalid	,
		s1_axis_tready	,

		// AXIS Master for output.
		m_axis_tready	,
		m_axis_tvalid	,
		m_axis_tdata
	);

/**************/
/* Parameters */
/**************/
parameter N		= 12;

// Number of parallel dds blocks.
localparam [31:0] N_DDS = 4;

/*********/
/* Ports */
/*********/
input				s_axi_aclk;
input				s_axi_aresetn;

input	[5:0]		s_axi_awaddr;
input	[2:0]		s_axi_awprot;
input				s_axi_awvalid;
output				s_axi_awready;

input	[31:0]		s_axi_wdata;
input	[3:0]		s_axi_wstrb;
input				s_axi_wvalid;
output				s_axi_wready;

output	[1:0]		s_axi_bresp;
output				s_axi_bvalid;
input				s_axi_bready;

input	[5:0]		s_axi_araddr;
input	[2:0]		s_axi_arprot;
input				s_axi_arvalid;
output				s_axi_arready;

output	[31:0]		s_axi_rdata;
output	[1:0]		s_axi_rresp;
output				s_axi_rvalid;
input				s_axi_rready;

input				s0_axis_aclk;
input				s0_axis_aresetn;
input 	[31:0]		s0_axis_tdata;
input				s0_axis_tvalid;
output				s0_axis_tready;

input				aresetn;
input				aclk;

input 	[159:0]		s1_axis_tdata;
input				s1_axis_tvalid;
output				s1_axis_tready;

input				m_axis_tready;
output				m_axis_tvalid;
output	[4*32-1:0]	m_axis_tdata;

/********************/
/* Internal signals */
/********************/
// Registers.
wire	[31:0]			START_ADDR_REG;
wire					WE_REG;

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
		.START_ADDR_REG	(START_ADDR_REG	),
		.WE_REG			(WE_REG	 		)
	);

signal_gen_top
	#(
		.N		(N		),
		.N_DDS	(N_DDS	)
	)
	signal_gen_top_i
	(
		// Reset and clock.
    	.aresetn			(aresetn			),
		.aclk				(aclk				),

    	// AXIS Slave to load memory samples.
    	.s0_axis_aresetn	(s0_axis_aresetn	),
		.s0_axis_aclk		(s0_axis_aclk		),
		.s0_axis_tdata_i	(s0_axis_tdata		),
		.s0_axis_tvalid_i	(s0_axis_tvalid		),
		.s0_axis_tready_o	(s0_axis_tready		),

    	// AXIS Slave to queue waveforms.
		.s1_axis_tdata_i	(s1_axis_tdata 		),
		.s1_axis_tvalid_i	(s1_axis_tvalid		),
		.s1_axis_tready_o	(s1_axis_tready		),

		// M_AXIS for output.
		.m_axis_tready_i	(m_axis_tready		),
		.m_axis_tvalid_o	(m_axis_tvalid		),
		.m_axis_tdata_o		(m_axis_tdata		),

		// Registers.
		.START_ADDR_REG		(START_ADDR_REG		),
		.WE_REG				(WE_REG				)
	);

endmodule

