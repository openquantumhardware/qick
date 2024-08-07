/*
 * This multiplier is optimized for 32x32 unsigned, so both of the
 * operands are wider than the 27 (or 26 for unsigned) and then
 * 4 DSPs are used. Pipeline is such that full-speed is achieved.
 *
 * Optimal pipeline: 6.
 *
 */
module mult_32x32
	(
		input	wire			clk		,
		input	wire	[31:0]	din_a	,
		input	wire	[31:0]	din_b	,
		output	wire	[63:0]	dout
	);

/***********/
/* Signals */
/***********/
// Input pipeline.
reg 	[31:0] 	din_a_r1	;
reg 	[31:0]	din_b_r1	;

// Product.
wire	[63:0]	p			;

// Output pipeline.
reg 	[63:0]	p_r1		;
reg 	[63:0] 	p_r2		;
reg 	[63:0] 	p_r3		;
reg 	[63:0] 	p_r4		;
reg 	[63:0] 	p_r5		;

/****************/
/* Architecture */
/****************/

// Partial products.
assign p = din_a_r1*din_b_r1;

// Registers.
always @(posedge clk) begin
	// Input pipeline.
	din_a_r1	<= din_a	;
	din_b_r1	<= din_b	;

	// Output pipeline.
	p_r1 	<= p	;
	p_r2 	<= p_r1	;
	p_r3 	<= p_r2	;
	p_r4 	<= p_r3	;
	p_r5 	<= p_r4	;
end

assign dout = p_r5;

endmodule
