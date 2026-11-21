// Legacy RTL of QICK:QICK:axis_cdcsync_v1:1.0 (openquantumhardware/qick firmware/ip/axis_cdcsync_v1/src/
// {axis_cdcsync_v1.sv,cdcsync.sv} and firmware/hdl/fifo_dc_axi_xpm.sv), the golden model
// of the testbench. Only the module names are changed (_legacy suffix).

module axis_cdcsync_v1_legacy
	#(
		// Number of inputs/outputs.
		parameter N = 2	,

		// Number of data bits.
		parameter B = 8
	)
	(
		// S_AXIS for input data.
		input	wire			s_axis_aresetn	,
		input	wire			s_axis_aclk		,

		output	wire 			s0_axis_tready	,
		input	wire 			s0_axis_tvalid	,
		input	wire 	[B-1:0]	s0_axis_tdata	,

		output	wire 			s1_axis_tready	,
		input	wire 			s1_axis_tvalid	,
		input	wire 	[B-1:0]	s1_axis_tdata	,

		output	wire			s2_axis_tready	,
		input	wire			s2_axis_tvalid	,
		input	wire	[B-1:0]	s2_axis_tdata	,

		output	wire			s3_axis_tready	,
		input	wire			s3_axis_tvalid	,
		input	wire	[B-1:0]	s3_axis_tdata	,

		output	wire			s4_axis_tready	,
		input	wire			s4_axis_tvalid	,
		input	wire	[B-1:0]	s4_axis_tdata	,

		output	wire			s5_axis_tready	,
		input	wire			s5_axis_tvalid	,
		input	wire	[B-1:0]	s5_axis_tdata	,

		output	wire			s6_axis_tready	,
		input	wire			s6_axis_tvalid	,
		input	wire	[B-1:0]	s6_axis_tdata	,

		output	wire			s7_axis_tready	,
		input	wire			s7_axis_tvalid	,
		input	wire	[B-1:0]	s7_axis_tdata	,

		output	wire			s8_axis_tready	,
		input	wire			s8_axis_tvalid	,
		input	wire	[B-1:0]	s8_axis_tdata	,

		output	wire			s9_axis_tready	,
		input	wire			s9_axis_tvalid	,
		input	wire	[B-1:0]	s9_axis_tdata	,

		output	wire			s10_axis_tready	,
		input	wire			s10_axis_tvalid	,
		input	wire	[B-1:0]	s10_axis_tdata	,

		output	wire			s11_axis_tready	,
		input	wire			s11_axis_tvalid	,
		input	wire	[B-1:0]	s11_axis_tdata	,

		output	wire			s12_axis_tready	,
		input	wire			s12_axis_tvalid	,
		input	wire	[B-1:0]	s12_axis_tdata	,

		output	wire			s13_axis_tready	,
		input	wire			s13_axis_tvalid	,
		input	wire	[B-1:0]	s13_axis_tdata	,

		output	wire			s14_axis_tready	,
		input	wire			s14_axis_tvalid	,
		input	wire	[B-1:0]	s14_axis_tdata	,

		output	wire			s15_axis_tready	,
		input	wire			s15_axis_tvalid	,
		input	wire	[B-1:0]	s15_axis_tdata	,

		// M_AXIS for output data.
		input	wire			m_axis_aresetn	,
		input	wire			m_axis_aclk		,

		input	wire 			m0_axis_tready	,
		output	wire			m0_axis_tvalid	,
		output	wire	[B-1:0]	m0_axis_tdata	,

		input	wire 			m1_axis_tready	,
		output	wire			m1_axis_tvalid	,
		output	wire	[B-1:0]	m1_axis_tdata	,

		input	wire 			m2_axis_tready	,
		output	wire			m2_axis_tvalid	,
		output	wire	[B-1:0]	m2_axis_tdata	,

		input	wire 			m3_axis_tready	,
		output	wire			m3_axis_tvalid	,
		output	wire	[B-1:0]	m3_axis_tdata	,

		input	wire 			m4_axis_tready	,
		output	wire			m4_axis_tvalid	,
		output	wire	[B-1:0]	m4_axis_tdata	,

		input	wire 			m5_axis_tready	,
		output	wire			m5_axis_tvalid	,
		output	wire	[B-1:0]	m5_axis_tdata	,

		input	wire 			m6_axis_tready	,
		output	wire			m6_axis_tvalid	,
		output	wire	[B-1:0]	m6_axis_tdata	,

		input	wire 			m7_axis_tready	,
		output	wire			m7_axis_tvalid	,
		output	wire	[B-1:0]	m7_axis_tdata   ,

		input	wire 			m8_axis_tready	,
		output	wire			m8_axis_tvalid	,
		output	wire	[B-1:0]	m8_axis_tdata	,		

		input	wire 			m9_axis_tready	,
		output	wire			m9_axis_tvalid	,
		output	wire	[B-1:0]	m9_axis_tdata	,		

		input	wire 			m10_axis_tready	,
		output	wire			m10_axis_tvalid	,
		output	wire	[B-1:0]	m10_axis_tdata	,		

		input	wire 			m11_axis_tready	,
		output	wire			m11_axis_tvalid	,
		output	wire	[B-1:0]	m11_axis_tdata	,		

		input	wire 			m12_axis_tready	,
		output	wire			m12_axis_tvalid	,
		output	wire	[B-1:0]	m12_axis_tdata	,		

		input	wire 			m13_axis_tready	,
		output	wire			m13_axis_tvalid	,
		output	wire	[B-1:0]	m13_axis_tdata	,		

		input	wire 			m14_axis_tready	,
		output	wire			m14_axis_tvalid	,
		output	wire	[B-1:0]	m14_axis_tdata	,		

		input	wire 			m15_axis_tready	,
		output	wire			m15_axis_tvalid	,
		output	wire	[B-1:0]	m15_axis_tdata	
	);

/**********************/
/* Begin Architecture */
/**********************/
cdcsync_legacy
	#(
		// Number of inputs/outputs.
		.N(N),

		// Number of data bits.
		.B(B)
	)
	cdcsync_i
	(
		// S_AXIS for input data.
		.s_axis_aresetn	(s_axis_aresetn	),
		.s_axis_aclk	(s_axis_aclk	),

		.s0_axis_tready	(s0_axis_tready	),
		.s0_axis_tvalid	(s0_axis_tvalid	),
		.s0_axis_tdata	(s0_axis_tdata	),

		.s1_axis_tready	(s1_axis_tready	),
		.s1_axis_tvalid	(s1_axis_tvalid	),
		.s1_axis_tdata	(s1_axis_tdata	),

		.s2_axis_tready	(s2_axis_tready	),
		.s2_axis_tvalid	(s2_axis_tvalid	),
		.s2_axis_tdata	(s2_axis_tdata	),

		.s3_axis_tready	(s3_axis_tready	),
		.s3_axis_tvalid	(s3_axis_tvalid	),
		.s3_axis_tdata	(s3_axis_tdata	),

		.s4_axis_tready	(s4_axis_tready	),
		.s4_axis_tvalid	(s4_axis_tvalid	),
		.s4_axis_tdata	(s4_axis_tdata	),

		.s5_axis_tready	(s5_axis_tready	),
		.s5_axis_tvalid	(s5_axis_tvalid	),
		.s5_axis_tdata	(s5_axis_tdata	),

		.s6_axis_tready	(s6_axis_tready	),
		.s6_axis_tvalid	(s6_axis_tvalid	),
		.s6_axis_tdata	(s6_axis_tdata	),

		.s7_axis_tready	(s7_axis_tready	),
		.s7_axis_tvalid	(s7_axis_tvalid	),
		.s7_axis_tdata	(s7_axis_tdata	),

		.s8_axis_tready	(s8_axis_tready	),
		.s8_axis_tvalid	(s8_axis_tvalid	),
		.s8_axis_tdata	(s8_axis_tdata	),

		.s9_axis_tready	(s9_axis_tready	),
		.s9_axis_tvalid	(s9_axis_tvalid	),
		.s9_axis_tdata	(s9_axis_tdata	),

		.s10_axis_tready  (s10_axis_tready	),
		.s10_axis_tvalid  (s10_axis_tvalid	),
		.s10_axis_tdata	  (s10_axis_tdata	),

		.s11_axis_tready  (s11_axis_tready	),
		.s11_axis_tvalid  (s11_axis_tvalid	),
		.s11_axis_tdata	  (s11_axis_tdata	),

		.s12_axis_tready  (s12_axis_tready	),
		.s12_axis_tvalid  (s12_axis_tvalid	),
		.s12_axis_tdata	  (s12_axis_tdata	),

		.s13_axis_tready  (s13_axis_tready	),
		.s13_axis_tvalid  (s13_axis_tvalid	),
		.s13_axis_tdata	  (s13_axis_tdata	),

		.s14_axis_tready  (s14_axis_tready	),
		.s14_axis_tvalid  (s14_axis_tvalid	),
		.s14_axis_tdata	  (s14_axis_tdata	),

		.s15_axis_tready  (s15_axis_tready	),
		.s15_axis_tvalid  (s15_axis_tvalid	),
		.s15_axis_tdata	  (s15_axis_tdata	),

		// M_AXIS for output data.
		.m_axis_aresetn	(m_axis_aresetn	),
		.m_axis_aclk	(m_axis_aclk	),

		.m0_axis_tready	(m0_axis_tready	),
		.m0_axis_tvalid	(m0_axis_tvalid	),
		.m0_axis_tdata	(m0_axis_tdata	),

		.m1_axis_tready	(m1_axis_tready	),
		.m1_axis_tvalid	(m1_axis_tvalid	),
		.m1_axis_tdata	(m1_axis_tdata	),

		.m2_axis_tready	(m2_axis_tready	),
		.m2_axis_tvalid	(m2_axis_tvalid	),
		.m2_axis_tdata	(m2_axis_tdata	),

		.m3_axis_tready	(m3_axis_tready	),
		.m3_axis_tvalid	(m3_axis_tvalid	),
		.m3_axis_tdata	(m3_axis_tdata	),

		.m4_axis_tready	(m4_axis_tready	),
		.m4_axis_tvalid	(m4_axis_tvalid	),
		.m4_axis_tdata	(m4_axis_tdata	),

		.m5_axis_tready	(m5_axis_tready	),
		.m5_axis_tvalid	(m5_axis_tvalid	),
		.m5_axis_tdata	(m5_axis_tdata	),

		.m6_axis_tready	(m6_axis_tready	),
		.m6_axis_tvalid	(m6_axis_tvalid	),
		.m6_axis_tdata	(m6_axis_tdata	),

		.m7_axis_tready	(m7_axis_tready	),
		.m7_axis_tvalid	(m7_axis_tvalid	),
		.m7_axis_tdata	(m7_axis_tdata	),

		.m8_axis_tready	(m8_axis_tready	),
		.m8_axis_tvalid	(m8_axis_tvalid	),
		.m8_axis_tdata	(m8_axis_tdata	),

		.m9_axis_tready	(m9_axis_tready	),
		.m9_axis_tvalid	(m9_axis_tvalid	),
		.m9_axis_tdata	(m9_axis_tdata	),

		.m10_axis_tready  (m10_axis_tready	),
		.m10_axis_tvalid  (m10_axis_tvalid	),
		.m10_axis_tdata	  (m10_axis_tdata	),

		.m11_axis_tready  (m11_axis_tready	),
		.m11_axis_tvalid  (m11_axis_tvalid	),
		.m11_axis_tdata	  (m11_axis_tdata	),

		.m12_axis_tready  (m12_axis_tready	),
		.m12_axis_tvalid  (m12_axis_tvalid	),
		.m12_axis_tdata	  (m12_axis_tdata	),

		.m13_axis_tready  (m13_axis_tready	),
		.m13_axis_tvalid  (m13_axis_tvalid	),
		.m13_axis_tdata	  (m13_axis_tdata	),

		.m14_axis_tready  (m14_axis_tready	),
		.m14_axis_tvalid  (m14_axis_tvalid	),
		.m14_axis_tdata	  (m14_axis_tdata	),

		.m15_axis_tready  (m15_axis_tready	),
		.m15_axis_tvalid  (m15_axis_tvalid	),
		.m15_axis_tdata	  (m15_axis_tdata	)
	);

endmodule


module cdcsync_legacy
	#(
		// Number of inputs/outputs.
		parameter N = 2	,

		// Number of data bits.
		parameter B = 8
	)
	(
		// S_AXIS for input data.
		input	wire			s_axis_aresetn	,
		input	wire			s_axis_aclk		,

		output	wire 			s0_axis_tready	,
		input	wire 			s0_axis_tvalid	,
		input	wire 	[B-1:0]	s0_axis_tdata	,

		output	wire 			s1_axis_tready	,
		input	wire 			s1_axis_tvalid	,
		input	wire 	[B-1:0]	s1_axis_tdata	,

		output	wire			s2_axis_tready	,
		input	wire			s2_axis_tvalid	,
		input	wire	[B-1:0]	s2_axis_tdata	,

		output	wire			s3_axis_tready	,
		input	wire			s3_axis_tvalid	,
		input	wire	[B-1:0]	s3_axis_tdata	,

		output	wire			s4_axis_tready	,
		input	wire			s4_axis_tvalid	,
		input	wire	[B-1:0]	s4_axis_tdata	,

		output	wire			s5_axis_tready	,
		input	wire			s5_axis_tvalid	,
		input	wire	[B-1:0]	s5_axis_tdata	,

		output	wire			s6_axis_tready	,
		input	wire			s6_axis_tvalid	,
		input	wire	[B-1:0]	s6_axis_tdata	,

		output	wire			s7_axis_tready	,
		input	wire			s7_axis_tvalid	,
		input	wire	[B-1:0]	s7_axis_tdata	,

		output	wire			s8_axis_tready	,
		input	wire			s8_axis_tvalid	,
		input	wire	[B-1:0]	s8_axis_tdata	,

		output	wire			s9_axis_tready	,
		input	wire			s9_axis_tvalid	,
		input	wire	[B-1:0]	s9_axis_tdata	,

		output	wire			s10_axis_tready	,
		input	wire			s10_axis_tvalid	,
		input	wire	[B-1:0]	s10_axis_tdata	,

		output	wire			s11_axis_tready	,
		input	wire			s11_axis_tvalid	,
		input	wire	[B-1:0]	s11_axis_tdata	,

		output	wire			s12_axis_tready	,
		input	wire			s12_axis_tvalid	,
		input	wire	[B-1:0]	s12_axis_tdata	,

		output	wire			s13_axis_tready	,
		input	wire			s13_axis_tvalid	,
		input	wire	[B-1:0]	s13_axis_tdata	,

		output	wire			s14_axis_tready	,
		input	wire			s14_axis_tvalid	,
		input	wire	[B-1:0]	s14_axis_tdata	,

		output	wire			s15_axis_tready	,
		input	wire			s15_axis_tvalid	,
		input	wire	[B-1:0]	s15_axis_tdata	,

		// M_AXIS for output data.
		input	wire			m_axis_aresetn	,
		input	wire			m_axis_aclk		,

		input	wire 			m0_axis_tready	,
		output	wire			m0_axis_tvalid	,
		output	wire	[B-1:0]	m0_axis_tdata	,

		input	wire 			m1_axis_tready	,
		output	wire			m1_axis_tvalid	,
		output	wire	[B-1:0]	m1_axis_tdata	,

		input	wire 			m2_axis_tready	,
		output	wire			m2_axis_tvalid	,
		output	wire	[B-1:0]	m2_axis_tdata	,

		input	wire 			m3_axis_tready	,
		output	wire			m3_axis_tvalid	,
		output	wire	[B-1:0]	m3_axis_tdata	,

		input	wire 			m4_axis_tready	,
		output	wire			m4_axis_tvalid	,
		output	wire	[B-1:0]	m4_axis_tdata	,

		input	wire 			m5_axis_tready	,
		output	wire			m5_axis_tvalid	,
		output	wire	[B-1:0]	m5_axis_tdata	,

		input	wire 			m6_axis_tready	,
		output	wire			m6_axis_tvalid	,
		output	wire	[B-1:0]	m6_axis_tdata	,

		input	wire 			m7_axis_tready	,
		output	wire			m7_axis_tvalid	,
		output	wire	[B-1:0]	m7_axis_tdata   ,

		input	wire 			m8_axis_tready	,
		output	wire			m8_axis_tvalid	,
		output	wire	[B-1:0]	m8_axis_tdata	,		

		input	wire 			m9_axis_tready	,
		output	wire			m9_axis_tvalid	,
		output	wire	[B-1:0]	m9_axis_tdata	,		

		input	wire 			m10_axis_tready	,
		output	wire			m10_axis_tvalid	,
		output	wire	[B-1:0]	m10_axis_tdata	,		

		input	wire 			m11_axis_tready	,
		output	wire			m11_axis_tvalid	,
		output	wire	[B-1:0]	m11_axis_tdata	,		

		input	wire 			m12_axis_tready	,
		output	wire			m12_axis_tvalid	,
		output	wire	[B-1:0]	m12_axis_tdata	,		

		input	wire 			m13_axis_tready	,
		output	wire			m13_axis_tvalid	,
		output	wire	[B-1:0]	m13_axis_tdata	,		

		input	wire 			m14_axis_tready	,
		output	wire			m14_axis_tvalid	,
		output	wire	[B-1:0]	m14_axis_tdata	,		

		input	wire 			m15_axis_tready	,
		output	wire			m15_axis_tvalid	,
		output	wire	[B-1:0]	m15_axis_tdata	
	);

/********************/
/* Internal signals */
/********************/
// Total bits.
localparam	BD = B + 1;
localparam	BT = N*BD;

// Input data to vector.
wire	[B-1:0]		din_data_v	[16]	;
wire	[15:0]		din_valid_v		;
wire	[15:0]		din_ready_v		;

// Output vector to data.
wire	[B-1:0]		dout_data_v	[16]	;
wire	[15:0]		dout_valid_v	;
wire	[15:0]		dout_ready_v	;

wire 				fifo_wr_en		;
wire	[BT-1:0]	fifo_din		;
wire	[BT-1:0]	fifo_dout		;
wire				fifo_full		;
wire				fifo_empty		;

/**********************/
/* Begin Architecture */
/**********************/

// Input data to vector.
assign din_data_v	[0]  = s0_axis_tdata		;
assign din_data_v	[1]  = s1_axis_tdata		;
assign din_data_v	[2]  = s2_axis_tdata		;
assign din_data_v	[3]  = s3_axis_tdata		;
assign din_data_v	[4]  = s4_axis_tdata		;
assign din_data_v	[5]  = s5_axis_tdata		;
assign din_data_v	[6]  = s6_axis_tdata		;
assign din_data_v	[7]  = s7_axis_tdata		;
assign din_data_v	[8]  = s8_axis_tdata		;
assign din_data_v	[9]  = s9_axis_tdata		;
assign din_data_v	[10] = s10_axis_tdata		;
assign din_data_v	[11] = s11_axis_tdata		;
assign din_data_v	[12] = s12_axis_tdata		;
assign din_data_v	[13] = s13_axis_tdata		;
assign din_data_v	[14] = s14_axis_tdata		;
assign din_data_v	[15] = s15_axis_tdata		;

assign din_valid_v	[0]  = s0_axis_tvalid	&& N >= 1;
assign din_valid_v	[1]  = s1_axis_tvalid	&& N >= 2;
assign din_valid_v	[2]  = s2_axis_tvalid	&& N >= 3;
assign din_valid_v	[3]  = s3_axis_tvalid	&& N >= 4;
assign din_valid_v	[4]  = s4_axis_tvalid	&& N >= 5;
assign din_valid_v	[5]  = s5_axis_tvalid	&& N >= 6;
assign din_valid_v	[6]  = s6_axis_tvalid	&& N >= 7;
assign din_valid_v	[7]  = s7_axis_tvalid	&& N >= 8;
assign din_valid_v	[8]  = s8_axis_tvalid	&& N >= 9;
assign din_valid_v	[9]  = s9_axis_tvalid	&& N >= 10;
assign din_valid_v	[10] = s10_axis_tvalid	&& N >= 11;
assign din_valid_v	[11] = s11_axis_tvalid	&& N >= 12;
assign din_valid_v	[12] = s12_axis_tvalid	&& N >= 13;
assign din_valid_v	[13] = s13_axis_tvalid	&& N >= 14;
assign din_valid_v	[14] = s14_axis_tvalid	&& N >= 15;
assign din_valid_v	[15] = s15_axis_tvalid	&& N >= 16;

assign s0_axis_tready	= din_ready_v	[0] ;
assign s1_axis_tready	= din_ready_v	[1] ;
assign s2_axis_tready	= din_ready_v	[2] ;
assign s3_axis_tready	= din_ready_v	[3] ;
assign s4_axis_tready	= din_ready_v	[4] ;
assign s5_axis_tready	= din_ready_v	[5] ;
assign s6_axis_tready	= din_ready_v	[6] ;
assign s7_axis_tready	= din_ready_v	[7] ;
assign s8_axis_tready	= din_ready_v	[8] ;
assign s9_axis_tready	= din_ready_v	[9] ;
assign s10_axis_tready	= din_ready_v	[10];
assign s11_axis_tready	= din_ready_v	[11];
assign s12_axis_tready	= din_ready_v	[12];
assign s13_axis_tready	= din_ready_v	[13];
assign s14_axis_tready	= din_ready_v	[14];
assign s15_axis_tready	= din_ready_v	[15];

assign din_ready_v	[0]  = ~fifo_full	|| N < 1;
assign din_ready_v	[1]  = ~fifo_full	|| N < 2;
assign din_ready_v	[2]  = ~fifo_full	|| N < 3;
assign din_ready_v	[3]  = ~fifo_full	|| N < 4;
assign din_ready_v	[4]  = ~fifo_full	|| N < 5;
assign din_ready_v	[5]  = ~fifo_full	|| N < 6;
assign din_ready_v	[6]  = ~fifo_full	|| N < 7;
assign din_ready_v	[7]  = ~fifo_full	|| N < 8;
assign din_ready_v	[8]  = ~fifo_full	|| N < 9;
assign din_ready_v	[9]  = ~fifo_full	|| N < 10;
assign din_ready_v	[10] = ~fifo_full	|| N < 11;
assign din_ready_v	[11] = ~fifo_full	|| N < 12;
assign din_ready_v	[12] = ~fifo_full	|| N < 13;
assign din_ready_v	[13] = ~fifo_full	|| N < 14;
assign din_ready_v	[14] = ~fifo_full	|| N < 15;
assign din_ready_v	[15] = ~fifo_full	|| N < 16;

// Output vector to data.
assign m0_axis_tdata    = dout_data_v	[0] ;
assign m1_axis_tdata    = dout_data_v	[1] ;
assign m2_axis_tdata    = dout_data_v	[2] ;
assign m3_axis_tdata    = dout_data_v	[3] ;
assign m4_axis_tdata    = dout_data_v	[4] ;
assign m5_axis_tdata    = dout_data_v	[5] ;
assign m6_axis_tdata    = dout_data_v	[6] ;
assign m7_axis_tdata    = dout_data_v	[7] ;
assign m8_axis_tdata    = dout_data_v	[8] ;
assign m9_axis_tdata    = dout_data_v	[9] ;
assign m10_axis_tdata   = dout_data_v	[10] ;
assign m11_axis_tdata   = dout_data_v	[11] ;
assign m12_axis_tdata   = dout_data_v	[12] ;
assign m13_axis_tdata   = dout_data_v	[13] ;
assign m14_axis_tdata   = dout_data_v	[14] ;
assign m15_axis_tdata   = dout_data_v	[15] ;

assign m0_axis_tvalid	= dout_valid_v	[0]  & ~fifo_empty;
assign m1_axis_tvalid	= dout_valid_v	[1]  & ~fifo_empty;
assign m2_axis_tvalid	= dout_valid_v	[2]  & ~fifo_empty;
assign m3_axis_tvalid	= dout_valid_v	[3]  & ~fifo_empty;
assign m4_axis_tvalid	= dout_valid_v	[4]  & ~fifo_empty;
assign m5_axis_tvalid	= dout_valid_v	[5]  & ~fifo_empty;
assign m6_axis_tvalid	= dout_valid_v	[6]  & ~fifo_empty;
assign m7_axis_tvalid	= dout_valid_v	[7]  & ~fifo_empty;
assign m8_axis_tvalid	= dout_valid_v	[8]  & ~fifo_empty;
assign m9_axis_tvalid	= dout_valid_v	[9]  & ~fifo_empty;
assign m10_axis_tvalid	= dout_valid_v	[10] & ~fifo_empty;
assign m11_axis_tvalid	= dout_valid_v	[11] & ~fifo_empty;
assign m12_axis_tvalid	= dout_valid_v	[12] & ~fifo_empty;
assign m13_axis_tvalid	= dout_valid_v	[13] & ~fifo_empty;
assign m14_axis_tvalid	= dout_valid_v	[14] & ~fifo_empty;
assign m15_axis_tvalid	= dout_valid_v	[15] & ~fifo_empty;

assign dout_ready_v	[0]	= m0_axis_tready	|| N < 1;
assign dout_ready_v	[1]	= m1_axis_tready	|| N < 2;
assign dout_ready_v	[2]	= m2_axis_tready	|| N < 3;
assign dout_ready_v	[3]	= m3_axis_tready	|| N < 4;
assign dout_ready_v	[4]	= m4_axis_tready	|| N < 5;
assign dout_ready_v	[5]	= m5_axis_tready	|| N < 6;
assign dout_ready_v	[6]	= m6_axis_tready	|| N < 7;
assign dout_ready_v	[7]	= m7_axis_tready	|| N < 8;
assign dout_ready_v	[8]	= m8_axis_tready	|| N < 9;
assign dout_ready_v	[9]	= m9_axis_tready	|| N < 10;
assign dout_ready_v	[10]	= m10_axis_tready	|| N < 11;
assign dout_ready_v	[11]	= m11_axis_tready	|| N < 12;
assign dout_ready_v	[12]	= m12_axis_tready	|| N < 13;
assign dout_ready_v	[13]	= m13_axis_tready	|| N < 14;
assign dout_ready_v	[14]	= m14_axis_tready	|| N < 15;
assign dout_ready_v	[15]	= m15_axis_tready	|| N < 16;


genvar i;
generate
	for (i=0; i<N; i=i+1) begin : GEN_data
		// Input data to vector.
		assign fifo_din	[BD*i +: BD] 	= {din_valid_v[i],din_data_v[i]};
	
		// Output vector to data.
		assign dout_data_v	[i]			= fifo_dout	[BD*i 		+: B];
		assign dout_valid_v	[i]			= fifo_dout [BD*i +	B		];
	end
endgenerate

// Fifo.
fifo_dc_axi_xpm_legacy
    #(
        // Data width.
        .B(BT),
        
        // Fifo depth.
        .N(16)
    )
    fifo_i
    ( 
        .wr_rstn	(s_axis_aresetn	),
        .wr_clk 	(s_axis_aclk	),

        .rd_rstn	(m_axis_aresetn	),
        .rd_clk 	(m_axis_aclk	),
        
        // Write I/F.
        .wr_en  	(fifo_wr_en		),
        .din     	(fifo_din		),
        
        // Read I/F.
        .rd_en  	(fifo_rd_en		),
        .dout   	(fifo_dout		),
        
        // Flags.
        .full    	(fifo_full		),
        .empty   	(fifo_empty		)
    );

// Or together all slave valid inputs.
assign fifo_wr_en	= |din_valid_v	;

// AND together all the master ready inputs
assign fifo_rd_en	= &dout_ready_v;

endmodule


//------------------------------------------------------------------------------
// Company:     Fermilab
// File:        fifo_dc_axi_xpm.sv
// Description: FIFO Dual-Clock with Compatible AXI-S interface
//------------------------------------------------------------------------------

module fifo_dc_axi_xpm_legacy 
   #(
      // Data width.
      parameter B = 16,
      
      // Fifo depth.
      parameter N = 4
   ) ( 
      input wire              wr_rstn,
      input wire              wr_clk,

      input wire              rd_rstn,
      input wire              rd_clk,
      
      // Write I/F.
      input wire              wr_en,
      input wire [B-1:0]      din,
      
      // Read I/F.
      input wire              rd_en,
      output logic [B-1:0]    dout,
      
      // Flags.
      output logic            full,
      output logic            empty
   );

   logic wr_rst;

   // Invert RST for FIFO Macro
   assign wr_rst = ~ wr_rstn;





// XPM_FIFO instantiation template for Asynchronous FIFO configurations
// Refer to the targeted device family architecture libraries guide for XPM_FIFO documentation
// =======================================================================================================================

// Parameter usage table, organized as follows:
// +---------------------------------------------------------------------------------------------------------------------+
// | Parameter name       | Data type          | Restrictions, if applicable                                             |
// |---------------------------------------------------------------------------------------------------------------------|
// | Description                                                                                                         |
// +---------------------------------------------------------------------------------------------------------------------+
// +---------------------------------------------------------------------------------------------------------------------+
// | CASCADE_HEIGHT       | Integer            | Range: 0 - 64. Default value = 0.                                       |
// |---------------------------------------------------------------------------------------------------------------------|
// | 0- No Cascade Height, Allow Vivado Synthesis to choose.                                                             |
// | 1 or more - Vivado Synthesis sets the specified value as Cascade Height.                                            |
// +---------------------------------------------------------------------------------------------------------------------+
// | CDC_SYNC_STAGES      | Integer            | Range: 2 - 8. Default value = 2.                                        |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specifies the number of synchronization stages on the CDC path                                                      |
// |                                                                                                                     |
// |   Must be < 5 if FIFO_WRITE_DEPTH = 16                                                                              |
// +---------------------------------------------------------------------------------------------------------------------+
// | DOUT_RESET_VALUE     | String             | Default value = 0.                                                      |
// |---------------------------------------------------------------------------------------------------------------------|
// | Reset value of read data path.                                                                                      |
// +---------------------------------------------------------------------------------------------------------------------+
// | ECC_MODE             | String             | Allowed values: no_ecc, en_ecc. Default value = no_ecc.                 |
// |---------------------------------------------------------------------------------------------------------------------|
// |                                                                                                                     |
// |   "no_ecc" - Disables ECC                                                                                           |
// |   "en_ecc" - Enables both ECC Encoder and Decoder                                                                   |
// |                                                                                                                     |
// | NOTE: ECC_MODE should be "no_ecc" if FIFO_MEMORY_TYPE is set to "auto". Violating this may result incorrect behavior.|
// +---------------------------------------------------------------------------------------------------------------------+
// | FIFO_MEMORY_TYPE     | String             | Allowed values: auto, block, distributed. Default value = auto.         |
// |---------------------------------------------------------------------------------------------------------------------|
// | Designate the fifo memory primitive (resource type) to use.                                                         |
// |                                                                                                                     |
// |   "auto"- Allow Vivado Synthesis to choose                                                                          |
// |   "block"- Block RAM FIFO                                                                                           |
// |   "distributed"- Distributed RAM FIFO                                                                               |
// |                                                                                                                     |
// | NOTE: There may be a behavior mismatch if Block RAM or Ultra RAM specific features, like ECC or Asymmetry, are selected with FIFO_MEMORY_TYPE set to "auto".|
// +---------------------------------------------------------------------------------------------------------------------+
// | FIFO_READ_LATENCY    | Integer            | Range: 0 - 10. Default value = 1.                                       |
// |---------------------------------------------------------------------------------------------------------------------|
// | Number of output register stages in the read data path.                                                             |
// |                                                                                                                     |
// |   If READ_MODE = "fwft", then the only applicable value is 0.                                                       |
// +---------------------------------------------------------------------------------------------------------------------+
// | FIFO_WRITE_DEPTH     | Integer            | Range: 16 - 4194304. Default value = 2048.                              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Defines the FIFO Write Depth, must be power of two.                                                                 |
// |                                                                                                                     |
// |   In standard READ_MODE, the effective depth = FIFO_WRITE_DEPTH-1                                                   |
// |   In First-Word-Fall-Through READ_MODE, the effective depth = FIFO_WRITE_DEPTH+1                                    |
// |                                                                                                                     |
// | NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.                                             |
// +---------------------------------------------------------------------------------------------------------------------+
// | FULL_RESET_VALUE     | Integer            | Range: 0 - 1. Default value = 0.                                        |
// |---------------------------------------------------------------------------------------------------------------------|
// | Sets full, almost_full and prog_full to FULL_RESET_VALUE during reset                                               |
// +---------------------------------------------------------------------------------------------------------------------+
// | PROG_EMPTY_THRESH    | Integer            | Range: 3 - 4194301. Default value = 10.                                 |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specifies the minimum number of read words in the FIFO at or below which prog_empty is asserted.                    |
// |                                                                                                                     |
// |   Min_Value = 3 + (READ_MODE_VAL*2)                                                                                 |
// |   Max_Value = (FIFO_WRITE_DEPTH-3) - (READ_MODE_VAL*2)                                                              |
// |                                                                                                                     |
// | If READ_MODE = "std", then READ_MODE_VAL = 0; Otherwise READ_MODE_VAL = 1.                                          |
// | NOTE: The default threshold value is dependent on default FIFO_WRITE_DEPTH value. If FIFO_WRITE_DEPTH value is      |
// | changed, ensure the threshold value is within the valid range though the programmable flags are not used.           |
// +---------------------------------------------------------------------------------------------------------------------+
// | PROG_FULL_THRESH     | Integer            | Range: 5 - 4194301. Default value = 10.                                 |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specifies the maximum number of write words in the FIFO at or above which prog_full is asserted.                    |
// |                                                                                                                     |
// |   Min_Value = 3 + (READ_MODE_VAL*2*(FIFO_WRITE_DEPTH/FIFO_READ_DEPTH))+CDC_SYNC_STAGES                              |
// |   Max_Value = (FIFO_WRITE_DEPTH-3) - (READ_MODE_VAL*2*(FIFO_WRITE_DEPTH/FIFO_READ_DEPTH))                           |
// |                                                                                                                     |
// | If READ_MODE = "std", then READ_MODE_VAL = 0; Otherwise READ_MODE_VAL = 1.                                          |
// | NOTE: The default threshold value is dependent on default FIFO_WRITE_DEPTH value. If FIFO_WRITE_DEPTH value is      |
// | changed, ensure the threshold value is within the valid range though the programmable flags are not used.           |
// +---------------------------------------------------------------------------------------------------------------------+
// | RD_DATA_COUNT_WIDTH  | Integer            | Range: 1 - 23. Default value = 1.                                       |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specifies the width of rd_data_count. To reflect the correct value, the width should be log2(FIFO_READ_DEPTH)+1.    |
// |                                                                                                                     |
// |   FIFO_READ_DEPTH = FIFO_WRITE_DEPTH*WRITE_DATA_WIDTH/READ_DATA_WIDTH                                               |
// +---------------------------------------------------------------------------------------------------------------------+
// | READ_DATA_WIDTH      | Integer            | Range: 1 - 4096. Default value = 32.                                    |
// |---------------------------------------------------------------------------------------------------------------------|
// | Defines the width of the read data port, dout                                                                       |
// |                                                                                                                     |
// |   Write and read width aspect ratio must be 1:1, 1:2, 1:4, 1:8, 8:1, 4:1 and 2:1                                    |
// |   For example, if WRITE_DATA_WIDTH is 32, then the READ_DATA_WIDTH must be 32, 64,128, 256, 16, 8, 4.               |
// |                                                                                                                     |
// | NOTE:                                                                                                               |
// |                                                                                                                     |
// |   READ_DATA_WIDTH should be equal to WRITE_DATA_WIDTH if FIFO_MEMORY_TYPE is set to "auto". Violating this may result incorrect behavior. |
// |   The maximum FIFO size (width x depth) is limited to 150-Megabits.                                                 |
// +---------------------------------------------------------------------------------------------------------------------+
// | READ_MODE            | String             | Allowed values: std, fwft. Default value = std.                         |
// |---------------------------------------------------------------------------------------------------------------------|
// |                                                                                                                     |
// |   "std"- standard read mode                                                                                         |
// |   "fwft"- First-Word-Fall-Through read mode                                                                         |
// +---------------------------------------------------------------------------------------------------------------------+
// | RELATED_CLOCKS       | Integer            | Range: 0 - 1. Default value = 0.                                        |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specifies if the wr_clk and rd_clk are related having the same source but different clock ratios                    |
// +---------------------------------------------------------------------------------------------------------------------+
// | SIM_ASSERT_CHK       | Integer            | Range: 0 - 1. Default value = 0.                                        |
// |---------------------------------------------------------------------------------------------------------------------|
// | 0- Disable simulation message reporting. Messages related to potential misuse will not be reported.                 |
// | 1- Enable simulation message reporting. Messages related to potential misuse will be reported.                      |
// +---------------------------------------------------------------------------------------------------------------------+
// | USE_ADV_FEATURES     | String             | Default value = 0707.                                                   |
// |---------------------------------------------------------------------------------------------------------------------|
// | Enables data_valid, almost_empty, rd_data_count, prog_empty, underflow, wr_ack, almost_full, wr_data_count,         |
// | prog_full, overflow features.                                                                                       |
// |                                                                                                                     |
// |   Setting USE_ADV_FEATURES[0] to 1 enables overflow flag; Default value of this bit is 1                            |
// |   Setting USE_ADV_FEATURES[1] to 1 enables prog_full flag; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[2] to 1 enables wr_data_count; Default value of this bit is 1                            |
// |   Setting USE_ADV_FEATURES[3] to 1 enables almost_full flag; Default value of this bit is 0                         |
// |   Setting USE_ADV_FEATURES[4] to 1 enables wr_ack flag; Default value of this bit is 0                              |
// |   Setting USE_ADV_FEATURES[8] to 1 enables underflow flag; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[9] to 1 enables prog_empty flag; Default value of this bit is 1                          |
// |   Setting USE_ADV_FEATURES[10] to 1 enables rd_data_count; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[11] to 1 enables almost_empty flag; Default value of this bit is 0                       |
// |   Setting USE_ADV_FEATURES[12] to 1 enables data_valid flag; Default value of this bit is 0                         |
// +---------------------------------------------------------------------------------------------------------------------+
// | WAKEUP_TIME          | Integer            | Range: 0 - 2. Default value = 0.                                        |
// |---------------------------------------------------------------------------------------------------------------------|
// |                                                                                                                     |
// |   0 - Disable sleep                                                                                                 |
// |   2 - Use Sleep Pin                                                                                                 |
// |                                                                                                                     |
// | NOTE: WAKEUP_TIME should be 0 if FIFO_MEMORY_TYPE is set to "auto". Violating this may result incorrect behavior.   |
// +---------------------------------------------------------------------------------------------------------------------+
// | WRITE_DATA_WIDTH     | Integer            | Range: 1 - 4096. Default value = 32.                                    |
// |---------------------------------------------------------------------------------------------------------------------|
// | Defines the width of the write data port, din                                                                       |
// |                                                                                                                     |
// |   Write and read width aspect ratio must be 1:1, 1:2, 1:4, 1:8, 8:1, 4:1 and 2:1                                    |
// |   For example, if WRITE_DATA_WIDTH is 32, then the READ_DATA_WIDTH must be 32, 64,128, 256, 16, 8, 4.               |
// |                                                                                                                     |
// | NOTE:                                                                                                               |
// |                                                                                                                     |
// |   WRITE_DATA_WIDTH should be equal to READ_DATA_WIDTH if FIFO_MEMORY_TYPE is set to "auto". Violating this may result incorrect behavior. |
// |   The maximum FIFO size (width x depth) is limited to 150-Megabits.                                                 |
// +---------------------------------------------------------------------------------------------------------------------+
// | WR_DATA_COUNT_WIDTH  | Integer            | Range: 1 - 23. Default value = 1.                                       |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specifies the width of wr_data_count. To reflect the correct value, the width should be log2(FIFO_WRITE_DEPTH)+1.   |
// +---------------------------------------------------------------------------------------------------------------------+

// Port usage table, organized as follows:
// +---------------------------------------------------------------------------------------------------------------------+
// | Port name      | Direction | Size, in bits                         | Domain  | Sense       | Handling if unused     |
// |---------------------------------------------------------------------------------------------------------------------|
// | Description                                                                                                         |
// +---------------------------------------------------------------------------------------------------------------------+
// +---------------------------------------------------------------------------------------------------------------------+
// | almost_empty   | Output    | 1                                     | rd_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Almost Empty : When asserted, this signal indicates that only one more read can be performed before the FIFO goes to|
// | empty.                                                                                                              |
// +---------------------------------------------------------------------------------------------------------------------+
// | almost_full    | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Almost Full: When asserted, this signal indicates that only one more write can be performed before the FIFO is full.|
// +---------------------------------------------------------------------------------------------------------------------+
// | data_valid     | Output    | 1                                     | rd_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Read Data Valid: When asserted, this signal indicates that valid data is available on the output bus (dout).        |
// +---------------------------------------------------------------------------------------------------------------------+
// | dbiterr        | Output    | 1                                     | rd_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Double Bit Error: Indicates that the ECC decoder detected a double-bit error and data in the FIFO core is corrupted.|
// +---------------------------------------------------------------------------------------------------------------------+
// | din            | Input     | WRITE_DATA_WIDTH                      | wr_clk  | NA          | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Write Data: The input data bus used when writing the FIFO.                                                          |
// +---------------------------------------------------------------------------------------------------------------------+
// | dout           | Output    | READ_DATA_WIDTH                       | rd_clk  | NA          | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Read Data: The output data bus is driven when reading the FIFO.                                                     |
// +---------------------------------------------------------------------------------------------------------------------+
// | empty          | Output    | 1                                     | rd_clk  | Active-high | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Empty Flag: When asserted, this signal indicates that the FIFO is empty.                                            |
// | Read requests are ignored when the FIFO is empty, initiating a read while empty is not destructive to the FIFO.     |
// +---------------------------------------------------------------------------------------------------------------------+
// | full           | Output    | 1                                     | wr_clk  | Active-high | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Full Flag: When asserted, this signal indicates that the FIFO is full.                                              |
// | Write requests are ignored when the FIFO is full, initiating a write when the FIFO is full is not destructive       |
// | to the contents of the FIFO.                                                                                        |
// +---------------------------------------------------------------------------------------------------------------------+
// | injectdbiterr  | Input     | 1                                     | wr_clk  | Active-high | Tie to 1'b0            |
// |---------------------------------------------------------------------------------------------------------------------|
// | Double Bit Error Injection: Injects a double bit error if the ECC feature is used on block RAMs or                  |
// | UltraRAM macros.                                                                                                    |
// +---------------------------------------------------------------------------------------------------------------------+
// | injectsbiterr  | Input     | 1                                     | wr_clk  | Active-high | Tie to 1'b0            |
// |---------------------------------------------------------------------------------------------------------------------|
// | Single Bit Error Injection: Injects a single bit error if the ECC feature is used on block RAMs or                  |
// | UltraRAM macros.                                                                                                    |
// +---------------------------------------------------------------------------------------------------------------------+
// | overflow       | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Overflow: This signal indicates that a write request (wren) during the prior clock cycle was rejected,              |
// | because the FIFO is full. Overflowing the FIFO is not destructive to the contents of the FIFO.                      |
// +---------------------------------------------------------------------------------------------------------------------+
// | prog_empty     | Output    | 1                                     | rd_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Programmable Empty: This signal is asserted when the number of words in the FIFO is less than or equal              |
// | to the programmable empty threshold value.                                                                          |
// | It is de-asserted when the number of words in the FIFO exceeds the programmable empty threshold value.              |
// +---------------------------------------------------------------------------------------------------------------------+
// | prog_full      | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Programmable Full: This signal is asserted when the number of words in the FIFO is greater than or equal            |
// | to the programmable full threshold value.                                                                           |
// | It is de-asserted when the number of words in the FIFO is less than the programmable full threshold value.          |
// +---------------------------------------------------------------------------------------------------------------------+
// | rd_clk         | Input     | 1                                     | NA      | Rising edge | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Read clock: Used for read operation. rd_clk must be a free running clock.                                           |
// +---------------------------------------------------------------------------------------------------------------------+
// | rd_data_count  | Output    | RD_DATA_COUNT_WIDTH                   | rd_clk  | NA          | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Read Data Count: This bus indicates the number of words read from the FIFO.                                         |
// +---------------------------------------------------------------------------------------------------------------------+
// | rd_en          | Input     | 1                                     | rd_clk  | Active-high | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Read Enable: If the FIFO is not empty, asserting this signal causes data (on dout) to be read from the FIFO.        |
// |                                                                                                                     |
// |   Must be held active-low when rd_rst_busy is active high.                                                          |
// +---------------------------------------------------------------------------------------------------------------------+
// | rd_rst_busy    | Output    | 1                                     | rd_clk  | Active-high | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Read Reset Busy: Active-High indicator that the FIFO read domain is currently in a reset state.                     |
// +---------------------------------------------------------------------------------------------------------------------+
// | rst            | Input     | 1                                     | wr_clk  | Active-high | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Reset: Must be synchronous to wr_clk. The clock(s) can be unstable at the time of applying reset, but reset must be released only after the clock(s) is/are stable.|
// +---------------------------------------------------------------------------------------------------------------------+
// | sbiterr        | Output    | 1                                     | rd_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Single Bit Error: Indicates that the ECC decoder detected and fixed a single-bit error.                             |
// +---------------------------------------------------------------------------------------------------------------------+
// | sleep          | Input     | 1                                     | NA      | Active-high | Tie to 1'b0            |
// |---------------------------------------------------------------------------------------------------------------------|
// | Dynamic power saving: If sleep is High, the memory/fifo block is in power saving mode.                              |
// +---------------------------------------------------------------------------------------------------------------------+
// | underflow      | Output    | 1                                     | rd_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Underflow: Indicates that the read request (rd_en) during the previous clock cycle was rejected                     |
// | because the FIFO is empty. Under flowing the FIFO is not destructive to the FIFO.                                   |
// +---------------------------------------------------------------------------------------------------------------------+
// | wr_ack         | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Write Acknowledge: This signal indicates that a write request (wr_en) during the prior clock cycle is succeeded.    |
// +---------------------------------------------------------------------------------------------------------------------+
// | wr_clk         | Input     | 1                                     | NA      | Rising edge | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Write clock: Used for write operation. wr_clk must be a free running clock.                                         |
// +---------------------------------------------------------------------------------------------------------------------+
// | wr_data_count  | Output    | WR_DATA_COUNT_WIDTH                   | wr_clk  | NA          | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Write Data Count: This bus indicates the number of words written into the FIFO.                                     |
// +---------------------------------------------------------------------------------------------------------------------+
// | wr_en          | Input     | 1                                     | wr_clk  | Active-high | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Write Enable: If the FIFO is not full, asserting this signal causes data (on din) to be written to the FIFO.        |
// |                                                                                                                     |
// |   Must be held active-low when rst or wr_rst_busy is active high.                                                   |
// +---------------------------------------------------------------------------------------------------------------------+
// | wr_rst_busy    | Output    | 1                                     | wr_clk  | Active-high | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Write Reset Busy: Active-High indicator that the FIFO write domain is currently in a reset state.                   |
// +---------------------------------------------------------------------------------------------------------------------+


// xpm_fifo_async : In order to incorporate this function into the design,
//    Verilog     : the following instance declaration needs to be placed
//    instance    : in the body of the design code.  The instance name
//  declaration   : (xpm_fifo_async_inst) and/or the port declarations within the
//      code      : parenthesis may be changed to properly reference and
//                : connect this function to the design.  All inputs
//                : and outputs must be connected.

//  Please reference the appropriate libraries guide for additional information on the XPM modules.

//  <-----Cut code below this line---->

   // xpm_fifo_async: Asynchronous FIFO
   // Xilinx Parameterized Macro, version 2023.1

   xpm_fifo_async #(
      .CASCADE_HEIGHT(0),        // DECIMAL
      .CDC_SYNC_STAGES(2),       // DECIMAL
      .DOUT_RESET_VALUE("0"),    // String
      .ECC_MODE("no_ecc"),       // String
      .FIFO_MEMORY_TYPE("auto"), // String
      .FIFO_READ_LATENCY(1),     // DECIMAL
      .FIFO_WRITE_DEPTH(N),      // DECIMAL
      .FULL_RESET_VALUE(0),      // DECIMAL
      .PROG_EMPTY_THRESH(10),    // DECIMAL
      .PROG_FULL_THRESH(10),     // DECIMAL
      .RD_DATA_COUNT_WIDTH(1),   // DECIMAL
      .READ_DATA_WIDTH(B),       // DECIMAL
      // .READ_MODE("std"),         // String
      .READ_MODE("fwft"),        // String
      .RELATED_CLOCKS(0),        // DECIMAL
      .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      // .USE_ADV_FEATURES("0707"), // String
      .USE_ADV_FEATURES("0000"), // String
      .WAKEUP_TIME(0),           // DECIMAL
      .WRITE_DATA_WIDTH(B),      // DECIMAL
      .WR_DATA_COUNT_WIDTH(1)    // DECIMAL
   )
   xpm_fifo_async_inst (
      .almost_empty(),   // 1-bit output: Almost Empty : When asserted, this signal indicates that
                                     // only one more read can be performed before the FIFO goes to empty.

      .almost_full(),     // 1-bit output: Almost Full: When asserted, this signal indicates that
                                     // only one more write can be performed before the FIFO is full.

      .data_valid(),       // 1-bit output: Read Data Valid: When asserted, this signal indicates
                                     // that valid data is available on the output bus (dout).

      .dbiterr(),             // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected
                                     // a double-bit error and data in the FIFO core is corrupted.

      .dout(dout),                   // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
                                     // when reading the FIFO.

      .empty(empty),                 // 1-bit output: Empty Flag: When asserted, this signal indicates that the
                                     // FIFO is empty. Read requests are ignored when the FIFO is empty,
                                     // initiating a read while empty is not destructive to the FIFO.

      .full(full),                   // 1-bit output: Full Flag: When asserted, this signal indicates that the
                                     // FIFO is full. Write requests are ignored when the FIFO is full,
                                     // initiating a write when the FIFO is full is not destructive to the
                                     // contents of the FIFO.

      .overflow(),           // 1-bit output: Overflow: This signal indicates that a write request
                                     // (wren) during the prior clock cycle was rejected, because the FIFO is
                                     // full. Overflowing the FIFO is not destructive to the contents of the
                                     // FIFO.

      .prog_empty(),       // 1-bit output: Programmable Empty: This signal is asserted when the
                                     // number of words in the FIFO is less than or equal to the programmable
                                     // empty threshold value. It is de-asserted when the number of words in
                                     // the FIFO exceeds the programmable empty threshold value.

      .prog_full(),         // 1-bit output: Programmable Full: This signal is asserted when the
                                     // number of words in the FIFO is greater than or equal to the
                                     // programmable full threshold value. It is de-asserted when the number of
                                     // words in the FIFO is less than the programmable full threshold value.

      .rd_data_count(), // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the
                                     // number of words read from the FIFO.

      .rd_rst_busy(),     // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
                                     // domain is currently in a reset state.

      .sbiterr(),             // 1-bit output: Single Bit Error: Indicates that the ECC decoder detected
                                     // and fixed a single-bit error.

      .underflow(),         // 1-bit output: Underflow: Indicates that the read request (rd_en) during
                                     // the previous clock cycle was rejected because the FIFO is empty. Under
                                     // flowing the FIFO is not destructive to the FIFO.

      .wr_ack(),               // 1-bit output: Write Acknowledge: This signal indicates that a write
                                     // request (wr_en) during the prior clock cycle is succeeded.

      .wr_data_count(), // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
                                     // the number of words written into the FIFO.

      .wr_rst_busy(),     // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
                                     // write domain is currently in a reset state.

      .din(din),                     // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
                                     // writing the FIFO.

      .injectdbiterr(1'b0), // 1-bit input: Double Bit Error Injection: Injects a double bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .injectsbiterr(1'b0), // 1-bit input: Single Bit Error Injection: Injects a single bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .rd_clk(rd_clk),               // 1-bit input: Read clock: Used for read operation. rd_clk must be a free
                                     // running clock.

      .rd_en(rd_en),                 // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
                                     // signal causes data (on dout) to be read from the FIFO. Must be held
                                     // active-low when rd_rst_busy is active high.

      .rst(wr_rst),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
                                     // unstable at the time of applying reset, but reset must be released only
                                     // after the clock(s) is/are stable.

      .sleep(1'b0),                 // 1-bit input: Dynamic power saving: If sleep is High, the memory/fifo
                                     // block is in power saving mode.

      .wr_clk(wr_clk),               // 1-bit input: Write clock: Used for write operation. wr_clk must be a
                                     // free running clock.

      .wr_en(wr_en)                  // 1-bit input: Write Enable: If the FIFO is not full, asserting this
                                     // signal causes data (on din) to be written to the FIFO. Must be held
                                     // active-low when rst or wr_rst_busy is active high.

   );

   // End of xpm_fifo_async_inst instantiation

endmodule
