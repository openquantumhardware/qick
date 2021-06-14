// AXIS AVG BUFFER.
// s_axi_aclk	: clock for s_axi_*
// s_axis_aclk	: clock for s_axis_*
// m_axis_aclk	: clock for m0_axis_* and m1_axis_*
//
module axis_avg_buffer
	( 
		// AXI Slave I/F for configuration.
		s_axi_aclk			,
		s_axi_aresetn		,

		s_axi_awaddr		,
		s_axi_awprot		,
		s_axi_awvalid		,
		s_axi_awready		,

		s_axi_wdata			,
		s_axi_wstrb			,
		s_axi_wvalid		,
		s_axi_wready		,

		s_axi_bresp			,
		s_axi_bvalid		,
		s_axi_bready		,

		s_axi_araddr		,
		s_axi_arprot		,
		s_axi_arvalid		,
		s_axi_arready		,

		s_axi_rdata			,
		s_axi_rresp			,
		s_axi_rvalid		,
		s_axi_rready		,

		// Trigger input.
		trigger				,

		// AXIS Slave for input data.
		s_axis_aclk			,
		s_axis_aresetn		,
		s_axis_tvalid		,
		s_axis_tready		,
		s_axis_tdata		,

		// Reset and clock for m0 and m1.
		m_axis_aclk			,
		m_axis_aresetn		,

		// AXIS Master for averaged output.
		m0_axis_tvalid		,
		m0_axis_tready		,
		m0_axis_tdata		,
		m0_axis_tlast		,

		// AXIS Master for raw output.
		m1_axis_tvalid		,
		m1_axis_tready		,
		m1_axis_tdata		,
		m1_axis_tlast		,

		// AXIS Master for register output.
		m2_axis_tvalid		,
		m2_axis_tready		,
		m2_axis_tdata
	);

/**************/
/* Parameters */
/**************/
// Memory depth.
parameter N_AVG = 10;
parameter N_BUF = 10;

// Number of bits.
parameter B = 16;

/*********/
/* Ports */
/*********/
input				s_axi_aclk;
input				s_axi_aresetn;

input		[5:0]	s_axi_awaddr;
input		[2:0]	s_axi_awprot;
input				s_axi_awvalid;
output				s_axi_awready;

input		[31:0]	s_axi_wdata;
input		[3:0]	s_axi_wstrb;
input				s_axi_wvalid;
output				s_axi_wready;

output		[1:0]	s_axi_bresp;
output				s_axi_bvalid;
input				s_axi_bready;

input		[5:0]	s_axi_araddr;
input		[2:0]	s_axi_arprot;
input				s_axi_arvalid;
output				s_axi_arready;

output		[31:0]	s_axi_rdata;
output		[1:0]	s_axi_rresp;
output				s_axi_rvalid;
input				s_axi_rready;

input				trigger;

input				s_axis_aclk;
input				s_axis_aresetn;
input				s_axis_tvalid;
output				s_axis_tready;
input	[2*B-1:0]	s_axis_tdata;

input				m_axis_aclk;
input				m_axis_aresetn;

output				m0_axis_tvalid;
input				m0_axis_tready;
output	[4*B-1:0]	m0_axis_tdata;
output				m0_axis_tlast;

output				m1_axis_tvalid;
input				m1_axis_tready;
output	[2*B-1:0]	m1_axis_tdata;
output				m1_axis_tlast;

output				m2_axis_tvalid;
input				m2_axis_tready;
output	[4*B-1:0]	m2_axis_tdata;


/********************/
/* Internal signals */
/********************/
// Registers.
wire				AVG_START_REG;
wire	[N_AVG-1:0]	AVG_ADDR_REG;
wire	[31:0]		AVG_LEN_REG;
wire				AVG_DR_START_REG;
wire	[N_AVG-1:0]	AVG_DR_ADDR_REG;
wire	[N_AVG-1:0]	AVG_DR_LEN_REG;
wire				BUF_START_REG;
wire	[N_BUF-1:0]	BUF_ADDR_REG;
wire	[N_BUF-1:0]	BUF_LEN_REG;
wire				BUF_DR_START_REG;
wire	[N_BUF-1:0]	BUF_DR_ADDR_REG;
wire	[N_BUF-1:0]	BUF_DR_LEN_REG;


/**********************/
/* Begin Architecture */
/**********************/
// AXI Slave.
axi_slv axi_slv_i
	(
		.aclk				(s_axi_aclk	 		),
		.aresetn			(s_axi_aresetn		),

		// Write Address Channel.
		.awaddr				(s_axi_awaddr 		),
		.awprot				(s_axi_awprot 		),
		.awvalid			(s_axi_awvalid		),
		.awready			(s_axi_awready		),

		// Write Data Channel.
		.wdata				(s_axi_wdata		),
		.wstrb				(s_axi_wstrb		),
		.wvalid				(s_axi_wvalid   	),
		.wready				(s_axi_wready		),

		// Write Response Channel.
		.bresp				(s_axi_bresp		),
		.bvalid				(s_axi_bvalid		),
		.bready				(s_axi_bready		),

		// Read Address Channel.
		.araddr				(s_axi_araddr 		),
		.arprot				(s_axi_arprot 		),
		.arvalid			(s_axi_arvalid		),
		.arready			(s_axi_arready		),

		// Read Data Channel.
		.rdata				(s_axi_rdata		),
		.rresp				(s_axi_rresp		),
		.rvalid				(s_axi_rvalid		),
		.rready				(s_axi_rready		),

		// Registers.
		.AVG_START_REG		(AVG_START_REG		),
		.AVG_ADDR_REG		(AVG_ADDR_REG		),
		.AVG_LEN_REG		(AVG_LEN_REG		),
		.AVG_DR_START_REG	(AVG_DR_START_REG	),
		.AVG_DR_ADDR_REG	(AVG_DR_ADDR_REG	),
		.AVG_DR_LEN_REG		(AVG_DR_LEN_REG		),
		.BUF_START_REG		(BUF_START_REG		),
		.BUF_ADDR_REG		(BUF_ADDR_REG		),
		.BUF_LEN_REG		(BUF_LEN_REG		),
		.BUF_DR_START_REG	(BUF_DR_START_REG	),
		.BUF_DR_ADDR_REG	(BUF_DR_ADDR_REG	),
		.BUF_DR_LEN_REG		(BUF_DR_LEN_REG		)
	);

// Averager + Buffer Top.
avg_buffer
	#(
		.N_AVG	(N_AVG	),
		.N_BUF	(N_BUF	),
		.B		(B		)
	)
	avg_buffer_i
	(
		// Reset and clock for s.
		.s_axis_aclk		(s_axis_aclk		),
		.s_axis_aresetn		(s_axis_aresetn		),

		// Trigger input.
		.trigger			(trigger			),

		// AXIS Slave for input data.
		.s_axis_tvalid		(s_axis_tvalid		),
		.s_axis_tready		(s_axis_tready		),
		.s_axis_tdata		(s_axis_tdata		),

		// Reset and clock for m0 and m1.
		.m_axis_aclk		(m_axis_aclk   		),
		.m_axis_aresetn		(m_axis_aresetn		),

		// AXIS Master for averaged output.
		.m0_axis_tvalid		(m0_axis_tvalid		),
		.m0_axis_tready		(m0_axis_tready		),
		.m0_axis_tdata		(m0_axis_tdata		),
		.m0_axis_tlast		(m0_axis_tlast		),

		// AXIS Master for raw output.
		.m1_axis_tvalid		(m1_axis_tvalid		),
		.m1_axis_tready		(m1_axis_tready		),
		.m1_axis_tdata		(m1_axis_tdata		),
		.m1_axis_tlast		(m1_axis_tlast		),

		// AXIS Master for register output.
		.m2_axis_tvalid		(m2_axis_tvalid		),
		.m2_axis_tready		(m2_axis_tready		),
		.m2_axis_tdata		(m2_axis_tdata		),

		// Registers.
		.AVG_START_REG		(AVG_START_REG		),
		.AVG_ADDR_REG		(AVG_ADDR_REG		),
		.AVG_LEN_REG		(AVG_LEN_REG		),
		.AVG_DR_START_REG	(AVG_DR_START_REG	),
		.AVG_DR_ADDR_REG	(AVG_DR_ADDR_REG	),
		.AVG_DR_LEN_REG		(AVG_DR_LEN_REG		),
		.BUF_START_REG		(BUF_START_REG		),
		.BUF_ADDR_REG		(BUF_ADDR_REG		),
		.BUF_LEN_REG		(BUF_LEN_REG		),
		.BUF_DR_START_REG	(BUF_DR_START_REG	),
		.BUF_DR_ADDR_REG	(BUF_DR_ADDR_REG	),
		.BUF_DR_LEN_REG		(BUF_DR_LEN_REG		)
	);

endmodule

