module tb();

// Number of channels.
parameter N = 64;

// Number of Lanes (Input).
parameter L = 4;

// Reset and clock.
reg						aresetn			;
reg						aclk			;

// S_AXIS for input data.
reg						s_axis_tvalid	;
wire	[L*32-1:0]		s_axis_tdata	;

// M_AXIS for output data.
wire					m_axis_tvalid	;
wire					m_axis_tlast	;
wire	[2*L*32-1:0]	m_axis_tdata	;

// Registers.
reg		[7:0]			QOUT_REG		;

/**************/
/* Test Bench */
/**************/
localparam	NCH = N/(2*L);
// x4 clock.
reg				aclk_x4						;
reg		[15:0]	din_real					;
reg		[15:0]	din_imag					;
reg		[31:0]	din	[L]						;

// x8 clock.
reg				aclk_x8						;

// TDM Demux outputs.
reg						tdm_sync			;
wire	[NCH*32-1:0]	tdm_dout	[2*L]	;
wire	[2*L-1:0]		tdm_valid			;
wire signed [15:0]		dout_real_ii 		[2*L][NCH]	;
wire signed [15:0]		dout_imag_ii 		[2*L][NCH]	;


/****************/
/* Architecture */
/****************/
genvar i,j;
generate
	// Input data.
	for (i=0; i<L; i=i+1) begin
		assign s_axis_tdata [i*32 +: 32] = din [i];
	end

	for (i=0; i<2*L; i=i+1) begin

		// TDM Demux.
		tdm_demux
			#(
				.NCH(NCH	),
				.B	(32		)
			)
			tdm_demux_i
			(
				// Reset and clock.
				.rstn		(aresetn					),
				.clk		(aclk						),
		
				// Resync.
				.sync		(tdm_sync					),
		
				// Data input.
				.din		(m_axis_tdata [i*32 +: 32]	),
				.din_last	(m_axis_tlast				),
				.din_valid	(m_axis_tvalid				),
		
				// Data output.
				.dout		(tdm_dout	[i]				),
				.dout_valid	(tdm_valid	[i]				)
			);

		for (j=0; j<NCH; j=j+1) begin
			assign dout_real_ii[i][j] = tdm_dout[i][2*j*16 	+: 16];
			assign dout_imag_ii[i][j] = tdm_dout[i][(2*j+1)*16 +: 16];
		end
	end
endgenerate

// Data in -> parallel.
always @(posedge aclk) begin
	for (int i=0; i<L; i=i+1) begin
		@(posedge aclk_x4);
		din [i] <= {din_imag, din_real};
	end
end

// DUT.
pfb
	#(
		// Number of channels.
		.N(N),
		
		// Number of Lanes (Input).
		.L(L)
	)
	DUT
	(
		// Reset and clock.
		.aresetn		,
		.aclk			,

		// S_AXIS for input data.
		.s_axis_tvalid	,
		.s_axis_tdata	,

		// M_AXIS for output data.
		.m_axis_tvalid	,
		.m_axis_tlast	,
		.m_axis_tdata	,

		// Registers.
		.QOUT_REG
	);

initial begin
	// Reset sequence.
	aresetn 		<= 0;
	s_axis_tvalid	<= 1;
	QOUT_REG		<= 5;
	tdm_sync		<= 1;
	#500;
	aresetn 		<= 1;

	#10000;

	tdm_sync		<= 0;
end

// Data input.
initial begin
	real w0;
	int n;

	w0 = 2*3.14159/N*8.11;

	n = 0;
	while(1) begin
		@(posedge aclk_x4);
		din_real <= 0.99*2**15*$cos(w0*n);
		din_imag <= 0.99*2**15*$sin(w0*n);
		n = n + 1;
	end
end


always begin
	aclk <= 0;
	#8;
	aclk <= 1;
	#8;
end  

// x4 clock.
always begin
	aclk_x4 <= 0;
	#2;
	aclk_x4 <= 1;
	#2;
end  

// x8 clock.
always begin
	aclk_x8 <= 0;
	#1;
	aclk_x8 <= 1;
	#1;
end  

endmodule

