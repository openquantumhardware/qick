module tb();

// Number of bits.
parameter B	= 8;

// Number of lanes (input).
parameter N	= 4;

// Reset and clock.
reg					aresetn			;
reg					aclk			;

// s_axis_* for input data.
wire				s_axis_tready	;
reg					s_axis_tvalid	;
reg		[N*B-1:0]	s_axis_tdata	;

// m_axis_* for output data.
reg					m_axis_tready	;
wire				m_axis_tvalid	;
wire	[N/2*B-1:0]	m_axis_tdata	;

/**************/
/* Test Bench */
/**************/

// DUT.
axis_resampler_2x1_v1
	#(
		// Number of bits.
		.B(B),

		// Number of lanes (input).
		.N(N)
	)
	DUT
	(
		// Reset and clock.
		.aclk			,
		.aresetn		,

		// s_axis_* for input data.
		.s_axis_tready	,
		.s_axis_tvalid	,
		.s_axis_tdata	,

		// m_axis_* for output data.
		.m_axis_tready	,
		.m_axis_tvalid	,
		.m_axis_tdata
	);

initial begin
	// Reset sequence.
	aresetn			<= 0;
	s_axis_tvalid	<= 0;
	m_axis_tready	<= 1;
	#500;
	aresetn 		<= 1;

	#1000;

	for (int i=0; i<200; i=i+1) begin
		@(posedge aclk);
		s_axis_tvalid	<= 0;
		@(posedge aclk);
		@(posedge aclk);
		@(posedge aclk);
		s_axis_tvalid	<= 1;
		for (int j=0; j<N; j=j+1) begin
			s_axis_tdata [j*B +: B] <= i*N + j;
		end	
	end
end

always begin
	aclk <= 0;
	#3;
	aclk <= 1;
	#3;
end

endmodule

