// This block resamples input data to reduce the number of lanes by 2.
// It is extremely important to be sure input data is valid only
// every other clock. Faster input data rate will make the block fail.
module axis_resampler_2x1_v1
	#(
		// Number of bits.
		parameter B	= 16	,

		// Number of lanes (input).
		parameter N	= 8
	)
	(
		// Reset and clock.
		input	wire				aclk			,
		input	wire				aresetn			,

		// s_axis_* for input data.
		output	wire				s_axis_tready	,
		input	wire				s_axis_tvalid	,
		input	wire	[N*B-1:0]	s_axis_tdata	,

		// m_axis_* for output data.
		input	wire				m_axis_tready	,
		output	wire				m_axis_tvalid	,
		output	wire	[N/2*B-1:0]	m_axis_tdata
	);

/*************/
/* Internals */
/*************/

// Data registers.
reg		[N*B-1:0]	din_r1		;
reg		[N*B-1:0]	din_r2		;

// Low/high part.
wire	[N/2*B-1:0]	din_low		;
wire	[N/2*B-1:0]	din_high	;

// Muxed output.
wire	[N/2*B-1:0]	d_mux		;
reg		[N/2*B-1:0]	d_mux_r1	;

// Valid.
reg					valid_r1	;
reg					valid_r2	;
reg					valid_r3	;
reg					valid_r4	;
wire				valid_i		;

/****************/
/* Architecture */
/****************/

// Low/high part.
assign din_low 	= din_r2	[0		+: N/2*B];
assign din_high = din_r2	[N/2*B	+: N/2*B];

// Muxed output.
assign d_mux	= (valid_r2)? din_low : din_high;

// Valid.
assign valid_i	= valid_r3 || valid_r4;

// Registers.
always @(posedge aclk) begin
	if (~aresetn) begin
		// Data registers.
		din_r1		<= 0;
		din_r2		<= 0;

		d_mux_r1	<= 0;	

		// Valid.
		valid_r1	<= 0;
		valid_r2	<= 0;
		valid_r3	<= 0;
		valid_r4	<= 0;
    end
	else begin
		// Data registers.
		din_r1		<= s_axis_tdata;
		if (valid_r1)
			din_r2		<= din_r1;

		// Muxed output.
		d_mux_r1	<= d_mux;	

		// Valid.
		valid_r1	<= s_axis_tvalid;
		valid_r2	<= valid_r1;
		valid_r3	<= valid_r2;
		valid_r4	<= valid_r3;
	end
end

// Assign outputs.
assign s_axis_tready = 1'b1		;
assign m_axis_tvalid = valid_i	;
assign m_axis_tdata  = d_mux_r1	;

endmodule

