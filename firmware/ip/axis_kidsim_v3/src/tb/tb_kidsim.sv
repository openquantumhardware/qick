module tb();

parameter B = 16;

// Reset and clock.
reg 		rstn			;
reg 		clk				;

// Modulation trigger.
reg			trigger			;

// Input data.
wire [31:0]	din				;
reg			din_valid		;

// Output data.
wire [31:0]	dout			;
wire		dout_valid		;

// Registers.
reg  [15:0]	DDS_BVAL_REG	;
reg  [15:0]	DDS_SLOPE_REG	;
reg  [15:0]	DDS_STEPS_REG	;
reg  [15:0]	DDS_WAIT_REG	;
reg  [15:0]	DDS_FREQ_REG	;
reg  [15:0]	IIR_C0_REG		;
reg  [15:0]	IIR_C1_REG		;
reg  [15:0]	IIR_G_REG		;
reg  [ 1:0]	OUTSEL_REG		;

// Debug.
reg	 [B-1:0] din_real;
reg	 [B-1:0] din_imag;
wire [B-1:0] dout_real;
wire [B-1:0] dout_imag;

// TB control.
reg	tb_data_in = 0;

assign din = {din_imag, din_real};
assign dout_real = dout[0 +: B];
assign dout_imag = dout[B +: B];

// DUT.
kidsim
	DUT
	(
		// Reset and clock.
		.rstn			,
		.clk			,

		// Modulation trigger.
		.trigger		,

		// Input data.
		.din			,
		.din_valid		,

		// Output data.
		.dout			,
		.dout_valid		,

		// Registers.
		.DDS_BVAL_REG	,
		.DDS_SLOPE_REG	,
		.DDS_STEPS_REG	,
		.DDS_WAIT_REG	,
		.DDS_FREQ_REG	,
		.IIR_C0_REG		,
		.IIR_C1_REG		,
		.IIR_G_REG		,
		.OUTSEL_REG
	);

// Main TB.
initial begin
    real b, m, n, wc;
	real c0, c1, g, a;

	rstn			<= 0;	
	trigger			<= 0;
	DDS_BVAL_REG	<= 0;
	DDS_SLOPE_REG	<= 0;
	DDS_STEPS_REG	<= 0;
	DDS_WAIT_REG	<= 0;
	DDS_FREQ_REG	<= 0;
	IIR_C0_REG		<= 0;
	IIR_C1_REG		<= 0;
	IIR_G_REG		<= 0;
	OUTSEL_REG		<= 0;

	#300;

	rstn			<= 1;

	// Configure DDS.
	wc				= 0.1;
	b 				= 0.9*wc*2**B;
	m 				= 10;
	n 				= b/m;
	DDS_BVAL_REG	<= integer'(b);
	DDS_SLOPE_REG	<= integer'(m);
	DDS_STEPS_REG	<= integer'(n);
	DDS_WAIT_REG	<= 50;
	DDS_FREQ_REG 	<= wc*2**B;

	// Configure Resonator.
	c0 				= 0.95;
	c1 				= 0.8;
	g				= (1+c1)/(1+c0);
	IIR_C0_REG		<= c0*(2**(B-1));
	IIR_C1_REG		<= c1*(2**(B-1));
	IIR_G_REG		<= g*(2**(B-1));
	
	# 300;
	
	tb_data_in <= 1;

	#5000;

	trigger <= 1;
	
end

// Input data generation.
initial begin
	int n;

	// Data.
	din_real	<= 0;
	din_imag	<= 0;
	din_valid	<= 1;

	wait(tb_data_in);

	// Load memory with frequencies.
	while (1) begin
		for (int i=0; i<100; i=i+1) begin	    
			@(posedge clk);
			din_real <= 0.9*(2**(B-1))*$cos(2*3.14*0.007*n);
			din_imag <= 0.9*(2**(B-1))*$sin(2*3.14*0.007*n);
			din_valid <= 1;
			n = n + 1;
		end
		//for (int i=0; i<10; i=i+1) begin	    
		//	@(posedge clk);
		//	din_real <= $random;
		//	din_valid <= 0;
		//end
	end
end

always begin
	clk <= 0;
	#5;
	clk <= 1;
	#5;
end  

endmodule

