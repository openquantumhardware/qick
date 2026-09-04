module tb();

// Bits.
parameter B = 8;

// Number of lanes.
parameter L = 4;

// Clock.
reg					aclk			;

// S_AXIS for input data.
reg		[L*B-1:0]	s_axis_tdata	;
reg					s_axis_tlast	;

// M_AXIS for output data.
wire				m_axis_tvalid	;
wire	[B-1:0]		m_axis_tdata	;

// Registers.
wire	[15:0]		ID_REG			;

/**************/
/* Test Bench */
/**************/
// Number of transactions.
localparam N = 8;

reg	[7:0] packet_r;
reg	[7:0] index_r;

// Vector input for debug.
wire [B-1:0] din_v [L];

/****************/
/* Architecture */
/****************/
genvar i;
generate 
	for (i=0; i<L; i=i+1) begin
		assign din_v[i] = s_axis_tdata [i*B +: B];
	end
endgenerate

assign ID_REG = {index_r, packet_r};

// DUT.
pfb_chsel
	#(
		// Bits.
		.B(B),

		// Number of lanes.
		.L(L)
	)
	DUT
	(
		// Clock.
		.aclk			,

		// S_AXIS for input data.
		.s_axis_tdata	,
		.s_axis_tlast	,

		// M_AXIS for output data.
		.m_axis_tvalid	,
		.m_axis_tdata	,

		// Registers.
		.ID_REG
	);

initial begin
	s_axis_tdata 	<= 0;
	packet_r		<= 0;
	index_r			<= 3;

	for (int i=0; i<N; i=i+1) begin
		for (int j=0; j<1000; j=j+1) begin
			@(posedge aclk);
			packet_r <= i;
			s_axis_tdata <= $random;
		end
	end
end

// tlast.
initial begin
	s_axis_tlast <= 0;
	
	while(1) begin
		for (int i=0; i<N-1; i=i+1) begin
			@(posedge aclk);
			s_axis_tlast <= 0;
		end
		@(posedge aclk);
		s_axis_tlast <= 1;
	end
end

always begin
	aclk <= 0;
	#8;
	aclk <= 1;
	#8;
end  

endmodule

