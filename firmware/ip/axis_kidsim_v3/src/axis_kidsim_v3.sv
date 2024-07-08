module axis_kidsim_v3
	#(
		// Number of lanes.
		parameter L	= 8
	)
	( 	
		// Modulation trigger.
		input 	wire	[L-1:0]		trigger			,

		// AXI Slave I/F for configuration.
		input	wire  				s_axi_aclk		,
		input 	wire  				s_axi_aresetn	,

		input 	wire	[7:0]		s_axi_awaddr	,
		input 	wire 	[2:0]		s_axi_awprot	,
		input 	wire  				s_axi_awvalid	,
		output	wire  				s_axi_awready	,

		input 	wire 	[31:0] 		s_axi_wdata		,
		input 	wire 	[3:0]		s_axi_wstrb		,
		input 	wire  				s_axi_wvalid	,
		output 	wire  				s_axi_wready	,

		output 	wire 	[1:0]		s_axi_bresp		,
		output 	wire  				s_axi_bvalid	,
		input 	wire  				s_axi_bready	,

		input 	wire 	[7:0] 		s_axi_araddr	,
		input 	wire 	[2:0] 		s_axi_arprot	,
		input 	wire  				s_axi_arvalid	,
		output 	wire  				s_axi_arready	,

		output 	wire 	[31:0] 		s_axi_rdata		,
		output 	wire 	[1:0]		s_axi_rresp		,
		output 	wire  				s_axi_rvalid	,
		input 	wire  				s_axi_rready	,

		// Reset and clock for axis_*.
		input 	wire 				aresetn			,
		input 	wire 				aclk			,

		// s_axis_* for input.
		input	wire				s_axis_tvalid	,
		input	wire	[32*L-1:0]	s_axis_tdata	,
		input	wire				s_axis_tlast	,

		// m_axis_* for output.
		output	wire				m_axis_tvalid	,
		output	wire	[32*L-1:0]	m_axis_tdata	,
		output	wire				m_axis_tlast
	);

/********************/
/* Internal signals */
/********************/

// WE vector.
wire	[L-1:0]	enable_v		;
wire	[L-1:0]	WE_REG_v		;

// Data input vector.
wire	[31:0]	din_v		[L]	;

// Data output vector.
wire	[L-1:0]	dout_valid		;
wire	[31:0]	dout_v		[L]	;
wire	[L-1:0]	dout_last		;

// Registers.
wire 	[15:0]	DDS_BVAL_REG	;
wire 	[15:0]	DDS_SLOPE_REG	;
wire 	[15:0]	DDS_STEPS_REG	;
wire 	[15:0]	DDS_WAIT_REG	;
wire 	[15:0]	DDS_FREQ_REG	;
wire 	[15:0]	IIR_C0_REG		;
wire 	[15:0]	IIR_C1_REG		;
wire 	[15:0]	IIR_G_REG		;
wire 	[ 1:0]	OUTSEL_REG		;
wire 	[15:0]	PUNCT_ID_REG	;
wire	[ 7:0]	ADDR_REG		;
wire			WE_REG			;

/**********************/
/* Begin Architecture */
/**********************/
// AXI Slave.
axi_slv axi_slv_i
	(
		.s_axi_aclk		(s_axi_aclk	  	),
		.s_axi_aresetn	(s_axi_aresetn	),

		// Write Address Channel.
		.s_axi_awaddr	(s_axi_awaddr	),
		.s_axi_awprot	(s_axi_awprot	),
		.s_axi_awvalid	(s_axi_awvalid	),
		.s_axi_awready	(s_axi_awready	),

		// Write Data Channel.
		.s_axi_wdata	(s_axi_wdata	),
		.s_axi_wstrb	(s_axi_wstrb	),
		.s_axi_wvalid	(s_axi_wvalid	),
		.s_axi_wready	(s_axi_wready	),

		// Write Response Channel.
		.s_axi_bresp	(s_axi_bresp	),
		.s_axi_bvalid	(s_axi_bvalid	),
		.s_axi_bready	(s_axi_bready	),

		// Read Address Channel.
		.s_axi_araddr	(s_axi_araddr	),
		.s_axi_arprot	(s_axi_arprot	),
		.s_axi_arvalid	(s_axi_arvalid	),
		.s_axi_arready	(s_axi_arready	),

		// Read Data Channel.
		.s_axi_rdata	(s_axi_rdata	),
		.s_axi_rresp	(s_axi_rresp	),
		.s_axi_rvalid	(s_axi_rvalid	),
		.s_axi_rready	(s_axi_rready	),

		// Registers.
		.DDS_BVAL_REG	(DDS_BVAL_REG	),
		.DDS_SLOPE_REG	(DDS_SLOPE_REG	),
		.DDS_STEPS_REG	(DDS_STEPS_REG	),
		.DDS_WAIT_REG	(DDS_WAIT_REG	),
		.DDS_FREQ_REG	(DDS_FREQ_REG	),
		.IIR_C0_REG		(IIR_C0_REG		),
		.IIR_C1_REG		(IIR_C1_REG		),
		.IIR_G_REG		(IIR_G_REG		),
		.OUTSEL_REG		(OUTSEL_REG		),
		.PUNCT_ID_REG	(PUNCT_ID_REG	),
		.ADDR_REG		(ADDR_REG		),
		.WE_REG			(WE_REG			)
	);

genvar i;
generate
	for (i=0; i<L; i=i+1) begin : GEN_kidsim
		// KIDSIM Block.
		kidsim_top
			kidsim_top_i
			(
				// Reset and clock.
				.rstn			(aresetn		),
				.clk			(aclk			),
		
				// Modulation trigger.
				.trigger		(trigger[i]		),
		
				// Input data.
				.din_valid		(s_axis_tvalid	),
				.din			(din_v[i]		),
				.din_last		(s_axis_tlast	),
		
				// Output data.
				.dout_valid		(dout_valid[i]	),
				.dout			(dout_v[i]		),
				.dout_last		(dout_last[i]	),
		
				// Registers.
				.DDS_BVAL_REG	(DDS_BVAL_REG	),
				.DDS_SLOPE_REG	(DDS_SLOPE_REG	),
				.DDS_STEPS_REG	(DDS_STEPS_REG	),
				.DDS_WAIT_REG	(DDS_WAIT_REG	),
				.DDS_FREQ_REG	(DDS_FREQ_REG	),
				.IIR_C0_REG		(IIR_C0_REG		),
				.IIR_C1_REG		(IIR_C1_REG		),
				.IIR_G_REG		(IIR_G_REG		),
				.OUTSEL_REG		(OUTSEL_REG		),
				.PUNCT_ID_REG	(PUNCT_ID_REG	),
				.WE_REG			(WE_REG_v[i]	)
			);

		// WE vector.
		assign enable_v		[i] 		= (ADDR_REG == i);
		assign WE_REG_v		[i] 		= enable_v[i] & WE_REG;

		// Data input vector
		assign din_v		[i]			= s_axis_tdata [i*32 +: 32];

		// Data output vector.
		assign m_axis_tdata [i*32 +: 32]= dout_v[i]	;

	end
endgenerate

// Assign outputs.
assign m_axis_tvalid 	= dout_valid[0];
assign m_axis_tlast		= dout_last[0];

endmodule

