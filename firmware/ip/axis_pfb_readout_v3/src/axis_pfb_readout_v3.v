module axis_pfb_readout_v3
	#(
		// Number of channels.
		parameter N = 64
	)
	( 
		// AXI Slave I/F for configuration.
		input				s_axi_aclk		,
		input				s_axi_aresetn	,
		
		input	[5:0]		s_axi_awaddr	,
		input	[2:0]		s_axi_awprot	,
		input				s_axi_awvalid	,
		output				s_axi_awready	,
		
		input	[31:0]		s_axi_wdata		,
		input	[3:0]		s_axi_wstrb		,
		input				s_axi_wvalid	,
		output				s_axi_wready	,
		
		output	[1:0]		s_axi_bresp		,
		output				s_axi_bvalid	,
		input				s_axi_bready	,
		
		input	[5:0]		s_axi_araddr	,
		input	[2:0]		s_axi_arprot	,
		input				s_axi_arvalid	,
		output				s_axi_arready	,
		
		output	[31:0]		s_axi_rdata		,
		output	[1:0]		s_axi_rresp		,
		output				s_axi_rvalid	,
		input				s_axi_rready	,

		// s_* and m_* reset/clock.
		input				aresetn			,
		input				aclk			,

    	// S_AXIS for input samples
		input				s_axis_tvalid	,
		input 	[4*32-1:0]	s_axis_tdata	,

		// M_AXIS for CH0 output.
		output				m0_axis_tvalid	,
		output	[31:0]		m0_axis_tdata	,

		// M_AXIS for CH1 output.
		output				m1_axis_tvalid	,
		output	[31:0]		m1_axis_tdata	,

		// M_AXIS for CH2 output.
		output				m2_axis_tvalid	,
		output	[31:0]		m2_axis_tdata	,

		// M_AXIS for CH3 output.
		output				m3_axis_tvalid	,
		output	[31:0]		m3_axis_tdata
	);

/********************/
/* Internal signals */
/********************/
// Registers.
wire	[15:0]		ID0_REG			;
wire	[15:0]		ID1_REG			;
wire	[15:0]		ID2_REG			;
wire	[15:0]		ID3_REG			;
wire	[31:0]		PINC0_REG		;
wire	[31:0]		POFF0_REG		;
wire	[31:0]		PINC1_REG		;
wire	[31:0]		POFF1_REG		;
wire	[31:0]		PINC2_REG		;
wire	[31:0]		POFF2_REG		;
wire	[31:0]		PINC3_REG		;
wire	[31:0]		POFF3_REG		;

// Internal valid.
wire				valid_int		;

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
		.ID0_REG		(ID0_REG		),
		.ID1_REG		(ID1_REG		),
		.ID2_REG		(ID2_REG		),
		.ID3_REG		(ID3_REG		),
		.PINC0_REG		(PINC0_REG		),
		.POFF0_REG		(POFF0_REG		),
		.PINC1_REG		(PINC1_REG		),
		.POFF1_REG		(POFF1_REG		),
		.PINC2_REG		(PINC2_REG		),
		.POFF2_REG		(POFF2_REG		),
		.PINC3_REG		(PINC3_REG		),
		.POFF3_REG		(POFF3_REG		)
	);

// PFB with DDS product.
pfb_readout
	#(
		// Number of channels.
		.N(N),
		
		// Number of Lanes (Input).
		.L(4)
	)
	pfb_readout_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tdata	(s_axis_tdata	),

		// M_AXIS for output data.
		.m_axis_tvalid	(valid_int		),
		.m0_axis_tdata	(m0_axis_tdata	),
		.m1_axis_tdata	(m1_axis_tdata	),
		.m2_axis_tdata	(m2_axis_tdata	),
		.m3_axis_tdata	(m3_axis_tdata	),

		// Registers.
		.ID0_REG		(ID0_REG		),
		.ID1_REG		(ID1_REG		),
		.ID2_REG		(ID2_REG		),
		.ID3_REG		(ID3_REG		),
		.PINC0_REG		(PINC0_REG		),
		.POFF0_REG		(POFF0_REG		),
		.PINC1_REG		(PINC1_REG		),
		.POFF1_REG		(POFF1_REG		),
		.PINC2_REG		(PINC2_REG		),
		.POFF2_REG		(POFF2_REG		),
		.PINC3_REG		(PINC3_REG		),
		.POFF3_REG		(POFF3_REG		)
	);

// Assign outputs.
assign m0_axis_tvalid = valid_int;
assign m1_axis_tvalid = valid_int;
assign m2_axis_tvalid = valid_int;
assign m3_axis_tvalid = valid_int;

endmodule

