module tb;

parameter B	= 8;

// Reset and clock.
reg 			rstn	;
reg 			clk		;

// Trigger.
reg				trigger	;

// Modulation Output.
wire [B-1:0]	y		;

// Registers.
 reg [B-1:0]	B_REG	;
 reg [B-1:0]	M_REG	;
 reg [B-1:0]	N_REG	;
 
// DUT.
mod_ctrl
	#(
		.B(B)
	)
	DUT
	(
		// Reset and clock.
		.rstn		(rstn		),
		.clk		(clk		),
	
		// Trigger.
		.trigger	(trigger	),

		// Modulation Output.
		.y			(y			),

		// Registers.
		.B_REG		,
		.M_REG		,
		.N_REG
	);

// Main TB.
initial begin
    real b, m, n;
    
	rstn	<= 0;
	trigger	<= 0;
	B_REG	<= 0;
	M_REG	<= 0;
	N_REG	<= 0;
	@(posedge clk);
	rstn	<= 1;

	#300;

	// Configure block.
	b = 77;
	m = 3;
	n = b/m;
	@(posedge clk);
	B_REG	<= integer'(b);
	M_REG	<= integer'(m);
	N_REG	<= integer'(n);

	#300;

	for (int i=0; i<10; i=i+1) begin
		@(posedge clk);
		trigger <= 1;
		#1000;
		@(posedge clk);
		trigger <= 0;
		#1000;
	end



	
end

always begin
	clk <= 0;
	#5;
	clk <= 1;
	#5;
end

endmodule

