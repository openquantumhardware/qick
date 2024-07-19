module tb();

localparam N = 8;

// Reset and clock.
reg				aresetn			;
reg				aclk			;

// s0_axis for pushing waveforms.
wire			s0_axis_tready	;
reg				s0_axis_tvalid	;
reg	[87:0]		s0_axis_tdata	;

// s1_axis for input data (8 real samples per clock).
wire			s1_axis_tready	;
reg			    s1_axis_tvalid	;
wire[N*16-1:0]	s1_axis_tdata	;

// m0_axis for output data (8 complex samples per clock).
reg			    m0_axis_tready	;
wire			m0_axis_tvalid	;
wire[255:0]		m0_axis_tdata	;

// m1_axis for output data (1 complex sample per clock).
reg			    m1_axis_tready	;
wire			m1_axis_tvalid	;
wire[31:0]		m1_axis_tdata	;

// Waveform parameters.
reg	[31:0]		freq_r			;
reg	[31:0]		phase_r			;
reg	[15:0]		nsamp_r			;
reg	[1:0]		outsel_r		;
reg				mode_r			;
reg				phrst_r			;
reg	[3:0]		zero_r			;

// Input data.
reg	[15:0]		din_r [N]		;

// Output full-speed data.
reg	[31:0]		dout_r_f [N]		;

// Output data.
wire[15:0]		dout_real		;
wire[15:0]		dout_imag		;

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
	assign s1_axis_tdata [ii*16 +: 16] 	= din_r[ii];
	assign dout_r_f[ii] 	= m0_axis_tdata[ii*32 +: 32];
end
endgenerate

assign dout_real = m1_axis_tdata[0 	+: 16];
assign dout_imag = m1_axis_tdata[16	+: 16];

assign s0_axis_tdata = {zero_r,phrst_r,mode_r,outsel_r,nsamp_r,phase_r,freq_r};

// DUT.
axis_dyn_readout_v1
	DUT
	(
		// Reset and clock.
		.aresetn		,
		.aclk			,

    	// s0_axis for pushing waveforms.
		.s0_axis_tready	,
		.s0_axis_tvalid	,
		.s0_axis_tdata	,

    	// s1_axis for input data (8 real samples per clock).
		.s1_axis_tready	,
		.s1_axis_tvalid	,
		.s1_axis_tdata	,

		// m0_axis for output data (8 complex samples per clock).
		.m0_axis_tready	,
		.m0_axis_tvalid	,
		.m0_axis_tdata   ,
		
        // m1_axis for output data (1 complex sample per clock).
		.m1_axis_tready	,
		.m1_axis_tvalid	,
		.m1_axis_tdata

	);

initial begin
	// Reset sequence.
	aresetn			<= 0;
	m0_axis_tready	<= 1;
	m1_axis_tready	<= 1;
	#500;
	aresetn 		<= 1;

	#1000;
	
	tb_wave			<= 1;

end

// Input data.
initial begin
	int n;
	real fs, f, pi, a;

	s1_axis_tvalid	<= 1;

	for (int i=0; i<N; i=i+1) begin
		din_r [i] <= 0;
	end

	#1000;
	
	n 	= 0;
	fs 	= 125*N;
	f 	= 18;
	pi	= 3.14159;
	a = 0.9;
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
	s0_axis_tvalid	<= 0;
	freq_r			<= 0;
	phase_r			<= 0;
	nsamp_r			<= 0;
	outsel_r		<= 0;
	mode_r			<= 0;
	phrst_r			<= 0;
	zero_r			<= 0;

	wait (tb_wave);

	@(posedge aclk);
	s0_axis_tvalid	<= 1;
	freq_r			<= freq_calc(125, N, 1);
	phase_r			<= 0;
	nsamp_r			<= 20;
	outsel_r		<= 1;
	mode_r			<= 1;
	phrst_r			<= 0;

	@(posedge aclk);
	s0_axis_tvalid	<= 0;

	#2000;

	@(posedge aclk);
	s0_axis_tvalid	<= 1;
	freq_r			<= freq_calc(125, N, 1);
	phase_r			<= 0;
	nsamp_r			<= 20;
	outsel_r		<= 2;
	mode_r			<= 1;
	phrst_r			<= 1;

	@(posedge aclk);
	s0_axis_tvalid	<= 0;

	#20000;

	@(posedge aclk);
	s0_axis_tvalid	<= 1;
	freq_r			<= freq_calc(125, N, 180);
	phase_r			<= 0;
	nsamp_r			<= 20;
	outsel_r		<= 0;
	mode_r			<= 1;
	phrst_r			<= 1;

	@(posedge aclk);
	s0_axis_tvalid	<= 0;
	
	#2000;

	@(posedge aclk);
	s0_axis_tvalid	<= 1;
	freq_r			<= freq_calc(125, N, 110);
	phase_r			<= 0;
	nsamp_r			<= 20;
	outsel_r		<= 0;
	mode_r			<= 1;
	phrst_r			<= 1;

	@(posedge aclk);
	s0_axis_tvalid	<= 0;
	
	#2000;

	@(posedge aclk);
	s0_axis_tvalid	<= 1;
	freq_r			<= freq_calc(125, N, 180);
	phase_r			<= 0;
	nsamp_r			<= 20;
	outsel_r		<= 0;
	mode_r			<= 1;
	phrst_r			<= 1;

	@(posedge aclk);
	s0_axis_tvalid	<= 0;		
end

// Paralel/serial conversion.
initial begin
	while(1) begin
		@(posedge aclk);
		for (int i=0; i<N; i=i+1) begin
			@(posedge aclk_f);
			din_r_f		<= din_r[i];
			dout_real_f		<= dout_r_f[i][0 +: 16];
			dout_imag_f		<= dout_r_f[i][16 +: 16];
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

