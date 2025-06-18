// Description:
// AVG_BUFFER is a block that receives an input stream of samples (s_axis) and generates three output streams, one with processed averaged data (m0_axis) and one with raw captured data (m1_axis) and one with averaged data but prior to be stored in internal memory (sent to tProc register) (m2_axis) Captured samples are internally stored in PL memory. 
// Capture is configured and controlled with Registers and is initiated by an external trigger after the buffer has been enabled. Number of captured samples and address where to store them are configurable.
// Output stream generation is configured and controlled with Registers where the address to start reading data and the number of samples can be configured. Output stream can be interfaced to an AXIS-DMA module
// 
// Parameters:
// N_AVG & N_BUF: memory depth as 2**N; B: memory data width
//
// Data is I,Q.
// I: lower B bits.
// Q: upper B bits.
module avg_buffer (
	// Reset and clock for s_axis
	s_axis_aclk			,
	s_axis_aresetn		,

	// Trigger input.
	trigger				,

	// AXIS Slave for input data.
	s_axis_tvalid		,
	s_axis_tready		,
	s_axis_tdata		,

	// Reset and clock for m0_axis, m1_axis and m2_axis.
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
	m2_axis_tdata		,

	// Registers.
	AVG_START_REG		,
	AVG_ADDR_REG		,
	AVG_LEN_REG			,
	AVG_PHOTON_MODE_REG ,
	AVG_H_THRSH_REG     ,
	AVG_L_THRSH_REG     ,
	AVG_DR_START_REG	,
	AVG_DR_ADDR_REG		,
	AVG_DR_LEN_REG		,
	BUF_START_REG		,
	BUF_ADDR_REG		,
	BUF_LEN_REG			,
	BUF_DR_START_REG	,
	BUF_DR_ADDR_REG		,
	BUF_DR_LEN_REG
	);

////////////////
// Parameters //
////////////////
// Memory depth.
parameter N_AVG = 10;
parameter N_BUF = 10;

// Number of bits.
parameter B = 16;

///////////
// Ports //
///////////
input				s_axis_aclk;
input				s_axis_aresetn;

input				trigger;

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

input				AVG_START_REG;
input	[N_AVG-1:0]	AVG_ADDR_REG;
input	[31:0]		AVG_LEN_REG;
input               AVG_PHOTON_MODE_REG;
input   [B-1:0]     AVG_H_THRSH_REG;
input   [B-1:0]     AVG_L_THRSH_REG;
input				AVG_DR_START_REG;
input	[N_AVG-1:0]	AVG_DR_ADDR_REG;
input	[N_AVG-1:0]	AVG_DR_LEN_REG;
input				BUF_START_REG;
input	[N_BUF-1:0]	BUF_ADDR_REG;
input	[N_BUF-1:0]	BUF_LEN_REG;
input				BUF_DR_START_REG;
input	[N_BUF-1:0]	BUF_DR_ADDR_REG;
input	[N_BUF-1:0]	BUF_DR_LEN_REG;

//////////////////////
// Internal signals //
//////////////////////

wire trigger_resync;

//////////////////
// Architecture //
//////////////////

// trigger_resync
synchronizer_n
	#(
		.N	(2)
	)
	trigger_resync_i (
		.rstn	    (s_axis_aresetn	),
		.clk 		(s_axis_aclk	),
		.data_in	(trigger		),
		.data_out	(trigger_resync	)
	);

// Average block.
avg_top 
	#(
		.N	(N_AVG	),
		.B	(B		)
	)
	avg_top_i
	(
		// Reset and clock.
		.rstn			(s_axis_aresetn		),
		.clk			(s_axis_aclk		),

		// Trigger input.
		.trigger_i		(trigger_resync		),

		// Data input.
		.din_valid_i	(s_axis_tvalid		),
		.din_i			(s_axis_tdata		),

		// Reset and clock for M_AXIS_*
		.m_axis_aclk	(m_axis_aclk		),
		.m_axis_aresetn	(m_axis_aresetn		),

		// AXIS Master for output.
		.m0_axis_tvalid	(m0_axis_tvalid		),
		.m0_axis_tready	(m0_axis_tready		),
		.m0_axis_tdata	(m0_axis_tdata		),
		.m0_axis_tlast	(m0_axis_tlast		),

		// AXIS Master for register output.
		.m1_axis_tvalid	(m2_axis_tvalid		),
		.m1_axis_tready	(m2_axis_tready		),
		.m1_axis_tdata	(m2_axis_tdata		),
		
		// Registers.
		.AVG_START_REG	(AVG_START_REG		),
		.AVG_ADDR_REG	(AVG_ADDR_REG		),
		.AVG_LEN_REG	(AVG_LEN_REG		),
		.DR_START_REG	(AVG_DR_START_REG	),
		.DR_ADDR_REG	(AVG_DR_ADDR_REG	),
		.DR_LEN_REG		(AVG_DR_LEN_REG		),
		.AVG_PHOTON_MODE_REG (AVG_PHOTON_MODE_REG),
		.AVG_H_THRSH_REG (AVG_H_THRSH_REG   ),
		.AVG_L_THRSH_REG (AVG_L_THRSH_REG   )
	);

// Buffer block.
buffer_top 
	#(
		.N	(N_BUF	),
		.B	(B		)
	)
	buffer_top_i
	(
		// Reset and clock.
		.rstn			(s_axis_aresetn		),
		.clk			(s_axis_aclk		),

		// Trigger input.
		.trigger_i		(trigger_resync		),

		// Data input.
		.din_valid_i	(s_axis_tvalid		),
		.din_i			(s_axis_tdata		),

		// AXIS Master for output.
		.m_axis_aclk	(m_axis_aclk		),
		.m_axis_aresetn	(m_axis_aresetn		),
		.m_axis_tvalid	(m1_axis_tvalid		),
		.m_axis_tready	(m1_axis_tready		),
		.m_axis_tdata	(m1_axis_tdata		),
		.m_axis_tlast	(m1_axis_tlast		),

		// Registers.
		.BUF_START_REG	(BUF_START_REG		),
		.BUF_ADDR_REG	(BUF_ADDR_REG		),
		.BUF_LEN_REG	(BUF_LEN_REG		),
		.DR_START_REG	(BUF_DR_START_REG	),
		.DR_ADDR_REG	(BUF_DR_ADDR_REG	),
		.DR_LEN_REG		(BUF_DR_LEN_REG		)
	);

// Assign outputs.
assign s_axis_tready	= 1'b1;

endmodule

