module ddsprod_v
	(
		// Reset and clock.
		aresetn			,
		aclk			,

		// S_AXIS for input data.
		s_axis_tvalid	,
		s_axis_tdata	,

		// M_AXIS for output data.
		m_axis_tvalid	,
		m_axis_tdata	,

		// Registers.
		FREQ0_REG		,
		FREQ1_REG		,
		FREQ2_REG		,
		FREQ3_REG		,
		FREQ4_REG		,
		FREQ5_REG		,
		FREQ6_REG		,
		FREQ7_REG		,
		OUTSEL_REG
	);

/*********/
/* Ports */
/*********/
input				aresetn;
input				aclk;

input				s_axis_tvalid;
input	[8*32-1:0]	s_axis_tdata;

output				m_axis_tvalid;
output	[8*32-1:0]	m_axis_tdata;

input	[31:0]		FREQ0_REG;
input	[31:0]		FREQ1_REG;
input	[31:0]		FREQ2_REG;
input	[31:0]		FREQ3_REG;
input	[31:0]		FREQ4_REG;
input	[31:0]		FREQ5_REG;
input	[31:0]		FREQ6_REG;
input	[31:0]		FREQ7_REG;
input	[1:0]		OUTSEL_REG;

/********************/
/* Internal signals */
/********************/
localparam L = 8;

// Input data vector.
wire	[31:0]		din_v [0:L-1];

// Frequency registers.
wire	[31:0]		freq_reg_v [0:7];

// Output data vector.
wire	[31:0]		dout_v [0:L-1];

/**********************/
/* Begin Architecture */
/**********************/
// Frequency registers.
assign freq_reg_v[0] = FREQ0_REG;
assign freq_reg_v[1] = FREQ1_REG;
assign freq_reg_v[2] = FREQ2_REG;
assign freq_reg_v[3] = FREQ3_REG;
assign freq_reg_v[4] = FREQ4_REG;
assign freq_reg_v[5] = FREQ5_REG;
assign freq_reg_v[6] = FREQ6_REG;
assign freq_reg_v[7] = FREQ7_REG;

genvar i;
generate
	for (i=0; i<L; i=i+1) begin
		// DDS product.
		ddsprod ddsprod_i
			(
				// Reset and clock.
				.aresetn		(aresetn		),
				.aclk			(aclk			),
		
				// S_AXIS for input data.
				.s_axis_tvalid	(s_axis_tvalid	),
				.s_axis_tdata	(din_v[i]		),
		
				// M_AXIS for output data.
				.m_axis_tvalid	(m_axis_tvalid	),
				.m_axis_tdata	(dout_v[i]		),
		
				// Registers.
				.FREQ_REG		(freq_reg_v[i]	),
				.OUTSEL_REG		(OUTSEL_REG		)
			);

		// Input: real.
		assign din_v[i][15:0]	= s_axis_tdata[i*16 +: 16];

		// Input: imag.
		assign din_v[i][31:16]	= s_axis_tdata[L*16+i*16 +: 16];

		// Output.
		// QQQQQQQQIIIIIIII.
		//assign m_axis_tdata[i*16		+: 16] 	= dout_v[i][15:0];
		//assign m_axis_tdata[L*16+i*16 	+: 16] 	= dout_v[i][31:16];

		// QIQIQIQIQIQIQIQI.
		assign m_axis_tdata[i*32 +: 32]	= dout_v[i];
	end
endgenerate

endmodule

