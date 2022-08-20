module axis_pfb_readout_v2
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

    	// S_AXIS for input samples
		s_axis_tvalid	,
		s_axis_tready	,
		s_axis_tdata	,

		// M_AXIS for CH0 output.
		m0_axis_tvalid	,
		m0_axis_tdata	,

		// M_AXIS for CH1 output.
		m1_axis_tvalid	,
		m1_axis_tdata	,

		// M_AXIS for CH2 output.
		m2_axis_tvalid	,
		m2_axis_tdata	,

		// M_AXIS for CH3 output.
		m3_axis_tvalid	,
		m3_axis_tdata
	);

/**************/
/* Parameters */
/**************/
// Input is interleaved I+Q, compatible with quad ADC (if false, input is not interleaved - compatible with dual ADC + combiner) 
parameter INTERLEAVED_INPUT = 1;

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

input				s_axis_tvalid;
output				s_axis_tready;
input 	[4*32-1:0]	s_axis_tdata;

output				m0_axis_tvalid;
output	[31:0]		m0_axis_tdata;

output				m1_axis_tvalid;
output	[31:0]		m1_axis_tdata;

output				m2_axis_tvalid;
output	[31:0]		m2_axis_tdata;

output				m3_axis_tvalid;
output	[31:0]		m3_axis_tdata;

/********************/
/* Internal signals */
/********************/
// Registers.
wire	[31:0]	FREQ0_REG;
wire	[31:0]	FREQ1_REG;
wire	[31:0]	FREQ2_REG;
wire	[31:0]	FREQ3_REG;
wire	[31:0]	FREQ4_REG;
wire	[31:0]	FREQ5_REG;
wire	[31:0]	FREQ6_REG;
wire	[31:0]	FREQ7_REG;
wire	[1:0]	OUTSEL_REG;
wire	[2:0]	CH0SEL_REG;
wire	[2:0]	CH1SEL_REG;
wire	[2:0]	CH2SEL_REG;
wire	[2:0]	CH3SEL_REG;


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
		.FREQ0_REG		(FREQ0_REG		), 
		.FREQ1_REG		(FREQ1_REG		), 
		.FREQ2_REG		(FREQ2_REG		), 
		.FREQ3_REG		(FREQ3_REG		), 
		.FREQ4_REG		(FREQ4_REG		), 
		.FREQ5_REG		(FREQ5_REG		), 
		.FREQ6_REG		(FREQ6_REG		), 
		.FREQ7_REG		(FREQ7_REG		), 
		.OUTSEL_REG		(OUTSEL_REG		),
		.CH0SEL_REG		(CH0SEL_REG		),
		.CH1SEL_REG		(CH1SEL_REG 	),
		.CH2SEL_REG		(CH2SEL_REG 	),
		.CH3SEL_REG		(CH3SEL_REG 	)
	);

// PFB with DDS product.
pfb_dds_mux
	#(
		.INTERLEAVED_INPUT(INTERLEAVED_INPUT)
	)
	pfb_dds_mux_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tready	(s_axis_tready	),
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tdata	(s_axis_tdata	),

		// M_AXIS for CH0 output.
		.m0_axis_tvalid	(m0_axis_tvalid	),
		.m0_axis_tdata	(m0_axis_tdata	),

		// M_AXIS for CH1 output.
		.m1_axis_tvalid	(m1_axis_tvalid	),
		.m1_axis_tdata	(m1_axis_tdata	),

		// M_AXIS for CH2 output.
		.m2_axis_tvalid	(m2_axis_tvalid	),
		.m2_axis_tdata	(m2_axis_tdata	),

		// M_AXIS for CH3 output.
		.m3_axis_tvalid	(m3_axis_tvalid	),
		.m3_axis_tdata	(m3_axis_tdata	),

		// Registers.
		.FREQ0_REG		(FREQ0_REG		), 
		.FREQ1_REG		(FREQ1_REG		), 
		.FREQ2_REG		(FREQ2_REG		), 
		.FREQ3_REG		(FREQ3_REG		), 
		.FREQ4_REG		(FREQ4_REG		), 
		.FREQ5_REG		(FREQ5_REG		), 
		.FREQ6_REG		(FREQ6_REG		), 
		.FREQ7_REG		(FREQ7_REG		), 
		.OUTSEL_REG		(OUTSEL_REG		),
		.CH0SEL_REG		(CH0SEL_REG		),
		.CH1SEL_REG		(CH1SEL_REG 	),
		.CH2SEL_REG		(CH2SEL_REG 	),
		.CH3SEL_REG		(CH3SEL_REG 	)
	);

endmodule

