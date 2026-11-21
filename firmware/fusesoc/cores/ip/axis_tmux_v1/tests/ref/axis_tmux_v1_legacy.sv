// Reference copy of the legacy RTL, used only as the golden model by axis_tmux_v1_tc00.sv.
// Source: openquantumhardware/qick firmware/ip/axis_tmux_v1/src/{axis_tmux_v1.sv,tmux.sv} (QICK:QICK:axis_tmux_v1:1.0),
// unchanged except for the module names (*_legacy).
module axis_tmux_v1_legacy
	#(
		// Number of outputs.
		parameter N = 8,

		// Number of data bits.
		parameter B = 16
	)
	(
		// Reset and clock.
		input	wire			aresetn			,
		input	wire			aclk			,

		// S_AXIS for input data.
		output	wire 			s_axis_tready	,
		input	wire 			s_axis_tvalid	,
		input	wire 	[B-1:0]	s_axis_tdata	,

		// M_AXIS for output data.
		output	wire			m0_axis_tvalid	,
		output	wire	[B-1:0]	m0_axis_tdata	,

		output	wire			m1_axis_tvalid	,
		output	wire	[B-1:0]	m1_axis_tdata	,

		output	wire			m2_axis_tvalid	,
		output	wire	[B-1:0]	m2_axis_tdata	,

		output	wire			m3_axis_tvalid	,
		output	wire	[B-1:0]	m3_axis_tdata	,

		output	wire			m4_axis_tvalid	,
		output	wire	[B-1:0]	m4_axis_tdata	,

		output	wire			m5_axis_tvalid	,
		output	wire	[B-1:0]	m5_axis_tdata	,

		output	wire			m6_axis_tvalid	,
		output	wire	[B-1:0]	m6_axis_tdata	,

		output	wire			m7_axis_tvalid	,
		output	wire	[B-1:0]	m7_axis_tdata
	);

/**********************/
/* Begin Architecture */
/**********************/
tmux_legacy
	#(
		// Number of outputs.
		.N(N),

		// Number of data bits.
		.B(B)
	)
	tmux_i
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tready	(s_axis_tready	),
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tdata	(s_axis_tdata	),

		// M_AXIS for output data.
		.m0_axis_tvalid	(m0_axis_tvalid	),
		.m0_axis_tdata	(m0_axis_tdata	),

		.m1_axis_tvalid	(m1_axis_tvalid	),
		.m1_axis_tdata	(m1_axis_tdata	),

		.m2_axis_tvalid	(m2_axis_tvalid	),
		.m2_axis_tdata	(m2_axis_tdata	),

		.m3_axis_tvalid	(m3_axis_tvalid	),
		.m3_axis_tdata	(m3_axis_tdata	),

		.m4_axis_tvalid	(m4_axis_tvalid	),
		.m4_axis_tdata	(m4_axis_tdata	),

		.m5_axis_tvalid	(m5_axis_tvalid	),
		.m5_axis_tdata	(m5_axis_tdata	),

		.m6_axis_tvalid	(m6_axis_tvalid	),
		.m6_axis_tdata	(m6_axis_tdata	),

		.m7_axis_tvalid	(m7_axis_tvalid	),
		.m7_axis_tdata	(m7_axis_tdata	)
	);

endmodule

module tmux_legacy
	#(
		// Number of outputs.
		parameter N = 8	,

		// Number of data bits.
		parameter B = 16
	)
	(
		// Reset and clock.
		input	wire			aresetn			,
		input	wire			aclk			,

		// S_AXIS for input data.
		output	wire 			s_axis_tready	,
		input	wire 			s_axis_tvalid	,
		input	wire 	[B-1:0]	s_axis_tdata	,

		// M_AXIS for output data.
		output	wire			m0_axis_tvalid	,
		output	wire	[B-1:0]	m0_axis_tdata	,

		output	wire			m1_axis_tvalid	,
		output	wire	[B-1:0]	m1_axis_tdata	,

		output	wire			m2_axis_tvalid	,
		output	wire	[B-1:0]	m2_axis_tdata	,

		output	wire			m3_axis_tvalid	,
		output	wire	[B-1:0]	m3_axis_tdata	,

		output	wire			m4_axis_tvalid	,
		output	wire	[B-1:0]	m4_axis_tdata	,

		output	wire			m5_axis_tvalid	,
		output	wire	[B-1:0]	m5_axis_tdata	,

		output	wire			m6_axis_tvalid	,
		output	wire	[B-1:0]	m6_axis_tdata	,

		output	wire			m7_axis_tvalid	,
		output	wire	[B-1:0]	m7_axis_tdata
	);

/********************/
/* Internal signals */
/********************/
// Pipeline registers.
reg				valid_r1	;
reg				valid_r2	;
reg		[B-1:0]	din_r1		;
reg		[B-1:0]	din_r2		;

// Selection.
wire	[7:0]	sel_full	;
wire	[2:0]	sel_8		;

// Output valid/data vectors.
wire			valid_v	[N]	;
wire	[B-1:0]	data_v	[N]	;

/**********************/
/* Begin Architecture */
/**********************/

// Selection (upper 8 bits).
assign sel_full	= din_r2 [B-1 -: 8];

// Reduced selection for fewer ports.
assign sel_8	= sel_full [2:0];

genvar i;
generate
	for (i=0; i<N; i=i+1) begin
		assign valid_v	[i] = (sel_8 == i)? valid_r2 : 1'b0;
		assign data_v	[i]	= din_r2;
	end
endgenerate

// Registers.
always @(posedge aclk) begin
	if (~aresetn) begin
		valid_r1	<= 0;
		valid_r2	<= 0;
		din_r1		<= 0;
		din_r2		<= 0;
	end
	else begin
		valid_r1	<= s_axis_tvalid;
		valid_r2	<= valid_r1;
		din_r1		<= s_axis_tdata;
		din_r2		<= din_r1;

	end
end

// Output vector to data.
assign m0_axis_tvalid	= valid_v	[0] ;
assign m1_axis_tvalid	= valid_v	[1] ;
assign m2_axis_tvalid	= valid_v	[2] ;
assign m3_axis_tvalid	= valid_v	[3] ;
assign m4_axis_tvalid	= valid_v	[4] ;
assign m5_axis_tvalid	= valid_v	[5] ;
assign m6_axis_tvalid	= valid_v	[6] ;
assign m7_axis_tvalid	= valid_v	[7] ;

assign m0_axis_tdata	= data_v	[0] ;
assign m1_axis_tdata	= data_v	[1] ;
assign m2_axis_tdata	= data_v	[2] ;
assign m3_axis_tdata	= data_v	[3] ;
assign m4_axis_tdata	= data_v	[4] ;
assign m5_axis_tdata	= data_v	[5] ;
assign m6_axis_tdata	= data_v	[6] ;
assign m7_axis_tdata	= data_v	[7] ;

// Always ready.
assign s_axis_tready	= 1'b1 ;

endmodule

