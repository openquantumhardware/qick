module tb();

// Number of channels.
parameter N = 64;

// Number of Lanes (Input).
parameter L = 4;

// Reset and clock.
reg					aresetn			;
reg					aclk			;

// S_AXIS for input data.
reg					s_axis_tvalid	;
wire	[L*32-1:0]	s_axis_tdata	;

// M_AXIS for output data.
wire				m_axis_tvalid	;
wire	[31:0]		m0_axis_tdata	;
wire	[31:0]		m1_axis_tdata	;
wire	[31:0]		m2_axis_tdata	;
wire	[31:0]		m3_axis_tdata	;

// Registers.
wire	[15:0]		ID0_REG			;
wire	[15:0]		ID1_REG			;
wire	[15:0]		ID2_REG			;
wire	[15:0]		ID3_REG			;

/**************/
/* Test Bench */
/**************/
localparam NCH = N/(2*L);
localparam NOUT = 4;

// x4 clock.
reg				aclk_x4						;
reg		[15:0]	din_real					;
reg		[15:0]	din_imag					;
reg		[31:0]	din	[L]						;

reg	[7:0] packet_r 	[NOUT];
reg	[7:0] index_r 	[NOUT];

/****************/
/* Architecture */
/****************/
genvar i,j;
generate
	// Input data.
	for (i=0; i<L; i=i+1) begin
		assign s_axis_tdata [i*32 +: 32] = din [i];
	end
endgenerate

// Data in -> parallel.
always @(posedge aclk) begin
	for (int i=0; i<L; i=i+1) begin
		@(posedge aclk_x4);
		din [i] <= {din_imag, din_real};
	end
end

// Registers.
assign ID0_REG = {index_r[0], packet_r[0]};
assign ID1_REG = {index_r[1], packet_r[1]};
assign ID2_REG = {index_r[2], packet_r[2]};
assign ID3_REG = {index_r[3], packet_r[3]};

// DUT.
pfb_top
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
		.m0_axis_tdata	,
		.m1_axis_tdata	,
		.m2_axis_tdata	,
		.m3_axis_tdata	,

		// Registers.
		.ID0_REG		,
		.ID1_REG		,
		.ID2_REG		,
		.ID3_REG
	);

initial begin
	// Reset sequence.
	aresetn 		<= 0;
	s_axis_tvalid	<= 1;
	for (int i=0; i<NOUT; i=i+1) begin
		packet_r[i] <= 0;
		index_r[i]	<= 0;
	end
	#500;
	aresetn 		<= 1;

	#10000;

	// Program output 0.
	packet_r[0] <= 1;
	index_r[0] <= 0;
	#100;

	// Program output 1.
	packet_r[1] <= 2;
	index_r[1] <= 7;
	#100;

	$display("Output 0: %d", (packet_r[0]*8 + index_r[0]));
	$display("Output 1: %d", (packet_r[1]*8 + index_r[1]));
end

// Data input.
initial begin
	real w0,p0,w1,p1;
	int n;

	w0 = 2*3.14159/N*8.11;
	p0 = 3.14159/5;
	w1 = 2*3.14159/N*23.11;
	p1 = 3.14159/1.456;

	n = 0;
	while(1) begin
		@(posedge aclk_x4);
		din_real <= 0.5*2**15*($cos(w0*n+p0)+$cos(w1*n+p1));
		din_imag <= 0.5*2**15*($sin(w0*n+p0)+$sin(w1*n+p1));
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

endmodule

