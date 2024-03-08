// This block reorders PFB output to get it ready for the
// SSR FFT.
module pfb_reorder
	(
		// Reset and clock.
		aclk			,

		// S_AXIS for input data.
		s_axis_tvalid	,
		s_axis_tlast	,
		s_axis_tdata	,

		// M_AXIS for output data.
		m_axis_tvalid	,
		m_axis_tlast	,
		m_axis_tdata
	);

/**************/
/* Parameters */
/**************/
// Bits.
parameter B = 32;

// Number of Lanes.
parameter L = 4;

/*********/
/* Ports */
/*********/
input				aclk;

input				s_axis_tvalid;
input				s_axis_tlast;
input	[2*L*B-1:0]	s_axis_tdata;

output				m_axis_tvalid;
output				m_axis_tlast;
output	[2*L*B-1:0]	m_axis_tdata;

/********************/
/* Internal signals */
/********************/
// Sorted input data.
wire	[2*L*B-1:0]	din_sort;

// Data registers.
reg		[2*L*B-1:0]	data_r1 = 0;
reg		[2*L*B-1:0]	data_r2 = 0;
reg		[2*L*B-1:0]	data_r3 = 0;
reg		[2*L*B-1:0]	data_r4 = 0;

// Tlast registers.
reg					last_r1 = 0;
reg					last_r2 = 0;
reg					last_r3 = 0;

// Low/High data.
wire	[2*L*B-1:0]	dlow;
wire	[2*L*B-1:0]	dhigh;

// Muxed output.
reg					sel = 0;
wire	[2*L*B-1:0]	dmux;

/**********************/
/* Begin Architecture */
/**********************/
genvar i;
generate
	for (i=0; i<L; i=i+1) begin
		// Even samples.
		assign din_sort[i*B 	+: B]	= s_axis_tdata[2*i*B +: B];

		// Odd samples.
		assign din_sort[L*B+i*B +: B] 	= s_axis_tdata[(2*i+1)*B +: B];
	end
endgenerate

// Low/High data.
assign dlow		= {data_r2[0 +: L*B],data_r3[0 +: L*B]};
assign dhigh	= {data_r3[L*B +: L*B],data_r4[L*B +: L*B]};

// Muxed output.
assign dmux		= (sel == 1'b0)? dlow : dhigh;

// Registers.
always @(posedge aclk) begin
	// Data registers.
	data_r1	<= din_sort;
	data_r2	<= data_r1;
	data_r3	<= data_r2;
	data_r4	<= data_r3;

	// Tvalid/tlast registers.
	last_r1	<= s_axis_tlast;
	last_r2	<= last_r1;
	last_r3	<= last_r2;

	// Muxed output.
	if (last_r3)
		sel <= 0;
	else
		sel	<= ~sel;
end

// Assign outputs.
assign m_axis_tvalid 	= 1'b1;
assign m_axis_tlast		= last_r3;
assign m_axis_tdata		= dmux;

endmodule

