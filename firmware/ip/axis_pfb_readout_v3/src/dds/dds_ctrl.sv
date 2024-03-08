/*
 * DDS Control input:
 * 
 * |----------|--------|----------|--------|
 * | 71 .. 65 | 64     | 63 .. 32 | 31 .. 0|
 * |----------|--------|----------|--------|
 * | not used | resync | poff     | pinc   |
 * |----------|--------|----------|--------|
 * 
*/

module dds_ctrl
	(
		// Clock.
		input	wire			aclk		,

		// Enable input.
		input	wire			en			,

		// Output data.
		output	wire			dout_valid	,
		output	wire	[71:0]	dout		,

		// Registers.
		input	wire	[31:0]	PINC_REG	,
		input	wire	[31:0]	POFF_REG
	);

/********************/
/* Internal signals */
/********************/
// Time counter.
reg		[31:0]	cnt		= 0;
reg		[31:0]	cnt_r1	= 0;

// Registers.
reg		[31:0]	pinc_r1	= 0;
reg		[31:0]	pinc_r2	= 0;
reg		[31:0]	poff_r1	= 0;

// Multiplier output (modulo arithmetic, keep lower bits).
wire	[31:0]	mult_int;

// Final phase.
wire	[31:0]	poff_out;
reg		[31:0]	poff_out_r1;

// Output control word.
wire	[71:0]	dds_ctrl_out;

// latency for en.
wire			en_la;

/**********************/
/* Begin Architecture */
/**********************/

// Final phase.
assign poff_out = poff_r1 + mult_int;

// Output control word.
assign dds_ctrl_out = {7'b0000000,1'b1,poff_out_r1,pinc_r2};

// Multiplier: 32x32, unsigned, optimized for speed.
// Latency: 6.
(* keep_hierarchy = "true" *) mult_32x32 mult_i
	(
		.clk	(aclk		),
		.din_a	(pinc_r1	),
		.din_b	(cnt_r1		),
		.dout	(mult_int	)
	);

// Latency for en (valid).
// Latency = 2 (cnt) + 6 (mult_32x32) + 1 (poff_out) = 9.
latency_reg
	#(
		.N(9),
		.B(1)
	)
	latency_reg_en_i
	(
		.clk	(aclk	),
		.din	(en		),
		.dout	(en_la	)
	);


// Registers.
always @(posedge aclk) begin
	// Time counter.
	if (en == 1'b1)
		cnt	<= cnt + 1;
	cnt_r1 <= cnt;

	// Registers.
	pinc_r1	<= PINC_REG;
	pinc_r2	<= pinc_r1;
	poff_r1	<= POFF_REG;

	// Final phase.
	poff_out_r1 <= poff_out;
end

// Assign outputs.
assign dout_valid 	= en_la			;
assign dout			= dds_ctrl_out	;

endmodule

