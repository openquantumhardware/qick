// This block computes the complex conjugate of the data.
module pfb_conjugate
	#(
		// Number of bits of real/imaginary part.
		parameter B = 16	,

		// Number of lanes.
		parameter L = 4	
	)
	(
		// Reset and clock.
		input wire 				aresetn			,
		input wire 				aclk			,

		// S_AXIS for input data.
		input wire [2*B*L-1:0]	s_axis_tdata	,
		input wire				s_axis_tlast	,
		input wire				s_axis_tvalid	,

		// M_AXIS for output data.
		output wire [2*B*L-1:0]	m_axis_tdata	,
		output wire				m_axis_tlast	,
		output wire				m_axis_tvalid
	);

/********************/
/* Internal signals */
/********************/
// Input data registers.
reg	[2*B*L-1:0]		din_r1;

// I/Q parts.
wire signed [B-1:0]	din_i_v[L];
wire signed [B-1:0]	din_q_v[L];

// Complex conjugate.
wire signed [B-1:0]	din_i_conj_v[L];
wire signed [B-1:0]	din_q_conj_v[L];

// Output data.
wire [2*B*L-1:0]	dout;

// Output data registers.
reg	[2*B*L-1:0]		dout_r1;

// tlast/tvalid registers.
reg					tlast_r1;
reg					tlast_r2;
reg					tvalid_r1;
reg					tvalid_r2;

/**********************/
/* Begin Architecture */
/**********************/
genvar i;
generate
	for (i=0; i<L; i=i+1) begin
		// I/Q parts.
		assign din_i_v[i]			= din_r1[2*i*B 		+: B];
		assign din_q_v[i]			= din_r1[(2*i+1)*B	+: B];

		// Complex conjugate.
		assign din_i_conj_v[i]		= din_i_v[i];
		assign din_q_conj_v[i]		= -din_q_v[i];

		// Output data.
		assign dout[2*i*B 	  +: B]	= din_i_conj_v[i];
		assign dout[(2*i+1)*B +: B]	= din_q_conj_v[i];
	end
endgenerate

// Registers.
always @(posedge aclk) begin
	if (~aresetn) begin
		// Input data registers.
		din_r1		<= 0;

		// Output data registers.
		dout_r1		<= 0;

		// tlast/tvalid registers.
		tlast_r1	<= 0;
		tlast_r2	<= 0;
		tvalid_r1	<= 0;
		tvalid_r2	<= 0;
	end
	else begin
		// Input data registers.
		din_r1		<= s_axis_tdata;

		// Output data registers.
		dout_r1		<= dout;

		// tlast/tvalid registers.
		tlast_r1	<= s_axis_tlast;
		tlast_r2	<= tlast_r1;
		tvalid_r1	<= s_axis_tvalid;
		tvalid_r2	<= tvalid_r1;
	end
end

// Assign outputs.
assign m_axis_tdata		= dout_r1;
assign m_axis_tlast		= tlast_r2;
assign m_axis_tvalid 	= tvalid_r2;

endmodule

