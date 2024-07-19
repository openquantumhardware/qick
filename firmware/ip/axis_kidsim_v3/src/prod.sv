module prod
	#(
		parameter CONJA = 0	,
		parameter CONJB = 0	,
		parameter B		= 16
	)
	(
		// Reset and clock.
		input 	wire 			rstn		,
		input 	wire 			clk			,

		// Input data.
		input	wire			din_valid	,
		input	wire [2*B-1:0]	dina		,
		input	wire [2*B-1:0]	dinb		,

		// Output data.
		output	wire			dout_valid	,
		output	wire [2*B-1:0]	dout
	);

/*************/
/* Internals */
/*************/
// Valid pipeline.
reg						valid_r1;
reg						valid_r2;
reg						valid_r3;
reg						valid_r4;

// Input registers.
reg			[2*B-1:0]	dina_r;
reg			[2*B-1:0]	dinb_r;

// Partial products.
wire signed [B-1:0]		dina_real;
wire signed [B-1:0]		dina_imag;
wire signed [B-1:0]		dinb_real;
wire signed [B-1:0]		dinb_imag;
wire signed [2*B-1:0]	prod_real_a;
wire signed [2*B-1:0]	prod_real_b;
wire signed [2*B-1:0]	prod_imag_a;
wire signed [2*B-1:0]	prod_imag_b;
reg  signed [2*B-1:0]	prod_real_a_r;
reg  signed [2*B-1:0]	prod_real_b_r;
reg  signed [2*B-1:0]	prod_imag_a_r;
reg  signed [2*B-1:0]	prod_imag_b_r;

// Full product.
wire signed [2*B-1:0]	prod_real;
wire signed [2*B-1:0]	prod_imag;
reg signed [2*B-1:0]	prod_real_r;
reg signed [2*B-1:0]	prod_imag_r;

// Rounding.
wire signed [B-1:0]		prod_real_round;
wire signed [B-1:0]		prod_imag_round;
wire 		[2*B-1:0]	prod;
reg 		[2*B-1:0]	prod_r;

/****************/
/* Architecture */
/****************/
// Partial products.
assign dina_real		= dina_r[0 +: B];
assign dina_imag		= (CONJA == 1)? -dina_r[B +: B] : dina_r[B +: B];
assign dinb_real		= dinb_r[0 +: B];
assign dinb_imag		= (CONJB == 1)? -dinb_r[B +: B] : dinb_r[B +: B];
assign prod_real_a		= dina_real*dinb_real;
assign prod_real_b		= dina_imag*dinb_imag;
assign prod_imag_a		= dina_real*dinb_imag;
assign prod_imag_b		= dina_imag*dinb_real;

// Full product.
assign prod_real		= prod_real_a_r - prod_real_b_r;
assign prod_imag		= prod_imag_a_r + prod_imag_b_r;

// Rounding.
assign prod_real_round	= prod_real_r [2*B-2 -: B];
assign prod_imag_round	= prod_imag_r [2*B-2 -: B];
assign prod				= {prod_imag_round,prod_real_round};

// Registers.
always @(posedge clk) begin
	if (~rstn) begin
		// Valid pipeline.
		valid_r1		<= 0;
		valid_r2		<= 0;
		valid_r3		<= 0;
		valid_r4		<= 0;

		// Input registers.
		dina_r			<= 0;
		dinb_r			<= 0;

		// Partial products.
		prod_real_a_r	<= 0;
		prod_real_b_r	<= 0;
		prod_imag_a_r	<= 0;
		prod_imag_b_r	<= 0;
		
		// Full product.
		prod_real_r		<= 0;
		prod_imag_r		<= 0;
		
		// Rounding.
		prod_r			<= 0;
	end
	else begin
		// Valid pipeline.
		valid_r1		<= din_valid;
		valid_r2		<= valid_r1;
		valid_r3		<= valid_r2;
		valid_r4		<= valid_r3;

		// Input registers.
		dina_r			<= dina;
		dinb_r			<= dinb;

		// Partial products.
		prod_real_a_r	<= prod_real_a;
		prod_real_b_r	<= prod_real_b;
		prod_imag_a_r	<= prod_imag_a;
		prod_imag_b_r	<= prod_imag_b;
		
		// Full product.
		prod_real_r		<= prod_real;
		prod_imag_r		<= prod_imag;
		
		// Rounding.
		prod_r			<= prod;

	end
end 

// Assign outputs.
assign dout_valid	= valid_r4;
assign dout			= prod_r;

endmodule

