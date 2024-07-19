module tb();

parameter N = 32;
parameter L = 4;

reg				aresetn;
reg				aclk;

wire[2*L*32-1:0]s_axis_tdata;
reg				s_axis_tlast;
reg				s_axis_tvalid;
wire			s_axis_tready;

wire[L*32-1:0]	m_axis_tdata;
wire			m_axis_tvalid;

reg	[31:0]		QOUT_REG;

// Input data.
wire[31:0]	din_ii 		[2*L];
reg [15:0]	din_real_ii [2*L];
reg [15:0]	din_imag_ii [2*L];

// Output data.
wire[31:0]	dout_ii 	[L];
wire[15:0]	dout_real_ii[L];
wire[15:0]	dout_imag_ii[L];

// Debug.
reg				faclk;
reg	[31:0]		debug_v;
reg	[15:0]		debug_v_real;
reg	[15:0]		debug_v_imag;


// TB control.
reg tb_data 	= 0;
reg tb_data_done= 0;
reg	tb_write_out= 0;

generate
genvar ii;
for (ii = 0; ii < L; ii = ii + 1) begin
	// Input data.
	assign din_ii		[ii]				= {din_imag_ii[ii]	, din_real_ii[ii]};
	assign din_ii		[ii+L]				= {din_imag_ii[ii+L]	, din_real_ii[ii+L]};

    assign s_axis_tdata	[32*ii 		+: 32] 	= din_ii[ii];
    assign s_axis_tdata	[32*(ii+L) 	+: 32] 	= din_ii[ii+L];

	assign dout_ii		[ii] 				= m_axis_tdata[32*ii +: 32];
	assign dout_real_ii	[ii] 				= dout_ii[ii][15:0];
	assign dout_imag_ii	[ii] 				= dout_ii[ii][31:16];
end
endgenerate

// DUT.
pfb 
	#(
		.N(N),
		.L(L)
	)
	DUT
	(
		// Reset and clock.
		.aresetn		,
		.aclk			,

		// S_AXIS for input data.
		.s_axis_tdata	,
		.s_axis_tlast	,
		.s_axis_tvalid	,
		.s_axis_tready	,

		// M_AXIS for output data.
		.m_axis_tdata	,
		.m_axis_tvalid	,

		// Registers.
		.QOUT_REG
	);

initial begin
	aresetn	<= 0;
	#500;
	aresetn	<= 1;

	#500;

	QOUT_REG	<= 0;

	// Start data.
	tb_data 		<= 1;
	#10000;
	tb_write_out 	<= 1;
	wait (tb_data_done);
	tb_write_out 	<= 0;

end

// Input data.
initial begin
	real pi;
	real w;
	int n;

	s_axis_tlast	<= 0;
	s_axis_tvalid 	<= 0;

	wait(tb_data);
	@(posedge aclk);
	
	n = 0;
	pi = 3.1415;
	w  = 0.001;
	for (int k=0; k<500; k=k+1) begin
		for (int i=0; i<N/(2*L); i=i+1) begin
			@(posedge aclk);
			s_axis_tvalid	<= 1;
			if (i == (N/(2*L))-1)
				s_axis_tlast <= 1;
			else
				s_axis_tlast <= 0;

			for (int j=0; j<2*L; j=j+1) begin
				if (i == 0) begin
					if (j == 5) begin
						din_real_ii [j] <= 30000;
						din_imag_ii [j] <= 0;
					end
					else begin
						din_real_ii [j] <= 0;
						din_imag_ii [j] <= 0;
					end
				end
				else begin
					din_real_ii [j] <= 0;
					din_imag_ii [j] <= 0;
				end
			end
		end
	end

	@(posedge aclk);
	tb_data_done <= 1;

end

// Parallel to serial conversion.
initial begin
    while(1) begin
		@(posedge aclk);
		for (int i=0; i<L; i=i+1) begin
			@(posedge faclk);
			debug_v 		<= m_axis_tdata [i*32 +: 32];
			debug_v_real	<= debug_v[15:0];
			debug_v_imag	<= debug_v[31:16];
		end
	end
end

// Write output into file.
initial begin
	int fd;
	int i;
	shortint real_d, imag_d;

	// Output file.
	fd = $fopen("../../../../../tb/dout.csv","w");

	// Data format.
	$fdisplay(fd, "real, imag");

	wait (tb_write_out);

	while (tb_write_out) begin
		@(posedge faclk);
		real_d = debug_v_real;
		imag_d = debug_v_imag;
		$fdisplay(fd,"%d,%d",real_d,imag_d);
	end

	$display("Closing file, t = %0t", $time);
	$fclose(fd);
end

always begin
	aclk <= 0;
	#8;
	aclk <= 1;
	#8;
end  

always begin
	faclk <= 0;
	#2;
	faclk <= 1;
	#2;
end  

endmodule

