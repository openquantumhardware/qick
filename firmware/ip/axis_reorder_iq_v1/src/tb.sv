module tb;

// Number of bits.
parameter B = 4;

// Number of lanes.
parameter L = 4;


// s_* and m_* reset/clock.
reg				aresetn			;
reg				aclk = 0		;

// S_AXIS for data input.
reg	[2*B*L-1:0]	s_axis_tdata	;
reg				s_axis_tvalid	;
wire			s_axis_tready	;

// M_AXIS for data output.
wire[2*B*L-1:0]	m_axis_tdata	;
wire			m_axis_tvalid	;
reg				m_axis_tready	;

// Data vectors.
reg [B-1:0]		din_real_ii [L];
reg [B-1:0]		din_imag_ii [L];

genvar i;
generate
	for (i=0; i<L; i=i+1) begin
		assign s_axis_tdata [i*B 	 +: B] = din_real_ii[i];
		assign s_axis_tdata [L*B+i*B +: B] = din_imag_ii[i];
	end
endgenerate

axis_reorder_iq_v1
	#(
		// Number of bits.
		.B(B),
		
		// Number of lanes.
		.L(L)
	)
	DUT
	( 
		// s_* and m_* reset/clock.
		.aresetn		,
		.aclk			,

    	// S_AXIS for data input.
		.s_axis_tdata	,
		.s_axis_tvalid	,
		.s_axis_tready	,

		// M_AXIS for data output.
		.m_axis_tdata	,
		.m_axis_tvalid	,
		.m_axis_tready
	);

initial begin
	aresetn			<= 0;
	s_axis_tvalid	<= 1;
	s_axis_tdata	<= 0;
	m_axis_tready	<= 1;
	#200;
	aresetn			<= 1;

	#300;

	for (int i=0; i<10000; i=i+1) begin
		@(posedge aclk);
		for (int j=0; j<L; j=j+1) begin
			din_real_ii[j] <= $random;
			din_imag_ii[j] <= $random;
		end
	end
end

// aclk.
always #5 aclk <= ~aclk;

endmodule

