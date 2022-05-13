module ddsprod
	(
		// Reset and clock.
		aresetn			,
		aclk			,

		// S_AXIS for input data.
		s_axis_tvalid	,
		s_axis_tdata	,

		// M_AXIS for output data.
		m_axis_tvalid	,
		m_axis_tdata	,

		// Registers.
		FREQ_REG		,
		OUTSEL_REG
	);

/*********/
/* Ports */
/*********/
input			aresetn;
input			aclk;

input			s_axis_tvalid;
input	[31:0]	s_axis_tdata;

output			m_axis_tvalid;
output	[31:0]	m_axis_tdata;

input	[31:0]	FREQ_REG;
input	[1:0]	OUTSEL_REG;

/********************/
/* Internal signals */
/********************/
// Input valid.
reg					tvalid_r1;
reg					tvalid_r2;
reg					tvalid_r3;

// DDS valid input.
reg	dds_valid_r;

// Input data.
reg			[31:0]	di_r1;
reg			[31:0]	di_r2;
reg			[31:0]	di_r3;
wire signed [15:0]	di_real;
wire signed	[15:0]	di_imag;

// DDS output.
wire 		[31:0]	dds_dout;
reg 		[31:0]	dds_dout_r1;
reg 		[31:0]	dds_dout_r2;
reg 		[31:0]	dds_dout_r3;
wire signed [15:0]	dds_real;
wire signed [15:0]	dds_imag;

// Partial products.
wire signed	[31:0]	do_real_a;
wire signed	[31:0]	do_real_b;
reg  signed	[31:0]	do_real_a_r1;
reg  signed	[31:0]	do_real_b_r1;
wire signed	[31:0]	do_imag_a;
wire signed	[31:0]	do_imag_b;
reg  signed	[31:0]	do_imag_a_r1;
reg  signed	[31:0]	do_imag_b_r1;

// Full out.
wire signed [31:0]	do_real;
reg  signed [15:0]	do_real_r1;
wire signed [31:0]	do_imag;
reg  signed [15:0]	do_imag_r1;

// Muxed output.
wire		[31:0]	do_mux;

/**********************/
/* Begin Architecture */
/**********************/
// DDS instance.
dds_0 dds_i 
	(
 		.aclk				(aclk			),
  		.s_axis_phase_tvalid(dds_valid_r	),
  		.s_axis_phase_tdata	(FREQ_REG		),
  		.m_axis_data_tvalid	(				),
  		.m_axis_data_tdata	(dds_dout		)
	);

// Input data.
assign di_real 		= di_r1[15:0];
assign di_imag 		= di_r1[31:16];

// DDS output.
assign dds_real		= dds_dout_r1[15:0];
assign dds_imag		= dds_dout_r1[31:16];

// Partial products.
assign do_real_a	= di_real*dds_real;
assign do_real_b	= di_imag*dds_imag;
assign do_imag_a	= di_real*dds_imag;
assign do_imag_b	= di_imag*dds_real;

// Full out.
assign do_real		= do_real_a_r1 - do_real_b_r1;
assign do_imag		= do_imag_a_r1 + do_imag_b_r1;

// Muxed output.
assign do_mux		=	(OUTSEL_REG == 0)?	{do_imag_r1,do_real_r1}	:
						(OUTSEL_REG == 1)?	di_r3					:
						(OUTSEL_REG == 2)?	dds_dout_r3				: 32'h0000_0000;

// Registers.
always @(posedge aclk) begin
	if (~aresetn) begin
		// Input valid.
		tvalid_r1		<= 0;
		tvalid_r2		<= 0;
		tvalid_r3		<= 0;

		// DDS valid input.
		dds_valid_r 	<= 0;

		// Input data.
		di_r1			<= 0;
		di_r2			<= 0;
		di_r3			<= 0;

		// DDS output.
		dds_dout_r1		<= 0;
		dds_dout_r2		<= 0;
		dds_dout_r3		<= 0;

		// Partial products.
		do_real_a_r1	<= 0;
		do_real_b_r1	<= 0;
		do_imag_a_r1	<= 0;
		do_imag_b_r1	<= 0;

		// Full out.
		do_real_r1		<= 0;
		do_imag_r1		<= 0;
	end 
	else begin
		// Input valid.
		tvalid_r1		<= s_axis_tvalid;
		tvalid_r2		<= tvalid_r1;
		tvalid_r3		<= tvalid_r2;

		// DDS valid input.
		dds_valid_r 	<= 1;

		// Input data.
		di_r1			<= s_axis_tdata;
		di_r2			<= di_r1;
		di_r3			<= di_r2;

		// DDS output.
		dds_dout_r1		<= dds_dout;
		dds_dout_r2		<= dds_dout_r1;
		dds_dout_r3		<= dds_dout_r2;

		// Partial products.
		do_real_a_r1	<= do_real_a;
		do_real_b_r1	<= do_real_b;
		do_imag_a_r1	<= do_imag_a;
		do_imag_b_r1	<= do_imag_b;

		// Full out.
		do_real_r1		<= do_real[30:15];
		do_imag_r1		<= do_imag[30:15];
	end
end

// Assign outputs.
assign m_axis_tvalid = tvalid_r3;
assign m_axis_tdata	 = do_mux;

endmodule

