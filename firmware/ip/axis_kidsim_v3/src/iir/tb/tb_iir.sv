module tb;

parameter B		= 8;
parameter BA	= B + 4;

// Reset and clock.
reg 			rstn		;
reg				clk			;

// Input data.
reg				din_valid	;
wire [2*B-1:0]	din			;

// Output data.
wire			dout_valid	;
wire [2*B-1:0]	dout		;

// Registers.
reg  [B-1:0]	C0_REG		;
reg  [B-1:0]	C1_REG		;
reg  [B-1:0]	G_REG		;

// Variables.
real c0, c1, g, a;

// Debug.
reg	 [B-1:0] din_real;
reg	 [B-1:0] din_imag;
wire [B-1:0] dout_real;
wire [B-1:0] dout_imag;

// Test bench control.
reg tb_data = 0;

assign din = {din_imag, din_real};
assign dout_real = dout[0 +: B];
assign dout_imag = dout[B +: B];

// IIR
iir_iq
	#(
		.B	(B	),
		.BA	(BA	)
	)
	DUT
	(
		// Reset and clock.
		.rstn		,
		.clk		,

		// Input data.
		.din_valid	,
		.din		,

		// Output data.
		.dout_valid	,
		.dout		,

		// Registers.
		.C0_REG		,
		.C1_REG		,
		.G_REG
	);

// Main TB.
initial begin
	rstn		<= 0;

	#300;

	@(posedge clk);
	rstn	<= 1;

	#200;

	@(posedge clk);
	tb_data		<= 1;

end

// Initialize memory contents.
initial begin
	int n;

	// Data.
	din_real	<= 0;
	din_imag	<= 0;
	din_valid	<= 1;

	c0 	= 0;
	c1 	= 0;
	g	= 0;
	a	= 0.9;

	// Set resonator.
	c0 	= 0.95;
	c1 	= 0.8;
	g	= (1+c1)/(1+c0);

	// Set registers.
	C0_REG	= c0*(2**(B-1));
	C1_REG	= c1*(2**(B-1));
	G_REG	= g*(2**(B-1));

	wait(tb_data);

	// Load memory with frequencies.
	while (1) begin
		for (int i=0; i<100; i=i+1) begin	    
			@(posedge clk);
			din_real <= a*(2**(B-1))*$cos(2*3.14*0.018*n);
			din_valid <= 1;
			n = n + 1;
		end
		for (int i=0; i<10; i=i+1) begin	    
			@(posedge clk);
			din_real <= $random;
			din_valid <= 0;
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

