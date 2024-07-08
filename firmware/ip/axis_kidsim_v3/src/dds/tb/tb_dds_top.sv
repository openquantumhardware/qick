module tb;

// Reset and clock.
reg 		rstn		;
reg 		clk			;

// Modulation trigger.
reg			trigger		;

// Data input.
reg			din_valid	;

// Data output.
wire[31:0]	dout		;

// Registers.
reg [15:0]	BVAL_REG	;
reg [15:0]	SLOPE_REG	;
reg [15:0]	STEPS_REG	;
reg [15:0]	WAIT_REG	;
reg [15:0]	FREQ_REG	;
 
// DUT.
dds_top
	DUT
	(
		// Reset and clock.
		.rstn		,
		.clk		,

		// Modulation trigger.
		.trigger	,

		// Data input.
		.din_valid	,

		// Data output.
		.dout		,

		// Registers.
		.BVAL_REG	,
		.SLOPE_REG	,
		.STEPS_REG	,
		.WAIT_REG	,
		.FREQ_REG
	);

// Main TB.
initial begin
    real b, m, n;
    
	rstn		<= 0;
	trigger		<= 0;
	BVAL_REG	<= 0;
	SLOPE_REG	<= 0;
	STEPS_REG	<= 0;
	WAIT_REG	<= 0;
	FREQ_REG    <= 0;
	@(posedge clk);
	rstn	<= 1;

	#300;

	// Configure block.
	b = 4000;
	m = 10;
	n = b/m;
	@(posedge clk);
	BVAL_REG	<= integer'(b);
	SLOPE_REG	<= integer'(m);
	STEPS_REG	<= integer'(n);
	WAIT_REG	<= 50;
	FREQ_REG 	<= freq_calc(100, 10.1);

	#3000;

	for (int i=0; i<10; i=i+1) begin
		@(posedge clk);
		trigger <= 1;
		@(posedge clk);
		trigger <= 0;
		#1000000;
	end
end

// din_valid.
initial begin
	din_valid	<= 1;

	#4000;

	@(posedge clk);
	din_valid	<= 0;

	#400;

	@(posedge clk);
	din_valid	<= 1;
end

always begin
	clk <= 0;
	#5;
	clk <= 1;
	#5;
end

// Function to compute frequency register.
function [15:0] freq_calc;
    input real fclk;
    input real f;
    
	// All input frequencies are in MHz.
	real temp;
	temp = f/fclk*2**16;
	freq_calc = int'(temp);
endfunction

endmodule

