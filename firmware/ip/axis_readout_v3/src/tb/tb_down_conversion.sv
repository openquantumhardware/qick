module tb();

localparam N = 4;

// Reset and clock.
reg				aresetn			;
reg				aclk			;

// Fifo interface.
wire			fifo_rd_en		;
wire			fifo_empty		;
wire[87:0]		fifo_dout		;

// s_axis for input data (N samples per clock).
wire			s_axis_tready	;
reg				s_axis_tvalid	;
wire[N*16-1:0]	s_axis_tdata	;

// m_axis for output data.
reg				m_axis_tready	;
wire			m_axis_tvalid	;
wire[N*32-1:0]	m_axis_tdata	;

// Waveform parameters.
reg	[31:0]		freq_r			;
reg	[31:0]		phase_r			;
reg	[15:0]		nsamp_r			;
reg	[1:0]		outsel_r		;
reg				mode_r			;
reg				phrst_r			;
reg	[3:0]		zero_r			;

// Fifo.
reg				fifo_wr_en		;
wire[87:0]		fifo_din		;

// Input data.
reg	[15:0]		din_r [N]		;

// Output data.
wire[15:0]		dout_real [N]	;
wire[15:0]		dout_imag [N]	;

// Fast clock for parallel/serial conversion.
reg				aclk_f			;
reg	[15:0]		din_r_f			;
reg	[15:0]		dout_real_f		;
reg	[15:0]		dout_imag_f		;

// Test bench control.
reg tb_wave	= 0;

// Debug.
generate
genvar ii;
for (ii = 0; ii < N; ii = ii + 1) begin : GEN_debug
	assign s_axis_tdata [ii*16 +: 16] 	= din_r[ii];
    assign dout_real	[ii] 			= m_axis_tdata[32*ii 	+: 16];
    assign dout_imag	[ii] 			= m_axis_tdata[32*ii+16 +: 16];
end
endgenerate

// Fifo for queuing waveforms.
fifo
	#(
		// Data width.
		.B	(88),
		
		// Fifo depth.
		.N	(8)
	)
	fifo_i
	( 
		.rstn	(aresetn	),
		.clk 	(aclk		),
		
		// Write I/F.
		.wr_en 	(fifo_wr_en	),
		.din    (fifo_din	),
		
		// Read I/F.
		.rd_en 	(fifo_rd_en	),
		.dout  	(fifo_dout	),
		
		// Flags.
		.full   (fifo_full	),
		.empty  (fifo_empty	)
	);

assign fifo_din = {zero_r,phrst_r,mode_r,outsel_r,nsamp_r,phase_r,freq_r};

// DUT.
down_conversion
	#(
		.N(N)
	)
	DUT
	(
		// Reset and clock.
		.aresetn		,
		.aclk			,

		// Fifo interface.
		.fifo_rd_en		,
		.fifo_empty		,
		.fifo_dout		,

    	// s_axis for input data (N samples per clock).
		.s_axis_tready	,
		.s_axis_tvalid	,
		.s_axis_tdata	,

		// m_axis for output data.
		.m_axis_tready	,
		.m_axis_tvalid	,
		.m_axis_tdata
	);

initial begin
	// Reset sequence.
	aresetn			<= 0;
	s_axis_tvalid	<= 1;
	m_axis_tready	<= 1;
	#500;
	aresetn 		<= 1;

	#1000;
	
	tb_wave			<= 1;

end

// Input data.
initial begin
	int n;
	real fs, f, pi, a;

	s_axis_tvalid	<= 1;

	for (int i=0; i<N; i=i+1) begin
		din_r [i] <= 0;
	end

	#1000;
	
	n 	= 0;
	fs 	= 125*N;
	f 	= 1;
	pi	= 3.14159;
	a = 0.7;
	while(1) begin
		@(posedge aclk);
		for (int i=0; i<N; i=i+1) begin
			din_r[i] <= 2**15*a*$cos(2*pi*f/fs*n);
			n = n+1;
		end
	end
end

// Waveforms.
initial begin
	fifo_wr_en	<= 0;
	freq_r		<= 0;
	phase_r		<= 0;
	nsamp_r		<= 0;
	outsel_r	<= 0;
	mode_r		<= 0;
	phrst_r		<= 0;
	zero_r		<= 0;

	wait (tb_wave);

	@(posedge aclk);
	fifo_wr_en	<= 1;
	freq_r		<= freq_calc(125, N, 1);
	phase_r		<= 0;
	nsamp_r		<= 20;
	outsel_r	<= 1;
	mode_r		<= 1;
	phrst_r		<= 0;

	@(posedge aclk);
	fifo_wr_en	<= 0;

	#2000;

	@(posedge aclk);
	fifo_wr_en	<= 1;
	freq_r		<= freq_calc(125, N, 1);
	phase_r		<= 0;
	nsamp_r		<= 20;
	outsel_r	<= 2;
	mode_r		<= 1;
	phrst_r		<= 1;

	@(posedge aclk);
	fifo_wr_en	<= 0;

	#2000;

	@(posedge aclk);
	fifo_wr_en	<= 1;
	freq_r		<= freq_calc(125, N, 1);
	phase_r		<= 0;
	nsamp_r		<= 20;
	outsel_r	<= 0;
	mode_r		<= 1;
	phrst_r		<= 1;

	@(posedge aclk);
	fifo_wr_en	<= 0;
end

// Paralel/serial conversion.
initial begin
	while(1) begin
		@(posedge aclk);
		for (int i=0; i<N; i=i+1) begin
			@(posedge aclk_f);
			din_r_f		<= din_r[i];
			dout_real_f <= dout_real[i];
			dout_imag_f <= dout_imag[i];
		end
	end
end

always begin
	aclk <= 0;
	#N;
	aclk <= 1;
	#N;
end

always begin
	aclk_f <= 0;
	#1;
	aclk_f <= 1;
	#1;
end

// Function to compute frequency register.
function [31:0] freq_calc;
    input int fclk;
    input int ndds;
    input int f;
    
	// All input frequencies are in MHz.
	real fs,temp;
	fs = fclk*ndds;
	temp = f/fs*2**30;
	freq_calc = {int'(temp),2'b00};
endfunction

endmodule

