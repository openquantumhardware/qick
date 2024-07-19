// This block reorders the data to format it for PFB.
// Input is formatted as follows:
// 
// Q[L-1] ... Q[2] Q[1] Q[0] I[L-1] .. I[2] I[1] I[0]
// 
// where Q[k],I[k] are B bits. Output is reordered to
// interleave the values as follows:
// 
// Q[L-1] I[L-1] .. Q[2] I[2] Q[1] I[1] Q[0] I[0]
//
module axis_reorder_iq_v1
	#(
		// Number of bits.
		parameter B = 16	,
		
		// Number of lanes.
		parameter L = 4
	)
	( 
		// s_* and m_* reset/clock.
		input wire				aresetn			,
		input wire				aclk			,

    	// S_AXIS for data input.
		input wire	[2*B*L-1:0]	s_axis_tdata	,
		input wire				s_axis_tvalid	,
		output wire				s_axis_tready	,

		// M_AXIS for data output.
		output wire	[2*B*L-1:0]	m_axis_tdata	,
		output wire				m_axis_tvalid	,
		input wire				m_axis_tready
	);

/********************/
/* Internal signals */
/********************/
// I/Q sections.
wire	[B*L-1:0]	data_i;
wire	[B*L-1:0]	data_q;

// I/Q vectors.
wire	[B-1:0]		data_iv [L];
wire	[B-1:0]		data_qv [L];

/**********************/
/* Begin Architecture */
/**********************/
// I/Q sectiions.
assign data_i = s_axis_tdata[0 		+: B*L];
assign data_q = s_axis_tdata[B*L 	+: B*L];

genvar i;
generate
	for (i=0; i<L; i = i+1) begin
		// I/Q vectors.
		assign data_iv[i] = data_i[i*B +: B];
		assign data_qv[i] = data_q[i*B +: B];

		// Assign output.
		assign m_axis_tdata [2*B*i +: 2*B] = {data_qv[i],data_iv[i]};
	end
endgenerate

// Assign outputs.
assign s_axis_tready	= 1'b1;
assign m_axis_tvalid	= s_axis_tvalid;

endmodule

