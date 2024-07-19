// Synthesis Polyphase Filter Bank, 4 lanes, 256 channels, 50 % overlap.
// This IP is good for cascading with the Analysis PFB only.
// s_axi_aclk	: clock for s_axi_*
// aclk			: clock for s_axis_* and m_axis_*
module axis_pfbs_pr_4x256_v1
	( 
		// AXI Slave I/F for configuration.
		input wire				s_axi_aclk		,
		input wire				s_axi_aresetn	,
		
		input wire [5:0]		s_axi_awaddr	,
		input wire [2:0]		s_axi_awprot	,
		input wire				s_axi_awvalid	,
		output wire				s_axi_awready	,
		
		input wire [31:0]		s_axi_wdata		,
		input wire [3:0]		s_axi_wstrb		,
		input wire				s_axi_wvalid	,
		output wire				s_axi_wready	,
		
		output wire	[1:0]		s_axi_bresp		,
		output wire				s_axi_bvalid	,
		input wire				s_axi_bready	,
		
		input wire [5:0]		s_axi_araddr	,
		input wire [2:0]		s_axi_arprot	,
		input wire				s_axi_arvalid	,
		output wire				s_axi_arready	,
		
		output wire [31:0]		s_axi_rdata		,
		output wire [1:0]		s_axi_rresp		,
		output wire 			s_axi_rvalid	,
		input wire				s_axi_rready	,

		// s_* and m_* reset/clock.
		input wire 				aresetn			,
		input wire 				aclk			,

    	// S_AXIS for data input.
		input wire [8*32-1:0]	s_axis_tdata	,
		input wire				s_axis_tlast	,
		input wire				s_axis_tvalid	,
		output wire				s_axis_tready	,

		// M_AXIS for data output.
		output wire	[4*32-1:0]	m_axis_tdata	,
		output wire				m_axis_tvalid
	);
	
parameter N = 256;

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
		.aresetn		,
		.aclk			,

		// S_AXIS for input data.
		.s_axis_tdata	,
		.s_axis_tlast	,
		.s_axis_tvalid	,
		.s_axis_tready	,

		// M_AXIS for output data.
		.m_axis_tdata	,
		.m_axis_tvalid	,

		// Registers.
		.QOUT_REG
	);

endmodule

