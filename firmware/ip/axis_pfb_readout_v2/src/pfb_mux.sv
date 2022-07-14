module pfb_mux
	(
		// Reset and clock.
		aresetn			,
		aclk			,

		// S_AXIS for input data.
		s_axis_tvalid	,
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
		m3_axis_tdata	,

		// Registers.
		CH0SEL_REG		,
		CH1SEL_REG		,
		CH2SEL_REG		,
		CH3SEL_REG	
	);

/*********/
/* Ports */
/*********/
input				aresetn;
input				aclk;

input				s_axis_tvalid;
input	[8*32-1:0]	s_axis_tdata;

output				m0_axis_tvalid;
output	[31:0]		m0_axis_tdata;

output				m1_axis_tvalid;
output	[31:0]		m1_axis_tdata;

output				m2_axis_tvalid;
output	[31:0]		m2_axis_tdata;

output				m3_axis_tvalid;
output	[31:0]		m3_axis_tdata;

input	[2:0]		CH0SEL_REG;
input	[2:0]		CH1SEL_REG;
input	[2:0]		CH2SEL_REG;
input	[2:0]		CH3SEL_REG;

/********************/
/* Internal signals */
/********************/
wire	[31:0]		din_v [0:7];

/**********************/
/* Begin Architecture */
/**********************/

generate
genvar ii;
for (ii = 0; ii < 8; ii = ii + 1) begin
	assign din_v[ii] 	= s_axis_tdata[ii*32 +: 32];
end
endgenerate

// Assign outputs.
assign m0_axis_tvalid 		= s_axis_tvalid;
assign m0_axis_tdata		= din_v[CH0SEL_REG];

assign m1_axis_tvalid 		= s_axis_tvalid;
assign m1_axis_tdata		= din_v[CH1SEL_REG];

assign m2_axis_tvalid 		= s_axis_tvalid;
assign m2_axis_tdata		= din_v[CH2SEL_REG];

assign m3_axis_tvalid 		= s_axis_tvalid;
assign m3_axis_tdata		= din_v[CH3SEL_REG];

endmodule

