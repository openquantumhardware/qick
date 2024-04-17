module cmult_sub
	#(
		parameter op = "sub"
	)
	(
		input	wire			clk	,
		input	wire	[15:0]	a	,
		input	wire	[15:0]	b	,
		input	wire	[15:0]	c	,
		input	wire	[15:0]	d	,
		output	wire	[31:0]	x
	);

/***********/
/* Signals */
/***********/
// Input pipeline.
reg signed	[15:0] a_r1;
reg signed	[15:0] b_r1;
reg signed	[15:0] c_r1;
reg signed	[15:0] c_r2;
reg signed	[15:0] d_r1;
reg signed	[15:0] d_r2;

// Partial products.
wire signed [31:0] ab;
wire signed [31:0] cd;

// Pipeline of partial products.
reg signed [31:0] ab_r1;
reg signed [31:0] ab_r2;
reg signed [31:0] cd_r1;

// Combined result.
wire signed [31:0] res;

// Pipelined result.
reg signed [31:0] res_r1;

/****************/
/* Architecture */
/****************/

// Partial products.
assign ab = a_r1*b_r1;
assign cd = c_r2*d_r2;

// Combined result.
generate
	if (op == "sub") begin
		assign res = ab_r2 - cd_r1;
	end
	else if (op == "add") begin
		assign res = ab_r2 + cd_r1;
	end
endgenerate

// Registers.
always @(posedge clk) begin
	// Input pipeline.
	a_r1 <= a;
	b_r1 <= b;
	c_r1 <= c;
	c_r2 <= c_r1;
	d_r1 <= d;
	d_r2 <= d_r1;

	// Pipeline of partial products.
	ab_r1 <= ab;
	ab_r2 <= ab_r1;
	cd_r1 <= cd;

	// Pipelined result.
	res_r1 <= res;
end

/***********/
/* Outputs */
/***********/
assign x = res_r1;

endmodule
