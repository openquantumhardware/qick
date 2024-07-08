/*
 * DDS Control input format:
 *
 * |----------|---------|
 * | 31 .. 16 | 15 .. 0 |
 * |----------|---------|
 * | phase    | pinc    |
 * |----------|---------|
 *
 */
module dds_ctrl
	(
		// Reset and clock.
		input 	wire 		rstn		,
		input 	wire 		clk			,

		// Modulation trigger.
		input	wire		trigger		,

		// Data input.
		input	wire		din_valid	,
	
		// DDS control output.
		output	wire		dout_valid	,
		output 	wire [31:0]	dout		,

		// Registers.
		input	wire [15:0]	BVAL_REG	,
		input	wire [15:0]	SLOPE_REG	,
		input	wire [15:0]	STEPS_REG	,
		input	wire [15:0]	WAIT_REG	,
		input	wire [15:0]	FREQ_REG
	);

/*************/
/* Internals */
/*************/

// Modulation output.
wire	[15:0]	mod_out		;
reg		[15:0]	mod_out_r1	;

// Frequency addition.
wire	[15:0]	freq		;
reg		[15:0]	freq_r1		;

// Valid pipeline.
reg				valid_r1	;
reg				valid_r2	;

// Registers.
reg		[15:0]	FREQ_REG_r	;

/****************/
/* Architecture */
/****************/

// Modulation control.
// Latency : 0.
mod_ctrl
	#(
		.B(16)
	)
	mod_ctrl_i
	(
		// Reset and clock.
		.rstn		(rstn		),
		.clk		(clk		),
	
		// Trigger.
		.trigger	(trigger	),

		// Enable.
		.en			(din_valid	),

		// Modulation Output.
		.y			(mod_out	),

		// Registers.
		.B_REG		(BVAL_REG	),
		.M_REG		(SLOPE_REG	),
		.N_REG		(STEPS_REG	),
		.W_REG		(WAIT_REG	)
	);

// Frequency addition.
assign freq = FREQ_REG_r - mod_out_r1;

always @(posedge clk) begin
	if (rstn == 1'b0) begin
		// Modulation output.
		mod_out_r1	<= 0;

		// Frequency addition.
		freq_r1		<= 0;

		// Valid pipeline.
		valid_r1	<= 0;
		valid_r2	<= 0;
		
		// Registers.
		FREQ_REG_r	<= 0;
	end
	else begin
		// Modulation output.
		mod_out_r1	<= mod_out;

		// Frequency addition.
		freq_r1		<= freq;

		// Valid pipeline.
		valid_r1	<= din_valid;
		valid_r2	<= valid_r1;
		
		// Registers.
		FREQ_REG_r	<= FREQ_REG;
	end
end

// Assign outputs.
assign dout			= {{16{1'b0}},freq_r1};
assign dout_valid	= valid_r2;

endmodule

