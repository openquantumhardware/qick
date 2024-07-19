module tb();

parameter B 		= 16;
parameter PUNCT_ID 	= 3;
parameter NLAST		= 100;

// Reset and clock.
reg 		rstn			;
reg 		clk				;

// Modulation trigger.
reg			trigger			;

// Input data.
reg			din_valid		;
wire [31:0]	din				;
reg			din_last		;

// Output data.
wire		dout_valid		;
wire [31:0]	dout			;
wire		dout_last		;

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
reg	 [15:0]	PUNCT_ID_REG	;

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
kidsim_top
	DUT
	(
		// Reset and clock.
		.rstn			,
		.clk			,

		// Modulation trigger.
		.trigger		,

		// Input data.
		.din_valid		,
		.din			,
		.din_last		,

		// Output data.
		.dout_valid		,
		.dout			,
		.dout_last		,

		// Registers.
		.DDS_BVAL_REG	,
		.DDS_SLOPE_REG	,
		.DDS_STEPS_REG	,
		.DDS_WAIT_REG	,
		.DDS_FREQ_REG	,
		.IIR_C0_REG		,
		.IIR_C1_REG		,
		.IIR_G_REG		,
		.OUTSEL_REG		,
		.PUNCT_ID_REG
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
	PUNCT_ID_REG	<= 4;

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
	int n, idx;

	// Data.
	din_valid	<= 1;
	din_last	<= 0;
	din_real	<= 0;
	din_imag	<= 0;

	wait(tb_data_in);

	// Load memory with frequencies.
	n = 0;
	idx = 0;
	while (1) begin
		if ( idx == NLAST-1) begin
			@(posedge clk);
			idx = 0;
			din_last <= 1;
		end
		else if ( idx == PUNCT_ID) begin
			@(posedge clk);
			idx = idx + 1;
			din_last	<= 0;
			din_real 	<= 0.9*(2**(B-1))*$cos(2*3.14*0.007*n);
			din_imag 	<= 0.9*(2**(B-1))*$sin(2*3.14*0.007*n);
			n = n + 1;
		end
		else begin
			@(posedge clk);
			idx = idx + 1;
			din_last	<= 0;
			//din_real 	<= $random;
			//din_imag 	<= $random;
			din_real 	<= 0;
			din_imag 	<= 0;
		end
	end
end

always begin
	clk <= 0;
	#5;
	clk <= 1;
	#5;
end  

endmodule

