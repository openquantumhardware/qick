// Polyphase Filter Bank, 4 lanes, 256 channels, 50 % overlap.
// This block has FIR coefficients that are good for cascading
// with the Synthesis PFB only.
// s_axi_aclk	: clock for s_axi_*
// aclk			: clock for s_axis_* and m_axis_*
module axis_pfba_pr_4x256_v1
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
		aresetn			,
		aclk			,

    	// S_AXIS for data input.
		s_axis_tready	,
		s_axis_tvalid	,
		s_axis_tdata	,

		// M_AXIS for data output.
		m_axis_tvalid	,
		m_axis_tlast	,
		m_axis_tdata
	);
	
parameter N = 256;

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

input				aresetn;
input				aclk;

output				s_axis_tready;
input				s_axis_tvalid;
input 	[4*32-1:0]	s_axis_tdata;

output				m_axis_tvalid;
output				m_axis_tlast;
output	[8*32-1:0]	m_axis_tdata;

/********************/
/* Internal signals */
/********************/
// Registers.
wire	[31:0]	QOUT_REG;

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
		.QOUT_REG		(QOUT_REG		)
	);

// PFB Block.
pfb
	#(
		.N	(256),
		.L	(4	)
	)
	pfb_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tready	(s_axis_tready	),
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tdata	(s_axis_tdata	),

		// M_AXIS for output data.
		.m_axis_tvalid	(m_axis_tvalid	),
		.m_axis_tlast	(m_axis_tlast	),
		.m_axis_tdata	(m_axis_tdata	),

		// Registers.
		.QOUT_REG		(QOUT_REG		)
	);

endmodule

