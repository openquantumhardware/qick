module tb();

parameter B = 8;
parameter L = 4;
parameter N = 256;

// Number of packets.
parameter M = N/(2*L);

reg				aresetn;
reg				aclk;

reg				s_axis_tvalid;
reg				s_axis_tlast;
reg	[2*L*B-1:0]	s_axis_tdata;

wire			m_axis_tvalid;
wire			m_axis_tlast;
wire[2*L*B-1:0]	m_axis_tdata;

// Input/output data.
reg	[B-1:0]	din_ii [0:2*L-1];
wire[B-1:0]	dout_ii [0:2*L-1];

// TB control.
reg tb_data 	= 0;

generate
genvar ii;
for (ii = 0; ii < 2*L; ii = ii + 1) begin
    assign s_axis_tdata[B*ii +: B] = din_ii[ii];
	assign dout_ii[ii] = m_axis_tdata[B*ii +: B];
end
endgenerate

// DUT.
pfb_switch
	#(
		.B(B),
		.L(L),
		.N(N)
	)
	DUT
	(
		// Reset and clock.
		.aresetn		(aresetn		),
		.aclk			(aclk			),

		// S_AXIS for input data.
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tlast	(s_axis_tlast	),
		.s_axis_tdata	(s_axis_tdata	),

		// M_AXIS for output data.
		.m_axis_tvalid	(m_axis_tvalid	),
		.m_axis_tlast	(m_axis_tlast	),
		.m_axis_tdata	(m_axis_tdata	)
	);

initial begin
	aresetn	<= 0;
	#500;
	aresetn	<= 1;

	#500;

	// Start data.
	tb_data 		<= 1;

end

// Input data.
initial begin
	s_axis_tdata	<= 0;
	s_axis_tlast  	<= 0;
	s_axis_tvalid 	<= 0;

	wait(tb_data);
	@(posedge aclk);
	
	for (int i=0; i<20; i = i+1) begin
		for (int j=0; j<10; j = j+1) begin
			for (int k=0; k<M; k = k+1) begin
				@(posedge aclk);
				s_axis_tvalid 	<= 1;
					if (k == M-1)
						s_axis_tlast <= 1;
					else
						s_axis_tlast <= 0;
				din_ii[0] <= 0+2*L*k;
				din_ii[1] <= 1+2*L*k;
				din_ii[2] <= 2+2*L*k;
				din_ii[3] <= 3+2*L*k;
				din_ii[4] <= 4+2*L*k;
				din_ii[5] <= 5+2*L*k;
				din_ii[6] <= 6+2*L*k;
				din_ii[7] <= 7+2*L*k;
			end
		end

		@(posedge aclk);
		s_axis_tvalid 	<= 1;
		s_axis_tlast	<= 0;

		@(posedge aclk);
		s_axis_tvalid 	<= 1;
		s_axis_tlast	<= 1;
	end
end

always begin
	aclk <= 0;
	#5;
	aclk <= 1;
	#5;
end  

endmodule

