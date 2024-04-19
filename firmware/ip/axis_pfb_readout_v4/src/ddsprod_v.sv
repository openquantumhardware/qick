/*
 * This block instantiates 4 ddsprod blocks to apply
 * the dds product to 4 independent inputs, with 4
 * independent DDS blocks.
 */
module ddsprod_v
	(
		// Clock.
		input	wire			aclk			,

		// S_AXIS for input data.
		input	wire			s_axis_tvalid	,
		input	wire	[31:0]	s0_axis_tdata	,
		input	wire	[31:0]	s1_axis_tdata	,
		input	wire	[31:0]	s2_axis_tdata	,
		input	wire	[31:0]	s3_axis_tdata	,
		input	wire	[31:0]	s4_axis_tdata	,
		input	wire	[31:0]	s5_axis_tdata	,
		input	wire	[31:0]	s6_axis_tdata	,
		input	wire	[31:0]	s7_axis_tdata	,

		// M_AXIS for output data.
		output	wire			m_axis_tvalid	,
		output	wire	[31:0]	m0_axis_tdata	,
		output	wire	[31:0]	m1_axis_tdata	,
		output	wire	[31:0]	m2_axis_tdata	,
		output	wire	[31:0]	m3_axis_tdata	,
		output	wire	[31:0]	m4_axis_tdata	,
		output	wire	[31:0]	m5_axis_tdata	,
		output	wire	[31:0]	m6_axis_tdata	,
		output	wire	[31:0]	m7_axis_tdata	,

		// Registers.
		input	wire	[31:0]	PINC0_REG		,
		input	wire	[31:0]	POFF0_REG		,
		input	wire	[31:0]	PINC1_REG		,
		input	wire	[31:0]	POFF1_REG		,
		input	wire	[31:0]	PINC2_REG		,
		input	wire	[31:0]	POFF2_REG		,
		input	wire	[31:0]	PINC3_REG		,
		input	wire	[31:0]	POFF3_REG		,
		input	wire	[31:0]	PINC4_REG		,
		input	wire	[31:0]	POFF4_REG		,
		input	wire	[31:0]	PINC5_REG		,
		input	wire	[31:0]	POFF5_REG		,
		input	wire	[31:0]	PINC6_REG		,
		input	wire	[31:0]	POFF6_REG		,
		input	wire	[31:0]	PINC7_REG		,
		input	wire	[31:0]	POFF7_REG
	);

/********************/
/* Internal signals */
/********************/
// Number of inputs/outputs.
localparam N = 8;

// Input valid.
reg				vin_r		;

// Output valid.
wire	[N-1:0]	vout_v		;
reg				vout_r		;

// Vectorized inputs.
wire	[31:0]	din_v	[N]	;
reg		[31:0]	din_r	[N]	;

// Vectorized outputs.
wire	[31:0]	dout_v	[N]	;
reg		[31:0]	dout_r	[N]	;

// Vectorized registers.
reg		[31:0]	pinc_v	[N]	;
reg		[31:0]	poff_v	[N]	;

/**********************/
/* Begin Architecture */
/**********************/
// Vectorized inputs.
assign din_v	[0] = s0_axis_tdata	;
assign din_v	[1] = s1_axis_tdata	;
assign din_v	[2] = s2_axis_tdata	;
assign din_v	[3] = s3_axis_tdata	;
assign din_v	[4] = s4_axis_tdata	;
assign din_v	[5] = s5_axis_tdata	;
assign din_v	[6] = s6_axis_tdata	;
assign din_v	[7] = s7_axis_tdata	;

// Vectorized registers.
assign pinc_v	[0] = PINC0_REG		;
assign pinc_v	[1] = PINC1_REG		;
assign pinc_v	[2] = PINC2_REG		;
assign pinc_v	[3] = PINC3_REG		;
assign pinc_v	[4] = PINC4_REG		;
assign pinc_v	[5] = PINC5_REG		;
assign pinc_v	[6] = PINC6_REG		;
assign pinc_v	[7] = PINC7_REG		;
assign poff_v	[0] = POFF0_REG		;
assign poff_v	[1] = POFF1_REG		;
assign poff_v	[2] = POFF2_REG		;
assign poff_v	[3] = POFF3_REG		;
assign poff_v	[4] = POFF4_REG		;
assign poff_v	[5] = POFF5_REG		;
assign poff_v	[6] = POFF6_REG		;
assign poff_v	[7] = POFF7_REG		;

genvar i;
generate
	for (i=0; i<N; i=i+1) begin: GEN_ddsprod
		// DDS prod block.
		ddsprod ddsprod_i
			(
				// Clock.
				.aclk			(aclk		),
		
				// S_AXIS for input data.
				.s_axis_tvalid	(vin_r		),
				.s_axis_tdata	(din_r	[i]	),
		
				// M_AXIS for output data.
				.m_axis_tvalid	(vout_v	[i]	),
				.m_axis_tdata	(dout_v	[i]	),
		
				// Registers.
				.PINC_REG		(pinc_v	[i]	),
				.POFF_REG		(poff_v	[i]	)
			);

		always @(posedge aclk) begin
			// Vectorized inputs.
			din_r	[i]	<= din_v	[i]	;

			// Vectorized outputs.
			dout_r	[i]	<= dout_v	[i]	;
		end
	end
endgenerate

// Registers.
always @(posedge aclk) begin
	// Input valid.
	vin_r	<= s_axis_tvalid	;

	// Output valid.
	vout_r	<= vout_v [0]		;
end

// Assign outputs.
assign m_axis_tvalid	= vout_r	;
assign m0_axis_tdata	= dout_r [0];
assign m1_axis_tdata	= dout_r [1];
assign m2_axis_tdata	= dout_r [2];
assign m3_axis_tdata	= dout_r [3];
assign m4_axis_tdata	= dout_r [4];
assign m5_axis_tdata	= dout_r [5];
assign m6_axis_tdata	= dout_r [6];
assign m7_axis_tdata	= dout_r [7];

endmodule

