module tb();

// Clock.
reg				aclk			;

// S_AXIS for input data.
reg				s_axis_tvalid	;
wire	[31:0]	s_axis_tdata	;

// M_AXIS for output data.
wire			m_axis_tvalid	;
wire	[31:0]	m_axis_tdata	;

// Registers.
reg		[31:0]	PINC_REG		;
reg		[31:0]	POFF_REG		;

/**************/
/* Test Bench */
/**************/
reg		[15:0]	din_real		;
reg		[15:0]	din_imag		;
wire	[15:0]	dout_real		;
wire	[15:0]	dout_imag		;

/****************/
/* Architecture */
/****************/

assign s_axis_tdata = {din_imag, din_real};
assign dout_real	= m_axis_tdata [15:0];
assign dout_imag	= m_axis_tdata [31:16];

// DUT.
ddsprod DUT
	(
		// Clock.
		.aclk			,

		// S_AXIS for input data.
		.s_axis_tvalid	,
		.s_axis_tdata	,

		// M_AXIS for output data.
		.m_axis_tvalid	,
		.m_axis_tdata	,

		// Registers.
		.PINC_REG		,
		.POFF_REG
	);

// PINC/POFF.
initial begin
	PINC_REG <= 0;
	POFF_REG <= 0;

	#1000;

	// Set dds frequency/phase.
	PINC_REG <= freq(1, 500);
	POFF_REG <= phase(90);
end

// Input data.
initial begin
	int n;
	real a0, w0, f0, fs;

	s_axis_tvalid <= 0;
	din_real <= 0;
	din_imag <= 0;

	// Amplitude.
	a0 = 0.5;

	// Frequency.
	fs = 500;
	f0 = 1;
	w0 = f0/fs*2*3.14159;

	n = 0;
	while (1) begin
		for (int i=0; i<10; i=i+1) begin
			@(posedge aclk);
			s_axis_tvalid <= 0;
		end
		@(posedge aclk);
		s_axis_tvalid <= 1;
		din_real <= a0*2**15*$cos(w0*n);
		din_imag <= a0*2**15*$sin(w0*n);
		n = n+1;
	end
end

always begin
	aclk <= 0;
	#1;
	aclk <= 1;
	#1;
end  

function bit [31:0] freq (input real f, fs);
    int ret;
    
	// I use only 16 bits for rounding. Add the remaining later...
	ret = 2**16*f/fs;

	return {ret,16'h0000};
endfunction

function bit [31:0] phase (input real phi);
    int ret;
    
	// I use only 16 bits for rounding. Add the remaining later...
	ret = 2**16*phi/360;

	return {ret,16'h0000};
endfunction

endmodule

