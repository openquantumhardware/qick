module tb;

// Number of outputs.
parameter N = 8		;

// Number of data bits.
parameter B = 32	;

// Reset and clock.
reg			aresetn			;
reg			aclk			;

// S_AXIS for input data.
wire 			s_axis_tready	;
reg 			s_axis_tvalid	;
wire 	[B-1:0]	s_axis_tdata	;

// M_AXIS for output data.
wire			m0_axis_tvalid	;
wire	[B-1:0]	m0_axis_tdata	;

wire			m1_axis_tvalid	;
wire	[B-1:0]	m1_axis_tdata	;

wire			m2_axis_tvalid	;
wire	[B-1:0]	m2_axis_tdata	;

wire			m3_axis_tvalid	;
wire	[B-1:0]	m3_axis_tdata	;

wire			m4_axis_tvalid	;
wire	[B-1:0]	m4_axis_tdata	;

wire			m5_axis_tvalid	;
wire	[B-1:0]	m5_axis_tdata	;

wire			m6_axis_tvalid	;
wire	[B-1:0]	m6_axis_tdata	;

wire			m7_axis_tvalid	;
wire	[B-1:0]	m7_axis_tdata	;

// Sel/data.
reg		[7:0]	sel_r			;
reg		[23:0]	data_r			;

// Input sel/data.
assign s_axis_tdata = {sel_r, data_r};

// DUT.
axis_tmux_v1
	#(
		// Number of outputs.
		.N(N),

		// Number of data bits.
		.B(B)
	)
	DUT
	(
		// Reset and clock.
		.aresetn		,
		.aclk			,

		// S_AXIS for input data.
		.s_axis_tready	,
		.s_axis_tvalid	,
		.s_axis_tdata	,

		// M_AXIS for output data.
		.m0_axis_tvalid	,
		.m0_axis_tdata	,

		.m1_axis_tvalid	,
		.m1_axis_tdata	,

		.m2_axis_tvalid	,
		.m2_axis_tdata	,

		.m3_axis_tvalid	,
		.m3_axis_tdata	,

		.m4_axis_tvalid	,
		.m4_axis_tdata	,

		.m5_axis_tvalid	,
		.m5_axis_tdata	,

		.m6_axis_tvalid	,
		.m6_axis_tdata	,

		.m7_axis_tvalid	,
		.m7_axis_tdata
	);

// Main TB.
initial begin
	aresetn			<= 0;
	s_axis_tvalid	<= 0;
	sel_r			<= 0;
	data_r			<= 0;
	#300;
	aresetn			<= 1;

	#1000;

	for (int i=0; i<N; i=i+1) begin
		@(posedge aclk);
		s_axis_tvalid	<= 1;
		sel_r 			<= i;
		data_r			<= $random;
	end

	@(posedge aclk);
	s_axis_tvalid	<= 0;

	#300;

	@(posedge aclk);
	s_axis_tvalid	<= 1;
	sel_r 			<= 3;
	data_r			<= $random;

	@(posedge aclk);
	s_axis_tvalid	<= 1;
	sel_r 			<= 1;
	data_r			<= $random;

	@(posedge aclk);
	s_axis_tvalid	<= 0;

	@(posedge aclk);
	s_axis_tvalid	<= 1;
	sel_r 			<= 0;
	data_r			<= $random;

	@(posedge aclk);
	s_axis_tvalid	<= 0;
end

// s_axis_aclk;
always begin
	aclk <= 0;
	#7;
	aclk <= 1;
	#7;
end

endmodule

