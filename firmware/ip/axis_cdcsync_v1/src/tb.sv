module tb;

// Number of inputs/outputs.
parameter N = 8	;

// Number of data bits.
parameter B = 8	;


// S_AXIS for input data.
reg			s_axis_aresetn	;
reg			s_axis_aclk		;

wire 		s0_axis_tready	;
reg 		s0_axis_tvalid	;
reg [B-1:0]	s0_axis_tdata	;

wire 		s1_axis_tready	;
reg 		s1_axis_tvalid	;
reg [B-1:0]	s1_axis_tdata	;

wire		s2_axis_tready	;
reg			s2_axis_tvalid	;
reg	[B-1:0]	s2_axis_tdata	;

wire		s3_axis_tready	;
reg			s3_axis_tvalid	;
reg	[B-1:0]	s3_axis_tdata	;

wire		s4_axis_tready	;
reg			s4_axis_tvalid	;
reg	[B-1:0]	s4_axis_tdata	;

wire		s5_axis_tready	;
reg			s5_axis_tvalid	;
reg	[B-1:0]	s5_axis_tdata	;

wire		s6_axis_tready	;
reg			s6_axis_tvalid	;
reg	[B-1:0]	s6_axis_tdata	;

wire		s7_axis_tready	;
reg			s7_axis_tvalid	;
reg	[B-1:0]	s7_axis_tdata	;

// M_AXIS for output data.
reg			m_axis_aresetn	;
reg			m_axis_aclk		;

wire		m0_axis_tvalid	;
wire[B-1:0]	m0_axis_tdata	;

wire		m1_axis_tvalid	;
wire[B-1:0]	m1_axis_tdata	;

wire		m2_axis_tvalid	;
wire[B-1:0]	m2_axis_tdata	;

wire		m3_axis_tvalid	;
wire[B-1:0]	m3_axis_tdata	;

wire		m4_axis_tvalid	;
wire[B-1:0]	m4_axis_tdata	;

wire		m5_axis_tvalid	;
wire[B-1:0]	m5_axis_tdata	;

wire		m6_axis_tvalid	;
wire[B-1:0]	m6_axis_tdata	;

wire		m7_axis_tvalid	;
wire[B-1:0]	m7_axis_tdata	;

// DUT.
axis_cdcsync_v1
	#(
		// Number of inputs/outputs.
		.N(N),

		// Number of data bits.
		.B(B)
	)
	DUT
	(
		// S_AXIS for input data.
		.s_axis_aresetn	,
		.s_axis_aclk	,

		.s0_axis_tready	,
		.s0_axis_tvalid	,
		.s0_axis_tdata	,

		.s1_axis_tready	,
		.s1_axis_tvalid	,
		.s1_axis_tdata	,

		.s2_axis_tready	,
		.s2_axis_tvalid	,
		.s2_axis_tdata	,

		.s3_axis_tready	,
		.s3_axis_tvalid	,
		.s3_axis_tdata	,

		.s4_axis_tready	,
		.s4_axis_tvalid	,
		.s4_axis_tdata	,

		.s5_axis_tready	,
		.s5_axis_tvalid	,
		.s5_axis_tdata	,

		.s6_axis_tready	,
		.s6_axis_tvalid	,
		.s6_axis_tdata	,

		.s7_axis_tready	,
		.s7_axis_tvalid	,
		.s7_axis_tdata	,

		// M_AXIS for output data.
		.m_axis_aresetn	,
		.m_axis_aclk	,

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
	s_axis_aresetn	<= 0;
	m_axis_aresetn	<= 0;
	s0_axis_tvalid	<= 0;
	s0_axis_tdata	<= 0;
	s1_axis_tvalid	<= 0;
	s1_axis_tdata	<= 0;
	s2_axis_tvalid	<= 0;
	s2_axis_tdata	<= 0;
	s3_axis_tvalid	<= 0;
	s3_axis_tdata	<= 0;
	s4_axis_tvalid	<= 0;
	s4_axis_tdata	<= 0;
	s5_axis_tvalid	<= 0;
	s5_axis_tdata	<= 0;
	s6_axis_tvalid	<= 0;
	s6_axis_tdata	<= 0;
	s7_axis_tvalid	<= 0;
	s7_axis_tdata	<= 0;
	#300;
	s_axis_aresetn	<= 1;
	m_axis_aresetn	<= 1;

	#1000;
	
	@(posedge s_axis_aclk);
	s0_axis_tvalid	<= 1'b1;
	s0_axis_tdata	<= $random;

	@(posedge s_axis_aclk);
	s0_axis_tvalid	<= 1'b0;

	#200;

	@(posedge s_axis_aclk);
	s1_axis_tvalid	<= 1'b1;
	s1_axis_tdata	<= $random;

	@(posedge s_axis_aclk);
	s1_axis_tvalid	<= 1'b0;

	for (int i=0; i<5; i=i+1) begin
		@(posedge s_axis_aclk);
		s0_axis_tvalid	<= 1'b1;
		s0_axis_tdata	<= $random;
		s1_axis_tvalid	<= 1'b1;
		s1_axis_tdata	<= $random;
	end

	@(posedge s_axis_aclk);
	s1_axis_tvalid	<= 1'b0;

	for (int i=0; i<7; i=i+1) begin
		@(posedge s_axis_aclk);
		s0_axis_tvalid	<= 1'b1;
		s0_axis_tdata	<= $random;
	end

	@(posedge s_axis_aclk);
	s0_axis_tvalid	<= 1'b0;
	
	#2000;

	@(posedge s_axis_aclk);
	s7_axis_tvalid	<= 1'b1;
	s7_axis_tdata	<= $random;

	@(posedge s_axis_aclk);
	s7_axis_tvalid	<= 1'b0;	
	
end

// s_axis_aclk;
always begin
	s_axis_aclk	<= 0;
	#7;
	s_axis_aclk	<= 1;
	#7;
end

// m_axis_aclk;
always begin
	m_axis_aclk	<= 0;
	#3;
	m_axis_aclk	<= 1;
	#3;
end

endmodule

