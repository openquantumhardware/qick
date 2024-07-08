module iir
	#(
		parameter B 	= 16,
		parameter BA	= 20
	)
	(
		// Reset and clock.
		input 	wire 			rstn		,
		input 	wire 			clk			,

		// Input data.
		input	wire			din_valid	,
		input 	wire [B-1:0]	din			,

		// Output data.
		output	wire			dout_valid	,
		output 	wire [B-1:0]	dout		,

		// Registers.
		input	wire [B-1:0]	C0_REG		,
		input	wire [B-1:0]	C1_REG		,
		input	wire [B-1:0]	G_REG
	);

/*************/
/* Internals */
/*************/
// Number of bits of product.
localparam BP = BA + B;

// Input registers.
reg 		[B-1:0]		din_r1		;
reg 		[B-1:0]		C0_REG_r1	;
reg 		[B-1:0]		C1_REG_r1	;
reg 		[B-1:0]		G_REG_r1	;

// Valid pipeline.
reg						valid_r1	;
reg						valid_r2	;
reg						valid_r3	;
reg						valid_r4	;

// Sign-extended input.
wire signed	[BA-1:0]	xn			;

// Feed-forward filter.
reg  signed	[BA-1:0]	xn_r1		;
wire signed [BP-1:0]	p0			;
wire signed [BA-1:0]	p0_q		;
wire signed	[BA-1:0]	y0			;
reg signed	[BA-1:0]	y0_r1		;

// Feed-back filter.
wire signed [BP-1:0]	p1			;
wire signed [BA-1:0]	p1_q		;
wire signed	[BA-1:0]	y1			;
reg signed	[BA-1:0]	y1_r1a		;
reg signed	[BA-1:0]	y1_r1b		;

// Product with gain.
wire signed	[BP-1:0]	yg			;
wire signed	[B-1:0]		yg_q		;
reg			[B-1:0]		yg_q_r1		;

// Coefficients.
wire signed	[B-1:0]		c0			;
wire signed	[B-1:0]		c1			;

// Gain.
wire signed	[B-1:0]		g			;

/****************/
/* Architecture */
/****************/

// Sign-extended input.
assign xn 	= {{(BA-B){din_r1[B-1]}},din_r1};

// Feed-forward filter.
assign p0 	= c0*xn_r1;
assign p0_q	= p0[BP-2 -: BA];
assign y0 	= xn - p0_q;

// Feed-back filter.
assign p1 	= c1*y1_r1a;
assign p1_q	= p1[BP-2 -: BA];
assign y1 	= y0_r1 + p1_q;

// Product with gain.
assign yg	= g*y1_r1b;
assign yg_q	= yg[BP-2-(BA-B) -: B];

// Coefficients.
assign c0	= C0_REG_r1;
assign c1	= C1_REG_r1;

// Gain.
assign g	= G_REG_r1;

// Registers.
always @(posedge clk) begin
	if (~rstn) begin
		// Input registers.
		din_r1		<= 0;
		C0_REG_r1	<= 0;
		C1_REG_r1	<= 0;
		G_REG_r1	<= 0;

		// Valid pipeline.
		valid_r1	<= 0;
		valid_r2	<= 0;
		valid_r3	<= 0;
		valid_r4	<= 0;

		// Feed-forward filter.
		xn_r1		<= 0;
		y0_r1		<= 0;

		// Feed-back filter.
		y1_r1a		<= 0;
		y1_r1b		<= 0;

		// Product with gain.
		yg_q_r1		<= 0;
	end
	else begin
		// Input registers.
		din_r1		<= din;
		C0_REG_r1	<= C0_REG;
		C1_REG_r1	<= C1_REG;
		G_REG_r1	<= G_REG;

		// Valid pipeline.
		valid_r1	<= din_valid;
		valid_r2	<= valid_r1;
		valid_r3	<= valid_r2;
		valid_r4	<= valid_r3;

		// Feed-forward filter.
		if ( valid_r1 == 1'b1 )
			xn_r1		<= xn;
		y0_r1		<= y0;

		// Feed-back filter.
		if ( valid_r2 == 1'b1 )
			y1_r1a		<= y1;
		y1_r1b		<= y1;

		// Product with gain.
		yg_q_r1		<= yg_q;
	end
end 


// Assign outputs.
assign dout 		= yg_q_r1;
assign dout_valid	= valid_r4;

endmodule

